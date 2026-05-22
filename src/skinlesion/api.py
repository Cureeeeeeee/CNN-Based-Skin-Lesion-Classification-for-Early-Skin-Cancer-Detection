from __future__ import annotations

import os
from io import BytesIO
from pathlib import Path

import torch
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, UnidentifiedImageError

from src.skinlesion.data import build_transform
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
DEVICE = select_device(os.getenv("SKINLESION_DEVICE", "auto"))
MODEL = None
MODEL_NAME = None
CLASSES: list[str] = []
TRANSFORM = None
LOAD_ERROR: str | None = None

MODEL_PERFORMANCE = [
    {"model": "MobileNetV3 Small", "test_accuracy": 0.6776, "macro_f1": 0.5726},
    {"model": "EfficientNet-B0", "test_accuracy": 0.7745, "macro_f1": 0.6477},
    {"model": "DenseNet121", "test_accuracy": 0.7964, "macro_f1": 0.6896},
    {"model": "ResNet50", "test_accuracy": 0.8022, "macro_f1": 0.6903},
]


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
    except Exception as exc:
        MODEL = None
        MODEL_NAME = None
        CLASSES = []
        TRANSFORM = None
        LOAD_ERROR = f"Model loading failed: {exc}"


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
    return {
        "default_model": "ResNet50",
        "loaded_model": display_model_name(MODEL_NAME),
        "raw_loaded_model": MODEL_NAME,
        "checkpoint": MODEL_PATH,
        "classes": CLASSES,
        "performance": MODEL_PERFORMANCE,
        "selection_reason": "ResNet50 achieved the best initial test accuracy and macro F1-score.",
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
            probabilities = torch.softmax(MODEL(tensor), dim=1).squeeze(0).detach().cpu()
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail={"error": "inference_failed", "message": str(exc)},
        ) from exc

    top_count = min(3, len(CLASSES))
    confidence_values, class_indices = torch.topk(probabilities, k=top_count)
    predictions = [
        {"label": CLASSES[index], "confidence": float(confidence)}
        for confidence, index in zip(confidence_values.tolist(), class_indices.tolist())
    ]
    top_candidates = [
        {"class": prediction["label"], "confidence": prediction["confidence"]}
        for prediction in predictions
    ]

    return {
        "model": display_model_name(MODEL_NAME),
        "checkpoint": MODEL_PATH,
        "predicted_class": predictions[0]["label"],
        "confidence": predictions[0]["confidence"],
        "predictions": predictions,
        "top_candidates": top_candidates,
        "disclaimer": "This result is for educational demonstration only and is not a medical diagnosis.",
    }
