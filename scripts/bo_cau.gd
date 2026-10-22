class_name BoCau
extends Node3D
## Đàn bồ câu (Thứ Tư trở đi, con vật nền, không phải boss). Model G5 bo_cau_nhe (812 tam giác, 13 xương) với các
## clip dau (đậu), mo (mổ), di (đi), cat_canh, bay, bay_tan_loan.
## Đậu thì mổ lia lịa; Bơ đi sát (trong bán kính DoKho "pigeon_notice") mà không rón rén/chui thì cả đàn bay
## tán loạn, ai đứng gần bị che tầm nhìn (blinded), bay vòng trên cao một lúc rồi đáp về chỗ cũ.

signal scattered(pos: Vector3)
signal blinded(seconds: float)

const COUNT := 8
const SCATTER_TIME := 2.2          ## bay tán loạn (lao ra, vỗ cánh)
const CIRCLE_TIME := 5.0           ## lượn vòng trên cao trước khi đáp lại
const LAND_TIME := 1.6

class Bird:
	var home := Vector3.ZERO
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var yaw := 0.0
	var phase := 0.0
	var from := Vector3.ZERO       ## chỗ bắt đầu đáp
	var node: Node3D
	var anim: AnimationPlayer
	var idle_t := 0.0              ## đậu: đổi dáng (đậu / mổ / đi vài bước) sau chừng này giây

var player: CharacterBody3D
var state := "perch"               ## perch | scatter | circle | land
var scatters := 0
var _birds: Array[Bird] = []
var _t := 0.0
var _center := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "BoCau"
	_rng.seed = 404
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
	match state:
		"perch":
			_check_player()
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
	for b in _birds:
		# Model nhìn +Z, yaw tính theo hướng -Z
		b.node.position = b.pos
		b.node.rotation.y = b.yaw + PI
		match state:
			"perch":
				b.idle_t -= delta
				if b.idle_t <= 0.0 or not b.anim.is_playing():
					var r := _rng.randf()
					_play(b, "mo" if r < 0.5 else ("dau" if r < 0.85 else "di"))
					b.idle_t = _rng.randf_range(1.0, 3.0)
				if b.anim.current_animation == "di":
					# Đi lững thững, ra xa chỗ đậu quá nửa mét thì quay đầu
					b.pos += Vector3(-sin(b.yaw), 0, -cos(b.yaw)) * 0.25 * delta
					if Vector2(b.pos.x - b.home.x, b.pos.z - b.home.z).length() > 0.5:
						b.yaw += PI
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
