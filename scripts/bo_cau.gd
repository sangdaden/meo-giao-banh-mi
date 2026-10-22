class_name BoCau
extends Node3D
## Đàn bồ câu (Thứ Tư trở đi, con vật nền, không phải boss). Khối tạm vẽ bằng một MultiMesh cho tới khi có
## model G5 có rig (đậu, mổ, đi, cất cánh, bay tán loạn).
## Đậu thì mổ lia lịa; Bơ đi sát (trong bán kính DoKho "pigeon_notice") mà không rón rén/chui thì cả đàn bay
## tán loạn, ai đứng gần bị che tầm nhìn (blinded), bay vòng trên cao một lúc rồi đáp về chỗ cũ.

signal scattered(pos: Vector3)
signal blinded(seconds: float)

const COUNT := 8
const SCATTER_TIME := 2.2          ## bay tán loạn (lao ra, vỗ cánh)
const CIRCLE_TIME := 5.0           ## lượn vòng trên cao trước khi đáp lại
const LAND_TIME := 1.6
const GREY := Color("#8E949A")

class Bird:
	var home := Vector3.ZERO
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var yaw := 0.0
	var phase := 0.0
	var from := Vector3.ZERO       ## chỗ bắt đầu đáp

var player: CharacterBody3D
var state := "perch"               ## perch | scatter | circle | land
var scatters := 0
var _birds: Array[Bird] = []
var _t := 0.0
var _mm: MultiMeshInstance3D
var _center := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "BoCau"
	_rng.seed = 404
	_mm = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _bird_mesh()
	mm.instance_count = COUNT
	_mm.multimesh = mm
	_mm.material_override = Blocks.mat(GREY)
	add_child(_mm)
	for i in COUNT:
		_birds.append(Bird.new())


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


func _process(_delta: float) -> void:
	if not visible:
		return
	var now := Time.get_ticks_msec() * 0.001
	for i in COUNT:
		var b := _birds[i]
		var basis := Basis(Vector3.UP, b.yaw)
		var p := b.pos
		if state == "perch":
			# Mổ: chúi đầu theo nhịp, thỉnh thoảng nhích người
			basis = basis * Basis(Vector3.RIGHT, -maxf(sin(now * 6.0 + b.phase), 0.0) * 0.5)
		else:
			# Vỗ cánh: thân dập dềnh
			p.y += sin(now * 22.0 + b.phase) * 0.04
			basis = basis.scaled(Vector3(1.0 + 0.6 * absf(sin(now * 22.0 + b.phase)), 1.0, 1.0))
		_mm.multimesh.set_instance_transform(i, Transform3D(basis, p))


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


## Khối tạm một con: thân, đầu, đuôi (dài ~0,3 m), mỏ hướng -Z.
static func _bird_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts := [
		[Vector3(0.12, 0.11, 0.2), Vector3(0, 0.1, 0)],
		[Vector3(0.08, 0.08, 0.08), Vector3(0, 0.19, -0.11)],
		[Vector3(0.1, 0.03, 0.1), Vector3(0, 0.12, 0.14)],
		[Vector3(0.22, 0.02, 0.1), Vector3(0, 0.15, 0.0)],
	]
	for part in parts:
		var bm := BoxMesh.new()
		bm.size = part[0]
		st.append_from(bm, 0, Transform3D(Basis.IDENTITY, part[1]))
	return st.commit()
