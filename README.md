# Ant Detection Project (YOLO-based)

## Overview

This project aims to automatically detect ants in video footage using a custom-trained YOLO model. The workflow includes data extraction from videos, dataset preparation, pre-annotation, dataset reduction, and model training.

The main challenge is that ants are small, often hard to detect, and appear in large amounts of video data. Therefore, the pipeline focuses on efficiently generating training data and improving detection performance.

---

## Project Structure

The repository contains the following key files:

- `tiling.py`
- `reduction_dataset.py`
- `Preannotation.ipynb`
- `Train_custom_YOLO_model_August.ipynb`

Each file represents one step in the pipeline.

---

## Workflow Summary

The full pipeline consists of the following steps:

1. Extract tiles from raw videos  
2. Reduce and clean the dataset  
3. Pre-annotate images using a model  
4. Manually refine annotations (external tools like Roboflow)  
5. Train a custom YOLO model  

---

## Step-by-Step Explanation

### 1. Tile Extraction (`tiling.py`)

**Purpose:**  
Extracts small image patches (tiles) from large video files.

**Why this is needed:**  
- Ants are small and difficult to detect in full-resolution frames  
- Tiling increases the relative size of ants in images  
- Enables more efficient and accurate training  

**What it does:**
- Loads videos from a directory  
- Optionally filters videos by time (e.g. only daytime footage)  
- Extracts random frames  
- Cuts multiple tiles per frame  
- Saves tiles into folders (e.g. 1500 images per folder)

---

### 2. Dataset Reduction (`reduction_dataset.py`)

**Purpose:**  
Reduces dataset size and removes unnecessary or redundant images.

**Why this is needed:**
- Large datasets slow down training  
- Many tiles may contain no ants  
- Reducing noise improves model performance  

**What it does:**
- Filters images based on criteria (e.g. empty frames)  
- Optionally balances dataset  
- Prepares a cleaner dataset for annotation/training  

---

### 3. Pre-Annotation (`Preannotation.ipynb`)

**Purpose:**  
Automatically generates initial bounding boxes using a model.

**Why this is needed:**
- Manual annotation is very time-consuming  
- Pre-annotation speeds up the process significantly  

**What it does:**
- Loads images  
- Runs inference using an existing YOLO model  
- Generates bounding boxes  
- Applies filtering (e.g. confidence threshold, IoU / NMS)  
- Outputs annotations (e.g. YOLO format)

**Important:**  
These annotations are not perfect and must be manually corrected.

---

### 4. Manual Annotation (External Step)

**Tools:**  
- Roboflow or similar annotation platforms  

**Purpose:**  
Clean and correct pre-annotations.

**Why this is needed:**
- Remove duplicate boxes  
- Fix incorrect detections  
- Ensure high-quality training data  

---

### 5. Model Training (`Train_custom_YOLO_model_August.ipynb`)

**Purpose:**  
Train a custom YOLO model on the prepared dataset.

**What it does:**
- Loads dataset  
- Configures training parameters  
- Trains YOLO model  
- Evaluates performance  

**Output:**
- Trained weights  
- Detection results  
- Metrics (precision, recall, mAP)

---

## Key Design Decisions

- **Tiling instead of full images**  
  → improves small object detection  

- **Pre-annotation**  
  → reduces manual workload  

- **Dataset reduction**  
  → improves efficiency and quality  

- **Iterative workflow**  
  → model → annotation → retraining loop  

---

## Requirements

Typical dependencies include:

- Python 3.x  
- OpenCV  
- NumPy  
- Ultralytics YOLO  
- Jupyter Notebook  

---

## Future Improvements

- Better filtering of empty images  
- Improved handling of overlapping bounding boxes  
- More balanced dataset (ants vs no ants)  
- Active learning loop (model suggests difficult samples)  

---

## Goal of the Project

To build a reliable and scalable system for detecting ants in large video datasets, enabling further analysis of their behaviour in ecological research.
