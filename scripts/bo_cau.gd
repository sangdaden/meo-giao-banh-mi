class_name BoCau
extends Node3D
## Đàn bồ câu (Thứ Tư trở đi, con vật nền, không phải boss). Model G5 bo_cau_nhe (812 tam giác, 13 xương) với các
## clip dau (đậu), mo (mổ), di (đi), cat_canh, bay, bay_tan_loan.
## Đậu thì mổ lia lịa; Bơ đi sát (trong bán kính DoKho "pigeon_notice") mà không rón rén/chui thì cả đàn bay
## tán loạn, ai đứng gần bị che tầm nhìn (blinded), bay vòng trên cao một lúc rồi đáp về chỗ cũ.
## K1 rắc vụn bánh (Thứ Tư, Thứ Bảy): Bơ ngồi gọi Q (ConVat, nhóm "con_vat") cách đàn trong goi_r thì rắc vụn,
## cả đàn sà xuống quanh chân Bơ mổ một lúc (state feed) rồi về chỗ cũ; ăn xong quen hơi Bơ, đi sát cũng không bay.
## Chỉ là thưởng: không tính vào đơn, không làm hỏng nhiệm vụ phụ "Không làm bồ câu bay".

signal scattered(pos: Vector3)
signal blinded(seconds: float)
signal fed(pos: Vector3)            ## vừa rắc vụn bánh, đàn đang sà xuống

const COUNT := 8
const SCATTER_TIME := 2.2          ## bay tán loạn (lao ra, vỗ cánh)
const CIRCLE_TIME := 5.0           ## lượn vòng trên cao trước khi đáp lại
const LAND_TIME := 1.6
const FEED_FLY := 1.2              ## sà từ chỗ đậu xuống quanh chân Bơ
const CRUMBS := 12
const CON_VAT := "res://scripts/con_vat.gd"   ## hợp đồng chung con vật (luồng "Cơ chế chung con vật")

class Bird:
	var home := Vector3.ZERO
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var yaw := 0.0
	var phase := 0.0
	var from := Vector3.ZERO       ## chỗ bắt đầu đáp
	var spot := Vector3.ZERO       ## chỗ mổ vụn bánh quanh Bơ
	var node: Node3D
	var anim: AnimationPlayer
	var idle_t := 0.0              ## đậu: đổi dáng (đậu / mổ / đi vài bước) sau chừng này giây

var player: CharacterBody3D
var state := "perch"               ## perch | scatter | circle | land | feed_go | feed
var scatters := 0
var feeds := 0
## Bán kính nghe Q của ConVat (khóa DoKho "rac_vun_r")
var goi_r := 4.0
## Hiện chữ nhắc (ngày gán hud.show_toast); không gán thì im
var toast: Callable
var _birds: Array[Bird] = []
var _t := 0.0
var _center := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _feed_at := Vector3.ZERO
var _calm := 0.0                   ## còn chừng này giây thì Bơ đi sát không làm đàn bay
var _crumbs: MultiMeshInstance3D
var _hinted := false


func _ready() -> void:
	name = "BoCau"
	_rng.seed = 404
	add_to_group("con_vat")
	goi_r = float(DoKho.v("rac_vun_r", 4.0))
	for i in COUNT:
		var b := Bird.new()
		b.node = ThuTuModels.put(self, "bo_cau_nhe", Vector3.ZERO)
		b.anim = b.node.find_children("*", "AnimationPlayer", true, false)[0]
		for clip in ["dau", "di", "bay"]:
			b.anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_birds.append(b)


## Đặt đàn đậu quanh `center` (trên mái hoặc mặt đường) trong vòng `radius` mét.
func perch_at(center: Vector3, radius := 1.6) -> void:
	_center = center
	for i in COUNT:
		var b := _birds[i]
		var a := TAU * i / COUNT + _rng.randf_range(-0.3, 0.3)
		var r := radius * sqrt(_rng.randf_range(0.15, 1.0))
		b.home = center + Vector3(cos(a) * r, 0, sin(a) * r)
		b.pos = b.home
		b.yaw = _rng.randf() * TAU
		b.phase = _rng.randf() * TAU
		b.idle_t = 0.0
	state = "perch"
	_t = 0.0
	visible = true


func _physics_process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_calm = maxf(_calm - delta, 0.0)
	match state:
		"perch":
			_check_player()
		"feed_go":
			var k := clampf(_t / FEED_FLY, 0.0, 1.0)
			for b in _birds:
				b.pos = b.from.lerp(b.spot, k) + Vector3.UP * sin(k * PI) * 1.0
				if k < 0.9:
					b.yaw = atan2(-(b.spot.x - b.from.x), -(b.spot.z - b.from.z))
			if k >= 1.0:
				for b in _birds:
					b.yaw = atan2(-(_feed_at.x - b.pos.x), -(_feed_at.z - b.pos.z))
					b.idle_t = 0.0
				_go("feed")
		"feed":
			if _t > float(DoKho.v("rac_vun_giay", 6.0)):
				_end_feed()
		"scatter":
			for b in _birds:
				b.vel.y = maxf(b.vel.y - 2.0 * delta, 1.5)
				b.pos += b.vel * delta
				b.yaw = atan2(-b.vel.x, -b.vel.z)
			if _t > SCATTER_TIME:
				_go("circle")
		"circle":
			for i in COUNT:
				var b := _birds[i]
				var a := _t * 0.9 + TAU * i / COUNT
				var goal := _center + Vector3(cos(a) * 5.0, 6.0 + sin(a * 2.0 + i) * 0.6, sin(a) * 5.0)
				b.pos = b.pos.lerp(goal, 1.0 - exp(-1.5 * delta))
				b.yaw = -a
			if _t > CIRCLE_TIME:
				for b in _birds:
					b.from = b.pos
				_go("land")
		"land":
			var k := clampf(_t / LAND_TIME, 0.0, 1.0)
			for b in _birds:
				b.pos = b.from.lerp(b.home, k) + Vector3.UP * sin(k * PI) * 0.8
			if k >= 1.0:
				_go("perch")


func _process(delta: float) -> void:
	if not visible:
		return
	_check_hint()
	for b in _birds:
		# Model nhìn +Z, yaw tính theo hướng -Z
		b.node.position = b.pos
		b.node.rotation.y = b.yaw + PI
		match state:
			"perch", "feed":
				# Đậu: mổ, đứng, đi vài bước. Đang ăn vụn bánh thì mổ nhiều hơn, quanh chỗ vụn rơi.
				var feeding := state == "feed"
				var anchor := b.spot if feeding else b.home
				b.idle_t -= delta
				if b.idle_t <= 0.0 or not b.anim.is_playing():
					var r := _rng.randf()
					var peck := 0.75 if feeding else 0.5
					_play(b, "mo" if r < peck else ("dau" if r < 0.88 else "di"))
					b.idle_t = _rng.randf_range(1.0, 3.0) if not feeding else _rng.randf_range(0.6, 1.6)
				if b.anim.current_animation == "di":
					# Đi lững thững, ra xa chỗ đậu quá nửa mét thì quay đầu
					b.pos += Vector3(-sin(b.yaw), 0, -cos(b.yaw)) * 0.25 * delta
					if Vector2(b.pos.x - anchor.x, b.pos.z - anchor.z).length() > 0.5:
						b.yaw += PI
			"feed_go":
				_play(b, "cat_canh" if _t > FEED_FLY - 0.5 else "bay")
			"scatter":
				if b.anim.current_animation != "bay_tan_loan" and b.anim.current_animation != "bay":
					_play(b, "bay_tan_loan")
				elif not b.anim.is_playing():
					_play(b, "bay")
			"circle":
				_play(b, "bay")
			"land":
				_play(b, "cat_canh" if _t > LAND_TIME - 0.5 else "bay")


func _play(b: Bird, clip: String) -> void:
	if b.anim.current_animation == clip and b.anim.is_playing():
		return
	b.anim.play(clip, 0.15)
	if clip in ["dau", "di", "bay"]:
		b.anim.seek(b.phase / TAU * b.anim.get_animation(clip).length, true)


func _check_player() -> void:
	if player == null:
		return
	var notice := float(DoKho.v("pigeon_notice", 3.0))
	if _calm > 0.0 and player.stance != "sprint":
		return  # vừa được Bơ cho ăn: quen hơi, chỉ chạy ào tới mới bay
	if player.stance in ["sneak", "crouch"]:
		return  # rón rén, chui qua thì chim không bay
	var pp := player.global_position
	for b in _birds:
		if absf(pp.y - b.pos.y) < 1.5 and Vector2(pp.x - b.pos.x, pp.z - b.pos.z).length() < notice:
			scatter(pp)
			return


## Cả đàn bay tán loạn ra xa `from`. Bơ đứng gần thì bị che tầm nhìn.
func scatter(from: Vector3) -> void:
	scatters += 1
	for b in _birds:
		var away := b.pos - from
		away.y = 0.0
		away = away.normalized() if away.length() > 0.05 else Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
		b.vel = away * _rng.randf_range(3.0, 5.0) + Vector3.UP * _rng.randf_range(3.0, 4.5)
	_go("scatter")
	scattered.emit(from)
	blinded.emit(float(DoKho.v("pigeon_blind", 2.0)))


func _go(s: String) -> void:
	state = s
	_t = 0.0


# ---------------------------------------------------------------- rắc vụn bánh (K1)

## ConVat: Bơ ngồi gọi Q ở `pos`. Đàn đang đậu (cùng tầng, trong goi_r) thì Bơ rắc vụn bánh, cả đàn sà xuống ăn.
func on_called(pos: Vector3) -> void:
	if not visible or state != "perch" or absf(pos.y - _center.y) > 2.0:
		return
	if Vector2(pos.x - _center.x, pos.z - _center.z).length() > goi_r + 1.6:
		return
	feed(pos)


## Rắc vụn bánh ở `pos` (chân Bơ): mỗi con một chỗ mổ trên vòng 0,5–1,3 m quanh đó.
func feed(pos: Vector3) -> void:
	feeds += 1
	_feed_at = pos
	for i in COUNT:
		var b := _birds[i]
		var a := TAU * i / COUNT + _rng.randf_range(-0.25, 0.25)
		var r := _rng.randf_range(0.5, 1.3)
		b.from = b.pos
		b.spot = pos + Vector3(cos(a) * r, 0, sin(a) * r)
	_drop_crumbs(pos)
	_go("feed_go")
	_meet()
	fed.emit(pos)
	_say("Bơ rắc vụn bánh, cả đàn bồ câu sà xuống ăn quanh chân!", 2.5)


## Ăn xong: về chỗ đậu cũ, quen hơi Bơ thêm một lúc (DoKho "rac_vun_em").
func _end_feed() -> void:
	for b in _birds:
		b.from = b.pos
	_calm = float(DoKho.v("rac_vun_em", 4.0))
	if _crumbs:
		_crumbs.queue_free()
		_crumbs = null
	_go("land")


func _drop_crumbs(pos: Vector3) -> void:
	if _crumbs:
		_crumbs.queue_free()
	var box := BoxMesh.new()
	box.size = Vector3(0.035, 0.018, 0.03)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = CRUMBS
	for i in CRUMBS:
		var a := _rng.randf() * TAU
		var r := 1.2 * sqrt(_rng.randf())
		var tf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), pos + Vector3(cos(a) * r, 0.012, sin(a) * r))
		mm.set_instance_transform(i, tf)
	_crumbs = MultiMeshInstance3D.new()
	_crumbs.name = "VunBanh"
	_crumbs.multimesh = mm
	_crumbs.material_override = Blocks.mat(Color("#E8C48A"))
	_crumbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_crumbs)


## Lần đầu Bơ tới gần đàn đang đậu: nhắc có thể gọi Q để rắc vụn (chỉ khi đã có phím Q chung của ConVat).
func _check_hint() -> void:
	if _hinted or state != "perch" or player == null or not toast.is_valid():
		return
	var pp := player.global_position
	if absf(pp.y - _center.y) > 1.5 or Vector2(pp.x - _center.x, pp.z - _center.z).length() > goi_r:
		return
	_hinted = true
	if ResourceLoader.exists(CON_VAT):
		_say("Bấm Q ngồi gọi: Bơ rắc vụn bánh cho bồ câu.", 3.0)


## Sổ "Bạn bốn chân" (ConVat.meet) khi đã có script chung; chưa có thì bỏ qua.
func _meet() -> void:
	if ResourceLoader.exists(CON_VAT):
		var cv: Script = load(CON_VAT)
		for m in cv.get_script_method_list():
			if m.name == "meet":
				cv.call("meet", "bo_cau")
				return


func _say(text: String, seconds: float) -> void:
	if toast.is_valid():
		toast.call(text, seconds)
