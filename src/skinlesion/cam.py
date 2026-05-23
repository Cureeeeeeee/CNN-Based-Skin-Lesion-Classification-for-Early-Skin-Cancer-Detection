"""Grad-CAM (Selvaraju et al. 2017) for the skin-lesion CNNs.

Computes a class-discriminative localisation map by:
  1. Forward pass through the network.
  2. Backward pass: gradients of the target class logit w.r.t. the
     activations of a chosen "target" convolutional layer.
  3. Channel-wise weights via global-average-pool of the gradients.
  4. Weighted sum of the activation maps -> ReLU -> per-image normalise.
  5. Bilinear upsample to input image resolution.

The result is a 2D map in [0, 1] over the input pixel grid. Higher
values mean the model attended more to that region when forming the
prediction for the target class.

Grad-CAM is *not* a clinical region-of-interest annotation: it shows
where the model looked, not where pathology is located. The Phase B
result-screen card and Safety/About copy state this explicitly.
"""
from __future__ import annotations

from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import torch
import torch.nn.functional as F
from matplotlib import colormaps
from PIL import Image
from torch import nn


# ── Per-architecture target layers ────────────────────────────────────────────
#
# Selvaraju et al. recommend hooking the deepest convolutional layer that
# retains spatial resolution. For a 224x224 input, all four backbones we
# use produce a 7x7 feature map at this layer (32x downsample).


def resolve_target_layer(model: nn.Module, model_name: str) -> nn.Module:
    """Return the module to hook for a given timm backbone."""
    if model_name == "resnet50":
        return model.layer4
    if model_name == "densenet121":
        return model.features.denseblock4
    if model_name in ("efficientnet_b0", "mobilenetv3_small_100"):
        return model.blocks[-1]
    raise ValueError(
        f"No Grad-CAM target layer registered for model '{model_name}'. "
        "Add it to resolve_target_layer() in src/skinlesion/cam.py."
    )


def target_layer_name(model_name: str) -> str:
    """Human-readable target-layer label for telemetry / responses."""
    return {
        "resnet50": "layer4",
        "densenet121": "features.denseblock4",
        "efficientnet_b0": "blocks[-1]",
        "mobilenetv3_small_100": "blocks[-1]",
    }.get(model_name, "unknown")


# ── Grad-CAM core ─────────────────────────────────────────────────────────────


class GradCAM:
    """Stateful Grad-CAM with explicit hook lifecycle.

    Use as a context manager so the forward/backward hooks are removed
    even if the inference path raises. Calling the same instance twice
    is safe; the hooks are re-registered each enter.
    """

    def __init__(self, model: nn.Module, target_layer: nn.Module) -> None:
        self.model = model
        self.target_layer = target_layer
        self._activations: torch.Tensor | None = None
        self._gradients: torch.Tensor | None = None
        self._handles: list = []

    # ── Hook lifecycle ──────────────────────────────────────────────────
    def __enter__(self) -> "GradCAM":
        self._handles.append(
            self.target_layer.register_forward_hook(self._save_activation)
        )
        self._handles.append(
            self.target_layer.register_full_backward_hook(self._save_gradient)
        )
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        for h in self._handles:
            h.remove()
        self._handles = []
        self._activations = None
        self._gradients = None

    def _save_activation(
        self, _module: nn.Module, _inputs: tuple, output: torch.Tensor
    ) -> None:
        self._activations = output.detach()

    def _save_gradient(
        self, _module: nn.Module, _grad_in: tuple, grad_out: tuple
    ) -> None:
        # grad_out is a tuple of length 1 for a module returning a single tensor.
        self._gradients = grad_out[0].detach()

    # ── Compute ─────────────────────────────────────────────────────────
    def compute(
        self,
        image_tensor: torch.Tensor,
        target_class: int | None = None,
    ) -> tuple[np.ndarray, int, float]:
        """Run Grad-CAM for a single image.

        Args:
          image_tensor: shape [1, C, H, W] on the same device as the model.
          target_class: class index to explain. If None, uses argmax(logits).

        Returns:
          heatmap: numpy array, shape [H, W] in [0, 1].
          target_class: the integer class actually explained.
          target_logit: the logit value for the target class (for telemetry).
        """
        if image_tensor.dim() != 4 or image_tensor.shape[0] != 1:
            raise ValueError(
                f"Grad-CAM expects [1, C, H, W], got {tuple(image_tensor.shape)}"
            )

        was_training = self.model.training
        self.model.eval()
        self.model.zero_grad(set_to_none=True)

        # Enable grad only for this forward (model params don't need grads,
        # but the input must propagate gradients to the target layer).
        image_tensor = image_tensor.detach().requires_grad_(False)
        with torch.enable_grad():
            logits = self.model(image_tensor)
            if target_class is None:
                target_class = int(logits.argmax(dim=1).item())
            target_logit = logits[0, target_class]
            target_logit.backward()

        if self._activations is None or self._gradients is None:
            raise RuntimeError(
                "Grad-CAM hooks did not capture activations/gradients. "
                "Check that the target layer is on the forward path."
            )

        activations = self._activations  # [1, C, h, w]
        gradients = self._gradients      # [1, C, h, w]

        # Channel-importance weights: GAP over spatial dims.
        weights = gradients.mean(dim=(2, 3), keepdim=True)  # [1, C, 1, 1]
        cam = (weights * activations).sum(dim=1, keepdim=True)  # [1, 1, h, w]
        cam = F.relu(cam)

        # Upsample to input resolution.
        cam = F.interpolate(
            cam,
            size=image_tensor.shape[-2:],
            mode="bilinear",
            align_corners=False,
        )  # [1, 1, H, W]

        # Per-image min-max normalisation to [0, 1].
        cam = cam.squeeze(0).squeeze(0)  # [H, W]
        cam_min = cam.min()
        cam_max = cam.max()
        if (cam_max - cam_min).item() < 1e-8:
            # Flat heatmap (degenerate): return zeros.
            cam = torch.zeros_like(cam)
        else:
            cam = (cam - cam_min) / (cam_max - cam_min)

        if was_training:
            self.model.train()

        return cam.cpu().numpy(), target_class, float(target_logit.item())


@contextmanager
def grad_cam(model: nn.Module, model_name: str) -> Iterator[GradCAM]:
    """Convenience: GradCAM + automatic target-layer lookup."""
    target = resolve_target_layer(model, model_name)
    cam = GradCAM(model, target)
    with cam:
        yield cam


# ── Rendering ────────────────────────────────────────────────────────────────


def overlay_heatmap(
    image_rgb: np.ndarray,
    heatmap: np.ndarray,
    *,
    alpha: float = 0.45,
    colormap: str = "viridis",
) -> np.ndarray:
    """Blend a heatmap onto an RGB image.

    Args:
      image_rgb: [H, W, 3] float in [0, 1].
      heatmap:   [H, W] float in [0, 1].
      alpha:     blend weight applied where heatmap is hottest. The blend
                 is heatmap-weighted so cold regions show the original
                 image largely unaltered.
      colormap:  matplotlib colormap name (default: perceptually uniform).

    Returns:
      [H, W, 3] float in [0, 1] suitable for PIL save.
    """
    if image_rgb.shape[:2] != heatmap.shape:
        raise ValueError(
            f"Shape mismatch: image {image_rgb.shape[:2]} vs heatmap {heatmap.shape}"
        )
    cmap = colormaps.get_cmap(colormap)
    coloured = cmap(np.clip(heatmap, 0.0, 1.0))[..., :3]  # [H, W, 3]
    # Heatmap-weighted blend: cold pixels keep their original colour.
    weight = (alpha * heatmap)[..., None]  # [H, W, 1]
    blended = (1.0 - weight) * image_rgb + weight * coloured
    return np.clip(blended, 0.0, 1.0)


def render_comparison_grid(
    image_rgb: np.ndarray,
    heatmap: np.ndarray,
    overlay: np.ndarray,
    title: str,
    output_path: str | Path,
    *,
    colormap: str = "viridis",
) -> Path:
    """Save a 1x3 grid: original | heatmap | overlay. For B1 review only."""
    fig, axes = plt.subplots(1, 3, figsize=(10.5, 3.8))
    axes[0].imshow(image_rgb)
    axes[0].set_title("input", fontsize=10)
    axes[1].imshow(heatmap, cmap=colormap, vmin=0, vmax=1)
    axes[1].set_title("Grad-CAM heatmap", fontsize=10)
    axes[2].imshow(overlay)
    axes[2].set_title("overlay", fontsize=10)
    for ax in axes:
        ax.set_xticks([])
        ax.set_yticks([])
    fig.suptitle(title, fontsize=11)
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=150)
    plt.close(fig)
    return out


def save_png(rgb_in_unit_range: np.ndarray, output_path: str | Path) -> Path:
    """Save an RGB float array in [0, 1] as a PNG."""
    arr = np.clip(rgb_in_unit_range * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(arr).save(output_path)
    return Path(output_path)
