class_name SanThuong
extends Node3D
## Đường sân thượng Thứ Tư (gói việc thiet-ke-man/goi-viec-thu-tu.md), bản khối tạm tới khi có model G5.
## Dãy nhà phía nam của khối 1 → 2 → 3 (dãy nhìn ra đường lớn). Độ cao mái đo lúc chạy từ hộp va chạm nhà
## City dựng, nên nhà đổi model thì đường tự khớp theo.
## - Bậc mái: hai nhà lệch mái thì có cầu thang sắt (va chạm là dốc 36°, nhìn là bậc) dựa tường nhà cao,
##   đặt trên mái nhà thấp, chạy dọc chiều sâu nhà. Xuống chỗ lệch hơn 3,9 m thì nhảy xuống đoạn cuối (≤ 1,6 m).
## - Qua đường: ván gỗ rộng 0,25 m dài 2 m (đi thăng bằng, ThangBang) + giàn sắt bắc ngang đường có lan can.
## - Lên: chồng thùng cạnh lò → mái hiên khối 1 → cầu thang sắt trên mái hiên → mái lò → mái khối 1.
## - Xuống: cầu thang sắt gấp khúc ở dải vỉa hè đầu khối 2 (sau tạp hóa Cô Hai) và đầu khối 3 (hẻm Bé Na).
## - Cổng chào bắc qua đường lớn ngang mái hiên (2,96 m): lối khô sang đầu hẻm 42 (đơn 4, Chú Năm).
## Dấu chân vàng vẽ dọc lối đi; routes[...] là các điểm đi lần lượt (bài thử tests/test_thu_tu.gd đi theo).

const STEEL := Color("#4A4E4F")
const STEEL_DARK := Color("#34383A")
const WOOD := Color("#9A6B3F")
const GANTRY := Color("#6F7A7C")
const PAW := Color("#F2C14E")

const SLOPE := deg_to_rad(36.0)      ## dốc cầu thang (CharacterBody3D đi được tới 45°)
const RAMP_W := 1.1                  ## bề ngang cầu thang trên mái
const RAMP_FOOT_Z := -8.0            ## chân cầu thang trên mái: phía mặt tiền (mái từ z -14,3 tới -7)
const RAMP_MAX_RISE := 3.9           ## cao nhất một cầu thang lên được (dài 5,4 m, vừa chiều sâu nhà)
const ROW_Z := Vector2(-14.3, -7.0)  ## dãy nhà phía nam khối 1–3
const CROSS_Z := -10.6               ## đường ván qua hai ngã đường dọc
const PLANK_LEN := 2.0
const PLANK_W := 0.25                ## ván thật 0,25 m (phác thảo G2); va chạm Thong thả rộng hơn cho dễ đứng
const PLANK_THICK := 0.04
const GANTRY_W := 0.9
const FLIGHT_RISE := 3.6             ## mỗi đợt cầu thang gấp khúc cao nhất 3,6 m
const FLIGHT_W := 0.95
const AWNING_TOP := 2.96             ## mặt mái hiên (CityProps.awning)
## Cổng chào bắc qua đường lớn: x giữa, bề ngang; mép bắc nối mái hiên khối 1, mép nam xuống dốc tới đầu hẻm 42
const ARCH_X := -23.75
const ARCH_W := 0.9
const ARCH_Z := Vector2(-6.9, 7.15)

## Ván đang có: [{xf: Transform3D (gốc ở giữa mặt ván, trục X dọc ván), len, w}] (ThangBang đọc)
var planks: Array = []
## Lối đi theo đơn: "co_hai" (đơn 2), "be_na" (đơn 3), "chu_nam" (đơn 4); mỗi lối là các điểm nối tiếp
var routes := {}
## Chuồng bồ câu trên mái (BoCau đậu quanh đây)
var coop := Vector3.ZERO
## Mái từng khối: [[x0, x1, cao]] từ tây sang đông
var roofs: Array = []

var _paws: Array[Transform3D] = []
var _easy := true


## Dựng đường sân thượng sau City.build. Gọi trước khi Bơ vào cảnh.
func build(city_root: Node3D) -> void:
	name = "SanThuong"
	_easy = not DoKho.hard()
	roofs = _scan_roofs(city_root)
	if roofs.size() < 3 or roofs[0].size() < 2 or roofs[1].size() < 2 or roofs[2].is_empty():
		push_warning("SanThuong: không tìm thấy đủ mái nhà ba khối")
		return
	var main_line: Array = []
	# Lên: chồng thùng cạnh lò (thùng cao nhất 2,4 m) → mái hiên → cầu thang trên mái hiên → mái nhà kế cuối khối 1
	var b1: Array = roofs[0]
	var last: Array = b1[b1.size() - 1]
	var entry: Array = b1[b1.size() - 2]
	var crate_top_x := ARCH_X - ARCH_W / 2.0 - 0.4 - 0.4  # thùng trên cùng nằm ngay tây cổng chào
	CityProps._stair(self, Vector3(crate_top_x - 1.6, 0, -5.6), 1.0)
	var r0_top := Vector3(entry[1] + 0.1, entry[2], -6.5)
	var r0_len: float = (entry[2] - AWNING_TOP) / tan(deg_to_rad(40.0))
	var r0_foot := Vector3(r0_top.x + r0_len, AWNING_TOP, -6.5)
	_ramp(r0_foot, r0_top, 0.9)
	_rails_along(r0_foot, r0_top, 0.9, [-1.0])  # phía đường; phía kia là mặt tiền
	_flat(Vector3(r0_top.x - 0.5, entry[2], -6.8), Vector3(1.0, 0, 1.6))  # chiếu nghỉ, chồm lên mái nhà
	main_line.append_array([Vector3(crate_top_x, 2.4, -5.6), Vector3(crate_top_x, AWNING_TOP, -6.5), r0_foot, r0_top,
		Vector3(r0_top.x - 0.5, entry[2], -7.3)])
	# Khối 1 → 2 → 3 trên mái
	var houses1: Array = b1.slice(b1.size() - 2)
	_walk_block(houses1, main_line)
	_crossing(last, roofs[1][0], main_line)
	var b2: Array = roofs[1]
	_walk_block(b2, main_line)
	# Đơn 2: xuống cầu thang gấp khúc dải vỉa hè đầu đông khối 2, vào hẻm giữa tới cửa sau tạp hóa
	var co_hai: Array = main_line.duplicate()
	var b2_last: Array = b2[b2.size() - 1]
	_switchback(b2_last[1], 1.0, b2_last[2], co_hai)
	co_hai.append_array([Vector3(b2_last[1] + 1.55, 0, -15.2), Vector3(9.0, 0, -15.2)])
	routes["co_hai"] = co_hai
	# Đơn 3: qua đường x = 16 sang mái khối 3, xuống cầu thang dải vỉa hè đầu tây khối 3, vào hẻm Bé Na
	var be_na: Array = main_line.duplicate()
	var c1: Array = roofs[2][0]
	_crossing(b2_last, c1, be_na)
	be_na.append(Vector3(c1[0] + 0.4, c1[2], -13.6))
	_switchback(c1[0], -1.0, c1[2], be_na)
	be_na.append_array([Vector3(c1[0] - 1.55, 0, -15.0), Vector3(c1[0] + 0.6, 0, -15.0)])
	routes["be_na"] = be_na
	# Đơn 4: mái hiên khối 1 → cổng chào qua đường lớn → dốc xuống đầu hẻm 42
	routes["chu_nam"] = _arch(crate_top_x)
	# Chuồng bồ câu: giữa mái thấp nhất khối 2 (đơn 3 đi ngang)
	var low: Array = b2[0]
	for h in b2:
		if h[2] < low[2]:
			low = h
	coop = Vector3((low[0] + low[1]) / 2.0, low[2], -11.6)
	_coop(coop)
	for key in routes:
		_paw_trail(routes[key])
	_draw_paws()
	Blocks.merge_static(self)


# ---------------------------------------------------------------- đo mái

## Hộp va chạm nhà dãy nam khối 1–3 (cao trên 4 m, chân ở đất), xếp theo x. Trả [[khối1], [khối2], [khối3]].
static func _scan_roofs(root: Node3D) -> Array:
	var out := [[], [], []]
	for n in root.get_children():
		var body := n as StaticBody3D
		if body == null or body.get_child_count() == 0:
			continue
		var cs := body.get_child(0) as CollisionShape3D
		if cs == null or not cs.shape is BoxShape3D:
			continue
		var s: Vector3 = (cs.shape as BoxShape3D).size
		var p: Vector3 = body.position + cs.position
		if s.x > 12.0 or p.y + s.y / 2.0 < 4.0 or p.y - s.y / 2.0 > 4.0:
			continue  # chỉ thân nhà (có thể chừa tầng trệt rỗng), bỏ vách mỏng, cột, tường bao
		if absf(p.z - s.z / 2.0 - ROW_Z.x) > 0.1 or absf(p.z + s.z / 2.0 - ROW_Z.y) > 0.1:
			continue
		var b := 0 if p.x < -22.0 else (1 if p.x < 12.0 else 2)
		out[b].append([p.x - s.x / 2.0, p.x + s.x / 2.0, p.y + s.y / 2.0])
	for row: Array in out:
		row.sort_custom(func(a, c): return a[0] < c[0])
	return out


# ---------------------------------------------------------------- lối đi trên mái

## Đi từ nhà đầu tới nhà cuối của một khối, thêm cầu thang chỗ hai mái lệch nhau.
func _walk_block(houses: Array, line: Array) -> void:
	for i in houses.size() - 1:
		var a: Array = houses[i]
		var b: Array = houses[i + 1]
		var wall: float = (a[1] + b[0]) / 2.0
		var dh: float = b[2] - a[2]
		if absf(dh) < 0.25:
			continue
		if dh > 0.0:
			# Lên: cầu thang trên mái nhà a, dựa tường nhà b
			var rise := minf(dh, RAMP_MAX_RISE)
			var xc: float = wall - 0.2 - RAMP_W / 2.0
			var foot := Vector3(xc, a[2], RAMP_FOOT_Z)
			var top := Vector3(xc, a[2] + rise, RAMP_FOOT_Z - rise / tan(SLOPE))
			_ramp(foot, top, RAMP_W)
			_flat(Vector3(wall - 0.1, top.y, top.z - 0.45), Vector3(RAMP_W + 1.3, 0, 0.9))
			line.append_array([Vector3(xc, a[2], RAMP_FOOT_Z + 0.5), foot, top, Vector3(wall + 0.7, b[2], top.z - 0.35)])
		else:
			# Xuống: cầu thang trên mái nhà b, đoạn cuối lệch quá 3,9 m thì nhảy xuống chiếu nghỉ
			var rise := minf(-dh, RAMP_MAX_RISE)
			var xc: float = wall + 0.2 + RAMP_W / 2.0
			var foot := Vector3(xc, b[2], RAMP_FOOT_Z)
			var top := Vector3(xc, b[2] + rise, RAMP_FOOT_Z - rise / tan(SLOPE))
			_ramp(foot, top, RAMP_W)
			_flat(Vector3(wall + 0.25, top.y, top.z - 0.45), Vector3(RAMP_W + 1.1, 0, 0.9))
			line.append_array([Vector3(wall - 0.5, a[2], top.z - 0.35), Vector3(xc, top.y, top.z - 0.35), top, foot,
				Vector3(xc, b[2], RAMP_FOOT_Z + 0.5)])


## Qua đường dọc giữa hai khối: ván, giàn sắt (dốc theo độ cao hai mái), ván.
func _crossing(west: Array, east: Array, line: Array) -> void:
	var xw: float = west[1]
	var xe: float = east[0]
	var hw: float = west[2]
	var he: float = east[2]
	line.append(Vector3(xw - 0.6, hw, CROSS_Z))
	_plank(Vector3(xw - 0.3, hw, CROSS_Z), Vector3(xw + PLANK_LEN, hw, CROSS_Z))
	var g0 := Vector3(xw + PLANK_LEN, hw, CROSS_Z)
	var g1 := Vector3(xe - PLANK_LEN, he, CROSS_Z)
	_gantry(g0, g1)
	_plank(Vector3(xe - PLANK_LEN, he, CROSS_Z), Vector3(xe + 0.3, he, CROSS_Z))
	line.append_array([g0 - Vector3(PLANK_LEN, 0, 0), g0, g1, g1 + Vector3(PLANK_LEN, 0, 0), Vector3(xe + 0.6, he, CROSS_Z)])


## Cầu thang sắt gấp khúc trong dải vỉa hè 2,1 m ở đầu khối (giữa nhà cuối và đường dọc).
## side = 1: dải nằm phía đông nhà (x_edge là mép đông mái), -1: phía tây. Đỉnh ở phía bắc (z -14),
## đợt đầu sát tường đi xuống về phía nam, các đợt sau đổi bên. Đi dưới các đợt trên vẫn đủ cao.
func _switchback(x_edge: float, side: float, height: float, line: Array) -> void:
	var n := int(ceil(height / FLIGHT_RISE))
	var rise := height / n
	var lf := rise / tan(deg_to_rad(38.0))
	var x_in := x_edge + side * (0.05 + FLIGHT_W / 2.0)
	var x_out := x_edge + side * (0.15 + FLIGHT_W * 1.5)
	var z_n := -14.0
	var z_s := z_n + lf
	var mid := (x_in + x_out) / 2.0
	var width := absf(x_out - x_in) + FLIGHT_W
	# Chiếu nghỉ trên cùng, chồm lên mép mái
	_flat(Vector3(x_in - side * 0.4, height, z_n - 0.35), Vector3(FLIGHT_W + 0.8, 0, 0.7))
	line.append_array([Vector3(x_in - side * 0.5, height, z_n - 0.35), Vector3(x_in, height, z_n - 0.3)])
	var h := height
	for k in n:
		var x := x_in if k % 2 == 0 else x_out
		var from_z := z_n if k % 2 == 0 else z_s
		var to_z := z_s if k % 2 == 0 else z_n
		var a := Vector3(x, h, from_z)
		var b := Vector3(x, h - rise, to_z)
		_ramp(b, a, FLIGHT_W)
		# Lan can phía hở: đợt sát tường chắn sang làn ngoài, đợt làn ngoài chắn phía đường
		var rail_x := x + side * (FLIGHT_W / 2.0 + 0.03)
		_slope_rail(Vector3(rail_x, b.y, b.z), Vector3(rail_x, a.y, a.z))
		h -= rise
		line.append_array([a, b])
		if k < n - 1:
			# Chiếu nghỉ đổi bên
			var lz := z_s + 0.45 if k % 2 == 0 else z_n - 0.45
			_flat(Vector3(mid, h, lz), Vector3(width, 0, 0.9))
			_rail_wall(Vector3(mid, h, lz + (0.48 if k % 2 == 0 else -0.48)), Vector3(width, 0, 0.06), 1.0)
			line.append(Vector3(x_out if k % 2 == 0 else x_in, h, lz))
	# Xuống tới đất: bước ra, sang làn ngoài rồi đi lên phía bắc dưới các đợt thang
	var end_z := z_s + 0.5 if n % 2 == 1 else z_n - 0.5
	line.append_array([Vector3(x_in, 0, end_z), Vector3(x_out, 0, end_z)])


## Cổng chào bắc qua đường lớn ngang mái hiên khối 1, đầu nam có dốc xuống đầu hẻm 42.
func _arch(crate_top_x: float) -> Array:
	var len_z := ARCH_Z.y - ARCH_Z.x
	var beam := Blocks.solid_box(self, Vector3(ARCH_W, 0.14, len_z), Vector3(ARCH_X, AWNING_TOP - 0.07, (ARCH_Z.x + ARCH_Z.y) / 2.0), Color("#B8412F"))
	beam.name = "CongChao"
	# Mép tây dầm (x -24,2) gối lên mái hiên khối 1 (tới x -24,1). Hai cặp trụ đứng ngoài lối đi.
	for z in [-5.6, 5.7]:
		for sx in [-1.0, 1.0]:
			Blocks.solid_box(self, Vector3(0.3, 4.6, 0.3), Vector3(ARCH_X + sx * 0.65, 2.3, z), Color("#B8412F"), Blocks.LAYER_PROP)
		Blocks.box(self, Vector3(1.6, 0.5, 0.08), Vector3(ARCH_X, 4.35, z), Color("#F2C14E"))
	Blocks.label(self, "KHU PHỐ BÁNH MÌ", Vector3(ARCH_X, 4.7, 0), 36, Color("#F2C14E"))
	_rail_wall(Vector3(ARCH_X - ARCH_W / 2.0 - 0.03, AWNING_TOP, -0.2), Vector3(0.06, 0, len_z - 1.6), 1.0)
	_rail_wall(Vector3(ARCH_X + ARCH_W / 2.0 + 0.03, AWNING_TOP, -0.4), Vector3(0.06, 0, len_z - 2.6), 1.0)
	var top := Vector3(ARCH_X + ARCH_W / 2.0, AWNING_TOP, ARCH_Z.y - 0.45)
	var foot := top + Vector3(AWNING_TOP / tan(SLOPE), -AWNING_TOP, 0)
	_ramp(foot, top, 0.9)
	_rails_along(foot, top, 0.9, [1.0, -1.0])
	return [Vector3(crate_top_x, 2.4, -5.6), Vector3(crate_top_x, AWNING_TOP, -6.5), Vector3(ARCH_X, AWNING_TOP, -6.5),
		Vector3(ARCH_X, AWNING_TOP, top.z), top, foot, foot + Vector3(0.8, 0, 1.2)]


# ---------------------------------------------------------------- khối

## Mặt dốc đi được từ foot (thấp) tới top (cao) theo một trục X hoặc Z; nhìn là bậc thang sắt.
func _ramp(foot: Vector3, top: Vector3, width: float) -> void:
	var d := top - foot
	var horiz := Vector3(d.x, 0, d.z)
	var run := horiz.length()
	var dir := horiz / run
	var length := Vector3(run, d.y, 0).length()
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_WORLD
	add_child(body)
	var basis := Basis.looking_at(-d.normalized(), Vector3.UP)  # trục Z cục bộ dọc dốc
	var thick := 0.2
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# Dài thêm 0,3 m phía chân (chìm vào mặt dưới), đầu trên dừng đúng mép cho khỏi gờ với chiếu nghỉ
	bs.size = Vector3(width, thick, length + 0.3)
	shape.shape = bs
	body.add_child(shape)
	body.transform = Transform3D(basis, (foot + top) / 2.0 - basis.z * 0.15 - basis.y * (thick / 2.0))
	# Bậc: mỗi bậc cao ~0,22 m
	var steps := maxi(2, int(ceil(d.y / 0.22)))
	for k in steps:
		var t := (k + 0.5) / steps
		var p := foot.lerp(top, t)
		var st := Blocks.box(self, Vector3(width, 0.05, run / steps + 0.02) if absf(dir.z) > 0.5 else Vector3(run / steps + 0.02, 0.05, width), p - Vector3(0, 0.03, 0), STEEL)
		st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Hai thanh dầm hai bên
	for s in [-1.0, 1.0]:
		var side: Vector3 = dir.cross(Vector3.UP) * s * (width / 2.0)
		var beam := Blocks.box(self, Vector3(0.05, 0.16, length + 0.1), Vector3.ZERO, STEEL_DARK)
		beam.transform = Transform3D(basis, (foot + top) / 2.0 + side - basis.y * 0.08)


## Lan can hai bên dốc: side 1 = bên phải hướng đi lên, -1 = bên trái.
func _rails_along(foot: Vector3, top: Vector3, width: float, sides: Array) -> void:
	var horiz := Vector3(top.x - foot.x, 0, top.z - foot.z).normalized()
	for s in sides:
		var off: Vector3 = horiz.cross(Vector3.UP) * float(s) * (width / 2.0 + 0.03)
		_slope_rail(foot + off, top + off)


## Lan can theo dốc: va chạm vô hình là các đoạn tường đứng 0,6 m nối bậc (không chồm ra chiếu nghỉ),
## cao 1 m trên mặt dốc; thanh vịn nhìn thấy nghiêng theo dốc ở 0,75 m.
func _slope_rail(foot: Vector3, top: Vector3) -> void:
	var d := top - foot
	var horiz := Vector3(d.x, 0, d.z)
	var run := horiz.length()
	var n := maxi(1, int(ceil(run / 0.6)))
	for k in n:
		var p0 := foot.lerp(top, float(k) / n)
		var p1 := foot.lerp(top, float(k + 1) / n)
		var lo := minf(p0.y, p1.y) - 0.1
		var hi := maxf(p0.y, p1.y) + 1.0
		var c := (p0 + p1) / 2.0
		var seg := Vector3(absf(p1.x - p0.x), 0, absf(p1.z - p0.z))
		Blocks.collider(self, Vector3(maxf(seg.x, 0.06), hi - lo, maxf(seg.z, 0.06)), Vector3(c.x, (lo + hi) / 2.0, c.z))
	var basis := Basis.looking_at(-d.normalized(), Vector3.UP)
	var bar := Blocks.box(self, Vector3(0.04, 0.04, d.length()), Vector3.ZERO, STEEL_DARK)
	bar.transform = Transform3D(basis, (foot + top) / 2.0 + Vector3.UP * 0.75)


## Mặt phẳng đi được (chiếu nghỉ): pos là giữa mặt trên, size.y bỏ qua (dày 0,2 m).
func _flat(top_center: Vector3, size: Vector3) -> void:
	Blocks.solid_box(self, Vector3(size.x, 0.2, size.z), top_center - Vector3(0, 0.1, 0), STEEL)


## Lan can: va chạm vô hình từ base.y cao `height`, có thanh vịn nhìn thấy ở trên cùng.
func _rail_wall(base: Vector3, size: Vector3, height: float) -> void:
	Blocks.collider(self, Vector3(maxf(size.x, 0.06), height, maxf(size.z, 0.06)), base + Vector3(0, height / 2.0, 0))
	Blocks.box(self, Vector3(maxf(size.x, 0.04), 0.04, maxf(size.z, 0.04)), base + Vector3(0, height - 0.25, 0), STEEL_DARK)


## Ván gỗ bắc qua khe: gốc a, ngọn b cùng độ cao. Thong thả có lan can vô hình thấp hai bên cho khỏi rớt.
func _plank(a: Vector3, b: Vector3) -> void:
	var c := (a + b) / 2.0
	var length := a.distance_to(b)
	var w := 0.45 if _easy else 0.3
	var body := Blocks.collider(self, Vector3(length, PLANK_THICK + 0.1, w), c - Vector3(0, (PLANK_THICK + 0.1) / 2.0, 0))
	body.name = "Van"
	Blocks.box(self, Vector3(length, PLANK_THICK, PLANK_W), c - Vector3(0, PLANK_THICK / 2.0, 0), WOOD)
	if _easy:
		for s in [-1.0, 1.0]:
			Blocks.collider(self, Vector3(length - 0.6, 0.6, 0.06), c + Vector3(0, 0.3, s * 0.33))  # mặt trong cách giữa ván 0,3 m (Bơ rộng 0,25)
	planks.append({"xf": Transform3D(Basis.IDENTITY, c), "len": length, "w": PLANK_W})


## Giàn sắt bắc ngang đường (khung biển quảng cáo): mặt đi rộng 0,9 m, lan can hai bên, hai trụ xuống đất.
func _gantry(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var run := Vector3(d.x, 0, d.z).length()
	var length := d.length()
	var basis := Basis.looking_at(-d.normalized(), Vector3.UP)
	var deck := Blocks.solid_box(self, Vector3(GANTRY_W, 0.12, length + 0.1), Vector3.ZERO, GANTRY)
	deck.transform = Transform3D(basis, (a + b) / 2.0 - basis.y * 0.06)
	for s in [-1.0, 1.0]:
		var off := Vector3(0, 0, s * (GANTRY_W / 2.0 + 0.03))
		_slope_rail(a + off, b + off)
	for p in [a, b]:
		Blocks.solid_box(self, Vector3(0.3, p.y, 0.3), Vector3(p.x, p.y / 2.0 - 0.1, p.z + GANTRY_W / 2.0 + 0.3), STEEL_DARK, Blocks.LAYER_PROP)
	# Biển quảng cáo treo dưới giàn
	Blocks.box(self, Vector3(run * 0.7, 1.2, 0.06), (a + b) / 2.0 + Vector3(0, -0.9, GANTRY_W / 2.0 + 0.1), Color("#E8DFC8"))


## Chuồng bồ câu gỗ có cửa (khối tạm; model G5 thay sau).
func _coop(p: Vector3) -> void:
	var body := Blocks.solid_box(self, Vector3(1.2, 0.9, 0.8), p + Vector3(0, 0.75, 0), Color("#B48A5A"), Blocks.LAYER_PROP)
	body.name = "ChuongBoCau"
	for k in 3:
		Blocks.box(self, Vector3(0.2, 0.2, 0.02), p + Vector3(-0.35 + k * 0.35, 0.85, 0.41), Color("#2B2622"))
	Blocks.box(self, Vector3(1.4, 0.06, 1.0), p + Vector3(0, 1.23, 0), Color("#8A5A3A"))
	for x in [-0.5, 0.5]:
		Blocks.box(self, Vector3(0.06, 0.3, 0.06), p + Vector3(x, 0.15, 0), Color("#6A4A2A"))


# ---------------------------------------------------------------- dấu chân

func _paw_trail(pts: Array) -> void:
	var carry := 0.0
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.01 or absf(b.y - a.y) > 0.3 and Vector2(b.x - a.x, b.z - a.z).length() < 0.6:
			continue  # bước nhảy, không vẽ dấu giữa không trung
		var dir := (b - a) / seg
		var yaw := atan2(-dir.x, -dir.z)
		var t := 1.2 - carry
		while t < seg:
			var p := a + dir * t
			_paws.append(Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.035, 0)))
			t += 1.2
		carry = seg - (t - 1.2)


func _draw_paws() -> void:
	if _paws.is_empty():
		return
	var arrow := PrismMesh.new()
	arrow.size = Vector3(0.22, 0.26, 0.02)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Mũi tên nằm phẳng, đỉnh chỉ -Z (hướng đi)
	var lay := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO)
	for xf in _paws:
		st.append_from(arrow, 0, xf * lay)
	var mi := MeshInstance3D.new()
	mi.name = "DauChan"
	mi.mesh = st.commit()
	mi.material_override = Blocks.mat(PAW, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
