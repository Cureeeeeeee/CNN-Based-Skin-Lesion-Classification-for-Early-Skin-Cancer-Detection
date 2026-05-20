from __future__ import annotations

import torch.nn as nn
import timm


def create_model(
    model_name: str,
    num_classes: int,
    dropout: float = 0.0,
    pretrained: bool = True,
) -> nn.Module:
    return timm.create_model(
        model_name,
        pretrained=pretrained,
        num_classes=num_classes,
        drop_rate=dropout,
    )
