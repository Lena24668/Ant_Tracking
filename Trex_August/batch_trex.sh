#!/usr/bin/env bash
set -euo pipefail
src_root="/data/2025-12-04/Videos_by_id"
settings="/home/flyvr01/src/Trex/singletrial.settings"
# Optional extra args (e.g., skip conversion) passed as a single string.
trex_extra_args=()
if [ -n "${TREX_EXTRA_ARGS:-}" ]; then
  # shellcheck disable=SC2206
  trex_extra_args=($TREX_EXTRA_ARGS)
fi

for dir in $(find "$src_root" -maxdepth 1 -mindepth 1 -type d | sort); do
  id_folder=$(basename "$dir")
  mapfile -t clips < <(find "$dir" -maxdepth 1 -type f -name "*.mp4" | sort)
  [ ${#clips[@]} -gt 0 ] || { echo "skip empty: $id_folder"; continue; }

  # Build bracketed list as you used on the CLI
  list="[\"${clips[0]}\""
  for ((i=1; i<${#clips[@]}; i++)); do
    list+=",\"${clips[$i]}\""
  done
  list+="]"

  echo "=== $id_folder ==="
  trex -i "$list" -s "$settings" "${trex_extra_args[@]}"
done
