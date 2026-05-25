# DermaSense

CNN-based skin lesion classification for early skin cancer detection — a research-grade diagnostic-support prototype combining a 4-model CNN ensemble, post-hoc probability calibration, Grad-CAM saliency explainability, and a clinical-style Flutter mobile/web interface.

> **Status:** v2.1 — UI Redesign · see [Releases](https://github.com/Cureeeeeeee/CNN-Based-Skin-Lesion-Classification-for-Early-Skin-Cancer-Detection/releases/tag/v2.1)
> **License:** Code MIT · Model weights CC BY-NC 4.0 (see [LICENSE](LICENSE), [LICENSE-MODELS.md](LICENSE-MODELS.md))
> **Not a clinical device.** Research and educational use only.

## Overview

DermaSense classifies dermatoscopic images into seven HAM10000 skin lesion categories and presents calibrated confidence values, a Top-3 differential, and on-demand Grad-CAM attention overlays through a Flutter interface. The system uses four ImageNet-pretrained backbones (ResNet50, DenseNet121, EfficientNet-B0, MobileNetV3 Small), a temperature-scaled calibration layer, a weighted ensemble with explicit disagreement detection, and a FastAPI backend exposing five HTTP endpoints.

## Highlights

- **4-model weighted ensemble** with cross-model disagreement detection surfaced as a first-class UI signal (indeterminate risk state + banner).
- **Post-hoc temperature scaling** per model, fit on the HAM10000 validation split and verified on the test split; deployed ResNet50 v2 reaches post-calibration test ECE 0.0248.
- **Grad-CAM saliency** for single-model and per-model ensemble views; lazy fetch with overlay caching in the app.
- **ResNet50 v2 retraining** (focal loss + class-balanced sampler) raises melanoma recall from 54.8% to 73.40% on the HAM10000 test split.
- **External validation** on a 4,353-image HAM-disjoint subset of ISIC 2019, with the resulting in-distribution / out-of-distribution gap surfaced as a Known Limitations panel inside the app.
- **Clinical-style Flutter UI** built on a centralised design-token system (institutional navy + teal, risk-state accents, hairline borders, no shadows).

## Performance summary (HAM10000 test split)

| Model | Test Acc | Macro F1 | mel recall |
|---|---|---|---|
| MobileNetV3 Small | 67.76% | 57.26% | — |
| EfficientNet-B0 | 77.45% | 64.77% | — |
| DenseNet121 | 79.64% | 68.96% | — |
| **ResNet50 (v1, baseline)** | **80.22%** | **69.03%** | 54.8% |
| **ResNet50 v2 (focal + sampler, deployed single)** | — | **70.08%** | **73.40%** |
| **4-model weighted ensemble** | — | **74.10%** | — |

External validation on ISIC 2019 (HAM-disjoint subset, 4,353 images): single-model mel recall drops 73.40% → 37.09%; ensemble macro F1 drops 74.10% → 41.24%. This gap is documented and surfaced to users.

## Quick start

See [REPRODUCE.md](REPRODUCE.md) for the full end-to-end reproduction recipe (clone, download released model weights via `gh release download v2.1`, run backend + Flutter Web). Minimum requirements: Python 3.10+, Flutter 3.16+, gh CLI authenticated.

## Architecture

- **Backend** (`src/skinlesion/`, FastAPI on port 8126):
  - `GET  /health` — service status
  - `POST /predict` — single-model prediction (ResNet50 v2 + calibration)
  - `POST /predict-ensemble` — 4-model weighted ensemble + disagreement detection
  - `POST /cam` — Grad-CAM heatmap for the deployed single model
  - Per-model CAM returned as part of the ensemble payload
- **Mobile app** (`mobile_app/`, Flutter — runs as web in Chrome for demonstration):
  - Five screens: Home, Analysis Setup, Analysis Result (single / ensemble), Model Performance, About & Safety
  - Centralised design tokens (`mobile_app/lib/theme/design_tokens.dart`)
  - Risk-state-coloured result hero · 200 ms cross-fade Grad-CAM toggle · 2×2 per-model ensemble grid with shared lightbox

## Repository layout

```
src/skinlesion/         # Python: training, inference, calibration, Grad-CAM
mobile_app/             # Flutter app (web/mobile)
configs/                # Training configs (v1 baselines + v2 focal+sampler)
runs/                   # Per-model checkpoints + calibration JSONs
runs_v2/                # Phase C v2 training experiment outputs
docs/                   # cam_design.md, calibration_report.md, ui_redesign/, figures/
scripts/                # Smoke tests + ad-hoc utilities
REPRODUCE.md            # End-to-end reproduction recipe
LICENSE                 # MIT (source code)
LICENSE-MODELS.md       # CC BY-NC 4.0 (released model weights)
CITATION.cff            # Citation metadata
```

## Known limitations

The deployed application surfaces these in a dedicated Known Limitations panel; the report covers them in detail. Briefly:

- **External-validation drop.** v2 single-model mel recall falls 73.40% → 37.09% on ISIC 2019 HAM-disjoint; ensemble macro F1 falls 74.10% → 41.24%. In-distribution metrics do not transfer.
- **Calibration scope.** Temperature scaling is fit and verified on HAM10000 only; not characterised for out-of-distribution images.
- **Class imbalance.** Rare classes (df, vasc) retain lower-confidence boundaries even after v2.
- **Imaging conditions.** All training data are dermatoscopic; phone-camera photos without dermatoscopic contact are out of distribution.
- **Not a clinical device.** No regulatory validation. Predictions must not be acted on without qualified clinician review.

## License

- **Source code:** [MIT](LICENSE)
- **Released model weights** (the twelve `*.pt` and `*calibration.json` assets attached to GitHub Releases): [CC BY-NC 4.0](LICENSE-MODELS.md), inherited from HAM10000 and ISIC 2019.

## Citation

If you use this project or its released model weights, please cite via the GitHub "Cite this repository" button (powered by [CITATION.cff](CITATION.cff)) or:

> Liu, J. *DermaSense — CNN-Based Skin Lesion Classification for Early Skin Cancer Detection.* MSc coursework project (UTS 42028), 2026. Release v2.1.
> https://github.com/Cureeeeeeee/CNN-Based-Skin-Lesion-Classification-for-Early-Skin-Cancer-Detection

## Datasets

- **HAM10000**: Tschandl, Rosendahl, Kittler. "The HAM10000 dataset, a large collection of multi-source dermatoscopic images of common pigmented skin lesions." *Scientific Data*, vol. 5, 180161, 2018. Licensed CC BY-NC 4.0.
- **ISIC 2019**: Combalia et al. "BCN20000: Dermoscopic Lesions in the Wild." arXiv:1908.02288, 2019. Licensed CC BY-NC 4.0.

## Acknowledgement

Built as the UTS 42028 (Deep Learning and Convolutional Neural Network) Assignment-3 final project. Iterative development assisted by Anthropic's Claude (commits include `Co-Authored-By: Claude` trailer for transparency).
