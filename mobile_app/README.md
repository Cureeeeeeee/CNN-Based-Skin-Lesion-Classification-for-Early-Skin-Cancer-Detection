# Skin Lesion Mobile Prototype

Flutter prototype for the skin lesion analysis system. The app uploads a camera
or gallery image to the FastAPI backend and displays the predicted lesion class,
confidence score, and top candidates.
It also includes a mock prediction mode for presentation safety when the backend
is not reachable.

## Screens

- HomeScreen: image selection, preview, and entry to analysis.
- ClassificationScreen: API URL, API/mock mode switch, loading state, and inline results.
- ResultScreen: final top-3 predictions, confidence scores, and disclaimer.
- ModelComparisonScreen: MobileNetV3, EfficientNet-B0, DenseNet121, and ResNet50 metrics.

The current UI is styled as a polished four-screen mobile demo with a blue
health-app theme, rounded cards, prominent image preview areas, confidence
cards, and clear presentation fallback through mock mode.

## Run

Install Flutter, then run:

```bash
flutter pub get
flutter run -d chrome
```

Start the backend before using the app:

```bash
uvicorn src.skinlesion.api:app --host 0.0.0.0 --port 8000
```

Default API URL:

- Flutter Web: `http://127.0.0.1:8000`
- Android emulator: `http://10.0.2.2:8000`
- Real phone: replace it with the computer's LAN IP, for example
  `http://192.168.1.20:8000`

The API URL is editable inside the Classification screen. API mode calls
FastAPI `/predict`; mock mode uses a fixed top-3 output and does not call the
backend.

ResNet50 remains the default deployment model. The mobile UI only changes the
presentation layer and does not alter the backend model selection.

If building web from the current OneDrive path with Chinese characters, use:

```bash
flutter build web --no-tree-shake-icons
```

## Validation

Validated locally:

- `flutter pub get`: passed
- `dart analyze lib test`: passed
- `flutter test`: passed
- `flutter build web --no-tree-shake-icons`: passed
