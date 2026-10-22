#!/usr/bin/env bash
# Quay các cảnh trailer ra <thư_mục>/<cảnh>.avi bằng Movie Maker (cần xvfb-run và Godot 4.3).
#   tools/trailer/quay.sh <thư_mục> <rộng>x<cao> cảnh1 cảnh2 ...
# Biến GODOT trỏ tới file chạy Godot (mặc định "godot").
set -e
out=$1; res=$2; shift 2
mkdir -p "$out"
for s in "$@"; do
  xvfb-run -a -s "-screen 0 1920x1080x24" "${GODOT:-godot}" --path . --rendering-driver opengl3 --resolution "$res" \
    --fixed-fps 30 --write-movie "$out/$s.avi" -s tools/trailer/quay_canh.gd -- "$s" > "$out/$s.log" 2>&1 || echo "lỗi cảnh $s"
  grep -E "SCRIPT ERROR|Parse Error" -A2 "$out/$s.log" | head -6 || true
done
