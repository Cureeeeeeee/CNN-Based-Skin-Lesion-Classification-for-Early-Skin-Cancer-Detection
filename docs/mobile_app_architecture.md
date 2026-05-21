# Mobile App Architecture

![Mobile app architecture](figures/mobile_app_architecture.png)

The prototype uses Flutter as the mobile frontend and FastAPI as the model
serving backend. The first mobile version uploads a camera/gallery image to the
backend, where the ResNet50 checkpoint performs classification and returns the
predicted class, confidence score, and top candidates.

```mermaid
flowchart LR
    A["Flutter mobile app<br/>Camera or gallery input"] -->|Image upload| B["FastAPI backend<br/>/predict"]
    B --> C["ResNet50 classifier<br/>runs/resnet50/best.pt"]
    C -->|Prediction JSON| D["Result screen<br/>Top 3 classes + confidence"]
    D --> A
```
