from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import torch
from torch import nn

from src.skinlesion.data import build_transform
from src.skinlesion.models import create_model


@dataclass
class LoadedModel:
    name: str
    display_name: str
    model: nn.Module
    classes: list[str]
    transform: object
    weight: float


_DISPLAY_NAMES: dict[str, str] = {
    "resnet50": "ResNet50",
    "densenet121": "DenseNet121",
    "efficientnet_b0": "EfficientNet-B0",
    "mobilenetv3_small_100": "MobileNetV3 Small",
}


def load_ensemble(
    checkpoints: dict[str, str],
    weights: dict[str, float],
    device: torch.device,
) -> tuple[dict[str, LoadedModel], list[str]]:
    """Load all available ensemble checkpoints. Missing or broken ones are skipped."""
    loaded: dict[str, LoadedModel] = {}
    errors: list[str] = []
    for model_name, checkpoint_path in checkpoints.items():
        path = Path(checkpoint_path)
        if not path.exists():
            errors.append(f"{model_name}: checkpoint not found at {checkpoint_path}")
            continue
        try:
            ck = torch.load(path, map_location=device, weights_only=False)
            stored_name: str = ck["model_name"]
            classes: list[str] = ck["classes"]
            image_size: int = ck["config"]["data"]["image_size"]
            model = create_model(stored_name, num_classes=len(classes), pretrained=False).to(device)
            model.load_state_dict(ck["state_dict"])
            model.eval()
            loaded[model_name] = LoadedModel(
                name=model_name,
                display_name=_DISPLAY_NAMES.get(model_name, model_name),
                model=model,
                classes=classes,
                transform=build_transform(split="test", image_size=image_size),
                weight=weights.get(model_name, 0.0),
            )
        except Exception as exc:
            errors.append(f"{model_name}: load failed — {exc}")
    return loaded, errors


def run_inference_single(
    loaded: LoadedModel,
    image_tensor: torch.Tensor,
    top_k: int = 3,
) -> tuple[list[float], list[dict[str, object]]]:
    """Run one model. Returns (full_prob_vector, top_k_predictions)."""
    with torch.no_grad():
        probs = torch.softmax(loaded.model(image_tensor), dim=1).squeeze(0).detach().cpu()
    k = min(top_k, len(loaded.classes))
    confidences, indices = torch.topk(probs, k=k)
    top_k_list = [
        {"label": loaded.classes[idx], "confidence": conf}
        for conf, idx in zip(confidences.tolist(), indices.tolist())
    ]
    return probs.tolist(), top_k_list


def compute_ensemble(
    prob_vectors: list[list[float]],
    weights: list[float],
    classes: list[str],
    top_k: int = 3,
) -> list[dict[str, object]]:
    """Weighted average of probability vectors. Returns top_k ensemble predictions."""
    total = sum(weights)
    ensemble_probs = torch.zeros(len(classes))
    for probs, w in zip(prob_vectors, weights):
        ensemble_probs += (w / total) * torch.tensor(probs)
    k = min(top_k, len(classes))
    confidences, indices = torch.topk(ensemble_probs, k=k)
    return [
        {"label": classes[idx], "confidence": conf}
        for conf, idx in zip(confidences.tolist(), indices.tolist())
    ]
