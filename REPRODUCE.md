# Reproducing DermaSense v2.1

This document describes how to reproduce the v2.1 release end-to-end:
download released model weights, run the backend, run the Flutter web
app, and (optionally) retrain the ResNet50 v2 single-model from scratch.

## Prerequisites

- Python 3.10 or 3.11
- Node 18+ (for Flutter Web build chain)
- Flutter 3.16 or later (https://docs.flutter.dev/get-started/install)
- NVIDIA GPU with CUDA 12.x (only required for retraining; inference
  works on CPU)
- gh CLI authenticated (https://cli.github.com/) for asset download
- Approximately 1 GB free disk for the repo + model weights

## 1. Clone

```bash
git clone https://github.com/Cureeeeeeee/CNN-Based-Skin-Lesion-Classification-for-Early-Skin-Cancer-Detection.git
cd CNN-Based-Skin-Lesion-Classification-for-Early-Skin-Cancer-Detection
git checkout v2.1
```

## 2. Download released model weights (12 assets, ~318 MB)

```bash
mkdir -p runs/resnet50 runs/densenet121 runs/efficientnet_b0 runs/mobilenetv3_small_100 runs/resnet50_v1_backup runs/resnet50_v2
gh release download v2.1 --dir _release_assets

# Place each weights+calibration pair into its run directory:
mv _release_assets/resnet50__best.pt              runs/resnet50/best.pt
mv _release_assets/resnet50__calibration.json     runs/resnet50/calibration.json
mv _release_assets/densenet121__best.pt           runs/densenet121/best.pt
mv _release_assets/densenet121__calibration.json  runs/densenet121/calibration.json
mv _release_assets/efficientnet_b0__best.pt       runs/efficientnet_b0/best.pt
mv _release_assets/efficientnet_b0__calibration.json runs/efficientnet_b0/calibration.json
mv _release_assets/mobilenetv3_small_100__best.pt runs/mobilenetv3_small_100/best.pt
mv _release_assets/mobilenetv3_small_100__calibration.json runs/mobilenetv3_small_100/calibration.json
mv _release_assets/resnet50_v1_backup__best.pt    runs/resnet50_v1_backup/best.pt
mv _release_assets/resnet50_v1_backup__calibration.json runs/resnet50_v1_backup/calibration.json
mv _release_assets/resnet50_v2__best.pt           runs/resnet50_v2/best.pt
mv _release_assets/resnet50_v2__calibration.json  runs/resnet50_v2/calibration.json
rmdir _release_assets
```

Note: `resnet50__best.pt` and `resnet50_v1_backup__best.pt` are
bit-identical (same MD5) — the backup is a labelled duplicate kept for
ensemble stability.

## 3. Python environment + backend

```bash
python -m venv .venv
source .venv/bin/activate          # Linux/macOS
# .venv\Scripts\Activate.ps1       # Windows PowerShell

pip install --upgrade pip
pip install -r requirements.txt

# Run the backend
uvicorn src.skinlesion.api:app --host 0.0.0.0 --port 8126
```

The backend exposes five endpoints:
- `GET  /health`
- `POST /predict`           (single-model — ResNet50 v2)
- `POST /predict-ensemble`  (4-model weighted ensemble + disagreement)
- `POST /cam`               (Grad-CAM for the single deployed model)
- (per-model CAM is part of the ensemble payload)

## 4. Flutter web app

In a second terminal:

```bash
cd mobile_app
flutter pub get
flutter run -d chrome
```

The app expects the backend at `http://127.0.0.1:8126` by default;
this can be overridden in the Backend Connection card on the Analysis
Setup screen.

## 5. (Optional) Retrain ResNet50 v2 from scratch

Reproduces the deployed single-model `/predict` checkpoint. Requires
the HAM10000 dataset prepared at `data/processed/`.

```bash
python -m src.skinlesion.train \
    --config configs/ham10000_v2_focal_sampler.yaml \
    --model resnet50
```

Expected runtime on a single NVIDIA RTX 5090: 30–45 minutes for full
20 epochs with early stopping.

Expected output metrics (on HAM10000 test split):
- test accuracy: ~80%
- macro F1: 70.08% (± 0.5 across seeds)
- mel recall: 73.40% (± 1.0 across seeds — the headline v2 improvement)
- post-cal test ECE: 0.0248 (after running calibration fit)

## 6. (Optional) Refit calibration

```bash
python -m src.skinlesion.calibrate --model resnet50 --run-dir runs/resnet50_v2
```

Writes `runs_v2/resnet50_v2/calibration.json` with the fitted scalar
temperature and before/after ECE on validation + test splits.

## 7. Run the test suite

```bash
# Python smoke tests
python scripts/test_api_demo.py
python scripts/test_api_cam_ensemble.py
python scripts/test_cam_all_models.py

# Flutter widget test
cd mobile_app && flutter test
```

## Known limitations of this reproduction

- The 4-model ensemble continues to use **ResNet50 v1** (not v2) for
  disagreement stability. The `runs/resnet50/` weights are v1.
- Calibration is fit on the HAM10000 validation split only. ISIC 2019
  external evaluation uses the val-fitted temperature; this is by
  design (no test-set leakage) and matches the deployed configuration.
- The released weights are bit-identical to those used to produce the
  numbers in the project report.
