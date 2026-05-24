# Phase F (Lightweight) — STATUS

**Started:** 2026-05-25
**Branch:** dev (local only — NO PUSH)
**Scope:** lightweight deployment/productionization — design docs + run scripts,
no actual Docker build.

## 30-second situation
Phase F just started. Setting up status tracking, then working through the four
subtasks in order: F.4 (lock deps) → F.2 (run scripts) → F.3 (release docs +
local tag) → F.1 (Docker design doc).

## Subtask progress
| Subtask | State | Notes |
|---|---|---|
| F.4 lock dependencies | DONE | requirements-lock.txt (54 pkgs; torch/torchvision separate; torchaudio+opencv excluded as unused) |
| F.2 run scripts | DONE | download_checkpoints.py (verify-only tested OK), run_demo.sh/.ps1, release_manifest.json (6 ckpts hashed), README Quick Start |
| F.3 release docs + tag | IN PROGRESS | release_v2.0.md, checklist, LOCAL v2.0 tag |
| F.1 Docker design doc | PENDING | docs/docker_design.md (no build) |

## Blockers
None.

## Note
`docs/phase_f/progress.log` is gitignored by the repo's blanket `*.log` rule;
it is force-added (`git add -f`) each commit so it survives as a deliverable,
consistent with how `runs_v2/*.log` are tracked.

## What the user should review first
(to be filled at completion)
