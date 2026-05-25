from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.utils.data import DataLoader
from tqdm import tqdm

from src.skinlesion.config import load_config
from src.skinlesion.data import SkinLesionDataset, compute_class_weights, load_split_dataframe, make_balanced_sampler
from src.skinlesion.metrics import summarize_classification
from src.skinlesion.models import create_model

class FocalLoss(nn.Module):
    """FL(p_t) = -alpha_t (1 - p_t)^gamma log(p_t).
    
    gamma=0 reduces to standard CE. alpha (per-class weight tensor) is optional;
    if provided, it modulates each sample's loss by its true class's weight.
    """
    def __init__(self, gamma=2.0, alpha=None):
        super().__init__()
        self.gamma = gamma
        if alpha is not None:
            self.register_buffer("alpha", alpha)
        else:
            self.alpha = None
    
    def forward(self, logits, target):
        logp = torch.log_softmax(logits, dim=1)
        logp_t = logp.gather(1, target.unsqueeze(1)).squeeze(1)
        p_t = logp_t.exp()
        loss = -((1 - p_t) ** self.gamma) * logp_t
        if self.alpha is not None:
            loss = loss * self.alpha[target]
        return loss.mean()
    

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train skin lesion classifiers.")
    parser.add_argument("--config", default="configs/ham10000.yaml")
    parser.add_argument("--model", help="One timm model name to train.")
    parser.add_argument("--all-models", action="store_true", help="Train every model in the config.")
    parser.add_argument(
        "--exp-name",
        help="Optional experiment name to disambiguate output directory; defaults "
        "to model name. Use to avoid collisions when running multiple variants of "
        "the same model architecture, e.g., --model resnet50 --exp-name "
        "resnet50_v2_focal. Cannot be combined with --all-models.",
    )
    parser.add_argument("--epochs", type=int, help="Override epochs from the config.")
    parser.add_argument("--batch-size", type=int, help="Override batch size from the config.")
    parser.add_argument("--limit-batches", type=int, help="Limit batches per epoch for smoke tests.")
    parser.add_argument("--no-pretrained", action="store_true", help="Do not download pretrained weights.")
    return parser.parse_args()


def set_seed(seed: int, cudnn_deterministic: bool = False) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    if cudnn_deterministic:
        # Exact reproducibility at a small GPU-speed cost. Off by default so
        # historical (non-deterministic) behaviour is preserved when unset.
        torch.backends.cudnn.deterministic = True
        torch.backends.cudnn.benchmark = False


def select_device(name: str) -> torch.device:
    if name == "auto":
        return torch.device("cuda" if torch.cuda.is_available() else "cpu")
    return torch.device(name)


def run_epoch(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    device: torch.device,
    optimizer: torch.optim.Optimizer | None = None,
    limit_batches: int | None = None,
) -> tuple[float, dict[str, object]]:
    is_train = optimizer is not None
    model.train(is_train)

    losses: list[float] = []
    y_true: list[int] = []
    y_pred: list[int] = []

    with torch.set_grad_enabled(is_train):
        for batch_index, (images, labels) in enumerate(tqdm(loader, leave=False), start=1):
            images = images.to(device)
            labels = labels.to(device)

            outputs = model(images)
            loss = criterion(outputs, labels)

            if is_train:
                optimizer.zero_grad(set_to_none=True)
                loss.backward()
                optimizer.step()

            losses.append(loss.item())
            predictions = outputs.argmax(dim=1)
            y_true.extend(labels.detach().cpu().tolist())
            y_pred.extend(predictions.detach().cpu().tolist())

            if limit_batches is not None and batch_index >= limit_batches:
                break

    metrics = summarize_classification(y_true, y_pred, class_names=loader.dataset.classes)
    return float(np.mean(losses)), metrics


def train_one_model(
    config: dict[str, object],
    model_name: str,
    *,
    pretrained: bool = True,
    limit_batches: int | None = None,
    exp_name: str | None = None,
    seed: int = 42,
) -> None:
    data_config = config["data"]
    training_config = config["training"]
    output_config = config["output"]
    classes = data_config["classes"]

    device = select_device(training_config["device"])
    splits_csv = data_config["splits_csv"]
    image_size = data_config["image_size"]

    train_rows = load_split_dataframe(splits_csv, "train")
    validation_rows = load_split_dataframe(splits_csv, "val")
    train_dataset = SkinLesionDataset(train_rows, classes, image_size, split="train")
    validation_dataset = SkinLesionDataset(validation_rows, classes, image_size, split="val")

    # Seeded generator makes the sampler / shuffle order deterministic.
    generator = torch.Generator().manual_seed(seed)
    use_sampler = data_config.get("sampler") == "balanced"
    sampler = make_balanced_sampler(train_rows, classes, generator=generator) if use_sampler else None
    train_loader = DataLoader(
        train_dataset,
        batch_size=training_config["batch_size"],
        shuffle=(sampler is None),
        sampler=sampler,
        num_workers=data_config["num_workers"],
        pin_memory=device.type == "cuda",
        generator=generator,
)
    validation_loader = DataLoader(
        validation_dataset,
        batch_size=training_config["batch_size"],
        shuffle=False,
        num_workers=data_config["num_workers"],
        pin_memory=device.type == "cuda",
    )

    model = create_model(
        model_name=model_name,
        num_classes=len(classes),
        dropout=training_config["dropout"],
        pretrained=pretrained,
    ).to(device)

    loss_name = training_config.get("loss", "ce")
    alpha = compute_class_weights(train_rows, classes).to(device) \
        if training_config.get("weighted_loss") else None
    if loss_name == "focal":
        criterion = FocalLoss(gamma=training_config.get("focal_gamma", 2.0), alpha=alpha)
    elif training_config.get("weighted_loss"):
        criterion = nn.CrossEntropyLoss(weight=alpha)
    else:
        criterion = nn.CrossEntropyLoss()

    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=training_config["learning_rate"],
        weight_decay=training_config["weight_decay"],
    )

    # exp_name disambiguates the output directory so multiple variants of the
    # same architecture (e.g. resnet50_v2_focal vs resnet50_v2_sampler) don't
    # collide on runs/<model_name>/. Defaults to model_name for backward compat.
    exp_name = exp_name or model_name
    run_dir = Path(output_config["run_dir"]) / exp_name
    run_dir.mkdir(parents=True, exist_ok=True)

    best_f1 = -1.0
    epochs_without_improvement = 0
    history: list[dict[str, object]] = []

    for epoch in range(1, training_config["epochs"] + 1):
        train_loss, train_metrics = run_epoch(
            model,
            train_loader,
            criterion,
            device,
            optimizer,
            limit_batches=limit_batches,
        )
        validation_loss, validation_metrics = run_epoch(
            model,
            validation_loader,
            criterion,
            device,
            limit_batches=limit_batches,
        )

        row = {
            "epoch": epoch,
            "train_loss": train_loss,
            "validation_loss": validation_loss,
            "train_accuracy": train_metrics["accuracy"],
            "validation_accuracy": validation_metrics["accuracy"],
            "validation_macro_f1": validation_metrics["macro_f1"],
        }
        history.append(row)
        print(json.dumps(row, indent=2))

        validation_f1 = float(validation_metrics["macro_f1"])
        if validation_f1 > best_f1:
            best_f1 = validation_f1
            epochs_without_improvement = 0
            torch.save(
                {
                    "model_name": model_name,
                    "classes": classes,
                    "state_dict": model.state_dict(),
                    "config": config,
                },
                run_dir / "best.pt",
            )
        else:
            epochs_without_improvement += 1

        if (
            epochs_without_improvement >= training_config["patience"]
            and epoch < training_config["epochs"]
        ):
            print(f"Early stopping at epoch {epoch}")
            break

    with (run_dir / "history.json").open("w", encoding="utf-8") as file:
        json.dump(history, file, indent=2)


def main() -> None:
    args = parse_args()
    config = load_config(args.config)
    if args.epochs is not None:
        config["training"]["epochs"] = args.epochs
    if args.batch_size is not None:
        config["training"]["batch_size"] = args.batch_size
    # Prefer the reproducibility block; fall back to the legacy top-level seed,
    # then 42, so configs lacking the block stay backward compatible.
    repro = config.get("reproducibility", {})
    seed = repro.get("seed", config.get("seed", 42))
    set_seed(seed, cudnn_deterministic=repro.get("cudnn_deterministic", False))

    if args.all_models:
        if args.exp_name:
            raise ValueError(
                "--exp-name names a single run directory and cannot be combined "
                "with --all-models."
            )
        model_names = config["models"]
    elif args.model:
        model_names = [args.model]
    else:
        raise ValueError("Provide --model or --all-models.")

    for model_name in model_names:
        train_one_model(
            config,
            model_name,
            pretrained=not args.no_pretrained,
            limit_batches=args.limit_batches,
            exp_name=args.exp_name,
            seed=seed,
        )


if __name__ == "__main__":
    main()
