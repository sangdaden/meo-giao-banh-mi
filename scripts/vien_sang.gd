class_name VienSang
extends Node
## Viền sáng nhẹ quanh Bơ buổi chiều tà, hoàng hôn, tối (luồng D1 "Màu chiều tà").
## Nắng thấp và sương ấm làm lông cam của Bơ chìm vào phố cam hồng: thêm một lượt vẽ cộng sáng
## (next_pass) lên vật liệu thân Bơ, sáng ở mép nhìn nghiêng và ưu tiên mép trên (đầu, tai, lưng),
## nên Bơ tách khỏi nền mà phố không đổi. Không dùng đèn: trên web (Compatibility, Godot 4.3) đèn
## định hướng không lọc được theo lớp, sẽ thắp cả phố.
## Vật liệu của Bơ dựng lại khi đổi giống hay mặc đồ, nên cứ 0,5 giây gắn lại cho mặt nào còn thiếu.

const COLOR := Color("#FFE6C2")  ## kem ấm, sáng hơn nắng chiều để mép lông nổi lên
const MASK := 1 << 10            ## = Player.LAYER_BO_BODY: chỉ thân Bơ, không chân góc nhìn thứ nhất

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
uniform vec4 tint : source_color;
uniform float strength = 0.0;
void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float top = clamp(wn.y * 0.6 + 0.55, 0.0, 1.0);
	ALBEDO = tint.rgb * edge * top * strength;
}
"""

## Độ sáng viền (0 = tắt). AnhSang.build gán theo preset "rim"; Thứ Bảy nội suy theo nấc trời.
var strength := 0.0:
	set(v):
		strength = v
		_mat.set_shader_parameter("strength", v)

var _mat := ShaderMaterial.new()
var _t := 0.0


func _init() -> void:
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("tint", COLOR)
	_mat.set_shader_parameter("strength", 0.0)


func _process(delta: float) -> void:
	if strength <= 0.01:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var player: Node = get_parent().get("player")
	if player == null:
		return
	for mi: MeshInstance3D in player.find_children("*", "MeshInstance3D", true, false):
		if not (mi.layers & MASK) or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as StandardMaterial3D
			if m and m.next_pass == null and m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				m.next_pass = _mat
