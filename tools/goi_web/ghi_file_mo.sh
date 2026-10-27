#!/bin/bash
# Q1 "Gói nhẹ bản web": cho bot chơi từng ngày dưới strace, ghi file nào được mở, để lap_goi.py chia gói.
# Chạy (Linux, cần strace và godot 4.3 trong PATH hoặc biến GODOT):
#   bash tools/goi_web/ghi_file_mo.sh /tmp/file_mo
#   python3 tools/goi_web/lap_goi.py /tmp/file_mo     # ghi lại tools/goi_web/goi.json
# Mất chừng 5 phút (chạy song song). Làm lại khi thêm đồ mới cho một ngày; đồ mới chưa có trong goi.json
# thì nằm trong index.pck như cũ, nên quên chạy cũng không hỏng game, chỉ chưa nhẹ hơn.
set -u
out=${1:?thư mục ghi log}
G=${GODOT:-godot}
mkdir -p "$out"
run() { n=$1; shift; timeout 900 strace -f -qq -e trace=openat -o "$out/$n.txt" "$G" --headless --path . "$@" > "$out/$n.log" 2>&1; }
for d in thu_hai thu_ba thu_tu thu_nam thu_sau thu_bay chu_nhat; do
  run "ngay.$d" -- --autotest --ngay=$d &
  run "ngay.$d.kho" -- --autotest --thu-thach --ngay=$d &
done
run ngay.thu_tu.ngap -- --autotest --ngay=thu_tu --ngap &
run ngay.thu_hai.en -- --autotest --lang=en &
# Cảnh chung: trang chủ, màn dạy chơi, hai phim
run chung.menu --quit-after 600 &
run chung.tap res://scenes/day_choi.tscn -- --autotest-tap &
run chung.mo_dau res://scenes/phim.tscn -- --phim=mo_dau --phim-test &
run chung.ket_tuan res://scenes/phim.tscn -- --phim=ket_tuan --phim-test &
# Bếp Cô Ba: ngày nào cũng vào bếp (Cả ca, Chỉ làm bếp) mà bot giao đơn của nhiều ngày đi thẳng ra phố,
# nên ghi riêng bếp từng ngày và tính là đồ chung. Thiếu dòng này đồ bếp từng rơi vào gói Thứ Ba,
# bản web vào bếp ngày khác là sập ("memory access out of bounds", 27/10/2026).
for d in thu_hai thu_ba thu_tu thu_nam thu_sau thu_bay chu_nhat; do
  run "chung.bep.$d" -- --autotest-bep --ngay=$d &
done
wait
bad=$(grep -L "OK" "$out"/ngay.*.log)
[ -n "$bad" ] && echo "Chưa thấy OK, xem lại: $bad"
true
