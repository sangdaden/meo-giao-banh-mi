class_name GameSettings
extends RefCounted
## Cài đặt của người chơi, lưu ở user://cai_dat.cfg.
## Âm lượng không nằm ở đây: autoload Sound của luồng âm thanh tự lưu (user://am_thanh.cfg).

const PATH := "user://cai_dat.cfg"
const DEFAULTS := {
	"first_person": false,   # góc nhìn: false = thứ ba (sau lưng mèo), true = thứ nhất
	"sensitivity": 45,       # 0..100, 45 ứng với 0.0035 rad/px như camera gốc
	"invert_y": false,
	"quality": 1,            # 0 thấp, 1 vừa, 2 cao
	"fps_cap": 60,           # 30, 60, 0 = không giới hạn
	"shadows": true,
	"fullscreen": false,
	"show_fps": false,
	"hud_scale": 1,          # 0 nhỏ, 1 vừa, 2 to
	"hints": true,           # gợi ý phím góc phải dưới
	"tips": true,            # mẹo lần đầu (gầm thấp, gần Chó Mực, tới khách), mỗi mẹo hiện một lần
	"tips_seen": "",         # các mẹo đã hiện, cách nhau bằng dấu phẩy
	"thu_thach": false,
	"bong_ky_luc": false,     # bóng mờ chạy lại lần giao nhanh nhất của đơn (scripts/ghost.gd)      # Chế độ thử thách: dùng các con số khó cũ (scripts/do_kho.gd)
}

static var _data := {}
static var _loaded := false


static func get_value(key: String) -> Variant:
	_ensure()
	return _data.get(key, DEFAULTS.get(key))


static func set_value(key: String, value: Variant) -> void:
	_ensure()
	_data[key] = value
	save()


static func reset() -> void:
	_data = DEFAULTS.duplicate()
	save()


static func save() -> void:
	var cf := ConfigFile.new()
	for k in _data:
		cf.set_value("cai_dat", k, _data[k])
	cf.save(PATH)


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_data = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS:
			_data[k] = cf.get_value("cai_dat", k, DEFAULTS[k])


static func hud_scale_factor() -> float:
	return [0.85, 1.0, 1.2][clampi(get_value("hud_scale"), 0, 2)]


## Áp cài đặt hình ảnh cho cửa sổ và cảnh đang chạy.
static func apply_graphics(tree: SceneTree) -> void:
	Engine.max_fps = int(get_value("fps_cap"))
	if not OS.has_feature("web"):
		var fs: bool = get_value("fullscreen")
		var mode := DisplayServer.window_get_mode()
		var is_fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if fs != is_fs and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
	var vp := tree.root.get_viewport()
	var q: int = get_value("quality")
	vp.scaling_3d_scale = [0.7, 0.85, 1.0][clampi(q, 0, 2)]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(q, 0, 2)] if not OS.has_feature("web") else Viewport.MSAA_DISABLED
	var shadows: bool = get_value("shadows")
	if tree.current_scene:
		for light in tree.current_scene.find_children("*", "DirectionalLight3D", true, false):
			if not light.is_in_group("den_phu"):  # đèn phụ (ánh trời) không bao giờ đổ bóng
				light.shadow_enabled = shadows


## Áp cài đặt camera cho rig (rig của luồng màn chơi: group "camera_rig").
## Kiểm tra từng thuộc tính để chạy được cả khi rig chưa có góc nhìn thứ nhất.
static func apply_camera(tree: SceneTree) -> void:
	var rig := tree.get_first_node_in_group("camera_rig")
	if rig == null and tree.current_scene:
		rig = tree.current_scene.get_node_or_null("CameraRig")
	if rig == null:
		return
	if "first_person" in rig:
		rig.first_person = get_value("first_person")
	if "mouse_sensitivity" in rig:
		rig.mouse_sensitivity = lerpf(0.001, 0.007, float(get_value("sensitivity")) / 100.0)
	if "invert_y" in rig:
		rig.invert_y = get_value("invert_y")


## Rig phát view_changed khi người chơi bấm V: lưu lại lựa chọn.
static func watch_camera(tree: SceneTree) -> void:
	var rig := tree.get_first_node_in_group("camera_rig")
	if rig and rig.has_signal("view_changed"):
		var cb := func(fp: bool) -> void: set_value("first_person", fp)
		if not rig.is_connected("view_changed", cb):
			rig.connect("view_changed", cb)
