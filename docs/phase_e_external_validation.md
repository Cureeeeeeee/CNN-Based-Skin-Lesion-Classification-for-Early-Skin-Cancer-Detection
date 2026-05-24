# Phase E.6 — External (Cross-Distribution) Validation on ISIC 2019

**Date:** 2026-05-25
**Script:** `scripts/evaluate_external.py` · **Per-config JSON:** `runs_v2/external_eval/*.json`
**External set:** `data/processed/isic2019_clean_test.csv` (4,353 rows, HAM10000-disjoint; see [Phase E.1–E.3 prep](phase_e_data_preparation.md))

## 1. Executive summary

We evaluated the deployed models on a HAM10000-disjoint slice of the ISIC 2019
test set (4,353 images, 0 skipped) to measure how in-distribution performance
generalises. **It does not generalise well.** Every model loses **~25–35 points
of macro F1** moving from HAM10000 test to ISIC 2019, and melanoma recall — the
headline clinical metric — collapses from 55–73% (in-distribution) to **27–43%**
(external). The Phase C v2 winner keeps its *relative* mel-recall edge over v1
ResNet50 externally (+10.5 pp), but its overall macro F1 becomes the **worst** of
all six configs out-of-distribution because it over-specialises on melanoma at
the expense of other classes. The **v1 4-model ensemble is the most robust
config externally** (best macro F1, best balanced accuracy, and by far the best
calibration). Calibration fit on HAM10000 does **not** transfer: single-model
ECE rises ~5–9× on the external set.

| Config | HAM mel | ISIC mel | HAM macF1 | ISIC macF1 | ISIC bAcc | ISIC ECE |
|---|--:|--:|--:|--:|--:|--:|
| v2 single RN50 (deployed) | 73.40 | 37.09 | 70.08 | 34.72 | 37.21 | 0.1814 |
| **v1 ensemble** | 60.64 | 28.63 | 74.10 | **41.24** | **45.34** | **0.0471** |
| v1 single RN50 | 54.79 | 26.61 | 69.03 | 37.18 | 44.62 | 0.1669 |
| v1 single DenseNet121 | 58.51 | 22.47 | 68.96 | 36.81 | 40.97 | 0.1741 |
| v1 single EfficientNet-B0 | 57.45 | 42.82 | 64.77 | 39.89 | 43.26 | 0.1579 |
| v1 single MobileNetV3-S | 56.91 | 37.97 | 57.26 | 28.87 | 32.04 | 0.1435 |

## 2. Methodology

- **Dataset.** The external set is the ISIC 2019 test images that survive
  HAM10000 cross-set deduplication and label alignment (Phase E.1–E.3). 4,353
  images, 7 HAM classes, true label distribution: nv 1,463 / mel 1,135 / bcc 867
  / bkl 421 / akiec 355 / vasc 66 / df 46.
- **Models / configs (6).** `v1_ensemble` (4 backbones, `configs/ham10000.yaml`
  weights), `v2_single_resnet50` (`runs/resnet50_v2`), `v1_single_resnet50`
  (`runs/resnet50_v1_backup`), and v1 singles for DenseNet121, EfficientNet-B0,
  MobileNetV3-Small.
- **Inference.** Shared test transform from `src/skinlesion/data.py`
  (Resize 224 → ToTensor → ImageNet normalise). Each model's
  temperature-scaling calibration is applied before softmax; the ensemble takes
  the weight-normalised average of calibrated probabilities, then argmax — the
  exact `src/skinlesion/ensemble.py` recipe. Each unique checkpoint is run once
  and cached, so all configs draw from identical per-model probabilities.
- **Metrics.** Per-class recall, macro F1, balanced accuracy (= macro recall),
  accuracy, and expected calibration error (ECE, 15 equal-width confidence bins
  on the post-calibration max-probability).
- **Determinism.** batch_size = 32 throughout (see §3 for why this matters).
- **Sanity gate.** Before trusting any external number, `v1_ensemble` was run on
  the in-distribution HAM10000 test split and required to reproduce the Phase C
  Stage B baseline.

## 3. Sanity gate result

`v1_ensemble` on HAM10000 test (1,734 images) reproduced Stage B's
`baseline_4v1` **exactly** at batch_size 32:

| metric | Stage B baseline | this run | match |
|---|--:|--:|:--:|
| mel recall | 60.64 | 60.64 | ✓ |
| bcc recall | 89.01 | 89.01 | ✓ |
| akiec recall | 65.38 | 65.38 | ✓ |
| macro F1 | 74.10 | 74.10 | ✓ |
| balanced acc | 80.34 | 80.34 | ✓ |

All six configs' HAM-test runs also reproduced their documented in-distribution
numbers (v2 RN50 mel 73.40 / F1 70.08 / ECE 0.0248; v1 RN50 mel 54.79 / F1 69.03;
DN121 F1 68.96; EN-B0 F1 64.77; MN F1 57.26). **Gate passed — pipeline verified
correct.**

> *Note on batch size.* At batch_size 64 the gate produced macro F1 74.06 (vs
> 74.10) — a single borderline image flipping argmax due to batch-size-dependent
> cuDNN kernel selection (floating-point, not a logic error). batch_size 32
> reproduces Stage B bit-for-bit, so it is fixed for all runs. mel/bcc/akiec
> recall were identical at both batch sizes.

## 4. Main results

Two rows per config (HAM10000 test in-distribution; ISIC 2019 external). All
values are percentages except ECE.

| Config | Set | mel | bcc | akiec | bkl | df | nv | vasc | macF1 | bAcc | acc | ECE |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| v2 single RN50 | HAM | 73.40 | 82.42 | 69.23 | 65.83 | 72.00 | 79.60 | 92.59 | 70.08 | 76.44 | 77.28 | 0.0248 |
| v2 single RN50 | ISIC | 37.09 | 49.83 | 5.63 | 39.67 | 21.74 | 76.21 | 30.30 | 34.72 | 37.21 | 50.20 | 0.1814 |
| v1 ensemble | HAM | 60.64 | 89.01 | 65.38 | 74.37 | 84.00 | 88.98 | 100.00 | 74.10 | 80.34 | 83.62 | 0.0838 |
| v1 ensemble | ISIC | 28.63 | 57.67 | 13.24 | 51.78 | 32.61 | 81.95 | 51.52 | 41.24 | 45.34 | 53.71 | 0.0471 |
| v1 single RN50 | HAM | 54.79 | 86.81 | 59.62 | 65.83 | 80.00 | 86.89 | 96.30 | 69.03 | 75.75 | 80.22 | 0.0183 |
| v1 single RN50 | ISIC | 26.61 | 57.32 | 11.83 | 38.24 | 39.13 | 77.10 | 62.12 | 37.18 | 44.62 | 50.29 | 0.1669 |
| v1 single DN121 | HAM | 58.51 | 84.62 | 59.62 | 74.87 | 68.00 | 84.29 | 96.30 | 68.96 | 75.17 | 79.64 | 0.0337 |
| v1 single DN121 | ISIC | 22.47 | 52.94 | 12.68 | 50.36 | 19.57 | 77.24 | 51.52 | 36.81 | 40.97 | 49.25 | 0.1741 |
| v1 single EN-B0 | HAM | 57.45 | 69.23 | 69.23 | 62.81 | 72.00 | 84.03 | 92.59 | 64.77 | 72.48 | 77.45 | 0.0346 |
| v1 single EN-B0 | ISIC | 42.82 | 38.87 | 21.97 | 54.87 | 28.26 | 70.61 | 45.45 | 39.89 | 43.26 | 50.72 | 0.1579 |
| v1 single MN-S | HAM | 56.91 | 86.81 | 57.69 | 47.24 | 72.00 | 71.18 | 100.00 | 57.26 | 70.26 | 67.76 | 0.0412 |
| v1 single MN-S | ISIC | 37.97 | 50.63 | 23.10 | 34.68 | 17.39 | 31.72 | 28.79 | 28.87 | 32.04 | 36.50 | 0.1435 |

**Prediction-distribution check (Task 3).** True external mel count = 1,135
(26.1%, as prepared). Models over-predict the dominant HAM class `nv` on the
shifted distribution: v2 RN50 predicts nv 1,862 / mel 670 (true nv 1,463 / mel
1,135); the ensemble predicts nv 1,797 / mel 412. No degenerate single-class
collapse — distributions are plausible given the HAM nv-prior bias.

## 5. Per-class recall deltas (HAM → ISIC, percentage points)

| Config | mel | bcc | akiec | bkl | df | nv | vasc |
|---|--:|--:|--:|--:|--:|--:|--:|
| v2 single RN50 | −36.3 | −32.6 | −63.6 | −26.2 | −50.3 | −3.4 | −62.3 |
| v1 ensemble | −32.0 | −31.3 | −52.1 | −22.6 | −51.4 | −7.0 | −48.5 |
| v1 single RN50 | −28.2 | −29.5 | −47.8 | −27.6 | −40.9 | −9.8 | −34.2 |
| v1 single DN121 | −36.0 | −31.7 | −46.9 | −24.5 | −48.4 | −7.1 | −44.8 |
| v1 single EN-B0 | −14.6 | −30.4 | −47.3 | −7.9 | −43.7 | −13.4 | −47.1 |
| v1 single MN-S | −18.9 | −36.2 | −34.6 | −12.6 | −54.6 | −39.5 | −71.2 |

Patterns: **`akiec` collapses hardest everywhere** (−35 to −64 pp), consistent
with the AK→akiec label-definition shift documented in E.1–E.3 (HAM `akiec` =
AK + intraepithelial carcinoma; ISIC `akiec` = AK only). **`nv` is the most
robust class** (−3 to −13 pp for the CNN/ensemble configs) — the HAM-dominant
class transfers and models lean on it. `df` and `vasc` are noisy (tiny external
support: 46 and 66).

## 6. Discussion

**Distribution shift is severe and real.** A ~25–35 pp macro-F1 drop is much
larger than the 5–15 pp "typical clinical ML shift" the roadmap anticipated.
The external set is not just a covariate shift: it has a different class prior
(mel 26% vs 11%, nv 34% vs 66%), different source institutions (BCN_20000 / MSK
vs HAM's Vienna/Queensland), and a label-definition shift on `akiec`. All three
compound.

**Does the v2 winner's mel advantage hold externally? Relatively yes, absolutely
no.** v2 RN50 beats v1 RN50 on external mel recall (37.09 vs 26.61, **+10.5 pp**),
so the focal-loss + balanced-sampler recipe does transfer its *ordering*. But
both land far below clinical usefulness, and v2's specialisation backfires on
overall metrics: it posts the **worst external macro F1 (34.72)** and an `akiec`
recall of **5.63%**, because pushing the decision boundary toward melanoma
sensitivity costs precision and other-class recall once the distribution moves.

**Most / least robust.** Most robust overall is the **v1 ensemble** — best
external macro F1 (41.24) and balanced accuracy (45.34), and dramatically the
best calibration (ECE 0.047 vs 0.14–0.18 for singles). Averaging four backbones
damps individual models' OOD failure modes. The single model that degrades
*least in relative terms* is **EfficientNet-B0** (macro F1 −24.9 pp; external mel
−14.6 pp, the smallest mel drop). **MobileNetV3-Small collapses worst** (external
macro F1 28.87, nv recall 31.72 — near-useless on its dominant class).

**Calibration does not survive the shift.** This is one of the clearest
findings. Single-model ECE jumps from ~0.02–0.04 (HAM) to **0.14–0.18** (ISIC) —
the temperature scalars fit on HAM val are meaningless out-of-distribution, and
models are badly overconfident. v2 RN50 is worst (0.1814) because its T=0.898
*sharpens* confidence. The ensemble's averaging is the only thing that keeps ECE
moderate (0.047), though still ~2× its in-distribution value (0.0838 → wait,
ensemble HAM ECE 0.0838 is already its weakest in-distribution number; on ISIC
0.0471 is lower largely because ensemble confidences are systematically more
hedged). Confidence scores shown to a user on external images would be
misleading.

## 7. Clinical implications

- **External melanoma recall (27–43%) is not clinically acceptable.** On
  out-of-distribution dermoscopy the system would miss the majority of
  melanomas. The strong in-distribution v2 number (73%) gives a false sense of
  safety — it does **not** generalise.
- This empirically reinforces the project's standing disclaimer: **educational
  prototype, not a medical device.** It is the strongest evidence in the project
  that the model must not be relied on for real diagnostic decisions.
- **Confidence is untrustworthy off-distribution** (ECE ≈ 0.15–0.18 single
  model). Any UI confidence shown for non-HAM-like images is misleading and
  should be caveated.
- If a single deployable model had to face mixed-source data, the **v1
  ensemble** is the safer default (better balanced accuracy and far better
  calibration) than the mel-specialised v2 single model — a different conclusion
  than the in-distribution-only Stage A/B analysis reached.

## 8. Limitations

- **Lesion-level dedup not feasible** (carried from E.1–E.3): ISIC Test Metadata
  has no `lesion_id`, so a HAM lesion contributing a different photo to ISIC test
  under a new `image_id` cannot be excluded. Exact-image leakage *is* removed.
- **Not a fully independent population.** ISIC 2019 aggregates BCN_20000 + MSK +
  HAM; HAM is removed by dedup, but BCN/MSK still share the broader ISIC archive
  acquisition ecosystem with HAM's sources, so this understates true wild-world
  shift.
- **`akiec` label-definition mismatch** inflates the apparent akiec degradation
  (AK-only external vs AK+IEC in training).
- **No skin-tone / Fitzpatrick metadata** in ISIC 2019 — the Phase E.5 bias
  audit cannot stratify by skin tone from this data; deferred to a
  Fitzpatrick-annotated dataset.
- **Tiny support for df (46) and vasc (66)** externally — their recall deltas
  are high-variance and should not be over-interpreted.
- ECE uses post-hoc temperature-scaled probabilities only; no OOD-specific
  recalibration was attempted (out of scope for E.6).

## 9. Reproducibility

```bash
# Sanity gate (must reproduce Stage B baseline_4v1):
python -m scripts.evaluate_external --config v1_ensemble --test-set ham_test --batch-size 32

# All six configs, external ISIC set:
python -m scripts.evaluate_external --config all --test-set isic_external --batch-size 32

# All six configs, HAM test (in-distribution baselines for the deltas):
python -m scripts.evaluate_external --config all --test-set ham_test --batch-size 32
```

Outputs: `runs_v2/external_eval/<config>_external.json` and
`<config>_ham_test.json` (12 files). Each JSON carries per-class recall, macro
F1, balanced accuracy, accuracy, ECE, true/predicted label counts, the confusion
matrix, and the member checkpoints + temperatures used.

```bash
# Preprocessing audit (§10):
python -m scripts.audit_image_stats --n 200 --seed 42         # HAM vs ISIC pixel stats
python -m scripts.audit_norm_sensitivity --stat-n 300 --seed 42  # norm sensitivity + misclassified
```

## 10. Preprocessing audit confirms the result (2026-05-25)

Because a 25–35 pp drop is large, we audited whether it could be a preprocessing
inconsistency between HAM and ISIC rather than genuine distribution shift.
**Conclusion: the drop is real semantic distribution shift; preprocessing is
consistent and is not the cause.**

**Pipeline is identical for both sets.** The eval transform (src/skinlesion/data.py,
applied via `scripts/evaluate_external.py` to both) is `Resize((224,224)) →
ToTensor → Normalize(ImageNet mean/std)`. Normalization uses the **ImageNet**
constants `[0.485,0.456,0.406]/[0.229,0.224,0.225]` — **not** HAM-derived
statistics — so the Task-4 "ImageNet vs HAM-norm" swap is moot (the model already
runs ImageNet norm). The square resize distorts aspect ratio, but it does so for
*both* sets, and in fact distorts HAM (600×450, 4:3) while leaving ISIC
(1024×1024, 1:1) undistorted — i.e. if anything the geometry favours ISIC.

**Pixel statistics differ — as a property of the images, not the pipeline**
(`scripts/audit_image_stats.py`, n=200 each):

| | per-channel mean (R,G,B) | per-channel std |
|---|---|---|
| HAM test | 0.777, 0.552, 0.575 | 0.086, 0.113, 0.126 |
| ISIC clean | 0.583, 0.512, 0.497 | 0.188, 0.187, 0.193 |
| \|Δ\| | **0.194**, 0.041, 0.078 | 0.102, 0.075, 0.067 |

The red-channel mean gap (0.19) exceeds the 0.10 "concern" threshold, so we
tested whether it is *causal*.

**Colour is not the cause (sensitivity test, `scripts/audit_norm_sensitivity.py`).**
Re-evaluating v2 RN50 on ISIC after mapping each ISIC image's per-channel colour
moments onto HAM's (then ImageNet-normalising) — i.e. making ISIC colour-match
the training distribution — **does not recover performance; it degrades it**:

| Variant | mel recall | macro F1 | bal acc |
|---|--:|--:|--:|
| imagenet (deployed) | 37.09 | 34.72 | 37.21 |
| ham_moment_match | 17.71 | 33.74 | 37.89 |
| Δ | **−19.38** | −0.97 | +0.68 |

If colour mismatch were inflating the drop, moment-matching would *raise* mel
recall; instead it falls 19 pp. The external degradation is therefore driven by
lesion-level appearance differences (semantic shift), not by colour/illumination
statistics. (The `imagenet` row reproduces the §4 external number 37.09/34.72
exactly, cross-validating the audit pipeline.)

**Misclassified samples are legitimate, not degenerate.** Five v2-misclassified
ISIC images were inspected: all are normal 1024×1024 dermoscopy images (no
all-black frames, no extreme aspect ratios), with non-degenerate probability
vectors dominated by the clinically classic **melanoma→nevus** confusion (e.g.
a true `mel` assigned `nv` at p=0.89). Total v2 misclassification on ISIC is
2,168/4,353 (49.8%), consistent with the 50.2% accuracy in §4 — i.e. the errors
are spread across genuinely hard cases, not a single broken element.

**Verdict:** the 37% external melanoma recall is a real cross-distribution
result. The clinical and deployment conclusions in §6–§7 stand.
