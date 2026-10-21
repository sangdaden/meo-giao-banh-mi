extends CharacterBody3D
## Mèo Bơ bản khối thô: chạy, chạy nhanh, nhảy, mang túi bánh.
## Cảm giác tay được chỉnh bằng các biến @export bên dưới (xem trong Inspector khi chạy).

signal jumped
signal landed

@export_group("Chạy")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var ground_accel := 45.0      ## tăng tốc trên mặt đất (m/s²)
@export var ground_decel := 55.0      ## phanh khi thả phím
@export var air_accel := 18.0         ## đổi hướng giữa không trung
@export var turn_speed := 14.0        ## tốc độ xoay người theo hướng chạy

@export_group("Nhảy")
@export var jump_velocity := 8.5      ## cao khoảng 1,3 m khi giữ nút nhảy
@export var gravity := 28.0
@export var fall_multiplier := 1.7    ## rơi nhanh hơn lúc lên cho đỡ "bồng bềnh"
@export var short_hop_multiplier := 2.2  ## thả nút nhảy sớm thì nhảy thấp
@export var coyote_time := 0.12       ## vẫn nhảy được ngay sau khi rời mép
@export var jump_buffer := 0.12       ## bấm nhảy hơi sớm trước khi chạm đất vẫn tính

var camera_rig: Node3D               ## main.gd gán: để lấy hướng camera
var can_move := false
var carrying := false:
	set(v):
		carrying = v
		if bread:
			bread.visible = v

var _coyote := 0.0
var _buffer := 0.0
var _stun := 0.0
var _phase := 0.0
var _was_on_floor := true
# Vị trí ở hai nhịp vật lý gần nhất, để vẽ mèo nằm giữa hai nhịp cho mượt
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO

var visual: Node3D
var _body: Node3D
var _legs: Array[Node3D] = []
var _tail: Node3D
var bread: Node3D

const ORANGE := Color("#E8913A")
const ORANGE_DARK := Color("#C96F1C")
const CREAM := Color("#FBE3C2")
const SCARF := Color("#C8412F")
const BAG := Color("#2E7C80")
const INK := Color("#1F2A2A")
const PINK := Color("#F6B8A0")


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 0.7
	shape.shape = cap
	shape.position.y = 0.35
	add_child(shape)
	_build_visual()
	# Phần hình tách khỏi thân vật lý: thân di chuyển 60 lần/giây theo nhịp vật lý,
	# còn hình được nội suy mỗi khung hình nên vẫn mượt trên màn 75, 120, 144 Hz.
	visual.top_level = true
	_prev_pos = global_position
	_curr_pos = global_position


## Mèo dựng bằng khối hộp, mặt quay về -Z (hướng "trước" của Godot).
## Tỉ lệ theo bản phác: Bơ cao khoảng 0,6 m tính tới đỉnh tai... ở đây hơi to hơn cho dễ nhìn.
func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "CatVisual"
	add_child(visual)
	_body = Node3D.new()
	visual.add_child(_body)

	Blocks.box(_body, Vector3(0.36, 0.30, 0.56), Vector3(0, 0.34, 0.02), ORANGE)       # thân
	Blocks.box(_body, Vector3(0.26, 0.06, 0.40), Vector3(0, 0.20, 0.0), CREAM)         # bụng
	# Đầu sát vai (cổ rất ngắn, giấu dưới khăn)
	Blocks.box(_body, Vector3(0.36, 0.30, 0.30), Vector3(0, 0.58, -0.26), ORANGE)
	Blocks.box(_body, Vector3(0.18, 0.10, 0.04), Vector3(0, 0.50, -0.42), CREAM)        # mõm
	Blocks.box(_body, Vector3(0.05, 0.04, 0.02), Vector3(0, 0.54, -0.445), PINK)        # mũi
	Blocks.box(_body, Vector3(0.05, 0.07, 0.02), Vector3(-0.09, 0.62, -0.415), INK)     # mắt
	Blocks.box(_body, Vector3(0.05, 0.07, 0.02), Vector3(0.09, 0.62, -0.415), INK)
	for side in [-1.0, 1.0]:
		var ear := PrismMesh.new()
		ear.size = Vector3(0.11, 0.13, 0.06)
		Blocks.mesh(_body, ear, Vector3(0.11 * side, 0.79, -0.24), ORANGE)
	Blocks.box(_body, Vector3(0.40, 0.08, 0.14), Vector3(0, 0.45, -0.17), SCARF)        # khăn
	Blocks.box(_body, Vector3(0.10, 0.16, 0.05), Vector3(0.12, 0.38, -0.25), SCARF)     # đuôi khăn
	Blocks.box(_body, Vector3(0.12, 0.20, 0.26), Vector3(0.24, 0.32, 0.04), BAG)        # túi bánh
	Blocks.box(_body, Vector3(0.40, 0.03, 0.03), Vector3(0.0, 0.50, 0.04), BAG)         # quai túi

	# Ổ bánh mì ló ra khỏi túi khi đang giao
	bread = Node3D.new()
	_body.add_child(bread)
	var loaf := CapsuleMesh.new()
	loaf.radius = 0.06
	loaf.height = 0.34
	loaf.radial_segments = 8
	loaf.rings = 2
	var loaf_mi := Blocks.mesh(bread, loaf, Vector3(0.25, 0.46, 0.04), Color("#D98E2B"))
	loaf_mi.rotation_degrees = Vector3(70, 0, 0)
	bread.visible = false

	# Bốn chân: gốc xoay ở hông để vung khi chạy
	for p in [Vector3(-0.11, 0.2, -0.16), Vector3(0.11, 0.2, -0.16), Vector3(-0.11, 0.2, 0.18), Vector3(0.11, 0.2, 0.18)]:
		var pivot := Node3D.new()
		pivot.position = p
		_body.add_child(pivot)
		Blocks.box(pivot, Vector3(0.10, 0.20, 0.10), Vector3(0, -0.10, 0), ORANGE)
		Blocks.box(pivot, Vector3(0.11, 0.04, 0.12), Vector3(0, -0.19, -0.01), CREAM)
		_legs.append(pivot)

	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.42, 0.28)
	_body.add_child(_tail)
	Blocks.box(_tail, Vector3(0.07, 0.07, 0.40), Vector3(0, 0, 0.20), ORANGE_DARK)


func _physics_process(delta: float) -> void:
	_prev_pos = _curr_pos
	var on_floor := is_on_floor()
	_coyote = coyote_time if on_floor else _coyote - delta
	_buffer = jump_buffer if (can_move and Input.is_action_just_pressed("jump")) else _buffer - delta
	_stun = maxf(_stun - delta, 0.0)

	if not on_floor:
		var g := gravity
		if velocity.y < 0.0:
			g *= fall_multiplier
		elif not Input.is_action_pressed("jump"):
			g *= short_hop_multiplier
		velocity.y = maxf(velocity.y - g * delta, -30.0)

	if _buffer > 0.0 and _coyote > 0.0 and _stun <= 0.0:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0
		visual.scale = Vector3(0.8, 1.25, 0.8)
		jumped.emit()

	var input := Vector2.ZERO
	if can_move and _stun <= 0.0:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = camera_rig.yaw if camera_rig else 0.0
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target := Vector2(dir.x, dir.z) * speed
	var accel := air_accel
	if on_floor:
		accel = ground_accel if dir.length() > 0.01 else ground_decel
	var hv := Vector2(velocity.x, velocity.z).move_toward(target, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.y

	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		visual.scale = Vector3(1.25, 0.75, 1.25)
		landed.emit()
	_was_on_floor = is_on_floor()

	if dir.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-turn_speed * delta))

	# Rơi khỏi bản đồ thì đưa về chỗ cũ
	if global_position.y < -10.0:
		global_position = Vector3(-33, 1, -2)
		velocity = Vector3.ZERO
	_curr_pos = global_position


## Animation tạm bằng code: vung chân, nhún người, vẫy đuôi.
## Tuần 2 sẽ thay bằng AnimationTree với animation làm trong Blender.
## Vị trí mèo đã nội suy giữa hai nhịp vật lý: camera và mũi tên bám theo vị trí này.
func smooth_position() -> Vector3:
	return _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())


func _process(delta: float) -> void:
	visual.global_position = smooth_position()
	var hspeed := Vector2(velocity.x, velocity.z).length()
	visual.scale = visual.scale.lerp(Vector3.ONE, 1.0 - exp(-12.0 * delta))
	if is_on_floor():
		_phase += delta * (4.0 + hspeed * 2.2)
		var k := clampf(hspeed / sprint_speed, 0.0, 1.0)
		var swing := sin(_phase) * 0.9 * k
		_legs[0].rotation.x = swing
		_legs[3].rotation.x = swing
		_legs[1].rotation.x = -swing
		_legs[2].rotation.x = -swing
		_body.position.y = absf(sin(_phase)) * 0.04 * k
		_body.rotation.x = 0.0
	else:
		# Trên không: chân trước duỗi, chân sau co
		var t := 1.0 - exp(-10.0 * delta)
		_legs[0].rotation.x = lerpf(_legs[0].rotation.x, 0.8, t)
		_legs[1].rotation.x = lerpf(_legs[1].rotation.x, 0.8, t)
		_legs[2].rotation.x = lerpf(_legs[2].rotation.x, -0.8, t)
		_legs[3].rotation.x = lerpf(_legs[3].rotation.x, -0.8, t)
		_body.rotation.x = clampf(velocity.y * 0.04, -0.3, 0.3)
	_tail.rotation.x = 0.7 + sin(Time.get_ticks_msec() * 0.004) * 0.15
	_tail.rotation.y = sin(Time.get_ticks_msec() * 0.006) * 0.4


## Bị Chó Mực đớp: văng ra và khựng lại một chút.
func knockback(from: Vector3, strength := 9.0) -> void:
	var away := global_position - from
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	velocity = away * strength + Vector3.UP * 4.5
	_stun = 0.45
	visual.scale = Vector3(1.3, 0.7, 1.3)
