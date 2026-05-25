# Skin Lesion Classification - demo setup & launch (Windows, CPU-only).
#
# Windows equivalent of run_demo.sh. Brings up the FastAPI backend:
#   venv -> CPU PyTorch -> pinned deps -> checkpoints -> API on :8126.
#
# Run from the project root:  powershell -ExecutionPolicy Bypass -File scripts\run_demo.ps1
$ErrorActionPreference = "Stop"
$Port = 8126

Write-Host "=================================================="
Write-Host " Skin Lesion Classification - Demo Setup (CPU)"
Write-Host "=================================================="

# --- Step 1: Python 3.11+ -------------------------------------------------
$py = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $py) { Write-Error "Python not found on PATH. Install Python 3.11+."; exit 1 }
$pyver = & python -c "import sys; print('%d.%d'%sys.version_info[:2])"
Write-Host "[1/6] Python $pyver"
& python -c "import sys; sys.exit(0 if sys.version_info[:2] -ge (3,11) else 1)"
if ($LASTEXITCODE -ne 0) { Write-Error "Python 3.11+ required (found $pyver)."; exit 1 }

# --- Step 2: virtual environment -----------------------------------------
if (-not (Test-Path ".venv")) {
  Write-Host "[2/6] .venv not found - creating one (python -m venv .venv)..."
  & python -m venv .venv
} else {
  Write-Host "[2/6] .venv present."
}
& .\.venv\Scripts\Activate.ps1
& python -m pip install --quiet --upgrade pip

# --- Step 3: CPU PyTorch (installed first so the pinned CPU build is used) -
Write-Host "[3/6] Installing CPU PyTorch (torch 2.11.0 / torchvision 0.26.0)..."
& python -m pip install --quiet "torch==2.11.0" "torchvision==0.26.0" `
    --index-url https://download.pytorch.org/whl/cpu

# --- Step 4: pinned runtime dependencies ----------------------------------
Write-Host "[4/6] Installing pinned dependencies (requirements-lock.txt)..."
& python -m pip install --quiet -r requirements-lock.txt

# --- Step 5: model checkpoints --------------------------------------------
Write-Host "[5/6] Fetching model checkpoints..."
if (Test-Path "runs\resnet50_v2\best.pt") {
  Write-Host "      checkpoints already present - verifying."
  & python scripts\download_checkpoints.py --verify-only
} else {
  & python scripts\download_checkpoints.py --skip-existing
}

# --- Step 6: launch API (CPU) ---------------------------------------------
Write-Host "[6/6] Starting API on http://127.0.0.1:$Port (CPU inference)..."
Write-Host "      Single-model /predict serves resnet50_v2 (Phase C winner)."
Write-Host "      Press Ctrl+C to stop."
Write-Host "--------------------------------------------------"
Write-Host "API ready at http://127.0.0.1:$Port   (docs: /docs, health: /model-info)"
$env:SKINLESION_DEVICE = "cpu"
& uvicorn src.skinlesion.api:app --host 127.0.0.1 --port $Port
