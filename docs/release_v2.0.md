# Release v2.0

**Tag:** `v2.0` · **Date:** 2026-05-25 · **Branch:** dev
**Theme:** Phase C production deploy of the v2 ResNet50 winner + Phase E external
validation, packaged for a reproducible CPU-only demo.

> Educational prototype — **not a medical device**. Non-commercial use only
> (CC BY-NC 4.0 datasets; see [§8](#8-license--citations)).

## 1. Overview

v2.0 bundles the full pipeline that has accumulated through Phases A–F:

- **Phase C** — a v2 ResNet50 trained with focal loss + a class-balanced sampler,
  deployed as the version-aware single-model production checkpoint
  (`/predict`, `/predict-cam`). v1 remains available for one-line rollback.
- **Phase A** — post-hoc temperature-scaling calibration for all models.
- **Phase B** — Grad-CAM attention overlays for the single-model path.
- **Ensemble** — a 4-model weighted ensemble (`/predict-ensemble`), kept on v1
  (Phase C Stage B showed swapping v2 in dilutes the melanoma signal).
- **Phase E** — honest external validation on a HAM-disjoint ISIC 2019 set.
- **Phase F** — pinned dependencies, one-command demo scripts, this release
  documentation, and a Docker design doc (build deferred).
- Flutter mobile UI, MIT-licensed code, full dataset attribution.

## 2. Headline results

| Metric | In-distribution (HAM10000 test, 1734) | External (ISIC 2019, 4353) |
|---|--:|--:|
| v2 ResNet50 melanoma recall | **73.40%** | **37.09%** |
| v2 ResNet50 macro F1 | 70.08% | 34.72% |
| v2 ResNet50 test ECE (calibrated) | 0.0248 | 0.1814 |
| v1 4-model ensemble macro F1 | 74.10% | 41.24% |

The Phase C v2 winner lifts in-distribution melanoma recall from the v1 baseline
of 54.79% to **73.40%** (+18.6 pp). **Phase E is deliberately honest about the
limits:** on out-of-distribution ISIC 2019 images the same model's melanoma
recall falls to ~37%, and a three-line preprocessing audit confirmed this is
genuine distribution shift, not a pipeline artefact
([details](phase_e_external_validation.md)). The strong in-distribution number
does **not** generalise — the central caveat for the thesis defense.

## 3. System architecture

Training → deployment pipeline and the FastAPI/Flutter split are documented in
`CLAUDE.md` (Architecture) and `docs/mobile_app_architecture.md`. In short:
`configs/ham10000.yaml` → `train.py` → `runs/<model>/best.pt` →
`api.py` (loads the production single model + the 4-model ensemble at startup) →
Flutter app. The deployed single-model directory is config-driven
(`production.resnet50_checkpoint`), enabling v1↔v2 A/B and rollback without code
changes.

## 4. Model artefacts

Six checkpoints (gitignored; distributed via the GitHub Release). Hashes/sizes
in [`runs_v2/release_manifest.json`](../runs_v2/release_manifest.json).

| Directory | Size | Origin / role |
|---|--:|---|
| `runs/resnet50_v2/` | 94.4 MB | **Phase C winner** (focal γ=2.0 + balanced sampler). Current production `/predict` default. |
| `runs/resnet50/` | 94.4 MB | v1 baseline ResNet50; ensemble member. |
| `runs/resnet50_v1_backup/` | 94.4 MB | byte-identical v1 backup for rollback. |
| `runs/densenet121/` | 28.4 MB | v1 ensemble member. |
| `runs/efficientnet_b0/` | 16.3 MB | v1 ensemble member. |
| `runs/mobilenetv3_small_100/` | 6.2 MB | v1 ensemble member. |

Each directory also carries `calibration.json` (temperature scaling, required
for calibrated inference) and report JSONs (`test_metrics.json`, `history.json`).

## 5. Installation

CPU-only, any modern machine. One command (see the README Quick Start for full
prerequisites and troubleshooting):

```bash
bash scripts/run_demo.sh            # macOS / Linux
powershell -ExecutionPolicy Bypass -File scripts\run_demo.ps1   # Windows
```

This creates `.venv`, installs CPU PyTorch + `requirements-lock.txt`, downloads
+ verifies checkpoints, and starts the API at `http://127.0.0.1:8126`.

## 6. Quick demo walkthrough (thesis defense)

1. **Start the backend:** `bash scripts/run_demo.sh` → wait for
   `API ready at http://127.0.0.1:8126`.
2. **Confirm the version:** `curl http://127.0.0.1:8126/model-info` →
   `resnet50_version = v2-focal-sampler`, `calibration.single.temperature ≈ 0.898`.
3. **Single prediction:** `python scripts/test_api_demo.py --base-url http://127.0.0.1:8126`
   → calibrated top-3 for the demo image.
4. **Ensemble + Grad-CAM:** hit `/predict-ensemble` (4-model breakdown) and
   `/predict-cam` (base64 attention overlay) — or use the Flutter UI.
5. **Tell the honest story:** in-distribution mel recall 73.4%; external ISIC
   ~37% — show `docs/phase_e_external_validation.md` and the distribution-shift
   finding.

## 7. Reproducibility

- Backend/Flutter validation log: [`docs/validation.md`](validation.md).
- Calibration report: [`docs/calibration_report.md`](calibration_report.md).
- External test-set preparation (dedup, label mapping):
  [`docs/phase_e_data_preparation.md`](phase_e_data_preparation.md).
- External evaluation + preprocessing audit:
  [`docs/phase_e_external_validation.md`](phase_e_external_validation.md).
- Pinned environment: [`requirements-lock.txt`](../requirements-lock.txt)
  (PyTorch installed separately, CPU build — see its header).
- Eval scripts: `scripts/evaluate_external.py`, `scripts/evaluate_ensemble_v2.py`
  (deterministic at `batch_size=32`).

## 8. License & citations

MIT for the code ([`LICENSE`](../LICENSE)). The trained weights are derivative
works of HAM10000 (CC BY-NC 4.0), so the **non-commercial** restriction
propagates to them and the project as a whole. Full dataset citations
(HAM10000, ISIC 2019 / BCN_20000 / MSK), dependency licenses, and the BibTeX
template are in [`docs/licenses.md`](licenses.md).

## 9. Known limitations

Summarised from [`docs/phase_e_external_validation.md` §6–§7](phase_e_external_validation.md):

- **External melanoma recall (~27–43%) is not clinically acceptable**; the
  in-distribution 73% does not generalise.
- **Calibration does not transfer out-of-distribution** (single-model ECE rises
  5–9×) — confidence is untrustworthy on non-HAM-like images.
- `akiec` label-definition mismatch (HAM AK+IEC vs ISIC AK-only); lesion-level
  dedup not feasible (no ISIC test `lesion_id`); no skin-tone metadata for a bias
  audit. **Not a medical device.**

## 10. SHA256 manifest

[`runs_v2/release_manifest.json`](../runs_v2/release_manifest.json) holds the
`sha256` + `size_bytes` for every checkpoint. `scripts/download_checkpoints.py
--verify-only` checks local files against it.

## 11. Changelog (Phase 0 → Phase F)

| Phase | Commit | Summary |
|---|---|---|
| Ensemble/UI (Phase 0) | `e9bd3c4`, `6421b13`, `ea6fccd` | 4-model weighted ensemble endpoint; medical-grade Flutter UI. |
| A — Calibration | `b1ed12a`, `703097f`, `5988f0e` | Temperature scaling for all 4 models, wired through API/UI, test-set generalisation. |
| B — Grad-CAM | `dfb5150`, `9343fb0` | Grad-CAM module + CLI; `/predict-cam` and UI attention overlay. |
| C — v2 training | `a80dd11`, `d364594`, `26eea0d`, `4b934e2` | Focal + balanced-sampler infra; exp 3 winner (mel 73.4%). |
| C — Stage A deploy | `01f2765` | Version-aware deploy of `resnet50_v2` as production single model. |
| C — Stage B | `b45953e` | Ensemble swap evaluated; ensemble kept on v1 (v2 dilutes mel). |
| E.4 — License | `8e77427` | License audit, MIT LICENSE, `data/` gitignore fix. |
| E.1–E.3 — Ext prep | `a6e4baa` | ISIC 2019 HAM-disjoint test set (4,353 rows). |
| E.6 — Ext validation | `1e46918` | Cross-distribution eval + preprocessing audit. |
| F — Deployment | `d101ffb`, `223a66d`, _this release_ | Dependency lock, run scripts, release docs, Docker design. |

## 12. Acknowledgments

HAM10000 — Tschandl, Rosendahl, Kittler & the ViDIR Group, Medical University of
Vienna. ISIC 2019 / BCN_20000 — Hospital Clínic de Barcelona and the
International Skin Imaging Collaboration. The PyTorch, timm, FastAPI, and Flutter
open-source communities. Full attributions in [`docs/licenses.md`](licenses.md).
