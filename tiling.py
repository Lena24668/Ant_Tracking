import cv2
import numpy as np
from pathlib import Path


def load_image_sequence(image_dir: str):
    image_dir = Path(image_dir)
    return sorted(image_dir.glob("*.jpg"))


def extract_random_tiles(image_dir: str,
                         output_dir: str,
                         n_tiles: int,
                         tile_size: int = 640):

    """Extract random spatial tiles from random images in a directory."""

    frames = load_image_sequence(image_dir)

    if len(frames) == 0:
        raise ValueError("No JPG images found in directory.")

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Read one image to get dimensions
    sample = cv2.imread(str(frames[0]))
    h, w = sample.shape[:2]

    if tile_size > w or tile_size > h:
        raise ValueError("Tile size larger than image dimensions.")

    n_frames = len(frames)

    for i in range(n_tiles):

        frame_idx = np.random.randint(0, n_frames)
        img = cv2.imread(str(frames[frame_idx]))

        if img is None:
            continue

        x0 = np.random.randint(0, w - tile_size)
        y0 = np.random.randint(0, h - tile_size)

        tile = img[y0:y0 + tile_size,
                   x0:x0 + tile_size]

        out_path = output_dir / f"tile_{i:06d}_f{frame_idx}_x{x0}_y{y0}.png"

        cv2.imwrite(str(out_path), tile)

        if i % 100 == 0:
            print(f"Extracted {i + 1}/{n_tiles} tiles.")


if __name__ == "__main__":
    extract_random_tiles(
        image_dir="/Volumes/HangarAnts/2025-11-28/2025-11-28-13",
        output_dir="/Volumes/PUMBAAAUPA/Ants/Tiling_Images/tiles_2025-11-28_2025-11-28-13",
        n_tiles=2000,
        tile_size=640
    )