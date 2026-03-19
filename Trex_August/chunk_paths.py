#!/usr/bin/env python3
"""Chunk a sorted list of file paths, breaking on missing indices."""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Iterable, List, Tuple

INDEX_RE = re.compile(r"^(.*?)(\d+)(\.[^.]+)?$")


def parse_path(line: str) -> Tuple[str, int]:
    """Return (base_without_index, numeric_index) for a path line."""
    line = line.strip()
    if not line:
        raise ValueError("empty line encountered")
    match = INDEX_RE.search(line)
    if not match:
        raise ValueError(f"could not parse numeric suffix in line: {line}")
    prefix, number, suffix = match.groups()
    base = f"{prefix}{suffix or ''}"
    return base, int(number)


def chunk_paths(
    lines: Iterable[str],
    chunk_size: int,
    ignore_base: bool = False,
) -> List[List[str]]:
    chunks: List[List[str]] = []
    current: List[str] = []
    prev_base: str | None = None
    prev_idx: int | None = None

    for raw in lines:
        line = raw.strip()
        if not line:
            continue

        base, idx = parse_path(line)
        gap = (
            prev_base is not None
            and (
                (not ignore_base and base != prev_base)
                or idx != (prev_idx or 0) + 1
            )
        )

        if gap or len(current) >= chunk_size:
            if current:
                chunks.append(current)
            current = []

        current.append(line)
        prev_base, prev_idx = base, idx

    if current:
        chunks.append(current)

    return chunks


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Chunk sorted paths on index gaps and size."
    )
    parser.add_argument("input", type=Path, help="path to the sorted list file")
    parser.add_argument(
        "--chunk-size",
        type=int,
        default=100,
        help="maximum chunk length before starting a new chunk (default: 100)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="where to write JSON array-of-arrays (default: stdout)",
    )
    parser.add_argument(
        "--ignore-base",
        action="store_true",
        help=(
            "treat all paths as a single series and only break on index gaps "
            "or chunk size (default: include base changes as gaps)"
        ),
    )
    args = parser.parse_args()

    try:
        lines = args.input.read_text(encoding="utf-8").splitlines()
        chunks = chunk_paths(lines, args.chunk_size, ignore_base=args.ignore_base)
    except Exception as exc:  # pragma: no cover - CLI convenience
        print(f"error: {exc}", file=sys.stderr)
        return 1

    out_text = json.dumps(chunks, indent=2)
    if args.output:
        args.output.write_text(out_text + "\n", encoding="utf-8")
    else:
        print(out_text)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
