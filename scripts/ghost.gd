extends Node3D
## Bóng kỷ lục: chạy lại đường của lần giao nhanh nhất (10 điểm mỗi giây) cùng lúc với người chơi.
## Tắt mặc định, bật trong Cài đặt ("Bóng kỷ lục", GameSettings "bong_ky_luc").
## Trông như bóng ma: chỉ có viền sáng xanh nhạt, nhãn "Kỷ lục" trên đầu, mờ dần khi đến gần Bơ
## để không che tầm nhìn. Hình tạm vẫn là khối mèo, sau này thay bằng model Bơ cùng vật liệu này.

const SAMPLE_RATE := 10.0
const TINT := Color(0.62, 0.9, 1.0)
## Trong khoảng này bóng mờ dần, sát Bơ thì gần như biến mất.
const FADE_FAR := 3.0
const FADE_NEAR := 1.0
## Khối mèo tạm nhỏ hơn model Bơ, phóng lên cho bằng.
const BODY_SCALE := 1.35

const SHADER := "shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform vec3 tint : source_color;
uniform float fade = 1.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	ALBEDO = tint;
	ALPHA = (0.14 + 0.86 * rim) * fade;
}
"

## Bơ, để mờ bóng khi ở gần (main.gd gán).
var player: Node3D
var path := PackedVector3Array()
var _t := 0.0
var _body: Node3D
var _mat: ShaderMaterial
var _tag: Label3D


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var shader := Shader.new()
	shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("tint", TINT)
	var torso := CapsuleMesh.new()
	torso.radius = 0.11
	torso.height = 0.46
	torso.radial_segments = 16
	torso.rings = 6
	_part(torso, Vector3(0, 0.2, 0)).rotation_degrees.x = 90
	var head := SphereMesh.new()
	head.radius = 0.1
	head.height = 0.2
	head.radial_segments = 16
	head.rings = 8
	_part(head, Vector3(0, 0.32, -0.25))
	for x in [-0.055, 0.055]:
		var ear := PrismMesh.new()
		ear.size = Vector3(0.07, 0.09, 0.04)
		_part(ear, Vector3(x, 0.43, -0.25))
	# Đuôi dựng lên: nhìn từ sau lưng vẫn ra dáng mèo.
	var tail := CapsuleMesh.new()
	tail.radius = 0.025
	tail.height = 0.3
	tail.radial_segments = 8
	_part(tail, Vector3(0, 0.33, 0.24)).rotation_degrees.x = -25
	_body.scale = Vector3.ONE * BODY_SCALE
	_tag = Blocks.label(self, "Kỷ lục", Vector3(0, 0.85, 0), 30, TINT)
	_tag.outline_size = 6
	visible = false


func _part(m: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mi)
	return mi


static func enabled() -> bool:
	return bool(GameSettings.get_value("bong_ky_luc"))


## Bắt đầu chạy lại một đường (rỗng hoặc đang tắt thì ẩn).
func play(p: PackedVector3Array) -> void:
	path = p
	_t = 0.0
	visible = path.size() >= 2 and enabled()
	if path.size() >= 2:
		position = path[0]


func stop() -> void:
	visible = false
	path = PackedVector3Array()


func _process(delta: float) -> void:
	if path.size() < 2:
		return
	# Bật/tắt trong Cài đặt lúc tạm dừng thì có tác dụng ngay.
	visible = enabled()
	if not visible:
		return
	_t += delta
	var f := _t * SAMPLE_RATE
	var i := int(f)
	if i >= path.size() - 1:
		position = path[path.size() - 1]
	else:
		var a := path[i]
		var b := path[i + 1]
		position = a.lerp(b, f - i)
		var flat := Vector3(b.x - a.x, 0, b.z - a.z)
		if flat.length() > 0.01:
			_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-flat.x, -flat.z), 1.0 - exp(-12.0 * delta))
	var fade := 1.0
	if player:
		fade = smoothstep(FADE_NEAR, FADE_FAR, global_position.distance_to(player.global_position))
	_mat.set_shader_parameter("fade", fade)
	_tag.modulate.a = fade
	_tag.outline_modulate.a = fade
