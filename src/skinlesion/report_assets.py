from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


MODEL_LABELS = {
    "mobilenetv3_small_100": "MobileNetV3 Small",
    "efficientnet_b0": "EfficientNet-B0",
    "resnet50": "ResNet50",
    "densenet121": "DenseNet121",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate report figures from training runs.")
    parser.add_argument("--runs-dir", default="runs")
    parser.add_argument("--output-dir", default="docs/figures")
    return parser.parse_args()


def read_json(path: Path) -> object:
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def load_histories(runs_dir: Path) -> dict[str, list[dict[str, float]]]:
    histories = {}
    for model_name in MODEL_LABELS:
        history_path = runs_dir / model_name / "history.json"
        if history_path.exists():
            histories[model_name] = read_json(history_path)
    return histories


def load_metrics(runs_dir: Path) -> dict[str, dict[str, object]]:
    metrics = {}
    for model_name in MODEL_LABELS:
        metrics_path = runs_dir / model_name / "test_metrics.json"
        if metrics_path.exists():
            metrics[model_name] = read_json(metrics_path)
    return metrics


def plot_training_curves(histories: dict[str, list[dict[str, float]]], output_path: Path) -> None:
    fig, axes = plt.subplots(2, 2, figsize=(14, 9))
    axes = axes.flatten()

    panels = [
        ("train_accuracy", "Train Accuracy"),
        ("validation_accuracy", "Validation Accuracy"),
        ("validation_macro_f1", "Validation Macro F1"),
        ("validation_loss", "Validation Loss"),
    ]

    for axis, (metric_key, title) in zip(axes, panels):
        for model_name, history in histories.items():
            epochs = [row["epoch"] for row in history]
            values = [row[metric_key] for row in history]
            axis.plot(epochs, values, marker="o", linewidth=1.8, markersize=3, label=MODEL_LABELS[model_name])
        axis.set_title(title)
        axis.set_xlabel("Epoch")
        axis.grid(True, alpha=0.3)

    axes[0].set_ylabel("Accuracy")
    axes[1].set_ylabel("Accuracy")
    axes[2].set_ylabel("F1-score")
    axes[3].set_ylabel("Loss")
    axes[0].legend(loc="lower right", fontsize=8)
    fig.suptitle("Training and Validation Curves", fontsize=16, fontweight="bold")
    fig.tight_layout()
    fig.savefig(output_path, dpi=220)
    plt.close(fig)


def plot_model_comparison(metrics: dict[str, dict[str, object]], output_path: Path) -> None:
    model_names = [name for name in MODEL_LABELS if name in metrics]
    labels = [MODEL_LABELS[name] for name in model_names]
    test_accuracy = [metrics[name]["accuracy"] for name in model_names]
    macro_f1 = [metrics[name]["macro_f1"] for name in model_names]
    weighted_f1 = [metrics[name]["weighted_f1"] for name in model_names]

    x = np.arange(len(model_names))
    width = 0.25

    fig, axis = plt.subplots(figsize=(11, 6))
    bars_a = axis.bar(x - width, test_accuracy, width, label="Test Accuracy", color="#2563eb")
    bars_b = axis.bar(x, macro_f1, width, label="Macro F1", color="#16a34a")
    bars_c = axis.bar(x + width, weighted_f1, width, label="Weighted F1", color="#f97316")

    for bars in [bars_a, bars_b, bars_c]:
        for bar in bars:
            height = bar.get_height()
            axis.annotate(
                f"{height * 100:.1f}%",
                xy=(bar.get_x() + bar.get_width() / 2, height),
                xytext=(0, 4),
                textcoords="offset points",
                ha="center",
                va="bottom",
                fontsize=8,
            )

    axis.set_ylim(0, 1.0)
    axis.set_ylabel("Score")
    axis.set_title("Model Performance Comparison", fontsize=15, fontweight="bold")
    axis.set_xticks(x)
    axis.set_xticklabels(labels, rotation=12, ha="right")
    axis.grid(axis="y", alpha=0.25)
    axis.legend()
    fig.tight_layout()
    fig.savefig(output_path, dpi=220)
    plt.close(fig)


def plot_confusion_matrix(metrics: dict[str, object], model_label: str, output_path: Path) -> None:
    report = metrics["classification_report"]
    class_names = [key for key in report.keys() if key not in {"accuracy", "macro avg", "weighted avg"}]
    matrix = np.asarray(metrics["confusion_matrix"])
    normalized = matrix / np.maximum(matrix.sum(axis=1, keepdims=True), 1)

    fig, axes = plt.subplots(1, 2, figsize=(15, 6))
    for axis, values, title, fmt in [
        (axes[0], matrix, "Counts", "d"),
        (axes[1], normalized, "Row-normalized", ".2f"),
    ]:
        image = axis.imshow(values, cmap="Blues", interpolation="nearest")
        fig.colorbar(image, ax=axis, fraction=0.046, pad=0.04)
        axis.set_title(f"{model_label} Confusion Matrix ({title})")
        axis.set_xticks(np.arange(len(class_names)))
        axis.set_yticks(np.arange(len(class_names)))
        axis.set_xticklabels(class_names, rotation=45, ha="right")
        axis.set_yticklabels(class_names)
        axis.set_xlabel("Predicted label")
        axis.set_ylabel("True label")

        for row_index in range(values.shape[0]):
            for column_index in range(values.shape[1]):
                cell_value = values[row_index, column_index]
                axis.text(
                    column_index,
                    row_index,
                    format(cell_value, fmt),
                    ha="center",
                    va="center",
                    fontsize=8,
                    color="white" if cell_value > values.max() / 2 else "black",
                )

    fig.tight_layout()
    fig.savefig(output_path, dpi=220)
    plt.close(fig)


def plot_mobile_architecture(output_path: Path) -> None:
    fig, axis = plt.subplots(figsize=(13, 7))
    axis.axis("off")

    boxes = [
        ("Flutter Mobile App\nCamera / Gallery", (0.08, 0.55), "#dbeafe"),
        ("FastAPI Backend\n/predict endpoint", (0.37, 0.55), "#dcfce7"),
        ("ResNet50 Classifier\nbest.pt checkpoint", (0.66, 0.55), "#fef3c7"),
        ("Result Screen\nTop 3 + Confidence", (0.37, 0.18), "#ede9fe"),
    ]

    for text, (x, y), color in boxes:
        axis.add_patch(
            plt.Rectangle((x, y), 0.22, 0.18, facecolor=color, edgecolor="#111827", linewidth=1.5)
        )
        axis.text(x + 0.11, y + 0.09, text, ha="center", va="center", fontsize=12, fontweight="bold")

    arrows = [
        ((0.30, 0.64), (0.37, 0.64), "image upload", (0.335, 0.78)),
        ((0.59, 0.64), (0.66, 0.64), "tensor inference", (0.625, 0.78)),
        ((0.77, 0.55), (0.48, 0.36), "prediction JSON", (0.63, 0.48)),
        ((0.37, 0.27), (0.19, 0.55), "display result", (0.29, 0.39)),
    ]

    for start, end, label, label_position in arrows:
        axis.annotate("", xy=end, xytext=start, arrowprops={"arrowstyle": "->", "lw": 1.8, "color": "#111827"})
        axis.text(label_position[0], label_position[1], label, ha="center", va="center", fontsize=10)

    axis.text(
        0.5,
        0.92,
        "Mobile Skin Lesion Analysis Prototype Architecture",
        ha="center",
        va="center",
        fontsize=18,
        fontweight="bold",
    )
    axis.text(
        0.5,
        0.06,
        "Future extension: Grad-CAM heatmaps, YOLO lesion localization, and diagnostic-style report generation.",
        ha="center",
        va="center",
        fontsize=11,
        color="#374151",
    )

    fig.tight_layout()
    fig.savefig(output_path, dpi=220)
    plt.close(fig)


def main() -> None:
    args = parse_args()
    runs_dir = Path(args.runs_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    histories = load_histories(runs_dir)
    metrics = load_metrics(runs_dir)
    plot_training_curves(histories, output_dir / "training_curves.png")
    plot_model_comparison(metrics, output_dir / "model_comparison.png")
    plot_mobile_architecture(output_dir / "mobile_app_architecture.png")

    for model_name in ["resnet50", "densenet121"]:
        if model_name in metrics:
            plot_confusion_matrix(
                metrics[model_name],
                MODEL_LABELS[model_name],
                output_dir / f"{model_name}_confusion_matrix_summary.png",
            )


if __name__ == "__main__":
    main()
