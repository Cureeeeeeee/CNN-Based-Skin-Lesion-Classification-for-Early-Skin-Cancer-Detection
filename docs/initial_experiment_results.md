# Initial Experiment Results

## Task Type

Image classification.

## Experimental Settings

The initial stage of this project focuses on multiclass skin lesion
classification using the HAM10000 dataset. The task is to classify each
dermatoscopic image into one of seven categories: `akiec`, `bcc`, `bkl`, `df`,
`mel`, `nv`, and `vasc`.

The planned CNN architectures are MobileNetV3, ResNet50, EfficientNet-B0, and
DenseNet121. These models will use transfer learning with pretrained ImageNet
weights. The final classification layer will be replaced with a seven-class
output layer. Input images will be resized to 224 x 224 pixels and normalized
using ImageNet statistics. Training augmentation will include horizontal and
vertical flipping, random rotation, and brightness/contrast variation.

The dataset split target is 70% training, 15% validation, and 15% testing. When
HAM10000 `lesion_id` values are available, the split process will keep duplicate
lesion groups in the same split to reduce data leakage. Class imbalance will be
handled with weighted cross-entropy loss. AdamW will be used as the optimizer,
with early stopping based on validation macro F1-score.

## Initial Results

The completed experiments used MobileNetV3 Small, ResNet50, EfficientNet-B0,
and DenseNet121 with ImageNet pretrained weights. The best checkpoint for each
model was selected by validation macro F1-score.

| CNN Architecture | Train Accuracy | Validation Accuracy | Test Accuracy |
| --- | ---: | ---: | ---: |
| MobileNetV3 Small | 68.96% | 69.35% | 67.76% |
| ResNet50 | 84.51% | 79.38% | 80.22% |
| EfficientNet-B0 | 87.28% | 78.97% | 77.45% |
| DenseNet121 | 84.70% | 79.38% | 79.64% |

Additional test metrics:

| CNN Architecture | Macro Precision | Macro Recall | Macro F1-score | Weighted F1-score |
| --- | ---: | ---: | ---: | ---: |
| MobileNetV3 Small | 52.09% | 70.26% | 57.26% | 70.72% |
| ResNet50 | 64.58% | 75.75% | 69.03% | 80.95% |
| EfficientNet-B0 | 59.93% | 72.48% | 64.77% | 78.73% |
| DenseNet121 | 65.48% | 75.17% | 68.96% | 80.66% |

## Initial Analysis

MobileNetV3 Small provides the first working lightweight baseline for the
classification pipeline. EfficientNet-B0 improved the test accuracy from 67.76%
to 77.45% and the macro F1-score from 57.26% to 64.77%. ResNet50 achieved the
strongest initial result, with 80.22% test accuracy and 69.03% macro F1-score.
DenseNet121 performed very closely to ResNet50, reaching 79.64% test accuracy
and 68.96% macro F1-score.

Per-class performance should still be reviewed carefully. The `nv` class
achieved strong precision, while classes such as `akiec`, `bkl`, and `mel`
remain more difficult. Overall, the results suggest that the deeper ResNet and
DenseNet architectures are more effective than the lightweight MobileNet
baseline for this dataset, while EfficientNet-B0 offers a useful middle point
between compactness and performance.
