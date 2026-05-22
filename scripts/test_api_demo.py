from __future__ import annotations

import argparse
import json
import mimetypes
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
    print("Top-3 predictions:")
    for index, item in enumerate(predictions, start=1):
        label = item.get("label") or item.get("class")
        confidence = float(item["confidence"])
        print(f"  {index}. {label}: {confidence:.2%}")


if __name__ == "__main__":
    main()
