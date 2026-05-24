"""Phase C Stage B — ensemble RN50 v1-vs-v2 swap evaluation.

Answers: when the 4-model weighted ensemble swaps its ResNet50 slot from v1 to
the v2 focal+sampler winner, does ensemble mel recall improve, or does the
weighted average dilute the v2 signal?

Runs five configurations on the HAM10000 test split (1734 images) and reports
per-class recall, macro F1, balanced accuracy, and 4-model agreement rate.

Method matches src/skinlesion/ensemble.py exactly: each model's calibration
(temperature scaling) is applied before softmax, then probabilities are
weighted-averaged (normalised by the weight sum) and argmax'd. Each unique
checkpoint is run over the test set once; configs are then assembled from the
cached per-model probability matrices so the comparison is strictly fair.

Usage:
    python -m scripts.evaluate_ensemble_v2                 # all configs
    python -m scripts.evaluate_ensemble_v2 --config baseline_4v1
"""
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import torch
from sklearn.metrics import balanced_accuracy_score
from torch.utils.data import DataLoader
from tqdm import tqdm

from src.skinlesion.config import load_config
from src.skinlesion.data import SkinLesionDataset, load_split_dataframe
from src.skinlesion.ensemble import load_calibration
from src.skinlesion.metrics import summarize_classification
from src.skinlesion.models import create_model
from src.skinlesion.train import select_device

OUTPUT_DIR = Path("runs_v2/ensemble_review")

# Single-model macro-F1 (%) used to derive tuned ensemble weights. v1 figures
# are the original model-zoo numbers (CLAUDE.md); resnet50_v2 is the Phase C
# focal+sampler winner.
F1_PCT = {
    "resnet50_v1": 69.03,
    "resnet50_v2": 70.08,
    "densenet121": 68.96,
    "efficientnet_b0": 64.77,
    "mobilenetv3_small_100": 57.26,
}
# Original curated ensemble weights (configs/ham10000.yaml ensemble.weights).
ORIG_WEIGHTS = {
    "resnet50": 0.38,
    "densenet121": 0.37,
    "efficientnet_b0": 0.20,
    "mobilenetv3_small_100": 0.05,
}


@dataclass
class Member:
    model: str           # timm architecture name (also runs/ subdir for v1)
    checkpoint_dir: str   # runs/<dir> holding best.pt + calibration.json
    weight: float


def build_configs() -> dict[str, list[Member]]:
    """Define the five evaluation configurations."""
    v1 = {
        "resnet50": "runs/resnet50",
        "densenet121": "runs/densenet121",
        "efficientnet_b0": "runs/efficientnet_b0",
        "mobilenetv3_small_100": "runs/mobilenetv3_small_100",
    }

    # Config 3a — F1-naive: weights ∝ each member's single-model macro F1,
    # using resnet50_v2's F1 in the RN50 slot.
    naive_f1 = [
        ("resnet50", F1_PCT["resnet50_v2"]),
        ("densenet121", F1_PCT["densenet121"]),
        ("efficientnet_b0", F1_PCT["efficientnet_b0"]),
        ("mobilenetv3_small_100", F1_PCT["mobilenetv3_small_100"]),
    ]
    naive_total = sum(f1 for _, f1 in naive_f1)
    naive_w = {name: f1 / naive_total for name, f1 in naive_f1}

    # Config 3b — F1-relative: scale each original weight by (new_F1/old_F1),
    # then renormalise. Only RN50's F1 changes (v1 69.03 -> v2 70.08); the other
    # three keep their v1 F1 so their ratio is 1.0.
    rel_ratio = {
        "resnet50": F1_PCT["resnet50_v2"] / F1_PCT["resnet50_v1"],
        "densenet121": 1.0,
        "efficientnet_b0": 1.0,
        "mobilenetv3_small_100": 1.0,
    }
    rel_raw = {name: ORIG_WEIGHTS[name] * rel_ratio[name] for name in ORIG_WEIGHTS}
    rel_total = sum(rel_raw.values())
    rel_w = {name: w / rel_total for name, w in rel_raw.items()}

    others = ["densenet121", "efficientnet_b0", "mobilenetv3_small_100"]

    return {
        # Config 1 — sanity baseline: original 4 v1 models, curated weights.
        "baseline_4v1": [
            Member("resnet50", v1["resnet50"], ORIG_WEIGHTS["resnet50"]),
            *[Member(n, v1[n], ORIG_WEIGHTS[n]) for n in others],
        ],
        # Reference — v2 RN50 alone; argmax metrics must reproduce the committed
        # runs/resnet50_v2/test_metrics.json (doubles as correctness check).
        "single_v2rn50_reference": [
            Member("resnet50", "runs/resnet50_v2", 1.0),
        ],
        # Config 2 — conservative swap: v2 RN50, 3 v1, original weights.
        "swap_v2rn50_original_weights": [
            Member("resnet50", "runs/resnet50_v2", ORIG_WEIGHTS["resnet50"]),
            *[Member(n, v1[n], ORIG_WEIGHTS[n]) for n in others],
        ],
        # Config 3a — tuned, F1-naive weights.
        "swap_v2rn50_tuned_naive": [
            Member("resnet50", "runs/resnet50_v2", naive_w["resnet50"]),
            *[Member(n, v1[n], naive_w[n]) for n in others],
        ],
        # Config 3b — tuned, F1-relative weights.
        "swap_v2rn50_tuned_relative": [
            Member("resnet50", "runs/resnet50_v2", rel_w["resnet50"]),
            *[Member(n, v1[n], rel_w[n]) for n in others],
        ],
    }


@dataclass
class CachedModel:
    probs: np.ndarray         # (N, C) calibrated softmax probabilities
    preds: np.ndarray         # (N,) argmax class index
    temperature: float
    calibrated: bool
    standalone_macro_f1: float  # argmax macro F1 of this model alone


def run_model_inference(
    checkpoint_dir: str,
    model_name: str,
    loader: DataLoader,
    device: torch.device,
    image_size: int,
    classes: list[str],
    collect_labels: bool,
) -> tuple[CachedModel, list[int] | None]:
    """Load one checkpoint, run the test split, return calibrated probs."""
    ckpt_path = Path(checkpoint_dir) / "best.pt"
    ckpt = torch.load(ckpt_path, map_location=device, weights_only=False)
    if ckpt["config"]["data"]["image_size"] != image_size:
        raise ValueError(
            f"{checkpoint_dir}: image_size {ckpt['config']['data']['image_size']} "
            f"!= shared loader image_size {image_size}"
        )
    model = create_model(model_name, num_classes=len(classes), pretrained=False).to(device)
    model.load_state_dict(ckpt["state_dict"])
    model.eval()
    temperature, cal_meta = load_calibration(ckpt_path)

    prob_chunks: list[np.ndarray] = []
    labels_out: list[int] | None = [] if collect_labels else None
    with torch.no_grad():
        for images, labels in tqdm(loader, desc=f"{checkpoint_dir}", leave=False):
            logits = model(images.to(device))
            probs = torch.softmax(logits / temperature, dim=1).detach().cpu().numpy()
            prob_chunks.append(probs)
            if labels_out is not None:
                labels_out.extend(labels.tolist())

    del model
    if device.type == "cuda":
        torch.cuda.empty_cache()

    probs_all = np.concatenate(prob_chunks, axis=0)
    preds = probs_all.argmax(axis=1)
    return (
        CachedModel(
            probs=probs_all,
            preds=preds,
            temperature=temperature,
            calibrated=cal_meta is not None,
            standalone_macro_f1=0.0,  # filled after y_true known
        ),
        labels_out,
    )


def evaluate_config(
    name: str,
    members: list[Member],
    cache: dict[str, CachedModel],
    y_true: list[int],
    classes: list[str],
) -> dict[str, object]:
    """Weighted-average cached probabilities and summarise."""
    weights = np.array([m.weight for m in members], dtype=np.float64)
    weight_sum = weights.sum()
    stacked = np.stack([cache[m.checkpoint_dir].probs for m in members], axis=0)  # (M, N, C)
    ensemble_probs = np.tensordot(weights / weight_sum, stacked, axes=(0, 0))  # (N, C)
    y_pred = ensemble_probs.argmax(axis=1).tolist()

    metrics = summarize_classification(y_true, y_pred, classes)
    report = metrics["classification_report"]
    per_class_recall = {c: report[c]["recall"] for c in classes}
    bal_acc = balanced_accuracy_score(y_true, y_pred)

    # Agreement rate: fraction of images where all members' top-1 agree.
    member_preds = np.stack([cache[m.checkpoint_dir].preds for m in members], axis=0)  # (M, N)
    if member_preds.shape[0] == 1:
        agreement_rate = 1.0
    else:
        agreement_rate = float(np.mean(np.all(member_preds == member_preds[0], axis=0)))

    return {
        "config_name": name,
        "n_test": len(y_true),
        "members": [
            {
                "model": m.model,
                "checkpoint_dir": m.checkpoint_dir,
                "weight": round(m.weight, 6),
                "temperature": round(cache[m.checkpoint_dir].temperature, 4),
                "calibrated": cache[m.checkpoint_dir].calibrated,
            }
            for m in members
        ],
        "accuracy": metrics["accuracy"],
        "macro_f1": metrics["macro_f1"],
        "macro_recall": metrics["macro_recall"],
        "balanced_accuracy": bal_acc,
        "per_class_recall": per_class_recall,
        "mel_recall": per_class_recall["mel"],
        "bcc_recall": per_class_recall["bcc"],
        "akiec_recall": per_class_recall["akiec"],
        "agreement_rate": agreement_rate,
        "confusion_matrix": metrics["confusion_matrix"],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Phase C Stage B ensemble swap evaluation.")
    parser.add_argument("--config", default="all", help="config name or 'all'")
    parser.add_argument("--data-config", default="configs/ham10000.yaml")
    parser.add_argument("--split", default="test", choices=["train", "val", "test"])
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    configs = build_configs()
    if args.config != "all" and args.config not in configs:
        raise SystemExit(f"Unknown config '{args.config}'. Choices: {list(configs)} or 'all'.")
    selected = list(configs) if args.config == "all" else [args.config]

    data_config = load_config(args.data_config)["data"]
    classes = data_config["classes"]
    image_size = data_config["image_size"]
    device = select_device("auto")

    rows = load_split_dataframe(data_config["splits_csv"], args.split)
    dataset = SkinLesionDataset(rows, classes, image_size, split=args.split)
    loader = DataLoader(
        dataset,
        batch_size=32,
        shuffle=False,
        num_workers=data_config["num_workers"],
        pin_memory=device.type == "cuda",
    )

    # Every unique checkpoint dir across the selected configs, run once.
    unique_dirs: dict[str, str] = {}
    for cfg in selected:
        for m in configs[cfg]:
            unique_dirs[m.checkpoint_dir] = m.model

    cache: dict[str, CachedModel] = {}
    y_true: list[int] | None = None
    for checkpoint_dir, model_name in unique_dirs.items():
        cached, labels = run_model_inference(
            checkpoint_dir, model_name, loader, device, image_size, classes,
            collect_labels=(y_true is None),
        )
        if labels is not None:
            y_true = labels
        cache[checkpoint_dir] = cached

    assert y_true is not None

    # Standalone correctness check: each model's argmax macro F1 must match its
    # committed test_metrics.json (calibration is monotone in argmax).
    print("=== standalone per-model sanity (argmax macro F1 vs committed) ===")
    for checkpoint_dir, cached in cache.items():
        standalone = summarize_classification(y_true, cached.preds.tolist(), classes)
        cached.standalone_macro_f1 = standalone["macro_f1"]
        saved_path = Path(checkpoint_dir) / "test_metrics.json"
        saved_f1 = None
        if saved_path.exists():
            saved_f1 = json.loads(saved_path.read_text(encoding="utf-8")).get("macro_f1")
        delta = None if saved_f1 is None else abs(saved_f1 - standalone["macro_f1"])
        flag = "OK" if (delta is not None and delta < 1e-3) else "CHECK"
        print(
            f"  {checkpoint_dir:<28} computed={standalone['macro_f1']:.4f} "
            f"saved={saved_f1} delta={delta} [{flag}]"
        )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    print("\n=== ensemble configurations ===")
    for cfg in selected:
        result = evaluate_config(cfg, configs[cfg], cache, y_true, classes)
        out_path = OUTPUT_DIR / f"{cfg}.json"
        out_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
        print(
            f"\n[{cfg}]  mel={result['mel_recall']*100:.2f}  "
            f"bcc={result['bcc_recall']*100:.2f}  akiec={result['akiec_recall']*100:.2f}  "
            f"macroF1={result['macro_f1']*100:.2f}  balAcc={result['balanced_accuracy']*100:.2f}  "
            f"agree={result['agreement_rate']*100:.2f}  -> {out_path}"
        )


if __name__ == "__main__":
    main()
