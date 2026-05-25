"""CLI for running Grad-CAM on a single image (or a batch of demo images).

This script is the B1 review surface: it produces overlay PNGs and 1x3
diagnostic grids (input | heatmap | overlay) so we can inspect what
Grad-CAM looks like on real lesion images before wiring it into the
API. The B2 step will render overlays server-side and stream them to
Flutter; nothing here is API-facing.

Usage:
    # Single image, default model (resnet50):
    python -m src.skinlesion.cam_demo \
        --image docs/demo/images/easy_correct_ISIC_0024308.jpg

    # Specific model + custom output dir:
    python -m src.skinlesion.cam_demo \
        --model densenet121 \
        --image docs/demo/images/easy_correct_ISIC_0024308.jpg \
        --output-dir docs/figures/cam_samples

    # Batch over every JPEG in docs/demo/images/ (default model):
    python -m src.skinlesion.cam_demo --all-demo
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import torch
from PIL import Image

from src.skinlesion.cam import (
    grad_cam,
    overlay_heatmap,
    render_comparison_grid,
    save_png,
    target_layer_name,
)
from src.skinlesion.config import load_config
from src.skinlesion.data import IMAGENET_MEAN, IMAGENET_STD
from src.skinlesion.models import create_model
from src.skinlesion.train import select_device

DEFAULT_DEMO_DIR = Path("docs/demo/images")
DEFAULT_OUTPUT_DIR = Path("docs/figures/cam_samples")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render Grad-CAM overlays.")
    parser.add_argument("--config", default="configs/ham10000.yaml")
    parser.add_argument(
        "--model",
        default="resnet50",
        help="Model name as used in the config (default: resnet50).",
    )
    parser.add_argument(
        "--image",
        help="Path to a single image. Mutually exclusive with --all-demo.",
    )
    parser.add_argument(
        "--all-demo",
        action="store_true",
        help=f"Iterate every JPEG under {DEFAULT_DEMO_DIR}.",
    )
    parser.add_argument(
        "--output-dir",
        default=str(DEFAULT_OUTPUT_DIR),
        help=f"Where to write PNGs (default: {DEFAULT_OUTPUT_DIR}).",
    )
    parser.add_argument(
        "--alpha",
        type=float,
        default=0.45,
        help="Heatmap blend weight at peak intensity (default: 0.45).",
    )
    parser.add_argument(
        "--colormap",
        default="viridis",
        help="Matplotlib colormap (default: viridis).",
    )
    return parser.parse_args()


def load_model(model_name: str, checkpoint_path: Path, device: torch.device):
    """Load a model + its classes from a self-describing checkpoint."""
    checkpoint = torch.load(checkpoint_path, map_location=device, weights_only=False)
    classes: list[str] = checkpoint["classes"]
    image_size: int = checkpoint["config"]["data"]["image_size"]
    model = create_model(model_name, num_classes=len(classes), pretrained=False).to(device)
    model.load_state_dict(checkpoint["state_dict"])
    model.eval()
    return model, classes, image_size


def preprocess_for_model(
    image_path: Path,
    image_size: int,
    device: torch.device,
) -> tuple[torch.Tensor, np.ndarray]:
    """Return (model_input_tensor [1,3,H,W], display_rgb [H,W,3] in [0,1])."""
    pil = Image.open(image_path).convert("RGB").resize((image_size, image_size))
    rgb01 = np.asarray(pil, dtype=np.float32) / 255.0  # [H, W, 3]
    mean = np.asarray(IMAGENET_MEAN, dtype=np.float32)
    std = np.asarray(IMAGENET_STD, dtype=np.float32)
    normalised = (rgb01 - mean) / std  # [H, W, 3]
    tensor = (
        torch.from_numpy(normalised)
        .permute(2, 0, 1)
        .unsqueeze(0)
        .to(device, dtype=torch.float32)
    )
    return tensor, rgb01


def softmax_topk(logits: torch.Tensor, classes: list[str], k: int = 3) -> list[tuple[str, float]]:
    probs = torch.softmax(logits, dim=1).squeeze(0)
    vals, idx = torch.topk(probs, k=min(k, len(classes)))
    return [(classes[i.item()], float(v.item())) for v, i in zip(vals, idx)]


def run_one(
    *,
    model,
    model_name: str,
    classes: list[str],
    image_size: int,
    image_path: Path,
    output_dir: Path,
    device: torch.device,
    alpha: float,
    colormap: str,
) -> dict:
    tensor, display = preprocess_for_model(image_path, image_size, device)

    # Forward pass (no grad) just to read the top-3 for the title.
    with torch.no_grad():
        logits_eval = model(tensor)
    top3 = softmax_topk(logits_eval, classes, k=3)

    # Grad-CAM for the predicted class.
    with grad_cam(model, model_name) as cam:
        heatmap, target_class, target_logit = cam.compute(tensor)

    predicted = classes[target_class]
    overlay = overlay_heatmap(display, heatmap, alpha=alpha, colormap=colormap)

    output_dir.mkdir(parents=True, exist_ok=True)
    stem = image_path.stem
    overlay_path = output_dir / f"cam_{model_name}_{stem}_overlay.png"
    grid_path = output_dir / f"cam_{model_name}_{stem}_grid.png"

    save_png(overlay, overlay_path)
    top3_text = " · ".join(f"{c}={p:.2f}" for c, p in top3)
    render_comparison_grid(
        display,
        heatmap,
        overlay,
        title=(
            f"{model_name} on {image_path.name}\n"
            f"predicted: {predicted} ({top3[0][1]:.2%})  |  top-3: {top3_text}\n"
            f"target layer: {target_layer_name(model_name)}"
        ),
        output_path=grid_path,
        colormap=colormap,
    )

    summary = {
        "image": image_path.name,
        "model": model_name,
        "predicted": predicted,
        "confidence": top3[0][1],
        "target_logit": target_logit,
        "top3": top3,
        "overlay": str(overlay_path),
        "grid": str(grid_path),
    }
    print(
        f"[ok ] {model_name:22s}  {image_path.name:42s}  "
        f"-> {predicted:5s} ({top3[0][1]:.2%})  grid: {grid_path}"
    )
    return summary


def main() -> None:
    args = parse_args()

    if not args.image and not args.all_demo:
        raise SystemExit("Provide --image or --all-demo.")
    if args.image and args.all_demo:
        raise SystemExit("--image and --all-demo are mutually exclusive.")

    config = load_config(args.config)
    device = select_device(config["training"]["device"])
    run_root = Path(config["output"]["run_dir"])

    checkpoint_path = run_root / args.model / "best.pt"
    if not checkpoint_path.exists():
        raise SystemExit(f"Checkpoint not found: {checkpoint_path}")

    model, classes, image_size = load_model(args.model, checkpoint_path, device)
    output_dir = Path(args.output_dir)

    if args.image:
        image_paths = [Path(args.image)]
    else:
        image_paths = sorted(DEFAULT_DEMO_DIR.glob("*.jpg")) + sorted(
            DEFAULT_DEMO_DIR.glob("*.jpeg")
        )
        if not image_paths:
            raise SystemExit(f"No JPEG images found under {DEFAULT_DEMO_DIR}.")

    for path in image_paths:
        if not path.exists():
            print(f"[skip] {path}: not found")
            continue
        run_one(
            model=model,
            model_name=args.model,
            classes=classes,
            image_size=image_size,
            image_path=path,
            output_dir=output_dir,
            device=device,
            alpha=args.alpha,
            colormap=args.colormap,
        )


if __name__ == "__main__":
    main()
