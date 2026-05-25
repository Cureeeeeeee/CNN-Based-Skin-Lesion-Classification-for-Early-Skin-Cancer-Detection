# Project Progress and Roadmap

> **Snapshot at v1.0 — 2026-05-24.** Treat this document as immutable except when phases land. It is intentionally a point-in-time orientation surface for any reviewer, collaborator, or future-self; live operational details belong in `CLAUDE.md`, validation evidence in `docs/validation.md`, and detailed sub-system writeups in `docs/calibration_report.md` and `docs/cam_design.md`.

---

## What This Project Is

A CNN-based **research-grade skin lesion diagnostic-support prototype** trained on HAM10000. End-to-end working stack:

- **Backend (FastAPI):** `/predict` (single-model ResNet50), `/predict-ensemble` (4-model weighted), `/predict-cam` (Grad-CAM overlay for ResNet50). All endpoints surface a `calibrated` flag and apply post-hoc temperature-scaled probabilities when calibration files are present.
- **Frontend (Flutter, Material 3):** five clinical-style screens (Home, Analysis Setup, unified Result, Model Performance, Safety/About). Institutional navy + teal palette, hairline-bordered cards, persistent disclaimer ribbon, risk-sensitive colour states.
- **Models:** 4 timm backbones fine-tuned on HAM10000 — ResNet50 (default single-model), DenseNet121, EfficientNet-B0, MobileNetV3 Small. Test accuracy 67.8–80.2%, macro F1 57.3–69.0%.
- **Calibration:** per-model temperature scaling fit on val, generalisation verified on held-out test. Post-cal test ECE 1.8–4.1%.
- **Explainability:** Grad-CAM overlay for the deployed ResNet50, lazy-fetched and cached in the Flutter Result screen.
- **Wording:** non-diagnostic throughout — "Requires Clinical Evaluation", "temperature-calibrated model-estimated confidence on the validation set", "not a clinical region of interest".

`dev` head at snapshot: `9343fb0` (Phase B2). Working tree clean.

---

## Completed Milestones

| # | Phase | Commit | Goal | Why it improved the project |
|---|---|---|---|---|
| 1 | Initial ResNet50 + 4-model baseline | `50efc0b` → `9af3ad4` | Train + evaluate four backbones; pick a default. | Established baseline numbers and the reproducible training/eval pipeline. |
| 2 | Initial FastAPI + Flutter demo | `f60eb20` → `0295bff` | Wrap ResNet50 in `/predict`; build a 4-screen Flutter prototype with API + mock modes. | Made the model usable as a product surface. The mock mode introduced here later became critical for offline demos. |
| 3 | Multi-model weighted ensemble API | `e9bd3c4` | Add `/predict-ensemble` with weighted-average probabilities + per-model breakdown + agreement signal. | First step toward "diagnostic-support" framing — multiple models with an explicit disagreement signal as a safety surface. |
| 4 | Medical-style Flutter UI redesign | `6421b13` | Replace consumer-grade UI with clinical visual register; collapse single + ensemble into one Result screen; persistent disclaimer ribbon; risk-sensitive states; new Safety/About screen. | Moved the app from "student demo" to "clinical-style prototype" in one coherent commit. Established the visual system used by everything since. |
| 5 | Probability calibration A1 (offline) | `b1ed12a` | Fit temperature scaling on val for all 4 models; report ECE/NLL/Brier before/after; render reliability diagrams. | Made the confidence number meaningful enough to tighten the UI hedge. ECE dropped 66–78% across the board; top-1 unchanged. |
| 6 | Probability calibration A2 (API + UI) | `703097f` | Read `runs/<m>/calibration.json` at startup; apply T in `/predict` and `/predict-ensemble`; expose `calibrated` flag; swap UI hedge text. | Surfaced calibration in the visible product, with backwards-compatible fallback when files absent. |
| 7 | Calibration A1.5 (test-set generalisation) | `5988f0e` | Apply each model's val-fitted T to the held-out test split without refitting; report metrics. | Closed Caveat #1 from A1: the calibration claim is now defensible on data the temperature was not fit on. Max val/test ECE gap 1.3 pp. |
| 8 | Grad-CAM B1 (offline module + samples) | `dfb5150` | Implement Grad-CAM; render sample overlays on 4 demo images + per-architecture comparison; write design notes. | Made the explainability story reviewable before committing to API/UI integration. Surfaced clinically illustrative cases (false positive + false negative on melanoma). |
| 9 | Grad-CAM B2 (API + UI) | `9343fb0` | `/predict-cam` endpoint (ResNet50, asyncio-lock serialised); lazy Attention toggle on Result screen; Safety/About card. | Shipped the explainability surface clinicians most often ask for, while keeping wording strictly non-diagnostic. |

---

## Current Architecture

### Request flow

```
Flutter App (Home → Analysis Setup → Result)
  │
  │ multipart image upload
  ▼
FastAPI (src/skinlesion/api.py)
  ├── POST /predict          → ResNet50 single-model, calibrated softmax
  ├── POST /predict-ensemble → 4 models, calibrated per-model softmax, weighted avg
  └── POST /predict-cam      → Grad-CAM on ResNet50 → base64 PNG overlay
  │
  ▼
ResultScreen
  ├── shared chrome: metadata strip, risk hero, image card, disclaimer ribbon
  ├── ensemble extras: disagreement banner, model breakdown (per-model T + calibrated)
  └── single extras: Attention toggle (lazy fetch /predict-cam, cache)
```

### Per-mode details

- **ResNet50 single-model.** `api.load_model()` loads `runs/resnet50/best.pt` at startup, reads `runs/resnet50/calibration.json` if present (`SINGLE_TEMPERATURE`, `SINGLE_CALIBRATED`). `/predict` runs softmax on `logits / T`, returns top-3 + `calibrated` + `temperature`.
- **4-model ensemble.** `api.load_ensemble_models()` loads all 4 checkpoints via `ensemble.load_ensemble()`; each `LoadedModel` carries its own `temperature` + `calibrated` from the per-model calibration file. `run_inference_single()` applies each model's T before softmax; `compute_ensemble()` does a weight-normalised probability average. Response includes per-model `predicted_class` + `temperature` + `calibrated`, a top-level `calibrated` flag (true iff all 4 have calibration files), `models_agree`, and an `agreement_note` when not.
- **Calibration.** Applied transparently in both paths. Absent calibration files → `T = 1.0`, `calibrated = false`. Flutter shows/hides the "calibrated" pill in the metadata strip and swaps the hero hedge text based on the flag.
- **Grad-CAM.** `/predict-cam` re-runs ResNet50 with `GradCAM` hooks on `model.layer4`, ReLUs and normalises the class activation map, bilinear-upsamples to 224×224, blends with the un-normalised RGB display copy using viridis at α = 0.45, base64-encodes the PNG. Endpoint serialised through `_CAM_LOCK` (asyncio) because shared-model hooks would race under concurrent requests. Flutter `ResultScreen` is `StatefulWidget`; toggle hidden in mock + ensemble modes; first tap shows spinner, fetches `/predict-cam`, caches `Uint8List` heatmap; subsequent toggles are instant. Errors render in an amber strip and reset the toggle.
- **Mock mode.** `ClassificationScreen` passes `apiBaseUrl = null` when `_mockMode == true`. `PredictionResult.mock` / `EnsembleResult.mock` are deterministic static constants. Attention toggle hidden in mock mode.

---

## Strengths

- End-to-end working stack validated under `dart analyze` + `flutter test` + `flutter build web` + live API smoke test on every recent commit.
- Four-model weighted ensemble with an agreement signal — clinically more defensible than any single model.
- Post-hoc temperature calibration confirmed on test split, not just val. Top-1 unchanged; confidence semantics improved.
- Grad-CAM explainability with rigorous "what this is not" wording.
- Clinical visual register documented in `docs/figures/` and reused across screens.
- Consistently non-diagnostic wording with a persistent disclaimer ribbon.
- Validation scripts (`scripts/test_api_demo.py`) assert (not just print) on every endpoint and surface calibration state.
- Demo-ready Web/Android workflow with a mock fallback that needs no backend.
- Reproducible artefacts: calibration script regenerates `calibration.json` + reliability PNGs; cam_demo regenerates sample heatmaps.

---

## Known Limitations

| # | Limitation | Where it's surfaced |
|---|---|---|
| L1 | **Melanoma recall 54–59%** across all four models. ~4 in 10 mel cases in the test set are misclassified. | Model Performance limitations card (Flutter); `docs/validation.md` |
| L2 | Grad-CAM available only for the single-model ResNet50 path. Ensemble breakdown has no attention surface. | Safety/About Grad-CAM card (Flutter); `docs/cam_design.md` |
| L3 | No external dataset validation. All metrics from one HAM10000 split. | Safety/About; `README.md` Known Limitations |
| L4 | HAM10000 dataset bias: predominantly Fitzpatrick I–III; dermoscopy not phone-camera; heavy `nv` skew. | Model Performance limitations card; `docs/cam_design.md` (Known failure modes) |
| L5 | Calibration is HAM10000-distribution only — not validated against out-of-distribution images. | Safety/About Calibration card; `docs/calibration_report.md` Caveat #4 |
| L6 | No regulatory clearance. Explicitly research-grade. | Safety/About "Not Intended For" card; persistent disclaimer ribbon on every screen |
| L7 | No Docker / deployment package. Backend runs via local `uvicorn`. | This document; phase F below |
| L8 | Limited automated test coverage (1 Dart widget test, 1 Python smoke test). | This document; `mobile_app/README.md` |

Cross-references:
- `docs/calibration_report.md` — full A1/A2/A1.5 writeup with per-model reliability diagrams.
- `docs/cam_design.md` — Grad-CAM design notes including failure modes.
- `docs/figures/calibration_*.png` and `docs/figures/calibration_*_test.png` — 8 reliability diagrams (val + test).
- `docs/figures/cam_samples/*.png` — 14 Grad-CAM sample overlays.

---

## Roadmap

### Phase 0 — Stabilisation and Documentation
**Status:** completed by the commit that introduces this document.
**Goal:** Bring `README.md`, `mobile_app/README.md`, and `docs/validation.md` in line with the actual shipped state. Snapshot a defensible "v1.0 of the prototype" before any further code work potentially churns model artefacts.
**Validation:** Full regression sweep (`compileall`, `dart analyze`, `flutter test`, `flutter build web`, live API smoke against the 4 demo images) green at `9343fb0`.

### Phase C — Melanoma Recall Improvement
**Status:** planned, not started. Gated on user approval of acceptance criteria.
**Goal:** Improve the 54–59% mel recall floor (L1) without losing material top-1 accuracy.
**Approach:** Training-pipeline change one at a time (focal loss / class-balanced sampling / mel auxiliary loss / longer schedule / stronger minority-class augmentation), starting with ResNet50 v2 as a focused experiment.
**Constraint:** ALL new artefacts under `runs_v2/`. `runs/` is read-only for this phase — v1 checkpoints are the reference baseline.
**Key files:** `src/skinlesion/train.py`, `src/skinlesion/data.py`, `configs/ham10000.yaml` (`runs_v2` output root for v2 experiments).
**Success criteria (to confirm with user):** mel recall ≥ 65% with macro F1 within 2 pp of v1.
**Validation:** Full test-split re-evaluation, per-class confusion matrices side-by-side against v1, recalibration of v2 checkpoint, post-cal ECE comparison.

### Phase C2 — Multi-model v2
**Status:** planned, conditional on C succeeding.
**Goal:** If C delivers a real mel-recall improvement on ResNet50, propagate the training change to DenseNet121, EfficientNet-B0 (and optionally MobileNetV3 Small).
**Tasks:** Train v2 of each model, recalibrate each (calibration is per-checkpoint — Caveat #3 in `docs/calibration_report.md`), re-evaluate ensemble weights, update `configs/ham10000.yaml` `ensemble:` block only after side-by-side comparison.

### Phase D — Optional Per-Model Grad-CAM (B3)
**Status:** optional. Lower priority than C/C2/E.
**Goal:** Address L2 — render Grad-CAM per model in the ensemble breakdown so disagreement is inspectable visually.
**Open design questions:** new `/predict-cam-ensemble` endpoint vs extending `/predict-cam` with a `?models=all` parameter; payload size for 4× ~30 KB PNGs; UI placement (inside the expandable model row vs a separate grid).

### Phase E — External Validation / Dataset Expansion
**Status:** planned.
**Goal:** Address L3 + L4 + L5. Characterise generalisation beyond HAM10000.
**Tasks:** Acquire ISIC 2019 (or similar). Label-mapping work (HAM10000's 7 classes vs ISIC 2019). Leakage control via `lesion_id` deduplication. Licensing audit before any commit. Bias audit (skin-type stratification if metadata available). Update Safety/About card with external-validation status.

### Phase F — Deployment / Productisation
**Status:** planned.
**Goal:** Address L7. Ship a runnable artefact someone else could deploy.
**Tasks:** Dockerfile for the backend (Python + PyTorch + the API), `docker-compose.yml` if Flutter Web is bundled, one-command run script, release checklist (which checkpoints, calibration files, version pinning, CORS, env vars), optional pre-built Flutter APK / iOS IPA instructions.

---

## Decision Log

Architectural choices made along the way, with the *why*. These are the most fragile pieces of knowledge — they live only in commit messages and in this document.

### Information architecture (Phase 4)
**Decision:** Option A+ hybrid — keep 4 existing screens, tighten responsibilities, add **one** new Safety/About screen. Reject Option B (7 separate screens).
**Why:** Clinical UIs reward shallow navigation. Each extra screen is a place to lose context. Adding only Safety/About earns trust by being there without growing depth.

### Unified ResultScreen
**Decision:** A single `ResultScreen` handles both ensemble and single-model results via named constructors (`ResultScreen.ensemble(...)`, `ResultScreen.single(...)`). Internal getters branch on which constructor was used.
**Why:** Two near-duplicate files would inevitably diverge. The conditional sections (disagreement banner, model breakdown, Attention toggle) are clearly bounded.

### Persistent disclaimer ribbon
**Decision:** A bottom-anchored disclaimer ribbon on every prediction-bearing screen, rendered via the `bottomNavigationBar` Scaffold slot (so SafeArea works automatically).
**Why:** A disclaimer at the bottom of a scrollable card stack is easy to scroll past. A persistent ribbon is the clinical safety contract of the prototype — always visible, no exceptions.

### Risk classification overrides class colour on disagreement
**Decision:** When ensemble models disagree, the risk hero uses the indeterminate (amber) palette **regardless** of the top-1 class's normal risk colour.
**Why:** Disagreement is itself a form of uncertainty and should visually outweigh whatever the ensemble's argmax decided. A confident red hero on a disagreeing ensemble would understate the actual situation.

### Risk labels: "Requires Clinical Evaluation" / "Indeterminate — Review Suggested" / "Lower Concern Indicator"
**Decision:** Risk pills carry these specific phrases. Do not use "Malignant", "Benign", "Safe", or "No disease".
**Why:** "Malignant" reads as a diagnosis. "Benign" / "Safe" reads as a clearance. Neither is appropriate for a non-cleared research prototype. The chosen phrases are clinically useful but explicitly non-diagnostic.

### Hairline borders, not shadows, for cards
**Decision:** All cards use `Border.all(color: AppColors.border)` with `elevation: 0`. No shadows anywhere except the AppBar (which inherits Material 3 defaults).
**Why:** The single largest visual change moving the app from "consumer SaaS app" to "clinical software". Shadows scream consumer; hairlines read as institutional.

### Calibration: temperature scaling, not isotonic or Platt
**Decision:** Scalar temperature scaling per model (Guo et al. 2017). Reject vector temperature, isotonic regression, and Platt scaling unless this fails to deliver.
**Why:** (a) Monotone in argmax — guarantees top-1 predictions don't change. (b) One parameter per model — trivially fit via LBFGS, no overfit risk. (c) Sufficient: post-cal ECE on the most miscalibrated model (MobileNetV3) is 3.3% on val, 4.1% on test — well within "calibrated for practical use".

### Calibration files live in `runs/`, not in the repo
**Decision:** `runs/<m>/calibration.json` is gitignored alongside the checkpoint it describes. The committed reliability PNGs live in `docs/figures/`.
**Why:** Checkpoints aren't in the repo; calibration is per-checkpoint. The committed PNGs let the report render in any clone of the repo without requiring local checkpoints. The API gracefully falls back to uncalibrated softmax if `calibration.json` is absent.

### Calibration: applied to both single-model and ensemble paths
**Decision:** Each model's temperature is applied to its own logits before softmax. The ensemble averages temperature-calibrated probabilities, not raw softmax.
**Why:** Each component's confidence has been individually fit on val. Averaging calibrated probabilities is the more defensible behaviour than averaging raw outputs. Top-1 argmax is preserved by construction.

### Grad-CAM: direct implementation, not pytorch-grad-cam library
**Decision:** Implement Grad-CAM in `src/skinlesion/cam.py` (~150 lines). Reject the `pytorch-grad-cam` library dependency.
**Why:** The algorithm is well-defined; the library adds opencv-python-headless and other transitive deps. The direct implementation gives precise control over hook lifecycle and keeps the dependency footprint small.

### Grad-CAM: context-manager hook lifecycle
**Decision:** `with grad_cam(model, model_name) as cam:` — hooks always removed, even if inference raises.
**Why:** Explicit `cleanup()` methods are easy to forget. The original plan called for one; this is harder to misuse.

### Grad-CAM: viridis, not jet
**Decision:** Perceptually uniform viridis colormap for the overlay.
**Why:** Jet has a yellow band that conflicts visually with skin pigmentation. Viridis is perceptually uniform and pairs naturally with the warm tones of dermoscopy images.

### Grad-CAM: heatmap-weighted blend, not constant alpha
**Decision:** Blend weight = `alpha * heatmap`, so low-attention regions are essentially untouched.
**Why:** A constant `alpha = 0.5` blend washes the entire image; the lesion becomes hard to read in cold regions. Heatmap-weighted blend is the standard medical-imaging convention and preserves the underlying image.

### Grad-CAM: pre-rendered overlay returned by API
**Decision:** `/predict-cam` returns a base64 PNG of the colour-blended overlay. Reject returning the raw heatmap array for client-side blending.
**Why:** Simpler Flutter code (just decode and show). The server already has matplotlib and the colormap; doing the work there once is cheaper than every client implementing the same blend. Could ship raw later if needed.

### Grad-CAM: lazy fetch on toggle, not eager
**Decision:** `/predict-cam` only called when the user toggles Attention for the first time. Cached afterwards.
**Why:** CAM adds a backward pass and PNG render — adding it to every prediction would slow the initial result. CAM is an exploration tool, not core to every result.

### Grad-CAM: single-model (ResNet50) only in B2
**Decision:** No per-model ensemble CAMs in B2. Deferred to Phase D.
**Why:** Bounded scope. The most common ask is "explain the deployed model". Per-model ensemble CAMs would 4× the payload size and require a substantial UI design pass for the breakdown view.

### Grad-CAM: asyncio.Lock serialisation
**Decision:** All `/predict-cam` requests serialised through `_CAM_LOCK`. Documented as a known demo limitation.
**Why:** Forward/backward hooks on the shared model layer would race under concurrent requests. Per-request model clones or batching would solve this for production; the demo's single-user assumption makes the lock acceptable.

### Phase splits (A1/A2/A1.5 and B1/B2)
**Decision:** Calibration and Grad-CAM each shipped in two reviewable rounds: an offline measurement/module round (A1, B1) followed by an integration round (A2, B2). A1.5 (test-set generalisation) was added as a follow-up that closed an outstanding caveat without expanding scope.
**Why:** Each round was reviewable on its own. The offline rounds produced committed artefacts (reports + sample figures) that justified the integration without speculation. The pattern keeps risk localised — if A2 had failed, A1's measurements would still be useful.

---

## How to Reproduce

This section is intentionally a pointer, not a duplicate.

- **Day-to-day commands** (training, evaluation, calibration, Grad-CAM rendering, API startup, Flutter dev workflow): see `CLAUDE.md`.
- **README quick-start** (clone → install → train → run): see `README.md`.
- **Flutter-specific build and dev**: see `mobile_app/README.md`.
- **API smoke validation**: `scripts/test_api_demo.py` exercises `/predict`, `/predict-ensemble`, and `/predict-cam` with assertions.
- **Calibration report and figures**: `docs/calibration_report.md` + `docs/figures/calibration_*.png` + `docs/figures/calibration_*_test.png`.
- **Grad-CAM design notes and samples**: `docs/cam_design.md` + `docs/figures/cam_samples/*.png`.

---

*End of snapshot. Next update lands with the first Phase C commit.*
