# Prediction Demo

This folder stores lightweight prediction demo outputs. The original dataset
images are not committed to GitHub; demo JSON files reference local image paths
under `data/processed/`.

Run a ResNet50 top-3 prediction demo:

```bash
python -m src.skinlesion.predict_demo \
  --checkpoint runs/resnet50/best.pt \
  --model resnet50 \
  --sample-split test \
  --sample-label mel \
  --top-k 3 \
  --output docs/demo/prediction_demo_resnet50.json
```
