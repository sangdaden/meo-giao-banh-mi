# Clip dọc 9:16 cho devlog (PH4)

Quay 5 clip ngắn từ game thật để Sang chọn đăng TikTok / Reels / Shorts qua Metricool. **Không đăng gì tự động.**

| Clip | Cảnh | Độ dài |
|---|---|---|
| `leo` | Thứ Năm, leo ống nước chung cư | ~3,7 s |
| `giao` | Thứ Hai, giao bánh Chú Tư (khoảnh khắc giao bánh) | ~6 s |
| `mua_mai` | Thứ Tư, mưa ngập, chạy dọc dãy mái hiên | ~6 s |
| `muc` | Thứ Hai, rón rén qua hẻm 42, Chó Mực thức | ~5,7 s |
| `chay` | Thứ Hai, chạy và nhảy dọc vỉa hè | ~6,6 s |

## Chạy

```bash
# Quay + dựng cả 5 clip (cần xvfb-run, ffmpeg, Pillow, Godot 4.3; ~8 phút trên máy 4 nhân)
GODOT=godot tools/clip_doc/lam_clip.sh /tmp/clip-doc            # 1080x1920
GODOT=godot tools/clip_doc/lam_clip.sh /tmp/clip-doc 720x1280 leo muc   # nhanh hơn, vài clip

# Chỉ dựng lại mp4 từ .avi đã quay (đổi chữ, nhạc)
python3 tools/clip_doc/dung_clip.py /tmp/clip-doc/avi /tmp/clip-doc
```

Ra `<clip>.mp4` (1080x1920, H.264, AAC, -16 LUFS), ảnh bìa `<clip>.jpg` và `index.html` để xem cả bộ.
Thư mục ra để **ngoài project** (clip không được vào `index.pck`).

CI: workflow `clip-doc.yml` chạy mỗi lần `main` đổi (và nút Run workflow, chọn được clip), để clip ở artifact `clip-doc` 30 ngày.

## Sửa clip

- Đường chạy, camera, độ dài: `CLIPS` trong `quay_clip_doc.gd` (cùng khóa với `SHOTS` của `tools/trailer/quay_canh.gd`,
  dùng chung các hàm chuẩn bị `_cam_banh`, `_mua_ngap`, `_muc_thuc`...). Soát đường chạy không cần render:
  `godot --headless --path . --fixed-fps 30 -s tools/clip_doc/quay_clip_doc.gd -- <clip> --debug`.
- Chữ trên hình và nhạc nền: `CLIPS` trong `dung_clip.py`. Chữ tự thu nhỏ cho vừa khung.
- Khung dọc dùng góc nhìn dọc của camera (`fov` là góc dọc), nên đặt camera gần Bơ hơn cảnh trailer.
- Bản đồ đổi thì sửa tọa độ trong `CLIPS` như với trailer (`tools/trailer/README.md`).
