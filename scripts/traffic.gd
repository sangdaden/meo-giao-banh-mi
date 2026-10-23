extends Node3D
## Giao thông ở hai ngã tư: đèn xanh vàng đỏ, xe máy chạy theo đèn, người đi bộ, xe đẩy hàng rong.
## Xe tông Bơ thì hất Bơ văng khoảng 2 m và Bơ đứng hình 1 giây.
## main.gd chỉ cần một dòng: add_child(preload("res://scripts/traffic.gd").new()) sau khi tạo mèo.
## Xe máy và xe bánh mì là model Blender đã duyệt (assets/models/pho/, luồng "Nhà và đồ phố vào game").
## Người lái và người bán xe đẩy là người qua đường P3 (gói G1). Người đi bộ là người qua đường thật của gói P3 (scripts/nguoi_qua_duong.gd),
## xe buýt tuyến 08 chạy chung đường với xe máy (scripts/xe_buyt.gd).
## Xe và người lái vẽ bằng MultiMesh nên cả phố chỉ tốn vài lệnh vẽ.

signal bike_hit_player(bike_pos: Vector3)  ## luồng âm thanh nghe để phát tiếng phanh, tiếng va
signal honked(bike_pos: Vector3)           ## xe bóp còi khi Bơ đứng chắn đường phía trước

## Tâm hai ngã tư (x, z). Đường ngang z = 0 rộng 10 m, hai đường dọc x = -18 và x = 16 rộng 8 m.
const CROSSINGS := [Vector2(-18, 0), Vector2(16, 0)]
const PHASE_OFFSET := [0.0, 7.0]  ## ngã tư thứ hai lệch pha để hai đèn không đổi cùng lúc
const GREEN_EW := 8.0             ## đèn xanh hướng đông tây (đường lớn) bao nhiêu giây
const GREEN_NS := 6.0             ## đèn xanh hướng bắc nam
const YELLOW := 2.0
const ALL_RED := 1.0              ## cả hai hướng cùng đỏ cho xe trong ngã tư chạy hết
const CYCLE := GREEN_EW + YELLOW + ALL_RED + GREEN_NS + YELLOW + ALL_RED
enum Light { GREEN, YELLOW, RED }

## Đường chạy của xe (x, z). Xe chạy bên phải: đi về đông ở làn z = 2,5, về tây ở làn z = -2,5;
## đường dọc làn x = tâm + 2 đi lên bắc, x = tâm - 2 đi xuống nam.
## Đường dọc x = -18 phía nam là hẻm 42 của Chó Mực nên xe chỉ vào ra từ phía bắc rồi rẽ phải.
## Tuyến kéo dài ra vành phố (VanhPho, gói P1): xe sinh ra và biến mất ở các ngã ba khuất ngoài vành
## (đường vành z = ±83, x = 100, đường bờ kênh x = −64,5), chạy qua cầu kênh phía tây, không còn chui ra từ mép bản đồ.
const ROUTES := [
	{"pts": [Vector2(-63.5, 70), Vector2(-63.5, 2.5), Vector2(99, 2.5), Vector2(99, 22)], "bikes": 4, "market_bikes": 2},
	{"pts": [Vector2(99, -22), Vector2(99, -2.5), Vector2(-63.5, -2.5), Vector2(-63.5, -70)], "bikes": 3, "market_bikes": 1},
	{"pts": [Vector2(30, 82), Vector2(18, 82), Vector2(18, -82), Vector2(30, -82)], "bikes": 3},
	{"pts": [Vector2(-30, -82), Vector2(14, -82), Vector2(14, 84), Vector2(30, 84)], "bikes": 3},
	{"pts": [Vector2(-30, -82), Vector2(-20, -82), Vector2(-20, -2.5), Vector2(-63.5, -2.5), Vector2(-63.5, -70)], "bikes": 2},
	{"pts": [Vector2(99, -22), Vector2(99, -2.5), Vector2(-16, -2.5), Vector2(-16, -84), Vector2(-30, -84)], "bikes": 2},
]
## Xe ở xa ngoài vành (|x| > FAR_X hoặc |z| > FAR_Z) chạy nhanh gấp FAR_SPEEDUP: tuyến dài gấp đôi mà vẫn giữ
## số xe (và tam giác) như cũ, mật độ xe trong vùng chơi không đổi.
const FAR_X := 62.0
const FAR_Z := 42.0
const FAR_SPEEDUP := 3.0
## Xe xa camera hơn chừng này thì thôi vẽ (sương và khoảng cách làm xe chỉ còn vài điểm ảnh)
const BIKE_DRAW_RANGE := 65.0
const CORNER_RADIUS := 3.0
## Vạch dừng: xe đông tây dừng cách tâm 5,6 m; xe bắc nam dừng trước vạch qua đường (z = ±6,5).
const STOP_EW := Vector2(5.6, 5.5)
const STOP_NS := Vector2(4.5, 8.6)

const BIKE_LENGTH := 1.6
const MIN_GAP := 1.0          ## khoảng hở tối thiểu với xe phía trước khi dừng
const ACCEL := 4.0
const BRAKE := 6.0            ## phanh êm khi thấy đèn đỏ hay xe trước
const BRAKE_MAX := 10.0       ## phanh gấp: không kịp dừng êm khi đèn vàng thì chạy luôn
const HIT_STRENGTH := 12.0    ## với trọng lực của Bơ, hất văng khoảng 2 m
const HIT_STUN := 1.0
const HONK_RANGE := 7.0
const PASS_RANGE := 9.0       ## xe chạy ngang trong tầm này thì nghe tiếng xe vụt qua
const IDLE_RANGE := 14.0      ## xe đứng chờ đèn đỏ trong tầm này thì nghe tiếng máy nổ

const BIKE_GLB := "res://assets/models/pho/xe_may_son.glb"   ## mặt "son" là màu sơn, tô riêng từng xe
const CART_GLB := "res://assets/models/pho/xe_banh_mi_day.glb"  ## xe đẩy chi tiết Sang duyệt 21/10
## Xa hơn chừng này xe đẩy chỉ còn vài điểm ảnh: thôi vẽ (5k tam giác mỗi xe, tính cả bóng)
const CART_VIEW_RANGE := 40.0
const CART_WHEEL_R := 0.33
const CART_PAINTS := [Color("#C8412F"), Color("#2F8F86")]  ## xe thứ hai sơn xanh ngọc
const PAINTS := [Color("#C8412F"), Color("#3D5A80"), Color("#E8C98A"), Color("#2E2E2E"), Color("#F2F0EA"), Color("#7FB7A4")]
## Người lái (gói G1, model P3 bản đám đông ~570 tam giác, đúc sẵn một khung clip): [model, clip]
const RIDERS := [["qd_sinhvien_xe_dong", "lai_xe"], ["qd_giaohang_dong", "lai_xe"], ["qd_mehoa_dong", "lai_xe"]]
const PILLION := ["qd_hocsinh_xe_dong", "ngoi_sau"]  ## học sinh ngồi sau, khoảng 1/4 số xe
const PILLION_AT := Vector3(0, 0.02, 0.4)            ## sau lưng người lái (đầu xe về -Z)
const LAMP_COLORS := [Color("#35D46A"), Color("#FFC22E"), Color("#FF3B2F")]

## Xe hàng rong chặn hẻm theo lịch (Thứ Ba, chợ bật bằng enable_alley_blocks): đẩy từ vỉa hè vào miệng hẻm,
## quay ngang chắn kín hẻm 2,4 m (thùng xe cao 1,5 m, Bơ nhảy không tới), đứng bán một lúc rồi đẩy ra.
## path: điểm chờ trên vỉa hè -> trước miệng hẻm -> chỗ chắn. rect: lòng hẻm bị chắn (x, z, cỡ).
const ALLEY_BLOCKS := [
	{"name": "hem_khoi_3", "label": "Bắp nướng", "color": Color("#D7A9C4"),
		"path": [Vector3(21.1, 0, -10.5), Vector3(21.1, 0, -15.05), Vector3(22.9, 0, -15.05)],
		"rect": Rect2(22.0, -16.7, 2.0, 2.4), "stay": 12.0, "away": 5.0, "speed": 0.9, "offset": 4.0},
]


class Route:
	var pts: PackedVector3Array
	var lens: PackedFloat32Array  ## quãng đường cộng dồn tới từng điểm
	var length := 0.0
	var stops: Array = []         ## [{s, crossing, ew}] theo thứ tự trên đường


class Bike:
	var route: Route
	var s := 0.0
	var seg := 0
	var speed := 0.0
	var cruise := 7.0
	var pos := Vector3.ZERO
	var dir := Vector3.FORWARD
	var lean := 0.0
	var active := true
	var holding := false          ## đã quyết dừng ở vạch (đèn vàng còn xa), giữ tới khi đèn xanh
	var honk_cd := 0.0
	var pass_cd := 0.0
	var prev_xf := Transform3D()
	var xf := Transform3D()
	var paint := Color.WHITE
	var rider := 0                ## chỉ số RIDERS
	var pillion := false
	var front := BIKE_LENGTH * 0.5  ## từ pos tới mũi xe và tới đuôi xe (xe buýt: pos ở mũi, dài 8,4 m về sau)
	var back := BIKE_LENGTH * 0.5
	var bus := false
	var rest := 0.0               ## xe buýt nghỉ ngoài vành giữa hai chuyến


class Walker:
	var a: Vector3
	var b: Vector3
	var t := 0.0                  ## 0..1 dọc đoạn a-b
	var forward := true
	var speed := 1.3
	var phase := 0.0
	var pause := 0.0
	var prev_xf := Transform3D()
	var xf := Transform3D()


var player: CharacterBody3D
var hud: Node
var _t := 0.0
var _routes: Array[Route] = []
var _bikes: Array[Bike] = []
var bus: XeBuyt                  ## xe buýt tuyến 08 (scripts/xe_buyt.gd), null ngày chợ
var passers: NguoiQuaDuong       ## người qua đường P3 (scripts/nguoi_qua_duong.gd)
## Người qua đường đang ở dưới lòng đường (NguoiQuaDuong cập nhật mỗi nhịp): xe máy, xe buýt phanh nhường
var peds: PackedVector3Array = []
var _carts: Array = []            ## [{body, walker}]
## Vùng xe máy phải chạy chậm (chợ tạm Thứ Ba): [{rect: Rect2, speed: float}]
var slow_zones: Array = []
## Hẻm đang bị xe hàng rong chặn: [{name, rect, blocked}]; luồng giao bánh, mũi tên đọc để biết đường nào kẹt.
var blocked_alleys: Array = []
var _alley_carts: Array = []      ## [{body, def, t, pts}]
var _hit_cd := 0.0
var _honk_label: Label3D
var _honk_time := 0.0

var _mm_paint: MultiMesh
var _mm_bike_shadow: MultiMesh
var _mm_dark: MultiMesh
var _mm_riders: Array[MultiMesh] = []
var _mm_pillion: MultiMesh
var _mm_lamps: MultiMesh
var _heads: Array = []            ## [{crossing, ew, xf}] từng cột đèn

var _crossed := 0                 ## số lượt xe qua vạch dừng (để autotest kiểm tra)
var _red_runs := 0                ## số lần xe vượt đèn đỏ: phải luôn bằng 0
var _autotest := false
var _idle_on := false


func _ready() -> void:
	name = "GiaoThong"
	var main := get_parent()
	player = main.get("player")
	hud = main.get("hud")
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_build_lights()
	slow_zones.append({"rect": VanhPho.MARKET_SLOW, "speed": 2.5})  # chợ ngoài đầu đường x = −18 phía bắc
	_build_routes(rng)
	_build_bus()
	_build_carts(rng)
	passers = NguoiQuaDuong.new()
	passers.traffic = self
	passers.player = player
	add_child(passers)
	_honk_label = Blocks.label(self, "Bíp bíp!", Vector3.ZERO, 40, Color("#FFF2B8"))
	_honk_label.visible = false
	_update_lamps()
	_draw(1.0)


# ---------------------------------------------------------------- đèn giao thông

## Trạng thái đèn của một hướng ở một ngã tư.
func light(crossing: int, ew: bool) -> int:
	var c := fposmod(_t + PHASE_OFFSET[crossing], CYCLE)
	var a := c if ew else fposmod(c - (GREEN_EW + YELLOW + ALL_RED), CYCLE)
	var g := GREEN_EW if ew else GREEN_NS
	if a < g:
		return Light.GREEN
	if a < g + YELLOW:
		return Light.YELLOW
	return Light.RED


func _build_lights() -> void:
	var still := Node3D.new()
	still.name = "CotDen"
	add_child(still)
	for i in CROSSINGS.size():
		var c: Vector2 = CROSSINGS[i]
		# Mỗi hướng xe tới có một cột đèn ở góc bên phải trước ngã tư, mặt đèn quay về phía xe tới.
		var approaches := [
			{"corner": Vector2(c.x - 4.3, 5.3), "face": Vector3.LEFT, "ew": true},     # xe về đông
			{"corner": Vector2(c.x + 4.3, -5.3), "face": Vector3.RIGHT, "ew": true},   # xe về tây
			{"corner": Vector2(c.x - 4.3, -5.3), "face": Vector3.FORWARD, "ew": false},  # xe xuống nam
			{"corner": Vector2(c.x + 4.3, 5.3), "face": Vector3.BACK, "ew": false},    # xe lên bắc
		]
		for ap in approaches:
			var base := Vector3(ap.corner.x, 0, ap.corner.y)
			Blocks.solid_box(still, Vector3(0.14, 3.0, 0.14), base + Vector3(0, 1.5, 0), Color("#4A5654"), Blocks.LAYER_PROP)
			var face: Vector3 = ap.face
			var head := base + Vector3(0, 3.1, 0) + face * 0.12
			var housing := Blocks.box(still, Vector3(0.34, 0.95, 0.24), head, Color("#2A302F"))
			housing.basis = Basis.looking_at(-face)
			_heads.append({"crossing": i, "ew": ap.ew, "pos": head + face * 0.13, "face": face})
		# Vạch dừng trắng trên đường
		Blocks.box(still, Vector3(0.3, 0.02, 4.6), Vector3(c.x - STOP_EW.x + 0.5, 0.012, 2.5), Color("#FFF8EA"))
		Blocks.box(still, Vector3(0.3, 0.02, 4.6), Vector3(c.x + STOP_EW.x - 0.5, 0.012, -2.5), Color("#FFF8EA"))
	Blocks.merge_static(still)

	var lamp := SphereMesh.new()
	lamp.radius = 0.1
	lamp.height = 0.2
	lamp.radial_segments = 8
	lamp.rings = 4
	_mm_lamps = _multimesh(lamp, _heads.size() * 3, true, true)
	for h in _heads.size():
		var hd: Dictionary = _heads[h]
		for k in 3:
			_mm_lamps.set_instance_transform(h * 3 + k, Transform3D(Basis(), hd.pos + Vector3(0, 0.3 - k * 0.3, 0)))


func _update_lamps() -> void:
	for h in _heads.size():
		var hd: Dictionary = _heads[h]
		var st := light(hd.crossing, hd.ew)
		# Thứ tự trên cột: đỏ, vàng, xanh
		var lit := [st == Light.RED, st == Light.YELLOW, st == Light.GREEN]
		var cols := [LAMP_COLORS[2], LAMP_COLORS[1], LAMP_COLORS[0]]
		for k in 3:
			var col: Color = cols[k] if lit[k] else cols[k].darkened(0.82)
			_mm_lamps.set_instance_color(h * 3 + k, col)


# ---------------------------------------------------------------- xe máy

func _build_routes(rng: RandomNumberGenerator) -> void:
	for def in ROUTES:
		var r := Route.new()
		r.pts = _rounded(def.pts)
		r.lens.append(0.0)
		for i in range(1, r.pts.size()):
			r.lens.append(r.lens[i - 1] + r.pts[i].distance_to(r.pts[i - 1]))
		r.length = r.lens[-1]
		r.stops = _find_stops(r)
		_routes.append(r)
		# Ngày chợ sáng (Thứ Ba) chợ chiếm đường lớn nên ít xe chạy dọc đường hơn (cũng giữ ngân sách web)
		var n: int = def.get("market_bikes", def.bikes) if Market.is_market_day() else def.bikes
		for k in n:
			var b := Bike.new()
			b.route = r
			b.cruise = rng.randf_range(6.0, 8.5)
			b.speed = 0.0  # mới vào game xe đứng yên, có xe đang sát vạch lúc đèn đỏ cũng kịp dừng
			b.s = r.length * (k + rng.randf_range(0.1, 0.6)) / n
			_place(b)
			b.prev_xf = b.xf
			_bikes.append(b)

	# Model xe dài theo trục +X, đầu xe ở +X: xoay 90° cho đầu xe về -Z như hướng chạy
	var parts := _glb_parts(BIKE_GLB, Basis(Vector3.UP, PI / 2), ["son"])
	# Thân xe chi tiết (1,4k tam giác) không đổ bóng; bóng xe là hộp thấp (_mm_bike_shadow) cho nhẹ lượt bóng đổ
	var no_shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm_paint = _multimesh(parts[0], _bikes.size(), true, false, no_shadow)
	_mm_dark = _multimesh(parts[1], _bikes.size(), false, false, no_shadow)
	var proxy := BoxMesh.new()
	proxy.size = Vector3(0.3, 0.75, 1.6)
	_mm_bike_shadow = _multimesh(_offset_mesh(proxy, Vector3(0, 0.45, 0)), _bikes.size(), false, false,
		GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	# Người lái: model quay mặt +Z, xoay 180° theo đầu xe
	var face := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	for r in RIDERS:
		_mm_riders.append(_multimesh(_xf_mesh(Nguoi.bake_pose(r[0], r[1]), face), _bikes.size(), false))
	_mm_pillion = _multimesh(_xf_mesh(Nguoi.bake_pose(PILLION[0], PILLION[1]), face.translated(PILLION_AT)), _bikes.size(), false)
	for b in _bikes:
		b.paint = PAINTS[rng.randi() % PAINTS.size()]
		b.rider = rng.randi() % RIDERS.size()
		b.pillion = rng.randf() < 0.25 and b.rider != 1  # anh giao hàng chở thùng, không chở ai


## Xe buýt tuyến 08 và trạm (gói P3). Ngày chợ chợ chiếm đường lớn nên xe buýt không chạy, trạm vẫn đứng đó.
func _build_bus() -> void:
	XeBuyt.build_stop(self)
	if Market.is_market_day():
		return
	var r := Route.new()
	r.pts = _rounded(XeBuyt.ROUTE)
	r.lens.append(0.0)
	for i in range(1, r.pts.size()):
		r.lens.append(r.lens[i - 1] + r.pts[i].distance_to(r.pts[i - 1]))
	r.length = r.lens[-1]
	r.stops = _find_stops(r)
	var b := Bike.new()
	b.route = r
	b.bus = true
	b.cruise = XeBuyt.CRUISE
	b.front = 0.1
	b.back = XeBuyt.LENGTH
	b.active = false
	b.rest = 6.0  # chuyến đầu chạy ra từ đường vành sau vài giây
	_bikes.append(b)
	bus = XeBuyt.new()
	add_child(bus)
	bus.setup(self, b)
	_place(b)
	b.prev_xf = b.xf


## Bo tròn các góc rẽ cho xe ôm cua, trả về điểm 3D trên mặt đường.
func _rounded(pts: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.append(Vector3(pts[0].x, 0, pts[0].y))
	for i in range(1, pts.size() - 1):
		var p: Vector2 = pts[i]
		var d_in: Vector2 = (p - pts[i - 1]).normalized()
		var d_out: Vector2 = (pts[i + 1] - p).normalized()
		var a := p - d_in * CORNER_RADIUS
		var b := p + d_out * CORNER_RADIUS
		for k in 9:
			var t := k / 8.0
			var q := a.lerp(p, t).lerp(p.lerp(b, t), t)  # đường cong Bézier bậc hai
			out.append(Vector3(q.x, 0, q.y))
	out.append(Vector3(pts[-1].x, 0, pts[-1].y))
	return out


## Dò dọc đường xem xe đi vào vùng ngã tư nào, ở quãng đường nào: chỗ đó là vạch dừng.
func _find_stops(r: Route) -> Array:
	var stops := []
	var inside := []
	inside.resize(CROSSINGS.size())
	inside.fill(false)
	var s := 0.0
	var probe := Bike.new()
	probe.route = r
	while s < r.length:
		probe.s = s
		_place(probe)
		var ew := absf(probe.dir.x) > absf(probe.dir.z)
		var box := STOP_EW if ew else STOP_NS
		for i in CROSSINGS.size():
			var c: Vector2 = CROSSINGS[i]
			var now := absf(probe.pos.x - c.x) < box.x and absf(probe.pos.z - c.y) < box.y
			if now and not inside[i]:
				stops.append({"s": s, "crossing": i, "ew": ew})
			inside[i] = now
		s += 0.2
	return stops


## Đặt xe theo quãng đường s: tính vị trí, hướng và tư thế.
func _place(b: Bike) -> void:
	var r := b.route
	if b.s < r.lens[b.seg]:
		b.seg = 0
	while b.seg < r.pts.size() - 2 and b.s > r.lens[b.seg + 1]:
		b.seg += 1
	var a := r.pts[b.seg]
	var c := r.pts[b.seg + 1]
	var seg_len := r.lens[b.seg + 1] - r.lens[b.seg]
	var t := clampf((b.s - r.lens[b.seg]) / seg_len, 0.0, 1.0) if seg_len > 0.0 else 0.0
	var new_dir := (c - a).normalized()
	var turn := b.dir.cross(new_dir).y
	b.dir = new_dir
	b.pos = a.lerp(c, t)
	b.pos.y = VanhPho.road_y(b.pos.x, b.pos.z)  # mặt cầu kênh vồng lên
	b.lean = lerpf(b.lean, clampf(turn * 4.0, -0.35, 0.35), 0.2)
	var basis := Basis.looking_at(b.dir).rotated(b.dir, b.lean)
	b.xf = Transform3D(basis, b.pos)
	if b.bus and bus:
		bus.after_place(b)


func _update_bike(b: Bike, delta: float) -> void:
	b.honk_cd = maxf(b.honk_cd - delta, 0.0)
	b.pass_cd = maxf(b.pass_cd - delta, 0.0)
	if not b.active:
		# Hết đường: chờ ngoài mép bản đồ tới khi đầu đường trống thì chạy lại từ đầu
		if b.rest > 0.0:
			b.rest -= delta
			return
		var start := b.route.pts[0]
		for o in _bikes:
			if o != b and o.active and o.pos.distance_to(start) < BIKE_LENGTH + 4.0 + b.back:
				return
		b.active = true
		if b.bus:
			bus.restart()
		b.s = 0.0
		b.seg = 0
		b.speed = b.cruise
		b.holding = false
		_place(b)
		b.prev_xf = b.xf
		return

	var limit := b.cruise
	if absf(b.pos.x) > FAR_X or absf(b.pos.z) > FAR_Z:
		limit *= FAR_SPEEDUP  # ngoài vành phố khuất tầm nhìn: chạy nhanh cho xe sớm quay lại, phố trong vẫn đông như cũ
	var stop_at := INF  # vạch phải dừng trước (nếu có)
	# Đèn ở ngã tư sắp tới
	for stop in b.route.stops:
		var dist: float = stop.s - b.s
		if dist < 0.0:
			continue
		var st := light(stop.crossing, stop.ew)
		if st == Light.GREEN:
			b.holding = false
		elif st == Light.RED:
			b.holding = true
		elif not b.holding and b.speed * b.speed / (2.0 * maxf(dist, 0.01)) <= BRAKE_MAX:
			b.holding = true  # đèn vàng mà còn kịp phanh thì dừng, không thì chạy qua luôn
		if b.holding:
			limit = minf(limit, sqrt(2.0 * BRAKE * maxf(dist - 0.1, 0.0)))
			stop_at = stop.s
		break
	# Xe phía trước cùng chiều
	for o in _bikes:
		if o == b or not o.active:
			continue
		var rel := o.pos - b.pos
		var ahead := rel.dot(b.dir)
		if ahead <= 0.0 or ahead > 12.0 or o.dir.dot(b.dir) < 0.3:
			continue
		if absf(rel.dot(b.dir.cross(Vector3.UP))) > 1.0:
			continue
		limit = minf(limit, sqrt(2.0 * BRAKE * maxf(ahead - o.back - b.front - MIN_GAP, 0.0)))
	# Người qua đường đang băng qua đường phía trước: phanh nhường
	for p in peds:
		var rel := p - b.pos
		var ahead := rel.dot(b.dir)
		if ahead > 0.0 and ahead < 10.0 and absf(rel.dot(b.dir.cross(Vector3.UP))) < 1.1:
			limit = minf(limit, sqrt(2.0 * BRAKE_MAX * maxf(ahead - b.front - 0.8, 0.0)))
	for z in slow_zones:
		var ahead_pt := b.pos + b.dir * 4.0  # phanh dần trước khi vào chợ
		if z.rect.has_point(Vector2(b.pos.x, b.pos.z)) or z.rect.has_point(Vector2(ahead_pt.x, ahead_pt.z)):
			limit = minf(limit, z.speed)
	if b.bus:
		limit = bus.limit(b, limit, delta)
	var rate := ACCEL if limit > b.speed else BRAKE_MAX
	b.speed = move_toward(b.speed, limit, rate * delta)

	var old_s := b.s
	b.s += b.speed * delta
	if b.s > stop_at - 0.05:
		# Không bao giờ lấn qua vạch khi đã quyết dừng
		b.s = maxf(old_s, stop_at - 0.05)
		b.speed = 0.0
	if b.bus:
		bus.clamp_stop(b)
	for stop in b.route.stops:
		if old_s < stop.s and b.s >= stop.s:
			_crossed += 1
			if light(stop.crossing, stop.ew) == Light.RED:
				_red_runs += 1
	if b.s >= b.route.length:
		b.active = false
		if b.bus:
			b.rest = XeBuyt.GAP
		return
	b.prev_xf = b.xf
	_place(b)
	if not b.bus:
		_check_player(b)  # xe buýt không tông Bơ: dừng và bóp còi (XeBuyt.limit)


## Bơ đứng trên đường xe chạy: xe bóp còi, đụng thì hất Bơ văng ra.
func _check_player(b: Bike) -> void:
	if player == null or b.speed < 1.5:
		return
	var rel := player.global_position - b.pos
	if b.pass_cd <= 0.0 and rel.length() < PASS_RANGE:
		b.pass_cd = 6.0
		_sound_at("moto_pass", b.pos)
	if rel.y > 0.95:
		return  # Bơ nhảy cao hơn yên xe thì xe chạy lọt bên dưới
	var right := b.dir.cross(Vector3.UP)
	var along := rel.dot(b.dir)
	var side := rel.dot(right)
	if absf(side) < 0.7 and along > 1.0 and along < HONK_RANGE and b.honk_cd <= 0.0:
		b.honk_cd = 3.0
		honk(b.pos)
	if _hit_cd > 0.0 or absf(side) > 0.45 or absf(along) > BIKE_LENGTH * 0.5 + 0.2:
		return
	_hit_cd = 1.5
	_sound_at("horn", b.pos)
	var away := right * (signf(side) if absf(side) > 0.05 else 1.0)
	player.knockback(player.global_position - (b.dir + away) * 0.7, float(DoKho.v("hit_strength", HIT_STRENGTH)), float(DoKho.v("hit_stun", HIT_STUN)))
	if player.has_method("bump"):
		player.bump("bike")  # đang ngậm túi trứng thì vỡ một quả
	b.speed *= 0.3
	bike_hit_player.emit(b.pos)
	if hud and hud.has_method("show_toast"):
		hud.show_toast("Xe máy tông Bơ! Nhìn đèn rồi hãy qua đường.", 2.0)


## Bóp còi: chữ "Bíp bíp!" trên đầu xe, tiếng còi, báo cho luồng âm thanh.
func honk(pos: Vector3) -> void:
	_honk_label.position = pos + Vector3.UP * (3.6 if bus and pos.distance_to(bus.bike.pos) < 1.0 else 2.1)
	_honk_label.visible = true
	_honk_time = 0.7
	honked.emit(pos)
	_sound_at("horn", pos)


## Lấy mesh từ file .glb, gộp mọi mảnh về một mesh, xoay theo `turn`.
## Trả về [mesh các mặt có tên trong `split`, mesh các mặt còn lại] để tô màu riêng từng xe.
func _glb_parts(path: String, turn: Basis, split: Array) -> Array:
	var scene: Node = load(path).instantiate()
	var picked := SurfaceTool.new()
	var rest := SurfaceTool.new()
	for st in [picked, rest]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D(turn, Vector3.ZERO) * _local_to(scene, mi)
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			var is_picked := mat != null and mat.resource_name in split
			(picked if is_picked else rest).append_from(mi.mesh, i, xf)
	scene.free()
	return [_srgb(picked.commit()), _srgb(rest.commit())]


func _local_to(root: Node, n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != root and p is Node3D:
		xf = p.transform * xf
		p = p.get_parent()
	return xf


## Bản web (Compatibility) không tự đổi màu đỉnh linear sang sRGB như Forward+ (giống player.gd).
func _srgb(m: ArrayMesh) -> ArrayMesh:
	if RenderingServer.get_rendering_device() != null or m.get_surface_count() == 0:
		return m
	var arrays := m.surface_get_arrays(0)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for k in cols.size():
		cols[k] = cols[k].linear_to_srgb()
	arrays[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Mesh đã đặt sẵn theo xf (người lái đúc từ Nguoi.bake_pose, quay theo đầu xe).
func _xf_mesh(m: ArrayMesh, xf: Transform3D) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(m, 0, xf)
	return st.commit()


func _offset_mesh(m: PrimitiveMesh, pos: Vector3) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(m, 0, Transform3D(Basis(), pos))
	return st.commit()


func _multimesh(m: Mesh, count: int, instance_colors: bool, unshaded := false, shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = instance_colors
	mm.mesh = m
	mm.instance_count = count
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true  # màu theo đỉnh, hoặc màu từng xe nếu có màu riêng
	mat.roughness = 0.8
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = shadow
	add_child(mmi)
	return mm


# ---------------------------------------------------------------- người đi bộ, xe đẩy

func _place_walker(w: Walker, delta: float) -> void:
	var line_len := w.a.distance_to(w.b)
	var moving := w.pause <= 0.0
	if moving:
		w.t += (1.0 if w.forward else -1.0) * w.speed * delta / line_len
		if w.t >= 1.0 or w.t <= 0.0:
			w.t = clampf(w.t, 0.0, 1.0)
			w.forward = not w.forward
			w.pause = 1.0
		w.phase += delta * w.speed * 6.0
	w.pause = maxf(w.pause - delta, 0.0)
	var pos := w.a.lerp(w.b, w.t)
	# Nhường đường cho Bơ: đứng lại khi mèo ở ngay trước mặt
	var fwd := (w.b - w.a).normalized() * (1.0 if w.forward else -1.0)
	if player and moving and (player.global_position - pos).length() < 1.4 and (player.global_position - pos).dot(fwd) > 0.0:
		w.pause = 0.6
	var bob := absf(sin(w.phase)) * 0.04 if moving else 0.0
	w.xf = Transform3D(Basis.looking_at(fwd), pos + Vector3.UP * bob)


## Xe đẩy hàng rong: xe bánh mì chi tiết (bánh xe đạp, tủ kính, lò than), người bán đứng sau tay đẩy.
## Bơ nhảy lên nóc tủ kính được. Model dài theo +X, tay đẩy ở +X: xoay cho tay đẩy ra sau (+Z).
func _build_carts(rng: RandomNumberGenerator) -> void:
	# Vỉa hè khối 3 và khối 6 nhìn ra đường lớn, cách mặt tiền 0,9 m để thùng xe không lấn vào tường.
	# Vỉa hè khối lò bánh và khối 5 đã kín đồ (tủ bánh Cô Ba, bàn ghế cà phê) nên xe không đi ở đó.
	# Hai làn này nằm trong CityProps.KEEP_CLEAR để xe máy đậu không chắn đường xe đẩy.
	var picks := [CityProps.CART_LANES[0], CityProps.CART_LANES[1]]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.7
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.8, 0.93, 0.95, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fire := StandardMaterial3D.new()
	fire.albedo_color = Color("#FF7A2E")
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var src: PackedScene = load(CART_GLB)
	for k in picks.size():
		var w := Walker.new()
		w.a = picks[k][0]
		w.b = picks[k][1]
		w.t = rng.randf_range(0.2, 0.8)
		w.speed = 0.7
		var body := AnimatableBody3D.new()
		body.collision_layer = Blocks.LAYER_PROP
		body.sync_to_physics = true
		body.set_meta("bump_kind", "cart")  # va xe đẩy khi ngậm túi trứng là vỡ một quả
		add_child(body)
		var model: Node3D = src.instantiate()
		model.rotation.y = -PI / 2
		body.add_child(model)
		var wheels: Array[Node3D] = []
		var flame: Node3D
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var n := String(mi.name)
			mi.visibility_range_end = CART_VIEW_RANGE
			if n.begins_with("kinh"):
				mi.material_override = glass
				continue
			if n.begins_with("lua"):
				mi.material_override = fire
				flame = mi
				continue
			mi.mesh = _recolor(_srgb(mi.mesh), CART_PAINTS[0], CART_PAINTS[k % CART_PAINTS.size()])
			mi.material_override = mat
			if n.begins_with("banh_xe"):
				wheels.append(mi)
		# Người bán: người qua đường P3 có xương, clip dắt xe (hai tay trước, bước đi) sau tay đẩy (G1)
		var seller := Nguoi.make(["qd_mehoa", "qd_giaohang"][k % 2], "dat_xe")
		seller.position = Vector3(0, 0, 1.32)
		seller.rotation.y = PI
		body.add_child(seller)
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.72, 1.38, 1.54)
		shape.shape = bs
		shape.position.y = 0.69
		body.add_child(shape)
		_place_walker(w, 0.0)
		body.global_transform = w.xf
		_carts.append({"body": body, "walker": w, "wheels": wheels, "flame": flame, "seller": seller, "walking": true})


## Đổi màu sơn đã nướng vào màu đỉnh (xe thứ hai sơn khác màu).
func _recolor(m: ArrayMesh, from: Color, to: Color) -> ArrayMesh:
	if from == to:
		return m
	var arrays := m.surface_get_arrays(0)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var lin := RenderingServer.get_rendering_device() != null  # Forward+ giữ màu linear
	var f := from.srgb_to_linear() if lin else from
	var t := to.srgb_to_linear() if lin else to
	for i in cols.size():
		var c := cols[i]
		if absf(c.r - f.r) + absf(c.g - f.g) + absf(c.b - f.b) < 0.06:
			cols[i] = Color(t.r, t.g, t.b, c.a)
	arrays[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Xe bắp nướng của Chú Sáu chặn hẻm (model xe_day + tủ kính xe_day_kinh, Sang duyệt 21/10).
## Thân xe (body) nhìn về -Z cục bộ; xe dài 1,73 m kể cả tay đẩy nằm dọc trục Z, tay đẩy ở phía sau (+Z).
## Lúc chắn hẻm: một chồng thúng ở đầu xe và người bán đứng sau tay đẩy che kín hai khe, cả cụm dài 2,3 m.
## Va chạm cao 1,4 m (nóc tủ kính) nên Bơ không nhảy qua được, phải đi vòng.
func _make_alley_cart(title: String, _col: Color) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.collision_layer = Blocks.LAYER_PROP
	body.sync_to_physics = true
	body.set_meta("bump_kind", "cart")  # player.gd: chạy húc xe thì phát bumped("cart")
	add_child(body)
	# Model: dài theo X (tay đẩy ở +X), tâm thân xe ở (0,375; 0,25) theo XZ của model.
	# Xoay -90° quanh Y để trục X của model thành +Z của thân; dời cho tâm xe nằm ở z = -0,45.
	var turn := Basis(Vector3.UP, -PI / 2.0)
	var cart := Market.put(body, "xe_day", Vector3(0.25, 0, -0.825))
	cart.basis = turn
	var glass := MeshInstance3D.new()
	glass.mesh = Market.cho_mesh("xe_day_kinh")
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(1, 1, 1, 0.45)
	gm.roughness = 0.1
	glass.material_override = gm
	glass.basis = turn
	glass.position = Vector3(0.0, 0.92, -0.6)
	body.add_child(glass)
	for k in 2:  # chồng thúng ở đầu xe
		Market.put(body, "thung", Vector3(0, k * 0.19, -1.45), k * 0.9)
	Market.put(body, "ro_rau", Vector3(0, 0.38, -1.45))
	# Chú Sáu đứng sau tay đẩy, nhìn về đầu xe (model người nhìn +Z nên xoay nửa vòng)
	var seller := Nguoi.make("hangrong", "quat_than")
	seller.ban = "nhe"
	seller.position = Vector3(0, 0, 0.62)
	seller.rotation.y = PI
	seller.look_target = player
	body.add_child(seller)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.8, 1.4, 2.3)
	shape.shape = bs
	shape.position = Vector3(0, 0.7, -0.45)
	body.add_child(shape)
	var board := Blocks.label(body, title, Vector3(0, 2.8, -0.45), 36, Color("#FFF8EA"))
	board.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	return body


# ---------------------------------------------------------------- xe hàng rong chặn hẻm (Thứ Ba)

## Bật các xe hàng rong chặn hẻm theo lịch ALLEY_BLOCKS. scripts/market.gd gọi vào ngày có chợ.
func enable_alley_blocks() -> void:
	if not _alley_carts.is_empty():
		return
	for def in ALLEY_BLOCKS:
		var body := _make_alley_cart(def.label, def.color)
		var c := {"body": body, "def": def, "t": def.offset, "pts": PackedVector3Array(def.path)}
		_alley_carts.append(c)
		blocked_alleys.append({"name": def.name, "rect": def.rect, "blocked": false})
		_place_alley_cart(c)


## Lịch một vòng: đẩy vào (đi hết path) -> đứng chắn "stay" giây -> đẩy ra -> vắng "away" giây.
func _place_alley_cart(c: Dictionary) -> void:
	var def: Dictionary = c.def
	var pts: PackedVector3Array = c.pts
	var path_len := 0.0
	for i in range(1, pts.size()):
		path_len += pts[i].distance_to(pts[i - 1])
	var travel := path_len / float(def.speed)
	var cycle: float = travel * 2.0 + def.stay + def.away
	var t := fposmod(c.t, cycle)
	var d := 0.0  # quãng đã đẩy vào tính từ điểm chờ
	if t < travel:
		d = t * def.speed
	elif t < travel + def.stay:
		d = path_len
	elif t < travel * 2.0 + def.stay:
		d = path_len - (t - travel - def.stay) * def.speed
	var pos := pts[0]
	var dir := (pts[1] - pts[0]).normalized()
	var left := d
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		dir = (pts[i] - pts[i - 1]).normalized()
		if left <= seg or i == pts.size() - 1:
			pos = pts[i - 1].lerp(pts[i], clampf(left / seg, 0.0, 1.0))
			break
		left -= seg
	# Trên vỉa hè xe đi dọc đường; vào tới miệng hẻm thì xoay ngang cho thân xe chắn hết bề rộng hẻm
	var across := clampf((d - (path_len - pts[-1].distance_to(pts[-2]))) / pts[-1].distance_to(pts[-2]), 0.0, 1.0)
	var yaw := lerp_angle(atan2(-dir.x, -dir.z), 0.0, across)
	c.body.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	# Đang đẩy thì cúi đẩy xe, đứng chắn hẻm hay chờ ngoài đường thì phe phẩy nón quạt
	var seller: Nguoi = c.body.get_node_or_null("Nguoi_hangrong")
	if seller and not seller.busy():
		var pushing: bool = t < travel or (t >= travel + def.stay and t < travel * 2.0 + def.stay)
		seller.play("day_xe" if pushing else "quat_than")
	for a in blocked_alleys:
		if a.name == def.name:
			a.blocked = d > path_len - 0.4


# ---------------------------------------------------------------- âm thanh

## Tiếng xe do luồng âm thanh làm (Sound.play_at có từ PR âm thanh); chưa có thì im lặng.
func _sound_at(sound_name: String, pos: Vector3) -> void:
	if Sound.has_method("play_at"):
		Sound.call("play_at", sound_name, pos)


## Có xe đứng chờ đèn đỏ gần Bơ thì nghe tiếng máy nổ rì rì.
func _idle_sound() -> void:
	var near := false
	if player:
		for b in _bikes:
			if b.active and b.speed < 0.5 and b.pos.distance_to(player.global_position) < IDLE_RANGE:
				near = true
				break
	if near == _idle_on or not Sound.has_method("play_at"):
		return
	_idle_on = near
	if near:
		Sound.loop("moto_idle")
	else:
		Sound.stop_loop("moto_idle")


func _exit_tree_sound() -> void:
	if _idle_on:
		Sound.stop_loop("moto_idle")


# ---------------------------------------------------------------- vòng lặp

func _physics_process(delta: float) -> void:
	_t += delta
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	for b in _bikes:
		_update_bike(b, delta)
	if bus:
		bus.sync()
	for c in _carts:
		var w: Walker = c.walker
		var before := w.t
		_place_walker(w, delta)
		c.body.global_transform = w.xf
		# Bánh xe đạp lăn theo quãng đường xe đi, lửa lò than nhấp nháy
		var spin := absf(w.t - before) * w.a.distance_to(w.b) / CART_WHEEL_R
		for wh: Node3D in c.wheels:
			wh.rotate_object_local(Vector3.BACK, spin)
		if c.flame:
			c.flame.scale.y = 0.8 + 0.4 * absf(sin(_t * 9.0 + c.body.position.x))
		var walking := w.pause <= 0.0
		if walking != c.walking and c.seller.anim:
			c.walking = walking
			c.seller.play("dat_xe" if walking else "dung_yen")
	for c in _alley_carts:
		c.t += delta
		_place_alley_cart(c)
	_update_lamps()
	_idle_sound()
	if _honk_time > 0.0:
		_honk_time -= delta
		_honk_label.visible = _honk_time > 0.0


func _process(_delta: float) -> void:
	_draw(Engine.get_physics_interpolation_fraction())


## Vẽ xe và người ở giữa hai nhịp vật lý cho mượt trên màn hình tần số cao.
func _draw(f: float) -> void:
	# Chỉ vẽ xe trong vành phố và gần camera (BIKE_DRAW_RANGE): xếp các xe đó lên đầu MultiMesh rồi cắt
	# visible_instance_count, xe ở xa tít đầu kia vành không tốn tam giác (cả lượt bóng đổ).
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var n := 0
	var rn := [0, 0, 0]
	var pn := 0
	for b in _bikes:
		var xf := b.prev_xf.interpolate_with(b.xf, f)
		var in_ring := absf(xf.origin.x) < 108.0 and absf(xf.origin.z) < 92.0
		if b.bus or not b.active or not in_ring:
			continue
		if cam and cam.global_position.distance_to(xf.origin) > BIKE_DRAW_RANGE:
			continue
		_mm_paint.set_instance_transform(n, xf)
		_mm_dark.set_instance_transform(n, xf)
		_mm_bike_shadow.set_instance_transform(n, xf)
		_mm_paint.set_instance_color(n, b.paint)
		_mm_riders[b.rider].set_instance_transform(rn[b.rider], xf)
		rn[b.rider] += 1
		if b.pillion:
			_mm_pillion.set_instance_transform(pn, xf)
			pn += 1
		n += 1
	for mm in [_mm_paint, _mm_dark, _mm_bike_shadow]:
		mm.visible_instance_count = n
	for k in _mm_riders.size():
		_mm_riders[k].visible_instance_count = rn[k]
	_mm_pillion.visible_instance_count = pn
	if bus:
		bus.draw(f, cam)


func _exit_tree() -> void:
	_exit_tree_sound()
	if _autotest or OS.has_feature("traffic_log"):
		print("[autotest] giao thông: %d lượt xe qua vạch dừng, %d lần vượt đèn đỏ" % [_crossed, _red_runs])
		if _red_runs > 0:
			push_error("Xe máy vượt đèn đỏ %d lần" % _red_runs)
