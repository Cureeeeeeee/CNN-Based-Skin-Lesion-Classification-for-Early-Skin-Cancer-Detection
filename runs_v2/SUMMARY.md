# Phase C Night 1 — v1 vs v2 Comparison Summary

Melanoma-recall rebalancing experiments on HAM10000 (test split, 1734 images).
Each v2 experiment introduces exactly **one** rebalancing mechanism (strict single-variable design).

**Acceptance:** mel recall ≥ 68% AND macro F1 ≥ 67% → PASS.

---

## v1 baselines (from runs/<model>/test_metrics.json)

| Model | Accuracy | Macro F1 | Balanced acc | mel recall | bcc recall | akiec recall |
|---|---|---|---|---|---|---|
| resnet50 (deployed) | 80.22% | 69.03% | 75.75% | **54.79%** | 86.81% | 59.62% |
| densenet121 | 79.64% | 68.96% | 75.17% | 58.51% | 84.62% | 59.62% |
| efficientnet_b0 | 77.45% | 64.77% | 72.48% | 57.45% | 69.23% | 69.23% |
| mobilenetv3_small_100 | 67.76% | 57.26% | 70.26% | 56.91% | 86.81% | 57.69% |

### v1 per-class recall (all 7 classes)

| Model | akiec | bcc | bkl | df | mel | nv | vasc |
|---|---|---|---|---|---|---|---|
| resnet50 | 59.62% | 86.81% | 65.83% | 80.00% | 54.79% | 86.89% | 96.30% |
| densenet121 | 59.62% | 84.62% | 74.87% | 68.00% | 58.51% | 84.29% | 96.30% |
| efficientnet_b0 | 69.23% | 69.23% | 62.81% | 72.00% | 57.45% | 84.03% | 92.59% |
| mobilenetv3_small_100 | 57.69% | 86.81% | 47.24% | 72.00% | 56.91% | 71.18% | 100.00% |

---

## v2 experiment results

| # | Experiment | mel recall | bcc recall | akiec recall | Macro F1 | Balanced acc | val ECE (cal) | test ECE (cal) | Train time | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | resnet50_v2_focal_loss | 64.89% | 86.81% | 63.46% | 64.68% | 73.98% | 0.0204 | 0.0297 | ~9 min | **FAIL** (mel <68, F1 <67) |
| 2 | resnet50_v2_balanced_sampler | 50.00% | 86.81% | 61.54% | 71.18% | 73.28% | 0.0161 | 0.0319 | ~10 min | **FAIL** (mel 50% < 68%, below v1) |
| 3 | resnet50_v2_focal_plus_sampler | **73.40%** | 82.42% | 69.23% | **70.08%** | 76.44% | 0.0214 | 0.0248 | ~9 min | ✅ **PASS** (mel ≥68, F1 ≥67) |
| 4 | mobilenetv3_small_100_v2_focal_plus_sampler | 48.94% | 74.73% | 50.00% | 60.31% | 72.95% | 0.0231 | 0.0337 | ~6 min | **FAIL** (mel & F1 both <thr) |

### v2 per-class recall (all 7 classes) — filled as experiments complete

| Experiment | akiec | bcc | bkl | df | mel | nv | vasc |
|---|---|---|---|---|---|---|---|
| resnet50_v2_focal_loss | 63.46% | 86.81% | 65.33% | 72.00% | 64.89% | 76.48% | 88.89% |
| resnet50_v2_balanced_sampler | 61.54% | 86.81% | 66.33% | 72.00% | 50.00% | 91.06% | 85.19% |
| resnet50_v2_focal_plus_sampler | 69.23% | 82.42% | 65.83% | 72.00% | 73.40% | 79.60% | 92.59% |
| mobilenetv3_small_100_v2_focal_plus_sampler | 50.00% | 74.73% | 69.85% | 88.00% | 48.94% | 79.17% | 100.00% |

---

## Recommendation

_To be written after the 4 core experiments complete: did any v2 meet both thresholds (mel recall ≥ 68% AND macro F1 ≥ 67%)? Which is the Phase C2 propagation candidate?_
