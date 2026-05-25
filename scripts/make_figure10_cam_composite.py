"""Figure 10 — 2x2 composite of the four ResNet50 Grad-CAM cases.

Composites the four pre-rendered ResNet50 Grad-CAM *overlay* PNGs (read as-is;
no regeneration) into a 2x2 grid, each panel annotated with case label +
true/pred/confidence/outcome. Visual register matches Figure 1
(docs/figures/dataset_samples.png).

Run from the repository root:
    python scripts/make_figure10_cam_composite.py
"""
from __future__ import annotations

import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

CAM_DIR = "docs/figures/cam_samples"
OUTPUT = "docs/figures/figure10_cam_composite.png"

# (subplot order: a=top-left, b=top-right, c=bottom-left, d=bottom-right)
PANELS = [
    ("cam_resnet50_easy_correct_ISIC_0024308_overlay.png",
     "Easy correct: nv → nv (96%)"),
    ("cam_resnet50_top3_recovery_ISIC_0024329_overlay.png",
     "Top-3 recovery: akiec → bcc (82%)"),
    ("cam_resnet50_difficult_uncertain_ISIC_0024439_overlay.png",
     "False positive: nv → mel (55%)"),
    ("cam_resnet50_weak_class_mel_ISIC_0024351_overlay.png",
     "False negative: mel → nv (66%)"),
]


def main() -> int:
    paths = [(os.path.join(CAM_DIR, fn), title) for fn, title in PANELS]
    for path, _ in paths:
        if not os.path.exists(path):
            raise FileNotFoundError(f"Source overlay not found: {path}")

    fig, axes = plt.subplots(2, 2, figsize=(12, 12))
    axes = axes.flatten()
    for ax, (path, title) in zip(axes, paths):
        img = plt.imread(path)  # raises if unreadable
        ax.imshow(img)
        ax.set_title(title, fontsize=13, fontweight="normal", loc="center")
        ax.axis("off")

    plt.tight_layout()
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    plt.savefig(OUTPUT, dpi=200, bbox_inches="tight")
    plt.close()

    print(f"Saved {OUTPUT}")
    for path, title in paths:
        # Sanitise the arrow for the Windows console; the figure keeps '→'.
        safe_title = title.replace("→", "->")
        print(f"  {safe_title}  <-  {os.path.basename(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
