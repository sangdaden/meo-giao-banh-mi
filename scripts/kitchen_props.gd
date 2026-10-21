class_name KitchenProps
## Đồ trong bếp Cô Ba dựng tạm bằng khối, màu lấy theo 15 thẻ đồ bếp kiểu D
## (meo-3d/style-d/renders/p_*.png). Khi có .glb low-poly từ Blender thì thay từng hàm ở đây.

const WOOD := Color("#E2B46E")
const WOOD_DARK := Color("#8A5A30")
const BRICK := Color("#B5553A")
const BRICK_DARK := Color("#8E3F2A")
const IRON := Color("#2B2B2B")
const STEEL := Color("#9AA3A3")
const CREAM := Color("#F2EBDC")
const TEAL := Color("#2E7C80")
const RED := Color("#C8412F")
const LEAF := Color("#6FAE4A")
const LEAF_DARK := Color("#4E8A33")
const HAM := Color("#E9A3A0")
const CHA := Color("#F3EAD3")
const DOUGH := Color("#F4E6C8")
const CRUST := Color("#D98E2B")
const BURNT := Color("#3A2418")
const ORANGE := Color("#E8913A")
const MITT := Color("#FBE3C2")
const WATER := Color(0.62, 0.82, 0.92, 0.55)
const PATE := Color("#9B6A4A")


## Vật liệu riêng (không dùng chung) cho món đổi màu khi nướng.
static func own_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func sphere(parent: Node, r: float, pos: Vector3, color: Color, squash := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	var mi := Blocks.mesh(parent, s, pos, color)
	mi.scale = squash
	return mi


static func cylinder(parent: Node, r: float, h: float, pos: Vector3, color: Color, segs := 16) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return Blocks.mesh(parent, c, pos, color)


static func capsule(parent: Node, r: float, h: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 3
	return Blocks.mesh(parent, c, pos, color)


## Bàn gỗ: mặt dày 6 cm, 4 chân vuông. size = (rộng, cao, sâu). Có va chạm.
static func table(parent: Node, size: Vector3, pos: Vector3, top := WOOD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_PROP
	body.position = pos
	parent.add_child(body)
	Blocks.box(body, Vector3(size.x, 0.06, size.z), Vector3(0, size.y - 0.03, 0), top)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Blocks.box(body, Vector3(0.06, size.y - 0.06, 0.06),
				Vector3(sx * (size.x / 2 - 0.06), (size.y - 0.06) / 2, sz * (size.z / 2 - 0.06)), WOOD_DARK)
	# Thanh giằng ngang như thẻ p_ban
	Blocks.box(body, Vector3(size.x - 0.12, 0.04, 0.04), Vector3(0, 0.18, size.z / 2 - 0.06), WOOD_DARK)
	_shape(body, Vector3(size.x, size.y, size.z), Vector3(0, size.y / 2, 0))
	return body


## Lò gạch mái vòm, cửa sắt quay mặt về +Z. Trả về body; cửa nằm ở body.get_node("Cua").
static func oven(parent: Node, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_PROP
	body.position = pos
	parent.add_child(body)
	# Thân gạch, các hàng gạch sẫm xen kẽ
	Blocks.box(body, Vector3(1.3, 1.1, 1.0), Vector3(0, 0.55, 0), BRICK)
	for i in 6:
		Blocks.box(body, Vector3(1.31, 0.025, 1.01), Vector3(0, 0.12 + i * 0.18, 0), BRICK_DARK)
	# Vòm và ống khói
	var dome := sphere(body, 0.62, Vector3(0, 1.1, 0), BRICK, Vector3(1.0, 0.7, 0.8))
	dome.name = "Vom"
	cylinder(body, 0.09, 0.7, Vector3(0.0, 1.75, -0.15), BRICK_DARK, 10)
	cylinder(body, 0.11, 0.06, Vector3(0.0, 2.1, -0.15), IRON, 10)
	# Miệng lò: hốc tối, lửa sáng bên trong
	Blocks.box(body, Vector3(0.62, 0.42, 0.04), Vector3(0, 0.62, 0.49), Color("#1A1210"))
	var glow := Blocks.box(body, Vector3(0.5, 0.06, 0.03), Vector3(0, 0.44, 0.5), Color("#FF8A2A"))
	glow.name = "Lua"
	# Cửa sắt có bản lề bên trái (pivot ở mép trái cửa)
	var door := Node3D.new()
	door.name = "Cua"
	door.position = Vector3(-0.33, 0.62, 0.53)
	body.add_child(door)
	Blocks.box(door, Vector3(0.66, 0.46, 0.04), Vector3(0.33, 0, 0), IRON)
	Blocks.box(door, Vector3(0.12, 0.04, 0.05), Vector3(0.55, 0.0, 0.04), STEEL)
	# Bậc đá trước miệng lò
	Blocks.box(body, Vector3(0.8, 0.05, 0.22), Vector3(0, 0.38, 0.6), Color("#7A6A5E"))
	_shape(body, Vector3(1.3, 1.6, 1.0), Vector3(0, 0.8, 0))
	return body


## Bao bột mì đứng, miệng bao mở, chữ BỘT MÌ đỏ.
static func flour_sack(parent: Node, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_PROP
	body.position = pos
	parent.add_child(body)
	var c := CylinderMesh.new()
	c.top_radius = 0.2
	c.bottom_radius = 0.26
	c.height = 0.62
	c.radial_segments = 16
	Blocks.mesh(body, c, Vector3(0, 0.31, 0), CREAM)
	sphere(body, 0.19, Vector3(0, 0.62, 0), Color("#FFFFFF"), Vector3(1, 0.35, 1))
	Blocks.box(body, Vector3(0.22, 0.1, 0.01), Vector3(0, 0.38, 0.235), RED)
	var l := Label3D.new()
	l.text = "BỘT MÌ"
	l.font_size = 22
	l.pixel_size = 0.004
	l.modulate = Color.WHITE
	l.position = Vector3(0, 0.38, 0.242)
	body.add_child(l)
	_shape(body, Vector3(0.5, 0.7, 0.5), Vector3(0, 0.35, 0))
	return body


## Kệ gỗ hai tầng sát tường, giữ rổ rau, đòn chả, khúc thịt.
static func shelf(parent: Node, pos: Vector3, width: float) -> StaticBody3D:
	var body := table(parent, Vector3(width, 0.72, 0.5), pos, WOOD)
	Blocks.box(body, Vector3(width - 0.1, 0.04, 0.44), Vector3(0, 0.3, 0), WOOD)
	return body


## Thớt gỗ tròn đặt trên bàn.
static func board(parent: Node, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	cylinder(n, 0.26, 0.05, Vector3(0, 0.025, 0), Color("#EBD8A8"), 24)
	cylinder(n, 0.2, 0.052, Vector3(0, 0.025, 0), Color("#E2CB95"), 24)
	return n


## Dao bếp: lưỡi thép, cán đen. Mũi dao chỉ về +X.
static func knife(parent: Node) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	Blocks.box(n, Vector3(0.2, 0.045, 0.006), Vector3(0.1, 0, 0), STEEL)
	Blocks.box(n, Vector3(0.09, 0.03, 0.02), Vector3(-0.045, 0, 0), IRON)
	return n


## Tủ kính bánh mì (xe Cô Ba): thân xanh, kính trong, mái đỏ, có kệ trong để xếp ổ xong.
static func glass_case(parent: Node, pos: Vector3, width: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_PROP
	body.position = pos
	parent.add_child(body)
	Blocks.box(body, Vector3(width, 0.5, 0.6), Vector3(0, 0.25, 0), TEAL)
	Blocks.box(body, Vector3(width + 0.04, 0.04, 0.64), Vector3(0, 0.52, 0), TEAL.darkened(0.25))
	for sx in [-1, 1]:
		Blocks.box(body, Vector3(0.04, 0.5, 0.04), Vector3(sx * (width / 2 - 0.02), 0.79, 0.28), Color("#DADADA"))
		Blocks.box(body, Vector3(0.04, 0.5, 0.04), Vector3(sx * (width / 2 - 0.02), 0.79, -0.28), Color("#DADADA"))
	Blocks.box(body, Vector3(width, 0.46, 0.01), Vector3(0, 0.79, 0.29), Color(0.82, 0.93, 0.95, 0.22))
	Blocks.box(body, Vector3(0.01, 0.46, 0.56), Vector3(-width / 2, 0.79, 0), Color(0.82, 0.93, 0.95, 0.22))
	Blocks.box(body, Vector3(0.01, 0.46, 0.56), Vector3(width / 2, 0.79, 0), Color(0.82, 0.93, 0.95, 0.22))
	Blocks.box(body, Vector3(width + 0.1, 0.05, 0.7), Vector3(0, 1.06, 0), RED)
	var l := Label3D.new()
	l.text = "BÁNH MÌ CÔ BA"
	l.font_size = 56
	l.pixel_size = 0.004
	l.modulate = Color("#FFF8EA")
	l.outline_size = 8
	l.outline_modulate = RED.darkened(0.4)
	l.position = Vector3(0, 0.27, 0.305)
	body.add_child(l)
	_shape(body, Vector3(width, 1.1, 0.6), Vector3(0, 0.55, 0))
	return body


## Ổ bánh mì dài ~0,2 m (to bằng nửa thân Bơ). Trả về MeshInstance3D có vật liệu riêng để đổi màu.
static func loaf(parent: Node, pos: Vector3, color := CRUST) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = 0.035
	c.height = 0.2
	c.radial_segments = 12
	c.rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = own_mat(color)
	mi.position = pos
	mi.rotation_degrees.z = 90
	mi.scale = Vector3(1, 1, 0.8)
	parent.add_child(mi)
	return mi


## Khay nướng sắt.
static func tray(parent: Node, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	Blocks.box(n, Vector3(0.34, 0.015, 0.22), Vector3.ZERO, STEEL.darkened(0.2))
	for sx in [-1, 1]:
		Blocks.box(n, Vector3(0.01, 0.03, 0.22), Vector3(sx * 0.17, 0.015, 0), STEEL)
	return n


## Chân trước của Bơ cho cận cảnh (model dùng chung, xem scripts/bo_paw.gd).
static func paw(parent: Node, side := 1.0) -> Node3D:
	var n := BoPaw.create(side)
	parent.add_child(n)
	return n


## Món đang cầm trên lưng Bơ (một món một lần).
static func carry_item(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"bot":
			sphere(n, 0.08, Vector3.ZERO, CREAM, Vector3(1, 0.8, 1))
			sphere(n, 0.05, Vector3(0, 0.05, 0), Color.WHITE, Vector3(1, 0.5, 1))
		"khay_song", "khay_chin", "khay_chay":
			tray(n, Vector3.ZERO)
			var col := DOUGH if kind == "khay_song" else (CRUST if kind == "khay_chin" else BURNT)
			for i in 2:
				loaf(n, Vector3(0, 0.04, -0.05 + i * 0.1), col)
		"rau":
			for i in 5:
				sphere(n, 0.04, Vector3(-0.06 + i * 0.03, 0.02, randf_range(-0.02, 0.02)), LEAF)
		"cha":
			var c := cylinder(n, 0.05, 0.16, Vector3.ZERO, LEAF_DARK)
			c.rotation_degrees.z = 90
		"thit":
			sphere(n, 0.07, Vector3.ZERO, HAM, Vector3(1.2, 0.8, 1))
		"rau_xong", "cha_xong", "thit_xong":
			cylinder(n, 0.09, 0.02, Vector3.ZERO, Color.WHITE, 16)
			var col2: Color = {"rau_xong": LEAF, "cha_xong": CHA, "thit_xong": HAM}[kind]
			for i in 4:
				cylinder(n, 0.03, 0.012, Vector3(-0.045 + i * 0.03, 0.018, 0), col2, 10).rotation_degrees.z = 60
		"banh_mi":
			sandwich(n, Vector3.ZERO)
	return n


## Ổ bánh mì đã kẹp nhân: vỏ vàng, lộ chả, thịt, rau.
static func sandwich(parent: Node, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	loaf(n, Vector3.ZERO)
	Blocks.box(n, Vector3(0.18, 0.012, 0.03), Vector3(0, 0.03, 0.0), HAM)
	Blocks.box(n, Vector3(0.16, 0.012, 0.028), Vector3(0, 0.04, 0.0), CHA)
	for i in 4:
		sphere(n, 0.012, Vector3(-0.06 + i * 0.04, 0.05, 0), LEAF)
	return n


static func _shape(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	shape.position = pos
	body.add_child(shape)
