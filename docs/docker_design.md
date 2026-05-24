# Docker Design (deferred — design only, not built for v2.0)

This document specifies a CPU-only container for the FastAPI backend. **It is
intentionally not built or shipped in v2.0.** The v2.0 demo runs native Python on
the MacBook (see the README Quick Start and `scripts/run_demo.sh`). The syntax
below is provided as a design artefact; there is deliberately **no** `Dockerfile`,
`docker-compose.yml`, or `.dockerignore` committed to the repo root, because an
untested build file would be misleading.

## 1. Why defer Docker for v2.0

- **Native is faster for the demo target.** The demo runs on a MacBook (Apple
  Silicon). A native Python venv can use the CPU/MPS PyTorch wheel directly; an
  `amd64` image would run under Rosetta/QEMU emulation (slow), and even a native
  `arm64` Linux container cannot reach the host's MPS device.
- **CPU torch install is already trivial** on the demo machine (one `pip`
  command in `run_demo.sh`), so containerisation adds setup/debug time without
  buying portability we need for a single-machine thesis demo.
- **Timeline.** Build/test/debug across two architectures is out of scope for the
  v2.0 release window; it is queued as future work (§6).

## 2. Proposed Dockerfile (CPU-only)

```dockerfile
# Design only — not built for v2.0.
FROM python:3.11-slim

# System libs. Pillow/matplotlib(Agg) need no GUI libs; libgl1/libglib2.0-0 are
# precautionary for any transitive that links libGL. Since the project uses
# Pillow (not opencv), these can likely be dropped after a test build.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# CPU PyTorch first (so the pinned CPU build is used, not a CUDA wheel),
# then the pinned runtime closure.
RUN pip install --no-cache-dir \
        torch==2.11.0 torchvision==0.26.0 \
        --index-url https://download.pytorch.org/whl/cpu
COPY requirements-lock.txt ./
RUN pip install --no-cache-dir -r requirements-lock.txt

# Application code + config only. Checkpoints are NOT baked in — they are large,
# gitignored, and CC BY-NC 4.0; they are mounted read-only at run time (§3).
COPY src/ ./src/
COPY configs/ ./configs/
COPY scripts/ ./scripts/

ENV SKINLESION_DEVICE=cpu \
    PYTHONUNBUFFERED=1
EXPOSE 8126

# Liveness probe: /health is the dedicated lightweight endpoint (returns
# model_loaded). /model-info also works but does more work per call.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request,sys; \
        sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8126/health').status==200 else 1)"

CMD ["uvicorn", "src.skinlesion.api:app", "--host", "0.0.0.0", "--port", "8126"]
```

## 3. Proposed docker-compose.yml

```yaml
# Design only — not built for v2.0.
services:
  skinlesion-api:
    build: .
    image: skinlesion-api:v2.0
    ports:
      - "8126:8126"
    environment:
      SKINLESION_DEVICE: cpu
    volumes:
      # Checkpoints + calibration mounted read-only (fetch on host first via
      # scripts/download_checkpoints.py). Keeps the image small and avoids
      # baking CC BY-NC weights into a distributable image.
      - ./runs:/app/runs:ro
      - ./configs:/app/configs:ro
    healthcheck:
      test: ["CMD", "python", "-c",
             "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8126/health').status==200 else 1)"]
      interval: 30s
      timeout: 5s
      start_period: 20s
      retries: 3
    restart: unless-stopped
```

## 4. Proposed .dockerignore

Keep the build context small and avoid copying weights/data/secrets:

```gitignore
.git/
.venv/
venv/
data/
runs/                # checkpoints come via read-only volume mount, not COPY
runs_v2/
mobile_app/          # Flutter frontend is built/run separately
notebooks/
docs/
*.pt
*.pth
*.onnx
__pycache__/
*.pyc
.pytest_cache/
.mypy_cache/
.ruff_cache/
```

(`runs/` is excluded from the *image build* but bind-mounted read-only at run
time, so the API still finds the checkpoints.)

## 5. Apple Silicon considerations

- **Build native `arm64`.** On an Apple-Silicon Mac, `docker build` defaults to
  `linux/arm64`, which runs natively. PyTorch publishes Linux `aarch64` CPU
  wheels, so the CPU index install works. Avoid forcing `--platform linux/amd64`
  (Rosetta/QEMU emulation → much slower inference).
- **No MPS inside containers.** A Linux container cannot access the host's Metal
  (MPS) GPU. Container inference is CPU-only regardless; the native venv path can
  optionally use MPS. This is a further reason native is preferred for the demo.
- **For x86 distribution** (e.g. a Linux server), build a separate
  `linux/amd64` image (or a multi-arch image via `docker buildx --platform
  linux/amd64,linux/arm64`).

## 6. Future work to actually ship Docker

1. Build + smoke-test the image on Linux `amd64` and Mac `arm64`
   (`docker run` → `/health` ok → `scripts/test_api_demo.py` against the
   container port). Trim `libgl1`/`libglib2.0-0` if unused.
2. Add a Docker path to `scripts/run_demo.*` as an alternative to the native
   venv flow (`docker compose up`).
3. Publish a multi-arch image to GHCR for distribution
   (`docker buildx build --push --platform linux/amd64,linux/arm64`).
4. Add a CI workflow (GitHub Actions) that builds the image and runs the smoke
   test on every tagged release, so the Dockerfile cannot silently rot.
5. Document the CC BY-NC 4.0 implications of distributing an image — ship code
   only; keep weights as a separately-fetched, read-only mounted artefact.
