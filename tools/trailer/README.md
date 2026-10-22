# Trailer Mèo Giao Bánh Mì

Bộ công cụ quay trailer từ chính game (Godot 4.3, Movie Maker) rồi dựng bằng ffmpeg.
Kịch bản phân cảnh Sang duyệt: https://claude.ai/artifact/WV9wPmxntWPypp5JTyFrVP

## Các bước

```bash
# 1. Quay các cảnh ngoài phố, các ngày (đường chạy và camera trong SHOTS của quay_canh.gd)
GODOT=godot tools/trailer/quay.sh /tmp/trailer 1920x1080 mo_dau chay_ra_pho nga_tu tren_cao \
  giao_chu_tu giao_be_na giao_anh_hung muc thu_ba thu_tu thu_nam thu_sau thu_bay chu_nhat ket

# 2. Bếp (bot tự làm bánh) và tủ đồ
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 \
  --write-movie /tmp/trailer/bep.avi -s tools/trailer/chay_canh.gd -- res://scenes/kitchen.tscn 30 --an-hud --demo-bep
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 \
  --write-movie /tmp/trailer/tu_do.avi -s tools/trailer/quay_tu_do.gd

# 3. Nhạc (tự tổng hợp, CC0) rồi dựng
python3 tools/trailer/nhac_trailer.py /tmp/trailer/nhac.wav
python3 tools/trailer/dung_trailer.py /tmp/trailer /tmp/trailer/nhac.wav trailer.mp4
```

Movie Maker ghi đúng 30 hình mỗi giây dù máy render chậm, nên quay được trên máy đám mây không có GPU
(xvfb + Mesa). Lúc quay, nhạc nền game bị tắt, tiếng động game giữ lại và được trộn nhỏ dưới nhạc trailer.

Soát đường chạy nhanh không cần render: `godot --headless --path . --fixed-fps 30 -s tools/trailer/quay_canh.gd -- <cảnh> --debug`
in vị trí Bơ mỗi nửa giây và vật Bơ đang chạm.

## Khi bản đồ khu phố mới xong

Các cảnh dùng tọa độ khu phố hiện tại phải sửa tọa độ trong `SHOTS` rồi quay lại:
`chay_ra_pho`, `nga_tu`, `tren_cao`, `giao_*`, `muc`, `thu_ba`, `thu_tu`, `thu_sau`, `thu_bay`, `ket`.
Giữ nguyên: bếp, tủ đồ, `thu_nam` (cảnh chung cư riêng), `chu_nhat` (sân hội), `mo_dau` (trước lò bánh, nếu lò không dời).
Độ dài từng đoạn và chữ trên hình nằm ở `CUTS`, `CAPTIONS` trong `dung_trailer.py`, khớp mốc nhạc in ra từ `nhac_trailer.py`.
