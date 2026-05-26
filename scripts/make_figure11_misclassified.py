"""Figure 11 — 2x5 gallery of 10 randomly-sampled ResNet50 v2 misclassified
HAM10000 test images, labelled "Pred: X / True: Y" (no confidence).

Reads the existing per-image predictions
(docs/data/predictions_resnet50_v2_test.csv) — no inference, no CSV
regeneration. Deterministic sample (random_state=14191136). Output:
docs/figures/figure11_misclassified_examples.png

Run from the repository root:
    python scripts/make_figure11_misclassified.py
"""
from __future__ import annotations

import os
import random
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

CSV = "docs/data/predictions_resnet50_v2_test.csv"
OUTPUT = "docs/figures/figure11_misclassified_examples.png"

CLASS_FULL = {
    "akiec": "Actinic Keratoses (akiec)",
    "bcc": "Basal Cell Carcinoma (bcc)",
    "bkl": "Benign Keratosis (bkl)",
    "df": "Dermatofibroma (df)",
    "mel": "Melanoma (mel)",
    "nv": "Melanocytic Nevi (nv)",
    "vasc": "Vascular Lesion (vasc)",
}


def main() -> int:
    if not os.path.exists(CSV):
        raise FileNotFoundError(f"predictions CSV missing: {CSV}")
    df = pd.read_csv(CSV)
    errors = df[df["true_label"] != df["pred_label"]].reset_index(drop=True)
    assert len(errors) >= 50, f"unexpectedly few errors: {len(errors)}"

    random.seed(14191136)  # project convention (same seed as Figure 1)
    picks = errors.sample(n=10, random_state=14191136).reset_index(drop=True)

    fig, axes = plt.subplots(2, 5, figsize=(18, 8))
    axes = axes.flatten()
    for i, row in picks.iterrows():
        if not os.path.exists(row["image_path"]):
            raise FileNotFoundError(f"image not found: {row['image_path']}")
        img = plt.imread(row["image_path"])  # raises if unreadable
        axes[i].imshow(img)
        axes[i].set_title(
            f"Pred: {CLASS_FULL[row['pred_label']]}\n"
            f"True: {CLASS_FULL[row['true_label']]}",
            fontsize=11,
        )
        axes[i].axis("off")

    plt.tight_layout()
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    plt.savefig(OUTPUT, dpi=200, bbox_inches="tight")
    plt.close()

    print(f"Saved {OUTPUT}  (sampled 10 of {len(errors)} errors)")
    for _, row in picks.iterrows():
        print(f"  {row['image_id']}: true={row['true_label']}, pred={row['pred_label']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
