extends Node3D
## Camera theo mèo, có hai góc nhìn (phím V hoặc cài đặt đổi qua lại):
## - Thứ ba: sau lưng mèo. SpringArm3D tự kéo camera lại gần khi bị tường che.
## - Thứ nhất: ngay mắt Bơ. Không vẽ thân Bơ để khỏi che mắt, bóng Bơ vẫn in trên đất.
## Chuột (hoặc cần phải tay cầm) xoay camera. Khi chuột chưa bị khóa (trình duyệt từ chối khóa con trỏ)
## thì giữ chuột trái hoặc phải rồi kéo để xoay.

signal view_changed(first_person: bool)

@export var mouse_sensitivity := 0.0035
@export var stick_speed := 2.8
@export var distance := 3.2
@export var follow_speed := 18.0
@export var look_height := 0.55
@export var fp_height := 0.44     ## độ cao mắt Bơ so với chân
@export var fp_forward := 0.04    ## mắt nằm trước tâm người bao nhiêu

var target: Node3D
var yaw := 0.0
var pitch := -0.32
var invert_y := false             ## đảo trục dọc chuột/cần (menu Cài đặt gán)
var first_person := false: set = set_first_person
var _manual_ms := -100000         ## lần cuối người chơi tự xoay (chuột hoặc cần)

var arm: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	add_to_group("camera_rig")
	arm = SpringArm3D.new()
	arm.spring_length = distance
	arm.margin = 0.15
	arm.collision_mask = Blocks.LAYER_WORLD  # chỉ né nhà và mặt đất, bỏ qua mèo, chó và đồ nhỏ
	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	arm.shape = sphere
	add_child(arm)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 300.0
	arm.add_child(camera)
	if target:
		global_position = target.global_position + Vector3.UP * look_height
	_apply_view()


func set_first_person(v: bool) -> void:
	if v == first_person:
		return
	first_person = v
	pitch = -0.15 if v else -0.32
	if is_node_ready():
		_apply_view()
		_snap()
	view_changed.emit(v)


func _apply_view() -> void:
	arm.spring_length = 0.0 if first_person else distance
	camera.near = 0.02 if first_person else 0.05
	if target and target.has_method("set_first_person"):
		target.set_first_person(first_person, camera)


## Bao nhiêu giây kể từ lần cuối người chơi tự xoay camera (cảnh tự lái camera thì nhường người chơi).
func since_manual() -> float:
	return (Time.get_ticks_msec() - _manual_ms) / 1000.0


func _pitch_limits() -> Vector2:
	return Vector2(-1.35, 1.2) if first_person else Vector2(-1.2, 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		first_person = not first_person
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			or event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)):
		_manual_ms = Time.get_ticks_msec()
		var lim := _pitch_limits()
		var dy: float = -event.relative.y if invert_y else event.relative.y
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - dy * mouse_sensitivity, lim.x, lim.y)


func _process(delta: float) -> void:
	var look := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if invert_y:
		look.y = -look.y
	var lim := _pitch_limits()
	if look.length() > 0.05:
		_manual_ms = Time.get_ticks_msec()
	yaw -= look.x * stick_speed * delta
	pitch = clampf(pitch - look.y * stick_speed * delta, lim.x, lim.y)
	if target:
		if first_person:
			_snap()  # góc thứ nhất bám sát mắt, không trễ, để khỏi chóng mặt
		else:
			global_position = global_position.lerp(_goal(), 1.0 - exp(-follow_speed * delta))
	rotation = Vector3(pitch, yaw, 0)


func _goal() -> Vector3:
	var at: Vector3 = target.smooth_position() if target.has_method("smooth_position") else target.global_position
	var low: float = target.get("crouch_amount") if "crouch_amount" in target else 0.0  # Bơ chui thì camera hạ theo
	if first_person:
		return at + Vector3.UP * fp_height * lerpf(1.0, 0.5, low) + Basis(Vector3.UP, yaw) * (Vector3.FORWARD * fp_forward)
	return at + Vector3.UP * look_height * lerpf(1.0, 0.6, low)


func _snap() -> void:
	if target:
		global_position = _goal()
