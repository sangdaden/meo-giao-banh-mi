class_name XeBuyt
extends Node3D
## Xe buýt tuyến 08 "Lò Bánh – Chợ Cũ" và trạm xe buýt (gói P3 "Người qua đường và xe ra vào", Sang duyệt 22/10).
## traffic.gd chạy xe như một chiếc xe máy dài (Bike.bus = true): cùng đèn giao thông, cùng xếp hàng với xe máy.
## File này lo phần riêng của xe buýt: tấp vào trạm, dừng DWELL giây mở cửa cho khách lên xuống, xi nhan,
## dừng và bóp còi khi Bơ đứng trước mũi (không bao giờ tông), đứng chờ khi Bơ đang đứng trên nóc xe.
##
## Tuyến: sinh ở đường bờ kênh x = −63,5 (khuất), qua cầu kênh, chạy về đông làn z = 2,5, tấp vào trạm, rồi rẽ phải
## ở đường vành x = 99 và khuất. Nghỉ GAP giây ngoài vành rồi chạy chuyến sau. Ngày chợ (Thứ Ba) không chạy.

const GLB := "res://assets/models/pho/xe_buyt.glb"        ## 3.880 tam giác, cửa đóng
const GLB_MO := "res://assets/models/pho/xe_buyt_mo.glb"  ## cửa mở, lộ bậc lên 0,35 m
const TRAM_GLB := "res://assets/models/pho/tram_xe_buyt.glb"
const ROUTE := [Vector2(-63.5, 70), Vector2(-63.5, 2.5), Vector2(99, 2.5), Vector2(99, 22)]
## Tâm trạm trên vỉa hè nam khối 6, mặt quay ra đường (model xoay nửa vòng). Phác thảo đặt ở vỉa hè bắc x = −8
## nhưng cả dải vỉa hè bắc khối 2 đã kín: thùng rác, xe máy đậu (P4), tủ báo Thứ Năm (x −2,3), sạp báo Chú Tư;
## mé công viên là cổng và đồ Hội mèo Chủ Nhật. Ở đây vỉa hè trống giữa thùng rác (x 24) và làn xe đẩy (x 31,3).
const STOP := Vector3(28.0, 0, 6.0)
const LENGTH := 8.4             ## dài cả cản trước sau
const WIDTH := 2.3
const HEIGHT := 3.1
const STOP_FRONT_X := 30.6      ## mũi xe khi dừng: cửa trước x = 29,9, cửa giữa x = 25,85
const DOORS := [0.7, 4.75]      ## khoảng cách từ mũi xe tới giữa cửa trước, cửa giữa
const PULL_IN := 1.35           ## tấp vào trạm: lệch khỏi làn về phía vỉa hè (tâm xe z = 3,85)
const DWELL := 8.0
const DOOR_OPEN := 1.0          ## dừng hẳn 1 s rồi mới mở cửa
const DOOR_CLOSE := 7.0
const GAP := 40.0
const CRUISE := 6.0
const HONK_AHEAD := 9.0
const ROOF_Y := 2.6             ## Bơ cao hơn chừng này trong thân xe là đang đứng trên nóc

signal doors_opened(doors: Array)  ## vị trí bậc cửa (mặt đường, sát thân xe) cho người lên xuống
signal doors_closing

var traffic: Node
var bike  ## Bike của traffic.gd, mũi xe ở bike.pos
var stop_s := 0.0
var phase := "toi"              ## toi: đang tới trạm, dung: đang đỗ, di: đã đón khách xong
var _t := 0.0
var _honk_cd := 0.0
var _blink := 0.0
var _closed: MeshInstance3D
var _open: MeshInstance3D
var _shadow: MeshInstance3D
var _lamps_right: Array[MeshInstance3D] = []
var _lamps_left: Array[MeshInstance3D] = []
var _body: AnimatableBody3D
var _bubble: Label3D
var _bubble_time := 0.0


func _ready() -> void:
	name = "XeBuyt"
	var turn := Basis(Vector3.UP, PI / 2)  # model dài theo +X, đầu xe +X, cửa phía +Z: xoay cho đầu xe về -Z, cửa về +X (bên phải)
	_closed = PhoModels.put(self, GLB, Vector3(0, 0, LENGTH / 2.0))
	_closed.basis = turn
	_open = PhoModels.put(self, GLB_MO, Vector3(0, 0, LENGTH / 2.0))
	_open.basis = turn
	_open.visible = false
	for mi in [_closed, _open]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 90.0
	# Bóng đổ là hộp thấp (12 tam giác) thay cho thân xe 3,9k tam giác ở lượt bóng
	var box := BoxMesh.new()
	box.size = Vector3(WIDTH, HEIGHT - 0.5, LENGTH - 0.2)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = box
	_shadow.position = Vector3(0, 0.5 + (HEIGHT - 0.5) / 2.0, LENGTH / 2.0)
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(_shadow)
	var lamp := SphereMesh.new()
	lamp.radius = 0.09
	lamp.height = 0.18
	lamp.radial_segments = 8
	lamp.rings = 4
	var lit := Blocks.mat(Color("#FFA21F"), true)
	for side in [1.0, -1.0]:
		for z in [0.12, LENGTH - 0.15]:
			var l := MeshInstance3D.new()
			l.mesh = lamp
			l.material_override = lit
			l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			l.position = Vector3(side * (WIDTH / 2.0 + 0.02), 0.85, z)
			l.visible = false
			add_child(l)
			(_lamps_right if side > 0.0 else _lamps_left).append(l)
	_bubble = Blocks.label(self, "Mèo ơi xuống đi, xe sắp chạy rồi!", Vector3(0, HEIGHT + 1.2, LENGTH / 2.0), 34, Color("#FFF8EA"))
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.visible = false

	# Va chạm thân xe: Bơ không chạy xuyên, nhảy lên nóc được (xe đứng chờ Bơ xuống)
	_body = AnimatableBody3D.new()
	_body.collision_layer = Blocks.LAYER_PROP
	_body.sync_to_physics = true
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(WIDTH, HEIGHT, LENGTH - 0.2)
	shape.shape = bs
	shape.position = Vector3(0, HEIGHT / 2.0, LENGTH / 2.0)
	_body.add_child(shape)
	_body.set_meta("bump_kind", "cart")
	add_child.call_deferred(_body)  # thân va chạm đứng riêng, đặt theo xe ở sync()
	_body.top_level = true


## Trạm xe buýt: model 1.746 tam giác, ghế inox cao 0,45 m và mái che 2,6 m có va chạm để Bơ nhảy lên.
static func build_stop(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "TramXeBuyt"
	root.position = STOP
	root.rotation.y = PI  # mặt trạm (phía +z của model) quay ra đường lớn ở phía bắc
	parent.add_child(root)
	var mi := PhoModels.put(root, TRAM_GLB, Vector3.ZERO)
	mi.visibility_range_end = 60.0
	# Bóng đổ: mái, ghế, vách kính mờ là ba hộp thấp thay cho model 1,7k tam giác ở lượt bóng
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for part in [[Vector3(4.3, 0.08, 1.75), Vector3(0.0, 2.6, 0.05)], [Vector3(2.6, 0.05, 0.42), Vector3(0.4, 0.45, -0.35)],
			[Vector3(0.1, 2.55, 0.1), Vector3(2.3, 1.45, 0.8)]]:
		var box := BoxMesh.new()
		box.size = part[0]
		var sh := MeshInstance3D.new()
		sh.mesh = box
		sh.position = part[1]
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		root.add_child(sh)
	# Ghế (mặt ghế 0,45 m), mái (2,56..2,64 m), vách kính sau, hai cột sau, cột biển trạm (tọa độ theo tâm trạm)
	Blocks.collider(root, Vector3(2.6, 0.45, 0.42), Vector3(0.4, 0.225, -0.35), Blocks.LAYER_PROP)
	Blocks.collider(root, Vector3(4.3, 0.08, 1.75), Vector3(0.0, 2.6, 0.05), Blocks.LAYER_PROP)
	Blocks.collider(root, Vector3(3.5, 1.7, 0.06), Vector3(0.2, 1.25, -0.66), Blocks.LAYER_PROP)
	for x in [-1.8, 1.8]:
		Blocks.collider(root, Vector3(0.12, 2.55, 0.12), Vector3(x, 1.28, -0.65), Blocks.LAYER_PROP)
	Blocks.collider(root, Vector3(0.1, 2.9, 0.1), Vector3(2.3, 1.45, 0.8), Blocks.LAYER_PROP)


## Chỗ ngồi chờ trên ghế trạm (mặt ghế 0,45 m) và chỗ đứng chờ, tọa độ thế giới.
static func seats() -> Array:
	return [at(Vector3(-0.45, 0.45, -0.3)), at(Vector3(1.15, 0.45, -0.3))]


static func stands() -> Array:
	return [at(Vector3(-1.5, 0, 0.55)), at(Vector3(1.6, 0, 0.5)), at(Vector3(0.4, 0, 0.6))]


## Điểm theo trục của model trạm (+z là mặt trạm nhìn ra đường) đổi ra tọa độ thế giới.
static func at(local: Vector3) -> Vector3:
	return STOP + Vector3(-local.x, local.y, -local.z)


## Hướng mặt trạm nhìn ra đường (thế giới).
static func facing() -> Vector3:
	return Vector3(0, 0, -1)


## Gắn vào chiếc Bike của traffic.gd: tìm quãng đường mũi xe tới chỗ dừng.
func setup(t: Node, b) -> void:
	traffic = t
	bike = b
	var probe_s := 0.0
	var best := INF
	while probe_s < b.route.length:
		var p: Vector3 = _lane_point(probe_s)
		var d := Vector2(p.x - STOP_FRONT_X, p.z - 2.5).length()
		if d < best:
			best = d
			stop_s = probe_s
		probe_s += 0.1


func _lane_point(s: float) -> Vector3:
	var r = bike.route
	for i in range(1, r.pts.size()):
		if r.lens[i] >= s:
			var seg: float = r.lens[i] - r.lens[i - 1]
			return r.pts[i - 1].lerp(r.pts[i], (s - r.lens[i - 1]) / seg if seg > 0.0 else 0.0)
	return r.pts[-1]


## Chuyến mới bắt đầu ở đầu tuyến.
func restart() -> void:
	phase = "toi"
	_t = 0.0
	_set_doors(false)


## Xe tấp sát vỉa hè quanh trạm: lệch PULL_IN về bên phải làn, vào êm trước trạm, ra êm sau khi đón khách.
func offset_at(s: float) -> float:
	var into := smoothstep(stop_s - 12.0, stop_s - 3.0, s)  # bắt đầu tấp khi đã qua ngã tư x = 16
	var out := smoothstep(stop_s + 1.0, stop_s + 11.0, s)
	return PULL_IN * into * (1.0 - out)


## Đặt lại vị trí sau traffic._place: lệch tấp vào trạm, thân xe không nghiêng như xe máy.
func after_place(b) -> void:
	var right: Vector3 = b.dir.cross(Vector3.UP)
	var off := offset_at(b.s)
	var slope := offset_at(b.s + 0.5) - offset_at(b.s - 0.5)
	b.pos += right * off
	var heading: Vector3 = (b.dir + right * slope).normalized()
	b.lean = 0.0
	b.xf = Transform3D(Basis.looking_at(heading), b.pos)


## Giới hạn tốc độ riêng của xe buýt (gọi trong traffic._update_bike): đỗ trạm, nhường Bơ, chờ Bơ xuống khỏi nóc.
func limit(b, lim: float, delta: float) -> float:
	_honk_cd = maxf(_honk_cd - delta, 0.0)
	_bubble_time = maxf(_bubble_time - delta, 0.0)
	match phase:
		"toi":
			var d: float = stop_s - b.s
			if d < 40.0:
				lim = minf(lim, sqrt(2.0 * traffic.BRAKE * maxf(d, 0.0)) + 0.05)
			if d <= 0.05 and b.speed < 0.3:
				phase = "dung"
				_t = 0.0
		"dung":
			lim = 0.0
			var before := _t
			_t += delta
			if before < DOOR_OPEN and _t >= DOOR_OPEN:
				_set_doors(true)
				doors_opened.emit(door_points())
			if before < DOOR_CLOSE and _t >= DOOR_CLOSE:
				doors_closing.emit()
			if _t >= DWELL - 0.4:
				_set_doors(false)
			if _t >= DWELL:
				phase = "di"
	var player: Node3D = traffic.player
	if player:
		var rel: Vector3 = player.global_position - b.pos
		var fwd: Vector3 = b.xf.basis.z * -1.0
		var right: Vector3 = b.xf.basis.x
		var along: float = rel.dot(fwd)
		var side: float = rel.dot(right)
		if along < 0.3 and along > -LENGTH and absf(side) < WIDTH / 2.0 + 0.2 and rel.y > ROOF_Y:
			lim = 0.0  # Bơ đứng trên nóc: đứng chờ, nhắc Bơ xuống
			if _bubble_time <= 0.0:
				_bubble_time = 3.0
		elif along > -0.2 and along < HONK_AHEAD and absf(side) < WIDTH / 2.0 + 0.5 and rel.y < ROOF_Y:
			lim = minf(lim, sqrt(2.0 * traffic.BRAKE_MAX * maxf(along - 1.2, 0.0)))
			if _honk_cd <= 0.0 and phase != "dung":
				_honk_cd = 3.0
				traffic.honk(b.pos + fwd * 0.5)
	return lim


## Không để mũi xe vượt quá chỗ dừng ở trạm.
func clamp_stop(b) -> void:
	if phase == "toi" and b.s > stop_s:
		b.s = stop_s
		b.speed = 0.0


## Bậc cửa trước và cửa giữa (mặt đường sát thân xe, phía vỉa hè) khi xe đang đỗ.
func door_points() -> Array:
	var out := []
	var fwd: Vector3 = bike.xf.basis.z * -1.0
	var right: Vector3 = bike.xf.basis.x
	for d in DOORS:
		var p: Vector3 = bike.pos - fwd * d + right * (WIDTH / 2.0 + 0.15)
		p.y = 0.0
		out.append(p)
	return out


func is_dwelling() -> bool:
	return phase == "dung" and _t >= DOOR_OPEN and _t < DOOR_CLOSE


func _set_doors(open: bool) -> void:
	_open.visible = open
	_closed.visible = not open


## Đặt va chạm theo xe ở mỗi nhịp vật lý; xe nghỉ ngoài vành thì cất va chạm đi.
func sync() -> void:
	if not _body.is_inside_tree():
		return
	if bike.active:
		_body.global_transform = bike.xf
	else:
		_body.global_transform = Transform3D(Basis(), Vector3(0, -50, 0))


func draw(f: float, cam: Camera3D) -> void:
	var xf: Transform3D = bike.prev_xf.interpolate_with(bike.xf, f)
	var shown: bool = bike.active and absf(xf.origin.x) < 108.0 and absf(xf.origin.z) < 92.0
	if shown and cam and cam.global_position.distance_to(xf.origin) > 100.0:
		shown = false
	visible = shown
	if not shown:
		return
	global_transform = xf
	# Xi nhan phải khi tấp vào trạm và khi rẽ vào đường vành x = 99, xi nhan trái khi rời trạm
	_blink += get_process_delta_time()
	var on := fmod(_blink, 0.8) < 0.4
	var s: float = bike.s
	var right_on: bool = (phase == "toi" and s > stop_s - 22.0) or (phase == "dung" and _t < DOOR_OPEN) or xf.origin.x > 88.0
	var left_on: bool = (phase == "dung" and _t > DOOR_CLOSE) or (phase == "di" and s < stop_s + 9.0)
	for l in _lamps_right:
		l.visible = right_on and on
	for l in _lamps_left:
		l.visible = left_on and on
	_bubble.visible = _bubble_time > 0.0
