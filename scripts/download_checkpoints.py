"""Download the v2.0 model checkpoints from the project's GitHub Release.

The trained checkpoints are gitignored (too large for the repo), so a fresh
clone needs them fetched before the API can serve predictions. This script
pulls each `best.pt` (and its `calibration.json`) from the GitHub Release and
verifies the download against `runs_v2/release_manifest.json`.

╔══════════════════════════════════════════════════════════════════════════╗
║ BEFORE FIRST USE (one-time, by the maintainer):                          ║
║  1. Create GitHub Release `v2.0` and upload the assets with the FLAT       ║
║     names below (GitHub asset names cannot contain "/"):                   ║
║        resnet50__best.pt                 resnet50__calibration.json        ║
║        resnet50_v2__best.pt              resnet50_v2__calibration.json     ║
║        resnet50_v1_backup__best.pt       resnet50_v1_backup__calibration.json
║        densenet121__best.pt              densenet121__calibration.json     ║
║        efficientnet_b0__best.pt          efficientnet_b0__calibration.json ║
║        mobilenetv3_small_100__best.pt    mobilenetv3_small_100__calibration.json
║  GITHUB_USER / GITHUB_REPO below are already set to this project's real     ║
║  release, so no editing is needed for default use. Forks should update      ║
║  those constants (or pass --base-url at runtime) to point at their release. ║
╚══════════════════════════════════════════════════════════════════════════╝

What it downloads per model directory:
  - best.pt          (required; SHA256-verified against the manifest)
  - calibration.json (required for the calibrated demo; temperature scaling)
Optional (only with --include-metadata; not needed for inference):
  - test_metrics.json, history.json

Usage:
  python scripts/download_checkpoints.py                 # download missing/changed
  python scripts/download_checkpoints.py --skip-existing # skip files already valid
  python scripts/download_checkpoints.py --verify-only   # no download; hash-check local
  python scripts/download_checkpoints.py --base-url https://github.com/me/repo/releases/download/v2.0
  python scripts/download_checkpoints.py --include-metadata
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.request
from pathlib import Path

# Real values for this project's GitHub Release. Forks should update these
# (or pass --base-url at runtime).
GITHUB_USER = "Cureeeeeeee"
GITHUB_REPO = "CNN-Based-Skin-Lesion-Classification-for-Early-Skin-Cancer-Detection"
RELEASE_TAG = "v2.0"

MANIFEST_PATH = Path("runs_v2/release_manifest.json")
# Companion files fetched alongside best.pt. (required, optional-with-flag)
REQUIRED_COMPANIONS = ["calibration.json"]
OPTIONAL_COMPANIONS = ["test_metrics.json", "history.json"]


def asset_name(checkpoint_rel: str, filename: str) -> str:
    """Flat GitHub-Release asset name, e.g. runs/resnet50_v2/best.pt +
    calibration.json -> 'resnet50_v2__calibration.json'."""
    model_dir = Path(checkpoint_rel).parent.name
    return f"{model_dir}__{filename}"


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def verify_file(path: Path, expected_sha: str | None) -> tuple[bool, str]:
    if not path.exists():
        return False, "missing"
    if expected_sha in (None, "MANUAL_VERIFICATION_REQUIRED"):
        return True, "present (no manifest hash to check)"
    actual = sha256_of(path)
    if actual == expected_sha:
        return True, "ok (sha256 match)"
    return False, f"SHA256 MISMATCH (got {actual[:16]}…, want {expected_sha[:16]}…)"


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    print(f"    downloading {url}")
    urllib.request.urlretrieve(url, tmp)  # noqa: S310 — trusted GitHub Release URL
    tmp.replace(dest)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Download v2.0 checkpoints from GitHub Release.")
    p.add_argument("--base-url", default=None,
                   help="override the release base URL (…/releases/download/v2.0)")
    p.add_argument("--skip-existing", action="store_true",
                   help="skip files that already exist and pass verification")
    p.add_argument("--verify-only", action="store_true",
                   help="verify local files against the manifest; do not download")
    p.add_argument("--include-metadata", action="store_true",
                   help="also fetch test_metrics.json + history.json (not needed for inference)")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    if not MANIFEST_PATH.exists():
        print(f"ERROR: manifest not found at {MANIFEST_PATH}", file=sys.stderr)
        return 2
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    checkpoints: dict = manifest["checkpoints"]

    base_url = args.base_url or (
        f"https://github.com/{GITHUB_USER}/{GITHUB_REPO}/releases/download/{RELEASE_TAG}"
    )
    placeholder = ("<GITHUB_USER>" in base_url) or ("<GITHUB_REPO>" in base_url)
    if placeholder and not args.verify_only:
        print("ERROR: Release URL still contains placeholders. Edit GITHUB_USER/"
              "GITHUB_REPO in this script or pass --base-url. (Use --verify-only "
              "to check already-present local files without downloading.)",
              file=sys.stderr)
        return 2

    print(f"Manifest version {manifest.get('version')} "
          f"({len(checkpoints)} checkpoints). verify_only={args.verify_only}")
    n_ok = n_fail = n_downloaded = 0

    for rel, meta in checkpoints.items():
        dest = Path(rel)
        expected_sha = meta.get("sha256")
        print(f"\n[{rel}]  {meta.get('description', '')}")

        ok, status = verify_file(dest, expected_sha)
        if args.verify_only:
            print(f"    verify: {status}")
            n_ok += ok; n_fail += (not ok)
            continue
        if ok and args.skip_existing:
            print(f"    skip-existing: {status}")
            n_ok += 1
        else:
            try:
                download(f"{base_url}/{asset_name(rel, 'best.pt')}", dest)
                ok, status = verify_file(dest, expected_sha)
                print(f"    best.pt: {status}")
                n_ok += ok; n_fail += (not ok); n_downloaded += 1
            except Exception as exc:  # noqa: BLE001
                print(f"    best.pt DOWNLOAD FAILED: {exc}", file=sys.stderr)
                n_fail += 1

        # companions (calibration.json required; metadata optional)
        companions = list(REQUIRED_COMPANIONS)
        if args.include_metadata:
            companions += OPTIONAL_COMPANIONS
        for fname in companions:
            cdest = dest.parent / fname
            if args.skip_existing and cdest.exists():
                print(f"    {fname}: present (skip)")
                continue
            try:
                download(f"{base_url}/{asset_name(rel, fname)}", cdest)
                # validate JSON parses
                json.loads(cdest.read_text(encoding="utf-8"))
                print(f"    {fname}: downloaded + valid JSON")
            except Exception as exc:  # noqa: BLE001
                required = fname in REQUIRED_COMPANIONS
                lvl = "ERROR" if required else "warn"
                print(f"    {fname} {lvl}: {exc}", file=sys.stderr)
                if required:
                    n_fail += 1

    print(f"\nSummary: ok={n_ok} fail={n_fail} downloaded={n_downloaded}")
    if n_fail:
        print("Some files failed verification/download. See messages above.", file=sys.stderr)
        return 1
    print("All checkpoints present and verified." if args.verify_only
          else "All checkpoints downloaded and verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
