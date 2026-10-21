class_name CityProps
## Đồ của bản đồ Thứ Hai, dựng bằng khối tạm đúng kích thước (theo trang thiết kế màn chơi, mục 03 đến 06).
## Gồm: hẻm 42 rộng 3 m, đồ chắn trong 5 hẻm giữa khối, mái hiên có va chạm, chồng thùng để leo,
## bàn cà phê thấp chui được, tiệm sửa xe có cửa sau ra hẻm khối 6, chung cư có cửa và ban công ra hẻm khối 3.
## Khi trang khu phố được duyệt, thay từng hàm ở đây bằng model .glb, giữ nguyên vị trí và hộp va chạm.
## Tên nhóm (group) để code khác tìm: "hem42_wall", "hem42_fence", "ba_gac", "ban_ca_phe", "mai_hien".

const BRICK := Color("#B9826A")
const WALL := Color("#D8CDB5")
const IRON := Color("#3D4A4A")
const WOOD := Color("#9B6A3A")
const FOAM := Color("#F4F1EA")
const BAGAC := Color("#4F7FA8")
const TABLE := Color("#5FA35A")
const STOOL := Color("#D94F3D")
const POT := Color("#B5653E")
const LEAF := Color("#4E8F4A")
const BARREL := Color("#3D7FB8")
const CLOTH := [Color("#F2E3B8"), Color("#E39C7A"), Color("#A9C7E8"), Color("#D7A9C4"), Color("#FFF8EA")]
const BOUGAIN := Color("#C8407E")

## Hẻm 42: lòng hẻm x từ -20 đến -17, z từ 9 đến 24 (nhà Bà Sáu chặn cuối hẻm)
const HEM42_X := Vector2(-20.0, -17.0)
const HEM42_Z := Vector2(9.0, 24.0)
## Chỗ hẻm giữa khối 5 đâm ra hẻm 42 (tường khối 5 hở một đoạn)
const HEM42_GAP_Z := Vector2(14.3, 16.7)

## Ô nhà đặc biệt trong dãy nhà ống: khối (0..5), dãy (0 = dãy bắc, 1 = dãy nam), x0..x1
const SLOTS := [
	{"block": 2, "row": 0, "x0": 22.0, "x1": 28.5, "kind": "chung_cu"},
	{"block": 5, "row": 1, "x0": 29.5, "x1": 35.0, "kind": "tiem_xe"},
]

## Điểm cho gói giao bánh dùng
const BE_NA_BIKE := Vector3(25.2, 0, -15.6)      ## xe máy đậu dưới ban công Bé Na, giỏ thòng xuống đây
const BE_NA_BALCONY := Vector3(25.2, 6.0, -16.2) ## sàn ban công tầng 3
const CAFE_COUNTER := Vector3(5.4, 0.9, 6.3)     ## mặt quầy Chị Mây
const SHOP_BACK_DOOR := Vector3(32.3, 0, 16.7)   ## cửa sau tiệm xe nhìn ra hẻm khối 6

## Làn xe đẩy hàng rong (traffic.gd): vỉa hè khối 3 và khối 6 nhìn ra đường lớn, tránh cột điện (31, 6) và chồng thùng khối 3
const CART_LANES := [
	[Vector3(21.5, 0, -6.1), Vector3(38.6, 0, -6.1)],
	[Vector3(32.0, 0, 6.1), Vector3(42.5, 0, 6.1)],
]

## Chợ tạm Thứ Ba (scripts/market.gd): chiếm đường lớn giữa khối 2 và khối 5, giữa hai ngã tư.
## Hai dãy sạp sát hai mép đường (mép đường ở z = ±5), chừa hai làn xe máy ở z = ±2,5 cho xe chạy chậm qua chợ.
const MARKET_ZONE := Rect2(-13.5, -5.0, 25.0, 10.0)
## Mỗi sạp rộng 1,8 m, sâu 1,4 m, mặt sạp cao 0,62 m, bạt phủ rủ xuống còn cách đất 0,5 m: Bơ chui gầm được.
## side = -1: dãy bắc (khách đứng phía nam), 1: dãy nam. Hai khoảng trống: trước sạp báo Chú Tư và trước quán cà phê Mây.
const MARKET_STALLS := [
	{"pos": Vector3(-12.0, 0, -4.0), "side": -1, "kind": "rau"},
	{"pos": Vector3(-9.7, 0, -4.0), "side": -1, "kind": "trai_cay"},
	{"pos": Vector3(-7.4, 0, -4.0), "side": -1, "kind": "ca"},
	{"pos": Vector3(-5.1, 0, -4.0), "side": -1, "kind": "hoa"},
	{"pos": Vector3(0.6, 0, -4.0), "side": -1, "kind": "kho"},
	{"pos": Vector3(2.9, 0, -4.0), "side": -1, "kind": "rau"},
	{"pos": Vector3(5.2, 0, -4.0), "side": -1, "kind": "trai_cay"},
	{"pos": Vector3(7.5, 0, -4.0), "side": -1, "kind": "ca"},
	{"pos": Vector3(9.8, 0, -4.0), "side": -1, "kind": "rau"},
	{"pos": Vector3(-12.0, 0, 4.0), "side": 1, "kind": "kho"},
	{"pos": Vector3(-9.7, 0, 4.0), "side": 1, "kind": "rau"},
	{"pos": Vector3(-7.4, 0, 4.0), "side": 1, "kind": "hoa"},
	{"pos": Vector3(-5.1, 0, 4.0), "side": 1, "kind": "trai_cay"},
	{"pos": Vector3(-2.8, 0, 4.0), "side": 1, "kind": "ca"},
	{"pos": Vector3(3.6, 0, 4.0), "side": 1, "kind": "rau"},
	{"pos": Vector3(5.9, 0, 4.0), "side": 1, "kind": "trai_cay"},
	{"pos": Vector3(8.2, 0, 4.0), "side": 1, "kind": "kho"},
	{"pos": Vector3(10.5, 0, 4.0), "side": 1, "kind": "hoa"},
]
## Xe ba gác chở hàng về khi chợ tan (đơn 4, 5): nằm giữa đường, dọc trục X
const MARKET_BA_GAC := Vector3(-1.0, 0, 0.2)

## Vùng không thả xe máy ngẫu nhiên (x_min, z_min, cỡ)
const KEEP_CLEAR := [
	Rect2(20.8, -6.2, 18.5, 0.2),   # làn xe đẩy khối 3
	Rect2(31.3, 6.0, 11.9, 0.2),    # làn xe đẩy khối 6
	Rect2(-10.0, 4.9, 17.0, 2.2),   # bàn ghế quán cà phê và chồng thùng bên hông
	Rect2(-12.5, -6.2, 3.5, 1.2),   # chồng thùng leo mái hiên khối 2
	Rect2(-22.0, 5.0, 8.0, 25.0),   # hẻm 42
	Rect2(38.5, 24.9, 2.5, 1.2),    # chồng thùng khối 6
	Rect2(39.5, -6.2, 2.5, 1.2),    # chồng thùng khối 3
]


static func build(parent: Node3D) -> void:
	hem_42(parent)
	_mid_alleys(parent)
	cafe(parent)
	# Chồng thùng bậc thang để leo lên mái hiên (bậc 0,8 m, nhảy được 1,3 m)
	_stair(parent, Vector3(-11.7, 0, -5.6), 1.0)   # khối 2, đối diện lò bánh: lối mái hiên khối 2
	_stair(parent, Vector3(-9.2, 0, 5.6), 1.0)     # khối 5, bên hông quán cà phê
	_stair(parent, Vector3(40.5, 0, 25.4), -1.0)   # khối 6, gần tiệm xe
	_stair(parent, Vector3(41.5, 0, -5.6), -1.0)   # khối 3


static func slot_at(block_index: int, row_index: int, x: float) -> Dictionary:
	for s in SLOTS:
		if s.block == block_index and s.row == row_index and x >= s.x0 - 0.01 and x < s.x1:
			return s
	return {}


## x bắt đầu của ô đặc biệt kế tiếp trong dãy (INF nếu không có)
static func next_slot_x(block_index: int, row_index: int, x: float) -> float:
	var best := INF
	for s in SLOTS:
		if s.block == block_index and s.row == row_index and s.x0 > x:
			best = minf(best, s.x0)
	return best


static func keep_clear(p: Vector2) -> bool:
	for r: Rect2 in KEEP_CLEAR:
		if r.grow(0.9).has_point(p):
			return true
	return false


## Mái hiên: tấm dày 0,12 m, sâu 1 m. Rộng đúng bằng ô nhà nên nối liền với nhà bên cạnh.
## Lớp PROP để camera không bị kéo sát vào khi Bơ đi dưới mái hiên.
static func awning(parent: Node3D, width: float, pos: Vector3, color: Color) -> StaticBody3D:
	var b := Blocks.solid_box(parent, Vector3(width, 0.12, 1.0), pos, color, Blocks.LAYER_PROP)
	b.add_to_group("mai_hien")
	return b


static func build_slot(parent: Node3D, slot: Dictionary, z0: float, depth: float) -> void:
	match slot.kind:
		"chung_cu":
			_chung_cu(parent, slot.x0, slot.x1, z0, depth)
		"tiem_xe":
			_tiem_xe(parent, slot.x0, slot.x1, z0, depth)


# ------------------------------------------------------------------ hẻm 42

static func hem_42(parent: Node3D) -> void:
	var x0 := HEM42_X.x
	var x1 := HEM42_X.y
	var z0 := HEM42_Z.x
	var z1 := HEM42_Z.y
	# Cỏ công viên lấn ra tới bờ rào (đường 8 m cũ thu lại còn hẻm 3 m)
	Blocks.box(parent, Vector3(x0 - 0.3 + 22.0, 0.05, z1 - z0 + 6.0), Vector3((-22.0 + x0 - 0.3) / 2.0, 0.025, (z0 + z1 + 6.0) / 2.0), Color("#7DB46C"))
	# Lòng hẻm láng xi măng
	Blocks.box(parent, Vector3(x1 - x0, 0.03, z1 - z0), Vector3((x0 + x1) / 2.0, 0.015, (z0 + z1) / 2.0), Color("#A8A397"))
	# Bờ rào gạch thấp 0,7 m phía công viên: nhảy lên chạy được (cách C)
	var fence := Blocks.solid_box(parent, Vector3(0.3, 0.7, z1 - z0), Vector3(x0 - 0.15, 0.35, (z0 + z1) / 2.0), BRICK, Blocks.LAYER_PROP)
	fence.add_to_group("hem42_fence")
	# Tường khối 5 phía đông, hở một đoạn ở hẻm giữa khối 5
	var segs := [Vector2(z0, HEM42_GAP_Z.x), Vector2(HEM42_GAP_Z.y, z1)]
	var heights := [4.5, 3.8]
	for i in segs.size():
		var s: Vector2 = segs[i]
		var wall := Blocks.solid_box(parent, Vector3(-14.0 - x1, heights[i], s.y - s.x), Vector3((x1 - 14.0) / 2.0, heights[i] / 2.0, (s.x + s.y) / 2.0), WALL)
		wall.add_to_group("hem42_wall")
		# Mấy ô cửa sổ song sắt nhìn ra hẻm
		var z := s.x + 1.5
		while z < s.y - 1.0:
			Blocks.box(parent, Vector3(0.06, 0.8, 0.9), Vector3(x1 + 0.03, 2.6, z), IRON)
			z += 2.6
	# Biển tên hẻm ở đầu hẻm
	Blocks.box(parent, Vector3(0.08, 0.35, 0.7), Vector3(x1 + 0.05, 2.4, z0 + 0.4), Color("#2E5F8A"))
	Blocks.label(parent, "HẺM 42", Vector3((x0 + x1) / 2.0, 3.2, z0), 48, Color("#FFF8EA"))
	# Nhà Bà Sáu chặn cuối hẻm: cổng sắt, giàn bông giấy, ghế mây
	var house_z := z1 + 0.5
	Blocks.solid_box(parent, Vector3(6.3, 6.0, 29.8 - house_z), Vector3(-17.15, 3.0, (house_z + 29.8) / 2.0), Color("#E8C98A"))
	Blocks.solid_box(parent, Vector3(x1 - x0, 2.2, 0.1), Vector3((x0 + x1) / 2.0, 1.1, house_z - 0.1), IRON)  # cổng sắt (đóng)
	for i in 9:
		Blocks.box(parent, Vector3(0.05, 2.2, 0.05), Vector3(x0 + 0.3 + i * 0.3, 1.1, house_z - 0.2), Color("#566363"))
	_bougainvillea(parent, Vector3((x0 + x1) / 2.0, 0, z1 - 0.4), x1 - x0)
	Blocks.solid_box(parent, Vector3(0.6, 0.5, 0.6), Vector3(-19.5, 0.25, 22.7), Color("#C9A06A"), Blocks.LAYER_PROP)  # ghế mây Bà Sáu
	Blocks.box(parent, Vector3(0.6, 0.6, 0.1), Vector3(-19.5, 0.8, 22.98), Color("#C9A06A"))  # lưng ghế
	# Xe ba gác sát tường khối 5: gầm cao 0,4 m, Bơ chui được, Chó Mực thì không (cách A)
	_ba_gac(parent, Vector3(-17.5, 0, 12.8), 0.0)
	# Ổ chó bằng thùng gỗ sát bờ rào, chừa chỗ nằm (-18, 15) trước cửa ổ
	var kennel := Blocks.solid_box(parent, Vector3(0.9, 0.8, 1.0), Vector3(-19.45, 0.4, 14.0), WOOD, Blocks.LAYER_PROP)
	kennel.add_to_group("o_cho")
	Blocks.box(kennel, Vector3(0.05, 0.5, 0.5), Vector3(0.46, -0.1, 0.0), Color("#3A2A1C"))  # cửa ổ
	Blocks.box(parent, Vector3(1.0, 0.04, 0.8), Vector3(-18.1, 0.05, 15.0), Color("#C8412F"))  # tấm bao bố chỗ Mực nằm
	# Thùng xốp chồng hai tầng
	Blocks.solid_box(parent, Vector3(0.6, 0.5, 0.45), Vector3(-19.4, 0.25, 18.6), FOAM, Blocks.LAYER_PROP)
	Blocks.solid_box(parent, Vector3(0.6, 0.5, 0.45), Vector3(-19.4, 0.75, 18.6), FOAM, Blocks.LAYER_PROP)
	_pot(parent, Vector3(-17.35, 0, 20.5))
	_pot(parent, Vector3(-17.35, 0, 21.3))


static func _bougainvillea(parent: Node3D, base: Vector3, width: float) -> void:
	# Hai cột, một thanh ngang cao 2,4 m có va chạm (sau này leo được), chùm bông phủ trên
	for side in [-1.0, 1.0]:
		Blocks.solid_box(parent, Vector3(0.1, 2.4, 0.1), base + Vector3(side * (width / 2.0 - 0.1), 1.2, 0), WOOD, Blocks.LAYER_PROP)
	Blocks.solid_box(parent, Vector3(width, 0.1, 0.6), base + Vector3(0, 2.45, 0.1), WOOD, Blocks.LAYER_PROP)
	for i in 6:
		var s := SphereMesh.new()
		s.radius = 0.35
		s.height = 0.5
		s.radial_segments = 8
		s.rings = 4
		Blocks.mesh(parent, s, base + Vector3(-width / 2.0 + 0.3 + i * (width - 0.6) / 5.0, 2.6 + 0.1 * (i % 2), 0.1), BOUGAIN)


# ------------------------------------------------------------------ hẻm giữa khối

## Đồ đặt trong hẻm 2,4 m giữa hai dãy nhà ống. z là tâm hẻm (khối 1-3: -15.5, khối 5-6: 15.5).
## Mỗi chỗ chắn đều đi qua được bằng cách khác: chui gầm, nhảy lên, hoặc lách khe 0,6 m.
static func _mid_alleys(parent: Node3D) -> void:
	var zn := -15.5
	var zs := 15.5
	# Khối 1 (lò bánh): thùng nước, chậu cây, dây phơi
	_barrel(parent, Vector3(-40.5, 0, zn - 0.75))
	_pot(parent, Vector3(-37.0, 0, zn + 0.85))
	_laundry(parent, -33.0, zn)
	_crate_pair(parent, Vector3(-28.0, 0, zn - 0.6))
	# Khối 2 (sạp báo): xe ba gác ngang hẻm, dây phơi ngay trên (phải chui hoặc trèo lên sàn xe)
	_pot(parent, Vector3(-10.0, 0, zn + 0.85))
	_ba_gac_across(parent, -4.0, zn)
	_barrel(parent, Vector3(3.0, 0, zn + 0.75))
	_laundry(parent, 7.0, zn)
	# Khối 3 (chung cư): xe máy dưới ban công Bé Na nằm trong _chung_cu; thêm dây phơi, chậu cây
	_laundry(parent, 32.0, zn)
	_pot(parent, Vector3(36.0, 0, zn - 0.85))
	_pot(parent, Vector3(36.8, 0, zn - 0.85))
	_crate_pair(parent, Vector3(40.0, 0, zn + 0.6))
	# Khối 5 (cà phê): đầu tây thông ra hẻm 42; ba gác và dây phơi
	_barrel(parent, Vector3(-9.5, 0, zs - 0.75))
	_laundry(parent, -5.0, zs)
	_ba_gac_across(parent, 1.0, zs)
	_pot(parent, Vector3(6.0, 0, zs + 0.85))
	# Khối 6 (tiệm xe): ba gác phải chui, dây phơi, rồi tới cửa sau tiệm xe
	_crate_pair(parent, Vector3(23.5, 0, zs + 0.6))
	_ba_gac_across(parent, 26.5, zs)
	_pot(parent, Vector3(30.5, 0, zs - 0.85))
	_barrel(parent, Vector3(37.0, 0, zs - 0.75))
	_laundry(parent, 39.5, zs)


## Xe ba gác: sàn gỗ 0,9 x 1,8 m, gầm 0,4 m, mặt sàn 0,55 m, tay cầm ở đầu xe.
## rot_y = 0: thân xe dọc trục Z.
static func _ba_gac(parent: Node3D, pos: Vector3, rot_y: float) -> StaticBody3D:
	var b := Blocks.solid_box(parent, Vector3(0.9, 0.15, 1.8), pos + Vector3(0, 0.475, 0), BAGAC, Blocks.LAYER_PROP)
	b.rotation.y = rot_y
	b.add_to_group("ba_gac")
	# Thành xe thấp (chỉ để nhìn), bánh xe và chân chống ở 4 góc (không va chạm để gầm thông)
	Blocks.box(b, Vector3(0.9, 0.2, 0.05), Vector3(0, 0.17, 0.88), BAGAC.darkened(0.2))
	Blocks.box(b, Vector3(0.9, 0.2, 0.05), Vector3(0, 0.17, -0.88), BAGAC.darkened(0.2))
	for sx in [-1.0, 1.0]:
		Blocks.box(b, Vector3(0.06, 0.4, 0.4), Vector3(sx * 0.42, -0.275, -0.55), Color("#2B2622"))  # bánh
		Blocks.box(b, Vector3(0.04, 0.4, 0.04), Vector3(sx * 0.4, -0.275, 0.82), Color("#2B2622"))   # chân chống
		Blocks.box(b, Vector3(0.04, 0.04, 0.6), Vector3(sx * 0.3, 0.2, 1.15), IRON)                   # càng xe
	return b


## Ba gác đặt ngang hẻm, sát tường phía bắc, khe 0,6 m còn lại có chậu cây chặn.
static func _ba_gac_across(parent: Node3D, x: float, z_mid: float) -> void:
	_ba_gac(parent, Vector3(x, 0, z_mid - 0.3), 0.0)
	_pot(parent, Vector3(x, 0, z_mid + 0.9))
	_laundry(parent, x, z_mid)


## Dây phơi ngang hẻm cao 2,4 m, đồ phơi thòng xuống tới 1,4 m: đi bộ qua được, không nhảy qua được.
static func _laundry(parent: Node3D, x: float, z_mid: float) -> void:
	Blocks.box(parent, Vector3(0.02, 0.02, 2.4), Vector3(x, 2.4, z_mid), Color("#566363"))
	for i in 3:
		var col: Color = CLOTH[int(absf(x * 7.0 + i)) % CLOTH.size()]
		var sheet := Blocks.solid_box(parent, Vector3(0.04, 0.9, 0.62), Vector3(x, 1.9, z_mid - 0.75 + i * 0.75), col, Blocks.LAYER_PROP)
		sheet.add_to_group("day_phoi")


static func _pot(parent: Node3D, pos: Vector3) -> void:
	var p := Blocks.solid_box(parent, Vector3(0.45, 0.45, 0.45), pos + Vector3(0, 0.225, 0), POT, Blocks.LAYER_PROP)
	var s := SphereMesh.new()
	s.radius = 0.32
	s.height = 0.5
	s.radial_segments = 8
	s.rings = 4
	Blocks.mesh(p, s, Vector3(0, 0.4, 0), LEAF)


static func _barrel(parent: Node3D, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_PROP
	body.position = pos
	parent.add_child(body)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.3
	cyl.height = 0.9
	cyl.radial_segments = 12
	cyl.rings = 1
	Blocks.mesh(body, cyl, Vector3(0, 0.45, 0), BARREL)
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.32
	cs.height = 0.9
	shape.shape = cs
	shape.position.y = 0.45
	body.add_child(shape)


static func _crate_pair(parent: Node3D, pos: Vector3) -> void:
	Blocks.solid_box(parent, Vector3(0.8, 0.8, 0.8), pos + Vector3(0, 0.4, 0), WOOD, Blocks.LAYER_PROP)
	Blocks.solid_box(parent, Vector3(0.8, 0.8, 0.8), pos + Vector3(0.85, 0.4, 0), WOOD, Blocks.LAYER_PROP)
	Blocks.solid_box(parent, Vector3(0.8, 0.8, 0.8), pos + Vector3(0.4, 1.2, 0), WOOD, Blocks.LAYER_PROP)


## Chồng thùng ba bậc 0,8 / 1,6 / 2,4 m cạnh mái hiên (mái hiên cao 2,96 m). dir = hướng bậc cao dần theo X.
static func _stair(parent: Node3D, pos: Vector3, dir: float) -> void:
	for step in 3:
		for level in step + 1:
			Blocks.solid_box(parent, Vector3(0.8, 0.8, 0.8), pos + Vector3(dir * step * 0.8, 0.4 + level * 0.8, 0), WOOD, Blocks.LAYER_PROP)


# ------------------------------------------------------------------ quán cà phê Mây

## Vỉa hè trước quán (khối 5, mặt bắc, z 5..7) kín bàn nhựa xanh thấp 0,45 m và ghế đỏ có khách.
## Bơ chui dưới hàng bàn (gầm 0,41 m) hoặc leo chồng thùng bên hông lên mái hiên rồi nhảy xuống trước quầy.
static func cafe(parent: Node3D) -> void:
	var z := 6.0
	var x := -6.0
	var i := 0
	while x < 2.7:
		var t := Blocks.solid_box(parent, Vector3(0.7, 0.04, 0.7), Vector3(x, 0.43, z), TABLE, Blocks.LAYER_PROP)
		t.add_to_group("ban_ca_phe")
		for c in [Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)]:
			Blocks.box(t, Vector3(0.03, 0.41, 0.03), Vector3(c.x, -0.225, c.y), TABLE.darkened(0.2))  # chân bàn, không va chạm
		# Ghế đỏ hai bên bàn (phía đường và phía nhà), vài ghế có khách ngồi
		for side in [-1.0, 1.0]:
			var sz: float = z + side * 0.62
			Blocks.solid_box(parent, Vector3(0.3, 0.28, 0.3), Vector3(x, 0.14, sz), STOOL, Blocks.LAYER_PROP)
			if (i + int(side > 0)) % 3 == 0:
				_seated_customer(parent, Vector3(x, 0.28, sz), side)
		x += 1.0
		i += 1
	# Quầy Chị Mây: cao 0,9 m, đặt bánh lên đây
	Blocks.solid_box(parent, Vector3(1.4, 0.9, 0.6), CAFE_COUNTER - Vector3(0, 0.45, 0), Color("#8C5A3A"), Blocks.LAYER_PROP)
	Blocks.box(parent, Vector3(1.44, 0.04, 0.64), CAFE_COUNTER + Vector3(0, 0.02, 0), Color("#E7D8B8"))
	Blocks.label(parent, "CÀ PHÊ MÂY", Vector3(2.0, 3.6, 6.6), 64, Color("#7FB7A4"))


## Khách ngồi ghế: thân trên + đùi duỗi về phía bàn. Có va chạm (chân khách chắn đường).
static func _seated_customer(parent: Node3D, seat: Vector3, side: float) -> void:
	var shirt: Color = CLOTH[int(absf(seat.x * 3.0)) % CLOTH.size()].darkened(0.15)
	var body := Blocks.solid_box(parent, Vector3(0.42, 0.6, 0.28), seat + Vector3(0, 0.3, side * 0.05), shirt, Blocks.LAYER_PROP)
	body.add_to_group("khach_ca_phe")
	Blocks.box(body, Vector3(0.36, 0.14, 0.4), Vector3(0, -0.22, -side * 0.3), Color("#3D4A4A"))  # đùi
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	head.radial_segments = 10
	head.rings = 5
	Blocks.mesh(body, head, Vector3(0, 0.45, 0), Color("#E7B98F"))


# ------------------------------------------------------------------ nhà đặc biệt

## Chung cư 5 tầng (cao 15 m) đầu tây dãy bắc khối 3. Cửa chính mở ra hẻm giữa khối,
## ban công tầng 3 nhô ra hẻm, xe máy đậu ngay dưới cho Bơ nhảy lên đón giỏ của Bé Na.
static func _chung_cu(parent: Node3D, x0: float, x1: float, z0: float, depth: float) -> void:
	var w := x1 - x0
	var cx := (x0 + x1) / 2.0
	var h := 15.0
	var col := Color("#BFD8D2")
	var back_z := z0 + depth  # mặt nhìn ra hẻm giữa khối
	Blocks.solid_box(parent, Vector3(w - 0.15, h, depth), Vector3(cx, h / 2.0, z0 + depth / 2.0), col)
	# Mặt đường lớn (phía bắc): cửa sổ từng tầng, mái hiên như nhà khác
	awning(parent, w, Vector3(cx, 2.9, z0 - 0.5), col.darkened(0.25))
	Blocks.box(parent, Vector3(w - 0.9, 2.4, 0.06), Vector3(cx, 1.2, z0 - 0.04), Color("#E8E2D0"))
	var y := 4.2
	while y < h - 1.0:
		for k in 2:
			Blocks.box(parent, Vector3(1.4, 1.0, 0.06), Vector3(x0 + w * (0.28 + 0.44 * k), y, z0 - 0.04), Color("#3D4A4A"))
			Blocks.box(parent, Vector3(1.4, 1.0, 0.06), Vector3(x0 + w * (0.28 + 0.44 * k), y, back_z + 0.04), Color("#3D4A4A"))
		y += 3.0
	# Cửa chính ra hẻm (cảnh leo chung cư Thứ Năm sẽ nạp khi bước qua cửa này)
	Blocks.box(parent, Vector3(1.4, 2.3, 0.08), Vector3(x0 + 1.4, 1.15, back_z + 0.05), Color("#6B4A2E"))
	Blocks.solid_box(parent, Vector3(1.8, 0.1, 0.8), Vector3(x0 + 1.4, 2.6, back_z + 0.4), col.darkened(0.3), Blocks.LAYER_PROP)  # mái che cửa
	Blocks.label(parent, "CHUNG CƯ", Vector3(x0 + 1.4, 3.2, back_z + 0.3), 40, Color("#2E5F8A"))
	# Ban công tầng 3 (sàn cao 6 m) nhô ra hẻm 1 m, lan can 1 m
	var bal := Vector3(BE_NA_BALCONY.x, BE_NA_BALCONY.y, back_z + 0.5)
	Blocks.solid_box(parent, Vector3(2.4, 0.15, 1.0), bal, col.darkened(0.2))
	Blocks.box(parent, Vector3(2.4, 1.0, 0.05), bal + Vector3(0, 0.55, 0.48), IRON)
	for sx in [-1.0, 1.0]:
		Blocks.box(parent, Vector3(0.05, 1.0, 1.0), bal + Vector3(sx * 1.18, 0.55, 0), IRON)
	Blocks.box(parent, Vector3(1.0, 2.0, 0.06), bal + Vector3(0, 1.1, -0.47), Color("#6B4A2E"))  # cửa ra ban công
	# Xe máy đậu dọc hẻm dưới ban công: bậc nhảy 0,9 m để đón giỏ
	var bike := Blocks.solid_box(parent, Vector3(1.6, 0.9, 0.5), BE_NA_BIKE + Vector3(0, 0.45, 0), Color("#C8412F"), Blocks.LAYER_PROP)
	bike.add_to_group("xe_may_be_na")
	Blocks.box(bike, Vector3(0.7, 0.08, 0.36), Vector3(-0.1, 0.49, 0), Color("#2B2622"))  # yên xe


## Tiệm sửa xe Anh Hùng: tầng trệt rỗng, mặt tiền mở ra đường phía nam, cửa sau 1,2 m ra hẻm giữa khối 6.
static func _tiem_xe(parent: Node3D, x0: float, x1: float, z0: float, depth: float) -> void:
	var w := x1 - x0
	var cx := (x0 + x1) / 2.0
	var z1 := z0 + depth   # mặt tiền (phía nam)
	var zc := z0 + depth / 2.0
	var col := Color("#A9C7E8")
	var ground_h := 3.2
	var h := 7.0
	# Hai vách hông, trần, các tầng trên
	for sx in [x0 + 0.1, x1 - 0.1]:
		Blocks.solid_box(parent, Vector3(0.2, ground_h, depth), Vector3(sx, ground_h / 2.0, zc), col)
	Blocks.solid_box(parent, Vector3(w - 0.15, h - ground_h, depth), Vector3(cx, (h + ground_h) / 2.0, zc), col)
	Blocks.box(parent, Vector3(w - 0.4, 0.02, depth - 0.1), Vector3(cx, ground_h - 0.01, zc), Color("#5E6F6C"))  # trần
	Blocks.box(parent, Vector3(w - 0.4, 0.02, depth - 0.1), Vector3(cx, 0.02, zc), Color("#6E6A62"))  # nền láng dầu
	# Tường sau có cửa
	var door_x := SHOP_BACK_DOOR.x
	var door_w := 1.2
	var left_w := door_x - door_w / 2.0 - x0
	var right_w := x1 - (door_x + door_w / 2.0)
	Blocks.solid_box(parent, Vector3(left_w, ground_h, 0.2), Vector3(x0 + left_w / 2.0, ground_h / 2.0, z0 + 0.1), col)
	Blocks.solid_box(parent, Vector3(right_w, ground_h, 0.2), Vector3(x1 - right_w / 2.0, ground_h / 2.0, z0 + 0.1), col)
	Blocks.solid_box(parent, Vector3(door_w, ground_h - 2.2, 0.2), Vector3(door_x, 2.2 + (ground_h - 2.2) / 2.0, z0 + 0.1), col)
	Blocks.box(parent, Vector3(door_w + 0.2, 0.12, 0.25), Vector3(door_x, 2.26, z0 + 0.05), Color("#6B4A2E"))  # khung cửa
	# Mái hiên và bảng hiệu mặt tiền
	awning(parent, w, Vector3(cx, 2.9, z1 + 0.5), col.darkened(0.25))
	Blocks.label(parent, "SỬA XE HÙNG", Vector3(cx, 3.6, z1 + 0.2), 56, Color("#F2C14E"))
	# Đồ trong tiệm, chừa lối đi giữa x 31,4..33,2 từ cửa sau ra mặt tiền
	Blocks.solid_box(parent, Vector3(0.5, 0.9, 1.6), Vector3(30.5, 0.45, zc - 1.2), Color("#3D5A80"), Blocks.LAYER_PROP)  # xe máy dựng chân chống
	Blocks.solid_box(parent, Vector3(0.5, 0.9, 1.6), Vector3(30.5, 0.45, zc + 1.8), Color("#C8412F"), Blocks.LAYER_PROP)
	Blocks.solid_box(parent, Vector3(1.0, 0.5, 2.0), Vector3(34.0, 0.25, zc + 1.0), Color("#5E6F6C"), Blocks.LAYER_PROP)    # bàn nâng
	Blocks.solid_box(parent, Vector3(0.5, 0.9, 1.6), Vector3(34.0, 0.95, zc + 1.0), Color("#7FB7A4"), Blocks.LAYER_PROP)    # xe trên bàn nâng
	Blocks.solid_box(parent, Vector3(0.4, 2.0, 1.8), Vector3(x0 + 0.4, 1.0, z0 + 1.6), WOOD, Blocks.LAYER_PROP)             # kệ đồ nghề
	for k in 4:
		Blocks.solid_box(parent, Vector3(0.6, 0.2, 0.6), Vector3(34.4, 0.1 + k * 0.2, z0 + 1.0), Color("#2B2622"), Blocks.LAYER_PROP)  # chồng lốp
	_barrel(parent, Vector3(33.9, 0, z0 + 2.3))  # bình hơi (tạm dùng thùng tròn)
