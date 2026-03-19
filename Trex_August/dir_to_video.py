#!/usr/bin/env python3
"""Render a directory of images into a video using ffmpeg."""

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "path",
        help="directory containing images, or any file inside that directory",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="output mp4 path (default: videos/<base>.mp4)",
    )
    parser.add_argument(
        "--glob",
        default="*.jp*g",
        help="glob pattern to match images (default: *.jp*g)",
    )
    parser.add_argument(
        "--fps",
        type=int,
        default=20,
        help="frames per second (default: 20)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="optional limit on number of frames (0 means all)",
    )
    parser.add_argument(
        "--skip",
        type=int,
        default=0,
        help="number of initial frames to skip after sorting (default: 0)",
    )
    parser.add_argument(
        "--keep-list",
        action="store_true",
        help="keep the generated concat list (for debugging)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    input_path = Path(args.path)

    if input_path.is_dir():
        dir_path = input_path
    elif input_path.exists():
        dir_path = input_path.parent
    else:
        print(f"error: path not found: {input_path}", file=sys.stderr)
        return 1

    files = sorted(
        p for p in dir_path.glob(args.glob) if p.is_file()
    )
    if not files:
        print(f"error: no images matched {args.glob!r} in {dir_path}", file=sys.stderr)
        return 1

    # Sort numerically by trailing integer if present (e.g., ...-123.jpg).
    num_re = re.compile(r"(\\d+)(?=\\.[^.]+$)")
    files.sort(
        key=lambda p: (
            int(num_re.search(p.name).group(1)) if num_re.search(p.name) else float("inf"),
            p.name,
        )
    )

    if args.skip:
        if args.skip >= len(files):
            print(f"error: skip ({args.skip}) is >= total frames ({len(files)})", file=sys.stderr)
            return 1
        files = files[args.skip :]

    if args.limit:
        files = files[: args.limit]

    stem0 = files[0].stem
    m = re.match(r"(.+)-\\d+$", stem0)
    base = m.group(1) if m else stem0

    out_path = args.output
    if not out_path:
        out_dir = Path("videos")
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / f"{base}.mp4"
    else:
        out_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"frames: {len(files)} from {dir_path}", flush=True)
    print(f"output: {out_path}", flush=True)

    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".txt", delete=False, newline="\n", encoding="utf-8"
    ) as tf:
        for f in files:
            tf.write(f"file '{f}'\n")
        list_path = Path(tf.name)

    cmd = [
        "ffmpeg",
        "-y",
        "-r",
        str(args.fps),
        "-f",
        "concat",
        "-safe",
        "0",
        "-protocol_whitelist",
        "file,pipe,crypto,data",
        "-i",
        str(list_path),
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        str(out_path),
    ]

    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if not args.keep_list:
        list_path.unlink(missing_ok=True)
    else:
        print(f"kept list file: {list_path}", flush=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout.decode())
        return result.returncode

    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
