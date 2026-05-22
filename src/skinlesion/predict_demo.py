from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd
import torch
from PIL import Image

from src.skinlesion.data import build_transform
from src.skinlesion.models import create_model
from src.skinlesion.train import select_device


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a top-k prediction demo.")
    parser.add_argument("--checkpoint", default="runs/resnet50/best.pt")
    parser.add_argument("--model", default="resnet50")
    parser.add_argument("--image", help="Optional image path. If omitted, use one row from the split CSV.")
    parser.add_argument("--split-csv", default="data/processed/splits.csv")
    parser.add_argument("--sample-split", default="test", choices=["train", "val", "test"])
    parser.add_argument("--sample-label", help="Optional true label to sample, such as mel or bcc.")
    parser.add_argument("--top-k", type=int, default=3)
    parser.add_argument("--output", default="docs/demo/prediction_demo_resnet50.json")
    parser.add_argument("--device", default="auto")
    return parser.parse_args()


def select_sample(args: argparse.Namespace) -> tuple[Path, dict[str, object]]:
    if args.image:
        return Path(args.image), {"source": "manual", "image_path": args.image}

    rows = pd.read_csv(args.split_csv)
    rows = rows[rows["split"] == args.sample_split].copy()
    if args.sample_label:
        rows = rows[rows["label"] == args.sample_label].copy()
    if rows.empty:
        raise ValueError("No matching sample found in split CSV.")

    row = rows.iloc[0]
    metadata = {
        "source": "split_csv",
        "image_id": row.get("image_id"),
        "true_label": row.get("label"),
        "split": row.get("split"),
        "image_path": row.get("image_path"),
    }
    return Path(row["image_path"]), metadata


def predict(
    checkpoint_path: Path,
    model_name: str,
    image_path: Path,
    top_k: int,
    device_name: str,
) -> dict[str, object]:
    device = select_device(device_name)
    checkpoint = torch.load(checkpoint_path, map_location=device)
    classes = checkpoint["classes"]
    image_size = checkpoint["config"]["data"]["image_size"]

    model = create_model(model_name, num_classes=len(classes), pretrained=False).to(device)
    model.load_state_dict(checkpoint["state_dict"])
    model.eval()

    transform = build_transform(split="test", image_size=image_size)
    image = Image.open(image_path).convert("RGB")
    tensor = transform(image).unsqueeze(0).to(device)

    with torch.no_grad():
        probabilities = torch.softmax(model(tensor), dim=1).squeeze(0).detach().cpu()

    top_k = min(top_k, len(classes))
    confidence_values, class_indices = torch.topk(probabilities, k=top_k)
    candidates = [
        {
            "class": classes[index],
            "confidence": round(float(confidence), 6),
        }
        for confidence, index in zip(confidence_values.tolist(), class_indices.tolist())
    ]

    return {
        "model": model_name,
        "checkpoint": str(checkpoint_path),
        "predicted_class": candidates[0]["class"],
        "confidence": candidates[0]["confidence"],
        "top_candidates": candidates,
    }


def main() -> None:
    args = parse_args()
    image_path, sample_metadata = select_sample(args)
    result = predict(
        checkpoint_path=Path(args.checkpoint),
        model_name=args.model,
        image_path=image_path,
        top_k=args.top_k,
        device_name=args.device,
    )
    output = {"sample": sample_metadata, "prediction": result}

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as file:
        json.dump(output, file, indent=2)

    print(json.dumps(output, indent=2))
    print(f"Wrote prediction demo to {output_path}")


if __name__ == "__main__":
    main()
