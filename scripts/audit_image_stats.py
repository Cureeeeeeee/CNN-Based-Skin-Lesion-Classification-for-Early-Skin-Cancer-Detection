"""Phase E.6 preprocessing audit — compare HAM-test vs ISIC-clean-test image
statistics, to confirm the external macro-F1 drop is distribution shift and not
a preprocessing inconsistency.

For 200 random images from each set, computes (after the same 224x224 bilinear
resize used at eval time, BEFORE ImageNet normalization):
  - per-channel mean and std on the [0,1] resized image
  - original (pre-resize) width/height and aspect-ratio statistics

If HAM and ISIC per-channel means differ by <0.05 the shared ImageNet
normalization is fine; >0.1 would indicate the normalization skews one set.

Usage:
  python -m scripts.audit_image_stats --n 200 --seed 42
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image

from src.skinlesion.data import load_split_dataframe


def sample_paths(df: pd.DataFrame, n: int, seed: int) -> list[str]:
    take = df.sample(n=min(n, len(df)), random_state=seed)
    return [str(Path(p)) for p in take["image_path"]]


def collect(paths: list[str], size: int = 224) -> dict:
    means, stds, ws, hs, ars = [], [], [], [], []
    for p in paths:
        with Image.open(p) as im:
            im = im.convert("RGB")
            w, h = im.size
            ws.append(w); hs.append(h); ars.append(w / h)
            arr = np.asarray(im.resize((size, size), Image.BILINEAR),
                             dtype=np.float64) / 255.0
        means.append(arr.reshape(-1, 3).mean(axis=0))
        stds.append(arr.reshape(-1, 3).std(axis=0))
    means = np.array(means); stds = np.array(stds)
    ws = np.array(ws); hs = np.array(hs); ars = np.array(ars)
    return {
        "n": len(paths),
        "chan_mean": means.mean(axis=0),
        "chan_std": stds.mean(axis=0),
        "w": (int(ws.min()), int(ws.max()), float(ws.mean())),
        "h": (int(hs.min()), int(hs.max()), float(hs.mean())),
        "aspect": (float(ars.min()), float(ars.max()), float(ars.mean())),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=200)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--splits", default="data/processed/splits.csv")
    ap.add_argument("--isic", default="data/processed/isic2019_clean_test.csv")
    args = ap.parse_args()

    ham = load_split_dataframe(args.splits, "test")
    isic = pd.read_csv(args.isic)
    ham_stats = collect(sample_paths(ham, args.n, args.seed))
    isic_stats = collect(sample_paths(isic, args.n, args.seed))

    def fmt3(v):
        return "[" + ", ".join(f"{x:.4f}" for x in v) + "]"

    print(f"=== HAM-test vs ISIC-clean-test image stats (n={args.n} each) ===")
    print(f"{'metric':22} {'HAM':28} {'ISIC':28}")
    print(f"{'per-channel mean':22} {fmt3(ham_stats['chan_mean']):28} {fmt3(isic_stats['chan_mean']):28}")
    print(f"{'per-channel std':22} {fmt3(ham_stats['chan_std']):28} {fmt3(isic_stats['chan_std']):28}")
    delta_mean = np.abs(ham_stats["chan_mean"] - isic_stats["chan_mean"])
    delta_std = np.abs(ham_stats["chan_std"] - isic_stats["chan_std"])
    print(f"{'|mean delta|':22} {fmt3(delta_mean)}")
    print(f"{'|std delta|':22} {fmt3(delta_std)}")
    print(f"max |mean delta| = {delta_mean.max():.4f}  (>0.10 => normalization concern)")
    print()
    print(f"{'orig W (min/max/mean)':22} HAM {ham_stats['w']}   ISIC {isic_stats['w']}")
    print(f"{'orig H (min/max/mean)':22} HAM {ham_stats['h']}   ISIC {isic_stats['h']}")
    print(f"{'aspect (min/max/mean)':22} HAM {tuple(round(x,3) for x in ham_stats['aspect'])}   "
          f"ISIC {tuple(round(x,3) for x in isic_stats['aspect'])}")
    print()
    verdict = "CONSISTENT (<0.05)" if delta_mean.max() < 0.05 else (
        "MILD (<0.10)" if delta_mean.max() < 0.10 else "CONCERN (>0.10)")
    print(f"VERDICT (channel-mean gap): {verdict}")


if __name__ == "__main__":
    main()
