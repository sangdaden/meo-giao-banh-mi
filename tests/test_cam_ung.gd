extends SceneTree
## G3 chơi bằng cảm ứng (scripts/cam_ung.gd): cần đi đẩy đúng hướng và chạy nhanh khi sát mép, nút Nhảy gửi
## hành động, vuốt chỗ trống xoay camera, ngón giữ cần không thành cú bấm chuột, ngón còn lại thành chuột,
## bấm bàn phím thì ẩn.
## Chạy: godot --headless --path . -s tests/test_cam_ung.gd

var m: Node3D
var cu: CamUng
var fails := 0


func _init() -> void:
	PlayMode.day = "thu_hai"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	GameState.use_test_save("user://luu_game_test_cam_ung.cfg")
	_run.call_deferred()


func _run() -> void:
	cu = root.get_node_or_null("NutCamUng")
	if cu == null:
		cu = CamUng.new()
		root.add_child(cu)
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	current_scene = m
	await _frames(20)
	CamUng.bat = false
	await _frames(2)
	_check(not cu.visible, "chưa chạm thì không hiện")

	m.start_game()
	if m.hud.has_method("hide_day_card"):
		m.hud.hide_day_card()
	paused = false
	await _frames(5)
	_cham(0, Vector2(100, 400), true)  # chạm đầu tiên: bật cảm ứng
	_cham(0, Vector2(100, 400), false)
	await _frames(3)
	_check(CamUng.bat and cu.visible, "chạm màn hình thì hiện cần và nút (bat=%s, hien=%s)" % [CamUng.bat, cu.visible])
	_check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "cảm ứng không khóa chuột")

	# 1. Cần đi: chạm nửa trái rồi kéo sang phải
	var g := Vector2(200, 500)
	_cham(0, g, true)
	await _frames(2)
	_check(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "ngón giữ cần đi không thành cú bấm chuột")
	var r: float = CamUng.CAN_R * cu._k()
	_keo(0, g + Vector2(r * 0.5, 0), Vector2(r * 0.5, 0))
	await _frames(2)
	var s := Input.get_action_strength("move_right")
	_check(s > 0.4 and s < 0.6 and not Input.is_action_pressed("sprint"), "kéo nửa đường: đi phải %.2f, chưa chạy nhanh" % s)
	_keo(0, g + Vector2(r * 2.0, 0), Vector2(r * 1.5, 0))
	await _frames(2)
	_check(Input.get_action_strength("move_right") > 0.95 and Input.is_action_pressed("sprint"), "kéo sát mép: đi phải hết cỡ và chạy nhanh")
	await _frames(20)
	_check(m.player.velocity.length() > 0.5, "Bơ đi theo cần (vận tốc %.2f)" % m.player.velocity.length())
	var nh := _nut("jump")
	_cham(1, nh, true)
	await _frames(2)
	_check(Input.is_action_pressed("jump") and Input.get_action_strength("move_right") > 0.95, "vừa giữ cần vừa nhảy được")
	_cham(1, nh, false)
	await _frames(1)
	await _frames(1)
	_check(Input.get_action_strength("move_right") > 0.95, "thả nút Nhảy, cần vẫn giữ")
	_cham(0, g + Vector2(r * 2.0, 0), false)
	await _frames(2)
	_check(Input.get_action_strength("move_right") == 0.0 and not Input.is_action_pressed("sprint"), "thả cần thì đứng lại")

	# 2. Nút Nhảy
	var nhay := _nut("jump")
	_check(nhay != Vector2.INF, "có nút Nhảy ngoài phố")
	_cham(1, nhay, true)
	await _frames(2)
	_check(Input.is_action_pressed("jump"), "chạm nút Nhảy là giữ nhảy")
	_cham(1, nhay, false)
	await _frames(2)
	_check(not Input.is_action_pressed("jump"), "thả nút Nhảy")
	_check(_nut("deliver") != Vector2.INF and _nut("crouch") != Vector2.INF, "có nút Giao và Chui")

	# 3. Vuốt chỗ trống nửa phải: xoay camera, và ngón đó là chuột (bấm được nút giao diện)
	var rig = m.player.camera_rig
	var yaw0: float = rig.yaw
	var p := Vector2(900, 250)
	_cham(2, p, true)
	await _frames(2)
	_check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "chạm chỗ trống thành chuột trái")
	_keo(2, p + Vector2(-120, 0), Vector2(-120, 0))
	await _frames(2)
	_check(absf(rig.yaw - yaw0) > 0.3, "vuốt xoay camera (yaw %.2f → %.2f)" % [yaw0, rig.yaw])
	_cham(2, p + Vector2(-120, 0), false)
	await _frames(2)
	_check(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "nhấc ngón thì nhả chuột")

	# 4. Bấm bàn phím thì ẩn
	var k := InputEventKey.new()
	k.physical_keycode = KEY_W
	k.pressed = true
	Input.parse_input_event(k)
	k = k.duplicate()
	k.pressed = false
	Input.parse_input_event(k)
	await _frames(2)
	_check(not CamUng.bat and not cu.visible, "bấm phím thì ẩn nút cảm ứng")

	# 5. Bếp: nút Làm, cần đi không thành cú bấm "Làm" (chuột trái cũng là Làm trong bếp)
	m.queue_free()
	await _frames(2)
	var b: Node = load("res://scenes/kitchen.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await _frames(20)
	b.start_game()
	paused = false
	await _frames(5)
	_cham(0, Vector2(100, 400), true)
	_cham(0, Vector2(100, 400), false)
	await _frames(3)
	_check(cu.visible and _nut("interact") != Vector2.INF and _nut("jump") == Vector2.INF, "trong bếp: nút Làm, không có nút Nhảy")
	_cham(0, g, true)
	await _frames(2)
	_check(not Input.is_action_pressed("interact"), "giữ cần đi trong bếp không bấm Làm")
	_cham(0, g, false)
	var lam := _nut("interact")
	_cham(1, lam, true)
	await _frames(2)
	_check(Input.is_action_pressed("interact"), "chạm nút Làm")
	_cham(1, lam, false)
	await _frames(2)
	b.queue_free()
	await _frames(2)

	print("CAM UNG TEST OK" if fails == 0 else "CAM UNG TEST FAIL (%d)" % fails)
	quit(1 if fails else 0)


func _nut(action: String) -> Vector2:
	for n in cu._nut:
		if n[0] == action:
			return n[2]
	return Vector2.INF


func _cham(i: int, p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = root.get_final_transform() * p  # p theo khung game, sự kiện cần tọa độ cửa sổ
	e.pressed = pressed
	Input.parse_input_event(e)


func _keo(i: int, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = root.get_final_transform() * p
	e.relative = root.get_final_transform().basis_xform(rel)
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1
