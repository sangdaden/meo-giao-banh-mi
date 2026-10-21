extends Node3D
## Camera màn bếp: đứng cố định ngoài tủ kính nhìn thẳng vào bếp, chỉ hơi ngoảnh theo Bơ.
## Khi Bơ làm một bước, camera lướt vào cận cảnh trạm đó rồi lướt ra lại.
## player.gd đọc `yaw` để biết hướng "lên" của phím: yaw = 0 nghĩa là W đi sâu vào bếp (-Z).

var yaw := 0.0
var target: Node3D

@export var main_pos := Vector3(0, 3.0, 5.3)
@export var main_look := Vector3(0, 0.2, -0.2)
@export var follow := 0.2       ## camera ngoảnh theo mèo bao nhiêu (0 = đứng yên hẳn)
@export var move_speed := 7.0   ## tốc độ lướt vào/ra cận cảnh

var camera: Camera3D
var _close := false
var _close_pos := Vector3.ZERO
var _close_look := Vector3.ZERO


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 46.0
	camera.near = 0.03
	add_child(camera)
	camera.global_transform = _main_xform()
	camera.make_current()


func close_up(pos: Vector3, look: Vector3) -> void:
	_close = true
	_close_pos = pos
	_close_look = look


func back_to_main() -> void:
	_close = false


func is_close() -> bool:
	return _close


func _main_xform() -> Transform3D:
	var look := main_look
	if target:
		var at: Vector3 = target.smooth_position() if target.has_method("smooth_position") else target.global_position
		look = main_look.lerp(Vector3(at.x, main_look.y, at.z), follow)
	return Transform3D(Basis.looking_at(look - main_pos), main_pos)


func _process(delta: float) -> void:
	var goal := Transform3D(Basis.looking_at(_close_look - _close_pos), _close_pos) if _close else _main_xform()
	var t := 1.0 - exp(-move_speed * delta)
	camera.global_transform = camera.global_transform.interpolate_with(goal, t)
	camera.fov = lerpf(camera.fov, 50.0 if _close else 46.0, t)
