# Release Checklist — v2.0

One-time checklist the maintainer follows to publish the v2.0 release. Most
artefacts already exist (Phase F); the remaining manual steps are the GitHub
Release upload, URL substitution, and the push.

## Pre-flight (verify current state)
- [ ] On `dev`, working tree clean; Phase F commits present
      (`F.4 lock`, `F.2 run scripts`, `F.3 release docs + tag`, `F.1 docker design`).
- [ ] Smoke test passes locally:
      `SKINLESION_DEVICE=cpu uvicorn src.skinlesion.api:app --port 8126` then
      `python scripts/test_api_demo.py --base-url http://127.0.0.1:8126`.
- [ ] `/model-info` reports `resnet50_version = v2-focal-sampler`.
- [ ] Docs current: `README.md` Quick Start, `docs/release_v2.0.md`,
      `docs/validation.md`, `docs/phase_e_external_validation.md`.
- [ ] `requirements-lock.txt` regenerated if deps changed
      (`.venv/Scripts/python -m pip freeze`; re-apply the torch/exclusion edits).
- [ ] SHA256 manifest current: re-run the manifest generator if any checkpoint
      changed, confirm `runs_v2/release_manifest.json` matches local files
      (`python scripts/download_checkpoints.py --verify-only` → 6/6 match).

## Publish the GitHub Release
- [ ] Create GitHub Release `v2.0` (target the `v2.0` tag).
- [ ] Upload the checkpoint + calibration assets with these **flat** names
      (GitHub asset names cannot contain `/`):
      - [ ] `resnet50__best.pt`, `resnet50__calibration.json`
      - [ ] `resnet50_v2__best.pt`, `resnet50_v2__calibration.json`
      - [ ] `resnet50_v1_backup__best.pt`, `resnet50_v1_backup__calibration.json`
      - [ ] `densenet121__best.pt`, `densenet121__calibration.json`
      - [ ] `efficientnet_b0__best.pt`, `efficientnet_b0__calibration.json`
      - [ ] `mobilenetv3_small_100__best.pt`, `mobilenetv3_small_100__calibration.json`
      - [ ] (optional) the `*__test_metrics.json` / `*__history.json` assets.
- [ ] Paste release notes from `docs/release_v2.0.md`.

## Wire up the downloader
- [ ] Edit `scripts/download_checkpoints.py`: set `GITHUB_USER` / `GITHUB_REPO`
      (or document the `--base-url` form).
- [ ] Re-test against the uploaded assets on a clean dir:
      `python scripts/download_checkpoints.py` → all 6 download + SHA256-verify.
- [ ] Optionally test the full path: `bash scripts/run_demo.sh` on a clean
      machine / fresh `.venv`.

## Tag & push (LAST — requires explicit go-ahead)
- [ ] Confirm the local tag exists: `git tag -l v2.0` (created in Phase F.3).
- [ ] `git push origin dev`
- [ ] `git push origin v2.0`   (or `git push --tags`)
- [ ] Confirm the GitHub Release shows the assets and the tag resolves.

## Post-release
- [ ] Verify a fresh clone + `run_demo` works end-to-end on the demo MacBook.
- [ ] (Future) Docker image — see `docs/docker_design.md`.
