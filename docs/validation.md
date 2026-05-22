# Validation Notes

Latest delivery-readiness validation:

- Python compile check: passed with `python -m compileall src scripts`.
- Notebook JSON check: passed for `notebooks/skin_lesion_delivery_demo.ipynb`.
- Report asset generation: passed with `python -m src.skinlesion.report_assets`.
- Demo set generation: passed with `python -m src.skinlesion.prepare_demo_set`.
- FastAPI real uvicorn validation on `127.0.0.1:8000`:
  - `GET /`: passed, root project JSON returned.
  - `GET /health`: passed, `status=ok`, ResNet50 loaded.
  - `GET /model-info`: passed, default model reported as ResNet50.
  - `GET /docs`: passed with HTTP 200.
  - `POST /predict`: passed through `scripts/test_api_demo.py`.
  - Demo top-3 output for `easy_correct_ISIC_0024308.jpg`: `nv` 91.28%, `mel` 8.58%, `bkl` 0.13%.
- FastAPI TestClient:
  - `GET /health`: passed, ResNet50 loaded.
  - `GET /model-info`: passed, default model reported as ResNet50.
  - `POST /predict`: passed, top-3 predictions returned.
  - Empty upload: returned HTTP 400.
  - Invalid image upload: returned HTTP 400.
- Real uvicorn startup: passed on `127.0.0.1:8010`; `/health` returned `status=ok`.
- Flutter:
  - Flutter SDK detected at `C:\Users\user\develop\flutter`.
  - `flutter pub get`: passed.
  - `dart analyze lib test`: passed with no issues.
  - `flutter test`: passed.
  - `flutter build web --no-tree-shake-icons`: passed.
  - Flutter Web API mode is implemented with multipart upload to `/predict`.
  - Flutter mock mode is implemented as a fallback and covered by UI flow.
  - Android emulator workflow is documented with `http://10.0.2.2:8000`; not run in this validation pass.

ResNet50 remains the default deployment model because it has the best validated
test accuracy and macro F1-score among the completed experiments.
