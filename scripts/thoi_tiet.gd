class_name ThoiTiet
extends Node3D
## Mưa cho màn phố (gói G4 "Ánh sáng và thời tiết", Sang duyệt 21/10). AnhSang.build thêm nút này cho
## preset có "weather": "mua". Mưa chỉ làm trơn và ngập, không làm hỏng bánh (bánh bọc ni-lông).
## - Hạt mưa: một GPUParticles3D trong hộp 14×10 m đi theo camera (1 lệnh vẽ).
## - Vòng nước bắn: một GPUParticles3D trên mặt đất quanh camera (1 lệnh vẽ).
## - Vũng nước: gộp thành một mesh phẳng, không đổ bóng. Bản web không có SSR nên shader trộn màu trời
##   theo góc nhìn (fresnel) cho giống mặt nước soi trời.
## - Mặt ướt: đổi một lần vật liệu dùng chung của phố (PhoModels, Blocks) sang tối hơn, bóng hơn;
##   rời màn thì trả lại như cũ.
## - Nước ngập: ngap(muc_nuoc, giay) dâng mặt nước dọc lòng đường lớn (màn Thứ Tư dùng; thử: -- --ngap).

const BOX := Vector3(14.0, 8.0, 10.0)   ## hộp rơi của hạt mưa quanh camera (rộng, cao, sâu)
const DROPS := [1500, 900]               ## số hạt [Forward+, Compatibility]
const SPLASHES := [220, 140]
const FALL_SPEED := 9.0
const WET_DARKEN := Color(0.78, 0.8, 0.84)
const WET_ROUGH := 0.3
const ROAD_HALF := 4.9                   ## nửa bề rộng lòng đường lớn (z), như City
const WATER := Color("#2A3436")
const SKY_TINT := Color("#7C8A92")
## Vũng nước dọc đường giao bánh: x, z, bán kính x, bán kính z (mét). Đặt ở mép lề và ổ gà, tránh vạch qua đường.
const PUDDLES := [
	Vector4(-34.2, -4.6, 1.3, 0.55), Vector4(-30.4, -3.2, 0.9, 0.7), Vector4(-27.6, -0.8, 1.6, 0.8),
	Vector4(-38.6, -4.3, 0.8, 0.45), Vector4(-31.8, 1.6, 1.1, 0.6), Vector4(-19.0, 3.4, 1.2, 0.6),
	Vector4(-8.5, -3.9, 1.4, 0.6), Vector4(2.0, 3.0, 1.0, 0.7), Vector4(9.5, -2.2, 1.3, 0.5),
	Vector4(17.5, 4.0, 0.9, 0.5), Vector4(26.0, -3.6, 1.5, 0.7), Vector4(34.0, 2.4, 1.1, 0.6),
]

var rain: GPUParticles3D
var splash: GPUParticles3D
var flood: MeshInstance3D
var _wet := {}   ## vật liệu -> [albedo_color, roughness] để trả lại khi rời màn
var _flood_goal := 0.0
var _flood_speed := 0.0


func _ready() -> void:
	add_to_group("giam_hat")
	var q := 1 if AnhSang.is_compat() else 0
	rain = _make_rain(DROPS[q])
	splash = _make_splash(SPLASHES[q])
	add_child(_make_puddles())
	_make_wet.call_deferred()
	if "--ngap" in OS.get_cmdline_user_args():
		ngap.call_deferred(0.09, 0.0)  # sau khi main gộp khối tĩnh, kẻo mặt nước bị gộp mất


func _exit_tree() -> void:
	lam_uot(false)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := cam.global_position
		# Hạt mưa không đi theo camera (local_coords tắt), chỉ chỗ sinh hạt đi theo
		rain.global_position = Vector3(p.x, p.y + BOX.y * 0.6, p.z)
		splash.global_position = Vector3(p.x, 0.0, p.z)
	if flood and not is_equal_approx(flood.position.y, _flood_goal):
		flood.position.y = move_toward(flood.position.y, _flood_goal, _flood_speed * delta)
		flood.visible = flood.position.y > 0.005


## GiuFps hạ bậc trên máy yếu: bớt một nửa hạt mưa và vòng bắn.
func giam() -> void:
	rain.amount = maxi(200, rain.amount / 2)
	splash.amount = maxi(40, splash.amount / 2)


## Bật hoặc tắt mặt ướt cho vật liệu dùng chung của phố.
func lam_uot(on: bool) -> void:
	if on:
		var mats: Array = [PhoModels.material()]
		for m in Blocks._materials.values():
			var sm := m as StandardMaterial3D
			if sm.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				mats.append(sm)
		for m in mats:
			if _wet.has(m):
				continue
			_wet[m] = [m.albedo_color, m.roughness]
			m.albedo_color = m.albedo_color * WET_DARKEN
			m.roughness = minf(m.roughness, WET_ROUGH)
	else:
		for m in _wet:
			m.albedo_color = _wet[m][0]
			m.roughness = _wet[m][1]
		_wet.clear()


## Dâng (hoặc rút) mặt nước ngập dọc lòng đường lớn tới `muc` mét trong `giay` giây.
func ngap(muc: float, giay: float) -> void:
	if flood == null:
		flood = _make_flood()
		add_child(flood)
	_flood_goal = muc
	_flood_speed = absf(muc - flood.position.y) / maxf(giay, 0.001)
	if giay <= 0.0:
		flood.position.y = muc
		flood.visible = muc > 0.005


# ---------------------------------------------------------------- dựng

func _make_wet() -> void:
	lam_uot(true)


func _make_rain(n: int) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(BOX.x / 2.0, 0.5, BOX.z / 2.0)
	pm.direction = Vector3(0.12, -1, 0)   # nghiêng 7° như phác thảo
	pm.spread = 2.0
	pm.initial_velocity_min = FALL_SPEED * 0.9
	pm.initial_velocity_max = FALL_SPEED * 1.1
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.7
	pm.scale_max = 1.25
	var quad := QuadMesh.new()
	quad.size = Vector2(0.013, 0.42)        # vệt mưa: Ø 1,3 cm, dài 0,42 m
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color("#DCEBF2", 0.38)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	quad.material = m
	var p := GPUParticles3D.new()
	p.name = "HatMua"
	p.amount = n
	p.lifetime = (BOX.y + 1.0) / FALL_SPEED
	p.preprocess = p.lifetime
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-BOX.x, -BOX.y * 1.4, -BOX.z), BOX * 2.0)
	add_child(p)
	return p


func _make_splash(n: int) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(BOX.x / 2.0 - 1.0, 0.0, BOX.z / 2.0 - 1.0)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	var grow := Curve.new()                 # vành nở từ 30% lên đủ cỡ rồi tan
	grow.add_point(Vector2(0, 0.3))
	grow.add_point(Vector2(1, 1))
	var ct := CurveTexture.new()
	ct.curve = grow
	pm.scale_curve = ct
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)           # vành Ø 9 cm
	quad.orientation = PlaneMesh.FACE_Y
	var ring := Gradient.new()              # vòng sáng mảnh, giữa và ngoài trong suốt
	ring.offsets = PackedFloat32Array([0.0, 0.55, 0.75, 0.95])
	ring.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = ring
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.albedo_color = Color("#E4F1F5", 0.8)
	m.vertex_color_use_as_albedo = true
	quad.material = m
	var p := GPUParticles3D.new()
	p.name = "VongBan"
	p.amount = n
	p.lifetime = 0.25
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = quad
	p.position.y = 0.05
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-BOX.x, -1, -BOX.z), Vector3(BOX.x * 2.0, 2, BOX.z * 2.0))
	add_child(p)
	return p


## Mặt nước soi trời: tối ở chỗ nhìn thẳng xuống, sáng màu trời ở góc nhìn xiên, có đốm nắng.
static func water_material(base: Color, sky: Color, waves := false) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 base_color : source_color;
uniform vec3 sky_color : source_color;
uniform bool waves = false;
void vertex() {
	if (waves) {
		VERTEX.y += sin(VERTEX.x * 1.7 + TIME * 1.3) * 0.006 + sin(VERTEX.z * 2.3 - TIME * 1.1) * 0.004;
	}
}
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(base_color, sky_color, 0.1 + 0.55 * f);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("sky_color", sky)
	m.set_shader_parameter("waves", waves)
	return m


func _make_puddles() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var n := 20
	for i in PUDDLES.size():
		var pd: Vector4 = PUDDLES[i]
		# trên vỉa hè (|z| > lòng đường) thì nâng lên bằng mặt vỉa hè
		var y := 0.012 if absf(pd.y) < ROAD_HALF else 0.05
		var c := Vector3(pd.x, y, pd.y)
		var ring: Array[Vector3] = []
		for k in n:
			var a := TAU * k / n
			var r := 1.0 + 0.18 * sin(a * 3.0 + i) + rng.randf_range(-0.06, 0.06)
			ring.append(c + Vector3(cos(a) * pd.z * r, 0, sin(a) * pd.w * r))
		for k in n:
			st.add_vertex(c)
			st.add_vertex(ring[(k + 1) % n])
			st.add_vertex(ring[k])
	var mi := MeshInstance3D.new()
	mi.name = "VungNuoc"
	mi.mesh = st.commit()
	mi.material_override = water_material(WATER, SKY_TINT)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _make_flood() -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(120.0, ROAD_HALF * 2.0)
	pm.subdivide_width = 60
	pm.subdivide_depth = 4
	var mi := MeshInstance3D.new()
	mi.name = "NuocNgap"
	mi.mesh = pm
	mi.material_override = water_material(Color("#4E5E58"), SKY_TINT, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0, 0)
	mi.visible = false
	return mi
