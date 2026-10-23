class_name CatVatChe
extends Node
## Làm mờ vật che giữa camera và Bơ (mái hiên, tường, chồng thùng, bảng hiệu...).
## Phố đã gộp mesh theo ô (Blocks.merge_static) nên không làm mờ từng vật được: thay vào đó, mesh nào
## nằm gần đường nhìn camera → Bơ thì tạm đổi sang bản vật liệu "cắt", bỏ lấm tấm (dither) các điểm ảnh
## nằm trong hình nón từ camera tới Bơ. Điểm thấp hơn chân Bơ (mặt đất, mái Bơ đang đứng) không cắt.
## Hết che thì trả lại vật liệu gốc, nên lúc bình thường phố vẽ y như cũ (không tốn thêm gì).
## Chỉ đổi StandardMaterial3D đục kiểu đơn giản (màu, màu đỉnh, ảnh màu, cắt alpha, độ nhám, phát sáng);
## vật liệu khác (trong suốt, shader riêng) để nguyên.
## camera_rig.gd tạo và gọi step() mỗi khung hình. Biến chung của shader (cam_cut_*) khai trong project.godot.

const RADIUS := 0.85         ## bán kính vùng cắt quanh Bơ (m); phía camera thu nhỏ dần
const KEEP := 0.0            ## trong lõi vùng cắt giữ lại chừng này điểm ảnh (0: lõi trong hẳn, chỉ viền lấm tấm)
const SPEED := 6.0           ## mờ/hiện nhanh cỡ nào (lần/giây)
const MAX_SIZE := 120.0      ## mesh to hơn (vành phố xa, phông chân trời) thì không đụng tới
const RESCAN := 2.0          ## bao lâu dò lại danh sách mesh của màn (đồ mới thêm, mesh đổi vật liệu)
const META := "cat_che_goc"

const SHADER := """
shader_type spatial;
render_mode %s;
global uniform vec3 cam_cut_from;
global uniform vec3 cam_cut_to;
global uniform float cam_cut_feet;
global uniform float cam_cut;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, hint_default_white, %s;
uniform float alpha_scissor_threshold = 0.5;
uniform bool use_vcol = false;
uniform bool vcol_srgb = false;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
varying vec3 world_pos;
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	if (use_vcol && vcol_srgb) {
		COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), COLOR.rgb * (1.0 / 12.92), lessThan(COLOR.rgb, vec3(0.04045)));
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (cam_cut > 0.0 && world_pos.y > cam_cut_feet) {
		vec3 ab = cam_cut_to - cam_cut_from;
		float len = length(ab);
		vec3 dir = ab / max(len, 0.001);
		vec3 af = world_pos - cam_cut_from;
		float t = dot(af, dir);
		if (t > 0.0 && t < len - 0.1) {
			float r = %f * clamp(t / len, 0.35, 1.0);
			float s = cam_cut * smoothstep(r, r * 0.45, length(af - dir * t)) * %f;
			ivec2 p = ivec2(FRAGCOORD.xy) %% 4;
			if ((BAYER[p.x + p.y * 4] + 0.5) / 16.0 < s) {
				discard;
			}
		}
	}
	vec4 c = albedo * texture(texture_albedo, UV);
	if (use_vcol) {
		c *= COLOR;
	}
	ALBEDO = c.rgb;
	%s
}
"""
const SCISSOR := "ALPHA = c.a;\n\tALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;"
const FILTERS := ["filter_nearest", "filter_linear", "filter_nearest_mipmap", "filter_linear_mipmap",
	"filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic"]
const LIT := "ROUGHNESS = roughness;\n\tMETALLIC = metallic;\n\tSPECULAR = specular;\n\tEMISSION = emission.rgb * emission_energy;"

var enabled := true                 ## tắt thì vật che vẽ như cũ (để so ảnh trước/sau)
var amount := 0.0                   ## độ cắt hiện tại 0..1
var _meshes: Array[MeshInstance3D] = []
var _scan_left := 0.0
var _swapped := {}                  ## id mesh → mesh đang mang vật liệu cắt
var _sync_left := 0.0
var _level: Node                    ## gốc màn chơi để dò mesh

static var _shaders := {}           ## render_mode → Shader
static var _cuts := {}              ## id vật liệu gốc → [vật liệu gốc, vật liệu cắt]


func _init(level: Node) -> void:
	_level = level
	name = "CatVatChe"


func _ready() -> void:
	# Bốn biến chung cam_cut_* khai trong project.godot ([shader_globals]) vì thêm lúc chạy cần hàm chỉ dành cho editor
	RenderingServer.global_shader_parameter_set("cam_cut", 0.0)


func _exit_tree() -> void:
	restore_all()
	RenderingServer.global_shader_parameter_set("cam_cut", 0.0)


## Gọi mỗi khung hình. on: có vật che giữa camera và Bơ. from: vị trí camera, to: giữa thân Bơ,
## feet: độ cao chân Bơ (điểm thấp hơn feet + 0,2 m không bị cắt).
func step(on: bool, from: Vector3, to: Vector3, feet: float, delta: float) -> void:
	amount = move_toward(amount, 1.0 if on and enabled else 0.0, SPEED * delta)
	if amount == 0.0:
		if not _swapped.is_empty():
			restore_all()
		RenderingServer.global_shader_parameter_set("cam_cut", 0.0)
		return
	RenderingServer.global_shader_parameter_set("cam_cut_from", from)
	RenderingServer.global_shader_parameter_set("cam_cut_to", to)
	RenderingServer.global_shader_parameter_set("cam_cut_feet", feet + 0.2)
	RenderingServer.global_shader_parameter_set("cam_cut", amount)
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = RESCAN
		_scan()
	_sync_left -= delta
	if _sync_left <= 0.0:
		_sync_left = 0.5
		_sync()
	# Mesh có hộp bao (nới thêm bán kính cắt) chạm đoạn camera → Bơ thì mang vật liệu cắt
	var near := {}
	for mi in _meshes:
		if not is_instance_valid(mi) or not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var box := (mi.global_transform * mi.get_aabb()).grow(RADIUS)
		if box.intersects_segment(from, to) or box.has_point(from):
			near[mi.get_instance_id()] = mi
	for id in _swapped.keys():
		if not near.has(id):
			_restore(_swapped[id])
			_swapped.erase(id)
	for id in near:
		if not _swapped.has(id) and _apply(near[id]):
			_swapped[id] = near[id]


func restore_all() -> void:
	for id in _swapped:
		_restore(_swapped[id])
	_swapped.clear()


## Dò mesh trong màn, bỏ qua mèo/chó/người có xương (thân nhân vật động, không cần cắt) và màn hình phụ.
func _scan() -> void:
	_meshes.clear()
	if is_instance_valid(_level):
		_walk(_level)


func _walk(n: Node) -> void:
	for c in n.get_children():
		if c is CharacterBody3D or c is Skeleton3D or c is SubViewport or c is CanvasLayer or c is Camera3D:
			continue
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var size := (c as MeshInstance3D).get_aabb().size * (c as MeshInstance3D).global_basis.get_scale()
			if maxf(size.x, maxf(size.y, size.z)) <= MAX_SIZE:
				_meshes.append(c)
		_walk(c)


func _apply(mi: MeshInstance3D) -> bool:
	var got := {}
	if mi.material_override != null:
		var cm := _cut_for(mi.material_override)
		if cm == null:
			return false
		got[-1] = [mi.material_override, cm]
		mi.material_override = cm
	else:
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var cm := _cut_for(src)
			if cm:
				got[i] = [mi.get_surface_override_material(i), cm]
				mi.set_surface_override_material(i, cm)
	if got.is_empty():
		return false
	mi.set_meta(META, got)
	return true


## Trả vật liệu gốc, trừ chỗ code khác đã thay vật liệu khác trong lúc đang cắt.
func _restore(mi: MeshInstance3D) -> void:
	if not is_instance_valid(mi) or not mi.has_meta(META):
		return
	var got: Dictionary = mi.get_meta(META)
	for i in got:
		if i == -1:
			if mi.material_override == got[i][1]:
				mi.material_override = got[i][0]
		elif i < mi.get_surface_override_material_count() and mi.get_surface_override_material(i) == got[i][1]:
			mi.set_surface_override_material(i, got[i][0])
	mi.remove_meta(META)


## Vật liệu gốc đổi màu/độ sáng lúc đang cắt (đèn tối bật, mưa ướt mái): chép sang bản cắt.
func _sync() -> void:
	for id in _cuts:
		var pair: Array = _cuts[id]
		if is_instance_valid(pair[0]) and _swapped.size() > 0:
			_copy(pair[0], pair[1])


## Bản vật liệu cắt của src (dùng chung cho mọi mesh cùng vật liệu), hoặc null nếu không đổi được.
static func _cut_for(src: Material) -> ShaderMaterial:
	if src == null:
		return null
	if _cuts.has(src.get_instance_id()):
		var pair: Array = _cuts[src.get_instance_id()]
		return pair[1] if pair[0] == src and convertible(src) else null
	if not convertible(src):
		return null
	var s := src as StandardMaterial3D
	var mode := "cull_disabled" if s.cull_mode == BaseMaterial3D.CULL_DISABLED else "cull_back"
	var lit := s.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if not lit:
		mode += ", unshaded"
	var tex: String = FILTERS[s.texture_filter] + (", repeat_enable" if s.texture_repeat else ", repeat_disable")
	var scissor := s.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var key := "%s|%s|%s" % [mode, tex, scissor]
	if not _shaders.has(key):
		var sh := Shader.new()
		var body := (LIT if lit else "") + ("\n\t" + SCISSOR if scissor else "")
		sh.code = SHADER % [mode, tex, RADIUS, 1.0 - KEEP, body]
		_shaders[key] = sh
	var cm := ShaderMaterial.new()
	cm.shader = _shaders[key]
	cm.render_priority = s.render_priority
	_copy(s, cm)
	_cuts[src.get_instance_id()] = [src, cm]
	return cm


static func _copy(src: StandardMaterial3D, cm: ShaderMaterial) -> void:
	cm.set_shader_parameter("albedo", src.albedo_color)
	cm.set_shader_parameter("texture_albedo", src.albedo_texture)
	cm.set_shader_parameter("use_vcol", src.vertex_color_use_as_albedo)
	cm.set_shader_parameter("vcol_srgb", src.vertex_color_is_srgb)
	cm.set_shader_parameter("uv1_scale", src.uv1_scale)
	cm.set_shader_parameter("uv1_offset", src.uv1_offset)
	cm.set_shader_parameter("roughness", src.roughness)
	cm.set_shader_parameter("metallic", src.metallic)
	cm.set_shader_parameter("specular", src.metallic_specular)
	cm.set_shader_parameter("emission", src.emission if src.emission_enabled else Color.BLACK)
	cm.set_shader_parameter("alpha_scissor_threshold", src.alpha_scissor_threshold)
	cm.set_shader_parameter("emission_energy", src.emission_energy_multiplier if src.emission_enabled else 0.0)


## Vật liệu chuẩn đục, chỉ dùng những tính năng bản cắt chép lại được.
static func convertible(m: Material) -> bool:
	var s := m as StandardMaterial3D
	if s == null or s.next_pass != null:
		return false
	return (s.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED or s.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR) \
		and s.shading_mode != BaseMaterial3D.SHADING_MODE_PER_VERTEX \
		and s.cull_mode != BaseMaterial3D.CULL_FRONT \
		and s.diffuse_mode == BaseMaterial3D.DIFFUSE_BURLEY and s.specular_mode == BaseMaterial3D.SPECULAR_SCHLICK_GGX \
		and s.blend_mode == BaseMaterial3D.BLEND_MODE_MIX and s.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY \
		and not s.no_depth_test and not s.disable_receive_shadows and not s.disable_ambient_light \
		and not s.shadow_to_opacity and not s.use_point_size and not s.fixed_size and not s.grow \
		and not s.normal_enabled and not s.rim_enabled and not s.clearcoat_enabled and not s.anisotropy_enabled \
		and not s.ao_enabled and not s.heightmap_enabled and not s.subsurf_scatter_enabled \
		and not s.backlight_enabled and not s.refraction_enabled and not s.detail_enabled \
		and not s.uv1_triplanar and s.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED \
		and s.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_DISABLED and not s.proximity_fade_enabled \
		and s.roughness_texture == null and s.metallic_texture == null and s.emission_texture == null \
		and (not s.emission_enabled or s.emission_operator == BaseMaterial3D.EMISSION_OP_ADD) \
		and s.texture_filter < FILTERS.size() and not s.alpha_antialiasing_mode
