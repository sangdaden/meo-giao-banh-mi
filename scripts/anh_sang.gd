class_name AnhSang
## Ánh sáng và không khí theo phong cách D (docs/huong-dan-phong-cach.md): nắng ấm làm đèn chính,
## ánh trời xanh bạc hà nhẹ làm đèn phụ phía đối diện, bóng đổ mềm hơi xanh, sương sớm ấm ở xa.
## Dùng chung cho màn giao bánh (phố buổi sáng) và màn bếp, chạy được cả hai renderer:
## - Forward+ (bản PC): SSAO nhẹ, bóng 2 tầng xa hơn.
## - Compatibility (bản web, WebGL 2): cùng màu nhưng giảm cường độ (renderer này sáng gắt hơn),
##   không SSAO, bóng 1 tầng gần mèo cho nhẹ.
## Mỗi ngày chơi một buổi (trang phác thảo G4 Sang duyệt 21/10): xem DAY_PRESET. Buổi mưa thêm ThoiTiet
## (scripts/thoi_tiet.gd), buổi chiều tối thêm DenToi (đèn lồng, chỉ vài đèn gần mèo được thắp).
## Thử một buổi: chạy với -- --buoi=pho_mua (hoặc --ngay=thu_tu).

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
	# Thứ Ba 7 giờ: chợ sáng đông, nắng lên cao hơn một chút, sương ấm che phố xa.
	"pho_cho": {
		"sun_rot": Vector3(-36, 50, 0),
		"sun_color": Color("#FFE2B8"),
		"sun_energy": [1.35, 0.8],
		"fill_rot": Vector3(-35, -120, 0),
		"fill_color": Color("#A9D4E0"),
		"fill_energy": [0.35, 0.22],
		"ambient": Color("#C4D4E0"),
		"ambient_energy": [0.58, 0.48],
		"sky_top": Color("#7DB5D4"),
		"sky_horizon": Color("#F3DDBA"),
		"ground_horizon": Color("#E9CFA8"),
		"ground_bottom": Color("#8F8B80"),
		"fog": Color("#F1DDBF"),
		"fog_density": [0.005, 0.009],
		"shadow_distance": [42.0, 26.0],
		"exposure": [1.0, 1.0],
	},
	# Thứ Tư 15 giờ: mưa chiều xám. Trời đục nên tắt bóng nắng (web nhẹ hơn hẳn), ánh môi trường
	# lạnh và đều, phản chiếu lấy từ trời để mặt ướt và vũng nước bóng lên.
	"pho_mua": {
		"sun_rot": Vector3(-40, -70, 0),
		"sun_color": Color("#C9D3D8"),
		"sun_energy": [0.16, 0.1],
		"shadows": false,
		"fill_rot": Vector3(-30, 110, 0),
		"fill_color": Color("#B8C6CE"),
		"fill_energy": [0.25, 0.18],
		"ambient": Color("#9AA8B0"),
		"ambient_energy": [0.9, 0.75],
		"sky_top": Color("#6D7B86"),
		"sky_horizon": Color("#9AA7AE"),
		"ground_horizon": Color("#8E9AA0"),
		"ground_bottom": Color("#5E6468"),
		"fog": Color("#A9B3B8"),
		"fog_density": [0.012, 0.02],
		"shadow_distance": [30.0, 20.0],
		"exposure": [1.0, 1.0],
		"reflect_sky": true,
		"weather": "mua",
	},
	# Thứ Năm 11 giờ 30: trưa oi, mặt trời gần đỉnh nên bóng ngắn, rút tầm bóng cho nét.
	"pho_trua": {
		"sun_rot": Vector3(-76, 10, 0),
		"sun_color": Color("#FFF3DC"),
		"sun_energy": [1.45, 0.6],
		"fill_rot": Vector3(-35, -120, 0),
		"fill_color": Color("#B4D6E2"),
		"fill_energy": [0.3, 0.2],
		"ambient": Color("#D0DCE0"),
		"ambient_energy": [0.56, 0.42],
		"sky_top": Color("#8EC0DD"),
		"sky_horizon": Color("#E4ECEC"),
		"ground_horizon": Color("#E6DDC8"),
		"ground_bottom": Color("#8F8B80"),
		"fog": Color("#F4E9D2"),
		"fog_density": [0.006, 0.011],
		"shadow_distance": [36.0, 20.0],
		"exposure": [0.94, 0.92],
	},
	# Thứ Sáu 17 giờ 30: chiều tà, nắng cam thấp từ phía tây, đèn lồng các tiệm đã thắp.
	"pho_chieu": {
		"sun_rot": Vector3(-11, -80, 0),
		"sun_color": Color("#FF9C5C"),
		"sun_energy": [1.2, 0.7],
		"fill_rot": Vector3(-35, 100, 0),
		"fill_color": Color("#8FA9D0"),
		"fill_energy": [0.3, 0.2],
		"ambient": Color("#C2B2B8"),
		"ambient_energy": [0.5, 0.42],
		"sky_top": Color("#6E8FB5"),
		"sky_horizon": Color("#E3A985"),
		"ground_horizon": Color("#C89A7C"),
		"ground_bottom": Color("#6E6660"),
		"fog": Color("#E8B48F"),
		"fog_density": [0.004, 0.008],
		"shadow_distance": [42.0, 14.0],  # nắng thấp, bóng rất dài: web rút tầm bóng để giữ tam giác trong ngân sách
		"exposure": [1.0, 1.0],
		"lights": 0.7,
	},
	# Thứ Bảy 18 giờ 15: hoàng hôn tím hồng, nắng sát chân trời, đèn sáng hơn.
	"pho_hoang_hon": {
		"sun_rot": Vector3(-3, -85, 0),
		"sun_color": Color("#FF7448"),
		"sun_energy": [0.75, 0.45],
		"fill_rot": Vector3(-35, 100, 0),
		"fill_color": Color("#7D86C0"),
		"fill_energy": [0.3, 0.2],
		"ambient": Color("#A08AA6"),
		"ambient_energy": [0.5, 0.42],
		"sky_top": Color("#4E5C8E"),
		"sky_horizon": Color("#B58BA8"),
		"ground_horizon": Color("#8E7590"),
		"ground_bottom": Color("#4A4550"),
		"fog": Color("#B58BA8"),
		"fog_density": [0.005, 0.009],
		"shadow_distance": [42.0, 18.0],  # nắng thấp, bóng rất dài: web rút tầm bóng để giữ tam giác trong ngân sách
		"exposure": [1.0, 1.0],
		"lights": 1.0,
	},
	# Chủ Nhật 19 giờ 30: tối Hội mèo. Trăng xanh nhạt không đổ bóng; ánh sáng chính là đèn lồng.
	# Ánh môi trường giữ đủ sáng để luôn thấy rõ mèo và đường đi.
	"pho_toi": {
		"sun_rot": Vector3(-35, -120, 0),
		"sun_color": Color("#9DB3E6"),
		"sun_energy": [0.1, 0.06],
		"shadows": false,
		"fill_rot": Vector3(-40, 60, 0),
		"fill_color": Color("#5A6FA8"),
		"fill_energy": [0.18, 0.12],
		"ambient": Color("#3A4A72"),
		"ambient_energy": [0.55, 0.42],
		"sky_top": Color("#0E1530"),
		"sky_horizon": Color("#1E2A48"),
		"ground_horizon": Color("#1A2236"),
		"ground_bottom": Color("#0E121C"),
		"fog": Color("#1E2A48"),
		"fog_density": [0.006, 0.01],
		"shadow_distance": [30.0, 20.0],
		"exposure": [1.0, 1.0],
		"reflect_sky": true,
		"lights": 1.6,
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


## Buổi của từng ngày chơi (scripts/days.gd ORDER).
## Thứ Bảy bắt đầu buổi sáng; scripts/thu_bay.gd ngả trời dần tới pho_hoang_hon theo số việc đã giúp.
const DAY_PRESET := {
	"thu_hai": "pho_sang", "thu_ba": "pho_cho", "thu_tu": "pho_mua", "thu_nam": "pho_trua",
	"thu_sau": "pho_chieu", "thu_bay": "pho_sang", "chu_nhat": "pho_toi",
}


## Preset phố cho ngày `day`; tham số -- --buoi=<preset> ghi đè để thử.
static func preset_for_day(day: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--buoi=") and PRESETS.has(a.substr(7)):
			return a.substr(7)
	return DAY_PRESET.get(day, "pho_sang")


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
	# Buổi mưa, buổi tối: lấy phản chiếu từ trời để mặt ướt bóng lên (bản đồ trời 64 px nên rẻ)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if p.get("reflect_sky", false) and p.has("sky_top") \
		else Environment.REFLECTION_SOURCE_DISABLED
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
	sun.shadow_enabled = p.get("shadows", true)
	if not sun.shadow_enabled:
		sun.add_to_group("den_phu")  # trời đục, trăng: cài đặt "Bóng đổ" cũng không bật bóng
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

	if p.get("weather", "") == "mua":
		var rain := ThoiTiet.new()
		rain.name = "ThoiTiet"
		parent.add_child(rain)
	if p.get("lights", 0.0) > 0.0:
		var lamps := DenToi.new()
		lamps.name = "DenToi"
		lamps.strength = p.lights
		lamps.add_to_group("den_toi")
		parent.add_child(lamps)
		Tiem.glow.call_deferred(parent.get_tree(), p.lights)  # đèn lồng tiệm Cô Ba người chơi đã bày (dựng phố sau)

	if GiuFps.wanted():
		var guard := GiuFps.new()
		guard.name = "GiuFps"
		guard.setup(sun)
		parent.add_child(guard)
	return sun


## Bếp: khi camera lướt vào cận cảnh một trạm, khung hình chỉ còn mặt bàn trong vài chục cm nên
## nắng và đèn bàn chiếu thẳng làm khay, bột, sàn kem cháy trắng, còn bóng (bản đồ bóng phủ cả bếp)
## bị răng cưa. Lúc cận cảnh: bóng chỉ phủ 2,5 m quanh camera (nét gấp ~5 lần), nắng và độ phơi
## sáng giảm. Ra toàn cảnh thì trả lại như cũ, chuyển mượt.
## `cam` cần hàm is_close() (scripts/kitchen_camera.gd).
static func watch_close_up(parent: Node, cam: Node) -> void:
	var w := CanCanh.new()
	w.name = "AnhSangCanCanh"
	w.cam = cam
	w.sun = parent.get_node_or_null("MatTroi")
	var world: WorldEnvironment = parent.get_node_or_null("MoiTruong")
	w.env = world.environment if world else null
	parent.add_child(w)


class CanCanh extends Node:
	const SHADOW_CLOSE := 2.5
	const SUN_CLOSE := 0.85      ## nhân với độ sáng nắng khi cận cảnh
	const EXPOSURE_CLOSE := 0.88 ## nhân với độ phơi sáng khi cận cảnh
	var cam: Node
	var sun: DirectionalLight3D
	var env: Environment
	var _shadow := 0.0
	var _energy := 0.0
	var _exposure := 1.0
	var _k := 0.0  ## 0 = toàn cảnh, 1 = cận cảnh

	func _ready() -> void:
		if sun:
			_shadow = sun.directional_shadow_max_distance
			_energy = sun.light_energy
		if env:
			_exposure = env.tonemap_exposure

	func _process(delta: float) -> void:
		if cam == null or sun == null or not cam.has_method("is_close"):
			return
		var goal := 1.0 if cam.is_close() else 0.0
		if is_equal_approx(goal, _k):
			return
		_k = move_toward(_k, goal, delta * 4.0)
		# Tầm bóng đổi ngay để khỏi thấy bóng co giãn; giữ phần GiuFps đã rút ngắn (nếu có)
		sun.directional_shadow_max_distance = minf(_shadow, SHADOW_CLOSE) if goal > 0.5 else _shadow
		sun.light_energy = _energy * lerpf(1.0, SUN_CLOSE, _k)
		if env:
			env.tonemap_exposure = _exposure * lerpf(1.0, EXPOSURE_CLOSE, _k)

