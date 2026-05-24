from __future__ import annotations

from pathlib import Path

import pandas as pd
import torch
from PIL import Image
from torch.utils.data import Dataset, WeightedRandomSampler
from torchvision import transforms


IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]


class SkinLesionDataset(Dataset):
    def __init__(
        self,
        rows: pd.DataFrame,
        classes: list[str],
        image_size: int,
        split: str,
    ) -> None:
        self.rows = rows.reset_index(drop=True)
        self.classes = classes
        self.class_to_index = {name: index for index, name in enumerate(classes)}
        self.transform = build_transform(split=split, image_size=image_size)

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, int]:
        row = self.rows.iloc[index]
        image = Image.open(row["image_path"]).convert("RGB")
        label = self.class_to_index[row["label"]]
        return self.transform(image), label


def build_transform(split: str, image_size: int) -> transforms.Compose:
    if split == "train":
        return transforms.Compose(
            [
                transforms.Resize((image_size, image_size)),
                transforms.RandomHorizontalFlip(),
                transforms.RandomVerticalFlip(),
                transforms.RandomRotation(20),
                transforms.ColorJitter(brightness=0.15, contrast=0.15),
                transforms.ToTensor(),
                transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
            ]
        )

    return transforms.Compose(
        [
            transforms.Resize((image_size, image_size)),
            transforms.ToTensor(),
            transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
        ]
    )


def load_split_dataframe(splits_csv: str | Path, split: str) -> pd.DataFrame:
    dataframe = pd.read_csv(splits_csv)
    required_columns = {"image_path", "label", "split"}
    missing = required_columns.difference(dataframe.columns)
    if missing:
        raise ValueError(f"Split CSV is missing columns: {sorted(missing)}")

    rows = dataframe[dataframe["split"] == split].copy()
    if rows.empty:
        raise ValueError(f"No rows found for split '{split}' in {splits_csv}")

    rows["image_path"] = rows["image_path"].map(lambda value: str(Path(value)))
    return rows


def compute_class_weights(rows: pd.DataFrame, classes: list[str]) -> torch.Tensor:
    counts = rows["label"].value_counts().reindex(classes, fill_value=0)
    if (counts == 0).any():
        missing = counts[counts == 0].index.tolist()
        raise ValueError(f"Training split has no samples for classes: {missing}")

    total = counts.sum()
    weights = total / (len(classes) * counts)
    return torch.tensor(weights.to_numpy(dtype="float32"))

def make_balanced_sampler(rows, classes):
    """WeightedRandomSampler with weights inversely proportional to class counts.
    
    Used for the training split only — gives each batch ~equal class representation.
    """
    counts = rows["label"].value_counts().reindex(classes, fill_value=0)
    class_w = {c: (0.0 if counts[c] == 0 else 1.0 / counts[c]) for c in classes}
    sample_w = rows["label"].map(class_w).to_numpy(dtype="float32")
    return WeightedRandomSampler(
        weights=sample_w, num_samples=len(sample_w), replacement=True
    )