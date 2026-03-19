#!/usr/bin/env bash
set -euo pipefail

VIDEOS_DIR="/data/2025-11-25/videos"
SETTINGS="/home/flyvr01/src/Trex/singletrial.settings"
DATE="20251125"

# First, group MP4s into 30-minute folders.
while IFS= read -r f; do
  base=${f##*/}
  rest=${base#*${DATE}-}
  time_part=${rest%%-*}
  file_hour=${time_part:0:2}
  file_min=${time_part:2:2}

  if [[ -z "$file_hour" || -z "$file_min" ]]; then
    echo "skip unparseable filename: $base"
    continue
  fi

  if [[ "$file_min" -lt 30 ]]; then
    half="00"
  else
    half="30"
  fi

  group_dir="${VIDEOS_DIR}/${DATE}-${file_hour}${half}"
  mkdir -p "$group_dir"
  mv "$f" "$group_dir/"
done < <(find "$VIDEOS_DIR" -maxdepth 1 -type f -name "VTKA_AuPa_${DATE}-*.mp4" | sort)

# Then run trex per folder to avoid output collisions.
for group_dir in "$VIDEOS_DIR"/${DATE}-*; do
  [ -d "$group_dir" ] || continue
  mapfile -t clips < <(find "$group_dir" -maxdepth 1 -type f -name "*.mp4" | sort)
  [ ${#clips[@]} -gt 0 ] || { echo "skip empty folder $group_dir"; continue; }

  list="[\"${clips[0]}\""
  for ((i=1; i<${#clips[@]}; i++)); do
    list+=",\"${clips[$i]}\""
  done
  list+="]"

  echo "Running trex for folder $(basename "$group_dir") (${#clips[@]} clips)"
  (
    cd "$group_dir"
    trex -i "$list" -s "$SETTINGS" -auto_quit
  )
done
