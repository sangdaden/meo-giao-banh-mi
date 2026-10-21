extends Node3D
## Bóng mờ của lần giao nhanh nhất: chạy lại đường đã lưu (10 điểm mỗi giây) cùng lúc với người chơi.
## Hình tạm: thân mèo khối mờ màu cam, sau này thay bằng model Bơ với vật liệu trong suốt.

const SAMPLE_RATE := 10.0

var path := PackedVector3Array()
var _t := 0.0
var _body: Node3D


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var col := Color(1.0, 0.72, 0.35, 0.35)
	var torso := CapsuleMesh.new()
	torso.radius = 0.11
	torso.height = 0.46
	torso.radial_segments = 10
	torso.rings = 3
	var t := Blocks.mesh(_body, torso, Vector3(0, 0.2, 0), col, true)
	t.rotation_degrees.x = 90
	var head := SphereMesh.new()
	head.radius = 0.1
	head.height = 0.2
	head.radial_segments = 10
	head.rings = 5
	Blocks.mesh(_body, head, Vector3(0, 0.32, -0.25), col, true)
	for x in [-0.055, 0.055]:
		var ear := PrismMesh.new()
		ear.size = Vector3(0.06, 0.07, 0.03)
		Blocks.mesh(_body, ear, Vector3(x, 0.43, -0.25), col, true)
	for mi in _body.get_children():
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## Bắt đầu chạy lại một đường (rỗng thì ẩn).
func play(p: PackedVector3Array) -> void:
	path = p
	_t = 0.0
	visible = path.size() >= 2
	if visible:
		position = path[0]


func stop() -> void:
	visible = false
	path = PackedVector3Array()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var f := _t * SAMPLE_RATE
	var i := int(f)
	if i >= path.size() - 1:
		position = path[path.size() - 1]
		return
	var a := path[i]
	var b := path[i + 1]
	position = a.lerp(b, f - i)
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	if flat.length() > 0.01:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-flat.x, -flat.z), 1.0 - exp(-12.0 * delta))
