"""Smoke test: Grad-CAM works on all four ensemble backbones (Phase D.1).

Loads each ensemble checkpoint, resolves its architecture-aware Grad-CAM target
layer (src/skinlesion/cam.py), runs Grad-CAM on the demo image, and asserts the
heatmap is a finite, non-degenerate 224x224 map. This is the cross-architecture
counterpart to the single-model Grad-CAM that /predict-cam already serves.

Run (as a module, from the project root, so `src` is importable):
    python -m scripts.test_cam_all_models
    python -m scripts.test_cam_all_models --image docs/demo/images/easy_correct_ISIC_0024308.jpg

Exit code 0 = all backbones passed; 1 = at least one failed.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import torch
from PIL import Image

from src.skinlesion.cam import grad_cam, resolve_target_layer, target_layer_name
from src.skinlesion.config import load_config
from src.skinlesion.data import IMAGENET_MEAN, IMAGENET_STD
from src.skinlesion.models import create_model
from src.skinlesion.train import select_device

DEFAULT_IMAGE = "docs/demo/images/easy_correct_ISIC_0024308.jpg"


def preprocess(image_path: Path, device: torch.device) -> torch.Tensor:
    """ImageNet-normalised [1,3,224,224] tensor (matches the API CAM path)."""
    pil = Image.open(image_path).convert("RGB").resize((224, 224), Image.BILINEAR)
    rgb01 = np.asarray(pil, dtype=np.float32) / 255.0
    mean = np.asarray(IMAGENET_MEAN, dtype=np.float32)
    std = np.asarray(IMAGENET_STD, dtype=np.float32)
    normalised = (rgb01 - mean) / std
    return torch.from_numpy(normalised).permute(2, 0, 1).unsqueeze(0).to(device, dtype=torch.float32)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Grad-CAM smoke test for all 4 backbones.")
    p.add_argument("--config", default="configs/ham10000.yaml")
    p.add_argument("--image", default=DEFAULT_IMAGE)
    return p.parse_args()


def main() -> int:
    args = parse_args()
    image_path = Path(args.image)
    if not image_path.exists():
        print(f"ERROR: demo image not found at {image_path}", file=sys.stderr)
        return 2

    config = load_config(args.config)
    checkpoints: dict[str, str] = config["ensemble"]["checkpoints"]
    device = select_device("auto")
    tensor = preprocess(image_path, device)

    print(f"device={device}  image={image_path}  ({len(checkpoints)} models)\n")
    n_pass = n_fail = 0
    for model_name, ckpt_path in checkpoints.items():
        path = Path(ckpt_path)
        if not path.exists():
            print(f"[skip] {model_name}: checkpoint missing at {ckpt_path}")
            continue
        try:
            ck = torch.load(path, map_location=device, weights_only=False)
            arch = ck["model_name"]
            classes = ck["classes"]
            model = create_model(arch, num_classes=len(classes), pretrained=False).to(device)
            model.load_state_dict(ck["state_dict"])
            model.eval()

            layer_label = target_layer_name(model_name)
            target_mod = resolve_target_layer(model, model_name)
            with grad_cam(model, model_name) as cam:
                heatmap, target_class, target_logit = cam.compute(tensor)

            assert heatmap.shape == (224, 224), f"shape {heatmap.shape} != (224,224)"
            assert np.isfinite(heatmap).all(), "heatmap has non-finite values"
            assert float(heatmap.max()) > 0.0, "heatmap is all-zero (degenerate)"
            assert 0.0 <= float(heatmap.min()) and float(heatmap.max()) <= 1.0, "heatmap out of [0,1]"

            print(
                f"[ ok ] {model_name:24s} layer={layer_label:20s} "
                f"target={type(target_mod).__name__:12s} "
                f"pred={classes[target_class]:5s} "
                f"hmax={heatmap.max():.3f} hmean={heatmap.mean():.3f}"
            )
            n_pass += 1
        except Exception as exc:  # noqa: BLE001
            print(f"[FAIL] {model_name}: {exc}", file=sys.stderr)
            n_fail += 1

    print(f"\nSummary: pass={n_pass} fail={n_fail}")
    if n_fail:
        print("Grad-CAM FAILED on one or more backbones.", file=sys.stderr)
        return 1
    print("Grad-CAM works on all backbones.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
