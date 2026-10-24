#!/usr/bin/env bash
# Quay rồi dựng các clip dọc 9:16 cho devlog (PH4). Cần xvfb-run, ffmpeg và Godot 4.3 (biến GODOT, mặc định "godot").
#   tools/clip_doc/lam_clip.sh <thư_mục_ra> [rộng]x[cao] [clip ...]
# Mặc định 1080x1920 và cả 5 clip (leo giao mua_mai muc chay). Thư mục ra phải nằm ngoài project
# (hoặc có .gdignore) để clip không bị đóng vào index.pck.
set -e
out=${1:?thiếu thư mục ra}; res=${2:-1080x1920}; shift $(( $# >= 2 ? 2 : 1 ))
clips=("$@"); [ ${#clips[@]} -eq 0 ] && clips=(leo giao mua_mai muc chay)
mkdir -p "$out/avi"
for c in "${clips[@]}"; do
  timeout 600 xvfb-run -a -s "-screen 0 1920x1920x24" "${GODOT:-godot}" --path . --rendering-driver opengl3 \
    --resolution "$res" --fixed-fps 30 --write-movie "$out/avi/$c.avi" \
    -s tools/clip_doc/quay_clip_doc.gd -- "$c" > "$out/avi/$c.log" 2>&1 || echo "lỗi quay clip $c"
  grep -E "SCRIPT ERROR|Parse Error" -A2 "$out/avi/$c.log" | head -6 || true
done
python3 tools/clip_doc/dung_clip.py "$out/avi" "$out" "${clips[@]}"
