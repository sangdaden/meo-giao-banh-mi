class_name City
## Khu phố bản khối thô, dựng theo bản đồ trong sổ phác thảo.
## Bản đồ 2D rộng 960 x 600 điểm ảnh, ở đây 1 điểm ảnh = 0,1 m nên khu phố 96 x 60 m.
## Gốc tọa độ ở giữa ngã tư: trục X sang phải (đông), trục Z xuống dưới bản đồ (nam).
## Tuần 3 sẽ thay các khối hộp bằng bộ mảnh modular từ Blender.

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
## Thùng hàng để nhảy qua (theo bản đồ) và vài chồng thêm cho vui
const CRATES := [
	Vector3(-18, 0, -12), Vector3(16, 0, 0.5), Vector3(-7, 0, 0.8), Vector3(26, 0, 27.5), Vector3(-18, 0, 12),
	Vector3(-25, 0, -2), Vector3(5, 0, -3.5), Vector3(14, 0, 18),
]

const ROAD := Color("#8F8B80")
const SIDEWALK := Color("#C9C3B3")
const LANE := Color("#FFF8EA")
const FACADES := [Color("#E8C98A"), Color("#7FB7A4"), Color("#E39C7A"), Color("#BFD8D2"), Color("#F2E3B8"), Color("#D7A9C4"), Color("#A9C7E8")]
const SHUTTER := Color("#2E7C80")
const GRASS := Color("#7DB46C")
const CRATE := Color("#9B6A3A")


static func build(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026  # cố định để lần nào mở game khu phố cũng giống nhau
	_ground(parent)
	for i in BLOCKS.size():
		if i == PARK_INDEX:
			_park(parent, BLOCKS[i], rng)
		else:
			_block(parent, BLOCKS[i], rng, i == 0)
	for c in CRATES:
		Blocks.solid_box(parent, Vector3(0.8, 0.8, 0.8), c + Vector3(0, 0.4, 0), CRATE)
	# Chồng thùng bậc thang gần lò bánh: tập nhảy
	Blocks.solid_box(parent, Vector3(0.8, 0.8, 0.8), Vector3(-25.8, 0.4, -2), CRATE)
	Blocks.solid_box(parent, Vector3(0.8, 0.8, 0.8), Vector3(-25.8, 1.2, -2), CRATE)
	_street_props(parent, rng)
	_bounds(parent)


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
			if absf(z) > 6:
				Blocks.box(parent, Vector3(0.2, 0.02, 1.8), Vector3(lane_x, 0.01, z), LANE)
			z += 3.6
	# Vạch qua đường ở ngã tư
	for cx in [-18.0, 16.0]:
		for i in 6:
			Blocks.box(parent, Vector3(0.5, 0.02, 2.5), Vector3(cx - 3 + i * 1.2, 0.01, -6.5), LANE)
			Blocks.box(parent, Vector3(0.5, 0.02, 2.5), Vector3(cx - 3 + i * 1.2, 0.01, 6.5), LANE)


## Một khối nhà: vỉa hè bao quanh, hai dãy nhà ống quay lưng vào nhau, giữa có hẻm nhỏ.
static func _block(parent: Node3D, r: Rect2, rng: RandomNumberGenerator, is_bakery_block: bool) -> void:
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
	for row in rows:
		var x := r.position.x + inset
		var x_end := r.end.x - inset
		while x < x_end - 0.5:
			var w := minf(rng.randf_range(3.6, 6.0), x_end - x)
			var h := rng.randf_range(5.0, 13.0)
			var col: Color = FACADES[rng.randi() % FACADES.size()]
			var pos := Vector3(x + w / 2.0, h / 2.0, row.z0 + depth / 2.0)
			var is_bakery: bool = is_bakery_block and row.faces_south and x + w > -36.0 and x < -30.0
			if is_bakery:
				col = Color("#F2E3B8")
			Blocks.solid_box(parent, Vector3(w - 0.15, h, depth), pos, col)
			# Cửa cuốn và mái hiên phía mặt đường
			var face_z: float = row.z0 + (depth if row.faces_south else 0.0)
			var out := 1.0 if row.faces_south else -1.0
			Blocks.box(parent, Vector3(w - 0.9, 2.4, 0.06), Vector3(pos.x, 1.2, face_z + 0.04 * out), SHUTTER.darkened(0.1) if not is_bakery else Color("#C8412F"))
			Blocks.box(parent, Vector3(w - 0.4, 0.12, 1.0), Vector3(pos.x, 2.9, face_z + 0.5 * out), col.darkened(0.25))
			# Cửa sổ các tầng trên
			var y := 4.2
			while y < h - 1.0:
				Blocks.box(parent, Vector3(w * 0.5, 1.0, 0.06), Vector3(pos.x, y, face_z + 0.04 * out), Color("#3D4A4A"))
				y += 3.0
			x += w


static func _park(parent: Node3D, r: Rect2, rng: RandomNumberGenerator) -> void:
	var center := r.get_center()
	Blocks.box(parent, Vector3(r.size.x, 0.05, r.size.y), Vector3(center.x, 0.025, center.y), GRASS)
	# Lối đi chéo
	var path := Blocks.box(parent, Vector3(2.0, 0.06, r.size.length()), Vector3(center.x, 0.03, center.y), SIDEWALK)
	path.rotation.y = atan2(r.size.x, r.size.y)
	# Cây: thân trụ + tán cầu
	for i in 9:
		var p := Vector3(rng.randf_range(r.position.x + 2, r.end.x - 2), 0, rng.randf_range(r.position.y + 2, r.end.y - 2))
		if Vector2(p.x - center.x, p.z - center.y).length() < 2.5:
			continue
		var trunk := StaticBody3D.new()
		trunk.position = p
		parent.add_child(trunk)
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.18
		cyl.bottom_radius = 0.25
		cyl.height = 2.6
		cyl.radial_segments = 10
		cyl.rings = 1
		Blocks.mesh(trunk, cyl, Vector3(0, 1.3, 0), Color("#7A5235"))
		var crown := SphereMesh.new()
		crown.radius = 1.6
		crown.height = 2.8
		crown.radial_segments = 12
		crown.rings = 6
		Blocks.mesh(trunk, crown, Vector3(0, 3.4, 0), Color("#4E8F4A"))
		var shape := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 0.25
		cs.height = 2.6
		shape.shape = cs
		shape.position.y = 1.3
		trunk.add_child(shape)
	# Ghế đá để nhảy lên
	for b in [Vector3(-38, 0, 10), Vector3(-28, 0, 22), Vector3(-40, 0, 20)]:
		Blocks.solid_box(parent, Vector3(1.8, 0.45, 0.6), b + Vector3(0, 0.225, 0), Color("#B8B2A2"))
	# Hàng rào thấp dọc hẻm phía đông công viên (chỗ Chó Mực canh)
	Blocks.solid_box(parent, Vector3(0.2, 0.7, 12.0), Vector3(-22.3, 0.35, 15.5), Color("#5E6F6C"))


static func _street_props(parent: Node3D, rng: RandomNumberGenerator) -> void:
	# Cột điện ở các góc ngã tư
	for p in [Vector3(-23, 0, -6), Vector3(-13, 0, 6), Vector3(11, 0, -6), Vector3(21, 0, 6), Vector3(3, 0, -6), Vector3(31, 0, 6)]:
		var pole := Blocks.solid_box(parent, Vector3(0.25, 7.0, 0.25), p + Vector3(0, 3.5, 0), Color("#5E6F6C"))
		pole.name = "CotDien"
	# Xe máy đậu trên vỉa hè: khối thấp nhảy lên được
	for i in 10:
		var r: Rect2 = BLOCKS[rng.randi() % BLOCKS.size()]
		if r == BLOCKS[PARK_INDEX]:
			continue
		var along := rng.randf_range(r.position.x + 3, r.end.x - 3)
		var z := r.end.y - 1.0 if rng.randf() < 0.5 else r.position.y + 1.0
		var bike := Blocks.solid_box(parent, Vector3(0.5, 0.9, 1.6), Vector3(along, 0.45, z), Color("#C8412F") if i % 2 == 0 else Color("#3D5A80"))
		bike.rotation.y = deg_to_rad(rng.randf_range(-15, 15))


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
