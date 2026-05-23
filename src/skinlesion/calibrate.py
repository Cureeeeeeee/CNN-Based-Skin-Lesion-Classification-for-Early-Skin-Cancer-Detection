"""Fit post-hoc temperature scaling for every model in the config.

For each model listed in `models:` of the YAML config, this script:
  1. Loads the checkpoint at `runs/<model>/best.pt`.
  2. Runs forward passes over the validation split to collect raw logits.
  3. Fits a single scalar temperature T minimising val NLL.
  4. Computes NLL / ECE / Brier / accuracy before and after.
  5. Writes `runs/<model>/calibration.json` and `runs/<model>/reliability.png`.

Calibration is stored alongside the checkpoint but the checkpoint itself
is not modified. The API can opt-in by loading `calibration.json` at
startup; if absent, it falls back to uncalibrated softmax.

Usage:
    python -m src.skinlesion.calibrate --config configs/ham10000.yaml
    python -m src.skinlesion.calibrate --config configs/ham10000.yaml --model resnet50
"""
from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

import torch
from torch.utils.data import DataLoader
from tqdm import tqdm

from src.skinlesion.calibration import (
    apply_temperature,
    fit_temperature,
    plot_reliability_diagram,
    reliability_bins,
    summarise,
)
from src.skinlesion.config import load_config
from src.skinlesion.data import SkinLesionDataset, load_split_dataframe
from src.skinlesion.models import create_model
from src.skinlesion.train import select_device


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fit post-hoc temperature scaling for trained models."
    )
    parser.add_argument("--config", default="configs/ham10000.yaml")
    parser.add_argument(
        "--model",
        help="Calibrate only this model (default: all models in config).",
    )
    parser.add_argument(
        "--split",
        default="val",
        choices=["val", "test"],
        help="Split to fit temperature on (default: val).",
    )
    parser.add_argument(
        "--n-bins",
        type=int,
        default=15,
        help="Number of bins for ECE / reliability diagram.",
    )
    return parser.parse_args()


def collect_logits(
    model: torch.nn.Module,
    loader: DataLoader,
    device: torch.device,
    desc: str,
) -> tuple[torch.Tensor, torch.Tensor]:
    """Run the model over the loader and return (logits, labels) on CPU."""
    all_logits: list[torch.Tensor] = []
    all_labels: list[torch.Tensor] = []
    model.eval()
    with torch.no_grad():
        for images, labels in tqdm(loader, desc=desc, leave=False):
            outputs = model(images.to(device, non_blocking=True))
            all_logits.append(outputs.detach().cpu())
            all_labels.append(labels.detach().cpu())
    return torch.cat(all_logits), torch.cat(all_labels)


def calibrate_one(
    model_name: str,
    checkpoint_path: Path,
    loader: DataLoader,
    classes: list[str],
    device: torch.device,
    output_dir: Path,
    figures_dir: Path,
    n_bins: int,
) -> dict:
    """Calibrate a single model and persist artefacts. Returns the summary."""
    checkpoint = torch.load(checkpoint_path, map_location=device, weights_only=False)
    model = create_model(model_name, num_classes=len(classes), pretrained=False).to(device)
    model.load_state_dict(checkpoint["state_dict"])

    logits, labels = collect_logits(model, loader, device, desc=model_name)
    logits = logits.to(device)
    labels = labels.to(device)

    before = summarise(logits, labels)
    temperature = fit_temperature(logits, labels)
    scaled_logits = logits / temperature
    after = summarise(scaled_logits, labels)

    before_bins = reliability_bins(
        torch.softmax(logits, dim=1), labels, n_bins=n_bins
    )
    after_bins = reliability_bins(
        apply_temperature(logits, temperature), labels, n_bins=n_bins
    )

    output_dir.mkdir(parents=True, exist_ok=True)
    figures_dir.mkdir(parents=True, exist_ok=True)
    # Local copy for ML iteration (alongside checkpoint, gitignored).
    plot_reliability_diagram(
        before_bins,
        after_bins,
        model_name=model_name,
        output_path=output_dir / "reliability.png",
    )
    # Canonical copy for documentation (committed).
    plot_reliability_diagram(
        before_bins,
        after_bins,
        model_name=model_name,
        output_path=figures_dir / f"calibration_{model_name}.png",
    )

    payload = {
        "model": model_name,
        "method": "temperature_scaling",
        "split": "val",
        "n_samples": int(labels.shape[0]),
        "n_bins": n_bins,
        "temperature": temperature,
        "before": asdict(before),
        "after": asdict(after),
    }
    (output_dir / "calibration.json").write_text(
        json.dumps(payload, indent=2), encoding="utf-8"
    )
    return payload


def main() -> None:
    args = parse_args()
    config = load_config(args.config)
    data_config = config["data"]
    training_config = config["training"]
    classes: list[str] = data_config["classes"]
    device = select_device(training_config["device"])

    rows = load_split_dataframe(data_config["splits_csv"], args.split)
    dataset = SkinLesionDataset(
        rows, classes, data_config["image_size"], split=args.split
    )
    loader = DataLoader(
        dataset,
        batch_size=training_config["batch_size"],
        shuffle=False,
        num_workers=data_config["num_workers"],
        pin_memory=device.type == "cuda",
    )

    run_root = Path(config["output"]["run_dir"])
    figures_root = Path("docs/figures")
    model_names: list[str] = (
        [args.model] if args.model else list(config["models"])
    )

    summaries: list[dict] = []
    for name in model_names:
        checkpoint_path = run_root / name / "best.pt"
        if not checkpoint_path.exists():
            print(f"[skip] {name}: checkpoint not found at {checkpoint_path}")
            continue

        print(f"[fit ] {name}")
        summary = calibrate_one(
            model_name=name,
            checkpoint_path=checkpoint_path,
            loader=loader,
            classes=classes,
            device=device,
            output_dir=run_root / name,
            figures_dir=figures_root,
            n_bins=args.n_bins,
        )
        summaries.append(summary)
        b, a = summary["before"], summary["after"]
        print(
            f"        T={summary['temperature']:.3f}  "
            f"NLL {b['nll']:.4f} -> {a['nll']:.4f}  "
            f"ECE {b['ece']:.4f} -> {a['ece']:.4f}  "
            f"acc {a['accuracy']:.4f}"
        )

    print()
    print("done. wrote calibration.json and reliability.png to:")
    for s in summaries:
        print(f"  runs/{s['model']}/")


if __name__ == "__main__":
    main()
