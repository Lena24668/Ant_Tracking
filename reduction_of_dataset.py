import argparse
import random
import shutil
from pathlib import Path

IMG_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".webp"}

def is_label_empty(label_path: Path) -> bool:
    if not label_path.exists():
        return True
    return label_path.read_text(encoding="utf-8", errors="ignore").strip() == ""

def find_matching_image(images_dir: Path, stem: str):
    for p in images_dir.glob(stem + ".*"):
        if p.suffix.lower() in IMG_EXTS:
            return p
    return None

def ensure_dirs(out_split: Path):
    (out_split / "images").mkdir(parents=True, exist_ok=True)
    (out_split / "labels").mkdir(parents=True, exist_ok=True)

def main():
    ap = argparse.ArgumentParser(
        description="Downsample empty-label samples to a target positive/negative ratio."
    )
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--pos_fraction", type=float, default=0.5)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--splits", nargs="+", default=["train", "valid", "test"])
    args = ap.parse_args()

    if not (0.0 < args.pos_fraction < 1.0):
        raise ValueError("--pos_fraction must be between 0 and 1.")

    random.seed(args.seed)

    in_root = Path(args.input).resolve()
    out_root = Path(args.output).resolve()
    out_root.mkdir(parents=True, exist_ok=True)

    print("Input :", in_root)
    print("Output:", out_root)
    print("Target pos_fraction:", args.pos_fraction)

    for split in args.splits:
        split_in = in_root / split
        images_dir = split_in / "images"
        labels_dir = split_in / "labels"

        positives, negatives = [], []

        for label_path in sorted(labels_dir.glob("*.txt")):
            img_path = find_matching_image(images_dir, label_path.stem)
            if img_path is None:
                continue
            if is_label_empty(label_path):
                negatives.append((img_path, label_path))
            else:
                positives.append((img_path, label_path))

        P, N = len(positives), len(negatives)

        if P == 0:
            keep = negatives
        else:
            target_N = int(round(P * (1 - args.pos_fraction) / args.pos_fraction))
            keep_N = min(N, target_N)
            keep = positives + (random.sample(negatives, keep_N) if keep_N > 0 else [])

        split_out = out_root / split
        ensure_dirs(split_out)

        for img_path, label_path in keep:
            shutil.copy2(img_path, split_out / "images" / img_path.name)
            shutil.copy2(label_path, split_out / "labels" / label_path.name)

        print(f"[{split}] Pos {P}, Neg {N}, Kept {len(keep)}")

    print("Done.")

if __name__ == "__main__":
    main()