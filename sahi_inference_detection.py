from sahi import AutoDetectionModel
from sahi.predict import get_sliced_prediction
import os
import json

image_path = "/Users/lenawunderlich/Library/Mobile Documents/com~apple~CloudDocs/Studium Shit/Master/Hiwi/Ants/Images/random_frame_0.jpg"
model_path = "/Users/lenawunderlich/Library/Mobile Documents/com~apple~CloudDocs/Studium Shit/Master/Hiwi/Ants/Models_Lena/best_endtoend_false.pt"
output_dir = "/Users/lenawunderlich/Library/Mobile Documents/com~apple~CloudDocs/Studium Shit/Master/Hiwi/Ants/Results/random_frame_0"

os.makedirs(output_dir, exist_ok=True)

detection_model = AutoDetectionModel.from_pretrained(
    model_type="ultralytics",
    model_path=model_path,
    confidence_threshold=0.25,
    device="cpu"
)

result = get_sliced_prediction(
    image_path,
    detection_model,
    slice_height=640,
    slice_width=640,
    overlap_height_ratio=0.2,
    overlap_width_ratio=0.2,
)

object_prediction_list = result.object_prediction_list
print(f"Number of detections: {len(object_prediction_list)}")

detections = []
for i, pred in enumerate(object_prediction_list):
    x1, y1, x2, y2 = pred.bbox.to_xyxy()
    det = {
        "detection_id": i,
        "bbox_xyxy": [float(x1), float(y1), float(x2), float(y2)],
        "score": float(pred.score.value),
        "category_id": int(pred.category.id),
        "category_name": str(pred.category.name),
    }
    detections.append(det)

    print(f"\nDetection {i}")
    print("bbox:", det["bbox_xyxy"])
    print("score:", det["score"])
    print("category_id:", det["category_id"])
    print("category_name:", det["category_name"])

# save JSON results
json_path = os.path.join(output_dir, "detections.json")
with open(json_path, "w") as f:
    json.dump(detections, f, indent=2)

# optional COCO-style predictions
coco_predictions = result.to_coco_predictions(image_id=1)
coco_path = os.path.join(output_dir, "coco_predictions.json")
with open(coco_path, "w") as f:
    json.dump(coco_predictions, f, indent=2)

# save visualization
result.export_visuals(export_dir=output_dir)

print(f"\nSaved visualization and JSON files to:\n{output_dir}")