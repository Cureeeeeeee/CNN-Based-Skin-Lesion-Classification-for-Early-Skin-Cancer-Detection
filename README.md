# CNN-Based Skin Lesion Classification for Early Skin Cancer Detection

This repository contains a delivery-ready prototype for AI-assisted multiclass
skin lesion classification. Stage 1 compares transfer-learning CNN models on a
HAM10000 / ISIC-derived dataset and exposes the best model through a FastAPI
backend for a Flutter mobile prototype.

The project is for educational demonstration and research support only. It is
not a medical diagnosis system.

## Current Results

| Model | Test Accuracy | Macro F1 | Role |
| --- | ---: | ---: | --- |
| MobileNetV3 Small | 67.76% | 57.26% | Lightweight baseline |
| EfficientNet-B0 | 77.45% | 64.77% | Efficient baseline |
| DenseNet121 | 79.64% | 68.96% | Strong comparison baseline |
| ResNet50 | 80.22% | 69.03% | Default deployment model |

ResNet50 remains the default model because it achieved the best initial test
accuracy and macro F1-score. DenseNet121 is retained as a strong comparison
model because its performance is very close to ResNet50.

## Project Structure

```text
configs/                         Training and data configuration
docs/
  demo/                           Stable demo images and saved predictions
  figures/                        Curves, model comparison, confusion matrices
  initial_experiment_results.md   Result summary for reports
  mobile_app_architecture.md      Mobile/backend workflow diagram
  validation.md                   Latest validation notes
mobile_app/                       Flutter prototype
notebooks/                        Clean notebook for demo/submission
src/skinlesion/                   Data, training, evaluation, API, demos
```

Large local artifacts are intentionally not committed:

- `data/raw/`
- `data/processed/`
- `runs/`
- `.venv/`

## Environment

Use Python 3.10 or 3.11. Install PyTorch separately with the correct CPU/CUDA
build for your machine, then install the remaining dependencies:

```bash
pip install -r requirements.txt
```

The current local experiment environment used CUDA-enabled PyTorch on an NVIDIA
GPU. See `docs/requirements_actual.txt` for a full local package snapshot.

## Dataset Preparation

Expected local layout:

```text
data/
  raw/
    ham10000_metadata_2026-04-02.csv
    ISIC-images.zip
```

Prepare grouped train/validation/test splits:

```bash
python -m src.skinlesion.prepare_ham10000 \
  --metadata data/raw/ham10000_metadata_2026-04-02.csv \
  --image-zip data/raw/ISIC-images.zip \
  --output data/processed/splits.csv
```

The split uses `lesion_id` where available to reduce duplicate-lesion leakage.

## Notebook

Open the clean delivery notebook:

```text
notebooks/skin_lesion_delivery_demo.ipynb
```

The notebook uses relative paths and can be opened in local Jupyter or adapted
for Google Colab. It includes dataset loading, preprocessing, model setup,
metric tables, figures, confusion matrices, top-3 demo outputs, and the
ResNet50 deployment conclusion.

## Training and Evaluation

Train a model:

```bash
python -m src.skinlesion.train --config configs/ham10000.yaml --model resnet50
```

Evaluate the best checkpoint:

```bash
python -m src.skinlesion.evaluate \
  --config configs/ham10000.yaml \
  --model resnet50 \
  --checkpoint runs/resnet50/best.pt \
  --split test
```

Regenerate report assets:

```bash
python -m src.skinlesion.report_assets --runs-dir runs --output-dir docs/figures
```

Key figures:

- `docs/figures/model_comparison.png`
- `docs/figures/training_curves.png`
- `docs/figures/resnet50_confusion_matrix_summary.png`
- `docs/figures/densenet121_confusion_matrix_summary.png`
- `docs/figures/mobile_app_architecture.png`

## FastAPI Backend

The backend defaults to:

```text
runs/resnet50/best.pt
```

Start the API:

```bash
uvicorn src.skinlesion.api:app --host 0.0.0.0 --port 8000
```

Open the root endpoint:

```bash
curl http://127.0.0.1:8000/
```

Test health:

```bash
curl http://127.0.0.1:8000/health
```

Test model info:

```bash
curl http://127.0.0.1:8000/model-info
```

Open the interactive API documentation:

```text
http://127.0.0.1:8000/docs
```

Test prediction:

```bash
curl -X POST http://127.0.0.1:8000/predict \
  -F "image=@docs/demo/images/easy_correct_ISIC_0024308.jpg"
```

Or run the standard smoke-test script:

```bash
python scripts/test_api_demo.py --base-url http://127.0.0.1:8000
```

`POST /predict` returns clean JSON with:

- selected model
- predicted class
- confidence score
- top-3 predictions as `predictions`, each with `label` and `confidence`
- educational-use disclaimer

The API includes error handling for empty uploads, invalid image files, missing
checkpoints, model loading failures, and unexpected inference errors. CORS is
enabled for local Flutter Web demo development.

## Stable Demo Set

Stable demo assets are in `docs/demo/`.

Regenerate them:

```bash
python -m src.skinlesion.prepare_demo_set \
  --checkpoint runs/resnet50/best.pt \
  --model resnet50 \
  --split-csv data/processed/splits.csv \
  --output-dir docs/demo
```

The demo set includes:

- an easy correct top-1 prediction
- a top-3 recovery example
- a difficult/uncertain example
- a melanoma weak-class example

These files are intended to prevent live demo failure during a presentation.

## Flutter Prototype

The Flutter prototype is in `mobile_app/`. It is organised into four screens:

- `HomeScreen`: select or upload an image.
- `ClassificationScreen`: preview the image, choose API or mock mode, and run analysis.
- `ResultScreen`: show final top-3 predictions and confidence scores.
- `ModelComparisonScreen`: show the real CNN comparison metrics.

It supports:

- camera/gallery image selection
- selected image preview
- configurable API base URL
- FastAPI `/predict` connection
- loading and error states
- top-3 prediction display
- confidence bars
- model comparison screen
- mock prediction mode for presentation safety

Run:

```bash
cd mobile_app
flutter pub get
flutter run -d chrome
```

For Flutter Web use:

```text
http://127.0.0.1:8000
```

For Android emulator use:

```text
http://10.0.2.2:8000
```

For a real phone, use the computer's LAN IP, for example:

```text
http://192.168.1.20:8000
```

If building web from this OneDrive path with Chinese characters, use:

```bash
flutter build web --no-tree-shake-icons
```

API mode sends the selected image to `POST /predict` using multipart form data
and displays the returned ResNet50 top-3 predictions. Mock mode does not call
the backend and uses a fixed sample output for presentation safety.

## Known Limitations

- The model is trained for academic demonstration, not clinical diagnosis.
- Minority classes remain harder, especially melanoma-related confusion with
  nevus and benign keratosis.
- No Grad-CAM heatmap is included yet.
- YOLO lesion localisation is planned as a later stage.
- Flutter Android deployment requires Android SDK configuration on the host
  machine.
