"""Smoke test for POST /predict-cam-ensemble (Phase D.2).

Drives the FastAPI app in-process via Starlette's TestClient (no separate
uvicorn needed; startup events load the real ensemble checkpoints), POSTs the
demo image, and validates the full response schema:
  - top-level: request_id, inference_time_ms, model_version, ensemble{}, calibrated
  - model_cams[]: one entry per ensemble model, in /predict-ensemble order,
    each with the documented fields; heatmap_png_b64 decodes to a 224x224 PNG.

Run (from the project root):
    python -m scripts.test_api_cam_ensemble

Exit 0 = schema valid + heatmaps decode; non-zero = failure.
"""
from __future__ import annotations

import base64
import sys
from io import BytesIO
from pathlib import Path

from fastapi.testclient import TestClient
from PIL import Image

from src.skinlesion.api import app

DEMO_IMAGE = Path("docs/demo/images/easy_correct_ISIC_0024308.jpg")

TOP_LEVEL_KEYS = {
    "request_id", "inference_time_ms", "model_version", "ensemble",
    "model_cams", "calibrated", "disclaimer",
}
CAM_KEYS = {
    "model", "weight", "target_layer", "predicted_class", "display_label",
    "confidence", "calibrated", "temperature", "image_size",
    "heatmap_png_b64", "error",
}
EXPECTED_MODEL_ORDER = ["ResNet50", "DenseNet121", "EfficientNet-B0", "MobileNetV3 Small"]


def main() -> int:
    if not DEMO_IMAGE.exists():
        print(f"ERROR: demo image not found at {DEMO_IMAGE}", file=sys.stderr)
        return 2

    failures: list[str] = []

    def check(cond: bool, msg: str) -> None:
        if not cond:
            failures.append(msg)
            print(f"  [FAIL] {msg}", file=sys.stderr)
        else:
            print(f"  [ ok ] {msg}")

    with TestClient(app) as client:
        with open(DEMO_IMAGE, "rb") as fh:
            resp = client.post(
                "/predict-cam-ensemble",
                files={"image": (DEMO_IMAGE.name, fh, "image/jpeg")},
            )

        # GET / should now advertise the endpoint.
        index = client.get("/").json()
        check(
            index.get("endpoints", {}).get("predict_cam_ensemble") == "/predict-cam-ensemble",
            "GET / lists predict_cam_ensemble endpoint",
        )

    print(f"HTTP {resp.status_code}")
    check(resp.status_code == 200, "status code is 200")
    if resp.status_code != 200:
        print(resp.text, file=sys.stderr)
        return 1

    body = resp.json()
    check(TOP_LEVEL_KEYS.issubset(body), f"top-level keys present (got {sorted(body)})")

    ens = body.get("ensemble", {})
    check({"predicted_class", "display_label", "confidence", "predictions"}.issubset(ens),
          "ensemble block has required keys")
    check(isinstance(ens.get("predictions"), list) and len(ens["predictions"]) >= 1,
          "ensemble.predictions is a non-empty list")

    cams = body.get("model_cams", [])
    check(isinstance(cams, list) and len(cams) == 4, f"model_cams has 4 entries (got {len(cams)})")
    check([c.get("model") for c in cams] == EXPECTED_MODEL_ORDER,
          f"model_cams order matches /predict-ensemble (got {[c.get('model') for c in cams]})")

    for c in cams:
        name = c.get("model", "?")
        check(CAM_KEYS.issubset(c), f"{name}: cam entry has all keys")
        if c.get("error") is None and c.get("heatmap_png_b64"):
            try:
                png = base64.b64decode(c["heatmap_png_b64"])
                img = Image.open(BytesIO(png))
                img.verify()
                check(img.size == (224, 224), f"{name}: heatmap PNG decodes to 224x224 (got {img.size})")
            except Exception as exc:  # noqa: BLE001
                check(False, f"{name}: heatmap PNG decode failed — {exc}")
        else:
            # Isolation contract: a failed CAM must carry an error string + null heatmap.
            check(c.get("heatmap_png_b64") is None and isinstance(c.get("error"), str),
                  f"{name}: failed CAM has null heatmap + error string")
        print(
            f"     {name:18s} pred={c.get('predicted_class'):5s} "
            f"conf={c.get('confidence'):.3f} T={c.get('temperature')} "
            f"layer={c.get('target_layer')} err={c.get('error')}"
        )

    print(f"\ninference_time_ms={body.get('inference_time_ms')}  "
          f"model_version={body.get('model_version')}  calibrated={body.get('calibrated')}")

    if failures:
        print(f"\nSCHEMA VALIDATION FAILED: {len(failures)} issue(s).", file=sys.stderr)
        return 1
    print("\nAll schema checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
