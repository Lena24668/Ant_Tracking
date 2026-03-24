#!/bin/bash

cd Trex_August

echo "=========================================="
echo "Batch Render Started"
echo "=========================================="

for d in /Volumes/August2tb/2025-11-28/2025-11-28-{13,14,15,16,17,18,19,20,21,22}; do
  if find "$d" -maxdepth 1 -name "*.jpg" -print -quit | grep -q .; then
    echo ""
    echo "➜ Processing: $d"
    echo "  $(find "$d" -maxdepth 1 -name "*.jpg" -type f | wc -l) JPG files found"
    echo "  Running chunk_aupa.py..."
    python3 -u chunk_aupa.py "$d" \
      --glob "*.jpg" \
      --render \
      --out-dir /Volumes/August2tb/videos
    echo "  ✓ Completed: $d"
  else
    echo "  ✗ Skipped: $d (no JPGs)"
  fi
done

echo ""
echo "=========================================="
echo "Batch Render Complete!"
echo "=========================================="
ls -lah /Volumes/August2tb/videos/
