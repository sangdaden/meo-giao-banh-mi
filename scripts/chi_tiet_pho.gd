class_name ChiTietPho
## Chi tiết phố P4 (Sang duyệt 22/10, trang https://claude.ai/artifact/XpHkLAnhpsjkHDkmEPLBKu):
## dây điện, cuộn dây rối, cây me, cây dầu, xe máy đậu, thùng rác, bàn thờ Thổ Địa, bình gas, dù cà phê,
## ghế nhựa, gánh hàng rong, biển tên đường, nắp cống, miệng cống, vá đường, ổ gà, cửa sau, cầu thang sắt,
## đồ đạc xếp, chỗ mèo hoang ngủ. Model ở assets/models/pho/chi_tiet/ (một mesh, màu đỉnh, gốc giữa đáy,
## mặt trước nhìn +z). Đồ gắn tường (bảng hiệu, máy lạnh, chậu, số nhà, công tơ) chờ điểm gắn của bộ ráp nhà P2.
##
## Gọi một lần ở cuối City.build. Mỗi món được thử trước khi đặt: nằm trong vùng chơi 96 × 60 m, không chồng
## lên va chạm đã dựng (thùng, cột, xe, mái hiên...), tránh CityProps.KEEP_CLEAR, làn xe đẩy, lối người đi bộ,
## chỗ giao đơn mọi ngày và các chỗ riêng của từng ngày (AVOID). Chỗ nào không đạt thì bỏ món đó.
## Lòng đường chỉ có món phẳng không va chạm (nắp cống, miệng cống, vá đường, ổ gà); còn lại trên vỉa hè hoặc trong hẻm.
##
## Hình tự gộp theo ô (8 m cho đồ thấp, 24 m cho đồ cao; không qua Blocks.merge_static) để đặt tầm nhìn riêng: món mặt đường tắt sau 24 m,
## đồ vỉa hè, hẻm, cuộn dây tắt sau 32 m, dây điện, biển tên đường và cây tắt sau 60 m; có LOD. Không món nào đổ bóng: góc phố nặng nhất đã gần 400k tam giác.

const DIR := "res://assets/models/pho/chi_tiet/"
const CELL := 24.0
const CELL_NEAR := 8.0  ## đồ thấp gộp ô nhỏ để tầm nhìn và cắt ngoài khung hình có tác dụng
const FLAT := 24.0
const NEAR := 32.0
const FAR := 60.0
const GROUP := "chi_tiet_pho"

## Ra/vào mép đường: vỉa hè rộng 2 m giữa mép khối (bó vỉa) và mặt tiền
const WALK := 2.0
## Dây điện: độ cao hai đầu, model dài 6,05 m, võng 1,37 m (hai đầu ở đỉnh model)
const WIRE_H := 6.3
const WIRE_LEN := 6.05
const WIRE_SAG := 1.37
## Cột điện mới để căng dây (model cot_dien có sẵn), cạnh các cột cũ ở góc ngã tư
const NEW_POLES := [Vector3(-13.6, 0, -6.5), Vector3(20.3, 0, -6.0)]
## Nhịp dây: hai đầu là cột (cũ hoặc mới)
const WIRES := [
	[Vector3(-23, 0, -6), Vector3(-13.6, 0, -6.5)],
	[Vector3(3, 0, -6), Vector3(11, 0, -6)],
	[Vector3(11, 0, -6), Vector3(20.3, 0, -6.0)],
	[Vector3(21, 0, 6), Vector3(31, 0, 6)],
]
## Cuộn dây rối trên cột (đáy cuộn cao 4,3 m), quay ổ rối ra đường
const COILS := [Vector3(-23, 0, -6), Vector3(11, 0, -6), Vector3(21, 0, 6)]

## Chỗ của từng ngày dựng sau City.build (không thấy được lúc kiểm va chạm): tâm, bán kính
const AVOID := [
	[Vector3(-33.0, 0, 22.6), 4.5],   # sân khấu Hội mèo (chu_nhat.gd)
	[Vector3(-33.0, 0, 18.0), 3.5],   # chiếu, ghế băng Hội mèo
	[Vector3(-33.0, 0, 5.6), 2.5],    # cổng Hội mèo
	[Vector3(-40.5, 0, 12.0), 2.5],   # chồng thùng Hội mèo
	[Vector3(-36.5, 0, 7.4), 1.5],    # bảng kỷ lục Hội mèo
	[Vector3(-34.0, 0, 17.5), 1.5],   # tổ bồ câu Thứ Bảy
	[Vector3(30.6, 0, -15.6), 2.5],   # võng Chị Thu Thứ Bảy
	[Vector3(-1.5, 0, -6.4), 2.0],    # tủ báo, sạp báo Chú Tư
	[Vector3(31.0, 0, 21.0), 5.5],    # tiệm xe, cầu nâng, khe hông (Thứ Năm, Thứ Sáu)
	[Vector3(7.6, 0, 6.2), 3.5],      # gác lửng quán Mây (Thứ Năm)
	[Vector3(10.8, 0, 5.6), 2.0],     # bậc leo lên gác lửng (ThuNam.LOFT_STEPS), bot thử chạy từ phía đông tới
	[Vector3(40.1, 0, -15.0), 1.5],   # cổng chung cư Thứ Năm
	[Vector3(-24.9, 0, -5.55), 1.2],  # bậc mái che Thứ Năm
	[Vector3(-29.0, 0, 8.5), 2.5],    # góc cờ tướng Thứ Ba
	[Vector3(23.0, 0, -15.5), 2.5],   # xe bắp nướng chắn hẻm khối 3 (Thứ Ba)
	[Vector3(41.0, 0, 28.0), 1.0],    # tem ở góc xa
	[Vector3(-41.0, 0, 28.0), 1.0],
	[Vector3(8.6, 0, -6.35), 1.0],    # Cô Hai đứng trước tạp hóa
	[Vector3(-22.9, 0, 6.4), 1.2],    # Chú Năm ngồi đầu hẻm 42
]

## Màu sơn xe máy (thay màu đỏ gốc của model)
const BIKE_PAINTS := [Color("#C8412F"), Color("#2457A0"), Color("#E9E6DE"), Color("#2A2A2A"), Color("#5E8F6E")]

static var _tools := {}       ## khóa ô -> SurfaceTool
static var _ranges := {}      ## khóa ô -> tầm nhìn
static var _boxes: Array = [] ## AABB va chạm đã có (hệ tọa độ parent)
static var _walk_lines: Array = []
static var _avoid_pts: Array = []
static var skipped: Array = []  ## món bị bỏ vì vướng (tools/thu_chi_tiet_pho.gd in ra)
static var placed := 0


static func build(parent: Node3D) -> void:
	_tools.clear()
	_ranges.clear()
	skipped.clear()
	placed = 0
	_collect_boxes(parent)
	_collect_avoid()
	_overhead(parent)
	_road(parent)
	_sidewalks(parent)
	_alleys(parent)
	_trees(parent)
	_commit(parent)


# ------------------------------------------------------------------ trên cao: cột, dây điện, cuộn dây

static func _overhead(parent: Node3D) -> void:
	for p: Vector3 in NEW_POLES:
		if not _fits(Vector3(0.4, 7.0, 0.4), p, 0.0, "cot_dien"):
			continue
		var pole := Blocks.collider(parent, Vector3(0.25, 7.0, 0.25), p + Vector3(0, 3.5, 0), Blocks.LAYER_PROP)
		pole.name = "CotDien"
		pole.add_to_group(GROUP)
		PhoModels.put(pole, "cot_dien", Vector3(0, -3.5, 0), PI / 2.0)  # như cột cũ: model chung, merge_static gộp
		_boxes.append(AABB(p - Vector3(0.2, 0, 0.2), Vector3(0.4, 7.0, 0.4)))
	for w: Array in WIRES:
		var a: Vector3 = w[0]
		var b: Vector3 = w[1]
		var d := b - a
		var xf := Transform3D(Basis(Vector3.UP, -atan2(d.z, d.x)).scaled(Vector3(d.length() / WIRE_LEN, 1, 1)),
			(a + b) / 2.0 + Vector3(0, WIRE_H - WIRE_SAG, 0))
		_add("day_dien", xf, FAR)
	for c: Vector3 in COILS:
		var out := 1.0 if c.z < 0.0 else -1.0  # ổ rối nhìn ra đường lớn
		_add("cuon_day_roi", Transform3D(Basis(Vector3.UP, 0.0 if out > 0 else PI), c + Vector3(0, 4.3, 0)), NEAR)


# ------------------------------------------------------------------ mặt đường: chỉ món phẳng, không va chạm

static func _road(_parent: Node3D) -> void:
	# Nắp cống giữa làn, lồi 2 cm
	for p in [Vector3(-42, 0, 2.5), Vector3(-30, 0, -2.5), Vector3(-6, 0, 2.5), Vector3(6, 0, -2.5),
			Vector3(28, 0, 2.5), Vector3(40, 0, -2.5), Vector3(-18, 0, -16), Vector3(16, 0, -20),
			Vector3(16, 0, 18), Vector3(-30, 0, -28), Vector3(2, 0, -28), Vector3(-2, 0, 28)]:
		_flat("nap_cong", p, 0.3, -0.03)
	# Miệng cống sát bó vỉa, mặt trước nhìn ra lòng đường
	for x in [-40.0, -28.0, -6.0, 8.0, 28.0, 40.0]:
		_flat("mieng_cong", Vector3(x, 0, -4.75), 0.0, -0.08)
	for x in [-34.0, -8.0, 4.0, 26.0, 40.0]:
		_flat("mieng_cong", Vector3(x, 0, 4.75), PI, -0.08)
	for z in [-12.0, -22.0]:
		_flat("mieng_cong", Vector3(19.75, 0, z), -PI / 2.0, -0.08)
		_flat("mieng_cong", Vector3(-21.75, 0, z), -PI / 2.0, -0.08)
	# Vá đường
	for v in [[Vector3(-36, 0, 1.2), 0.1], [Vector3(-4, 0, -1.5), -0.05], [Vector3(24, 0, 2.0), 0.08],
			[Vector3(36, 0, -2.2), 0.0], [Vector3(-18, 0, -21), PI / 2.0 + 0.1], [Vector3(16, 0, 12), PI / 2.0],
			[Vector3(-20, 0, 28), 0.05], [Vector3(10, 0, -28), -0.1]]:
		_flat("va_duong", v[0], v[1], 0.002)
	# Ổ gà gần mép đường: lún xuống cho miệng ổ ngang mặt đường
	for v in [[Vector3(-10, 0, 3.8), 0.4], [Vector3(34, 0, -3.8), 1.2], [Vector3(13.4, 0, -13), 0.0]]:
		_flat("o_ga", v[0], v[1], -0.06)


static func _flat(model: String, p: Vector3, rot: float, dy: float) -> void:
	if absf(p.x) > City.SIZE.x / 2.0 - 1.0 or absf(p.z) > City.SIZE.y / 2.0 - 1.0:
		skipped.append("%s %s ngoài vùng chơi" % [model, p])
		return
	_add(model, Transform3D(Basis(Vector3.UP, rot), p + Vector3(0, dy, 0)), FLAT)


# ------------------------------------------------------------------ vỉa hè

## Điểm trên vỉa hè của khối i. outer = mặt phố ngoài (mép bản đồ), không thì mặt đường lớn.
## d: cách bó vỉa (mét). Trả [vị trí, góc quay để mặt trước nhìn ra đường, hướng từ bó vỉa vào mặt tiền].
static func _walk(i: int, outer: bool, x: float, d: float) -> Array:
	var r: Rect2 = City.BLOCKS[i]
	var north := r.end.y < 0.0
	var curb: float
	var dir: float
	if north:
		curb = r.position.y if outer else r.end.y
		dir = 1.0 if outer else -1.0
	else:
		curb = r.end.y if outer else r.position.y
		dir = -1.0 if outer else 1.0
	return [Vector3(x, 0, curb + dir * d), 0.0 if dir < 0.0 else PI, dir]


static func _sidewalks(parent: Node3D) -> void:
	# Mặt phố ngoài (không có người đi bộ): hàng xe máy, bàn thờ, bình gas, thùng rác, dù cà phê
	_bike_row(parent, 0, -40.0, 4)
	_bike_row(parent, 1, 1.0, 3)
	_bike_row(parent, 2, 24.0, 4)
	_bike_row(parent, 4, 1.5, 4)
	for v in [[0, -33.5], [1, -4.0], [4, -4.5], [5, 25.0]]:
		_wall_item(parent, "ban_tho_dia", v[0], true, v[1], Vector3(0.72, 0.74, 0.43))
	for v in [[0, -27.5], [1, 4.9], [4, 7.2]]:
		_wall_item(parent, "binh_gas", v[0], true, v[1], Vector3(0.85, 1.12, 0.44))
	for v in [[0, -30.0, true], [1, -8.0, true], [2, 40.5, true], [4, 8.5, true], [0, -39.0, false], [1, -8.0, false], [4, -12.2, false], [5, 24.0, false]]:
		_bin(parent, v[0], v[2], v[1])
	_cafe_set(parent, 2, 34.0)
	_cafe_set(parent, 1, -10.5)
	# Gánh hàng rong sát bó vỉa
	var g := _walk(4, true, -6.5, 0.45)
	_solid(parent, "ganh_hang_rong", g[0], g[1], [[Vector3(-0.62, 0.32, 0), Vector3(0.6, 0.64, 0.6)], [Vector3(0.62, 0.32, 0), Vector3(0.6, 0.64, 0.6)]])
	# Biển tên đường ở góc ngã tư và đầu hẻm 42, cách bó vỉa 0,6 m
	for p in [Vector3(-13.5, 0, -5.4), Vector3(-13.4, 0, 8.0)]:
		_solid(parent, "bien_ten_duong", p, 0.0, [[Vector3(0, 1.5, 0), Vector3(0.12, 3.0, 0.12)]], FAR,
			Color(0, 0, 0, 0), 1.0, Vector3(0.3, 3.0, 0.3))  # bảng tên ở trên cao 2,4 m, chỉ cột chạm đất


## Hàng xe máy đậu xéo 45°, cách nhau 1,3 m, đầu xe (phía +x của model) quay vào nhà, màu sơn khác nhau.
static func _bike_row(parent: Node3D, i: int, x0: float, n: int) -> void:
	var mid := _walk(i, true, x0 + (n - 1) * 0.65, 1.0)
	if not _fits_group(mid[0], Vector3((n - 1) * 1.3 + 1.6, 1.4, 1.9), "hàng %d xe máy" % n):
		return
	for k in n:
		var w := _walk(i, true, x0 + k * 1.3, 1.0)
		var into: float = w[2]
		# đầu xe chỉ vào nhà (hướng dir theo z), xéo 45° về phía +x
		var rot := -atan2(into, 1.0)
		var paint: Color = BIKE_PAINTS[(i * 3 + k) % BIKE_PAINTS.size()]
		_solid(parent, "xe_may_dau", w[0], rot, [[Vector3(0, 0.45, 0), Vector3(1.75, 0.9, 0.45)]], NEAR, paint, 1.0, Vector3.ZERO, false)


## Đồ sát chân tường mặt tiền trên mặt phố ngoài (lưng sát tường).
static func _wall_item(parent: Node3D, model: String, i: int, outer: bool, x: float, size: Vector3) -> void:
	var w := _walk(i, outer, x, WALK - size.z / 2.0 - 0.02)
	_solid(parent, model, w[0], w[1], [[Vector3(0, size.y / 2.0, 0), size]])


static func _bin(parent: Node3D, i: int, outer: bool, x: float) -> void:
	var w := _walk(i, outer, x, 0.5)
	_solid(parent, "thung_rac_xanh", w[0], w[1], [[Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 0.77)]])


## Dù cà phê và 3 ghế nhựa thấp trên mặt phố ngoài. Vỉa hè trong game chỉ 2 m và có mái hiên ở 2,84 m nên
## dù thu nhỏ 0,8 lần (tán 1,9 m, cao 2,25 m) để tán không chìa ra lòng đường, không chạm mái hiên.
static func _cafe_set(parent: Node3D, i: int, x: float) -> void:
	var w := _walk(i, true, x, 1.0)
	var c: Vector3 = w[0]
	var into: float = w[2]
	if not _fits_group(c, Vector3(1.95, 2.3, 1.95), "dù cà phê"):
		return
	_solid(parent, "o_du_cafe", c, w[1], [[Vector3(0, 0.15, 0), Vector3(0.45, 0.3, 0.45)]], NEAR, Color(0, 0, 0, 0), 0.8, Vector3.ZERO, false)
	for s in [Vector3(-0.72, 0, 0.2 * into), Vector3(0.72, 0, -0.15 * into), Vector3(0.1, 0, 0.66 * into)]:
		_solid(parent, "ghe_nhua_thap", c + s, s.x, [[Vector3(0, 0.13, 0), Vector3(0.33, 0.26, 0.33)]], NEAR, Color(0, 0, 0, 0), 1.0, Vector3.ZERO, false)


# ------------------------------------------------------------------ hẻm giữa khối (z ±15,5, rộng 2,4 m)

## Tường sau của hai dãy nhà: dãy phía bắc hẻm ở z_mid - 1,2 (mặt nhìn +z), dãy phía nam ở z_mid + 1,2.
static func _alley_wall(z_mid: float, north_wall: bool, depth: float) -> Array:
	if north_wall:
		return [z_mid - 1.2 + depth / 2.0 + 0.02, 0.0]
	return [z_mid + 1.2 - depth / 2.0 - 0.02, PI]


static func _alleys(parent: Node3D) -> void:
	var zn := -15.5
	var zs := 15.5
	# Cửa sau: khung và bậc va chạm, cánh đóng sát tường
	for v in [[-38.5, zn, true], [-7.5, zn, false], [-2.5, zs, false]]:
		var a := _alley_wall(v[1], v[2], 0.84)
		_solid(parent, "cua_sau", Vector3(v[0], 0, a[0]), a[1], [[Vector3(0, 1.36, -0.32), Vector3(1.5, 2.72, 0.2)], [Vector3(0, 0.06, 0.15), Vector3(1.3, 0.12, 0.5)]])
	# Cầu thang sắt dọc tường hẻm khối 5, lên chiếu nghỉ 3,0 m ở phía đông
	var st := _alley_wall(zs, true, 0.92)
	_stair(parent, Vector3(7.5, 0, st[0]))
	# Đồ đạc xếp ngoài (két nhựa leo được) và chỗ mèo hoang ngủ
	var dd := _alley_wall(zn, true, 0.74)
	_solid(parent, "do_dac_xep", Vector3(5.5, 0, dd[0]), dd[1], [[Vector3(-0.45, 0.42, 0), Vector3(1.0, 0.84, 0.7)], [Vector3(0.55, 0.3, 0), Vector3(0.85, 0.6, 0.7)]])
	var dd2 := _alley_wall(zn, false, 0.74)
	_solid(parent, "do_dac_xep", Vector3(-31.0, 0, dd2[0]), dd2[1], [[Vector3(-0.45, 0.42, 0), Vector3(1.0, 0.84, 0.7)], [Vector3(0.55, 0.3, 0), Vector3(0.85, 0.6, 0.7)]])
	var cm := _alley_wall(zn, false, 0.86)
	_solid(parent, "cho_meo_hoang", Vector3(-25.0, 0, cm[0]), cm[1], [[Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.8)]])


## Cầu thang sắt: 14 bậc cao 0,21 m chạy theo +x, chiếu nghỉ 0,6 m ở đầu +x. Mỗi bậc một hộp va chạm.
static func _stair(parent: Node3D, c: Vector3) -> void:
	var run := (3.49 - 0.6) / 14.0
	var shapes := []
	for k in 14:
		var top := (k + 1) * 0.21
		shapes.append([Vector3(-1.745 + run * (k + 0.5), top - 0.03, 0.05), Vector3(run + 0.02, 0.06, 0.8)])
	shapes.append([Vector3(1.745 - 0.3, 2.97, 0.05), Vector3(0.6, 0.06, 0.8)])
	_solid(parent, "cau_thang_sat", c, 0.0, shapes, NEAR, Color(0, 0, 0, 0), 1.0, Vector3(3.5, 3.0, 0.92))


# ------------------------------------------------------------------ cây lớn (trong công viên, mép không người)

static func _trees(parent: Node3D) -> void:
	for v in [["cay_dau", Vector3(-42.6, 0, 6.8), 0.3], ["cay_me", Vector3(-25.2, 0, 24.4), 1.1], ["cay_me", Vector3(-42.0, 0, 18.5), 2.4]]:
		_solid(parent, v[0], v[1], v[2], [[Vector3(0, 1.5, 0), Vector3(0.6, 3.0, 0.6)]], FAR, Color(0, 0, 0, 0), 1.0, Vector3(0.8, 3.0, 0.8))


# ------------------------------------------------------------------ đặt món, kiểm chỗ, gộp hình

## Đặt một món có va chạm. shapes: [[tâm (hệ model), cỡ hộp]...]. Trả false nếu chỗ vướng.
static func _solid(parent: Node3D, model: String, pos: Vector3, rot: float, shapes: Array, view := NEAR,
		paint := Color(0, 0, 0, 0), scale := 1.0, check_size := Vector3.ZERO, check := true) -> bool:
	var size := check_size
	if size == Vector3.ZERO:
		var bb := PhoModels.mesh(DIR + model + ".glb").get_aabb()
		size = Vector3(bb.size.x, minf(bb.size.y, 2.4), bb.size.z) * scale
	if check and not _fits(size, pos, rot, model):
		return false
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_PROP
	body.position = pos
	body.rotation.y = rot
	body.name = model
	body.add_to_group(GROUP)
	parent.add_child(body)
	for s: Array in shapes:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = s[1] * scale
		cs.shape = box
		cs.position = s[0] * scale
		body.add_child(cs)
	_add(model, Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * scale), pos), view, paint)
	if check:
		var half := _rot_half(size, rot)
		_boxes.append(AABB(pos - Vector3(half.x, 0, half.y), Vector3(half.x * 2.0, size.y, half.y * 2.0)))
	return true


## Thử cả một cụm (hàng xe, bộ dù ghế) như một hộp: center, cỡ (x, cao, z). Đạt thì ghi chỗ đã chiếm.
static func _fits_group(center: Vector3, size: Vector3, what: String) -> bool:
	if not _fits(size, center, 0.0, what):
		return false
	_boxes.append(AABB(center - Vector3(size.x / 2.0, 0, size.z / 2.0), size))
	return true


## Nửa bề ngang/sâu của hộp đã xoay quanh trục đứng (x, z)
static func _rot_half(size: Vector3, rot: float) -> Vector2:
	var c := absf(cos(rot))
	var s := absf(sin(rot))
	return Vector2(size.x * c + size.z * s, size.x * s + size.z * c) / 2.0


static func _fits(size: Vector3, pos: Vector3, rot: float, model: String) -> bool:
	var half := _rot_half(size, rot)
	var why := ""
	if absf(pos.x) + half.x > City.SIZE.x / 2.0 - 0.3 or absf(pos.z) + half.y > City.SIZE.y / 2.0 - 0.3:
		why = "ngoài vùng chơi"
	elif not _on_walk(pos, half):
		why = "ra lòng đường"
	else:
		var p2 := Vector2(pos.x, pos.z)
		var me := Rect2(p2 - half, half * 2.0)
		for r: Rect2 in CityProps.KEEP_CLEAR:
			if r.grow(0.3).intersects(me):
				why = "KEEP_CLEAR %s" % r
		for line: Array in _walk_lines:
			if why == "" and _seg_dist(p2, line[0], line[1]) < 0.45 + minf(half.x, half.y):
				why = "lối người đi bộ"
		for a: Array in _avoid_pts:
			if why == "" and p2.distance_to(a[0]) < a[1] + minf(half.x, half.y):
				why = "gần %s" % a[0]
		var me3 := AABB(pos - Vector3(half.x, 0, half.y), Vector3(half.x * 2.0, size.y, half.y * 2.0)).grow(-0.03)  # sát tường thì được
		for b: AABB in _boxes:
			if why == "" and b.intersects(me3):
				why = "chạm va chạm %s" % b
	if why != "":
		skipped.append("%s %s: %s" % [model, pos, why])
		return false
	return true


## Cả đáy món nằm trên vỉa hè hoặc trong khối nhà (hẻm, công viên), không lấn lòng đường
static func _on_walk(pos: Vector3, half: Vector2) -> bool:
	var me := Rect2(Vector2(pos.x, pos.z) - half, half * 2.0)
	for r: Rect2 in City.BLOCKS:
		if r.encloses(me):
			return true
	return false


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Hộp va chạm đã dựng dưới parent (đổi về hệ tọa độ parent, không cần nằm trong cây cảnh)
static func _collect_boxes(parent: Node3D) -> void:
	_boxes.clear()
	for cs: CollisionShape3D in parent.find_children("*", "CollisionShape3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = cs
		while n != null and n != parent:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var aabb := AABB()
		if cs.shape is BoxShape3D:
			var s: Vector3 = (cs.shape as BoxShape3D).size
			aabb = AABB(-s / 2.0, s)
		elif cs.shape is CylinderShape3D:
			var c := cs.shape as CylinderShape3D
			aabb = AABB(Vector3(-c.radius, -c.height / 2.0, -c.radius), Vector3(c.radius * 2.0, c.height, c.radius * 2.0))
		else:
			continue
		var w := xf * aabb
		if w.size.y < 0.2 and w.position.y < 0.1:
			continue  # mặt đất, vỉa hè
		if w.size.x > 30.0 or w.size.z > 30.0:
			continue  # tường vô hình, mặt đường
		_boxes.append(w)


## Chỗ giao đơn mọi ngày, chỗ đứng của người dân, lối người đi bộ (traffic.gd), làn xe đẩy
static func _collect_avoid() -> void:
	_avoid_pts.clear()
	for a: Array in AVOID:
		_avoid_pts.append([Vector2(a[0].x, a[0].z), a[1]])
	for id: String in Days.DATA:
		for o: Dictionary in (Days.DATA[id] as Dictionary).get("orders", []):
			_avoid_pts.append([Vector2(o.pos.x, o.pos.z), 1.6])
	_avoid_pts.append([Vector2(City.BAKERY_POINT.x, City.BAKERY_POINT.z), 3.0])
	_walk_lines.clear()
	for lane: Array in CityProps.CART_LANES:
		_walk_lines.append([Vector2(lane[0].x, lane[0].z), Vector2(lane[1].x, lane[1].z)])
	# Giống traffic.gd _sidewalk_lines/_build_walkers: các đoạn vỉa hè có người đi bộ
	var lines := []
	for i in City.BLOCKS.size():
		if i == City.PARK_INDEX:
			continue
		var r: Rect2 = City.BLOCKS[i]
		var m := 1.6
		var z_road := r.end.y - m if r.end.y < 0.0 else r.position.y + m
		lines.append([Vector2(r.position.x + m, z_road), Vector2(r.end.x - m, z_road)])
		lines.append([Vector2(r.position.x + m, r.position.y + m), Vector2(r.position.x + m, r.end.y - m)])
		lines.append([Vector2(r.end.x - m, r.position.y + m), Vector2(r.end.x - m, r.end.y - m)])
	for busy in [9, 3, 0]:
		lines.remove_at(busy)
	for k in 10:
		_walk_lines.append(lines[(k * 7) % lines.size()])


static func _add(model: String, xf: Transform3D, view: float, paint := Color(0, 0, 0, 0)) -> void:
	var c := xf.origin
	var cell := CELL if view >= FAR else CELL_NEAR
	var key := "%d:%d:%d" % [floori(c.x / cell), floori(c.z / cell), int(view)]
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
		_ranges[key] = view
	var m: Mesh = PhoModels.mesh(DIR + model + ".glb")
	if paint.a > 0.0:
		m = _repaint(m, paint)
	_tools[key].append_from(m, 0, xf)
	placed += 1


## Đổi màu sơn đỏ gốc của xe máy sang màu khác (màu đỉnh)
static func _repaint(src: Mesh, paint: Color) -> Mesh:
	var arrays := src.surface_get_arrays(0)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var red := BIKE_PAINTS[0]
	var web := RenderingServer.get_rendering_device() == null
	var ref := red if web else red.srgb_to_linear()
	var to := paint if web else paint.srgb_to_linear()
	for k in cols.size():
		var c := cols[k]
		if absf(c.r - ref.r) + absf(c.g - ref.g) + absf(c.b - ref.b) < 0.12:
			cols[k] = to
	arrays[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Mỗi ô một mesh, vật liệu nằm trong mesh (không material_override) nên Blocks.merge_static để nguyên.
static func _commit(parent: Node3D) -> void:
	for key: String in _tools:
		# LOD như Blocks.merge_static: ở xa vẽ ít tam giác hơn
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, _tools[key].commit_to_arrays(), [], {}, PhoModels.material())
		im.generate_lods(25, 60, [])
		var mi := MeshInstance3D.new()
		mi.name = "ChiTietPho"
		mi.mesh = im.get_mesh()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = _ranges[key]
		mi.visibility_range_end_margin = 5.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mi.add_to_group(GROUP)
		parent.add_child(mi)
	_tools.clear()
