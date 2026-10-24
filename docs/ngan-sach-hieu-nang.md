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

Ngày 24/10 (Q3 "Gói nhẹ bản web"): bỏ 58 model không dùng (bản nhẹ/bản xa người dân không ai gọi, 10 đồ bếp/đồ giỗ/đồ phố thừa): index.pck 58,7 → 52,7 MiB. Cách tìm: cho bot chơi đủ 7 ngày (thường + thử thách) và chạy cả bộ test dưới `strace -e openat`, file nào không bao giờ được mở thì soát tay xem code có gọi theo tên ghép không (âm thanh, mèo, nhà ráp theo cỡ, cầu thang theo cỡ đều gọi theo tên ghép nên giữ).

Góc nhìn từ trên cao (`tham_khao_tren_cao`) chỉ in số để tham khảo, không chấm.

Ngày 23/10 (D2 "Giảm tam giác phố"): trước khi giảm, góc nặng nhất (ngã tư) là 390 000 tam giác, trong đó lượt bóng 151 000. Sau khi giảm: mọi góc 160 000–253 000, ngã tư ≈ 251 000 (lượt bóng ≈ 64 000), nên còn chỗ khoảng 150 000 tam giác cho người, xe, khối tạm thay thật (G1). Ở đâu mất bao nhiêu thì đo bằng `tools/dem_tam_giac.gd` (xem dưới).

## Ngân sách từng model (cho các luồng làm model)

| Loại | Tam giác | Vật liệu | Texture | Ghi chú |
|---|---|---|---|---|
| Nhà thường (nha_A–E) | ≤ 3 000 | ≤ 2 | màu đỉnh (vertex colour) hoặc ≤ 512 px | gộp qua `Blocks.merge_static` |
| Nhà đặc biệt (lò bánh, chung cư, cà phê, tiệm xe, nhà Bà Sáu, tạp hóa, sạp báo) | ≤ 8 000 | ≤ 3 | ≤ 1024 px | |
| Đồ phố (cột điện, thùng, ghế, chậu cây...) | ≤ 600 | 1 | màu đỉnh | đồ nhỏ hơn 1,5 m: tầm nhìn ≤ 45 m |
| Người dân (19 xương) | ≤ 4 000 | ≤ 2 | ≤ 512 px | tầm nhìn ≤ 40 m, không qua merge_static; nhập không tangent, không LOD, không shadow mesh (bớt dung lượng web) |
| Xe máy, người đi bộ | ≤ 1 500 | 1 | màu đỉnh | tầm nhìn ≤ 45 m |
| Bơ (22 xương) | ≤ 8 000 | ≤ 3 | ≤ 1024 px | luôn trong khung hình |
| Chó Mực | ≤ 6 000 | ≤ 2 | ≤ 1024 px | |

Quy tắc chung:
- Đồ đứng yên: để `Blocks.merge_static` gộp theo vật liệu, nên dùng chung vật liệu càng nhiều càng tốt (màu đỉnh thay vì mỗi màu một vật liệu).
- Đồ chuyển động, có xương: đặt `visibility_range_end` (và `visibility_range_end_margin` khoảng 5 m để mờ dần) cho từng MeshInstance3D.
- Mảng phẳng sát đất (vạch đường, vũng nước, decal): tắt đổ bóng (`cast_shadow = OFF`).
- Đồ thấp hơn 1 m (thùng, ghế, bàn nhựa, chậu) không đổ bóng: `Blocks.merge_static` tự tắt (`Blocks.SMALL_SHADOW`). Đồ nhỏ đặt riêng không qua gộp (ly, chén, tờ báo trong `deliveries.gd`) tắt bóng và tắt khi xa hơn 18 m: 36 ly cà phê quán Mây từng ngốn ~54 000 tam giác ở góc ngã tư.
- Lượt bóng không cần chi tiết vụn: model gắn meta `bong_tho` (một Mesh) thì `merge_static` vẽ mesh đó ở lượt bóng, bản đủ chỉ vẽ ở lượt chính. `Blocks.shadow_mesh` làm bản này bằng cách bỏ các cụm tam giác rời nhỏ hơn 0,6 m (khung cửa, chậu, máy lạnh, gờ, chữ nổi); tường, sàn, mái giữ nguyên chỗ nên bóng không lệch, gầm tiệm không lọt nắng. Nhà ráp (`NhaRap.shadow_mesh`) và model `PhoModels` từ 1 500 tam giác trở lên tự có.
- Nhà ở xa: model gắn meta `ban_xa` (một Mesh) được gộp theo ô 12 m và đổi sang bản xa khi tâm ô cách camera hơn 40 m (`Blocks.FAR_SWITCH`). Nhà ráp có `NhaRap.far_mesh`: hộp thân nhà, mặt tiền là các dải màu trung bình 0,5 m, mái là mảnh mái thật, chừng 300 tam giác thay 2 300.
- LOD tự sinh (`ImporterMesh.generate_lods`) gần như không giúp nhà và đồ phố: model là nhiều khối cạnh vuông, mỗi mặt tách pháp tuyến nên mọi cạnh là "biên" và không rút được gì; cho gộp pháp tuyến 180° thì rút được nhưng thủng tường. Muốn bớt tam giác thì làm bản xa / bản bóng như trên.
- Tầm nhìn (`visibility_range_*`) tính từ camera tới **tâm** hộp bao của mesh, không phải mép gần nhất: mesh gộp ô càng lớn thì càng phải để ý.
- Không thêm OmniLight/SpotLight ngoài phố: mỗi đèn trên WebGL vẽ lại các vật trong tầm của nó. Trong bếp có 3 đèn nhỏ là đủ.
- File .glb trong `assets/` nên nén (Draco không dùng được trong Godot; giảm tam giác và texture là cách chính).

## Đo xem cái gì ngốn tam giác

```
xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  -s tools/dem_tam_giac.gd -- --goc=pho_nga_tu [--tat]
```

`tools/dem_tam_giac.gd` đặt camera ở một góc của `do_hieu_nang.gd`, in số đo thật, rồi dựng lại khu phố chưa gộp và liệt kê từng model/nhóm: số tam giác trong khung nhìn và số tam giác đổ bóng trong tầm bóng web (ước theo LOD0). `--tat` tắt lần lượt từng nhóm lớn (ly cà phê, người, xe, vành phố, ô gộp có/không bóng...) và đo lại xem bớt được bao nhiêu.

## Tự hạ chất lượng trên web

`scripts/giu_fps.gd` chạy trong cả màn phố và màn bếp ở bản web: sau 3 giây đầu, cứ 2 giây đo FPS trung bình, thấp hơn 88% mục tiêu thì hạ một bậc: độ phân giải 3D 85% → 70% (thấp nhất 60%), rồi rút tầm bóng còn 14 m, cuối cùng tắt bóng. Không ghi vào cài đặt; vào lại màn là thử lại từ đầu. Thử trên máy tính: `-- --giu-fps`.

## Ánh sáng

`scripts/anh_sang.gd` dựng trời, nắng, ánh trời và sương cho từng màn theo phong cách D. Mỗi ngày chơi một buổi (`AnhSang.DAY_PRESET`): `pho_sang` Thứ Hai, `pho_cho` Thứ Ba, `pho_mua` Thứ Tư, `pho_trua` Thứ Năm, `pho_chieu` Thứ Sáu, `pho_hoang_hon` Thứ Bảy, `pho_toi` Chủ Nhật; `bep_sang` cho bếp. Thử một buổi: `-- --buoi=pho_mua`, thêm `--ngap` để thấy nước ngập.

Thêm theo buổi (đo ở 8 góc phố, bản web):
- Mưa (`scripts/thoi_tiet.gd`): hạt mưa và vòng bắn là hai GPUParticles3D đi theo camera (2 lệnh vẽ), vũng nước gộp một mesh, mặt ướt đổi vật liệu dùng chung một lần. Trời đục nên tắt bóng nắng: tổng lệnh vẽ còn khoảng một nửa buổi nắng.
- Chiều tà, hoàng hôn (`scripts/den_toi.gd`): đèn lồng cả phố là một MultiMesh, chỉ 4 đèn thật (web) không bóng dời theo mèo. Nắng thấp làm bóng rất dài nên web rút tầm bóng còn 14–18 m.
- Tối Chủ Nhật: không bóng nắng, đèn như trên. Bản web và bản PC dùng cùng màu, khác cường độ vì Compatibility tính sáng trong không gian sRGB. Bóng đổ: PC 2 tầng tới 42 m; web 1 tầng tới 26 m.
