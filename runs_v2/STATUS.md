# Phase C Night 1 — STATUS

**Wall-clock start:** 2026-05-24 12:12:52
**Branch:** phase-c-night-1
**Current experiment:** — (4 core complete) → writing 5th commit (SUMMARY + figures)
**Current step:** core done; final comparison deliverable
**Elapsed:** ~0.75 h
**FAILED list:** (no errors) · Results: exp1 FAIL, exp2 FAIL, exp3 PASS, exp4 FAIL

## Core experiments

| # | Experiment | Model | Config | Status | Updated |
|---|---|---|---|---|---|
| 1 | resnet50_v2_focal_loss | resnet50 | ham10000_v2_focal.yaml | DONE (FAIL) | 2026-05-24 12:26 |
| 2 | resnet50_v2_balanced_sampler | resnet50 | ham10000_v2_sampler.yaml | DONE (FAIL) | 2026-05-24 12:38 |
| 3 | resnet50_v2_focal_plus_sampler | resnet50 | ham10000_v2_focal_sampler.yaml | DONE (PASS) | 2026-05-24 12:49 |
| 4 | mobilenetv3_small_100_v2_focal_plus_sampler | mobilenetv3_small_100 | ham10000_v2_focal_sampler.yaml | DONE (FAIL) | 2026-05-24 12:57 |

**Status legend:** PENDING → RUNNING → DONE / FAILED

## Acceptance thresholds (per experiment)
- mel recall ≥ 68% (v1 RN50 baseline 54.79%)
- macro F1 ≥ 67% (v1 RN50 baseline 69.03%)
- PASS = both met; FAIL = either missed (still a completed result).

## Halt sentinels (presence = stop)
- runs_v2/HALT.txt · runs_v2/STUCK.txt · runs_v2/TIMEOUT.txt — none present.
