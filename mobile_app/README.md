# Skin Lesion Mobile Prototype

Flutter prototype for the skin lesion analysis system. The app uploads a camera
or gallery image to the FastAPI backend and displays the predicted lesion class,
confidence score, and top candidates.

## Run

Install Flutter, then run:

```bash
flutter create . --platforms android,ios
flutter pub get
flutter run
```

Start the backend before using the app:

```bash
uvicorn src.skinlesion.api:app --host 0.0.0.0 --port 8000
```

Default API URL:

- Android emulator: `http://10.0.2.2:8000`
- Real phone: replace it with the computer's LAN IP, for example
  `http://192.168.1.20:8000`
