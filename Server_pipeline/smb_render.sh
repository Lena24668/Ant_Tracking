#!/usr/bin/env bash
# Test run: copy only 10 JPGs from SMB/server, render locally, upload MP4 back.
# Does NOT delete anything.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: smb_render_test.sh <src_images_dir> <dst_videos_dir> [--tmpdir DIR] [--fps N]

Example:
  ./smb_render_test.sh /Volumes/myshare/images /Volumes/myshare/videos
USAGE
}

if [[ ${1:-} == "--help" || ${1:-} == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

SRC_DIR=$1
DST_DIR=$2
shift 2

TMPDIR=""
FPS=20
cleanup_tmpdir=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --tmpdir)
      TMPDIR=$2
      shift 2
      ;;
    --fps)
      FPS=$2
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "$SRC_DIR" ]]; then
  echo "error: source directory does not exist: $SRC_DIR" >&2
  exit 1
fi

mkdir -p "$DST_DIR"

if [[ -z "$TMPDIR" ]]; then
  TMPDIR=$(mktemp -d)
  cleanup_tmpdir=true
else
  mkdir -p "$TMPDIR"
fi

cleanup() {
  if [[ "$cleanup_tmpdir" == true && -n "${TMPDIR:-}" ]]; then
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT

IMG_TMP="$TMPDIR/images"
VID_TMP="$TMPDIR/videos"
mkdir -p "$IMG_TMP" "$VID_TMP"

echo "[1/4] Copying only 10 JPGs locally..."

find "$SRC_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | sort | head -n 10 | while IFS= read -r img; do
  cp "$img" "$IMG_TMP/"
done

echo "Copied files:"
ls -1 "$IMG_TMP"

echo "[2/4] Rendering MP4 locally..."
python3 "/Users/lenawunderlich/Library/Mobile Documents/com~apple~CloudDocs/Studium Shit/Master/Hiwi/Ants/Trex_August/chunk_aupa.py" "$IMG_TMP" \
  --glob "*.jpg" \
  --render \
  --out-dir "$VID_TMP" \
  --fps "$FPS"

echo "[3/4] Uploading MP4(s) back to server..."
rsync -a "$VID_TMP/" "$DST_DIR/"

echo "[4/4] Done."
echo "Local buffered images: $IMG_TMP"
echo "Local rendered videos: $VID_TMP"