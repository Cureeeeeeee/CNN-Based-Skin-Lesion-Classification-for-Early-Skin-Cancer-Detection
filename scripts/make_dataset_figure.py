"""Figure 1 — one representative HAM10000 test image per class (2x4 grid).

Reads data/processed/splits.csv (columns: image_id, lesion_id, label, split,
image_path), filters to the test split, and picks one deterministic image per
class via random.choice on the sorted per-class image_path list. Renders a
2x4 grid (7 classes + 1 blank cell) to docs/figures/dataset_samples.png.

Run from the repository root:
    python scripts/make_dataset_figure.py

Determinism: random.seed(14191136); classes iterated in fixed alphabetical
order so the per-class random.choice sequence is reproducible.
"""
from __future__ import annotations

import os
import random
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

SPLITS_CSV = "data/processed/splits.csv"
OUTPUT_PNG = "docs/figures/dataset_samples.png"
SEED = 14191136

# Alphabetical 7 classes.
CLASSES = ["akiec", "bcc", "bkl", "df", "mel", "nv", "vasc"]
FULL_NAMES = {
    "akiec": "Actinic Keratoses (akiec)",
    "bcc": "Basal Cell Carcinoma (bcc)",
    "bkl": "Benign Keratosis (bkl)",
    "df": "Dermatofibroma (df)",
    "mel": "Melanoma (mel)",
    "nv": "Melanocytic Nevi (nv)",
    "vasc": "Vascular Lesion (vasc)",
}


def main() -> int:
    df = pd.read_csv(SPLITS_CSV)
    test = df[df["split"] == "test"]

    present = sorted(test["label"].unique().tolist())
    assert len(present) == 7, (
        f"Expected 7 classes in the test split, found {len(present)}: {present}"
    )
    assert present == CLASSES, (
        f"Test classes {present} do not match expected {CLASSES}"
    )

    random.seed(SEED)
    picks = []  # (class, image_id, image_path)
    for cls in CLASSES:
        sub = test[test["label"] == cls]
        if len(sub) == 0:
            raise ValueError(f"Class '{cls}' has 0 images in the test split.")
        paths = sorted(sub["image_path"].tolist())
        chosen_path = random.choice(paths)
        image_id = sub.loc[sub["image_path"] == chosen_path, "image_id"].iloc[0]
        if not os.path.exists(chosen_path):
            raise FileNotFoundError(
                f"image_path for class '{cls}' does not exist on disk: {chosen_path}"
            )
        picks.append((cls, str(image_id), chosen_path))

    fig, axes = plt.subplots(2, 4, figsize=(16, 8))
    axes = axes.flatten()
    for i, (cls, image_id, path) in enumerate(picks):
        img = plt.imread(path)  # raises if the image fails to load
        ax = axes[i]
        ax.imshow(img)
        ax.set_title(FULL_NAMES[cls], fontsize=13)
        ax.axis("off")
    axes[7].axis("off")  # 8th cell blank

    plt.tight_layout()
    os.makedirs(os.path.dirname(OUTPUT_PNG), exist_ok=True)
    plt.savefig(OUTPUT_PNG, dpi=200, bbox_inches="tight")
    plt.close()

    print(f"Saved {OUTPUT_PNG}")
    print("Selected (class, image_id):")
    for cls, image_id, _ in picks:
        print(f"  ({cls!r}, {image_id!r})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
