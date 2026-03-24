# Ant Detection Project (YOLO-based)

## Overview

This project aims to automatically detect ants in video footage using a custom-trained YOLO model. The workflow includes video preprocessing, dataset preparation, pre-annotation, dataset reduction, inference, and model training.

Ants are small, often difficult to detect, and appear in large volumes of video data. Therefore, this pipeline focuses on efficient data generation, scalable processing, and improving detection performance.

---

## Project Structure

The repository is organized into the following components:

- tiling.py
- reduction_of_dataset.py
- Preannotation_of_images.ipynb
- Train_custom_YOLO_model_August.ipynb
- sahi_inference_detection.py
- chunk_aupa.py (new)
- dir_to_video.py (new)
- plot_centroid_trajectories.py (new)

### Additional folders

- Server_pipeline/
  Scripts for running batch processing and rendering pipelines on a server.

- Trex_August/
  Scripts and configuration files for integrating detections into the T-Rex tracking software.

### Supporting workflows for file rendering and trajectory visualization

- `dir_to_video.py`
  - Render one image directory (or the directory containing a file) into a single MP4
  - Supports image glob, fps, limit, skip frames, and optional keeping of the concat list for debugging
  - Uses numeric filename sorting to preserve time order

- `chunk_aupa.py`
  - Split long ordered image sequences into chunks (default max 6000 frames per chunk)
  - Optionally render each chunk to MP4 with ffmpeg
  - Save chunk metadata as a JSON report and warn on index gaps/group changes

- `plot_centroid_trajectories.py`
  - Read per-ID centroid `.npz` data and draw XY trajectories with time-based color
  - Auto-detect common centroid key names (`wcentroid`, `pcentroid`, `xc/yc`, etc.)
  - Optionally overlay an average background image from the same session
  - Output trajectory PNG files for analysis and review

---

## Workflow Summary

The full pipeline consists of the following steps:

0. Convert image sequences to video (`dir_to_video.py`)
1. Chunk long frame sequences into manageable parts (`chunk_aupa.py`)
2. Extract tiles from raw videos (`tiling.py`)
3. Reduce and clean the dataset (`reduction_of_dataset.py`)
4. Pre-annotate images using a model (`Preannotation_of_images.ipynb`)
5. Manually refine annotations (external tools like Roboflow)
6. Train a custom YOLO model (`Train_custom_YOLO_model_August.ipynb`)
7. Run inference (e.g. with SAHI for tiled detection) (`sahi_inference_detection.py`)
8. Export detections for tracking (T-Rex) ('trex_batch_pipeline.sh')
9. Plot centroid trajectories from tracking outputs (`plot_centroid_trajectories.py`)

---

## Step-by-Step Explanation

### 1. Tile Extraction (tiling.py)

Purpose:  
Extracts small image patches (tiles) from large video files.

Why this is needed:
- Ants are small and difficult to detect in full-resolution frames  
- Tiling increases the relative size of ants in images  
- Enables more efficient and accurate training  

What it does:
- Loads videos from a directory  
- Optionally filters videos by time (e.g. daytime footage)  
- Extracts frames  
- Generates multiple tiles per frame  
- Saves tiles in structured folders  

---

### 2. Dataset Reduction (reduction_of_dataset.py)

Purpose:  
Reduces dataset size and removes redundant or uninformative images.

Why this is needed:
- Large datasets slow down training  
- Many tiles may contain no ants  
- Reducing noise improves model performance  

What it does:
- Filters images based on defined criteria  
- Removes empty or low-information samples  
- Prepares a cleaner dataset for annotation and training  

---

### 3. Pre-Annotation (Preannotation_of_images.ipynb)

Purpose:  
Automatically generates initial bounding boxes using a trained model.

Why this is needed:
- Manual annotation is very time-consuming  
- Pre-annotation significantly speeds up labeling  

What it does:
- Loads image tiles  
- Runs YOLO inference  
- Applies filtering (confidence threshold, NMS)  
- Outputs annotations (YOLO format)

Important:  
Annotations must be manually reviewed and corrected.

---

### 4. Manual Annotation (External Step)

Tools:  
- Roboflow or similar annotation platforms  

Purpose:  
Refine and correct pre-annotations.

Why this is needed:
- Remove duplicate detections  
- Fix incorrect bounding boxes  
- Ensure high-quality training data  

---

### 5. Model Training (Train_custom_YOLO_model_August.ipynb)

Purpose:  
Train a custom YOLO model on the prepared dataset.

What it does:
- Loads dataset  
- Configures training parameters  
- Trains YOLO model  
- Evaluates performance  

Output:
- Trained weights  
- Detection metrics (precision, recall, mAP)  

---

### 6. Inference with SAHI (sahi_inference_detection.py)

Purpose:  
Run inference on large images or frames using tiled prediction.

Why this is needed:
- Improves detection of small objects  
- Reduces missed detections at image boundaries  

What it does:
- Splits images into overlapping tiles  
- Runs detection on each tile  
- Merges predictions (NMS)  
- Outputs final detections  

---

### 7. Pipeline Execution (Server_pipeline/)

Purpose:  
Automate large-scale processing of videos and image batches.

What it includes:
- Chunk-based video processing  
- Rendering scripts  
- Batch execution via shell scripts  

---

### 8. Tracking With Trex (Trex_August/) (trex_batch_pipeline.sh) (Trex_pipeline.settings)

Purpose:  
Prepare detection outputs for tracking with T-Rex software.

What it includes:
- Conversion scripts  
- Chunk handling  
- Trajectory analysis tools  

trex_batch_pipeline.sh:
- Chunk handling: it runs trex on videos in batches (days or hour) with predefined settings (Trex_pipeline.settings)

---

## Key Design Decisions

- Tiling instead of full images  
  → improves small object detection  

- Pre-annotation  
  → reduces manual workload  

- Dataset reduction  
  → improves efficiency and data quality  

- SAHI-based inference  
  → enhances detection performance on large images  

- Modular pipeline  
  → allows flexible scaling and debugging  

---

## Requirements

Typical dependencies include:

- Python 3.x  
- OpenCV  
- NumPy  
- Ultralytics YOLO  
- SAHI  
- Jupyter Notebook  

---

## Future Improvements

- Improved filtering of empty images  
- Better handling of overlapping detections  
- More balanced dataset (ants vs no ants)  
- Active learning loop for dataset refinement  
- Full automation of the pipeline  

---

## Goal of the Project

To build a reliable and scalable system for detecting ants in large video datasets, enabling downstream tracking and behavioural analysis in ecological research.
