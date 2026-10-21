extends Node3D
## Camera góc nhìn thứ ba sau lưng mèo.
## Chuột (hoặc cần phải tay cầm) xoay camera; SpringArm3D tự kéo camera lại gần khi bị tường che.

@export var mouse_sensitivity := 0.0035
@export var stick_speed := 2.8
@export var distance := 3.2
@export var follow_speed := 18.0
@export var look_height := 0.55

var target: Node3D
var yaw := 0.0
var pitch := -0.32

var arm: SpringArm3D
var camera: Camera3D


func _ready() -> void:
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.2, 0.35)


func _process(delta: float) -> void:
	var look := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	yaw -= look.x * stick_speed * delta
	pitch = clampf(pitch - look.y * stick_speed * delta, -1.2, 0.35)
	if target:
		var at: Vector3 = target.smooth_position() if target.has_method("smooth_position") else target.global_position
		var goal := at + Vector3.UP * look_height
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	rotation = Vector3(pitch, yaw, 0)
