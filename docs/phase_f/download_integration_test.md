# Checkpoint Download — Integration Test (POLISH-4)

**Test date:** 2026-05-25
**Script under test:** `scripts/download_checkpoints.py`
**Release:** GitHub Release `v2.0` on
`Cureeeeeeee/CNN-Based-Skin-Lesion-Classification-for-Early-Skin-Cancer-Detection`
(public).
**Result:** ✅ **PASS** — all 12 assets (6 × `best.pt` + 6 × `calibration.json`)
downloaded from the real Release and SHA256-verified against
`runs_v2/release_manifest.json`.

---

## Summary

| Stage | Outcome |
|-------|---------|
| `--verify-only` (local files vs. manifest) | 6/6 SHA256 match |
| Full download (clean temp dir, no token) | 6/6 `best.pt` SHA256 match, 6/6 `calibration.json` valid JSON |
| Total wall-clock for full download | **35.4 s** |
| Total payload | **318.7 MB** (`best.pt` files; `calibration.json` are <1 KB each) |

The script summary line was:
```
Summary: ok=6 fail=0 downloaded=6
All checkpoints downloaded and verified.
```

### Note on repo visibility (history)
A first attempt on 2026-05-25 returned **HTTP 404 for all 12 assets** because the
repository was still **private** — GitHub serves `404` (not `403`) to
unauthenticated requests for private resources, and the script downloads with
unauthenticated `urllib.request`. After the maintainer made the repo **public**
(confirmed `private: false`, `visibility: public` via the GitHub API), the
re-run below succeeded with no script change. If you fork into a private repo,
either make it public or add token auth to the downloader.

---

## Per-asset results (12 total)

All `best.pt` verified `ok (sha256 match)`; all `calibration.json` verified
`downloaded + valid JSON`.

| # | Asset (flat name on Release) | Destination | Size | best.pt result |
|---|------------------------------|-------------|------|----------------|
| 1 | `resnet50__best.pt` | `runs/resnet50/best.pt` | 94,392,749 B | sha256 match |
| 2 | `resnet50__calibration.json` | `runs/resnet50/calibration.json` | 494 B | valid JSON |
| 3 | `resnet50_v2__best.pt` | `runs/resnet50_v2/best.pt` | 94,393,389 B | sha256 match |
| 4 | `resnet50_v2__calibration.json` | `runs/resnet50_v2/calibration.json` | 907 B | valid JSON |
| 5 | `resnet50_v1_backup__best.pt` | `runs/resnet50_v1_backup/best.pt` | 94,392,749 B | sha256 match |
| 6 | `resnet50_v1_backup__calibration.json` | `runs/resnet50_v1_backup/calibration.json` | 494 B | valid JSON |
| 7 | `densenet121__best.pt` | `runs/densenet121/best.pt` | 28,417,722 B | sha256 match |
| 8 | `densenet121__calibration.json` | `runs/densenet121/calibration.json` | 902 B | valid JSON |
| 9 | `efficientnet_b0__best.pt` | `runs/efficientnet_b0/best.pt` | 16,342,245 B | sha256 match |
| 10 | `efficientnet_b0__calibration.json` | `runs/efficientnet_b0/calibration.json` | 910 B | valid JSON |
| 11 | `mobilenetv3_small_100__best.pt` | `runs/mobilenetv3_small_100/best.pt` | 6,223,337 B | sha256 match |
| 12 | `mobilenetv3_small_100__calibration.json` | `runs/mobilenetv3_small_100/calibration.json` | 916 B | valid JSON |

Total `best.pt`: **334,162,191 bytes (318.7 MB)**.

`runs/resnet50` and `runs/resnet50_v1_backup` `best.pt` are byte-identical
(same size + same manifest hash), as expected — the backup is a copy of the v1
deployed default for rollback.

---

## Timing breakdown

- **Full download wall-clock:** 35.4 s for 318.7 MB → ≈ **9 MB/s** effective
  (sequential, single connection via `urllib.request.urlretrieve`).
- Well within the brief's 1–5 minute expectation.
- `calibration.json` downloads are negligible (<1 KB each).
- No retries, no resumes — each asset fetched once, first try.

## Anomalies

None on the successful run. (The earlier all-404 run was a repo-visibility
issue, since resolved — see the note above, not an upload error.)

---

## Exact commands used (re-test recipe for future devs)

Run from a clean temp dir so `runs/` in the working tree is never clobbered.
The script reads `runs_v2/release_manifest.json` *relative to the current
directory*, so copy the manifest into the temp dir first.

```powershell
# 1. (optional) confirm the repo/release is publicly reachable
$repo = "Cureeeeeeee/CNN-Based-Skin-Lesion-Classification-for-Early-Skin-Cancer-Detection"
(Invoke-WebRequest "https://api.github.com/repos/$repo" -UseBasicParsing | ConvertFrom-Json) |
  Select-Object full_name, private, visibility

# 2. set up an isolated temp dir with the manifest the script expects
$test = Join-Path $env:TEMP "release_v2_test"
if (Test-Path $test) { Remove-Item -Recurse -Force $test }
New-Item -ItemType Directory -Path (Join-Path $test "runs_v2") -Force | Out-Null
Copy-Item "C:\Users\user\Documents\New project\runs_v2\release_manifest.json" `
  -Destination (Join-Path $test "runs_v2\release_manifest.json") -Force

# 3. run the full download from the temp dir, timed
Set-Location $test
Measure-Command {
  python "C:\Users\user\Documents\New project\scripts\download_checkpoints.py"
}

# 4. (optional) inspect sizes
Get-ChildItem -Recurse -File $test | Select-Object FullName, Length

# 5. clean up
Set-Location "C:\Users\user\Documents\New project"
Remove-Item -Recurse -Force $test
```

To instead verify already-present local checkpoints without downloading
(fast, from the project root):
```powershell
python scripts/download_checkpoints.py --verify-only   # expect 6/6 match
```
