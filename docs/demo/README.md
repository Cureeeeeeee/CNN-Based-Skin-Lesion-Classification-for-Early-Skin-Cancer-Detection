# Prediction Demo Set

This folder stores a stable ResNet50 prediction demo set for presentations. The
selected images are copied into `docs/demo/images/` so the demo does not depend
on live access to the full raw dataset.

Included cases:

- `easy_correct`: top-1 prediction is correct with high confidence.
- `top3_recovery`: top-1 prediction is wrong, but the true class appears in top 3.
- `difficult_uncertain`: uncertain or difficult example showing model limitation.
- `weak_class_mel`: melanoma-related weak-class example for discussion.

Regenerate the demo set:

```bash
python -m src.skinlesion.prepare_demo_set \
  --checkpoint runs/resnet50/best.pt \
  --model resnet50 \
  --split-csv data/processed/splits.csv \
  --output-dir docs/demo
```
