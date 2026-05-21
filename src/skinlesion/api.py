from __future__ import annotations

import os
from io import BytesIO

import torch
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image

from src.skinlesion.data import build_transform
from src.skinlesion.models import create_model
from src.skinlesion.train import select_device


app = FastAPI(title="Skin Lesion Analysis API")

MODEL_PATH = os.getenv("SKINLESION_MODEL_PATH", "runs/resnet50/best.pt")
DEVICE = select_device(os.getenv("SKINLESION_DEVICE", "auto"))
MODEL = None
MODEL_NAME = None
CLASSES: list[str] = []
TRANSFORM = None


@app.on_event("startup")
def load_model() -> None:
    global MODEL, MODEL_NAME, CLASSES, TRANSFORM
    if not os.path.exists(MODEL_PATH):
        return

    checkpoint = torch.load(MODEL_PATH, map_location=DEVICE)
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


@app.get("/health")
def health() -> dict[str, object]:
    return {
        "status": "ok",
        "model_loaded": MODEL is not None,
        "model_name": MODEL_NAME,
        "checkpoint": MODEL_PATH,
        "device": str(DEVICE),
    }


@app.get("/model-info")
def model_info() -> dict[str, object]:
    return {
        "default_model": MODEL_NAME or "resnet50",
        "checkpoint": MODEL_PATH,
        "classes": CLASSES,
        "selection_reason": "ResNet50 achieved the best initial test accuracy and macro F1-score.",
        "disclaimer": "Research prototype only; not for medical diagnosis.",
    }


@app.post("/predict")
async def predict(image: UploadFile = File(...)) -> dict[str, object]:
    if MODEL is None or TRANSFORM is None:
        raise HTTPException(status_code=503, detail="Model checkpoint has not been loaded.")

    contents = await image.read()
    try:
        pil_image = Image.open(BytesIO(contents)).convert("RGB")
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Uploaded file is not a valid image.") from exc

    tensor = TRANSFORM(pil_image).unsqueeze(0).to(DEVICE)
    with torch.no_grad():
        probabilities = torch.softmax(MODEL(tensor), dim=1).squeeze(0).detach().cpu()

    top_count = min(3, len(CLASSES))
    confidence_values, class_indices = torch.topk(probabilities, k=top_count)
    candidates = [
        {"class": CLASSES[index], "confidence": float(confidence)}
        for confidence, index in zip(confidence_values.tolist(), class_indices.tolist())
    ]

    return {
        "model": MODEL_NAME,
        "checkpoint": MODEL_PATH,
        "predicted_class": candidates[0]["class"],
        "confidence": candidates[0]["confidence"],
        "top_candidates": candidates,
        "disclaimer": "Research prototype only; not for medical diagnosis.",
    }
