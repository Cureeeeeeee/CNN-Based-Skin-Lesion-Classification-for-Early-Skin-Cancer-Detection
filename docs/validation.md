# Validation Notes

Latest delivery-readiness validation:

- Python compile check: passed with `python -m compileall src`.
- Notebook JSON check: passed for `notebooks/skin_lesion_delivery_demo.ipynb`.
- Report asset generation: passed with `python -m src.skinlesion.report_assets`.
- Demo set generation: passed with `python -m src.skinlesion.prepare_demo_set`.
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
  - `flutter analyze`: Flutter tool/analysis-server crash in this environment.
  - `flutter build web`: failed with icon tree-shaking under the OneDrive Chinese path.
  - `flutter build web --no-tree-shake-icons`: passed.

ResNet50 remains the default deployment model because it has the best validated
test accuracy and macro F1-score among the completed experiments.
