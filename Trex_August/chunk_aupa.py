#!/usr/bin/env python3
"""Chunk AuPa image sequences and optionally render them to MP4."""

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Iterable, List, NamedTuple


class Chunk(NamedTuple):
    id_value: str | None
    start_idx: int | None
    end_idx: int | None
    files: List[Path]


FRAME_RE = re.compile(r"[_-](?P<idx>\d+)(?=\.[^.]+$)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", help="directory containing the images")
    parser.add_argument(
        "--glob",
        default="*.jp*g",
        help="glob for image files (default: *.jp*g)",
    )
    parser.add_argument(
        "--chunk-size",
        type=int,
        default=6000,
        help="max frames per chunk before starting a new one (default: 6000)",
    )
    parser.add_argument(
        "--id-regex",
        default=None,
        help="optional regex with a named 'id' group for grouping (default: none)",
    )
    parser.add_argument(
        "--output-json",
        type=Path,
        help="optional path to write chunk metadata as JSON",
    )
    parser.add_argument(
        "--render",
        action="store_true",
        help="run ffmpeg for each chunk",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("videos"),
        help="where to place rendered videos (default: videos/)",
    )
    parser.add_argument(
        "--fps",
        type=int,
        default=20,
        help="frames per second for ffmpeg (default: 20)",
    )
    return parser.parse_args()


def natural_key(path: Path) -> list:
    """Return a key that sorts numbers numerically inside a string."""
    parts = re.split(r"(\d+)", path.name)
    return [int(p) if p.isdigit() else p for p in parts]


def iter_files(root: Path, pattern: str) -> Iterable[Path]:
    for path in sorted(root.glob(pattern), key=natural_key):
        if path.is_file():
            yield path


def extract_id(name: str, id_re: re.Pattern | None) -> str | None:
    if not id_re:
        return None
    m = id_re.search(name)
    return m.group("id") if m else None


def extract_idx(name: str) -> int | None:
    m = FRAME_RE.search(name)
    return int(m.group("idx")) if m else None


def chunk_files(
    files: Iterable[Path],
    chunk_size: int,
    id_re: re.Pattern | None,
) -> list[Chunk]:
    chunks: list[Chunk] = []
    current: list[Path] = []
    current_id: str | None = None
    last_idx: int | None = None

    for path in files:
        file_id = extract_id(path.name, id_re)
        file_idx = extract_idx(path.name)
        start_new_chunk = False
        gap_break = False

        if current:
            if len(current) >= chunk_size:
                start_new_chunk = True
            elif file_id != current_id:
                start_new_chunk = True
            elif (
                last_idx is not None
                and file_idx is not None
                and file_idx != last_idx + 1
            ):
                start_new_chunk = True
                gap_break = True

        if start_new_chunk:
            if gap_break:
                print(
                    f"warning: index gap between {last_idx} and {file_idx} at {path.name}; "
                    "starting new chunk",
                    file=sys.stderr,
                )
            chunks.append(_finalize_chunk(current, current_id))
            current = []
            current_id = None
            last_idx = None

        current.append(path)
        current_id = file_id
        last_idx = file_idx

    if current:
        chunks.append(_finalize_chunk(current, current_id))

    return chunks


def _finalize_chunk(files: list[Path], id_value: str | None) -> Chunk:
    start_idx = extract_idx(files[0].name)
    end_idx = extract_idx(files[-1].name)
    return Chunk(id_value=id_value, start_idx=start_idx, end_idx=end_idx, files=list(files))


def out_name(first: Path, start_idx: int | None, end_idx: int | None) -> str:
    m = re.match(r"(?P<prefix>.+)[_-](?P<frame>\d+)(?P<ext>\.[^.]+)$", first.name)
    if m:
        prefix, ext = m.group("prefix"), m.group("ext")
        if start_idx is not None and end_idx is not None:
            return f"{prefix}-{start_idx}-{end_idx}.mp4"
        return f"{prefix}.mp4"
    stem = first.stem
    if start_idx is not None and end_idx is not None:
        return f"{stem}-{start_idx}-{end_idx}.mp4"
    return f"{stem}.mp4"


def render_chunk(chunk: Chunk, out_dir: Path, fps: int, chunk_no: int, total: int) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    name = out_name(chunk.files[0], chunk.start_idx, chunk.end_idx)
    if chunk.id_value:
        name = name.replace(".mp4", f"_{chunk.id_value}.mp4")
    out_path = out_dir / name

    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False, newline="\n") as tf:
        for f in chunk.files:
            tf.write(f"file '{f}'\n")
        list_path = Path(tf.name)

    cmd = [
        "ffmpeg",
        "-y",
        "-r",
        str(fps),
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

    print(f"[{chunk_no}/{total}] {out_path}")
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    list_path.unlink(missing_ok=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout.decode())
        raise RuntimeError(f"ffmpeg failed for {out_path}")


def main() -> int:
    args = parse_args()
    root = Path(args.root)
    if not root.is_dir():
        print(f"error: not a directory: {root}", file=sys.stderr)
        return 1

    files = list(iter_files(root, args.glob))
    if not files:
        print(f"error: no files match {args.glob!r} in {root}", file=sys.stderr)
        return 1

    id_re = re.compile(args.id_regex) if args.id_regex else None
    chunks = chunk_files(files, args.chunk_size, id_re)
    print(f"found {len(files)} files -> {len(chunks)} chunks")

    if args.output_json:
        try:
            import json
        except ImportError as exc:  # pragma: no cover - stdlib availability
            print(f"error: json module missing: {exc}", file=sys.stderr)
            return 1
        payload = [
            {
                "id": c.id_value,
                "start_idx": c.start_idx,
                "end_idx": c.end_idx,
                "files": [str(p) for p in c.files],
            }
            for c in chunks
        ]
        args.output_json.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {args.output_json}")

    if args.render:
        for i, chunk in enumerate(chunks, 1):
            try:
                render_chunk(chunk, args.out_dir, args.fps, i, len(chunks))
            except Exception as exc:  # pragma: no cover - CLI convenience
                print(f"error rendering chunk {i}: {exc}", file=sys.stderr)
                return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
