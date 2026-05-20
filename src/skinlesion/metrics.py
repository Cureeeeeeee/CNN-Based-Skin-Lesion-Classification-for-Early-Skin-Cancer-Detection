from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)


def summarize_classification(
    y_true: list[int],
    y_pred: list[int],
    class_names: list[str],
) -> dict[str, object]:
    labels = list(range(len(class_names)))
    return {
        "accuracy": accuracy_score(y_true, y_pred),
        "macro_precision": precision_score(y_true, y_pred, labels=labels, average="macro", zero_division=0),
        "macro_recall": recall_score(y_true, y_pred, labels=labels, average="macro", zero_division=0),
        "macro_f1": f1_score(y_true, y_pred, labels=labels, average="macro", zero_division=0),
        "weighted_f1": f1_score(y_true, y_pred, labels=labels, average="weighted", zero_division=0),
        "classification_report": classification_report(
            y_true,
            y_pred,
            labels=labels,
            target_names=class_names,
            zero_division=0,
            output_dict=True,
        ),
        "confusion_matrix": confusion_matrix(y_true, y_pred, labels=labels).tolist(),
    }


def save_confusion_matrix(
    matrix: list[list[int]],
    class_names: list[str],
    output_path: str | Path,
) -> None:
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    values = np.asarray(matrix)
    fig, axis = plt.subplots(figsize=(8, 7))
    image = axis.imshow(values, interpolation="nearest", cmap="Blues")
    fig.colorbar(image, ax=axis)
    axis.set(
        xticks=np.arange(len(class_names)),
        yticks=np.arange(len(class_names)),
        xticklabels=class_names,
        yticklabels=class_names,
        ylabel="True label",
        xlabel="Predicted label",
    )
    plt.setp(axis.get_xticklabels(), rotation=45, ha="right", rotation_mode="anchor")

    for row_index in range(values.shape[0]):
        for column_index in range(values.shape[1]):
            axis.text(
                column_index,
                row_index,
                format(values[row_index, column_index], "d"),
                ha="center",
                va="center",
                color="white" if values[row_index, column_index] > values.max() / 2 else "black",
            )

    fig.tight_layout()
    fig.savefig(output_path, dpi=200)
    plt.close(fig)
