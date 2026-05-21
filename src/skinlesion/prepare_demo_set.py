from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

import pandas as pd
import torch
from PIL import Image

from src.skinlesion.data import build_transform
from src.skinlesion.models import create_model
from src.skinlesion.train import select_device


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prepare stable demo images and top-3 prediction outputs.")
    parser.add_argument("--checkpoint", default="runs/resnet50/best.pt")
    parser.add_argument("--model", default="resnet50")
    parser.add_argument("--split-csv", default="data/processed/splits.csv")
    parser.add_argument("--output-dir", default="docs/demo")
    parser.add_argument("--device", default="auto")
    parser.add_argument("--max-samples", type=int, default=800)
    return parser.parse_args()


def load_model(checkpoint_path: Path, model_name: str, device_name: str):
    device = select_device(device_name)
    checkpoint = torch.load(checkpoint_path, map_location=device)
    classes = checkpoint["classes"]
    image_size = checkpoint["config"]["data"]["image_size"]
    model = create_model(model_name, num_classes=len(classes), pretrained=False).to(device)
    model.load_state_dict(checkpoint["state_dict"])
    model.eval()
    return model, classes, build_transform(split="test", image_size=image_size), device


def predict_image(model, transform, device, classes: list[str], image_path: Path) -> dict[str, object]:
    image = Image.open(image_path).convert("RGB")
    tensor = transform(image).unsqueeze(0).to(device)
    with torch.no_grad():
        probabilities = torch.softmax(model(tensor), dim=1).squeeze(0).detach().cpu()

    confidence_values, class_indices = torch.topk(probabilities, k=3)
    candidates = [
        {"class": classes[index], "confidence": round(float(confidence), 6)}
        for confidence, index in zip(confidence_values.tolist(), class_indices.tolist())
    ]
    return {
        "predicted_class": candidates[0]["class"],
        "confidence": candidates[0]["confidence"],
        "top_candidates": candidates,
    }


def case_priority(case_name: str) -> int:
    return {
        "easy_correct": 0,
        "top3_recovery": 1,
        "difficult_uncertain": 2,
        "weak_class_mel": 3,
    }[case_name]


def main() -> None:
    args = parse_args()
    output_dir = Path(args.output_dir)
    image_output_dir = output_dir / "images"
    image_output_dir.mkdir(parents=True, exist_ok=True)

    model, classes, transform, device = load_model(Path(args.checkpoint), args.model, args.device)
    rows = pd.read_csv(args.split_csv)
    rows = rows[rows["split"] == "test"].head(args.max_samples).copy()

    selected: dict[str, dict[str, object]] = {}
    for _, row in rows.iterrows():
        image_path = Path(row["image_path"])
        true_label = row["label"]
        prediction = predict_image(model, transform, device, classes, image_path)
        top_classes = [candidate["class"] for candidate in prediction["top_candidates"]]
        confidence = float(prediction["confidence"])
        top1_correct = prediction["predicted_class"] == true_label
        true_in_top3 = true_label in top_classes

        candidate = {
            "sample": {
                "image_id": row["image_id"],
                "true_label": true_label,
                "split": row["split"],
                "source_image_path": str(image_path),
            },
            "prediction": {
                "model": args.model,
                "checkpoint": args.checkpoint,
                **prediction,
                "top1_correct": top1_correct,
                "true_label_in_top3": true_in_top3,
            },
        }

        if "easy_correct" not in selected and top1_correct and confidence >= 0.90:
            selected["easy_correct"] = candidate
        if "top3_recovery" not in selected and not top1_correct and true_in_top3:
            selected["top3_recovery"] = candidate
        if "difficult_uncertain" not in selected and (not true_in_top3 or confidence <= 0.55):
            selected["difficult_uncertain"] = candidate
        if "weak_class_mel" not in selected and true_label == "mel":
            selected["weak_class_mel"] = candidate

        if len(selected) == 4:
            break

    manifest = []
    for case_name, candidate in sorted(selected.items(), key=lambda item: case_priority(item[0])):
        source_path = Path(candidate["sample"]["source_image_path"])
        image_name = f"{case_name}_{candidate['sample']['image_id']}{source_path.suffix.lower()}"
        image_destination = image_output_dir / image_name
        shutil.copy2(source_path, image_destination)
        candidate["sample"]["demo_image_path"] = str(image_destination)
        json_path = output_dir / f"prediction_{case_name}.json"
        with json_path.open("w", encoding="utf-8") as file:
            json.dump(candidate, file, indent=2)
        manifest.append({"case": case_name, "json": str(json_path), "image": str(image_destination)})

    manifest_path = output_dir / "manifest.json"
    with manifest_path.open("w", encoding="utf-8") as file:
        json.dump(manifest, file, indent=2)

    print(json.dumps(manifest, indent=2))
    print(f"Wrote demo manifest to {manifest_path}")


if __name__ == "__main__":
    main()
