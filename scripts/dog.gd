extends CharacterBody3D
## Chó Mực bản khối: ngủ ở đầu hẻm, chỉ thức dậy canh đường ở đơn 5.
## Lại gần thì nó đuổi; bị đớp là văng ra và mất giờ. Nhảy qua đầu nó thì an toàn.

signal bit_player

@export var chase_speed := 6.3         ## chậm hơn mèo chạy nhanh (8), nhanh hơn mèo đi bộ (5)
@export var notice_radius := 8.0       ## mèo vào gần thế này thì chó đuổi
@export var leash_radius := 13.0       ## không đuổi xa nhà quá mức này
@export var bite_cooldown := 1.5

var player: CharacterBody3D
var awake := false:
	set(v):
		awake = v
		if _zzz:
			_zzz.visible = not v
var home := Vector3.ZERO

var _cooldown := 0.0
var _visual: Node3D
var _legs: Array[Node3D] = []
var _phase := 0.0
var _zzz: Label3D
var _bark: Label3D
var _lie := 0.0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO

const BLACK := Color("#2B2622")
const EAR := Color("#4A3F37")
const MUZZLE := Color("#8A6A4F")
const BROW := Color("#C9A06A")
const COLLAR := Color("#C8412F")
const TAG := Color("#F2C14E")


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	home = global_position
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.45, 0.6, 0.85)
	shape.shape = bs
	shape.position.y = 0.3
	add_child(shape)
	_build_visual()
	_visual.top_level = true  # hình nội suy giữa hai nhịp vật lý, giống mèo
	_prev_pos = global_position
	_curr_pos = global_position
	awake = false


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	Blocks.box(_visual, Vector3(0.42, 0.36, 0.80), Vector3(0, 0.46, 0.05), BLACK)       # thân
	Blocks.box(_visual, Vector3(0.30, 0.16, 0.36), Vector3(0, 0.36, -0.12), MUZZLE)     # ngực
	Blocks.box(_visual, Vector3(0.38, 0.34, 0.34), Vector3(0, 0.74, -0.42), BLACK)      # đầu
	Blocks.box(_visual, Vector3(0.22, 0.16, 0.20), Vector3(0, 0.66, -0.66), MUZZLE)     # mõm
	Blocks.box(_visual, Vector3(0.08, 0.06, 0.04), Vector3(0, 0.72, -0.77), BLACK)      # mũi
	for side in [-1.0, 1.0]:
		Blocks.box(_visual, Vector3(0.08, 0.04, 0.03), Vector3(0.09 * side, 0.84, -0.59), BROW)   # mày vàng
		Blocks.box(_visual, Vector3(0.05, 0.05, 0.02), Vector3(0.09 * side, 0.79, -0.595), Color.WHITE)
		var ear := Blocks.box(_visual, Vector3(0.08, 0.22, 0.14), Vector3(0.22 * side, 0.74, -0.40), EAR)  # tai cụp
		ear.rotation.z = 0.35 * side
	Blocks.box(_visual, Vector3(0.44, 0.07, 0.10), Vector3(0, 0.60, -0.28), COLLAR)     # vòng cổ
	Blocks.box(_visual, Vector3(0.07, 0.08, 0.02), Vector3(0, 0.54, -0.34), TAG)        # thẻ tên
	var tail := Blocks.box(_visual, Vector3(0.07, 0.07, 0.30), Vector3(0, 0.66, 0.55), BLACK)
	tail.rotation.x = 0.8
	for p in [Vector3(-0.13, 0.30, -0.22), Vector3(0.13, 0.30, -0.22), Vector3(-0.13, 0.30, 0.30), Vector3(0.13, 0.30, 0.30)]:
		var pivot := Node3D.new()
		pivot.position = p
		_visual.add_child(pivot)
		Blocks.box(pivot, Vector3(0.12, 0.30, 0.12), Vector3(0, -0.15, 0), BLACK)
		_legs.append(pivot)
	_zzz = Blocks.label(self, "z z z", Vector3(0, 1.2, 0), 40, Color("#9FD3D6"))
	_bark = Blocks.label(self, "GÂU!", Vector3(0, 1.4, 0), 64, Color("#C8412F"))
	_bark.visible = false


func _physics_process(delta: float) -> void:
	_prev_pos = _curr_pos
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y -= 28.0 * delta

	var goal := home
	var speed := 3.0
	if awake and player and _cooldown <= 0.0:
		var to_player := player.global_position - global_position
		var player_near_home := player.global_position.distance_to(home) < leash_radius
		if to_player.length() < notice_radius and player_near_home:
			goal = player.global_position
			speed = chase_speed
		# Đớp: chỉ khi mèo không nhảy cao hơn lưng chó
		var flat := Vector2(to_player.x, to_player.z).length()
		if flat < 0.75 and player.global_position.y < global_position.y + 0.65:
			_cooldown = bite_cooldown
			_bark.visible = true
			get_tree().create_timer(0.8).timeout.connect(func(): _bark.visible = false)
			bit_player.emit()

	var to_goal := goal - global_position
	to_goal.y = 0
	if to_goal.length() > 0.3:
		var dir := to_goal.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-10.0 * delta))
	else:
		velocity.x = 0
		velocity.z = 0
	move_and_slide()
	_curr_pos = global_position

	# Animation tạm: nằm khi ngủ, vung chân khi chạy
	var hspeed := Vector2(velocity.x, velocity.z).length()
	_phase += delta * (3.0 + hspeed * 2.0)
	var k := clampf(hspeed / chase_speed, 0.0, 1.0)
	for i in _legs.size():
		var s := 1.0 if i == 0 or i == 3 else -1.0
		_legs[i].rotation.x = sin(_phase) * 0.8 * k * s
	var lying := 0.0 if awake else -0.22
	_lie = lerpf(_lie, lying, 1.0 - exp(-6.0 * delta))


func _process(_delta: float) -> void:
	var smooth := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	_visual.global_position = smooth + Vector3(0, _lie, 0)
