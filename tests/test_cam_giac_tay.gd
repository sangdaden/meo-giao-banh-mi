extends SceneTree
## DK1–DK3 "Cảm giác tay và camera" (scripts/camera_rig.gd, scripts/cam_giac_tay.gd):
## - DK1: chạy chéo mà buông chuột thì camera tự quay ra sau lưng Bơ; mới xoay chuột hoặc tắt công tắc thì không.
## - DK2: đáp từ cao thì tung bụi và camera nảy; phanh gấp thì bụi; bị hất văng thì rung tay cầm.
## - DK3: FOV theo cài đặt, giãn khi chạy nhanh, tắt được.
## Chạy: godot --headless --path . -s tests/test_cam_giac_tay.gd

var m: Node3D
var bo: CharacterBody3D
var rig: Node3D
var cg: CamGiacTay
var fails := 0
var _cu := {}


func _init() -> void:
	PlayMode.day = "thu_hai"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	GameState.use_test_save("user://luu_game_test_cam_giac_tay.cfg")
	for k in ["cam_sau_lung", "fov", "fov_chay", "camera_nay", "rung_tay_cam", "first_person"]:
		_cu[k] = GameSettings.get_value(k)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _dat(key: String, value: Variant) -> void:
	GameSettings.set_value(key, value)
	GameSettings.apply_camera(self)


## Chỗ trống bằng phẳng trên đường trước lò bánh
func _put(p: Vector3) -> void:
	bo.global_position = p
	bo.velocity = Vector3.ZERO
	await _frames(20)


func _release_all() -> void:
	for a in ["move_forward", "move_right", "move_left", "sprint"]:
		Input.action_release(a)


func _run() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(30)
	bo = m.player
	rig = m.get_node("CameraRig")
	cg = rig.get_node("CamGiacTay")
	_dat("first_person", false)
	_dat("cam_sau_lung", true)
	_dat("fov", 70)
	_dat("fov_chay", true)
	_dat("camera_nay", true)
	_dat("rung_tay_cam", true)
	var start: Vector3 = City.BAKERY_POINT + Vector3(0, 0.1, 6.0)

	print("DK1 camera về sau lưng")
	await _put(start)
	rig.yaw = 0.0
	rig._manual_ms = -100000
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await _frames(150)
	_release_all()
	_check(absf(rig.yaw) > 0.25, "chạy chéo, buông chuột 2,5 s: camera quay theo hướng chạy (yaw %.2f)" % rig.yaw)

	await _put(start)
	rig.yaw = 0.0
	rig._manual_ms = Time.get_ticks_msec()  # vừa xoay chuột
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await _frames(60)
	_release_all()
	_check(absf(rig.yaw) < 0.02, "vừa xoay chuột thì camera nhường người chơi (yaw %.2f)" % rig.yaw)

	_dat("cam_sau_lung", false)
	await _put(start)
	rig.yaw = 0.0
	rig._manual_ms = -100000
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await _frames(150)
	_release_all()
	_check(absf(rig.yaw) < 0.02, "tắt công tắc thì camera giữ nguyên (yaw %.2f)" % rig.yaw)
	_dat("cam_sau_lung", true)

	await _put(start)
	rig.yaw = 0.0
	rig._manual_ms = -100000
	Input.action_press("move_right")
	await _frames(150)
	_release_all()
	_check(absf(rig.yaw) < 0.02, "đi ngang thẳng (A/D) thì không xoay vòng (yaw %.2f)" % rig.yaw)

	print("DK3 góc nhìn")
	_dat("fov", 85)
	await _put(start)
	await _frames(90)
	_check(absf(rig.camera.fov - 85.0) < 0.5, "FOV theo cài đặt (%.1f)" % rig.camera.fov)
	rig._manual_ms = Time.get_ticks_msec() + 100000  # giữ hướng camera, chỉ đo FOV
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(60)
	var f_run: float = rig.camera.fov
	_release_all()
	_check(f_run > 89.0, "chạy nhanh thì góc nhìn giãn (%.1f)" % f_run)
	_dat("fov_chay", false)
	await _put(start)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(60)
	f_run = rig.camera.fov
	_release_all()
	_check(absf(f_run - 85.0) < 0.5, "tắt giãn thì FOV đứng yên khi chạy (%.1f)" % f_run)
	_dat("fov_chay", true)
	_dat("fov", 70)

	print("DK2 phanh gấp")
	await _put(start)
	var n0 := cg.so_lan_phanh
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(50)
	_release_all()
	await _frames(10)
	_check(cg.so_lan_phanh > n0 and cg._phanh.visible, "đang chạy nhanh thả phím thì tung bụi phanh")
	await _frames(60)
	_check(not cg._phanh.visible, "bụi tan xong thì ẩn (không tốn lệnh vẽ)")
	_check(cg._phanh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and cg._phanh.visibility_range_end > 0.0,
		"bụi không đổ bóng, có visibility_range")
	await _put(start)
	n0 = cg.so_lan_phanh
	Input.action_press("move_forward")
	await _frames(50)
	_release_all()
	await _frames(10)
	_check(cg.so_lan_phanh == n0, "đi thường dừng lại thì không có bụi phanh")

	print("DK2 đáp từ cao")
	await _put(start)
	var b0 := cg.so_lan_bui
	bo.global_position = start + Vector3.UP * 3.5
	var min_bump := 0.0
	for i in 120:
		await physics_frame
		min_bump = minf(min_bump, rig._bump)
	_check(cg.so_lan_bui > b0, "rơi 3,5 m: bụi tung khi đáp")
	_check(min_bump < -0.03, "rơi 3,5 m: camera nảy xuống (%.3f m)" % min_bump)
	_check(absf(rig._bump) < 0.005, "camera nảy xong về chỗ cũ")
	_dat("camera_nay", false)
	await _put(start)
	bo.global_position = start + Vector3.UP * 3.5
	min_bump = 0.0
	for i in 120:
		await physics_frame
		min_bump = minf(min_bump, rig._bump)
	_check(min_bump == 0.0, "tắt camera nảy thì không nảy")
	_dat("camera_nay", true)
	await _put(start)
	b0 = cg.so_lan_bui
	bo.global_position = start + Vector3.UP * 0.6
	await _frames(60)
	_check(cg.so_lan_bui == b0, "nhảy thấp không tung bụi")

	print("DK2 rung tay cầm")
	var r0 := cg.so_lan_rung
	bo.knockback(bo.global_position + Vector3.FORWARD)
	await _frames(5)
	_check(cg.so_lan_rung == r0 + 1, "bị hất văng thì rung tay cầm")
	_dat("rung_tay_cam", false)
	await _frames(40)
	bo.knockback(bo.global_position + Vector3.FORWARD)
	await _frames(5)
	_check(cg.so_lan_rung == r0 + 1, "tắt rung thì không rung")

	for k in _cu:
		GameSettings.set_value(k, _cu[k])
	print("CAM GIAC TAY OK" if fails == 0 else "CAM GIAC TAY LỖI: %d" % fails)
	quit(1 if fails else 0)
