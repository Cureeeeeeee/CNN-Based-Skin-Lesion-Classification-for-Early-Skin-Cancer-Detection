"""Generate the 2-panel ResNet50 v2 confusion-matrix summary figure
(counts | per-class recall %), matching the visual style of the existing v1
summaries by REUSING report_assets.plot_confusion_matrix.

Data source: runs/resnet50_v2/test_metrics.json (precomputed confusion matrix
+ classification report). NO model inference is run — this only reads the JSON
and renders. Output: docs/figures/resnet50_v2_confusion_matrix_summary.png
(the v1 file docs/figures/resnet50_confusion_matrix_summary.png is untouched).

Run as a module from the repository root (so `src` is importable):
    python -m scripts.make_v2_confusion_figure
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # lock headless backend before report_assets imports pyplot
import numpy as np

from src.skinlesion.report_assets import plot_confusion_matrix

METRICS = Path("runs/resnet50_v2/test_metrics.json")
OUTPUT = Path("docs/figures/resnet50_v2_confusion_matrix_summary.png")

# Expected v2 per-class recall (%) for the post-render sanity gate.
EXPECTED = {
    "akiec": 69.2, "bcc": 82.4, "bkl": 65.8, "df": 72.0,
    "mel": 73.4, "nv": 79.6, "vasc": 92.6,
}
TOL = 0.5  # percentage points


def main() -> int:
    if not METRICS.exists():
        raise FileNotFoundError(f"Missing {METRICS} — cannot build v2 figure.")
    metrics = json.loads(METRICS.read_text(encoding="utf-8"))
    if "confusion_matrix" not in metrics or "classification_report" not in metrics:
        raise KeyError(
            f"{METRICS} lacks 'confusion_matrix'/'classification_report'; "
            f"keys present: {list(metrics.keys())}"
        )

    cm = np.asarray(metrics["confusion_matrix"])
    report = metrics["classification_report"]
    classes = [k for k in report.keys() if k not in {"accuracy", "macro avg", "weighted avg"}]
    if cm.shape != (len(classes), len(classes)):
        raise ValueError(f"Confusion matrix shape {cm.shape} != {len(classes)} classes.")

    recalls = cm.diagonal() / np.maximum(cm.sum(axis=1), 1)
    computed = {c: round(float(r) * 100, 1) for c, r in zip(classes, recalls)}

    # Sanity gate against expected v2 values.
    mismatches = [
        f"{c}: got {computed[c]}% expected {EXPECTED[c]}%"
        for c in EXPECTED
        if c not in computed or abs(computed[c] - EXPECTED[c]) > TOL
    ]
    if mismatches:
        raise AssertionError(
            "Rendered per-class recall does not match expected v2 values "
            f"(tol {TOL}pp): " + "; ".join(mismatches)
        )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    plot_confusion_matrix(metrics, "ResNet50 v2", OUTPUT)

    print(f"Saved {OUTPUT}")
    print("Per-class recall (computed from confusion_matrix):")
    for c in classes:
        print(f"  {c:5s} {computed[c]:.1f}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())
