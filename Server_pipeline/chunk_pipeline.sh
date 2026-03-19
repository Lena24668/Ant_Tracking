#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  chunk_pipeline.sh <src_images_dir> <dst_videos_dir> [options]

Arguments:
  src_images_dir     Source folder with JPG/JPEG images
  dst_videos_dir     Destination folder for MP4 videos

Options:
  --workdir DIR      Local working directory (default: ./pipeline_work)
  --chunk-size N     Number of images per chunk (default: 6000)
  --fps N            FPS passed to chunk_aupa.py (default: 20)
  --glob PATTERN     Glob for chunk_aupa.py (default: *.jpg)
  --python PATH      Path to python executable (default: python3)
  --renderer PATH    Path to chunk_aupa.py
  --help             Show this help

Examples:
  Local test:
    ./chunk_pipeline.sh ~/Desktop/render_test/images ~/Desktop/render_test/videos \
      --workdir ~/Desktop/pipeline_work \
      --chunk-size 10 \
      --renderer "/full/path/to/chunk_aupa.py"

  Server run:
    ./chunk_pipeline.sh /Volumes/myshare/images /Volumes/myshare/videos \
      --workdir ~/Desktop/pipeline_work \
      --chunk-size 6000 \
      --renderer "/full/path/to/chunk_aupa.py"
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

WORKDIR="./pipeline_work"
CHUNK_SIZE=6000
FPS=20
GLOB="*.jpg"
PYTHON_BIN="python3"
RENDERER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workdir)
      WORKDIR=$2
      shift 2
      ;;
    --chunk-size)
      CHUNK_SIZE=$2
      shift 2
      ;;
    --fps)
      FPS=$2
      shift 2
      ;;
    --glob)
      GLOB=$2
      shift 2
      ;;
    --python)
      PYTHON_BIN=$2
      shift 2
      ;;
    --renderer)
      RENDERER=$2
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

if [[ -z "$RENDERER" ]]; then
  echo "error: please provide --renderer /path/to/chunk_aupa.py" >&2
  exit 1
fi

if [[ ! -f "$RENDERER" ]]; then
  echo "error: renderer not found: $RENDERER" >&2
  exit 1
fi

mkdir -p "$WORKDIR"
WORKDIR=$(cd "$WORKDIR" && pwd)

SLOT="$WORKDIR/current_chunk"
MANIFESTS="$WORKDIR/manifests"
DONE_DIR="$WORKDIR/done"
FAILED_DIR="$WORKDIR/failed"
LOGS="$WORKDIR/logs"
STATE="$WORKDIR/state"
UPLOAD_QUEUE="$WORKDIR/upload_queue"

mkdir -p "$SLOT" "$MANIFESTS" "$DONE_DIR" "$FAILED_DIR" "$LOGS" "$STATE" "$UPLOAD_QUEUE"

MASTER_LIST="$STATE/all_images_sorted.txt"
TOTAL_FILE="$STATE/total_count.txt"
NEXT_INDEX_FILE="$STATE/next_index.txt"
MAIN_LOG="$LOGS/pipeline.log"
FAILED_LIST="$STATE/failed_chunks.txt"

touch "$MAIN_LOG" "$FAILED_LIST"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg"
  echo "$msg" >> "$MAIN_LOG"
}

fail_chunk() {
  local chunk_name="$1"
  local reason="$2"
  local info_file="$3"

  log "FAILED: $chunk_name -> $reason"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $chunk_name | $reason" >> "$FAILED_LIST"

  mkdir -p "$FAILED_DIR/$chunk_name"

  if [[ -f "$info_file" ]]; then
    cp "$info_file" "$FAILED_DIR/$chunk_name/info.env"
  fi

  if [[ -d "$SLOT/images" ]]; then
    cp -R "$SLOT/images" "$FAILED_DIR/$chunk_name/" 2>/dev/null || true
  fi

  if [[ -d "$SLOT/out" ]]; then
    cp -R "$SLOT/out" "$FAILED_DIR/$chunk_name/" 2>/dev/null || true
  fi
}

build_master_list() {
  log "Building master image list ..."
  find "$SRC_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | sort > "$MASTER_LIST"
  wc -l < "$MASTER_LIST" | tr -d ' ' > "$TOTAL_FILE"

  if [[ ! -f "$NEXT_INDEX_FILE" ]]; then
    echo "1" > "$NEXT_INDEX_FILE"
  fi

  log "Master list created with $(cat "$TOTAL_FILE") files."
}

ensure_master_list() {
  if [[ ! -f "$MASTER_LIST" || ! -f "$TOTAL_FILE" ]]; then
    build_master_list
  else
    log "Using existing master list with $(cat "$TOTAL_FILE") files."
  fi
}

read_next_index() {
  if [[ ! -f "$NEXT_INDEX_FILE" ]]; then
    echo "1" > "$NEXT_INDEX_FILE"
  fi
  cat "$NEXT_INDEX_FILE"
}

write_next_index() {
  echo "$1" > "$NEXT_INDEX_FILE"
}

chunk_name_from_index() {
  local start="$1"
  printf "chunk_%06d" "$start"
}

chunk_done() {
  local chunk_name="$1"
  [[ -f "$DONE_DIR/${chunk_name}.done" ]]
}

prepare_chunk() {
  local start_index="$1"
  local total
  total=$(cat "$TOTAL_FILE")

  if (( start_index > total )); then
    return 1
  fi

  local end_index=$(( start_index + CHUNK_SIZE - 1 ))
  if (( end_index > total )); then
    end_index=$total
  fi

  local chunk_name
  chunk_name=$(chunk_name_from_index "$start_index")

  if chunk_done "$chunk_name"; then
    log "$chunk_name already done. Skipping."
    write_next_index $(( end_index + 1 ))
    return 2
  fi

  local manifest="$MANIFESTS/${chunk_name}.txt"
  local slot_images="$SLOT/images"
  local slot_meta="$SLOT/meta"

  rm -rf "$slot_images" "$slot_meta"
  mkdir -p "$slot_images" "$slot_meta"

  sed -n "${start_index},${end_index}p" "$MASTER_LIST" > "$manifest"

  if [[ ! -s "$manifest" ]]; then
    return 1
  fi

  log "Preparing $chunk_name with images $start_index to $end_index ..."

  while IFS= read -r img; do
    cp "$img" "$slot_images/"
  done < "$manifest"

  {
    echo "chunk_name=$chunk_name"
    echo "start_index=$start_index"
    echo "end_index=$end_index"
    echo "manifest=$manifest"
    echo "slot_images=$slot_images"
  } > "$slot_meta/info.env"

  write_next_index $(( end_index + 1 ))
  log "$chunk_name prepared successfully."
  return 0
}

render_chunk() {
  local info_file="$SLOT/meta/info.env"
  local slot_out="$SLOT/out"

  if [[ ! -f "$info_file" ]]; then
    log "No chunk metadata found. Nothing to render."
    return 1
  fi

  # shellcheck disable=SC1090
  source "$info_file"

  rm -rf "$slot_out"
  mkdir -p "$slot_out"

  log "Rendering $chunk_name ..."

  if ! "$PYTHON_BIN" "$RENDERER" "$slot_images" \
    --glob "$GLOB" \
    --render \
    --out-dir "$slot_out" \
    --fps "$FPS" \
    > "$LOGS/${chunk_name}_render.log" 2>&1; then
    fail_chunk "$chunk_name" "render command failed" "$info_file"
    return 1
  fi

  shopt -s nullglob
  local mp4s=( "$slot_out"/*.mp4 )
  shopt -u nullglob

  if (( ${#mp4s[@]} == 0 )); then
    fail_chunk "$chunk_name" "no mp4 produced" "$info_file"
    return 1
  fi

  local queue_dir="$UPLOAD_QUEUE/$chunk_name"
  rm -rf "$queue_dir"
  mkdir -p "$queue_dir"

  cp "$manifest" "$queue_dir/"
  cp "$info_file" "$queue_dir/info.env"
  cp "$slot_out"/*.mp4 "$queue_dir/"

  log "Rendering finished for $chunk_name."
  return 0
}

upload_chunk() {
  local info_file="$SLOT/meta/info.env"

  if [[ ! -f "$info_file" ]]; then
    log "No chunk metadata found. Nothing to upload."
    return 1
  fi

  # shellcheck disable=SC1090
  source "$info_file"

  local queue_dir="$UPLOAD_QUEUE/$chunk_name"

  if [[ ! -d "$queue_dir" ]]; then
    fail_chunk "$chunk_name" "upload queue missing" "$info_file"
    return 1
  fi

  shopt -s nullglob
  local mp4s=( "$queue_dir"/*.mp4 )
  shopt -u nullglob

  if (( ${#mp4s[@]} == 0 )); then
    fail_chunk "$chunk_name" "no mp4 in upload queue" "$info_file"
    return 1
  fi

  log "Uploading $chunk_name ..."

  if ! rsync -a "$queue_dir/" "$DST_DIR/" > "$LOGS/${chunk_name}_upload.log" 2>&1; then
    fail_chunk "$chunk_name" "upload failed" "$info_file"
    return 1
  fi

  touch "$DONE_DIR/${chunk_name}.done"
  log "Upload successful for $chunk_name. Marked as done."

  return 0
}

cleanup_after_success() {
  local info_file="$SLOT/meta/info.env"

  if [[ ! -f "$info_file" ]]; then
    return 0
  fi

  # shellcheck disable=SC1090
  source "$info_file"

  log "Cleaning local files for $chunk_name ..."

  rm -rf "$SLOT/images" "$SLOT/out" "$SLOT/meta"
  rm -rf "$UPLOAD_QUEUE/$chunk_name"

  mkdir -p "$SLOT/images" "$SLOT/out" "$SLOT/meta"

  log "Local cleanup done for $chunk_name."
}

main() {
  log "Pipeline started."
  log "Source: $SRC_DIR"
  log "Destination: $DST_DIR"
  log "Workdir: $WORKDIR"
  log "Chunk size: $CHUNK_SIZE"
  log "FPS: $FPS"
  log "Renderer: $RENDERER"

  ensure_master_list

  while true; do
    local start_idx
    start_idx=$(read_next_index)

    if prepare_chunk "$start_idx"; then
      :
    else
      rc=$?
      if [[ $rc -eq 1 ]]; then
        log "No more chunks left. Pipeline finished."
        break
      elif [[ $rc -eq 2 ]]; then
        continue
      else
        log "Unexpected error while preparing chunk."
        exit 1
      fi
    fi

    if ! render_chunk; then
      log "Pipeline stopped because rendering failed."
      exit 1
    fi

    if ! upload_chunk; then
      log "Pipeline stopped because upload failed."
      exit 1
    fi

    cleanup_after_success
  done

  log "Pipeline completed successfully."
}

main