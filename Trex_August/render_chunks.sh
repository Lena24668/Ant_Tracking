#!/usr/bin/env bash
# Render videos for path chunks defined in a JSON array-of-arrays.
# Usage: bash render_chunks.sh /path/to/chunks.json [output_dir]
# Optional env vars: FPS (10), CRF (18), PRESET (veryfast), START (0), LIMIT (0=all)

set -euo pipefail

CHUNKS_JSON=${1:?path to chunks.json}
OUT_DIR=${2:-./videos}
FPS=${FPS:-10}
CRF=${CRF:-18}
PRESET=${PRESET:-veryfast}
START=${START:-0}
LIMIT=${LIMIT:-0}

mkdir -p "$OUT_DIR"

# Keep temp files inside the repo/workdir to avoid sandbox permission issues.
TMP_BASE=${TMPDIR:-.}
LIST_DIR=$(mktemp -d "$TMP_BASE/render_chunks.XXXX")
trap 'rm -rf "$LIST_DIR"' EXIT

# Pre-split the JSON into concat lists; we load the JSON once in Python.
mapfile -t CHUNK_INDICES < <(python3 - "$CHUNKS_JSON" "$START" "$LIMIT" "$LIST_DIR" <<'PY'
import json, sys, pathlib

json_path = pathlib.Path(sys.argv[1])
start = int(sys.argv[2])
limit = int(sys.argv[3])
out_dir = pathlib.Path(sys.argv[4])

chunks = json.loads(json_path.read_text())
if start < 0 or start >= len(chunks):
    raise SystemExit(f"start index {start} out of range (0..{len(chunks)-1})")

end = len(chunks) if limit <= 0 else min(len(chunks), start + limit)
for idx in range(start, end):
    # ffmpeg concat demuxer expects lines like: file /abs/path
    list_path = out_dir / f"chunk_{idx}.txt"
    list_path.write_text("\n".join(f"file {p}" for p in chunks[idx]) + "\n")
    print(idx)
PY
)

if [[ ${#CHUNK_INDICES[@]} -eq 0 ]]; then
    echo "No chunks selected (maybe LIMIT too small?)" >&2
    exit 1
fi

for idx in "${CHUNK_INDICES[@]}"; do
    list_file="$LIST_DIR/chunk_${idx}.txt"
    first_frame=$(head -n1 "$list_file" | cut -d' ' -f2-)
    last_frame=$(tail -n1 "$list_file" | cut -d' ' -f2-)
    out_file="$OUT_DIR/chunk_${idx}_$(basename "$first_frame")__$(basename "$last_frame").mp4"

    ffmpeg -y -r "$FPS" -f concat -safe 0 -i "$list_file" \
      -c:v libx264 -preset "$PRESET" -crf "$CRF" -pix_fmt yuv420p "$out_file"

    echo "Wrote $out_file"
done
