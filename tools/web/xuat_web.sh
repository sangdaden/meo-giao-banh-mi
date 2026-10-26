#!/usr/bin/env bash
# Xuất bản web vào một thư mục, dùng trong .github/workflows/pages.yml (PH2).
#   tools/web/xuat_web.sh <thu_muc_ra> [ten_thu_muc_luu]
# ten_thu_muc_luu: đặt thì bản này lưu game riêng (user://) để không đụng file lưu của bản khác cùng tên miền
# (bản /moi-nhat/ dùng "meo-giao-banh-mi-moi-nhat", bản ổn định ở link gốc để trống như cũ).
# Cần biến GODOT (mặc định ~/godot/godot) và GITHUB_SHA (mã bản, ghi vào version.json cho web/update-check.js).
set -euo pipefail
out="$1"
luu="${2:-}"
godot="${GODOT:-$HOME/godot/godot}"
sha="${GITHUB_SHA:-$(git rev-parse HEAD)}"
if [ -n "$luu" ]; then
  cp project.godot /tmp/project.godot.goc
  trap 'cp /tmp/project.godot.goc project.godot' EXIT
  python3 - "$luu" <<'PY'
import sys
p = "project.godot"
s = open(p, encoding="utf-8").read()
them = 'config/use_custom_user_dir=true\nconfig/custom_user_dir_name="%s"\n' % sys.argv[1]
assert "[application]\n" in s
s = s.replace("[application]\n", "[application]\n\n" + them, 1)
open(p, "w", encoding="utf-8").write(s)
PY
fi
mkdir -p "$out"
"$godot" --headless --path . --export-release "Web" "$out/index.html"
test -f "$out/index.wasm"
# Gói nhẹ (Q1): đồ riêng từng ngày và tủ đồ tách ra goi/*.pck, tải khi vào ngày (scripts/goi_web.gd)
python3 tools/goi_web/tach_goi.py "$out/index.pck"
# Mã phiên bản để trang báo có bản mới (web/update-check.js)
sed "s/__BUILD_VERSION__/${sha}/" web/update-check.js > "$out/update-check.js"
echo "{\"version\": \"${sha}\"}" > "$out/version.json"
# Đếm lượt chơi bằng Umami (Vũ Trụ Mark K1)
cp web/do-luot.js "$out/do-luot.js"
