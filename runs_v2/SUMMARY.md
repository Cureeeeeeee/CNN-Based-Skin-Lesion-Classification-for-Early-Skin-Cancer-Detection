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

**One variant meets both thresholds: `resnet50_v2_focal_plus_sampler` (focal γ=2.0 + balanced sampler).**
mel recall **73.40%** (≥68 ✓, +18.6 pp over v1) and macro F1 **70.08%** (≥67 ✓, +1.05 pp over v1),
with balanced accuracy 76.44% (the best of all runs) and clean post-hoc calibration
(test ECE 0.0248, T=0.898). **This is the Phase C2 propagation candidate.**

**Why the single-mechanism variants failed — and why the combination works.**
- *Focal alone* (exp 1) lifts mel recall to 64.9% but collapses macro F1 to 64.7%: the
  hard-example weighting over-corrects, dragging nv recall from 86.9%→76.5%.
- *Balanced sampler alone* (exp 2) holds macro F1 high (71.2%, even above v1) but mel recall
  *drops below v1* to 50.0% — oversampling minority classes uniformly does not specifically
  help the hardest minority (mel), while nv recall climbs to 91.1%.
- *Focal + sampler* (exp 3) is the only combination that lifts mel **and** preserves F1: the
  sampler supplies class balance while focal concentrates gradient on the still-hard melanoma
  examples. The two mechanisms are complementary, not redundant — neither alone suffices.

**Confusion-matrix delta (winner vs v1, see `docs/figures/c_phase/confusion_delta_resnet50.png`).**
On the test set the winner correctly classifies **+35 more melanomas** and makes **15 fewer
mel→nv misses** (the clinically dangerous error), at the cost of +72 nv→mel false positives.
For a melanoma-screening prototype this is the desirable sensitivity/precision trade.

**Architecture caveat.** The same recipe did **not** transfer to MobileNetV3-small (exp 4):
mel recall 48.9% (below its own v1 56.9%), macro F1 60.3%. The smaller backbone lacks the
capacity to exploit the rebalancing. **Propagation must be re-validated per architecture, not assumed.**

**Next step (Phase C2):** adopt focal+sampler as the ResNet50 candidate and re-validate it on the
remaining ensemble backbones (DenseNet121, EfficientNet-B0) before any ensemble-level change. The
stretch queue below does exactly this when budget allows.

---

## Stretch queue results

Entry conditions were all met (4 core DONE, summary + 5th commit written, no halt sentinels,
wall-clock <7h, exp3 PASS), so the winning recipe (**focal γ=2.0 + balanced sampler**) was
re-run on the two remaining ensemble backbones to test cross-architecture transfer.

| Stretch | Model | mel recall | macro F1 | Balanced acc | val ECE (cal) | test ECE (cal) | Verdict |
|---|---|---|---|---|---|---|---|
| S1 | densenet121_v2_focal_plus_sampler | 61.17% | 70.29% | 73.99% | 0.0269 | 0.0239 | **FAIL** (mel <68) |
| S2 | efficientnet_b0_v2_focal_plus_sampler | 58.51% | 63.26% | 67.95% | 0.0157 | 0.0232 | **FAIL** (both <thr) |

**mel recall vs each backbone's own v1 baseline (focal+sampler recipe):**

| Backbone | v1 mel | v2 mel | Δ | F1 v1→v2 |
|---|---|---|---|---|
| ResNet50 | 54.79% | **73.40%** | **+18.6 pp** ✅ | 69.03→70.08 |
| DenseNet121 | 58.51% | 61.17% | +2.7 pp | 68.96→70.29 |
| EfficientNet-B0 | 57.45% | 58.51% | +1.1 pp | 64.77→63.26 |
| MobileNetV3-small | 56.91% | 48.94% | −8.0 pp | 57.26→60.31 |

**Conclusion — the recipe does NOT transfer.** Only ResNet50 clears the 68% mel bar; the gain
shrinks monotonically with backbone capacity (DN121 +2.7, EN-B0 +1.1, MobileNet −8.0). macro F1 is
preserved or improved everywhere except EfficientNet-B0. The strong melanoma-recall lift is a
**ResNet50-specific** property of focal+sampler, not a general rebalancing law. Phase C2 should treat
focal+sampler as a per-architecture tuning choice, validated individually, rather than a recipe to
broadcast across the ensemble. See `docs/figures/c_phase/per_class_recall_all_v2.png`.
