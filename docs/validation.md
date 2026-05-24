# Validation Notes

Latest delivery-readiness validation:

- Python compile check: passed with `python -m compileall src scripts`.
- Notebook JSON check: passed for `notebooks/skin_lesion_delivery_demo.ipynb`.
- Report asset generation: passed with `python -m src.skinlesion.report_assets`.
- Demo set generation: passed with `python -m src.skinlesion.prepare_demo_set`.
- FastAPI real uvicorn validation on `127.0.0.1:8000`:
  - `GET /`: passed, root project JSON returned.
  - `GET /health`: passed, `status=ok`, ResNet50 loaded.
  - `GET /model-info`: passed, default model reported as ResNet50.
  - `GET /docs`: passed with HTTP 200.
  - `POST /predict`: passed through `scripts/test_api_demo.py`.
  - Demo top-3 output for `easy_correct_ISIC_0024308.jpg`: `nv` 91.28%, `mel` 8.58%, `bkl` 0.13%.
  - Prediction JSON includes raw labels, display labels, and confidence scores.
- FastAPI clean-port validation on `127.0.0.1:8011`:
  - `POST /predict`: passed after adding readable display labels.
  - Demo top-3 display output: `nv - Melanocytic nevi`, `mel - Melanoma`, `bkl - Benign keratosis-like lesions`.
- FastAPI TestClient:
  - `GET /health`: passed, ResNet50 loaded.
  - `GET /model-info`: passed, default model reported as ResNet50.
  - `POST /predict`: passed, top-3 predictions returned.
  - Empty upload: returned HTTP 400.
  - Invalid image upload: returned HTTP 400.
- Real uvicorn startup: passed on `127.0.0.1:8010`; `/health` returned `status=ok`.
- Flutter:
  - Flutter SDK detected at `C:\Users\user\develop\flutter`.
  - `flutter pub get`: passed.
  - `dart analyze lib test`: passed with no issues.
  - `flutter test`: passed.
  - `flutter build web --no-tree-shake-icons`: passed.
  - Product-like Flutter UI polish completed for Home, Classification, Result, and Model Comparison screens.
  - Current `127.0.0.1:8000` service smoke test passed for root, docs, and `/predict` top-3 predictions.
  - Flutter Web API mode is implemented with multipart upload to `/predict`.
  - Flutter mock mode is implemented as a fallback and covered by UI flow.
  - Prediction results show both HAM10000 class codes and readable class names.
  - Android emulator workflow is documented with `http://10.0.2.2:8000`; not run in this validation pass.

ResNet50 remains the default single-model deployment because it has the best
validated test accuracy and macro F1-score among the completed experiments.

---

## Phase 0 regression — 2026-05-24

Validated on `dev` branch at `9343fb0` (after Phase B2 Grad-CAM landed):

### Backend
- `python -m compileall src scripts`: clean.
- FastAPI real uvicorn validation on `127.0.0.1:8126`:
  - `GET /health`: `status=ok`, ResNet50 loaded.
  - `GET /model-info`: includes new `calibration` block reporting
    `single.calibrated=true T=1.5391` and `ensemble.all_calibrated=true` with
    per-model fitted T values (RN 1.5391, DN 1.689, EN 2.0267, MN 1.6551).
  - `POST /predict`: returns `calibrated=true`, `temperature=1.5391`, top-3
    predictions with display labels.
  - `POST /predict-ensemble`: returns `request_id`, `inference_time_ms ~113ms`,
    `model_version=ensemble-v1`, `models_agree=true`, `calibrated=true`,
    ensemble top-1 + per-model breakdown with each model's `calibrated`,
    `temperature`, `weight`, predicted class, and top-3.
  - `POST /predict-cam`: returns `calibrated=true T=1.5391`,
    `target_layer=layer4`, `method=grad-cam`, valid 224×224 base64-encoded
    PNG overlay (~90KB) that decodes cleanly via `PIL.Image.verify()`.
  - All three endpoints exercised via `scripts/test_api_demo.py` with
    explicit assertions on the `calibrated` flag and the Grad-CAM PNG decode.

### Calibration (Phase A1 + A1.5)
- Temperature scaling fit on val (1,736 samples) for all 4 models.
  Post-cal val ECE: RN 0.0204, DN 0.0205, EN 0.0240, MN 0.0326.
- Test-set generalisation verified on held-out test (1,734 samples) using
  the val-fitted T without refitting. Post-cal test ECE: RN 0.0183,
  DN 0.0337, EN 0.0346, MN 0.0412. Max val/test ECE gap: 1.3 pp
  (DenseNet121).
- Top-1 accuracy unchanged on every model on every split (monotone in argmax
  by construction).
- Full per-model report: `docs/calibration_report.md`. Reliability diagrams:
  `docs/figures/calibration_<m>.png` (val) and `docs/figures/calibration_<m>_test.png` (test).

### Grad-CAM (Phase B1 + B2)
- `src/skinlesion/cam.py` runs Grad-CAM with explicit hook lifecycle
  (context manager); `src/skinlesion/cam_demo.py` reproduces the 14
  committed sample overlays under `docs/figures/cam_samples/`.
- API path serialised through `_CAM_LOCK` (asyncio) to avoid forward/backward
  hook races on the shared model layer. Documented limitation for the demo;
  production would require per-request model clones or batching.
- Design notes: `docs/cam_design.md` (per-architecture target-layer rationale,
  four annotated sample cases including a false positive and a false negative
  on melanoma, known failure modes, and the "what Grad-CAM is not" section).

### Flutter
- `flutter pub get`: passed.
- `dart analyze lib test`: 0 issues across all current lib/ and test/ files
  (including the new `theme/`, `widgets/`, `models/cam_response.dart`, and
  the refactored stateful `screens/result_screen.dart`).
- `flutter test`: 1/1 passing (HomeScreen renders identity, scope, source
  controls, and the persistent disclaimer ribbon).
- `flutter build web`: passed.
- Visual register: institutional navy (#0F4C81) + teal accent (#0E7490),
  hairline-bordered cards, persistent disclaimer ribbon on every
  prediction-bearing screen, risk-sensitive colour states (lower /
  indeterminate / requires-evaluation). Non-diagnostic wording verified
  throughout.
- ResultScreen handles both single-model and ensemble modes via named
  constructors. Single-model + non-mock mode exposes a lazy Grad-CAM
  Attention toggle on the image card (cached after first fetch).
- SafetyAboutScreen reachable via app-bar info icon from every screen;
  includes Calibration and Model Attention (Grad-CAM) cards.

### Known limitations carried forward
- Melanoma recall (54–59% across all 4 models) is the headline remaining
  clinical weakness — to be addressed in Phase C with model artefacts saved
  under `runs_v2/` so the v1 baseline is preserved.
- No external dataset validation yet (Phase E candidate).
- Calibration is HAM10000-distribution only; out-of-distribution behaviour
  is uncharacterised.
- Grad-CAM available for the single-model (ResNet50) path only.
- 1 Dart widget test + 1 Python smoke test; broader coverage is not in place.

---

## Phase C Stage A deploy — 2026-05-25

Deployed the Phase C night-1 winner (`resnet50_v2_focal_plus_sampler`) to the
single-model production path in a **version-aware, rollback-ready** way.

### Design
- The winner's artefacts (`best.pt`, `calibration.json`, `test_metrics.json`,
  `history.json`, reliability PNGs, confusion matrix) were copied into
  `runs/resnet50_v2/`. v1 was first backed up byte-for-byte to
  `runs/resnet50_v1_backup/` (SHA256 verified, `best.pt` = 94,392,749 bytes).
- A new `production:` block in `configs/ham10000.yaml` carries
  `resnet50_checkpoint: resnet50_v2`. `api.py` now resolves the single-model
  ResNet50 directory from this block (`resolve_resnet50_dir()`), falling back
  to `resnet50` (v1) when the block/key is absent — backwards compatible.
- The version-aware logic affects **only** the single-model paths: `/predict`,
  `/predict-cam`, and the `/model-info` report. The 4-model ensemble loader
  (`config['ensemble']['checkpoints']`) was deliberately left unchanged and
  **still uses v1 across all four backbones**, including its ResNet50 member.
- `/model-info` now returns a `resnet50_version` field, read from a `VERSION`
  file in the model directory (`runs/resnet50_v2/VERSION` → `v2-focal-sampler`)
  and inferred as `v1` for the original `resnet50` directory.

### Deployed-model metrics (`runs/resnet50_v2/test_metrics.json`)
- mel recall **73.40%** (v1 54.79%, +18.6 pp); macro F1 **70.08%**
  (v1 69.03%, +1.05 pp); accuracy 77.28%.
- Calibration: val-fitted temperature **T=0.8982**, post-cal test ECE
  **0.0248** (v1 0.0297).

### Smoke test (real uvicorn on `127.0.0.1:8126`, via `scripts/test_api_demo.py`)
- `GET /health`: `status=ok`, `checkpoint=runs/resnet50_v2/best.pt`, CUDA.
- `GET /model-info`: `resnet50_version=v2-focal-sampler`,
  `calibration.single.calibrated=true T=0.8982`.
- `POST /predict`: `calibrated=true T=0.8982`. Demo top-3:
  `nv` 61.27%, `mel` 38.07%, `bkl` 0.63%.
- `POST /predict-ensemble`: `model_version=ensemble-v1`, `models_agree=true`,
  ensemble top-1 `nv` 86.64%, `inference_time_ms ~131ms`. Per-model T values
  are the **v1** calibration set (RN 1.5391, DN 1.689, EN 2.0267, MN 1.6551) —
  expected, because the ensemble path was intentionally not migrated to v2.
- `POST /predict-cam`: `calibrated=true T=0.8982`, `target_layer=layer4`,
  valid 224×224 base64 PNG.

> **Spec note for reviewer:** the Stage-A verification checklist anticipated the
> ensemble's ResNet50 row showing the v2 temperature (~0.898). It shows v1's
> 1.5391 instead. This is the *correct* outcome given the explicit Stage-A
> design instruction to leave the ensemble on v1 across all backbones — the two
> checklist items were mutually inconsistent and the design instruction was
> treated as authoritative. Migrating the ensemble's ResNet50 member to v2 is a
> separate, deliberate follow-up if desired.

### Rollback
Set `production.resnet50_checkpoint` back to `resnet50` in
`configs/ham10000.yaml` and restart the API. The single-model path then loads
the v1 checkpoint (`runs/resnet50/best.pt`, T=1.5391) and `/model-info` reports
`resnet50_version=v1`. No code change required. `runs/resnet50_v1_backup/` is an
additional safety copy of the original v1 artefacts.
