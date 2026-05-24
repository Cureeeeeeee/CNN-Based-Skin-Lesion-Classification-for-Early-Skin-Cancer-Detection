# Phase C Night 1 — STATUS

**Wall-clock start:** 2026-05-24 12:12:52
**Branch:** phase-c-night-1
**Current experiment:** 3 — resnet50_v2_focal_plus_sampler
**Current step:** about to launch training
**Elapsed:** ~0.45 h
**FAILED list:** (none — exp1/exp2 completed as FAIL results, not errors)

## Core experiments

| # | Experiment | Model | Config | Status | Updated |
|---|---|---|---|---|---|
| 1 | resnet50_v2_focal_loss | resnet50 | ham10000_v2_focal.yaml | DONE (FAIL) | 2026-05-24 12:26 |
| 2 | resnet50_v2_balanced_sampler | resnet50 | ham10000_v2_sampler.yaml | DONE (FAIL) | 2026-05-24 12:38 |
| 3 | resnet50_v2_focal_plus_sampler | resnet50 | ham10000_v2_focal_sampler.yaml | PENDING | 2026-05-24 12:12 |
| 4 | mobilenetv3_small_100_v2_focal_plus_sampler | mobilenetv3_small_100 | ham10000_v2_focal_sampler.yaml | PENDING | 2026-05-24 12:12 |

**Status legend:** PENDING → RUNNING → DONE / FAILED

## Acceptance thresholds (per experiment)
- mel recall ≥ 68% (v1 RN50 baseline 54.79%)
- macro F1 ≥ 67% (v1 RN50 baseline 69.03%)
- PASS = both met; FAIL = either missed (still a completed result).

## Halt sentinels (presence = stop)
- runs_v2/HALT.txt · runs_v2/STUCK.txt · runs_v2/TIMEOUT.txt — none present.
