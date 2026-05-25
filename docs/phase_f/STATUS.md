# Phase F (Lightweight) — STATUS

**Started:** 2026-05-25 · **Completed:** 2026-05-25
**Branch:** dev (local only — **NOT pushed**)
**Scope:** lightweight deployment/productionization — design docs + run scripts,
no actual Docker build.

## 30-second situation
**ALL 4 F SUBTASKS COMPLETE.** F.4/F.2/F.3 are functional; F.1 is a design
document for future enhancement (no Docker build, by design). 4 new local
commits on `dev` + a local `v2.0` tag. **Nothing pushed** — awaiting user review.

## Subtask progress
| Subtask | State | Commit | Notes |
|---|---|---|---|
| F.4 lock dependencies | DONE | `d101ffb` | requirements-lock.txt (54 pins; torch/torchvision separate CPU install; torchaudio+opencv excluded as unused). |
| F.2 run scripts | DONE | `223a66d` | download_checkpoints.py (`--verify-only` passes 6/6), run_demo.sh/.ps1, release_manifest.json, README Quick Start. |
| F.3 release docs + tag | DONE | `12ff289` | release_v2.0.md (12 sec), release_checklist.md, LOCAL annotated tag `v2.0` → `12ff289`. |
| F.1 Docker design doc | DONE | (this commit) | docs/docker_design.md — design only, no build. |

## Blockers
None.

## What the user should review first
1. **`requirements-lock.txt`** — confirm the torch-separate strategy and the
   torchaudio/opencv exclusions match your intent for the Mac demo.
2. **`scripts/download_checkpoints.py`** — has PLACEHOLDER GitHub URLs
   (`GITHUB_USER`/`GITHUB_REPO`). Must be filled after creating the Release.
   `runs_v2/release_manifest.json` has the real SHA256s.
3. **`docs/release_checklist.md`** — the manual steps remaining (Release upload
   with flat asset names, URL substitution, the two `git push` commands).
4. **Local `v2.0` tag** points to the F.3 commit `12ff289` (NOT the F.1 commit),
   per the task spec. Re-tag if you want it on HEAD after review.
5. **`docs/docker_design.md`** — Docker is deferred; confirm that's acceptable.

## Decisions / deviations to note
- `progress.log` is gitignored by the repo's `*.log` rule; force-added (`-f`)
  each commit so it persists as a deliverable (consistent with `runs_v2/*.log`).
- Healthcheck in the Docker design uses `/health` (dedicated liveness) rather
  than `/model-info`; noted inline.
- v2.0 tag is on the F.3 commit (per spec); the F.1 Docker-design commit lands
  after the tag, so the tagged release excludes the deferred Docker doc.

## NOT done (out of scope / by design)
- No `git push` (any remote). No Docker build. No src/configs/runs/Flutter edits.
