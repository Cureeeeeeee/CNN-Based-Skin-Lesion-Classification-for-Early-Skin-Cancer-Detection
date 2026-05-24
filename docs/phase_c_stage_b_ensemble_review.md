# Phase C Stage B — Ensemble ResNet50 v1→v2 Swap Review

**Date:** 2026-05-25
**Question:** When the 4-model weighted ensemble swaps its ResNet50 slot from v1
to the v2 focal+sampler winner, does the ensemble's melanoma recall improve, or
does the 4-model weighted average dilute the v2 signal?

**Evaluation:** `scripts/evaluate_ensemble_v2.py` on the HAM10000 test split
(1,734 images — the same set used throughout Phase C). Each model's calibration
(temperature scaling) is applied before softmax, then probabilities are
weighted-averaged and argmax'd — identical to `src/skinlesion/ensemble.py`.
Per-config JSON: `runs_v2/ensemble_review/*.json`.

**Correctness check:** every model's standalone argmax macro F1 reproduces its
committed `runs/<m>/test_metrics.json` exactly (delta = 0.0 for all five), and
the `single_v2rn50_reference` config reproduces the v2 single-model numbers
exactly. The pipeline is verified before any comparison is drawn.

## Results

| Config | mel recall | bcc recall | akiec recall | macro F1 | bal acc | agreement rate |
|---|---|---|---|---|---|---|
| Baseline (4 v1, orig weights) | 60.64 | 89.01 | 65.38 | **74.10** | **80.34** | 58.25 |
| Single-model v2 RN50 (for reference) | **73.40** | 82.42 | 69.23 | 70.08 | 76.44 | N/A |
| Swap v2 RN50 + 3 v1, orig weights | 67.02 | 87.91 | 67.31 | 73.59 | 79.63 | 56.98 |
| Swap, F1-naive weights | 64.89 | 87.91 | 63.46 | 72.72 | 79.05 | 56.98 |
| Swap, F1-relative weights | 67.02 | 87.91 | 67.31 | 73.71 | 79.70 | 56.98 |

All values are percentages. Bold marks the best value in each column among the
deployable configs (the reference row is a single model, shown for context).

### Weight derivations
- **Original (curated):** RN50 0.38, DN121 0.37, EN-B0 0.20, MobileNet 0.05.
- **F1-naive:** weights ∝ single-model macro F1 with v2's 70.08 in the RN50 slot
  → RN50 0.2684, DN121 0.2641, EN-B0 0.2481, MobileNet 0.2193. (Note this
  *upweights* the weakest model, MobileNet, from 0.05 to 0.22.)
- **F1-relative:** each original weight × (new_F1/old_F1), renormalised. Only
  RN50's F1 changes (69.03→70.08, ratio 1.0152); the other three keep their v1
  F1 (ratio 1.0) → RN50 0.3836, DN121 0.3679, EN-B0 0.1988, MobileNet 0.0497.
  Essentially the original weights with a hair more RN50.

## What the data says

**The 4-model weighted average dilutes the v2 signal.** Dropping the v2 RN50
into the ensemble lifts ensemble mel recall from 60.64% (baseline) to 67.02%
(conservative swap, +6.38 pp) — a real improvement — but it never reaches the
**73.40%** that the v2 model delivers on its own. Three v1 backbones, two of
which (DN121 58.5%, EN-B0 57.4%) have mediocre mel recall, pull the averaged
melanoma probability back down. The remaining gap to the single model is 6.4 pp.

**The swap also slightly degrades the ensemble's core strengths.** The ensemble's
whole value proposition is its high macro F1 (74.10) and balanced accuracy
(80.34) — both well above any single model. Swapping in v2 RN50 costs ~0.5 pp
macro F1 (74.10→73.59) and ~0.7 pp balanced accuracy (80.34→79.63), because the
v2 model trades overall precision/F1 for mel sensitivity (its single-model macro
F1 is 70.08 vs v1's 69.03 but its precision profile is flatter). bcc recall also
slips (89.01→87.91).

**Weight tuning does not rescue the swap.**
- *F1-naive* is strictly worse than the conservative swap on every metric
  (mel 64.89 < 67.02, macro F1 72.72 < 73.59) — naive F1-normalisation
  over-weights the weak MobileNet backbone, confirming why the original team
  curated the weights rather than F1-normalising.
- *F1-relative* is numerically indistinguishable from the conservative swap
  (mel identical at 67.02, macro F1 73.71 vs 73.59) because it barely moves the
  weights. There is no weighting of the existing four checkpoints that recovers
  the single model's mel recall.

Agreement rate drops slightly with the swap (58.25%→56.98%): the more
mel-sensitive v2 RN50 disagrees with the v1 majority more often, which is
expected and not itself a problem.

## Recommendation

**Deploy the single-model v2 path for the melanoma-recall objective (already
done in Stage A), and keep the ensemble on v1 for now. Do not swap v2 RN50 into
the ensemble production config.**

Rationale, directly from the data:

1. **For the clinical priority (mel recall), the single model wins decisively.**
   73.40% (single v2) vs at-best 67.02% (any swap config). The entire point of
   Phase C was melanoma sensitivity; the ensemble swap recovers only ~40% of the
   single-model's gain over the v1 ensemble baseline.

2. **The swap is a net negative for the ensemble's own purpose.** It costs macro
   F1 and balanced accuracy — the metrics on which the ensemble beats every
   single model — while still trailing the single model on mel. So the swap is
   worse than the single model on mel *and* worse than the v1 ensemble on
   balanced metrics: there is no configuration in which the swapped ensemble is
   the best available option.

3. **The ensemble needs per-backbone improvement, not a single-slot swap.** The
   dilution is structural: 3 of 4 members carry weak mel signal. To get a
   high-mel-recall *ensemble*, the path is Phase C2 — train focal+sampler v2
   variants of DenseNet121 and EfficientNet-B0 (the two carrying meaningful
   ensemble weight) so the averaged melanoma probability is no longer dragged
   down by v1 members. The Phase C stretch runs already showed DN121 v2 reaches
   61.2% and EN-B0 v2 reaches 58.5% mel recall; an all-v2 ensemble is the
   experiment worth running before any ensemble production swap.

**Net:** Stage A's single-model v2 deployment stands as the melanoma-recall
deliverable. The ensemble production config (`configs/ham10000.yaml`
`ensemble.checkpoints`) should remain unchanged — this is the decision Stage A's
commit explicitly reserved. Revisit the ensemble only after Phase C2 produces v2
variants of the other backbones.
