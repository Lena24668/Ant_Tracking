# Trex helper scripts
test

This repo contains small utilities for chunking large image sequences, turning
chunks into MP4s, and running `trex` on the resulting videos.

## Requirements
- Python 3
- ffmpeg in `PATH` (for video rendering)
- trex in `PATH` (for tracking)

## Chunking image sequences (no ID in filename)
Example filenames:
`VTKA_AuPa_20251125-111437-684877_4.jpg`

The chunker expects the frame index at the end of the filename, right before
the extension, separated by `_` or `-`. It will:
- sort images naturally
- split on index gaps (with a warning)
- split once chunk size is reached (default 6000)

```bash
python3 chunk_aupa.py /data/2025-11-25/2025-11-25/2025-11-25-11 \
  --glob "*.jpg" \
  --output-json /data/2025-11-25/2025-11-25-11_chunks_aupa.json
```

Batch multiple folders:

```bash
for d in /data/2025-11-25/2025-11-25/2025-11-25-{11,12,13,14,15,16,17,18,19,20,21,22,23}; do
  python3 chunk_aupa.py "$d" \
    --glob "*.jpg" \
    --output-json "/data/2025-11-25/$(basename "$d")_chunks_aupa.json"
done
```

## Chunking image sequences (ID in filename)
If your filenames include a stable ID and you want chunking to reset whenever
the ID changes, pass `--id-regex` with a named `id` group.

Example (ID looks like `AuPa_<id>`):

```bash
python3 chunk_aupa.py /data/2025-12-04/2025-12-04/2025-12-04-11 \
  --glob "*.jpg" \
  --id-regex 'AuPa_(?P<id>[^_]+)' \
  --output-json /data/2025-12-04/2025-12-04-11_chunks_aupa.json
```

## Render videos from chunks
Use the chunker to render MP4s directly:

```bash
python3 chunk_aupa.py /data/2025-11-25/2025-11-25/2025-11-25-11 \
  --glob "*.jpg" \
  --render \
  --out-dir /data/2025-11-25/videos
```

Or batch render:

```bash
for d in /data/2025-11-25/2025-11-25/2025-11-25-{11,12,13,14,15,16,17,18,19,20,21,22,23}; do
  if ls "$d"/*.jpg >/dev/null 2>&1; then
    python3 chunk_aupa.py "$d" \
      --glob "*.jpg" \
      --render \
      --out-dir /data/2025-11-25/videos
  fi
done
```

## Render from an SMB (or slow) mount

If your images live on a network share (e.g. an SMB mount), rendering can be
slow if ffmpeg reads JPGs over the network. Use `smb_render.sh` to copy images
locally first, render locally, then upload the MP4s back to the share.

```bash
./smb_render.sh /Volumes/myshare/images /Volumes/myshare/videos
```

## Track videos with trex
`batch_trex.sh` runs `trex` on all MP4s in each subfolder and feeds them as a
bracketed list (the same format as the CLI).

Update these in `batch_trex.sh` before running:
- `src_root` to the folder with per-ID subfolders of MP4s
- `settings` to your `singletrial.settings`

Then run:

```bash
./batch_trex.sh
```

Optional: pass extra `trex` args via env var:

```bash
TREX_EXTRA_ARGS="--skip-conversion" ./batch_trex.sh
```
