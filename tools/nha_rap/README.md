# Bộ ráp nhà P2 cho game

Script Blender (bpy) xuất các mảnh nhà mà `scripts/nha_rap.gd` ghép thành nhà phố. Chép từ gói phác thảo P2
(`/mnt/project-files/thiet-ke-lai-khu-pho/p2-bo-rap-nha/scripts/`) và thêm chế độ cho game.

Cần: `pip install bpy` (Blender 5.x dạng module), Pillow, và thư mục phông chữ của gói P2
(đặt bằng `NHA_RAP_FONTS=...`, mặc định là đường dẫn trong gói P2; phông không đưa vào repo).

```sh
cd tools/nha_rap
# tầng trệt 8 kiểu × 4 bề ngang, KHÔNG có mái hiên và bảng hiệu (game dùng mái hiên CityProps.awning)
GAME=1 LITE=1 python3 run.py tret_game /tmp/manh
# 21 bảng hiệu × 4 bề ngang, mỗi bảng một .glb, chữ ghi ra chu.json thay vì làm khối
GAME=1 LITE=1 python3 run.py bang_game /tmp/bang
# gom chữ của mọi bảng vào một ảnh atlas
python3 atlas_chu.py /tmp/bang/chu.json ../../assets/textures/nha_rap/chu_bang.png /tmp/bang/chu_uv.json
```

Chép `tret_*.glb` vào `assets/models/nha_rap/manh/`, `bang_*.glb` vào `assets/models/nha_rap/bang/`, rồi cập nhật
`assets/models/nha_rap/nha_rap.json` (tam giác, khung, chỗ gắn đồ, mặt mái, chữ). Lầu và mái (`lau_*`, `mai_*`)
và 5 nhà mốc (`moc/`) lấy nguyên từ gói P2.

Mỗi mảnh có hai bề mặt: `pho_mausac` (màu đỉnh) và `son` (tường, game thay bằng một trong 10 màu sơn).
Gốc ở góc trái mặt tiền, mặt tiền tại z = 0 nhìn ra +z. Trệt cao 3,4 m, mỗi lầu 3,1 m, sâu 7,3 m.

## Nhà vành phố

`tools/vanh_pho/nha_vanh_p2.py` (cùng `vanh.py`, `vp_lib.py` của gói P1) dựng lại nhà vành phố theo kiểu P2:

```sh
python3 tools/vanh_pho/nha_vanh_p2.py /tmp/vanh
```

Chép `nha_vanh_p2.glb` và `nha_vanh.json` vào `assets/models/vanh/`. `scripts/vanh_pho.gd` bỏ nhà tạm cũ
(`VanhGan`, `VanhXa` trong `vanh_pho.glb`) và đặt chung cư Ngọc Lan lô C, biệt thự, mẫu giáo vào ô chừa sẵn.
