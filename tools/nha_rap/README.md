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

## Bảng hiệu vòng 3

Sang duyệt 27/10 (trang https://claude.ai/artifact/J8eJA7aPV4B5hBVsiCxhGq): bảng cao 1,2 m, mỗi quán một cỡ chữ,
hình nghề nổi 3D, bảng dọc chìa ra phố, và 4 bảng riêng cho quán trong truyện (lò bánh Cô Ba, cà phê Mây, tiệm xe
Anh Hùng, tạp hóa Cô Hai). Hình bảng ở `bang_v3.py` (bảng `GEN`, cỡ chữ `CO`, các hàm quán truyện), chạy bằng `run_bang_v3.py`.

```sh
cd tools/nha_rap
# 21 bảng x 4 bề ngang + 4 bảng quán truyện, mỗi bảng một .glb (khung, hình, bảng dọc) và chu.json (4 góc mỗi dòng chữ)
LITE=1 python3 run_bang_v3.py game /tmp/bang3
python3 atlas_chu_v3.py /tmp/bang3/chu.json ../../assets/textures/nha_rap/chu_bang.png /tmp/bang3/chu_uv.json
cp /tmp/bang3/bang_*.glb ../../assets/models/nha_rap/bang/
python3 ghep_bang_v3.py /tmp/bang3 /tmp/bang3/chu_uv.json ../../assets/models/nha_rap/nha_rap.json
```

Bảng quán thường do `NhaRap._sign` gắn; bảng quán truyện do `NhaRap.put_sign` gắn trong `scripts/city_props.gd`
và `scripts/shop_tap_hoa.gd`. Ảnh soát trong game: `tools/chup_bang_hieu.gd`.

## Nhà vành phố

`tools/vanh_pho/nha_vanh_p2.py` (cùng `vanh.py`, `vp_lib.py` của gói P1) dựng lại nhà vành phố theo kiểu P2:

```sh
python3 tools/vanh_pho/nha_vanh_p2.py /tmp/vanh
```

Chép `nha_vanh_p2.glb` và `nha_vanh.json` vào `assets/models/vanh/`. `scripts/vanh_pho.gd` bỏ nhà tạm cũ
(`VanhGan`, `VanhXa` trong `vanh_pho.glb`) và đặt chung cư Ngọc Lan lô C, biệt thự, mẫu giáo vào ô chừa sẵn.
