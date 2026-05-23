"""Post-hoc probability calibration for classifier outputs.

Implements temperature scaling (Guo et al. 2017), expected calibration
error (ECE), and reliability diagrams. Temperature scaling fits a single
scalar T on a validation set such that the softmax of logits / T minimises
negative log-likelihood. It is monotone in argmax, so it does not change
top-1 accuracy — only the probability distribution.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import torch
import torch.nn.functional as F
from torch import nn


@dataclass(frozen=True)
class CalibrationMetrics:
    """Summary of probabilistic calibration on a held-out set."""

    nll: float
    ece: float
    brier: float
    accuracy: float


@dataclass(frozen=True)
class ReliabilityBins:
    """Per-bin aggregates for a reliability diagram (top-1 confidence)."""

    bin_edges: list[float]
    bin_conf: list[float]
    bin_acc: list[float]
    bin_count: list[int]


# ── Core metrics ──────────────────────────────────────────────────────────────


def negative_log_likelihood(logits: torch.Tensor, labels: torch.Tensor) -> float:
    """Mean cross-entropy of logits against integer class labels."""
    return F.cross_entropy(logits, labels, reduction="mean").item()


def expected_calibration_error(
    probs: torch.Tensor,
    labels: torch.Tensor,
    n_bins: int = 15,
) -> float:
    """Standard top-1 ECE (Naeini et al. 2015, Guo et al. 2017).

    Bin samples by max-probability into n_bins equal-width buckets on [0, 1].
    Each bin contributes |mean_conf − mean_acc| × (bin_count / total).
    """
    confidences, predictions = probs.max(dim=1)
    accuracies = predictions.eq(labels).float()

    edges = torch.linspace(0.0, 1.0, n_bins + 1, device=probs.device)
    total = labels.shape[0]
    ece = 0.0

    for i in range(n_bins):
        lo = edges[i]
        hi = edges[i + 1]
        # First bin is closed on the left so probs == 0 land somewhere.
        if i == 0:
            in_bin = (confidences >= lo) & (confidences <= hi)
        else:
            in_bin = (confidences > lo) & (confidences <= hi)
        count = int(in_bin.sum().item())
        if count == 0:
            continue
        bin_acc = accuracies[in_bin].mean().item()
        bin_conf = confidences[in_bin].mean().item()
        ece += abs(bin_acc - bin_conf) * (count / total)
    return float(ece)


def brier_score(probs: torch.Tensor, labels: torch.Tensor) -> float:
    """Multi-class Brier score: mean squared error against one-hot labels."""
    num_classes = probs.shape[1]
    one_hot = F.one_hot(labels, num_classes=num_classes).float()
    return float(((probs - one_hot) ** 2).sum(dim=1).mean().item())


def accuracy(probs: torch.Tensor, labels: torch.Tensor) -> float:
    return float(probs.argmax(dim=1).eq(labels).float().mean().item())


def summarise(logits: torch.Tensor, labels: torch.Tensor) -> CalibrationMetrics:
    """Compute NLL, ECE, Brier, accuracy from raw logits."""
    probs = F.softmax(logits, dim=1)
    return CalibrationMetrics(
        nll=negative_log_likelihood(logits, labels),
        ece=expected_calibration_error(probs, labels),
        brier=brier_score(probs, labels),
        accuracy=accuracy(probs, labels),
    )


# ── Temperature scaling ───────────────────────────────────────────────────────


def fit_temperature(
    logits: torch.Tensor,
    labels: torch.Tensor,
    max_iter: int = 100,
    lr: float = 0.05,
) -> float:
    """Fit a single positive scalar T minimising NLL of softmax(logits / T).

    Optimises log_T so T stays positive without explicit constraints.
    Returns the fitted T as a float.
    """
    device = logits.device
    log_T = nn.Parameter(torch.zeros(1, device=device))
    optimizer = torch.optim.LBFGS([log_T], lr=lr, max_iter=max_iter)

    def closure() -> torch.Tensor:
        optimizer.zero_grad()
        T = log_T.exp()
        loss = F.cross_entropy(logits / T, labels)
        loss.backward()
        return loss

    optimizer.step(closure)
    return float(log_T.exp().detach().item())


def apply_temperature(logits: torch.Tensor, temperature: float) -> torch.Tensor:
    """Return probabilities from temperature-scaled logits."""
    if temperature <= 0:
        raise ValueError(f"Temperature must be > 0, got {temperature}")
    return F.softmax(logits / temperature, dim=1)


# ── Reliability diagram ───────────────────────────────────────────────────────


def reliability_bins(
    probs: torch.Tensor,
    labels: torch.Tensor,
    n_bins: int = 15,
) -> ReliabilityBins:
    """Per-bin (count, mean_conf, mean_acc) for plotting."""
    confidences, predictions = probs.max(dim=1)
    accuracies = predictions.eq(labels).float()
    edges = torch.linspace(0.0, 1.0, n_bins + 1)

    bin_conf: list[float] = []
    bin_acc: list[float] = []
    bin_count: list[int] = []

    for i in range(n_bins):
        lo = edges[i].item()
        hi = edges[i + 1].item()
        if i == 0:
            in_bin = (confidences >= lo) & (confidences <= hi)
        else:
            in_bin = (confidences > lo) & (confidences <= hi)
        count = int(in_bin.sum().item())
        if count == 0:
            bin_conf.append(float("nan"))
            bin_acc.append(float("nan"))
        else:
            bin_conf.append(float(confidences[in_bin].mean().item()))
            bin_acc.append(float(accuracies[in_bin].mean().item()))
        bin_count.append(count)

    return ReliabilityBins(
        bin_edges=[float(x) for x in edges.tolist()],
        bin_conf=bin_conf,
        bin_acc=bin_acc,
        bin_count=bin_count,
    )


def plot_reliability_diagram(
    before: ReliabilityBins,
    after: ReliabilityBins,
    model_name: str,
    output_path: str | Path,
) -> Path:
    """Render a 2-panel reliability diagram (before / after temperature)."""
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    fig, axes = plt.subplots(1, 2, figsize=(9, 4.2), sharey=True)
    for ax, bins, title in (
        (axes[0], before, "Before"),
        (axes[1], after, "After"),
    ):
        _draw_panel(ax, bins, title)

    fig.suptitle(f"{model_name} — reliability (val set)", fontsize=12)
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    fig.savefig(output, dpi=150)
    plt.close(fig)
    return output


def _draw_panel(ax, bins: ReliabilityBins, title: str) -> None:
    edges = np.asarray(bins.bin_edges)
    centres = (edges[:-1] + edges[1:]) / 2
    width = edges[1] - edges[0]
    confs = np.asarray(bins.bin_conf)
    accs = np.asarray(bins.bin_acc)
    counts = np.asarray(bins.bin_count)

    # Per-bin accuracy bars (skip empty bins)
    mask = counts > 0
    ax.bar(
        centres[mask],
        accs[mask],
        width=width * 0.95,
        color="#0F4C81",
        alpha=0.85,
        edgecolor="#0A3A66",
        linewidth=0.5,
        label="accuracy",
    )

    # Confidence overlay (red dots)
    ax.plot(
        centres[mask],
        confs[mask],
        marker="o",
        color="#B91C1C",
        linewidth=0,
        markersize=4,
        label="confidence",
    )

    # Perfect-calibration diagonal
    ax.plot([0, 1], [0, 1], "--", color="#94A3B8", linewidth=1, label="perfect")

    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.set_xlabel("predicted confidence")
    if title == "Before":
        ax.set_ylabel("accuracy")
    ax.set_title(title, fontsize=10)
    ax.grid(True, alpha=0.2, linewidth=0.5)
    ax.legend(loc="upper left", fontsize=8, frameon=False)
