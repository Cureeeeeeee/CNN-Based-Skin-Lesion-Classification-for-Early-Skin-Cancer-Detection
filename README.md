# AI Skin Lesion Analysis

This project builds a staged AI-assisted skin lesion analysis system.

Stage 1 focuses on multiclass image classification for HAM10000 using transfer
learning CNN models. The first supported model family includes MobileNet,
ResNet, EfficientNet, and DenseNet. Later stages can add YOLO lesion
localization and diagnostic-style report generation.

## Current status

The repository currently contains the Stage 1 starter implementation:

- HAM10000 split preparation with leakage reduction by `lesion_id`
- PyTorch dataset and training pipeline
- Transfer learning model factory using `timm`
- Evaluation metrics: accuracy, precision, recall, F1-score, confusion matrix
- FastAPI prediction endpoint for future Flutter integration
- Initial experiment result template

No experiment has been run yet, so all reported results must remain marked as
pending until training is completed.

## Project structure

```text
configs/
  ham10000.yaml                 # Main experiment configuration
docs/
  initial_experiment_results.md # Report-ready initial results template
src/
  skinlesion/
    data.py                     # Dataset loading and transforms
    models.py                   # CNN model factory
    train.py                    # Training and validation loop
    evaluate.py                 # Test metrics and confusion matrix
    prepare_ham10000.py         # Metadata split generation
    api.py                      # FastAPI prediction API
```

## Environment

Python is required, preferably Python 3.10 or 3.11.

Install dependencies:

```bash
pip install -r requirements.txt
```

Install PyTorch separately before the remaining dependencies. Choose the
matching Windows/CUDA command from the official PyTorch website. This avoids
accidentally replacing a working GPU build with an older pinned package.

## Dataset preparation

Download HAM10000 images and metadata from the ISIC Archive, then arrange them
locally. A typical layout is:

```text
data/
  raw/
    HAM10000_metadata.csv
    images/
      ISIC_0024306.jpg
      ISIC_0024307.jpg
      ...
```

Create train/validation/test splits:

```bash
python -m src.skinlesion.prepare_ham10000 \
  --metadata data/raw/ISIC-metadata.csv \
  --image-zip data/raw/ISIC-images.zip \
  --output data/processed/splits.csv
```

The split target is 70% training, 15% validation, and 15% testing. The script
uses `lesion_id` as a grouping column when available to reduce duplicate-lesion
data leakage.

## Training

Train one architecture:

```bash
python -m src.skinlesion.train --config configs/ham10000.yaml --model mobilenetv3_small_100
```

Run a quick smoke test before full training:

```bash
python -m src.skinlesion.train \
  --config configs/ham10000.yaml \
  --model mobilenetv3_small_100 \
  --epochs 1 \
  --limit-batches 2 \
  --no-pretrained
```

Train all configured architectures:

```bash
python -m src.skinlesion.train --config configs/ham10000.yaml --all-models
```

Outputs are written to `runs/<model_name>/` by default.

## Evaluation

Evaluate a checkpoint on the held-out test split:

```bash
python -m src.skinlesion.evaluate \
  --config configs/ham10000.yaml \
  --model mobilenetv3_small_100 \
  --checkpoint runs/mobilenetv3_small_100/best.pt
```

The evaluation script writes metrics and a confusion matrix to the model run
folder.

## Report assets

Generate training curves, model comparison charts, confusion matrix summaries,
and the mobile architecture diagram:

```bash
python -m src.skinlesion.report_assets --runs-dir runs --output-dir docs/figures
```

Important generated figures:

- `docs/figures/training_curves.png`
- `docs/figures/model_comparison.png`
- `docs/figures/resnet50_confusion_matrix_summary.png`
- `docs/figures/densenet121_confusion_matrix_summary.png`
- `docs/figures/mobile_app_architecture.png`

## Prediction demo

Run a top-3 prediction demo with the default ResNet50 checkpoint:

```bash
python -m src.skinlesion.predict_demo \
  --checkpoint runs/resnet50/best.pt \
  --model resnet50 \
  --sample-split test \
  --sample-label vasc \
  --top-k 3 \
  --output docs/demo/prediction_demo_resnet50_vasc.json
```

## API prototype

Start the local API after a trained checkpoint exists. The default checkpoint is
`runs/resnet50/best.pt`.

```bash
uvicorn src.skinlesion.api:app --host 0.0.0.0 --port 8000
```

Prediction endpoint:

```text
POST /predict
multipart/form-data image=<file>
```

The response contains the predicted lesion class, confidence score, and top
candidate classes. This is the interface the future Flutter mobile app can call.

## Mobile prototype

The Flutter prototype is in `mobile_app/`. It supports camera/gallery image
selection, backend upload, top-3 result display, and a model comparison screen.

## Medical disclaimer

This project is for academic and research purposes only. It is not a medical
device and must not be used as a final diagnosis system.
