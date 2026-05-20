# Runbook

This file records the practical steps for getting the first experiment running.

## 1. Current dataset state

`data/raw/ISIC-images.zip` contains image files such as `ISIC_0024306.jpg`.
`data/raw/ham10000_metadata_2026-04-02.csv` contains the current ISIC metadata
and labels.

Use one of these metadata sources:

- Preferred: use the current file
  `data/raw/ham10000_metadata_2026-04-02.csv`.
- Alternative: download metadata for ISIC collection 212 from the ISIC Archive
  collection page and save it as `data/raw/ISIC-metadata.csv`.
- Also supported: use the original Kaggle-style `HAM10000_metadata.csv` and
  save it as `data/raw/HAM10000_metadata.csv`.

The code supports label columns named `dx`, `label`, `diagnosis_3`,
`diagnosis`, or `benign_malignant`, and image id columns named `image_id`,
`isic_id`, or `name`.

## 2. Prepare splits

After metadata is present, run:

```bash
python -m src.skinlesion.prepare_ham10000 \
  --metadata data/raw/ham10000_metadata_2026-04-02.csv \
  --image-zip data/raw/ISIC-images.zip \
  --output data/processed/splits.csv
```

The script extracts the zip once into `data/processed/images/`, links labels to
image paths, and writes `data/processed/splits.csv`.

## 3. Train the first baseline

First run a quick smoke test. This checks the dataset, model construction,
CUDA, forward pass, loss, backward pass, checkpoint saving, and validation loop:

```bash
python -m src.skinlesion.train \
  --config configs/ham10000.yaml \
  --model mobilenetv3_small_100 \
  --epochs 1 \
  --limit-batches 2 \
  --no-pretrained
```

Then start with MobileNetV3 because it is lighter and faster:

```bash
python -m src.skinlesion.train \
  --config configs/ham10000.yaml \
  --model mobilenetv3_small_100
```

## 4. Evaluate

```bash
python -m src.skinlesion.evaluate \
  --config configs/ham10000.yaml \
  --model mobilenetv3_small_100 \
  --checkpoint runs/mobilenetv3_small_100/best.pt
```

Copy the final train, validation, and test accuracy into
`docs/initial_experiment_results.md`.
