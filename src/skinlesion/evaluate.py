from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch
from torch.utils.data import DataLoader
from tqdm import tqdm

from src.skinlesion.config import load_config
from src.skinlesion.data import SkinLesionDataset, load_split_dataframe
from src.skinlesion.metrics import save_confusion_matrix, summarize_classification
from src.skinlesion.models import create_model
from src.skinlesion.train import select_device


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate a trained skin lesion classifier.")
    parser.add_argument("--config", default="configs/ham10000.yaml")
    parser.add_argument("--model", required=True)
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--split", default="test", choices=["train", "val", "test"])
    parser.add_argument(
        "--exp-name",
        help="Optional experiment name to disambiguate the metrics output "
        "directory; defaults to model name. Use to keep metrics next to the "
        "right checkpoint when multiple variants share an architecture, e.g., "
        "--model resnet50 --exp-name resnet50_v2_focal.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config = load_config(args.config)
    data_config = config["data"]
    training_config = config["training"]
    classes = data_config["classes"]
    device = select_device(training_config["device"])

    rows = load_split_dataframe(data_config["splits_csv"], args.split)
    dataset = SkinLesionDataset(rows, classes, data_config["image_size"], split=args.split)
    loader = DataLoader(
        dataset,
        batch_size=training_config["batch_size"],
        shuffle=False,
        num_workers=data_config["num_workers"],
        pin_memory=device.type == "cuda",
    )

    checkpoint = torch.load(args.checkpoint, map_location=device)
    model = create_model(args.model, num_classes=len(classes), pretrained=False).to(device)
    model.load_state_dict(checkpoint["state_dict"])
    model.eval()

    y_true: list[int] = []
    y_pred: list[int] = []

    with torch.no_grad():
        for images, labels in tqdm(loader):
            outputs = model(images.to(device))
            predictions = outputs.argmax(dim=1).detach().cpu().tolist()
            y_pred.extend(predictions)
            y_true.extend(labels.tolist())

    metrics = summarize_classification(y_true, y_pred, classes)
    # exp_name defaults to model_name (backward compat); set it to write metrics
    # next to a variant checkpoint instead of runs/<model_name>/.
    exp_name = args.exp_name or args.model
    run_dir = Path(config["output"]["run_dir"]) / exp_name
    run_dir.mkdir(parents=True, exist_ok=True)

    metrics_path = run_dir / f"{args.split}_metrics.json"
    with metrics_path.open("w", encoding="utf-8") as file:
        json.dump(metrics, file, indent=2)

    save_confusion_matrix(
        metrics["confusion_matrix"],
        classes,
        run_dir / f"{args.split}_confusion_matrix.png",
    )

    print(json.dumps({key: metrics[key] for key in ["accuracy", "macro_recall", "macro_f1"]}, indent=2))
    print(f"Wrote metrics to {metrics_path}")


if __name__ == "__main__":
    main()
