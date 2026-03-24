#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VIDEOS_DIR="/Volumes/PUMBAAAUPA/Videosout"
DEFAULT_SETTINGS="/Users/lenawunderlich/Library/Mobile Documents/com~apple~CloudDocs/Studium Shit/Master/Hiwi/Ant_Tracking/Trex_pipeline.settings"
DEFAULT_DATE="20251125"

DATE="${1:-$DEFAULT_DATE}"
TARGET_HOUR="${2:-}"
VIDEOS_DIR="${3:-$DEFAULT_VIDEOS_DIR}"
SETTINGS="${4:-$DEFAULT_SETTINGS}"

if [[ -n "$TARGET_HOUR" && ! "$TARGET_HOUR" =~ ^([01][0-9]|2[0-3])$ ]]; then
  echo "ERROR: hour must be 00..23, got '$TARGET_HOUR'" >&2
  exit 1
fi

if [[ -n "$TARGET_HOUR" ]]; then
  echo "Process date=$DATE only hour=$TARGET_HOUR"
else
  echo "Process date=$DATE all hours"
fi

echo "VIDEOS_DIR=$VIDEOS_DIR"
echo "SETTINGS=$SETTINGS"

# First, group MP4s into hourly folders.
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

  if [[ -n "$TARGET_HOUR" && "$file_hour" != "$TARGET_HOUR" ]]; then
    continue
  fi

  # Group into hourly directories (e.g., 10:00-10:59 -> DATE-1000)
  group_dir="${VIDEOS_DIR}/${DATE}-${file_hour}00"
  mkdir -p "$group_dir"
  mv "$f" "$group_dir/"
done < <(find "$VIDEOS_DIR" -maxdepth 1 -type f -name "VTKA_AuPa_${DATE}-*.mp4" | sort)

# Then run trex per folder to avoid output collisions.
for group_dir in "$VIDEOS_DIR"/${DATE}-*; do
  [ -d "$group_dir" ] || continue

  if [[ -n "$TARGET_HOUR" ]]; then
    group_name=$(basename "$group_dir")
    if [[ "$group_name" != "${DATE}-${TARGET_HOUR}00" ]]; then
      continue
    fi
  fi

  clips=()
  while IFS= read -r clip; do
    clips+=("$clip")
  done < <(find "$group_dir" -maxdepth 1 -type f -name "*.mp4" | sort)
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
