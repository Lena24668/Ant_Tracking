#!/usr/bin/env python3
import argparse
import glob
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
import numpy as np


def pick_centroid_keys(keys):
    lower = {k.lower(): k for k in keys}
    candidates = [
        ("x#wcentroid", "y#wcentroid"),
        ("x#pcentroid", "y#pcentroid"),
        ("x_centroid", "y_centroid"),
        ("centroid_x", "centroid_y"),
        ("xc", "yc"),
    ]
    for xk, yk in candidates:
        if xk in lower and yk in lower:
            return lower[xk], lower[yk]
    return None, None


def plot_npz(npz_path, out_path, title=None):
    with np.load(npz_path) as data:
        xk, yk = pick_centroid_keys(data.keys())
        if not xk or not yk:
            raise KeyError(f"no centroid keys found in {npz_path}")
        x = data[xk]
        y = data[yk]
        if "time" in data:
            t = data["time"]
        else:
            t = np.arange(x.size, dtype=float)

    mask = np.isfinite(x) & np.isfinite(y)
    x = x[mask]
    y = y[mask]
    t = t[mask]

    if x.size == 0:
        raise ValueError(f"no finite centroid samples in {npz_path}")

    parent_dir = os.path.dirname(os.path.dirname(npz_path))
    bg_candidates = sorted(glob.glob(os.path.join(parent_dir, "average_*.png")))
    bg_img = None
    if bg_candidates:
        bg_img = plt.imread(bg_candidates[0])

    fig, ax = plt.subplots(figsize=(6, 6), dpi=150)
    if bg_img is not None:
        ax.imshow(bg_img, origin="upper")

    pts = np.column_stack([x, y])
    if pts.shape[0] >= 2:
        diffs = np.diff(pts, axis=0)
        dists = np.hypot(diffs[:, 0], diffs[:, 1])
        ok = dists <= 100.0
        segs = np.stack([pts[:-1], pts[1:]], axis=1)[ok]
        t_mid = (t[:-1] + t[1:]) / 2.0
        t_mid = t_mid[ok]
        if t_mid.size > 0:
            t_min = float(t_mid.min())
            t_max = float(t_mid.max())
            if t_max > t_min:
                t_norm = (t_mid - t_min) / (t_max - t_min)
            else:
                t_norm = np.zeros_like(t_mid)
            lc = LineCollection(segs, cmap="viridis_r", linewidths=0.9)
            lc.set_array(t_norm)
            ax.add_collection(lc)
    ax.scatter([1125], [3713], s=22, c="red", edgecolors="none", alpha=0.25, zorder=10)
    ax.set_xlabel(xk)
    ax.set_ylabel(yk)
    if title:
        ax.set_title(title)
    else:
        ax.set_title("Centroid trajectory")
    ax.set_aspect("equal", adjustable="box")
    ax.grid(True, linewidth=0.3, alpha=0.5)
    fig.tight_layout()
    fig.savefig(out_path)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(
        description="Plot centroid XY trajectories for each ID folder."
    )
    parser.add_argument(
        "--src-root",
        default="/data/2025-12-04/Videos_by_id",
        help="Root directory containing ID folders.",
    )
    args = parser.parse_args()

    id_dirs = sorted(
        d for d in glob.glob(os.path.join(args.src_root, "*")) if os.path.isdir(d)
    )
    if not id_dirs:
        raise SystemExit(f"no directories found under {args.src_root}")

    for d in id_dirs:
        npz_files = sorted(glob.glob(os.path.join(d, "data", "*.npz")))
        if not npz_files:
            print(f"skip (no npz): {d}")
            continue

        npz_path = npz_files[0]
        base = os.path.basename(d)
        date_part = base[:8] if len(base) >= 8 else base
        time_part = base[9:13] if len(base) >= 13 else ""
        id_part = base.split("_ID")[-1] if "_ID" in base else base
        out_name = f"{date_part}{time_part}_centroid_trajectory_ID{id_part}.png"
        out_path = os.path.join(d, out_name)
        title = f"ID{id_part} {date_part} {time_part}".strip()
        try:
            plot_npz(npz_path, out_path, title=title)
            print(f"wrote {out_path}")
        except Exception as exc:
            print(f"skip ({d}): {exc}")


if __name__ == "__main__":
    main()
