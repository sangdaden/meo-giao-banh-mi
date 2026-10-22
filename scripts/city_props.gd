class_name CityProps
## Đồ của bản đồ Thứ Hai (theo trang thiết kế màn chơi, mục 03 đến 06).
## Gồm: hẻm 42 rộng 3 m, đồ chắn trong 5 hẻm giữa khối, mái hiên có va chạm, chồng thùng để leo,
## bàn cà phê thấp chui được, tiệm sửa xe có cửa sau ra hẻm khối 6, chung cư có cửa và ban công ra hẻm khối 3.
## Hình là model Blender theo trang "Khu phố Lò Bánh" (PhoModels, assets/models/pho/); va chạm vẫn là
## hộp đúng kích thước như bản khối tạm (Blocks.collider), nên lối chơi không đổi.
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
const CAP := Color("#9C978C")

## Hẻm 42: lòng hẻm x từ -20 đến -17, z từ 9 đến 21,6 (sân nhà Bà Sáu chặn cuối hẻm)
const HEM42_X := Vector2(-20.0, -17.0)
const HEM42_Z := Vector2(9.0, 21.6)
## Sân nhà Bà Sáu (G7, mọi ngày): cổng z 22,0 rộng 2,5 m, sân gạch 6 × 4,6 m, nhà giữ mặt tiền z 26,6
const BA_SAU_YARD := Rect2(-21.5, 22.0, 6.0, 4.6)
const BA_SAU_FRONT := 26.6
const BA_SAU_GATE_W := 2.5
const BA_SAU_CHAIR := Vector3(-20.4, 0, 25.6)   ## ghế mây cạnh lu, lưng ghế phía nhà (z + 0,28)
const BA_SAU_LU := Vector3(-21.05, 0, 26.0)
const BA_SAU_POTS := [Vector3(-21.05, 0, 22.9), Vector3(-21.05, 0, 23.7)]
## Giàn bông giấy trùm lên cổng: 2,6 × 1,2 m, mặt trên 2,3 m, thang hai bên bậc 30 cm, ván đi ở x -17,9
const GIAN_POS := Vector3(-18.5, 0, 22.0)
const GIAN_SIZE := Vector3(2.6, 2.3, 1.2)
const GIAN_PLANK_X := -17.9
const GIO := "res://assets/models/gio/%s.glb"
const PINK := Color("#E2A7B4")
## Chỗ hẻm giữa khối 5 đâm ra hẻm 42 (tường khối 5 hở một đoạn)
const HEM42_GAP_Z := Vector2(14.3, 16.7)

## Ô nhà đặc biệt trong dãy nhà ống: khối (0..5), dãy (0 = dãy bắc, 1 = dãy nam), x0..x1
const SLOTS := [
	{"block": 0, "row": 1, "x0": -35.6, "x1": -30.4, "kind": "lo_banh"},
	{"block": 2, "row": 0, "x0": 22.0, "x1": 42.0, "kind": "chung_cu"},
	{"block": 4, "row": 0, "x0": 4.0, "x1": 10.0, "kind": "cafe_may"},
	{"block": 5, "row": 1, "x0": 28.3, "x1": 29.5, "kind": "khe_hong"},  # khe 1,2 m bên hông tiệm xe (G6, ThuSau.build_khe)
	{"block": 5, "row": 1, "x0": 29.5, "x1": 35.0, "kind": "tiem_xe"},
	{"block": 1, "row": 0, "x0": 5.6, "x1": 10.0, "kind": "tap_hoa"},  # tạp hóa Cô Hai (ShopTapHoa), mặt tiền nhìn ra phía bắc
]

## Bốn màu bạt mái hiên và bốn màu xe máy đậu (model)
const AWNINGS := ["mai_hien_do", "mai_hien_xanh", "mai_hien_la", "mai_hien_vang"]
const BIKES := ["xe_may_do", "xe_may_den", "xe_may_xanh", "xe_may_trang"]

## Điểm cho gói giao bánh dùng
const BE_NA_BIKE := Vector3(25.2, 0, -15.6)      ## xe máy đậu dưới ban công Bé Na, giỏ thòng xuống đây
const BE_NA_BALCONY := Vector3(25.2, 6.0, -16.2) ## sàn ban công tầng 3
const CAFE_COUNTER := Vector3(5.4, 0.9, 6.3)     ## mặt quầy Chị Mây
const SHOP_BACK_DOOR := Vector3(32.3, 0, 16.7)   ## cửa sau tiệm xe nhìn ra hẻm khối 6
const CHESS_CORNER := Vector3(-29.0, 0, 8.5)     ## tâm bàn cờ góc công viên khối 4 (chess_corner.gd, đơn 3 Thứ Ba)

## Làn xe đẩy hàng rong (traffic.gd): vỉa hè khối 3 và khối 6 nhìn ra đường lớn, tránh cột điện (31, 6) và chồng thùng khối 3
const CART_LANES := [
	[Vector3(21.5, 0, -6.1), Vector3(38.6, 0, -6.1)],
	[Vector3(32.0, 0, 6.1), Vector3(42.5, 0, 6.1)],
]

## Chợ tạm Thứ Ba (scripts/market.gd): chiếm đường lớn giữa khối 2 và khối 5, giữa hai ngã tư.
## Hai dãy sạp sát hai mép đường (mép đường ở z = ±5), chừa hai làn xe máy ở z = ±2,5 cho xe chạy chậm qua chợ.
const MARKET_ZONE := Rect2(-13.5, -5.0, 25.0, 10.0)
## Mỗi sạp (model sap_rau / sap_trai / sap_kho) rộng 1,8 m, sâu 1,1 m, mặt bàn cao 0,72 m, bạt rủ xuống còn
## cách đất 0,5 m: Bơ chui gầm được.
## side = -1: dãy bắc (khách đứng phía nam), 1: dãy nam. Hai khoảng trống: trước sạp báo Chú Tư và trước quán cà phê Mây.
const MARKET_STALLS := [
	{"pos": Vector3(-12.0, 0, -4.0), "side": -1, "kind": "rau"},
	{"pos": Vector3(-9.7, 0, -4.0), "side": -1, "kind": "trai"},
	{"pos": Vector3(-7.4, 0, -4.0), "side": -1, "kind": "rau"},
	{"pos": Vector3(-5.1, 0, -4.0), "side": -1, "kind": "trai"},
	{"pos": Vector3(0.6, 0, -4.0), "side": -1, "kind": "kho"},
	{"pos": Vector3(2.9, 0, -4.0), "side": -1, "kind": "rau"},
	{"pos": Vector3(5.2, 0, -4.0), "side": -1, "kind": "trai"},
	{"pos": Vector3(7.5, 0, -4.0), "side": -1, "kind": "rau"},
	{"pos": Vector3(9.8, 0, -4.0), "side": -1, "kind": "rau"},
	{"pos": Vector3(-12.0, 0, 4.0), "side": 1, "kind": "kho"},
	{"pos": Vector3(-9.7, 0, 4.0), "side": 1, "kind": "rau"},
	{"pos": Vector3(-7.4, 0, 4.0), "side": 1, "kind": "trai"},
	{"pos": Vector3(-5.1, 0, 4.0), "side": 1, "kind": "trai"},
	{"pos": Vector3(-2.8, 0, 4.0), "side": 1, "kind": "rau"},
	{"pos": Vector3(3.6, 0, 4.0), "side": 1, "kind": "rau"},
	{"pos": Vector3(5.9, 0, 4.0), "side": 1, "kind": "trai"},
	{"pos": Vector3(8.2, 0, 4.0), "side": 1, "kind": "kho"},
	{"pos": Vector3(10.5, 0, 4.0), "side": 1, "kind": "trai"},
]
## Xe ba gác chở hàng về khi chợ tan (đơn 4, 5): nằm giữa đường, dọc trục X (gốc model ba_gac)
const MARKET_BA_GAC := Vector3(-1.0, 0, 0.2)

## Vùng không thả xe máy ngẫu nhiên (x_min, z_min, cỡ)
const KEEP_CLEAR := [
	Rect2(20.8, -6.2, 18.5, 0.2),   # làn xe đẩy khối 3
	Rect2(31.3, 6.0, 11.9, 0.2),    # làn xe đẩy khối 6
	Rect2(-10.0, 4.9, 17.0, 2.2),   # bàn ghế quán cà phê và chồng thùng bên hông
	Rect2(-12.5, -6.2, 3.5, 1.2),   # chồng thùng leo mái hiên khối 2
	Rect2(-22.0, 5.0, 8.0, 25.0),   # hẻm 42
	Rect2(-37.0, -7.2, 9.0, 2.2),   # trước lò bánh Cô Ba: chỗ nhận bánh, xe tủ kính
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


## Mái hiên: tấm va chạm dày 0,12 m, sâu 1 m, mặt trên 2,96 m. Rộng đúng bằng ô nhà nên nối liền với nhà bên cạnh.
## Lớp PROP để camera không bị kéo sát vào khi Bơ đi dưới mái hiên. Hình là bạt sọc (model) giãn theo bề ngang,
## mép trong cao 3,0 m sát tường, dốc nhẹ ra ngoài. out = 1 nếu mái nhô về +z, -1 nếu về -z.
static func awning(parent: Node3D, width: float, pos: Vector3, model: String, out := 1.0) -> StaticBody3D:
	var b := Blocks.collider(parent, Vector3(width, 0.12, 1.0), pos, Blocks.LAYER_PROP)
	b.add_to_group("mai_hien")
	PhoModels.put(b, model, Vector3(0, 0.1, -0.5 * out), 0.0 if out > 0 else PI, Vector3(width, 1, 1))
	return b


static func build_slot(parent: Node3D, slot: Dictionary, z0: float, depth: float) -> void:
	match slot.kind:
		"lo_banh":
			_lo_banh(parent, slot.x0, slot.x1, z0, depth)
		"cafe_may":
			_cafe_may(parent, slot.x0, slot.x1, z0, depth)
		"chung_cu":
			_chung_cu(parent, slot.x0, slot.x1, z0, depth)
		"tiem_xe":
			_tiem_xe(parent, slot.x0, slot.x1, z0, depth)
		"khe_hong":
			ThuSau.build_khe(parent, slot.x0, slot.x1, z0 + depth, depth)
		"tap_hoa":
			ShopTapHoa.build(parent, slot.x0, slot.x1, z0, depth)


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
	# Bờ rào gạch thấp 0,7 m phía công viên: nhảy lên chạy được (cách C). Gờ xi măng và trụ mỗi 3 m như bản phác.
	var fence := Blocks.solid_box(parent, Vector3(0.3, 0.7, z1 - z0), Vector3(x0 - 0.15, 0.35, (z0 + z1) / 2.0), BRICK, Blocks.LAYER_PROP)
	fence.add_to_group("hem42_fence")
	Blocks.box(parent, Vector3(0.36, 0.05, z1 - z0), Vector3(x0 - 0.15, 0.725, (z0 + z1) / 2.0), CAP)
	var zp := z0 + 1.0
	while zp < z1:
		Blocks.box(parent, Vector3(0.34, 0.74, 0.3), Vector3(x0 - 0.15, 0.37, zp), BRICK.darkened(0.12))
		zp += 3.0
	# Tường khối 5 phía đông, hở một đoạn ở hẻm giữa khối 5
	var segs := [Vector2(z0, HEM42_GAP_Z.x), Vector2(HEM42_GAP_Z.y, z1)]
	var heights := [4.5, 3.8]
	for i in segs.size():
		var s: Vector2 = segs[i]
		var wall := Blocks.solid_box(parent, Vector3(-14.0 - x1, heights[i], s.y - s.x), Vector3((x1 - 14.0) / 2.0, heights[i] / 2.0, (s.x + s.y) / 2.0), WALL)
		wall.add_to_group("hem42_wall")
		Blocks.box(parent, Vector3(0.08, 0.1, s.y - s.x), Vector3(x1 - 0.02, heights[i] - 0.05, (s.x + s.y) / 2.0), CAP)
		# Mấy ô cửa sổ song sắt nhìn ra hẻm
		var z := s.x + 1.5
		while z < s.y - 1.0:
			Blocks.box(parent, Vector3(0.06, 0.8, 0.9), Vector3(x1 + 0.03, 2.6, z), IRON)
			z += 2.6
	# Cổng hẻm: hai trụ, bảng tên ngang trên cao như bản phác
	for gx in [x0 - 0.15, x1 + 0.12]:
		Blocks.solid_box(parent, Vector3(0.24, 3.6, 0.24), Vector3(gx, 1.8, z0), Color("#CFC3A8"), Blocks.LAYER_PROP)
	Blocks.box(parent, Vector3(x1 - x0 + 0.6, 0.6, 0.2), Vector3((x0 + x1) / 2.0, 3.6, z0), Color("#2E7C80"))
	Blocks.label(parent, "HẺM 42", Vector3((x0 + x1) / 2.0, 3.6, z0 - 0.15), 48, Color("#FFF8EA"))
	# Nhà Bà Sáu (42/7) chặn cuối hẻm, quay mặt về phía bắc. G7: nhà giữ mặt tiền z 26,6, cổng dời ra z 22,0
	var gate_z := z1 + 0.4
	var house_x1 := (x0 + x1) / 2.0 + 3.0       # cổng ở giữa mặt nhà rộng 6 m
	var house := PhoModels.put(parent, "nha_ba_sau", Vector3(house_x1, 0, BA_SAU_FRONT), PI)
	house.mesh = PhoModels.mesh_cut_front("nha_ba_sau", 1.9)  # hàng rào cũ đúc liền model (cách mặt tiền 2 m) nay nằm giữa sân
	Blocks.collider(parent, Vector3(6.0, 6.5, 3.6), Vector3(house_x1 - 3.0, 3.25, 28.4))
	Blocks.solid_box(parent, Vector3(-14.0 - house_x1, 4.0, 30.0 - z1), Vector3((house_x1 - 14.0) / 2.0, 2.0, (z1 + 30.0) / 2.0), WALL)  # tường giữa nhà Bà Sáu và khối 5
	_ba_sau_yard(parent, gate_z)
	gian_bong_giay(parent)
	# Xe ba gác sát tường khối 5, đầu xe quay ra đầu hẻm: gầm thùng 0,32 m, Bơ chui được, Chó Mực thì không (cách A)
	_ba_gac(parent, Vector3(-17.72, 0, 12.5), PI / 2.0)
	# Ổ chó bằng thùng gỗ sát bờ rào, cửa ổ quay ra lòng hẻm, chừa chỗ nằm (-18, 15) trước cửa ổ
	var kennel := Blocks.collider(parent, Vector3(0.9, 0.8, 1.0), Vector3(-19.45, 0.4, 14.0), Blocks.LAYER_PROP)
	kennel.add_to_group("o_cho")
	PhoModels.put(kennel, "o_cho", Vector3(0, -0.4, 0), PI / 2.0)
	Blocks.box(parent, Vector3(1.0, 0.04, 0.8), Vector3(-18.1, 0.05, 15.0), Color("#C8412F"))  # tấm bao bố chỗ Mực nằm
	# Thùng xốp chồng hai tầng
	for k in 2:
		var foam := Blocks.collider(parent, Vector3(0.6, 0.5, 0.45), Vector3(-19.4, 0.25 + k * 0.5, 18.6), Blocks.LAYER_PROP)
		PhoModels.put(foam, "thung_xop", Vector3(0, -0.25, 0), 0.0, Vector3(0.6 / 0.72, 0.5 / 0.42, 0.45 / 0.48))
	_pot(parent, Vector3(-17.35, 0, 19.3))
	_pot(parent, Vector3(-17.35, 0, 19.9))


## Sân gạch nhà Bà Sáu (G7): rào gạch hồng 0,8 m + lan can sắt, cổng 2,5 m mở (cổng xếp gập bên phải),
## bậc thềm, lu nước, chậu kiểng dọc tường trái, ghế mây. Bàn cỗ, bàn thờ của ngày giỗ do ThuSau đặt thêm.
static func _ba_sau_yard(parent: Node3D, gate_z: float) -> void:
	var y := BA_SAU_YARD
	for ix in 3:
		for iz in 2:
			PhoModels.put(parent, GIO % "san_gach", Vector3(y.position.x + 1.0 + ix * 2.0, 0.03, y.position.y + 1.15 + iz * 2.3), 0.0, Vector3(2.0 / 2.1, 1, 2.3 / 2.1))
	var gx0 := GIAN_POS.x - BA_SAU_GATE_W / 2.0
	var gx1 := GIAN_POS.x + BA_SAU_GATE_W / 2.0
	_yard_fence(parent, Vector3(y.position.x, 0, gate_z), Vector3(gx0, 0, gate_z))
	_yard_fence(parent, Vector3(gx1, 0, gate_z), Vector3(y.end.x, 0, gate_z))
	_yard_fence(parent, Vector3(y.position.x + 0.1, 0, gate_z), Vector3(y.position.x + 0.1, 0, BA_SAU_FRONT))
	for gx in [gx0 - 0.05, gx1 + 0.05]:
		Blocks.solid_box(parent, Vector3(0.3, 2.0, 0.3), Vector3(gx, 1.0, gate_z), PINK, Blocks.LAYER_PROP)
	# Cổng xếp sắt gập sát trụ phải
	Blocks.solid_box(parent, Vector3(0.22, 1.9, 0.12), Vector3(gx1 - 0.2, 0.95, gate_z + 0.12), IRON, Blocks.LAYER_PROP)
	Blocks.label(parent, "42/7", Vector3(gx0 - 0.8, 1.2, gate_z - 0.13), 40, Color("#2E4A8A"))
	# Bậc thềm trước cửa nhà
	PhoModels.put(parent, GIO % "bac_them", Vector3(GIAN_POS.x, 0, BA_SAU_FRONT - 0.17), PI)
	Blocks.collider(parent, Vector3(2.1, 0.165, 0.345), Vector3(GIAN_POS.x, 0.0825, BA_SAU_FRONT - 0.17), Blocks.LAYER_PROP)
	# Lu nước, nắp gỗ, gáo dừa; chậu kiểng dọc tường trái
	var lu := Blocks.collider(parent, Vector3(0.62, 0.85, 0.62), BA_SAU_LU + Vector3(0, 0.425, 0), Blocks.LAYER_PROP)
	PhoModels.put(lu, GIO % "lu_nuoc", Vector3(0, -0.425, 0))
	PhoModels.put(lu, GIO % "nap_lu", Vector3(0, 0.425, 0))
	PhoModels.put(lu, GIO % "gao_dua", Vector3(0.05, 0.495, 0.02), 0.6)
	for pos in BA_SAU_POTS:
		_pot(parent, pos)
	# Ghế mây Bà Sáu
	Blocks.solid_box(parent, Vector3(0.6, 0.5, 0.6), BA_SAU_CHAIR + Vector3(0, 0.25, 0), Color("#C9A06A"), Blocks.LAYER_PROP)
	Blocks.box(parent, Vector3(0.6, 0.6, 0.1), BA_SAU_CHAIR + Vector3(0, 0.8, 0.28), Color("#C9A06A"))  # lưng ghế


## Một đoạn rào sân: tường gạch hồng 0,8 m, gờ trắng, lan can sắt 0,8 m (va chạm cao 1,7 m).
static func _yard_fence(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var mid := (a + b) / 2.0
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var length := absf(b.x - a.x) if along_x else absf(b.z - a.z)
	var size := func(l: float, h: float, t: float) -> Vector3: return Vector3(l, h, t) if along_x else Vector3(t, h, l)
	Blocks.solid_box(parent, size.call(length, 0.8, 0.2), mid + Vector3(0, 0.4, 0), PINK, Blocks.LAYER_PROP)
	Blocks.box(parent, size.call(length + 0.04, 0.1, 0.24), mid + Vector3(0, 0.85, 0), Color("#F4EFE6"))
	Blocks.box(parent, size.call(length, 0.04, 0.04), mid + Vector3(0, 1.66, 0), IRON)
	Blocks.collider(parent, size.call(length, 0.8, 0.2), mid + Vector3(0, 1.3, 0), Blocks.LAYER_PROP)
	var n := int(length / 0.25)
	for k in n:
		var t := (k + 0.5) / n - 0.5
		var off := Vector3(t * length, 0, 0) if along_x else Vector3(0, 0, t * length)
		Blocks.box(parent, Vector3(0.02, 0.76, 0.02), mid + off + Vector3(0, 1.28, 0), IRON)


## Giàn bông giấy G7 trùm lên cổng nhà Bà Sáu: 4 cột tre, thang bậc 30 cm hai bên, mặt trên đứng được
## (ván tre ở x -17,9 nhô vào sân 0,43 m, ngay trên mẹt đầu bàn cỗ). Model soi gương để ván nằm phía đông.
static func gian_bong_giay(parent: Node3D) -> void:
	var c := GIAN_POS
	var w := GIAN_SIZE.x
	var d := GIAN_SIZE.z
	var top := GIAN_SIZE.y
	PhoModels.put(parent, GIO % "gian_bong_giay", c, PI, Vector3(-1, 1, 1))
	PhoModels.put(parent, GIO % "canh_roi", c + Vector3(0, 0.07, -0.25), PI)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Blocks.collider(parent, Vector3(0.08, top + 0.1, 0.08), c + Vector3(sx * w / 2.0, (top + 0.1) / 2.0, sz * d / 2.0), Blocks.LAYER_PROP)
		var h := 0.3
		while h < top - 0.05:
			Blocks.collider(parent, Vector3(0.1, 0.05, d + 0.06), c + Vector3(sx * w / 2.0, h, 0), Blocks.LAYER_PROP)
			h += 0.3
	var deck := Blocks.collider(parent, Vector3(w + 0.1, 0.1, d + 0.1), c + Vector3(0, top + 0.07, 0), Blocks.LAYER_PROP)
	deck.add_to_group("gian_bong_giay")
	Blocks.collider(parent, Vector3(0.3, 0.06, 0.45), Vector3(GIAN_PLANK_X, top + 0.09, c.z + d / 2.0 + 0.22), Blocks.LAYER_PROP)


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
	# Khối 2 (sạp báo): xe ba gác chắn hẻm, dây phơi ngay trên (phải chui hoặc trèo lên sàn xe)
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


## Xe ba gác máy (model ba_gac): thùng 2,1 x 1,36 m, gầm thùng 0,32 m, sàn 0,47 m, thành xe 0,82 m,
## đầu xe máy phía +x của model. Va chạm: sàn, bốn thành, đầu xe; bánh không va chạm để gầm thông.
## rot_y = PI/2: thân xe dọc trục Z, đầu xe về -z.
static func _ba_gac(parent: Node3D, pos: Vector3, rot_y: float) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = Blocks.LAYER_PROP
	b.position = pos
	b.rotation.y = rot_y
	b.add_to_group("ba_gac")
	parent.add_child(b)
	PhoModels.put(b, "ba_gac", Vector3.ZERO)
	for part: Array in [
		[Vector3(2.1, 0.15, 1.36), Vector3(-0.3, 0.395, 0)],     # sàn thùng
		[Vector3(2.1, 0.35, 0.06), Vector3(-0.3, 0.645, 0.65)],  # thành bên
		[Vector3(2.1, 0.35, 0.06), Vector3(-0.3, 0.645, -0.65)],
		[Vector3(0.06, 0.35, 1.36), Vector3(-1.32, 0.645, 0)],   # thành sau
		[Vector3(0.06, 0.63, 1.36), Vector3(0.72, 0.785, 0)],    # thành trước cao
		[Vector3(1.1, 1.0, 0.35), Vector3(1.3, 0.6, 0)],         # đầu xe máy
	]:
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = part[0]
		shape.shape = bs
		shape.position = part[1]
		b.add_child(shape)
	return b


## Ba gác đậu dọc hẻm sát tường phía bắc; khe 1 m còn lại có thùng xốp và chậu cây chặn, dây phơi phía trên.
## Qua được bằng cách chui gầm thùng (0,32 m) hoặc nhảy lên thùng xốp / sàn xe.
static func _ba_gac_across(parent: Node3D, x: float, z_mid: float) -> void:
	_ba_gac(parent, Vector3(x + 0.3, 0, z_mid - 0.5), 0.0)
	var foam := Blocks.collider(parent, Vector3(0.72, 0.42, 0.48), Vector3(x, 0.21, z_mid + 0.45), Blocks.LAYER_PROP)
	PhoModels.put(foam, "thung_xop", Vector3(0, -0.21, 0))
	_pot(parent, Vector3(x, 0, z_mid + 0.95))
	_laundry(parent, x, z_mid)


## Dây phơi ngang hẻm cao 2,4 m, đồ phơi thòng xuống tới 1,4 m: đi bộ qua được, không nhảy qua được.
static func _laundry(parent: Node3D, x: float, z_mid: float) -> void:
	PhoModels.put(parent, "day_phoi_a" if int(absf(x)) % 2 == 0 else "day_phoi_b", Vector3(x, 2.4, z_mid), PI / 2.0)
	for i in 3:
		var sheet := Blocks.collider(parent, Vector3(0.04, 0.9, 0.62), Vector3(x, 1.9, z_mid - 0.75 + i * 0.75), Blocks.LAYER_PROP)
		sheet.add_to_group("day_phoi")


static func _pot(parent: Node3D, pos: Vector3) -> void:
	var p := Blocks.collider(parent, Vector3(0.45, 0.45, 0.45), pos + Vector3(0, 0.225, 0), Blocks.LAYER_PROP)
	PhoModels.put(p, ["chau_bui", "chau_boug", "chau_cau"][int(absf(pos.x * 3.0 + pos.z)) % 3], Vector3(0, -0.225, 0))


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


## Thùng gỗ 0,8 m (model thung_go). pos là giữa đáy thùng.
static func crate(parent: Node3D, pos: Vector3) -> StaticBody3D:
	var b := Blocks.collider(parent, Vector3(0.8, 0.8, 0.8), pos + Vector3(0, 0.4, 0), Blocks.LAYER_PROP)
	PhoModels.put(b, "thung_go", Vector3(0, -0.4, 0), PI / 2.0 * (int(absf(pos.x + pos.z * 3.0 + pos.y * 5.0)) % 4))
	return b


static func _crate_pair(parent: Node3D, pos: Vector3) -> void:
	crate(parent, pos)
	crate(parent, pos + Vector3(0.85, 0, 0))
	crate(parent, pos + Vector3(0.4, 0.8, 0))


## Chồng thùng ba bậc 0,8 / 1,6 / 2,4 m cạnh mái hiên (mái hiên cao 2,96 m). dir = hướng bậc cao dần theo X.
static func _stair(parent: Node3D, pos: Vector3, dir: float) -> void:
	for step in 3:
		for level in step + 1:
			crate(parent, pos + Vector3(dir * step * 0.8, level * 0.8, 0))


## Bàn cờ tướng gỗ thấp và hai ghế đẩu đỏ (công viên). pos là giữa đáy bàn.
static func chess_set(parent: Node3D, pos: Vector3) -> void:
	var t := Blocks.collider(parent, Vector3(0.6, 0.42, 0.6), pos + Vector3(0, 0.21, 0), Blocks.LAYER_PROP)
	PhoModels.put(t, "ban_co", Vector3(0, -0.21, 0))
	for sx in [-0.55, 0.55]:
		var st := Blocks.collider(parent, Vector3(0.3, 0.29, 0.3), pos + Vector3(sx, 0.145, 0), Blocks.LAYER_PROP)
		PhoModels.put(st, "ghe_do", Vector3(0, -0.145, 0))


# ------------------------------------------------------------------ quán cà phê Mây

## Vỉa hè trước quán (khối 5, mặt bắc, z 5..7) kín bàn nhựa thấp 0,45 m và ghế đỏ có khách.
## Bơ chui dưới hàng bàn (gầm 0,41 m) hoặc leo chồng thùng bên hông lên mái hiên rồi nhảy xuống trước quầy.
static func cafe(parent: Node3D) -> void:
	var z := 6.0
	var x := -6.0
	var i := 0
	while x < 2.7:
		# Mặt bàn va chạm 0,7 x 0,7 dày 4 cm ở 0,41..0,45 m; chân bàn không va chạm
		var t := Blocks.collider(parent, Vector3(0.7, 0.04, 0.7), Vector3(x, 0.43, z), Blocks.LAYER_PROP)
		t.add_to_group("ban_ca_phe")
		PhoModels.put(t, "ban_nhua", Vector3(0, -0.43, 0), 0.0, Vector3(0.7 / 0.6, 0.45 / 0.47, 0.7 / 0.6))
		# Ghế đỏ hai bên bàn (phía đường và phía nhà), vài ghế có khách ngồi
		for side in [-1.0, 1.0]:
			var sz: float = z + side * 0.62
			var stool := Blocks.collider(parent, Vector3(0.3, 0.28, 0.3), Vector3(x, 0.14, sz), Blocks.LAYER_PROP)
			PhoModels.put(stool, "ghe_do" if (i + int(side > 0)) % 2 else "ghe_xanh", Vector3(0, -0.14, 0), 0.0, Vector3(1, 0.28 / 0.29, 1))
			if (i + int(side > 0)) % 3 == 0:
				_seated_customer(parent, Vector3(x, 0.28, sz), side)
		x += 1.0
		i += 1
	# Quầy Chị Mây: cao 0,9 m, đặt bánh lên đây
	Blocks.solid_box(parent, Vector3(1.4, 0.9, 0.6), CAFE_COUNTER - Vector3(0, 0.45, 0), Color("#B07C46"), Blocks.LAYER_PROP)
	Blocks.box(parent, Vector3(1.44, 0.04, 0.64), CAFE_COUNTER + Vector3(0, 0.02, 0), Color("#8A5A30"))


## Khách ngồi ghế: thân trên + đùi duỗi về phía bàn. Có va chạm (chân khách chắn đường).
## (Người thật có rig sẽ do thread "Người dân vào game" thay.)
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

## Lò bánh Cô Ba (khối 1, dãy nam, nhìn ra đường lớn). Xe tủ kính bánh mì và Cô Ba do main.gd đặt.
static func _lo_banh(parent: Node3D, x0: float, x1: float, z0: float, depth: float) -> void:
	var w := x1 - x0
	var face_z := z0 + depth
	PhoModels.put_house(parent, "lo_banh", x0, w, 5.2, face_z, true)
	Blocks.collider(parent, Vector3(w - 0.15, 7.0, depth), Vector3((x0 + x1) / 2.0, 3.5, z0 + depth / 2.0)).set_meta("model", "lo_banh")
	awning(parent, w, Vector3((x0 + x1) / 2.0, 2.9, face_z + 0.5), "mai_hien_do", 1.0)
	# Hai đèn lồng dưới mái hiên (tách khỏi model nhà): đèn lồng tiệm nếu người chơi đã mua và đang bày
	var tiem_den := Tiem.shown("den_long_tiem")
	for i in 2:
		var lx := x0 + 0.6 * w / 5.2 if i == 0 else x1 - 0.6 * w / 5.2
		if tiem_den:
			var lamp := Tiem.make("den_long_tiem", 1.4 * i)
			parent.add_child(lamp)
			lamp.position = Vector3(lx, 2.86, face_z + 0.25)
			lamp.scale = Vector3.ONE * 1.8  # cỡ bằng đèn lồng phố cũ (đèn tiệm vẽ cho bếp, nhỏ hơn)
		else:
			PhoModels.put(parent, "den_long", Vector3(lx, 2.45, face_z + 0.25))
	if Tiem.shown("bang_hieu_go"):
		var sign := Tiem.make("bang_hieu_go")
		parent.add_child(sign)
		sign.position = Vector3(x1 - 1.3, 2.3, face_z + 0.02)  # cạnh cửa, dưới bảng lớn và mái hiên


## Cà phê Mây (khối 5, dãy bắc). Quầy ngoài vỉa hè và bàn ghế do cafe() đặt.
static func _cafe_may(parent: Node3D, x0: float, x1: float, z0: float, depth: float) -> void:
	var w := x1 - x0
	PhoModels.put_house(parent, "cafe_may", x0, w, 6.0, z0, false)
	Blocks.collider(parent, Vector3(w - 0.15, 7.0, depth), Vector3((x0 + x1) / 2.0, 3.5, z0 + depth / 2.0))
	if PlayMode.day != "thu_nam":  # Thứ Năm trưa quán Mây cuốn bạt lên, chỗ đó là gác lửng (scripts/thu_nam.gd)
		awning(parent, w, Vector3((x0 + x1) / 2.0, 2.9, z0 - 0.5), "mai_hien_xanh", -1.0)


## Chung cư Hoa Sữa 5 tầng (cao 15 m) cả dãy bắc khối 3. Hành lang chung nhìn ra hẻm giữa khối (phía nam),
## nhô ra hẻm 1 m; hành lang tầng 3 (sàn 6 m) là ban công Bé Na, xe máy đậu ngay dưới để Bơ nhảy lên đón giỏ.
## Mặt đường lớn (phía bắc) là lưng chung cư, vẫn có mái hiên 2,9 m nối với dãy mái hiên.
static func _chung_cu(parent: Node3D, x0: float, x1: float, z0: float, depth: float) -> void:
	var back_z := z0 + depth           # mép hẻm giữa khối
	var front_z := back_z + 1.0        # lan can hành lang (model: y = 0)
	var w := 16.8                      # 4 căn x 4,2 m, thêm tháp cầu thang 2,6 m
	PhoModels.put(parent, "chung_cu", Vector3(x0, 0, front_z))
	Blocks.collider(parent, Vector3(w, 15.0, front_z - 1.6 - z0), Vector3(x0 + w / 2.0, 7.5, (z0 + front_z - 1.6) / 2.0))
	Blocks.collider(parent, Vector3(2.6, 16.0, 8.3 * 0.7), Vector3(x0 + w + 1.3, 8.0, front_z - 8.3 * 0.35))  # tháp cầu thang
	for u in 5:
		Blocks.collider(parent, Vector3(0.3, 15.0, 0.3), Vector3(x0 + u * 4.2, 7.5, front_z))  # cột hành lang
	for f in range(1, 5):
		Blocks.collider(parent, Vector3(w + 0.2, 0.22, 1.8), Vector3(x0 + w / 2.0, f * 3.0 + 0.01, front_z - 0.8))  # sàn hành lang
	awning(parent, x1 - x0, Vector3((x0 + x1) / 2.0, 2.9, z0 - 0.5), "mai_hien_la", -1.0)
	# Xe máy đậu dọc hẻm dưới ban công: bậc nhảy 0,9 m để đón giỏ
	var bike := Blocks.collider(parent, Vector3(1.6, 0.9, 0.5), BE_NA_BIKE + Vector3(0, 0.45, 0), Blocks.LAYER_PROP)
	bike.add_to_group("xe_may_be_na")
	PhoModels.put(bike, "xe_may_do", Vector3(0, -0.45, 0), PI)


## Tiệm sửa xe Anh Hùng: tầng trệt rỗng, mặt tiền mở ra đường phía nam, cửa sau 1,2 m ra hẻm giữa khối 6.
static func _tiem_xe(parent: Node3D, x0: float, x1: float, z0: float, depth: float) -> void:
	var w := x1 - x0
	var cx := (x0 + x1) / 2.0
	var z1 := z0 + depth   # mặt tiền (phía nam)
	var zc := z0 + depth / 2.0
	var ground_h := 3.2
	var h := 7.0
	PhoModels.put_house(parent, "sua_xe", x0, w, 5.5, z1, true)
	# Hai vách hông, các tầng trên
	for sx in [x0 + 0.1, x1 - 0.1]:
		Blocks.collider(parent, Vector3(0.2, ground_h, depth), Vector3(sx, ground_h / 2.0, zc))
	Blocks.collider(parent, Vector3(w - 0.15, h - ground_h, depth), Vector3(cx, (h + ground_h) / 2.0, zc))
	# Tường sau có cửa
	var door_x := SHOP_BACK_DOOR.x
	var door_w := 1.2
	var left_w := door_x - door_w / 2.0 - x0
	var right_w := x1 - (door_x + door_w / 2.0)
	Blocks.collider(parent, Vector3(left_w, ground_h, 0.2), Vector3(x0 + left_w / 2.0, ground_h / 2.0, z0 + 0.1))
	Blocks.collider(parent, Vector3(right_w, ground_h, 0.2), Vector3(x1 - right_w / 2.0, ground_h / 2.0, z0 + 0.1))
	Blocks.collider(parent, Vector3(door_w, ground_h - 2.2, 0.2), Vector3(door_x, 2.2 + (ground_h - 2.2) / 2.0, z0 + 0.1))
	awning(parent, w, Vector3(cx, 2.9, z1 + 0.5), "mai_hien_xanh", 1.0)
	# Đồ trong tiệm, chừa lối đi giữa x 31,4..33,2 từ cửa sau ra mặt tiền
	for bz in [zc - 1.2, zc + 1.8]:
		var bike := Blocks.collider(parent, Vector3(0.5, 0.9, 1.6), Vector3(30.5, 0.45, bz), Blocks.LAYER_PROP)  # xe máy dựng chân chống
		PhoModels.put(bike, "xe_may_xanh" if bz < zc else "xe_may_do", Vector3(0, -0.45, 0), PI / 2.0)
	if PlayMode.day == "thu_sau":
		# Thứ Sáu: lòng tiệm, kệ, cầu nâng, máy nén, lốp là model G6 do ThuSau dựng; kệ chỉ giữ va chạm
		Blocks.collider(parent, Vector3(0.4, 2.0, 1.8), Vector3(x0 + 0.4, 1.0, z0 + 1.6), Blocks.LAYER_PROP)
		return
	Blocks.solid_box(parent, Vector3(0.4, 2.0, 1.8), Vector3(x0 + 0.4, 1.0, z0 + 1.6), WOOD, Blocks.LAYER_PROP)  # kệ đồ nghề
	var lift := Blocks.collider(parent, Vector3(0.9, 0.6, 2.2), Vector3(34.0, 0.3, zc + 1.0), Blocks.LAYER_PROP)  # bàn nâng
	PhoModels.put(lift, "ban_nang", Vector3(0, -0.3, 0), PI / 2.0)
	Blocks.collider(parent, Vector3(0.5, 0.9, 1.6), Vector3(34.0, 1.05, zc + 1.0), Blocks.LAYER_PROP)          # xe trên bàn nâng
	var tyres := Blocks.collider(parent, Vector3(0.6, 0.56, 0.6), Vector3(34.4, 0.28, z0 + 1.0), Blocks.LAYER_PROP)  # chồng lốp
	PhoModels.put(tyres, "lop_xe", Vector3(0, -0.28, 0))
	var comp := Blocks.collider(parent, Vector3(0.45, 0.8, 0.9), Vector3(33.9, 0.4, z0 + 2.3), Blocks.LAYER_PROP)  # máy nén khí
	PhoModels.put(comp, "may_nen", Vector3(0, -0.4, 0), PI / 2.0)
