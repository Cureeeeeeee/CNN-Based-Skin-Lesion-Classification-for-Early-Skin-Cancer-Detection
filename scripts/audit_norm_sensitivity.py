"""Phase E.6 preprocessing audit — normalization sensitivity + misclassified
sample inspection for the v2 single ResNet50 on the ISIC clean test set.

Task 2 found a large HAM-vs-ISIC channel-mean gap (red ~0.19). This tests
whether that colour gap is *causal* for the external drop, by re-evaluating v2
RN50 under two preprocessing variants:

  imagenet          : the deployed pipeline (resize 224 -> ImageNet normalize).
  ham_moment_match  : per-channel map ISIC colour moments onto HAM's
                      (x - isic_mean)/isic_std * ham_std + ham_mean, clip [0,1],
                      THEN ImageNet normalize. This makes ISIC inputs colour-
                      match the training (HAM) distribution.

If ham_moment_match does NOT recover mel recall / macro F1, the external drop is
semantic distribution shift, not a colour/normalization artefact.

Also prints 5 v2-misclassified ISIC examples (true/pred/prob/dims) to rule out
degenerate inputs.

Usage: python -m scripts.audit_norm_sensitivity --stat-n 300 --seed 42
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from PIL import Image
from sklearn.metrics import balanced_accuracy_score

from src.skinlesion.config import load_config
from src.skinlesion.data import IMAGENET_MEAN, IMAGENET_STD
from src.skinlesion.ensemble import load_calibration
from src.skinlesion.metrics import summarize_classification
from src.skinlesion.models import create_model
from src.skinlesion.train import select_device

CKPT_DIR = "runs/resnet50_v2"
SIZE = 224


def channel_moments(paths, size=SIZE):
    ms, ss = [], []
    for p in paths:
        with Image.open(p) as im:
            arr = np.asarray(im.convert("RGB").resize((size, size), Image.BILINEAR),
                             dtype=np.float64) / 255.0
        ms.append(arr.reshape(-1, 3).mean(axis=0))
        ss.append(arr.reshape(-1, 3).std(axis=0))
    return np.array(ms).mean(0), np.array(ss).mean(0)


def load_resized01(path):
    with Image.open(path) as im:
        rgb = im.convert("RGB")
        w, h = rgb.size
        arr = np.asarray(rgb.resize((SIZE, SIZE), Image.BILINEAR), dtype=np.float32) / 255.0
    return arr, (w, h)


def to_tensor(arr01):
    mean = np.asarray(IMAGENET_MEAN, dtype=np.float32)
    std = np.asarray(IMAGENET_STD, dtype=np.float32)
    norm = (arr01 - mean) / std
    return torch.from_numpy(norm).permute(2, 0, 1)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stat-n", type=int, default=300)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--batch-size", type=int, default=32)
    args = ap.parse_args()

    cfg = load_config("configs/ham10000.yaml")
    classes = cfg["data"]["classes"]
    c2i = {c: i for i, c in enumerate(classes)}
    device = select_device("auto")

    ham = pd.read_csv("data/processed/splits.csv")
    ham = ham[ham["split"] == "test"]
    isic = pd.read_csv("data/processed/isic2019_clean_test.csv")

    rng = np.random.default_rng(args.seed)
    ham_s = [str(Path(p)) for p in ham["image_path"].sample(min(args.stat_n, len(ham)), random_state=args.seed)]
    isic_s = [str(Path(p)) for p in isic["image_path"].sample(min(args.stat_n, len(isic)), random_state=args.seed)]
    ham_mean, ham_std = channel_moments(ham_s)
    isic_mean, isic_std = channel_moments(isic_s)
    print(f"HAM  moments mean={np.round(ham_mean,4)} std={np.round(ham_std,4)}")
    print(f"ISIC moments mean={np.round(isic_mean,4)} std={np.round(isic_std,4)}")

    # load v2 model
    ckpt = torch.load(Path(CKPT_DIR) / "best.pt", map_location=device, weights_only=False)
    model = create_model("resnet50", num_classes=len(classes), pretrained=False).to(device)
    model.load_state_dict(ckpt["state_dict"]); model.eval()
    T, _ = load_calibration(Path(CKPT_DIR) / "best.pt")
    print(f"v2 RN50 loaded, T={T:.4f}\n")

    paths = [str(Path(p)) for p in isic["image_path"]]
    y_true = [c2i[l] for l in isic["label"]]
    image_ids = list(isic["image_id"])
    dims = {}

    def run(variant: str):
        preds, probs_all = [], []
        with torch.no_grad():
            for start in range(0, len(paths), args.batch_size):
                chunk = paths[start:start + args.batch_size]
                tensors = []
                for p in chunk:
                    arr, wh = load_resized01(p)
                    dims[p] = wh
                    if variant == "ham_moment_match":
                        arr = (arr - isic_mean) / isic_std * ham_std + ham_mean
                        arr = np.clip(arr, 0.0, 1.0).astype(np.float32)
                    tensors.append(to_tensor(arr))
                batch = torch.stack(tensors).to(device)
                p_ = torch.softmax(model(batch) / T, dim=1).cpu().numpy()
                probs_all.append(p_); preds.extend(p_.argmax(1).tolist())
        return np.array(preds), np.concatenate(probs_all, 0)

    results = {}
    for variant in ["imagenet", "ham_moment_match"]:
        preds, probs = run(variant)
        m = summarize_classification(y_true, preds.tolist(), classes)
        rec = m["classification_report"]
        results[variant] = {
            "mel": rec["mel"]["recall"] * 100, "macro_f1": m["macro_f1"] * 100,
            "bal_acc": balanced_accuracy_score(y_true, preds) * 100,
            "preds": preds, "probs": probs,
        }
        print(f"[{variant:18}] mel={results[variant]['mel']:6.2f} "
              f"macroF1={results[variant]['macro_f1']:6.2f} balAcc={results[variant]['bal_acc']:6.2f}")

    d_mel = results["ham_moment_match"]["mel"] - results["imagenet"]["mel"]
    d_f1 = results["ham_moment_match"]["macro_f1"] - results["imagenet"]["macro_f1"]
    print(f"\nDELTA (moment_match - imagenet): mel={d_mel:+.2f} pp  macroF1={d_f1:+.2f} pp")
    print("=> colour/normalization is " + (
        "a MAJOR factor (recovers >5pp)" if max(d_mel, d_f1) > 5
        else "NOT the cause (recovery <5pp) — drop is semantic distribution shift"))

    # Task 3: 5 misclassified examples under the deployed (imagenet) pipeline
    print("\n=== 5 v2-misclassified ISIC examples (imagenet pipeline) ===")
    preds = results["imagenet"]["preds"]; probs = results["imagenet"]["probs"]
    wrong = [i for i in range(len(y_true)) if preds[i] != y_true[i]]
    for i in wrong[:5]:
        dist = {classes[j]: round(float(probs[i][j]), 3) for j in range(len(classes))}
        print(f"  {image_ids[i]}  true={classes[y_true[i]]:5} pred={classes[preds[i]]:5} "
              f"dims={dims[paths[i]]}  probs={dist}")
    print(f"\ntotal misclassified: {len(wrong)}/{len(y_true)} "
          f"({100*len(wrong)/len(y_true):.1f}%)")


if __name__ == "__main__":
    main()
