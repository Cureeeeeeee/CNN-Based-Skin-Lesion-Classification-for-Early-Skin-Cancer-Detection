"""Fit post-hoc temperature scaling for every model in the config.

For each model listed in `models:` of the YAML config, this script:
  1. Loads the checkpoint at `runs/<model>/best.pt`.
  2. Runs forward passes over the fit split (default: val) to collect logits.
  3. Fits a single scalar temperature T minimising fit-split NLL.
  4. Computes NLL / ECE / Brier / accuracy on the fit split before and after.
  5. **Also** runs forward passes over the eval split (default: test) and
     reports the same metrics with the same T — to confirm calibration
     generalises beyond the split it was fit on.
  6. Writes `runs/<m>/calibration.json` (val + test blocks), plus
     reliability diagrams for both splits.

Calibration is stored alongside the checkpoint but the checkpoint itself
is not modified. The API only reads the `temperature` field, so the
`test_evaluation` block is additive and does not change API behaviour.

Usage:
    python -m src.skinlesion.calibrate --config configs/ham10000.yaml
    python -m src.skinlesion.calibrate --config configs/ham10000.yaml --model resnet50
    python -m src.skinlesion.calibrate --config configs/ham10000.yaml --no-eval
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
        "--eval-split",
        default="test",
        choices=["val", "test"],
        help="Additionally evaluate the fitted T on this split (default: test).",
    )
    parser.add_argument(
        "--no-eval",
        action="store_true",
        help="Skip the secondary eval-split evaluation.",
    )
    parser.add_argument(
        "--n-bins",
        type=int,
        default=15,
        help="Number of bins for ECE / reliability diagram.",
    )
    return parser.parse_args()


def build_loader(
    config: dict,
    classes: list[str],
    split: str,
    device: torch.device,
) -> DataLoader:
    data_config = config["data"]
    training_config = config["training"]
    rows = load_split_dataframe(data_config["splits_csv"], split)
    dataset = SkinLesionDataset(rows, classes, data_config["image_size"], split=split)
    return DataLoader(
        dataset,
        batch_size=training_config["batch_size"],
        shuffle=False,
        num_workers=data_config["num_workers"],
        pin_memory=device.type == "cuda",
    )


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


def evaluate_split(
    model: torch.nn.Module,
    loader: DataLoader,
    device: torch.device,
    temperature: float,
    desc: str,
    n_bins: int,
) -> tuple[dict, dict, tuple]:
    """Run model + temperature on a split. Returns (before, after, (bins_before, bins_after))."""
    logits, labels = collect_logits(model, loader, device, desc=desc)
    logits = logits.to(device)
    labels = labels.to(device)
    before = summarise(logits, labels)
    after = summarise(logits / temperature, labels)
    bins_before = reliability_bins(
        torch.softmax(logits, dim=1), labels, n_bins=n_bins
    )
    bins_after = reliability_bins(
        apply_temperature(logits, temperature), labels, n_bins=n_bins
    )
    return asdict(before), asdict(after), (bins_before, bins_after, int(labels.shape[0]))


def calibrate_one(
    model_name: str,
    checkpoint_path: Path,
    fit_loader: DataLoader,
    fit_split: str,
    eval_loader: DataLoader | None,
    eval_split: str | None,
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

    # Fit T on the fit split.
    fit_logits, fit_labels = collect_logits(model, fit_loader, device, desc=f"{model_name} [{fit_split}]")
    fit_logits = fit_logits.to(device)
    fit_labels = fit_labels.to(device)

    before = summarise(fit_logits, fit_labels)
    temperature = fit_temperature(fit_logits, fit_labels)
    after = summarise(fit_logits / temperature, fit_labels)

    fit_bins_before = reliability_bins(
        torch.softmax(fit_logits, dim=1), fit_labels, n_bins=n_bins
    )
    fit_bins_after = reliability_bins(
        apply_temperature(fit_logits, temperature), fit_labels, n_bins=n_bins
    )

    output_dir.mkdir(parents=True, exist_ok=True)
    figures_dir.mkdir(parents=True, exist_ok=True)
    # Reliability diagram on the FIT split (val).
    plot_reliability_diagram(
        fit_bins_before, fit_bins_after,
        model_name=f"{model_name} ({fit_split})",
        output_path=output_dir / "reliability.png",
    )
    plot_reliability_diagram(
        fit_bins_before, fit_bins_after,
        model_name=f"{model_name} ({fit_split})",
        output_path=figures_dir / f"calibration_{model_name}.png",
    )

    payload: dict = {
        "model": model_name,
        "method": "temperature_scaling",
        "fit_split": fit_split,
        # Backwards-compat alias: the original schema used "split".
        "split": fit_split,
        "n_samples": int(fit_labels.shape[0]),
        "n_bins": n_bins,
        "temperature": temperature,
        "before": asdict(before),
        "after": asdict(after),
    }

    # Optional eval split (default: test) — uses the SAME fitted T.
    if eval_loader is not None and eval_split is not None and eval_split != fit_split:
        eval_before, eval_after, (eb_bins, ea_bins, n_eval) = evaluate_split(
            model, eval_loader, device, temperature,
            desc=f"{model_name} [{eval_split}]", n_bins=n_bins,
        )
        plot_reliability_diagram(
            eb_bins, ea_bins,
            model_name=f"{model_name} ({eval_split})",
            output_path=output_dir / f"reliability_{eval_split}.png",
        )
        plot_reliability_diagram(
            eb_bins, ea_bins,
            model_name=f"{model_name} ({eval_split})",
            output_path=figures_dir / f"calibration_{model_name}_{eval_split}.png",
        )
        payload["eval_evaluation"] = {
            "split": eval_split,
            "n_samples": n_eval,
            "before": eval_before,
            "after": eval_after,
        }

    (output_dir / "calibration.json").write_text(
        json.dumps(payload, indent=2), encoding="utf-8"
    )
    return payload


def main() -> None:
    args = parse_args()
    config = load_config(args.config)
    data_config = config["data"]
    classes: list[str] = data_config["classes"]
    device = select_device(config["training"]["device"])

    fit_loader = build_loader(config, classes, args.split, device)
    eval_loader: DataLoader | None = None
    eval_split: str | None = None
    if not args.no_eval and args.eval_split != args.split:
        eval_loader = build_loader(config, classes, args.eval_split, device)
        eval_split = args.eval_split

    run_root = Path(config["output"]["run_dir"])
    figures_root = Path(config["output"].get("figures_dir", "docs/figures"))
    model_names: list[str] = (
        [args.model] if args.model else list(config["models"])
    )

    summaries: list[dict] = []
    for name in model_names:
        checkpoint_path = run_root / name / "best.pt"
        if not checkpoint_path.exists():
            print(f"[skip] {name}: checkpoint not found at {checkpoint_path}")
            continue

        print(f"[fit ] {name}  (fit={args.split}, eval={eval_split or 'none'})")
        summary = calibrate_one(
            model_name=name,
            checkpoint_path=checkpoint_path,
            fit_loader=fit_loader,
            fit_split=args.split,
            eval_loader=eval_loader,
            eval_split=eval_split,
            classes=classes,
            device=device,
            output_dir=run_root / name,
            figures_dir=figures_root,
            n_bins=args.n_bins,
        )
        summaries.append(summary)
        b, a = summary["before"], summary["after"]
        msg = (
            f"        T={summary['temperature']:.3f}  "
            f"NLL {b['nll']:.4f} -> {a['nll']:.4f}  "
            f"ECE {b['ece']:.4f} -> {a['ece']:.4f}  "
            f"acc {a['accuracy']:.4f}"
        )
        if "eval_evaluation" in summary:
            eb = summary["eval_evaluation"]["before"]
            ea = summary["eval_evaluation"]["after"]
            msg += (
                f"  | {summary['eval_evaluation']['split']}:  "
                f"NLL {eb['nll']:.4f} -> {ea['nll']:.4f}  "
                f"ECE {eb['ece']:.4f} -> {ea['ece']:.4f}  "
                f"acc {ea['accuracy']:.4f}"
            )
        print(msg)

    print()
    print("done. wrote calibration.json and reliability diagrams to:")
    for s in summaries:
        print(f"  {run_root}/{s['model']}/")


if __name__ == "__main__":
    main()
