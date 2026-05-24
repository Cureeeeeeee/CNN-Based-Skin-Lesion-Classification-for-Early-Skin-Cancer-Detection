#!/bin/bash
# Skin Lesion Classification — demo setup & launch (macOS / Linux, CPU-only).
#
# Brings up the FastAPI backend for the thesis demo on a fresh machine:
#   venv -> CPU PyTorch -> pinned deps -> checkpoints -> API on :8126.
#
# Run from the project root:  bash scripts/run_demo.sh
set -euo pipefail

PORT=8126
PYREQ_MAJOR=3
PYREQ_MINOR=11

echo "=================================================="
echo " Skin Lesion Classification — Demo Setup (CPU)"
echo "=================================================="

# --- Step 1: Python 3.11+ -------------------------------------------------
if command -v python3 >/dev/null 2>&1; then PY=python3; else PY=python; fi
PYVER=$("$PY" -c 'import sys; print("%d.%d"%sys.version_info[:2])')
echo "[1/6] Python: $PY ($PYVER)"
"$PY" -c "import sys; raise SystemExit(0 if sys.version_info[:2] >= ($PYREQ_MAJOR,$PYREQ_MINOR) else 1)" || {
  echo "ERROR: Python ${PYREQ_MAJOR}.${PYREQ_MINOR}+ required (found $PYVER)."; exit 1; }

# --- Step 2: virtual environment -----------------------------------------
if [ ! -d ".venv" ]; then
  echo "[2/6] .venv not found — creating one (python -m venv .venv)…"
  "$PY" -m venv .venv
else
  echo "[2/6] .venv present."
fi
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install --quiet --upgrade pip

# --- Step 3: CPU PyTorch (installed first so the pinned CPU build is used) -
echo "[3/6] Installing CPU PyTorch (torch 2.11.0 / torchvision 0.26.0)…"
# macOS: PyPI wheel is already CPU/MPS. Linux: use the CPU wheel index.
if [ "$(uname -s)" = "Darwin" ]; then
  python -m pip install --quiet "torch==2.11.0" "torchvision==0.26.0"
else
  python -m pip install --quiet "torch==2.11.0" "torchvision==0.26.0" \
    --index-url https://download.pytorch.org/whl/cpu
fi

# --- Step 4: pinned runtime dependencies ----------------------------------
echo "[4/6] Installing pinned dependencies (requirements-lock.txt)…"
python -m pip install --quiet -r requirements-lock.txt

# --- Step 5: model checkpoints --------------------------------------------
echo "[5/6] Fetching model checkpoints…"
if python -c "import pathlib,sys; sys.exit(0 if pathlib.Path('runs/resnet50_v2/best.pt').exists() else 1)"; then
  echo "      checkpoints already present — verifying."
  python scripts/download_checkpoints.py --verify-only || \
    echo "      (verify reported issues — see above; continuing)"
else
  python scripts/download_checkpoints.py --skip-existing
fi

# --- Step 6: launch API (CPU) ---------------------------------------------
echo "[6/6] Starting API on http://127.0.0.1:${PORT} (CPU inference)…"
echo "      Single-model /predict serves resnet50_v2 (Phase C winner)."
echo "      Press Ctrl+C to stop."
echo "--------------------------------------------------"
echo "API ready at http://127.0.0.1:${PORT}   (docs: /docs, health: /model-info)"
export SKINLESION_DEVICE=cpu
exec uvicorn src.skinlesion.api:app --host 127.0.0.1 --port "${PORT}"
