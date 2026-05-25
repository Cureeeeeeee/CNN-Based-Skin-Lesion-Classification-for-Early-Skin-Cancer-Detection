# CNN-Based Skin Lesion Classification for Early Skin Cancer Detection

This repository contains a delivery-ready prototype for AI-assisted multiclass
skin lesion classification. Stage 1 compares transfer-learning CNN models on a
HAM10000 / ISIC-derived dataset and exposes the best model through a FastAPI
backend for a Flutter mobile prototype.

The project is for educational demonstration and research support only. It is
not a medical diagnosis system.

## Quick Start (Demo)

The demo runs the FastAPI backend with **CPU-only** inference on any modern
machine — no GPU required. The single-model `/predict` endpoint serves the
Phase C v2 ResNet50 (focal + balanced sampler) winner.

**Prerequisites**
- Python 3.11+ (the only hard requirement for the backend).
- ~2 GB free RAM during inference; ~250 MB disk for the six checkpoints.
- Flutter SDK *only if* you also want to run the mobile UI (optional).
- The trained checkpoints are not in the repo — `run_demo` fetches them from the
  GitHub Release (see [`docs/release_v2.0.md`](docs/release_v2.0.md)).

**One-command setup + launch**

```bash
# macOS / Linux
bash scripts/run_demo.sh
```
```powershell
# Windows
powershell -ExecutionPolicy Bypass -File scripts\run_demo.ps1
```

The script creates `.venv`, installs CPU PyTorch + pinned deps
(`requirements-lock.txt`), downloads + SHA256-verifies the checkpoints
(`scripts/download_checkpoints.py` against `runs_v2/release_manifest.json`), and
starts the API at **http://127.0.0.1:8126**.

**Time estimates:** deps install 2–4 min (first run) · checkpoint download ~5 min
(~250 MB, first run only) · API startup ~5 sec · each prediction is effectively
instant on CPU.

**Verify it's up**
```bash
curl http://127.0.0.1:8126/model-info     # should report resnet50_version=v2-focal-sampler
python scripts/test_api_demo.py --base-url http://127.0.0.1:8126
```

**Expected demo behaviour:** `/predict` returns calibrated top-3 predictions
from the v2 single model (in-distribution HAM10000 melanoma recall **73.40%**,
temperature T=0.898). `/predict-ensemble` runs the 4-model v1 ensemble.

**Mobile UI (optional):** in `mobile_app/`, run `flutter pub get` then
`flutter run -d chrome`, and point the in-app API URL at
`http://127.0.0.1:8126`. See [`mobile_app/README.md`](mobile_app/README.md).

**Troubleshooting**
- *`/model-info` says model not loaded / `status: degraded`* → the checkpoints
  are missing. Run `python scripts/download_checkpoints.py` and confirm
  `runs/resnet50_v2/best.pt` exists.
- *Checkpoint download fails with a placeholder-URL error* → the maintainer must
  set the Release URL first (see `scripts/download_checkpoints.py` header and
  [`docs/release_checklist.md`](docs/release_checklist.md)). Use
  `--verify-only` to check files already on disk.
- *Predictions look uncalibrated (`calibrated: false`)* → `calibration.json` is
  missing next to the checkpoint; re-run the download script.
- *Want to roll back to v1 ResNet50* → set
  `production.resnet50_checkpoint: resnet50` in `configs/ham10000.yaml` and
  restart (see `docs/validation.md`).

> **Important:** external-dataset validation shows melanoma recall drops to ~37%
> on out-of-distribution ISIC 2019 images — the in-distribution number does not
> generalise. This is an educational prototype, **not** a medical device. See
> [`docs/phase_e_external_validation.md`](docs/phase_e_external_validation.md).

## Current Results

| Model | Test Accuracy | Macro F1 | Role |
| --- | ---: | ---: | --- |
| MobileNetV3 Small | 67.76% | 57.26% | Lightweight baseline |
| EfficientNet-B0 | 77.45% | 64.77% | Efficient baseline |
| DenseNet121 | 79.64% | 68.96% | Strong comparison baseline |
| ResNet50 | 80.22% | 69.03% | Default deployment model |

ResNet50 remains the default single-model backend because it achieved the best
test accuracy and macro F1-score. DenseNet121 is retained as a strong comparison
model because its performance is very close to ResNet50, and it sits inside the
4-model weighted ensemble alongside EfficientNet-B0 and MobileNetV3 Small. All
four models have post-hoc temperature calibration fit on the validation split
and verified on the held-out test split (see `docs/calibration_report.md`).

## Project Structure

```text
configs/                         Training and data configuration
docs/
  demo/                           Stable demo images and saved predictions
  figures/                        Curves, model comparison, confusion matrices
  initial_experiment_results.md   Result summary for reports
  mobile_app_architecture.md      Mobile/backend workflow diagram
  presentation_demo_runbook.md    Stable presentation demo steps
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

Or run the standard smoke-test script (covers `/predict`, `/predict-ensemble`,
and `/predict-cam`):

```bash
python scripts/test_api_demo.py --base-url http://127.0.0.1:8000
```

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/` | Project info + endpoint list |
| GET | `/health` | Liveness check |
| GET | `/model-info` | Loaded model metadata + per-model calibration block |
| POST | `/predict` | Single-model ResNet50 → top-3 + `calibrated`/`temperature` |
| POST | `/predict-ensemble` | All 4 models → weighted ensemble + per-model breakdown + `models_agree` + `agreement_note` |
| POST | `/predict-cam` | Single-model Grad-CAM overlay (base64 PNG, 224×224) for the predicted class |

`POST /predict` returns JSON with: selected model, predicted class, confidence,
top-3 predictions (each with `label`, `display_label`, `confidence`), a
`calibrated` flag, the applied `temperature`, and an educational-use disclaimer.

`POST /predict-ensemble` additionally returns `request_id`, `inference_time_ms`,
`model_version`, an `ensemble` block (predicted class + top-3), a `model_outputs`
list (one entry per model with its weight, prediction, calibrated/temperature,
and top-3), `models_agree` and `agreement_note`. The top-level `calibrated`
flag is true only if every loaded model has a calibration file.

`POST /predict-cam` runs Grad-CAM (Selvaraju et al. 2017) on the deployed
ResNet50, returning a pre-rendered viridis overlay as base64 PNG along with
predicted class, confidence (calibrated), `target_layer`, and `method`. See
`docs/cam_design.md` for the offline samples and the explicit list of what
Grad-CAM is not (it is not a clinical region-of-interest annotation).

Both calibration and Grad-CAM are backwards-compatible: if a model has no
`runs/<m>/calibration.json` next to its checkpoint, that model runs
uncalibrated and `calibrated` is `false` in the response. `/predict-cam`
requires the single-model checkpoint to be loaded.

The API includes error handling for empty uploads, invalid image files, missing
checkpoints, model loading failures, and unexpected inference errors. CORS is
enabled for local Flutter Web demo development.

## Stable Demo Set

Stable demo assets are in `docs/demo/`.

For a step-by-step live demonstration plan, use:

```text
docs/presentation_demo_runbook.md
```

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

The Flutter prototype is in `mobile_app/`. It is organised as a five-screen
clinical-style diagnostic-support interface:

- **HomeScreen** — system identity + scope + image source (camera / gallery).
- **ClassificationScreen** (Analysis Setup role) — image-quality guidance,
  Single Model / 4-Model Ensemble toggle, collapsible backend connection card,
  mock-mode switch, run analysis.
- **ResultScreen** — unified screen for both single and ensemble results.
  Shared chrome: metadata strip, risk hero with class-discriminative colouring,
  image card, top-3 differential, metadata footer, disclaimer card. Ensemble
  mode adds a disagreement banner (when models disagree) and a per-model
  breakdown (with each model's weight, calibrated temperature, and top-3).
  Single-model mode adds a lazy **Attention** toggle on the image card that
  fetches a Grad-CAM overlay from the backend.
- **ModelComparisonScreen** (Model Performance) — per-model accuracy / macro F1
  / ensemble weight table plus per-class recall (low-recall cells flagged) plus
  a known-limitations status card sourced from `runs/<m>/test_metrics.json`.
- **SafetyAboutScreen** — system identity, intended use, not-intended-for,
  dataset description, per-model fitted temperatures, and a Grad-CAM
  description card. Reachable from the app-bar info icon on every screen.

Visual register: institutional navy (`#0F4C81`) + teal accent (`#0E7490`),
hairline-bordered cards instead of shadows, persistent disclaimer ribbon at
the bottom of every prediction-bearing screen, risk-sensitive colour states
(lower / indeterminate / requires-evaluation). Non-diagnostic wording
throughout — "Requires Clinical Evaluation", "temperature-calibrated
model-estimated confidence on the validation set", "not a clinical region of
interest".

Key capabilities:

- camera/gallery image selection with a quality-guidance card
- Single-model (ResNet50) **or** 4-model weighted ensemble analysis
- post-hoc temperature-calibrated confidence (calibration auto-detected from
  the backend response; UI hedge text adapts)
- on-demand Grad-CAM "Attention" overlay (single-model only, lazy fetch +
  cache)
- disagreement banner when ensemble models disagree
- mock mode for offline demos (no backend required; Attention toggle hidden)
- loading + error + empty states for every async operation

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

- The model is trained for academic demonstration and is not cleared for
  clinical use under any regulatory framework.
- **Melanoma recall is 54–59% across all four baseline (v1) models** (54.8%
  ResNet50, 58.5% DenseNet121, 57.4% EfficientNet-B0, 56.9% MobileNetV3 Small)
  on the HAM10000 test split. Roughly 4 in 10 melanoma cases are misclassified.
  The v2 ResNet50 (focal loss + balanced sampler) lifts mel recall to **73.4%**
  and is available as a configurable production checkpoint
  (`configs/ham10000.yaml` → `production.resnet50_checkpoint`); the figures
  above remain the baseline the ensemble still uses. Improving recall further
  is the highest-priority remaining work and is surfaced honestly in the Model
  Performance limitations card in the Flutter UI.
- HAM10000 is dominated by Fitzpatrick I–III skin types and dermoscopy
  images. Performance on darker skin tones, phone-camera images, or other
  populations is uncharacterised.
- Calibration is fit on HAM10000 val and verified on HAM10000 test. Phase E.6
  showed it does not transfer to ISIC 2019 — single-model ECE rises 5-9x
  out-of-distribution (see `docs/phase_e_external_validation.md`). Confidence
  is untrustworthy off-distribution.
- Grad-CAM is available only for the single-model (ResNet50) path; per-model
  Grad-CAM for the ensemble breakdown is not yet implemented.
- External validation performed on a HAM-disjoint subset of ISIC 2019 (4,353
  images); melanoma recall falls from in-distribution 73.40% to external
  37.09% — see `docs/phase_e_external_validation.md`. The strong
  in-distribution number does not generalise; this is the central caveat for
  clinical use.
- Docker design documented in `docs/docker_design.md` but not built for v2.0 —
  the MacBook demo target runs faster on native Python without Rosetta amd64
  emulation. The backend runs via local `uvicorn` (see `scripts/run_demo.sh` /
  `.ps1`); the Flutter Web bundle ships separately.
- Test coverage is limited (1 Dart widget test, 1 Python smoke test); broader
  widget and integration tests are not in place.
- Flutter Android deployment requires Android SDK configuration on the host
  machine.
- **Non-commercial use only.** The training data (HAM10000, CC BY-NC 4.0) makes
  the trained checkpoints derivative works bound by the same NonCommercial
  terms — this project may be used for academic / research / educational
  purposes but not for any commercial product without renegotiating the dataset
  licenses. See [License & Citations](#license--citations).

## License & Citations

This is an educational prototype, not a medical device, and is restricted to
**non-commercial use**.

- **Code license:** MIT license committed as `LICENSE` in repo root (Copyright
  (c) 2026 Jiahao Liu). The MIT license governs the code only; CC BY-NC
  propagates to the trained weights via HAM10000.
- **Datasets:** **HAM10000** (training) and **ISIC 2019** (planned external
  validation) are both **CC BY-NC 4.0** (Attribution–NonCommercial). The model
  weights are derivative works of this data, so the NonCommercial restriction
  propagates to them and to the project as a whole.
- **Dependencies:** all third-party libraries are permissive (BSD / MIT /
  Apache-2.0 / PSF-based); no GPL/AGPL/LGPL is present.

**Required dataset citation (HAM10000):**

> Tschandl P., Rosendahl C. & Kittler H. The HAM10000 dataset, a large
> collection of multi-source dermatoscopic images of common pigmented skin
> lesions. *Scientific Data* **5**, 180161 (2018). doi:10.1038/sdata.2018.161

Full license terms, all dataset citations (including ISIC 2019 / BCN_20000 /
MSK), per-dependency licenses with verification URLs, distribution rules, and a
BibTeX citation template are in **[`docs/licenses.md`](docs/licenses.md)**.
