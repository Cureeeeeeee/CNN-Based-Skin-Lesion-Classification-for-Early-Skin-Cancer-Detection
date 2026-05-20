from __future__ import annotations

import argparse
import random
from pathlib import Path
from zipfile import ZipFile

import pandas as pd


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prepare HAM10000 train/val/test splits.")
    parser.add_argument("--metadata", required=True, help="Path to HAM10000_metadata.csv.")
    parser.add_argument("--image-dir", action="append", default=[], help="Directory containing images.")
    parser.add_argument("--image-zip", action="append", default=[], help="Zip file containing images.")
    parser.add_argument("--extract-dir", default="data/processed/images", help="Directory for extracted zip images.")
    parser.add_argument("--output", required=True, help="Output split CSV path.")
    parser.add_argument("--seed", type=int, default=42)
    return parser.parse_args()


def find_image(image_id: str, image_dirs: list[Path]) -> Path:
    for image_dir in image_dirs:
        for suffix in [".jpg", ".jpeg", ".png"]:
            candidate = image_dir / f"{image_id}{suffix}"
            if candidate.exists():
                return candidate
    raise FileNotFoundError(f"Could not find image file for image_id={image_id}")


LABEL_MAP = {
    "actinic keratosis": "akiec",
    "actinic keratoses": "akiec",
    "akiec": "akiec",
    "basal cell carcinoma": "bcc",
    "bcc": "bcc",
    "benign keratosis": "bkl",
    "benign keratosis-like lesions": "bkl",
    "pigmented benign keratosis": "bkl",
    "bkl": "bkl",
    "dermatofibroma": "df",
    "df": "df",
    "melanoma": "mel",
    "melanoma invasive": "mel",
    "melanoma, nos": "mel",
    "mel": "mel",
    "nevus": "nv",
    "nevus, benign melanocytic": "nv",
    "melanocytic nevus": "nv",
    "nv": "nv",
    "solar or actinic keratosis": "akiec",
    "squamous cell carcinoma, nos": "akiec",
    "benign soft tissue proliferations - vascular": "vasc",
    "vascular lesion": "vasc",
    "vascular lesions": "vasc",
    "vasc": "vasc",
}


def normalize_label(value: object) -> str | None:
    if pd.isna(value):
        return None
    text = str(value).strip().lower()
    return LABEL_MAP.get(text)


def extract_image_zips(zip_paths: list[Path], extract_dir: Path) -> list[Path]:
    extracted_dirs: list[Path] = []
    extract_dir.mkdir(parents=True, exist_ok=True)

    for zip_path in zip_paths:
        destination = extract_dir / zip_path.stem
        destination.mkdir(parents=True, exist_ok=True)
        marker = destination / ".extracted"
        if not marker.exists():
            with ZipFile(zip_path) as archive:
                archive.extractall(destination)
            marker.write_text("ok", encoding="utf-8")
        extracted_dirs.append(destination)

    return extracted_dirs


def find_label_column(metadata: pd.DataFrame) -> str:
    candidates = ["dx", "label", "diagnosis_3", "diagnosis", "benign_malignant"]
    for column in candidates:
        if column in metadata.columns:
            normalized = metadata[column].map(normalize_label)
            if normalized.notna().any():
                return column
    raise ValueError(
        "Could not find a usable label column. Expected one of: "
        "dx, label, diagnosis_3, diagnosis, benign_malignant."
    )


def infer_label(row: pd.Series, label_column: str) -> str | None:
    direct_label = normalize_label(row.get(label_column))
    if direct_label is not None:
        return direct_label

    for fallback_column in ["diagnosis_3", "diagnosis_2", "diagnosis"]:
        if fallback_column in row.index:
            fallback_label = normalize_label(row.get(fallback_column))
            if fallback_label is not None:
                return fallback_label
    return None


def find_image_id_column(metadata: pd.DataFrame) -> str:
    candidates = ["image_id", "isic_id", "name"]
    for column in candidates:
        if column in metadata.columns:
            return column
    raise ValueError("Could not find image id column. Expected image_id, isic_id, or name.")


def assign_splits(metadata: pd.DataFrame, seed: int) -> pd.DataFrame:
    split_values = pd.Series("train", index=metadata.index)
    group_column = "lesion_id" if "lesion_id" in metadata.columns else "image_id"
    rng = random.Random(seed)

    group_table = (
        metadata.groupby(group_column, dropna=False)["label"]
        .agg(lambda values: values.value_counts().index[0])
        .reset_index()
    )

    for _, class_groups in group_table.groupby("label"):
        groups = class_groups[group_column].tolist()
        rng.shuffle(groups)
        total = len(groups)
        test_count = max(1, round(total * 0.15))
        validation_count = max(1, round(total * 0.15))

        test_groups = set(groups[:test_count])
        validation_groups = set(groups[test_count : test_count + validation_count])

        split_values.loc[metadata[group_column].isin(test_groups)] = "test"
        split_values.loc[metadata[group_column].isin(validation_groups)] = "val"

    output = metadata.copy()
    output["split"] = split_values
    return output


def main() -> None:
    args = parse_args()
    metadata = pd.read_csv(args.metadata)

    image_id_column = find_image_id_column(metadata)
    label_column = find_label_column(metadata)
    metadata = metadata.copy()
    metadata["image_id"] = metadata[image_id_column].astype(str)
    metadata["label"] = metadata.apply(lambda row: infer_label(row, label_column), axis=1)
    metadata = metadata[metadata["label"].notna()].copy()
    if metadata.empty:
        raise ValueError("No HAM10000-compatible labels were found in the metadata.")

    zip_dirs = extract_image_zips([Path(value) for value in args.image_zip], Path(args.extract_dir))
    image_dirs = [Path(value) for value in args.image_dir] + zip_dirs
    if not image_dirs:
        raise ValueError("Provide at least one --image-dir or --image-zip.")

    output = assign_splits(metadata, seed=args.seed)
    output["image_path"] = output["image_id"].map(lambda image_id: str(find_image(image_id, image_dirs)))

    columns = ["image_id", "label", "split", "image_path"]
    if "lesion_id" in output.columns:
        columns.insert(1, "lesion_id")

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output[columns].to_csv(output_path, index=False)

    print(output.groupby(["split", "label"]).size().unstack(fill_value=0))
    print(f"Wrote split file to {output_path}")


if __name__ == "__main__":
    main()
