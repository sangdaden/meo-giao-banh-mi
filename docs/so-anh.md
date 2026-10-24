# Ảnh so sánh mỗi PR (mã P2)

Workflow `.github/workflows/so-anh.yml` chạy ở mỗi PR (trừ PR chỉ sửa `.md`, `docs/`). Nó chụp cùng các góc
camera trên **main** và trên **PR**, rồi đánh dấu chỗ khác. Chỉ để báo: khác ảnh không bao giờ làm đỏ CI.

## Xem kết quả ở đâu

- **Bình luận trên PR** (khi có góc khác): bảng các góc khác, link tải trang so sánh. Lần chạy sau sửa lại
  chính bình luận đó, không đăng thêm.
- **Trang Summary** của lượt chạy "Ảnh so sánh": cùng bảng đó.
- **Artifact `so-anh`**: tải zip, giải nén, mở `index.html`. Mỗi góc có ba kiểu xem: kéo thanh để so main/PR,
  hai ảnh cạnh nhau, và ảnh "Vùng khác" (đỏ là điểm đổi, xanh là chỗ tự động nên bỏ qua). Ảnh PR có khung đỏ
  quanh vùng khác. Mặc định chỉ hiện góc khác; bấm "Tất cả" để xem hết.

## Chụp những góc nào

`tools/so_anh/chup.gd`, cho cả 7 ngày:

| Ảnh | Góc |
|---|---|
| `<ngày>_tren_cao` | nhìn khu phố từ trên cao |
| `<ngày>_lo_banh` | trước lò bánh Cô Ba |
| `<ngày>_don<N>` | chỗ khách của đơn N (`pos` trong `scripts/ngay/<ngày>.gd`); camera lùi ra phía thoáng nhất, cao 1,8 m |
| `bep_toan_canh` | màn bếp |
| `menu_chinh` | màn hình chính, có giao diện |

Các ảnh phố tắt giao diện 2D. Muốn thêm góc: thêm vào `SHOTS_DAY` / `SHOTS_BEP` trong `chup.gd`. CI chép
`tools/so_anh/` của PR sang bản main trước khi chụp, nên góc mới có ngay ở cả hai bên; vì vậy `chup.gd` chỉ được
dùng thứ đã có lâu trong game (`PlayMode.day`, `Days.orders`, các cảnh `.tscn`).

## Sao không báo nhầm vì người đi, mưa

Mỗi góc chụp 4 ảnh cách nhau vài khung (`<góc>.png`, `.sau1`, `.sau2`, `.sau3`). Chỗ nào tự đổi giữa các ảnh
đó (người qua đường, đuôi Bơ, mũi tên nhún, mưa, chim bay) là **chỗ động**, `so_sanh.py` không tính. Game chạy với
`--fixed-fps 30` nên hai lần chụp cùng một bản gần như trùng từng điểm ảnh. Điểm ảnh lệch dưới 24/255 bỏ qua;
vùng khác nhỏ hơn 40 điểm ảnh bỏ qua.

Hạn chế: thay đổi nằm đúng ở chỗ động (ví dụ đổi màu áo người đang đi) có thể không được báo.

## Chạy trên máy mình

```
# Chụp bản đang sửa (cần màn hình ảo trên máy đám mây)
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --fixed-fps 30 \
  -s tools/so_anh/chup.gd -- --chup=/tmp/anh_moi [--ngay=thu_hai,thu_ba] [--khong-bep] [--khong-menu]
# Chụp bản main ở một worktree khác vào /tmp/anh_goc (chép tools/so_anh/ sang trước), rồi:
python3 tools/so_anh/so_sanh.py --goc /tmp/anh_goc --moi /tmp/anh_moi --out /tmp/trang_so_anh
```

Để thư mục ảnh ngoài project (hoặc thêm `.gdignore`) để ảnh không bị đóng vào `index.pck`.
Cả 7 ngày mất khoảng 8–10 phút mỗi bên trên máy CI.
