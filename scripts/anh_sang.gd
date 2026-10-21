class_name AnhSang
## Ánh sáng và không khí theo phong cách D (docs/huong-dan-phong-cach.md): nắng ấm làm đèn chính,
## ánh trời xanh bạc hà nhẹ làm đèn phụ phía đối diện, bóng đổ mềm hơi xanh, sương sớm ấm ở xa.
## Dùng chung cho màn giao bánh (phố buổi sáng) và màn bếp, chạy được cả hai renderer:
## - Forward+ (bản PC): SSAO nhẹ, bóng 2 tầng xa hơn.
## - Compatibility (bản web, WebGL 2): cùng màu nhưng giảm cường độ (renderer này sáng gắt hơn),
##   không SSAO, bóng 1 tầng gần mèo cho nhẹ.
## Thêm buổi khác (trưa, chiều, tối) cho các ngày sau: thêm một mục vào PRESETS.

const PRESETS := {
	# Thứ Hai 6 giờ 30: mặt trời thấp phía đông đông nam, bóng nhà dài đổ xuống đường.
	"pho_sang": {
		"sun_rot": Vector3(-30, 60, 0),
		"sun_color": Color("#FFD7A3"),
		"sun_energy": [1.45, 0.85],        # [Forward+, Compatibility]
		"fill_rot": Vector3(-35, -120, 0), # ánh trời từ phía tây bắc, không đổ bóng
		"fill_color": Color("#A9D4E0"),
		"fill_energy": [0.35, 0.22],
		"ambient": Color("#BCD0E2"),
		"ambient_energy": [0.55, 0.46],
		"sky_top": Color("#5FA6CF"),
		"sky_horizon": Color("#F6D3A4"),
		"ground_horizon": Color("#E9CFA8"),
		"ground_bottom": Color("#8F8B80"),
		"fog": Color("#F3D8B4"),
		"fog_density": [0.0035, 0.0075],
		"shadow_distance": [42.0, 26.0],
		"exposure": [1.0, 1.0],
	},
	# Bếp Cô Ba buổi sáng: nắng xiên qua cửa sổ sau, đèn bàn vàng, lò lửa cam.
	# Tường vàng, sàn kem nên bếp rất dễ lóa: giữ nắng và ánh môi trường thấp, ánh môi trường
	# trung tính (không vàng) để đồ trên bàn tách khỏi tường, giảm bóng loáng mặt bàn.
	"bep_sang": {
		"sun_rot": Vector3(-50, 25, 0),
		"sun_color": Color("#FFE6C8"),
		"sun_energy": [0.62, 0.34],
		"sun_specular": 0.25,
		"fill_rot": Vector3(-25, -160, 0),
		"fill_color": Color("#C4DCE6"),
		"fill_energy": [0.3, 0.16],
		"ambient": Color("#D8DCDC"),
		"ambient_energy": [0.38, 0.2],
		"background": Color("#2A2620"),
		"shadow_distance": [14.0, 10.0],
		"exposure": [0.92, 1.0],
		"contrast": 1.08,
		"saturation": 1.1,
	},
}


## Bản web (WebGL) chạy renderer Compatibility: không có RenderingDevice.
static func is_compat() -> bool:
	return RenderingServer.get_rendering_device() == null


## Dựng WorldEnvironment + mặt trời + đèn phụ cho `preset`, gắn vào parent. Trả về mặt trời.
static func build(parent: Node, preset: String) -> DirectionalLight3D:
	var p: Dictionary = PRESETS[preset]
	var q := 1 if is_compat() else 0  # chỉ số trong các cặp [Forward+, Compatibility]
	var env := Environment.new()
	if p.has("sky_top"):
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = p.sky_top
		sm.sky_horizon_color = p.sky_horizon
		sm.sky_curve = 0.12
		sm.ground_horizon_color = p.ground_horizon
		sm.ground_bottom_color = p.ground_bottom
		sm.sun_angle_max = 20.0
		sm.sun_curve = 0.08
		sky.sky_material = sm
		sky.radiance_size = Sky.RADIANCE_SIZE_64  # trời không phản chiếu nhiều, bản đồ nhỏ cho nhẹ
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = p.background
	# Ánh sáng môi trường màu trơn: hai renderer ra giống nhau, và bóng đổ ngả xanh nhẹ như ảnh phong cách D.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = p.ambient
	env.ambient_light_energy = p.ambient_energy[q]
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_exposure = p.exposure[q]
	# Cả hai bản đều tonemap tuyến tính: màu phẳng, ấm, bão hoà vừa như ảnh phong cách D,
	# và bản PC với bản web nhìn giống nhau (filmic của Godot 4.3 làm màu xám bạc đi).
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if q == 0:
		env.ssao_enabled = true
		env.ssao_radius = 0.8
		env.ssao_intensity = 1.2
		env.ssao_light_affect = 0.1
		env.adjustment_enabled = true
		env.adjustment_saturation = p.get("saturation", 1.06)
		env.adjustment_contrast = p.get("contrast", 1.0)
	if p.has("fog"):
		env.fog_enabled = true
		env.fog_light_color = p.fog
		env.fog_density = p.fog_density[q]
		env.fog_sun_scatter = 0.25
		env.fog_sky_affect = 0.1
		env.fog_aerial_perspective = 0.15
	var world := WorldEnvironment.new()
	world.name = "MoiTruong"
	world.environment = env
	parent.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "MatTroi"
	sun.rotation_degrees = p.sun_rot
	sun.light_color = p.sun_color
	sun.light_energy = p.sun_energy[q]
	sun.light_specular = p.get("sun_specular", 0.5)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5        # bóng mềm, không viền gắt
	# WebGL cần lệch bóng nhiều hơn, không thì mặt đường lớn bị sọc (shadow acne)
	sun.shadow_bias = 0.04 if q == 0 else 0.1
	sun.shadow_normal_bias = 1.2 if q == 0 else 2.5
	sun.directional_shadow_max_distance = p.shadow_distance[q]
	sun.directional_shadow_fade_start = 0.85
	if q == 0 and p.shadow_distance[q] > 20.0:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_blend_splits = true
	else:
		# Web: một tầng bóng, mỗi vật chỉ vẽ thêm một lần cho bóng
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	parent.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "AnhTroi"
	fill.rotation_degrees = p.fill_rot
	fill.light_color = p.fill_color
	fill.light_energy = p.fill_energy[q]
	fill.light_specular = 0.0
	fill.shadow_enabled = false
	fill.add_to_group("den_phu")  # cài đặt "Bóng đổ" không bật bóng cho đèn này
	parent.add_child(fill)

	if GiuFps.wanted():
		var guard := GiuFps.new()
		guard.name = "GiuFps"
		guard.setup(sun)
		parent.add_child(guard)
	return sun
