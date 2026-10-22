class_name City
## Khu phố bản khối thô, dựng theo bản đồ trong sổ phác thảo.
## Bản đồ 2D rộng 960 x 600 điểm ảnh, ở đây 1 điểm ảnh = 0,1 m nên khu phố 96 x 60 m.
## Gốc tọa độ ở giữa ngã tư: trục X sang phải (đông), trục Z xuống dưới bản đồ (nam).
## Nhà, cây, cột điện, xe đậu, thùng hàng là model Blender (PhoModels); va chạm vẫn là hộp như bản khối.

const SIZE := Vector2(96, 60)

## 6 khối nhà (x_min, z_min, x_max, z_max) tính bằng mét
const BLOCKS := [
	Rect2(-44, -26, 22, 21),  # 1: lò bánh Cô Ba
	Rect2(-14, -26, 26, 21),  # 2
	Rect2(20, -26, 24, 21),   # 3
	Rect2(-44, 5, 22, 21),    # 4: công viên
	Rect2(-14, 5, 26, 21),    # 5
	Rect2(20, 5, 24, 21),     # 6
]
const PARK_INDEX := 3

const BAKERY_POINT := Vector3(-33, 0, -5.8)
## Thùng hàng lẻ: đặt sát mép vỉa hè, sát hông nhà hoặc trong hẻm, không nằm trên lòng đường
const CRATES := [
	Vector3(-12.45, 0, -12), Vector3(10.45, 0, -8.5), Vector3(-12.45, 0, 12), Vector3(22.5, 0, 25.4), Vector3(-19.4, 0, 10.5),
	Vector3(6.2, 0, -5.6), Vector3(10.45, 0, 18.5),
]
## Chồng thùng bậc thang góc khối 1 cạnh cột điện, sát mái hiên: tập nhảy, có tem ở đỉnh, Thứ Bảy leo lên mái hiên
const CORNER_STAIR := Vector3(-24.3, 0, -5.6)

const ROAD := Color("#8F8B80")
const SIDEWALK := Color("#C9C3B3")
const LANE := Color("#FFF8EA")
const GRASS := Color("#7DB46C")


static func build(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026  # cố định để lần nào mở game khu phố cũng giống nhau
	_ground(parent)
	for i in BLOCKS.size():
		if i == PARK_INDEX:
			_park(parent, BLOCKS[i], rng)
		else:
			_block(parent, BLOCKS[i], rng, i)
	for c in CRATES:
		CityProps.crate(parent, c)
	# Chồng thùng bậc thang gần lò bánh: tập nhảy (bậc 0,8 m phía tây, chồng 1,6 m)
	CityProps.crate(parent, CORNER_STAIR + Vector3(-0.85, 0, 0))
	CityProps.crate(parent, CORNER_STAIR)
	CityProps.crate(parent, CORNER_STAIR + Vector3(0, 0.8, 0))
	_street_props(parent, rng)
	CityProps.build(parent)
	_bounds(parent)
	ChiTietPho.build(parent)  # chi tiết phố P4: dây điện, xe đậu, thùng rác, cống, đồ hẻm (scripts/chi_tiet_pho.gd)


static func _ground(parent: Node3D) -> void:
	# Mặt đường: một khối phẳng lớn có va chạm
	Blocks.solid_box(parent, Vector3(SIZE.x + 20, 1, SIZE.y + 20), Vector3(0, -0.5, 0), ROAD)
	# Vạch kẻ đường đứt khúc: trục ngang z=0, hai trục dọc x=-18 và x=16
	var x := -46.0
	while x < 46.0:
		if absf(x + 18) > 5 and absf(x - 16) > 5:
			Blocks.box(parent, Vector3(1.8, 0.02, 0.2), Vector3(x, 0.01, 0), LANE)
		x += 3.6
	for lane_x in [-18.0, 16.0]:
		var z := -28.0
		while z < 28.0:
			# Đoạn x = -18 phía nam đã thành hẻm 42, không kẻ vạch
			if absf(z) > 6 and not (lane_x < 0 and z > 8):
				Blocks.box(parent, Vector3(0.2, 0.02, 1.8), Vector3(lane_x, 0.01, z), LANE)
			z += 3.6
	# Vạch qua đường ở ngã tư
	for cx in [-18.0, 16.0]:
		for i in 6:
			Blocks.box(parent, Vector3(0.5, 0.02, 2.5), Vector3(cx - 3 + i * 1.2, 0.01, -6.5), LANE)
			Blocks.box(parent, Vector3(0.5, 0.02, 2.5), Vector3(cx - 3 + i * 1.2, 0.01, 6.5), LANE)


## Một khối nhà: vỉa hè bao quanh, hai dãy nhà ống quay lưng vào nhau, giữa có hẻm nhỏ.
## Chỗ nào có nhà đặc biệt (CityProps.SLOTS: lò bánh, cà phê, chung cư, tiệm xe) thì chừa ô đó cho CityProps dựng.
## Còn lại ghép nhà lấp (PhoModels.FILLERS) theo bề ngang thật; nhà cuối dãy giãn nhẹ cho kín.
static func _block(parent: Node3D, r: Rect2, rng: RandomNumberGenerator, block_index: int) -> void:
	var center := r.get_center()
	# Vỉa hè (chỉ để nhìn, không có bậc để mèo khỏi vấp)
	Blocks.box(parent, Vector3(r.size.x, 0.04, r.size.y), Vector3(center.x, 0.02, center.y), SIDEWALK)
	var inset := 2.0
	var alley := 2.4
	var depth := (r.size.y - inset * 2 - alley) / 2.0
	var rows := [
		{"z0": r.position.y + inset, "faces_south": false},
		{"z0": r.position.y + inset + depth + alley, "faces_south": true},
	]
	var names: Array = PhoModels.FILLERS.keys()
	for row_index in rows.size():
		var row: Dictionary = rows[row_index]
		var x := r.position.x + inset
		var x_end := r.end.x - inset
		var prev := ""
		while x < x_end - 0.5:
			var slot := CityProps.slot_at(block_index, row_index, x)
			if not slot.is_empty():
				CityProps.build_slot(parent, slot, row.z0, depth)
				x = slot.x1
				prev = ""
				continue
			# Nhà không được lấn sang ô đặc biệt kế bên
			var room := minf(x_end, CityProps.next_slot_x(block_index, row_index, x)) - x
			var model: String = names[rng.randi() % names.size()]
			if model == prev:  # hai nhà giống hệt đứng sát nhau trông lặp
				model = names[(names.find(model) + 1) % names.size()]
			var w: float = PhoModels.FILLERS[model]
			if room < w + 3.6:
				# Chỗ còn lại không đủ hai nhà: chọn ngẫu nhiên trong ba nhà có bề ngang gần nhất (khác nhà bên cạnh) rồi giãn cho kín
				var near: Array = names.filter(func(n): return n != prev)
				near.sort_custom(func(a, b): return absf(PhoModels.FILLERS[a] - room) < absf(PhoModels.FILLERS[b] - room))
				model = near[rng.randi() % 3]
				w = room
			_house(parent, model, x, w, row.z0, depth, row.faces_south, rng)
			prev = model
			x += w


## Nhà ống lấp chỗ trống: model + hộp va chạm thân nhà + mái hiên 2,9 m (có va chạm, nối liền nhà bên).
static func _house(parent: Node3D, model: String, x: float, w: float, z0: float, depth: float, faces_south: bool, rng: RandomNumberGenerator) -> void:
	var face_z: float = z0 + (depth if faces_south else 0.0)
	var out := 1.0 if faces_south else -1.0
	PhoModels.put_house(parent, model, x, w, PhoModels.FILLERS[model], face_z, faces_south)
	var h := PhoModels.aabb(model).end.y - 1.0  # thân nhà, chừa phần mái
	var body := Blocks.collider(parent, Vector3(w - 0.15, h, depth), Vector3(x + w / 2.0, h / 2.0, z0 + depth / 2.0))
	body.set_meta("model", model)  # SanThuong (Thứ Tư) đo mái thật theo mẫu nhà
	CityProps.awning(parent, w, Vector3(x + w / 2.0, 2.9, face_z + 0.5 * out), CityProps.AWNINGS[rng.randi() % CityProps.AWNINGS.size()], out)


static func _park(parent: Node3D, r: Rect2, rng: RandomNumberGenerator) -> void:
	var center := r.get_center()
	Blocks.box(parent, Vector3(r.size.x, 0.05, r.size.y), Vector3(center.x, 0.025, center.y), GRASS)
	# Lối đi chéo
	var path := Blocks.box(parent, Vector3(2.0, 0.06, r.size.length()), Vector3(center.x, 0.03, center.y), SIDEWALK)
	path.rotation.y = atan2(r.size.x, r.size.y)
	# Bàn cờ tướng trang trí (cách góc cờ Thứ Ba của thread "Góc cờ tướng" ở (-29, 8.5) hơn 4 m)
	var chess_sets := [Vector3(-35, 0, 14), Vector3(-32, 0, 19.5), Vector3(-38, 0, 24)]
	for c: Vector3 in chess_sets:
		if PlayMode.day != "chu_nhat":  # Chủ Nhật cất bàn cờ trang trí, nhường chỗ sân Hội mèo (G11)
			CityProps.chess_set(parent, c)
	# Cây vỉa hè (model cay_xanh): thân có va chạm
	for i in 9:
		var p := Vector3(rng.randf_range(r.position.x + 2, r.end.x - 2), 0, rng.randf_range(r.position.y + 2, r.end.y - 2))
		if Vector2(p.x - center.x, p.z - center.y).length() < 2.5:
			continue
		# Chừa chỗ góc cờ Thứ Ba (CityProps.CHESS_CORNER bên thread "Góc cờ tướng") và các bàn cờ trang trí
		if Vector2(p.x + 29.0, p.z - 8.5).length() < 3.5:
			continue
		var near_chess := false
		for c: Vector3 in chess_sets:
			near_chess = near_chess or Vector2(p.x - c.x, p.z - c.z).length() < 2.0
		if near_chess:
			continue
		var trunk := StaticBody3D.new()
		trunk.collision_layer = Blocks.LAYER_PROP
		trunk.position = p
		parent.add_child(trunk)
		PhoModels.put(trunk, "cay_xanh", Vector3.ZERO, rng.randf() * TAU)
		var shape := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 0.25
		cs.height = 2.6
		shape.shape = cs
		shape.position.y = 1.3
		trunk.add_child(shape)
	# Ghế đá để nhảy lên
	for b in [Vector3(-38, 0, 10), Vector3(-28, 0, 22), Vector3(-40, 0, 20)]:
		Blocks.solid_box(parent, Vector3(1.8, 0.45, 0.6), b + Vector3(0, 0.225, 0), Color("#B8B2A2"), Blocks.LAYER_PROP)
	# Bờ rào dọc hẻm 42 nay do CityProps.hem_42 dựng


static func _street_props(parent: Node3D, rng: RandomNumberGenerator) -> void:
	# Cột điện ở các góc ngã tư
	for p in [Vector3(-23, 0, -6), Vector3(-13, 0, 6), Vector3(11, 0, -6), Vector3(21, 0, 6), Vector3(3, 0, -6), Vector3(31, 0, 6)]:
		var pole := Blocks.collider(parent, Vector3(0.25, 7.0, 0.25), p + Vector3(0, 3.5, 0), Blocks.LAYER_PROP)
		pole.name = "CotDien"
		PhoModels.put(pole, "cot_dien", Vector3(0, -3.5, 0), PI / 2.0)  # xà ngang vuông góc đường lớn
	# Xe máy đậu trên vỉa hè: khối thấp nhảy lên được
	for i in 10:
		var r: Rect2 = BLOCKS[rng.randi() % BLOCKS.size()]
		if r == BLOCKS[PARK_INDEX]:
			continue
		var along := rng.randf_range(r.position.x + 3, r.end.x - 3)
		var z := r.end.y - 1.0 if rng.randf() < 0.5 else r.position.y + 1.0
		if CityProps.keep_clear(Vector2(along, z)):
			continue  # chỗ này đã có bàn quán cà phê hoặc đồ đặt sẵn
		var bike := Blocks.collider(parent, Vector3(0.5, 0.9, 1.6), Vector3(along, 0.45, z), Blocks.LAYER_PROP)
		bike.rotation.y = deg_to_rad(rng.randf_range(-15, 15))
		PhoModels.put(bike, CityProps.BIKES[i % CityProps.BIKES.size()], Vector3(0, -0.45, 0), PI / 2.0 if i % 3 else -PI / 2.0)


static func _bounds(parent: Node3D) -> void:
	var hx := SIZE.x / 2.0
	var hz := SIZE.y / 2.0
	Blocks.invisible_wall(parent, Vector3(1, 20, SIZE.y + 2), Vector3(-hx - 0.5, 10, 0))
	Blocks.invisible_wall(parent, Vector3(1, 20, SIZE.y + 2), Vector3(hx + 0.5, 10, 0))
	Blocks.invisible_wall(parent, Vector3(SIZE.x + 2, 20, 1), Vector3(0, 10, -hz - 0.5))
	Blocks.invisible_wall(parent, Vector3(SIZE.x + 2, 20, 1), Vector3(0, 10, hz + 0.5))
	# Tường thấp nhìn thấy được ở mép bản đồ
	Blocks.box(parent, Vector3(SIZE.x, 1.2, 0.3), Vector3(0, 0.6, -hz), Color("#B8B2A2"))
	Blocks.box(parent, Vector3(SIZE.x, 1.2, 0.3), Vector3(0, 0.6, hz), Color("#B8B2A2"))
	Blocks.box(parent, Vector3(0.3, 1.2, SIZE.y), Vector3(-hx, 0.6, 0), Color("#B8B2A2"))
	Blocks.box(parent, Vector3(0.3, 1.2, SIZE.y), Vector3(hx, 0.6, 0), Color("#B8B2A2"))
