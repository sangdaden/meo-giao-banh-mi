# Ngân sách hiệu năng (bản web 60 FPS)

Bản web chạy renderer **Compatibility** (WebGL 2) trên máy của người chơi, thường là laptop văn phòng có GPU tích hợp. Mục tiêu: 60 FPS ở 1280×720 khi đã có đủ model thật (nhà, đồ phố, người dân, Bơ 22 xương). Bản PC (Forward+) nhẹ hơn nhiều vì tự gộp lệnh vẽ, nên ngân sách đặt theo bản web.

## Đo thế nào

```
# giống bản web (cần màn hình; máy đám mây dùng xvfb-run)
xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  -s tools/do_hieu_nang.gd -- --chup=anh
# giống bản PC (cần Vulkan; máy đám mây: apt-get install mesa-vulkan-drivers)
xvfb-run -a godot --path . -s tools/do_hieu_nang.gd -- --chup=anh
```

`tools/do_hieu_nang.gd` mở màn phố, màn bếp và màn hình chính, đặt camera ở 8 góc phố (tầm camera sau lưng mèo), 2 góc bếp và màn hình chính, rồi in số lệnh vẽ, vật thể, tam giác, ms/khung. Thêm `--canh=pho|bep|menu` để đo một màn. Workflow **Hiệu năng bản web** (`.github/workflows/hieu-nang.yml`) chạy bài này ở mỗi PR, vượt ngân sách thì đỏ, ảnh các góc nằm ở mục Artifacts, bảng số nằm ở trang tóm tắt của lượt chạy.

Lưu ý: CI vẽ bằng CPU nên FPS ở đó không có ý nghĩa; số lệnh vẽ và tam giác thì giống máy thật. Compatibility của Godot 4.3 không báo lệnh vẽ của lượt bóng đổ, nên "vật thể" là con số cần canh nhất: mỗi vật thể đổ bóng tốn thêm khoảng một lệnh vẽ nữa.

## Ngân sách mỗi khung hình (bản web)

| Mục | Ngân sách | Main ngày 21/10 (khối tạm) |
|---|---|---|
| Lệnh vẽ (tổng) | ≤ 350 | 116–273 |
| Vật thể nhìn thấy | ≤ 450 | 116–273 |
| Tam giác (tổng, cả bóng) | ≤ 400 000 | 39 000–54 000 |
| index.pck | ≤ 60 MB (Sang nâng 21/10/2026) | 5,6 MB |

Góc nhìn từ trên cao (`tham_khao_tren_cao`) chỉ in số để tham khảo, không chấm.

## Ngân sách từng model (cho các luồng làm model)

| Loại | Tam giác | Vật liệu | Texture | Ghi chú |
|---|---|---|---|---|
| Nhà thường (nha_A–E) | ≤ 3 000 | ≤ 2 | màu đỉnh (vertex colour) hoặc ≤ 512 px | gộp qua `Blocks.merge_static` |
| Nhà đặc biệt (lò bánh, chung cư, cà phê, tiệm xe, nhà Bà Sáu, tạp hóa, sạp báo) | ≤ 8 000 | ≤ 3 | ≤ 1024 px | |
| Đồ phố (cột điện, thùng, ghế, chậu cây...) | ≤ 600 | 1 | màu đỉnh | đồ nhỏ hơn 1,5 m: tầm nhìn ≤ 45 m |
| Người dân (19 xương) | ≤ 4 000 | ≤ 2 | ≤ 512 px | tầm nhìn ≤ 40 m, không qua merge_static |
| Xe máy, người đi bộ | ≤ 1 500 | 1 | màu đỉnh | tầm nhìn ≤ 45 m |
| Bơ (22 xương) | ≤ 8 000 | ≤ 3 | ≤ 1024 px | luôn trong khung hình |
| Chó Mực | ≤ 6 000 | ≤ 2 | ≤ 1024 px | |

Quy tắc chung:
- Đồ đứng yên: để `Blocks.merge_static` gộp theo vật liệu, nên dùng chung vật liệu càng nhiều càng tốt (màu đỉnh thay vì mỗi màu một vật liệu).
- Đồ chuyển động, có xương: đặt `visibility_range_end` (và `visibility_range_end_margin` khoảng 5 m để mờ dần) cho từng MeshInstance3D.
- Mảng phẳng sát đất (vạch đường, vũng nước, decal): tắt đổ bóng (`cast_shadow = OFF`).
- Không thêm OmniLight/SpotLight ngoài phố: mỗi đèn trên WebGL vẽ lại các vật trong tầm của nó. Trong bếp có 3 đèn nhỏ là đủ.
- File .glb trong `assets/` nên nén (Draco không dùng được trong Godot; giảm tam giác và texture là cách chính).

## Tự hạ chất lượng trên web

`scripts/giu_fps.gd` chạy trong cả màn phố và màn bếp ở bản web: sau 3 giây đầu, cứ 2 giây đo FPS trung bình, thấp hơn 88% mục tiêu thì hạ một bậc: độ phân giải 3D 85% → 70% (thấp nhất 60%), rồi rút tầm bóng còn 14 m, cuối cùng tắt bóng. Không ghi vào cài đặt; vào lại màn là thử lại từ đầu. Thử trên máy tính: `-- --giu-fps`.

## Ánh sáng

`scripts/anh_sang.gd` dựng trời, nắng, ánh trời và sương cho từng màn theo phong cách D (preset `pho_sang` cho Thứ Hai, `bep_sang` cho bếp). Bản web và bản PC dùng cùng màu, khác cường độ vì Compatibility tính sáng trong không gian sRGB. Bóng đổ: PC 2 tầng tới 42 m; web 1 tầng tới 26 m.
