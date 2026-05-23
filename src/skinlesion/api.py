from __future__ import annotations

import asyncio
import base64
import os
import time
import uuid
from collections import Counter
from io import BytesIO
from pathlib import Path

import numpy as np
import torch
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, UnidentifiedImageError

from src.skinlesion.cam import (
    grad_cam,
    overlay_heatmap,
    target_layer_name,
)
from src.skinlesion.config import load_config
from src.skinlesion.data import IMAGENET_MEAN, IMAGENET_STD, build_transform
from src.skinlesion.ensemble import (
    LoadedModel,
    compute_ensemble,
    load_calibration,
    load_ensemble,
    run_inference_single,
)
from src.skinlesion.models import create_model
from src.skinlesion.train import select_device


app = FastAPI(title="Skin Lesion Analysis API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MODEL_PATH = os.getenv("SKINLESION_MODEL_PATH", "runs/resnet50/best.pt")
CONFIG_PATH = os.getenv("SKINLESION_CONFIG_PATH", "configs/ham10000.yaml")
DEVICE = select_device(os.getenv("SKINLESION_DEVICE", "auto"))
MODEL = None
MODEL_NAME = None
CLASSES: list[str] = []
TRANSFORM = None
LOAD_ERROR: str | None = None
# Post-hoc calibration for the single-model /predict path. Mirrors the
# per-model fields on LoadedModel for the ensemble path. Defaults match
# "uncalibrated" so the API is backwards-compatible if no calibration
# file is present alongside the checkpoint.
SINGLE_TEMPERATURE: float = 1.0
SINGLE_CALIBRATED: bool = False
SINGLE_CALIBRATION: dict | None = None

ENSEMBLE_MODELS: dict[str, LoadedModel] = {}
ENSEMBLE_VERSION: str = "ensemble-v1"
ENSEMBLE_LOAD_ERRORS: list[str] = []

# Grad-CAM requires a backward pass through the deployed model.
# Forward/backward hooks registered on the shared model layer would
# race if two CAM requests ran concurrently, so all /predict-cam work
# is serialised through this lock. Acceptable for a single-user demo;
# document as a known limitation in CLAUDE.md.
_CAM_LOCK = asyncio.Lock()

MODEL_PERFORMANCE = [
    {"model": "MobileNetV3 Small", "test_accuracy": 0.6776, "macro_f1": 0.5726},
    {"model": "EfficientNet-B0", "test_accuracy": 0.7745, "macro_f1": 0.6477},
    {"model": "DenseNet121", "test_accuracy": 0.7964, "macro_f1": 0.6896},
    {"model": "ResNet50", "test_accuracy": 0.8022, "macro_f1": 0.6903},
]

CLASS_DISPLAY_NAMES = {
    "akiec": "Actinic keratoses and intraepithelial carcinoma",
    "bcc": "Basal cell carcinoma",
    "bkl": "Benign keratosis-like lesions",
    "df": "Dermatofibroma",
    "mel": "Melanoma",
    "nv": "Melanocytic nevi",
    "vasc": "Vascular lesions",
}


def display_model_name(model_name: str | None) -> str | None:
    if model_name == "resnet50":
        return "ResNet50"
    return model_name


@app.get("/")
def root() -> dict[str, object]:
    return {
        "project": "CNN-Based Skin Lesion Classification",
        "status": "running" if MODEL is not None else "degraded",
        "default_model": "ResNet50",
        "model_loaded": MODEL is not None,
        "endpoints": {
            "health": "/health",
            "model_info": "/model-info",
            "predict": "/predict",
            "docs": "/docs",
        },
        "disclaimer": "This result is for educational demonstration only and is not a medical diagnosis.",
    }


@app.on_event("startup")
def load_model() -> None:
    global MODEL, MODEL_NAME, CLASSES, TRANSFORM, LOAD_ERROR
    global SINGLE_TEMPERATURE, SINGLE_CALIBRATED, SINGLE_CALIBRATION
    checkpoint_path = Path(MODEL_PATH)
    if not checkpoint_path.exists():
        LOAD_ERROR = f"Checkpoint not found: {MODEL_PATH}"
        return

    try:
        checkpoint = torch.load(checkpoint_path, map_location=DEVICE)
        CLASSES = checkpoint["classes"]
        MODEL_NAME = checkpoint["model_name"]
        image_size = checkpoint["config"]["data"]["image_size"]
        TRANSFORM = build_transform(split="test", image_size=image_size)
        MODEL = create_model(
            MODEL_NAME,
            num_classes=len(CLASSES),
            pretrained=False,
        ).to(DEVICE)
        MODEL.load_state_dict(checkpoint["state_dict"])
        MODEL.eval()
        LOAD_ERROR = None
        # Pick up post-hoc calibration if it has been fit (Phase A1).
        SINGLE_TEMPERATURE, SINGLE_CALIBRATION = load_calibration(checkpoint_path)
        SINGLE_CALIBRATED = SINGLE_CALIBRATION is not None
    except Exception as exc:
        MODEL = None
        MODEL_NAME = None
        CLASSES = []
        TRANSFORM = None
        LOAD_ERROR = f"Model loading failed: {exc}"
        SINGLE_TEMPERATURE = 1.0
        SINGLE_CALIBRATED = False
        SINGLE_CALIBRATION = None


@app.on_event("startup")
def load_ensemble_models() -> None:
    global ENSEMBLE_MODELS, ENSEMBLE_VERSION, ENSEMBLE_LOAD_ERRORS
    try:
        config = load_config(CONFIG_PATH)
        ens_cfg: dict[str, object] = config.get("ensemble", {})
        ENSEMBLE_VERSION = str(ens_cfg.get("version", "ensemble-v1"))
        weights: dict[str, float] = ens_cfg.get("weights", {})
        checkpoints: dict[str, str] = ens_cfg.get("checkpoints", {})
        ENSEMBLE_MODELS, ENSEMBLE_LOAD_ERRORS = load_ensemble(checkpoints, weights, DEVICE)
    except Exception as exc:
        ENSEMBLE_LOAD_ERRORS = [f"Ensemble config error: {exc}"]


@app.get("/health")
def health() -> dict[str, object]:
    return {
        "status": "ok" if MODEL is not None else "degraded",
        "model_loaded": MODEL is not None,
        "default_model": "ResNet50",
        "model_name": display_model_name(MODEL_NAME),
        "checkpoint": MODEL_PATH,
        "device": str(DEVICE),
        "load_error": LOAD_ERROR,
    }


@app.get("/model-info")
def model_info() -> dict[str, object]:
    ensemble_calibration = [
        {
            "model": loaded.display_name,
            "calibrated": loaded.calibrated,
            "temperature": round(loaded.temperature, 4),
        }
        for loaded in ENSEMBLE_MODELS.values()
    ]
    all_ensemble_calibrated = bool(ENSEMBLE_MODELS) and all(
        m.calibrated for m in ENSEMBLE_MODELS.values()
    )
    return {
        "default_model": "ResNet50",
        "loaded_model": display_model_name(MODEL_NAME),
        "raw_loaded_model": MODEL_NAME,
        "checkpoint": MODEL_PATH,
        "classes": CLASSES,
        "class_display_names": CLASS_DISPLAY_NAMES,
        "performance": MODEL_PERFORMANCE,
        "selection_reason": "ResNet50 achieved the best initial test accuracy and macro F1-score.",
        "calibration": {
            "single": {
                "calibrated": SINGLE_CALIBRATED,
                "temperature": round(SINGLE_TEMPERATURE, 4),
                "method": (SINGLE_CALIBRATION or {}).get("method"),
                "fit_split": (SINGLE_CALIBRATION or {}).get("split"),
            },
            "ensemble": {
                "all_calibrated": all_ensemble_calibrated,
                "per_model": ensemble_calibration,
            },
        },
        "disclaimer": "This result is for educational demonstration only and is not a medical diagnosis.",
    }


@app.post("/predict")
async def predict(image: UploadFile = File(...)) -> dict[str, object]:
    if MODEL is None or TRANSFORM is None:
        raise HTTPException(
            status_code=503,
            detail={
                "error": "model_unavailable",
                "message": LOAD_ERROR or "Model checkpoint has not been loaded.",
            },
        )

    contents = await image.read()
    if not contents:
        raise HTTPException(
            status_code=400,
            detail={"error": "empty_file", "message": "Uploaded image file is empty."},
        )

    try:
        pil_image = Image.open(BytesIO(contents)).convert("RGB")
        pil_image.load()
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise HTTPException(
            status_code=400,
            detail={"error": "invalid_image", "message": "Uploaded file is not a valid image."},
        ) from exc

    try:
        tensor = TRANSFORM(pil_image).unsqueeze(0).to(DEVICE)
        with torch.no_grad():
            logits = MODEL(tensor)
            probabilities = (
                torch.softmax(logits / SINGLE_TEMPERATURE, dim=1)
                .squeeze(0)
                .detach()
                .cpu()
            )
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail={"error": "inference_failed", "message": str(exc)},
        ) from exc

    top_count = min(3, len(CLASSES))
    confidence_values, class_indices = torch.topk(probabilities, k=top_count)
    predictions = [
        {
            "label": CLASSES[index],
            "display_label": CLASS_DISPLAY_NAMES.get(CLASSES[index], CLASSES[index]),
            "confidence": float(confidence),
        }
        for confidence, index in zip(confidence_values.tolist(), class_indices.tolist())
    ]
    top_candidates = [
        {
            "class": prediction["label"],
            "display_label": prediction["display_label"],
            "confidence": prediction["confidence"],
        }
        for prediction in predictions
    ]

    return {
        "model": display_model_name(MODEL_NAME),
        "checkpoint": MODEL_PATH,
        "predicted_class": predictions[0]["label"],
        "confidence": predictions[0]["confidence"],
        "predictions": predictions,
        "top_candidates": top_candidates,
        "calibrated": SINGLE_CALIBRATED,
        "temperature": round(SINGLE_TEMPERATURE, 4),
        "disclaimer": "This result is for educational demonstration only and is not a medical diagnosis.",
    }


@app.post("/predict-ensemble")
async def predict_ensemble(image: UploadFile = File(...)) -> dict[str, object]:
    if not ENSEMBLE_MODELS:
        raise HTTPException(
            status_code=503,
            detail={
                "error": "ensemble_unavailable",
                "message": "No ensemble models loaded. " + "; ".join(ENSEMBLE_LOAD_ERRORS),
            },
        )

    contents = await image.read()
    if not contents:
        raise HTTPException(
            status_code=400,
            detail={"error": "empty_file", "message": "Uploaded image file is empty."},
        )

    try:
        pil_image = Image.open(BytesIO(contents)).convert("RGB")
        pil_image.load()
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise HTTPException(
            status_code=400,
            detail={"error": "invalid_image", "message": "Uploaded file is not a valid image."},
        ) from exc

    request_id = str(uuid.uuid4())
    t_start = time.perf_counter()

    try:
        prob_vectors: list[list[float]] = []
        model_weights: list[float] = []
        per_model: list[dict[str, object]] = []
        classes: list[str] = []

        for loaded in ENSEMBLE_MODELS.values():
            if not classes:
                classes = loaded.classes
            tensor = loaded.transform(pil_image).unsqueeze(0).to(DEVICE)
            probs, top_k = run_inference_single(loaded, tensor)
            prob_vectors.append(probs)
            model_weights.append(loaded.weight)
            per_model.append({
                "model": loaded.display_name,
                "weight": loaded.weight,
                "predicted_class": top_k[0]["label"],
                "display_label": CLASS_DISPLAY_NAMES.get(top_k[0]["label"], top_k[0]["label"]),
                "confidence": top_k[0]["confidence"],
                "calibrated": loaded.calibrated,
                "temperature": round(loaded.temperature, 4),
                "predictions": [
                    {
                        "label": p["label"],
                        "display_label": CLASS_DISPLAY_NAMES.get(p["label"], p["label"]),
                        "confidence": p["confidence"],
                    }
                    for p in top_k
                ],
            })

        ensemble_top = compute_ensemble(prob_vectors, model_weights, classes)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail={"error": "inference_failed", "message": str(exc)},
        ) from exc

    inference_time_ms = round((time.perf_counter() - t_start) * 1000, 1)

    ensemble_predictions = [
        {
            "label": p["label"],
            "display_label": CLASS_DISPLAY_NAMES.get(p["label"], p["label"]),
            "confidence": p["confidence"],
        }
        for p in ensemble_top
    ]

    top_classes = [m["predicted_class"] for m in per_model]
    models_agree = len(set(top_classes)) == 1
    agreement_note: str | None = None
    if not models_agree:
        counts = Counter(top_classes)
        parts = [
            f"{count}× {CLASS_DISPLAY_NAMES.get(cls, cls)}"
            for cls, count in counts.most_common()
        ]
        agreement_note = "Models disagree. Top predictions: " + ", ".join(parts)

    all_calibrated = bool(ENSEMBLE_MODELS) and all(
        m.calibrated for m in ENSEMBLE_MODELS.values()
    )

    return {
        "request_id": request_id,
        "inference_time_ms": inference_time_ms,
        "model_version": ENSEMBLE_VERSION,
        "ensemble": {
            "predicted_class": ensemble_predictions[0]["label"],
            "display_label": ensemble_predictions[0]["display_label"],
            "confidence": ensemble_predictions[0]["confidence"],
            "predictions": ensemble_predictions,
        },
        "model_outputs": per_model,
        "models_agree": models_agree,
        "agreement_note": agreement_note,
        "calibrated": all_calibrated,
        "disclaimer": "This result is for research-grade diagnostic-support purposes only and is not a medical diagnosis.",
    }


@app.post("/predict-cam")
async def predict_cam(image: UploadFile = File(...)) -> dict[str, object]:
    """Grad-CAM overlay for the single-model (ResNet50) path.

    Returns a base64-encoded PNG of the colour-blended heatmap overlay
    plus prediction metadata. The overlay is pre-rendered server-side so
    Flutter just decodes and displays. Ensemble-mode CAMs are out of
    scope for this phase (B3).
    """
    if MODEL is None or MODEL_NAME is None:
        raise HTTPException(
            status_code=503,
            detail={
                "error": "model_unavailable",
                "message": LOAD_ERROR or "Single-model checkpoint not loaded.",
            },
        )

    contents = await image.read()
    if not contents:
        raise HTTPException(
            status_code=400,
            detail={"error": "empty_file", "message": "Uploaded image file is empty."},
        )

    try:
        pil_image = (
            Image.open(BytesIO(contents))
            .convert("RGB")
            .resize((224, 224), Image.BILINEAR)
        )
        pil_image.load()
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise HTTPException(
            status_code=400,
            detail={"error": "invalid_image", "message": "Uploaded file is not a valid image."},
        ) from exc

    # Display copy (un-normalised, for overlay blend) and model input.
    rgb01 = np.asarray(pil_image, dtype=np.float32) / 255.0
    mean = np.asarray(IMAGENET_MEAN, dtype=np.float32)
    std = np.asarray(IMAGENET_STD, dtype=np.float32)
    normalised = (rgb01 - mean) / std
    tensor = (
        torch.from_numpy(normalised)
        .permute(2, 0, 1)
        .unsqueeze(0)
        .to(DEVICE, dtype=torch.float32)
    )

    try:
        # Serialise: forward/backward hooks on the shared model layer race.
        async with _CAM_LOCK:
            with grad_cam(MODEL, MODEL_NAME) as cam:
                heatmap, target_class, _ = cam.compute(tensor)
            # Confidence (calibrated, matching /predict).
            with torch.no_grad():
                probs = (
                    torch.softmax(MODEL(tensor) / SINGLE_TEMPERATURE, dim=1)
                    .squeeze(0)
                    .detach()
                    .cpu()
                )
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail={"error": "cam_failed", "message": str(exc)},
        ) from exc

    overlay = overlay_heatmap(rgb01, heatmap, alpha=0.45, colormap="viridis")
    overlay_u8 = np.clip(overlay * 255.0, 0, 255).astype(np.uint8)
    buf = BytesIO()
    Image.fromarray(overlay_u8).save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")

    predicted_label = CLASSES[target_class]
    return {
        "model": display_model_name(MODEL_NAME),
        "checkpoint": MODEL_PATH,
        "predicted_class": predicted_label,
        "display_label": CLASS_DISPLAY_NAMES.get(predicted_label, predicted_label),
        "confidence": float(probs[target_class]),
        "calibrated": SINGLE_CALIBRATED,
        "temperature": round(SINGLE_TEMPERATURE, 4),
        "method": "grad-cam",
        "target_layer": target_layer_name(MODEL_NAME),
        "image_size": 224,
        "heatmap_png_b64": b64,
        "disclaimer": (
            "Grad-CAM shows which image regions most influenced the model's "
            "predicted class. It is not a clinical region of interest and "
            "does not validate the prediction."
        ),
    }
