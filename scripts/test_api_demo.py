from __future__ import annotations

import argparse
import base64
import json
import mimetypes
from io import BytesIO
from pathlib import Path
from urllib import error, request


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Smoke-test the FastAPI demo backend.")
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--image", default="docs/demo/images/easy_correct_ISIC_0024308.jpg")
    return parser.parse_args()


def get_json(url: str, label: str) -> dict[str, object]:
    try:
        with request.urlopen(url, timeout=10) as response:
            return json.loads(response.read().decode("utf-8"))
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{label} failed: {exc.code} {body}") from exc


def post_image(url: str, image_path: Path) -> dict[str, object]:
    boundary = "----skinlesiondemo"
    mime_type = mimetypes.guess_type(image_path.name)[0] or "application/octet-stream"
    image_bytes = image_path.read_bytes()
    body = b"".join(
        [
            f"--{boundary}\r\n".encode("utf-8"),
            (
                'Content-Disposition: form-data; name="image"; '
                f'filename="{image_path.name}"\r\n'
            ).encode("utf-8"),
            f"Content-Type: {mime_type}\r\n\r\n".encode("utf-8"),
            image_bytes,
            f"\r\n--{boundary}--\r\n".encode("utf-8"),
        ]
    )
    upload = request.Request(
        url,
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    try:
        with request.urlopen(upload, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"POST /predict failed: {exc.code} {body}") from exc


def main() -> None:
    args = parse_args()
    base_url = args.base_url.rstrip("/")
    image_path = Path(args.image)
    if not image_path.exists():
        raise FileNotFoundError(f"Demo image not found: {image_path}")

    root = get_json(f"{base_url}/", "GET /")
    health = get_json(f"{base_url}/health", "GET /health")
    model_info = get_json(f"{base_url}/model-info", "GET /model-info")
    prediction = post_image(f"{base_url}/predict", image_path)

    predictions = prediction.get("predictions") or prediction.get("top_candidates") or []
    if len(predictions) != 3:
        raise AssertionError(f"Expected 3 predictions, got {len(predictions)}")

    print("API demo validation passed")
    print(f"Project: {root.get('project')}")
    print(f"Health: {health.get('status')} | loaded={health.get('model_loaded')}")
    print(f"Default model: {model_info.get('default_model')}")
    cal_block = model_info.get("calibration", {}) or {}
    single_cal = cal_block.get("single", {}) or {}
    ens_cal = cal_block.get("ensemble", {}) or {}
    print(
        "Calibration: single "
        f"{'on' if single_cal.get('calibrated') else 'off'} "
        f"T={single_cal.get('temperature')} | ensemble "
        f"{'all-on' if ens_cal.get('all_calibrated') else 'partial/off'}"
    )
    print("Top-3 predictions:")
    for index, item in enumerate(predictions, start=1):
        label = item.get("label") or item.get("class")
        display_label = item.get("display_label") or label
        confidence = float(item["confidence"])
        print(f"  {index}. {label} - {display_label}: {confidence:.2%}")
    if "calibrated" not in prediction:
        raise AssertionError("/predict response missing 'calibrated' flag")
    print(
        f"  /predict calibrated={prediction.get('calibrated')} "
        f"T={prediction.get('temperature')}"
    )

    ensemble = post_image(f"{base_url}/predict-ensemble", image_path)
    ens = ensemble.get("ensemble", {})
    model_outputs = ensemble.get("model_outputs", [])
    if not ens.get("predicted_class"):
        raise AssertionError("Ensemble response missing ensemble.predicted_class")
    if len(model_outputs) == 0:
        raise AssertionError("Ensemble response has no model_outputs")

    if "calibrated" not in ensemble:
        raise AssertionError("/predict-ensemble response missing 'calibrated' flag")

    cam = post_image(f"{base_url}/predict-cam", image_path)
    for required in ("heatmap_png_b64", "predicted_class", "target_layer", "method"):
        if required not in cam:
            raise AssertionError(f"/predict-cam response missing '{required}'")
    if cam["method"] != "grad-cam":
        raise AssertionError(f"/predict-cam method should be 'grad-cam', got {cam['method']!r}")
    try:
        decoded = base64.b64decode(cam["heatmap_png_b64"], validate=True)
    except Exception as exc:  # noqa: BLE001
        raise AssertionError(f"/predict-cam heatmap is not valid base64: {exc}") from exc
    try:
        from PIL import Image as _Image
        decoded_img = _Image.open(BytesIO(decoded))
        decoded_img.verify()
    except Exception as exc:  # noqa: BLE001
        raise AssertionError(f"/predict-cam heatmap is not a valid PNG: {exc}") from exc

    print()
    print("Ensemble validation passed")
    print(f"  request_id:        {ensemble.get('request_id')}")
    print(f"  inference_time_ms: {ensemble.get('inference_time_ms')}")
    print(f"  model_version:     {ensemble.get('model_version')}")
    print(f"  models_agree:      {ensemble.get('models_agree')}")
    print(f"  calibrated:        {ensemble.get('calibrated')}")
    if ensemble.get("agreement_note"):
        print(f"  note:              {ensemble.get('agreement_note')}")
    print(f"  Ensemble top-1:    {ens.get('predicted_class')} - {ens.get('display_label')} ({ens.get('confidence'):.2%})")
    print("  Per-model top-1:")
    for m in model_outputs:
        cal = "cal" if m.get("calibrated") else "raw"
        temp = m.get("temperature", 1.0)
        print(
            f"    {m['model']:22s} (w={m['weight']:.2f})  "
            f"{m['predicted_class']:5s}  {m['confidence']:.2%}  "
            f"[{cal} T={temp}]"
        )

    print()
    print("Grad-CAM validation passed")
    print(f"  model:         {cam.get('model')}")
    print(f"  predicted:     {cam.get('predicted_class')} ({cam.get('confidence'):.2%})")
    print(f"  target_layer:  {cam.get('target_layer')}")
    print(f"  calibrated:    {cam.get('calibrated')} (T={cam.get('temperature')})")
    print(f"  heatmap PNG:   {len(cam.get('heatmap_png_b64', ''))} chars base64 -> "
          f"{decoded_img.size if decoded_img.size else 'unknown'} px")


if __name__ == "__main__":
    main()
