# Presentation Demo Runbook

This runbook is the recommended order for a stable project demonstration.

## 1. Demo Goal

Show a complete product-like flow:

```text
Flutter app -> image upload -> FastAPI /predict -> ResNet50 -> top-3 result screen
```

ResNet50 should be introduced as the default deployment model because it has
the best validated test accuracy and macro F1 among the four trained CNN
architectures.

## 2. Pre-Demo Checklist

From the project root:

```powershell
cd "C:\Users\user\Documents\New project"
git status
```

Confirm these local files exist:

- `runs/resnet50/best.pt`
- `docs/demo/images/easy_correct_ISIC_0024308.jpg`
- `mobile_app/`

Run the API smoke test after starting FastAPI:

```powershell
.\.venv\Scripts\python.exe scripts\test_api_demo.py --base-url http://127.0.0.1:8000
```

Expected result: the script prints `API demo validation passed` and three
predictions.

## 3. Start FastAPI

```powershell
cd "C:\Users\user\Documents\New project"
.\.venv\Scripts\python.exe -m uvicorn src.skinlesion.api:app --host 0.0.0.0 --port 8000
```

Useful pages:

- Root: `http://127.0.0.1:8000/`
- Health: `http://127.0.0.1:8000/health`
- Model info: `http://127.0.0.1:8000/model-info`
- Docs: `http://127.0.0.1:8000/docs`

## 4. Start Flutter Web

Open a second PowerShell window:

```powershell
cd "C:\Users\user\Documents\New project\mobile_app"
flutter pub get
flutter run -d chrome
```

Use this API URL in Flutter Web:

```text
http://127.0.0.1:8000
```

For Android emulator testing, use:

```text
http://10.0.2.2:8000
```

For a real phone, use the PC LAN IP:

```text
http://<PC-LAN-IP>:8000
```

## 5. Recommended Live Demo Flow

1. Open the Flutter app home screen.
2. Upload `docs/demo/images/easy_correct_ISIC_0024308.jpg`.
3. Press `Analyze`.
4. Keep API mode enabled and confirm the API URL is `http://127.0.0.1:8000`.
5. Run analysis.
6. Show the top-3 predictions and confidence bars.
7. Open the result screen and read the disclaimer.
8. Open the model comparison screen.
9. Explain that ResNet50 is selected because it has the best test accuracy and
   macro F1 among MobileNetV3 Small, EfficientNet-B0, DenseNet121, and ResNet50.

## 6. Fallback Plan

If the backend is unavailable during presentation:

1. Turn on `Mock mode` in the Classification screen.
2. Run analysis again.
3. Explain that mock mode is only a presentation safety fallback and does not
   call the model.

If Flutter Web has trouble starting:

```powershell
flutter build web --no-tree-shake-icons
```

Then continue with the backend API documentation and `scripts/test_api_demo.py`
as the technical proof of the pipeline.

## 7. Talking Points

- The task is multiclass image classification, not clinical diagnosis.
- The dataset contains seven HAM10000 lesion classes.
- The pipeline uses transfer learning with pretrained CNN architectures.
- Metrics include test accuracy and macro F1, not only accuracy.
- Macro F1 is important because the dataset is imbalanced.
- ResNet50 is the default model; DenseNet121 is a strong comparison baseline.
- Grad-CAM heatmaps and YOLO lesion localisation are planned future extensions.

## 8. Known Limitations To State Clearly

- The prototype is for educational demonstration only.
- It is not a medical diagnosis system.
- Minority classes remain more difficult.
- A real clinical workflow would require expert validation, regulatory review,
  and stronger external testing.
