# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Behavioral Guidelines

### Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing: state assumptions explicitly, present multiple interpretations rather than picking silently, and stop to ask when something is unclear.

### Simplicity First

Minimum code that solves the problem. No features beyond what was asked, no abstractions for single-use code, no "flexibility" that wasn't requested, no error handling for impossible scenarios.

### Surgical Changes

Touch only what you must. Don't improve adjacent code or refactor things that aren't broken. Match existing style. When your changes create orphaned imports/variables/functions, remove them — but don't touch pre-existing dead code unless asked.

### Goal-Driven Execution

Transform tasks into verifiable goals. For multi-step tasks, state a brief plan with explicit success criteria before starting.

---

## What This Project Is

A CNN-based skin lesion classification prototype (educational/demo only — not a medical diagnostic tool). It classifies HAM10000 dermoscopy images into 7 lesion classes using transfer-learning CNNs, exposed via a FastAPI backend and a Flutter mobile frontend.

The 7 classes: `akiec`, `bcc`, `bkl`, `df`, `mel`, `nv`, `vasc`.

## Commands

### Python Backend

```bash
# Install dependencies (PyTorch must be installed separately)
pip install -r requirements.txt

# Prepare dataset
python -m src.skinlesion.prepare_ham10000 \
  --metadata data/raw/ham10000_metadata_2026-04-02.csv \
  --image-zip data/raw/ISIC-images.zip \
  --output data/processed/splits.csv

# Train a model
python -m src.skinlesion.train --config configs/ham10000.yaml --model resnet50

# Evaluate a checkpoint
python -m src.skinlesion.evaluate \
  --config configs/ham10000.yaml --model resnet50 \
  --checkpoint runs/resnet50/best.pt --split test

# Generate report figures
python -m src.skinlesion.report_assets --runs-dir runs --output-dir docs/figures

# Start the API server (default port 8000)
uvicorn src.skinlesion.api:app --host 0.0.0.0 --port 8000

# Run API smoke tests
python scripts/test_api_demo.py --base-url http://127.0.0.1:8000

# Syntax-check all Python
python -m compileall src scripts
```

### Flutter Frontend

```bash
cd mobile_app
flutter pub get
flutter run -d chrome          # run as web app
flutter test                   # run tests
dart analyze lib test          # lint
```

## Architecture

### Training → Deployment Pipeline

```
configs/ham10000.yaml
       │
       ▼
src/skinlesion/train.py  ──saves──►  runs/<model>/best.pt
       │                                    │
       ▼                                    ▼
src/skinlesion/evaluate.py          src/skinlesion/api.py
src/skinlesion/metrics.py           (loads ResNet50 + ensemble at startup)
src/skinlesion/report_assets.py     src/skinlesion/ensemble.py
```

Checkpoints are saved as dicts containing `state_dict`, `config`, `classes`, and `model_name` so the API can reconstruct the model without a separate config file at inference time.

### FastAPI (`src/skinlesion/api.py`)

Loads ResNet50 (single-model path) and all four ensemble models at startup. Endpoints:

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/` | Health/info |
| GET | `/health` | Liveness check |
| GET | `/model-info` | Loaded model metadata |
| POST | `/predict` | Single-model (ResNet50) → top-3 predictions |
| POST | `/predict-ensemble` | All 4 models → weighted ensemble + per-model top-3 |

`/predict` response is unchanged and Flutter-parser-compatible. `/predict-ensemble` adds `request_id`, `inference_time_ms`, `model_version`, `ensemble{}`, `model_outputs[]`, `models_agree`, `agreement_note`. Ensemble weights are configured in `configs/ham10000.yaml` under `ensemble:`. CORS is enabled for all origins.

### Flutter App (`mobile_app/lib/`)

Four screens in a linear navigation flow:
1. **HomeScreen** — camera / gallery image selection
2. **ClassificationScreen** — preview, API URL config, API/mock mode toggle
3. **ResultScreen** — top-3 predictions with confidence bars
4. **ModelComparisonScreen** — accuracy/F1 table for all four CNNs

`prediction_api.dart` handles multipart upload to `/predict`. Mock mode is available as a fallback for demos when no server is running.

### Data Pipeline (`src/skinlesion/data.py`)

`SkinLesionDataset` (PyTorch `Dataset`) applies:
- **Train**: Resize 224×224, random H/V flip, rotation ±15°, color jitter, ImageNet normalization
- **Val/Test**: Resize 224×224, center crop, ImageNet normalization

Class weights are computed from split frequencies and passed to `CrossEntropyLoss` to handle class imbalance (HAM10000 is heavily `nv`-skewed).

### Model Zoo

Four backbones via `timm`, all fine-tuned on HAM10000:

| Model | Accuracy | Macro F1 |
|-------|----------|----------|
| MobileNetV3 Small | 67.76% | 57.26% |
| EfficientNet-B0 | 77.45% | 64.77% |
| DenseNet121 | 79.64% | 68.96% |
| **ResNet50** | **80.22%** | **69.03%** |

ResNet50 is the default deployed model.

## Key Constraints

- `data/raw/`, `data/processed/`, and `runs/` are gitignored — model checkpoints and datasets are not in the repo. The demo requires `runs/resnet50/best.pt` to exist locally.
- `num_workers: 0` in the config is intentional for Windows compatibility (multiprocessing issues with DataLoader on Windows).
- The project targets Windows (PowerShell commands in docs, OneDrive-compatible paths).
- `timm` model name for MobileNetV3 is `mobilenetv3_small_100` (not `mobilenet_v3_small`).
