#!/usr/bin/env bash
# Convert each chunk from chunks.data.chunked.json into an MP4 at 20 fps.
# Usage: ./chunk_ffmpeg.sh [chunk_json_path] [output_dir] [max_chunks]
# Defaults: chunk_json_path=chunks.data.chunked.json, output_dir=videos, max_chunks=all

set -euo pipefail

CHUNKS_JSON="${1:-chunks.data.chunked.json}"
OUT_DIR="${2:-videos}"
FPS="${FPS:-20}"
MAX_CHUNKS="${3:-0}" # 0 means all

mkdir -p "$OUT_DIR"

python - <<'PY' "$CHUNKS_JSON" "$OUT_DIR" "$FPS" "$MAX_CHUNKS"
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

chunks_path = Path(sys.argv[1])
out_dir = Path(sys.argv[2])
fps = sys.argv[3]
max_chunks = int(sys.argv[4])

if not chunks_path.exists():
    sys.stderr.write(f"missing chunks file: {chunks_path}\n")
    sys.exit(1)

chunks = json.loads(chunks_path.read_text())

NAME_RE = re.compile(r"^(?P<prefix>.*)_(?P<ts>\d{12})_(?P<group>\d+)-(?P<idx>\d+)\.[^.]+$")

for chunk_no, chunk in enumerate(chunks, 1):
    if max_chunks and chunk_no > max_chunks:
        break
    if not chunk:
        continue

    first, last = chunk[0], chunk[-1]
    m_first = NAME_RE.search(Path(first).name)
    m_last = NAME_RE.search(Path(last).name)
    if not (m_first and m_last):
        sys.stderr.write(f"skip chunk {chunk_no}: could not parse names\n")
        continue

    prefix = m_first.group("prefix")
    ts = m_first.group("ts")
    group = m_first.group("group")
    start_idx = int(m_first.group("idx"))
    end_idx = int(m_last.group("idx"))

    out_name = f"{prefix}_{ts}_{group}-{start_idx}-{end_idx}.mp4"
    out_path = out_dir / out_name

    # Build concat input listing all files in order
    concat_lines = []
    missing = []
    for p in chunk:
        path = Path(p)
        if not path.exists():
            missing.append(str(path))
        concat_lines.append(f"file '{path}'")

    if missing:
        sys.stderr.write(f"chunk {chunk_no}: {len(missing)} files missing; skipping\n")
        continue

    # Write concat list to a temporary file to avoid stdin/pipe protocol issues.
    tmp_list = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as tf:
            tmp_list = Path(tf.name)
            for line in concat_lines:
                tf.write(line + "\n")

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
            str(tmp_list),
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            str(out_path),
        ]

        print(f"[{chunk_no}/{len(chunks)}] {out_name}")
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if result.returncode != 0:
            sys.stderr.write(f"ffmpeg failed for chunk {chunk_no} -> {out_name}\n")
            sys.stderr.write(result.stdout.decode())
            sys.exit(result.returncode)
    finally:
        if tmp_list and tmp_list.exists():
            tmp_list.unlink(missing_ok=True)

print("done")
PY
