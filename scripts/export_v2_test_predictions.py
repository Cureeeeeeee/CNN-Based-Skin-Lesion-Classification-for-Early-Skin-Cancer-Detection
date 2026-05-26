"""Export per-image ResNet50 v2 predictions on the HAM10000 test split.

Loads runs/resnet50_v2/best.pt, runs inference over the test split (same
SkinLesionDataset transform evaluate.py uses), applies calibrated temperature
scaling (T from runs/resnet50_v2/calibration.json, ~0.898), and writes a
per-image CSV: image_id, image_path, true_label, pred_label, pred_confidence.

Read-only w.r.t. runs/ and src/. Run as a module from the repo root:
    python -m scripts.export_v2_test_predictions

Sanity gate: the CSV-derived accuracy must match
runs/resnet50_v2/test_metrics.json accuracy within 0.001 (temperature scaling
is monotonic, so argmax/accuracy is identical to the metrics file).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pandas as pd
import torch
from torch.utils.data import DataLoader

from src.skinlesion.data import SkinLesionDataset, load_split_dataframe
from src.skinlesion.models import create_model
from src.skinlesion.train import select_device

CKPT = Path("runs/resnet50_v2/best.pt")
CALIB = Path("runs/resnet50_v2/calibration.json")
METRICS = Path("runs/resnet50_v2/test_metrics.json")
SPLITS = Path("data/processed/splits.csv")
OUT_CSV = Path("docs/data/predictions_resnet50_v2_test.csv")

# Buckets needed for Figure 11 (true, pred): N picks.
FIG11_BUCKETS = [("mel", "nv"), ("nv", "mel"), ("akiec", "bcc"), ("bkl", "mel")]


def main() -> int:
    if not CKPT.exists():
        raise FileNotFoundError(f"checkpoint missing: {CKPT}")
    device = select_device("auto")

    temperature = float(json.loads(CALIB.read_text(encoding="utf-8"))["temperature"])
    print(f"calibration temperature T = {temperature}")
    if abs(temperature - 0.898) > 0.005:
        raise AssertionError(f"T={temperature} differs from expected 0.898")

    ckpt = torch.load(CKPT, map_location=device, weights_only=False)
    classes = ckpt["classes"]
    model_name = ckpt["model_name"]
    image_size = ckpt["config"]["data"]["image_size"]
    model = create_model(model_name, num_classes=len(classes), pretrained=False).to(device)
    model.load_state_dict(ckpt["state_dict"])
    model.eval()

    rows = load_split_dataframe(SPLITS, "test").reset_index(drop=True)
    dataset = SkinLesionDataset(rows, classes, image_size, split="test")
    loader = DataLoader(dataset, batch_size=64, shuffle=False, num_workers=0)

    prob_chunks = []
    with torch.no_grad():
        for images, _labels in loader:
            logits = model(images.to(device))
            probs = torch.softmax(logits / temperature, dim=1).cpu()
            prob_chunks.append(probs)
    probs = torch.cat(prob_chunks)  # [N, num_classes], in dataframe order
    assert probs.shape[0] == len(rows), "row/inference count mismatch"

    pred_idx = probs.argmax(dim=1).tolist()
    pred_conf = probs.max(dim=1).values.tolist()

    out = pd.DataFrame({
        "image_id": rows["image_id"],
        "image_path": rows["image_path"],
        "true_label": rows["label"],
        "pred_label": [classes[i] for i in pred_idx],
        "pred_confidence": [round(float(c), 4) for c in pred_conf],
    })
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(OUT_CSV, index=False)

    # ── Sanity gate ──
    csv_acc = float((out["true_label"] == out["pred_label"]).mean())
    ref_acc = float(json.loads(METRICS.read_text(encoding="utf-8"))["accuracy"])
    print(f"wrote {OUT_CSV}  ({len(out)} rows)")
    print(f"CSV accuracy = {csv_acc:.6f}  |  test_metrics.json = {ref_acc:.6f}")
    if abs(csv_acc - ref_acc) > 0.001:
        raise AssertionError(
            f"accuracy mismatch: CSV {csv_acc:.6f} vs metrics {ref_acc:.6f} "
            "(>0.001) — wrong checkpoint/transform/split?"
        )

    # ── Summary ──
    n_correct = int((out["true_label"] == out["pred_label"]).sum())
    print(f"total={len(out)}  correct={n_correct}  misclassified={len(out) - n_correct}")
    print("Figure-11 bucket counts (misclassified):")
    mis = out[out["true_label"] != out["pred_label"]]
    for t, p in FIG11_BUCKETS:
        n = int(((mis["true_label"] == t) & (mis["pred_label"] == p)).sum())
        print(f"  {t} -> {p}: {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
