# Skin Lesion Mobile Prototype

Flutter prototype for the skin lesion diagnostic-support system. The app uploads
a camera or gallery image to the FastAPI backend and displays either a
single-model (ResNet50) result or a 4-model weighted ensemble result, with
post-hoc temperature-calibrated confidence and an optional on-demand Grad-CAM
attention overlay. A mock prediction mode is included for offline demos when
the backend is not reachable.

## Screens

- **HomeScreen** — system identity + scope + image source (camera / gallery).
- **ClassificationScreen** (Analysis Setup role) — image-quality guidance,
  Single Model / 4-Model Ensemble toggle, collapsible backend connection card,
  mock-mode switch, run analysis.
- **ResultScreen** — unified result view for both single-model and ensemble
  modes. Shared chrome: metadata strip (with `calibrated` indicator when
  applicable), risk hero with class-discriminative colouring, image card,
  top-3 differential, metadata footer, disclaimer card. Ensemble mode adds a
  disagreement banner and per-model breakdown (each model's weight, calibrated
  temperature, and top-3). Single-model mode adds a lazy **Attention** toggle
  on the image card that fetches a Grad-CAM overlay from `/predict-cam`.
- **ModelComparisonScreen** (Model Performance) — per-model accuracy / macro F1
  / weight table plus per-class recall with low-recall cells flagged plus a
  known-limitations status card.
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

## Run

Install Flutter, then run:

```bash
flutter pub get
flutter run -d chrome
```

Start the backend before using the app:

```bash
uvicorn src.skinlesion.api:app --host 0.0.0.0 --port 8000
```

Default API URL:

- Flutter Web: `http://127.0.0.1:8000`
- Android emulator: `http://10.0.2.2:8000`
- Real phone: replace it with the computer's LAN IP, for example
  `http://192.168.1.20:8000`

The API URL is editable inside the Classification screen's collapsible
connection card. API mode calls one of:

- `POST /predict` (Single Model toggle) — ResNet50 only.
- `POST /predict-ensemble` (4-Model Ensemble toggle) — all four backbones
  with weighted-average probabilities.
- `POST /predict-cam` (lazy, on first Attention toggle in single-model mode)
  — Grad-CAM overlay rendered server-side.

Mock mode bypasses the backend with deterministic `PredictionResult.mock` and
`EnsembleResult.mock` constants; the Attention toggle is hidden in this mode.

The backend's `calibrated` flag is parsed transparently and surfaces in the UI
as a small `calibrated` pill in the result metadata strip and in adjusted hero
hedge wording. If the backend has no calibration files, the UI falls back to
the original uncalibrated wording.

ResNet50 remains the default single-model backend. The mobile UI only changes
the presentation layer and does not alter the backend model selection.

If building web from the current OneDrive path with Chinese characters, use:

```bash
flutter build web --no-tree-shake-icons
```

## Validation

Validated locally (Phase 0 regression, 2026-05-24):

- `flutter pub get`: passed
- `dart analyze lib test`: 0 issues
- `flutter test`: 1/1 passing (HomeScreen render)
- `flutter build web`: passed
- Live API smoke test against `/predict`, `/predict-ensemble`, and
  `/predict-cam` on `127.0.0.1:8126`: all three endpoints return valid
  responses; Grad-CAM overlay decodes to a valid 224×224 PNG.

For backend validation see `../docs/validation.md`.

## License & Attribution

This frontend is part of an educational prototype restricted to **non-commercial
use**. The backend model weights are derivative works of the HAM10000 dataset
(CC BY-NC 4.0), so the NonCommercial restriction applies to the system as a
whole. The Flutter SDK itself is BSD-3-Clause.

The `SafetyAboutScreen` (About page) is where the required dataset attributions
should be surfaced to users — the HAM10000 attribution now, and the ISIC 2019 /
BCN_20000 / MSK attributions once external validation ships. *(That is a UI
change for a later phase; this note only documents the requirement.)*

Full license terms, dataset citations, and dependency licenses are in
[`../docs/licenses.md`](../docs/licenses.md).
