"""Phase E.6 — external (cross-distribution) evaluation on ISIC 2019.

Evaluates the deployed models on the HAM10000-disjoint ISIC 2019 clean test set
(``data/processed/isic2019_clean_test.csv``, 4,353 rows, prepared in Phase
E.1-E.3) and, as a sanity gate, on the in-distribution HAM10000 test split.

Method matches src/skinlesion/ensemble.py: each model's temperature-scaling
calibration is applied before softmax, then (for the ensemble) probabilities are
weighted-averaged (normalised by the weight sum) and argmax'd. Preprocessing is
the shared test transform from src/skinlesion/data.py — identical to training/
evaluation. Each unique checkpoint is run once per test set and cached, so the
six configs are assembled fairly from the same per-model probabilities.

Configs:
  v1_ensemble                      4 v1 models, configs/ham10000.yaml weights
  v2_single_resnet50               runs/resnet50_v2        (Phase C winner)
  v1_single_resnet50               runs/resnet50_v1_backup (v1 baseline)
  v1_single_densenet121            runs/densenet121
  v1_single_efficientnet_b0        runs/efficientnet_b0
  v1_single_mobilenetv3_small_100  runs/mobilenetv3_small_100

Usage:
  python scripts/evaluate_external.py --config all --test-set isic_external
  python scripts/evaluate_external.py --config v1_ensemble --test-set ham_test
"""
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from PIL import Image
from sklearn.metrics import balanced_accuracy_score
from tqdm import tqdm

from src.skinlesion.config import load_config
from src.skinlesion.data import build_transform, load_split_dataframe
from src.skinlesion.ensemble import load_calibration
from src.skinlesion.metrics import summarize_classification
from src.skinlesion.models import create_model
from src.skinlesion.train import select_device

# Curated ensemble weights (configs/ham10000.yaml ensemble.weights).
ORIG_WEIGHTS = {
    "resnet50": 0.38,
    "densenet121": 0.37,
    "efficientnet_b0": 0.20,
    "mobilenetv3_small_100": 0.05,
}


@dataclass
class Member:
    model: str           # timm architecture name
    checkpoint_dir: str   # runs/<dir> with best.pt + calibration.json
    weight: float


def build_configs() -> dict[str, list[Member]]:
    v1 = {
        "resnet50": "runs/resnet50",
        "densenet121": "runs/densenet121",
        "efficientnet_b0": "runs/efficientnet_b0",
        "mobilenetv3_small_100": "runs/mobilenetv3_small_100",
    }
    return {
        "v1_ensemble": [Member(n, v1[n], ORIG_WEIGHTS[n]) for n in v1],
        "v2_single_resnet50": [Member("resnet50", "runs/resnet50_v2", 1.0)],
        "v1_single_resnet50": [Member("resnet50", "runs/resnet50_v1_backup", 1.0)],
        "v1_single_densenet121": [Member("densenet121", "runs/densenet121", 1.0)],
        "v1_single_efficientnet_b0": [Member("efficientnet_b0", "runs/efficientnet_b0", 1.0)],
        "v1_single_mobilenetv3_small_100": [
            Member("mobilenetv3_small_100", "runs/mobilenetv3_small_100", 1.0)
        ],
    }


@dataclass
class CachedModel:
    probs: np.ndarray         # (N, C) calibrated softmax
    preds: np.ndarray         # (N,) argmax
    temperature: float
    calibrated: bool


def load_test_frame(test_set: str, data_config: dict) -> pd.DataFrame:
    """Return a frame with image_path + label for the requested test set."""
    if test_set == "ham_test":
        return load_split_dataframe(data_config["splits_csv"], "test")
    if test_set == "isic_external":
        df = pd.read_csv("data/processed/isic2019_clean_test.csv")
        return df
    raise ValueError(f"unknown test set {test_set!r}")


def run_model(
    checkpoint_dir: str,
    model_name: str,
    image_paths: list[str],
    valid_idx: list[int],
    device: torch.device,
    image_size: int,
    classes: list[str],
    batch_size: int,
) -> CachedModel:
    """Batched inference over the already-validated image set."""
    ckpt_path = Path(checkpoint_dir) / "best.pt"
    ckpt = torch.load(ckpt_path, map_location=device, weights_only=False)
    if ckpt["config"]["data"]["image_size"] != image_size:
        raise ValueError(f"{checkpoint_dir}: image_size mismatch")
    model = create_model(model_name, num_classes=len(classes), pretrained=False).to(device)
    model.load_state_dict(ckpt["state_dict"])
    model.eval()
    temperature, cal_meta = load_calibration(ckpt_path)
    transform = build_transform(split="test", image_size=image_size)

    probs_chunks: list[np.ndarray] = []
    with torch.no_grad():
        for start in tqdm(range(0, len(valid_idx), batch_size),
                          desc=checkpoint_dir, leave=False):
            batch_idx = valid_idx[start:start + batch_size]
            tensors = []
            for i in batch_idx:
                img = Image.open(image_paths[i]).convert("RGB")
                tensors.append(transform(img))
            batch = torch.stack(tensors).to(device)
            logits = model(batch)
            p = torch.softmax(logits / temperature, dim=1).detach().cpu().numpy()
            probs_chunks.append(p)
    del model
    if device.type == "cuda":
        torch.cuda.empty_cache()
    probs = np.concatenate(probs_chunks, axis=0)
    return CachedModel(probs=probs, preds=probs.argmax(axis=1),
                       temperature=temperature, calibrated=cal_meta is not None)


def expected_calibration_error(probs: np.ndarray, y_true: list[int], n_bins: int = 15) -> float:
    conf = probs.max(axis=1)
    pred = probs.argmax(axis=1)
    correct = (pred == np.asarray(y_true)).astype(np.float64)
    bins = np.linspace(0.0, 1.0, n_bins + 1)
    ece = 0.0
    n = len(y_true)
    for lo, hi in zip(bins[:-1], bins[1:]):
        m = (conf > lo) & (conf <= hi)
        if m.sum() == 0:
            continue
        ece += (m.sum() / n) * abs(correct[m].mean() - conf[m].mean())
    return float(ece)


def evaluate_config(name, members, test_set, cache, y_true, classes,
                    n_total, n_skipped, skipped_ids) -> dict:
    weights = np.array([m.weight for m in members], dtype=np.float64)
    stacked = np.stack([cache[m.checkpoint_dir].probs for m in members], axis=0)
    ensemble_probs = np.tensordot(weights / weights.sum(), stacked, axes=(0, 0))
    y_pred = ensemble_probs.argmax(axis=1)

    metrics = summarize_classification(y_true, y_pred.tolist(), classes)
    report = metrics["classification_report"]
    per_class_recall = {c: report[c]["recall"] for c in classes}
    pred_counts = {c: int((y_pred == i).sum()) for i, c in enumerate(classes)}
    true_counts = {c: int(report[c]["support"]) for c in classes}

    return {
        "config_name": name,
        "test_set": test_set,
        "n_total": n_total,
        "n_evaluated": len(y_true),
        "n_skipped": n_skipped,
        "skipped_ids": skipped_ids,
        "members": [
            {"model": m.model, "checkpoint_dir": m.checkpoint_dir,
             "weight": round(m.weight, 6),
             "temperature": round(cache[m.checkpoint_dir].temperature, 4),
             "calibrated": cache[m.checkpoint_dir].calibrated}
            for m in members
        ],
        "accuracy": metrics["accuracy"],
        "macro_f1": metrics["macro_f1"],
        "macro_recall": metrics["macro_recall"],
        "balanced_accuracy": balanced_accuracy_score(y_true, y_pred),
        "ece": expected_calibration_error(ensemble_probs, y_true),
        "per_class_recall": per_class_recall,
        "mel_recall": per_class_recall["mel"],
        "bcc_recall": per_class_recall["bcc"],
        "akiec_recall": per_class_recall["akiec"],
        "true_label_counts": true_counts,
        "predicted_label_counts": pred_counts,
        "confusion_matrix": metrics["confusion_matrix"],
    }


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Phase E.6 external evaluation.")
    p.add_argument("--config", default="all")
    p.add_argument("--test-set", default="isic_external",
                   choices=["isic_external", "ham_test"])
    p.add_argument("--output-dir", default="runs_v2/external_eval")
    p.add_argument("--data-config", default="configs/ham10000.yaml")
    p.add_argument("--batch-size", type=int, default=64)
    return p.parse_args()


def main() -> None:
    args = parse_args()
    configs = build_configs()
    if args.config != "all" and args.config not in configs:
        raise SystemExit(f"Unknown config {args.config!r}. Choices: {list(configs)} or 'all'.")
    selected = list(configs) if args.config == "all" else [args.config]

    cfg = load_config(args.data_config)
    data_config = cfg["data"]
    classes = data_config["classes"]
    image_size = data_config["image_size"]
    class_to_idx = {c: i for i, c in enumerate(classes)}
    device = select_device("auto")
    suffix = "external" if args.test_set == "isic_external" else "ham_test"

    df = load_test_frame(args.test_set, data_config).reset_index(drop=True)
    image_paths = [str(Path(p)) for p in df["image_path"]]
    image_ids = list(df["image_id"]) if "image_id" in df.columns else list(range(len(df)))
    labels = list(df["label"])
    n_total = len(df)

    # Validate which images load; build the shared evaluated set (model-independent).
    valid_idx: list[int] = []
    skipped_ids: list[str] = []
    for i, path in enumerate(image_paths):
        try:
            with Image.open(path) as im:
                im.verify()
            valid_idx.append(i)
        except Exception as exc:  # noqa: BLE001 — log and skip per spec
            skipped_ids.append(str(image_ids[i]))
            print(f"  [skip] {image_ids[i]} ({path}): {exc}")
    n_skipped = len(skipped_ids)
    y_true = [class_to_idx[labels[i]] for i in valid_idx]
    print(f"test_set={args.test_set}  total={n_total}  evaluated={len(valid_idx)}  skipped={n_skipped}")

    # Run each unique checkpoint once over the validated set.
    unique_dirs: dict[str, str] = {}
    for c in selected:
        for m in configs[c]:
            unique_dirs[m.checkpoint_dir] = m.model
    cache: dict[str, CachedModel] = {}
    for checkpoint_dir, model_name in unique_dirs.items():
        cache[checkpoint_dir] = run_model(
            checkpoint_dir, model_name, image_paths, valid_idx,
            device, image_size, classes, args.batch_size,
        )

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"\n=== {args.test_set} results ===")
    for c in selected:
        result = evaluate_config(c, configs[c], args.test_set, cache, y_true, classes,
                                 n_total, n_skipped, skipped_ids)
        out_path = out_dir / f"{c}_{suffix}.json"
        out_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
        print(
            f"[{c:32}] mel={result['mel_recall']*100:6.2f} "
            f"bcc={result['bcc_recall']*100:6.2f} akiec={result['akiec_recall']*100:6.2f} "
            f"macroF1={result['macro_f1']*100:6.2f} balAcc={result['balanced_accuracy']*100:6.2f} "
            f"ECE={result['ece']:.4f} -> {out_path.name}"
        )


if __name__ == "__main__":
    main()
