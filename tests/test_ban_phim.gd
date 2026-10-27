extends SceneTree
## F2 đổi phím + tay cầm, B3 tùy chọn hỗ trợ: đổi phím đổi đúng InputMap, trùng thì đổi chỗ, phím phụ trùng bị bỏ,
## về mặc định; A/B dùng được trong menu; Mực không đớp khi bật hỗ trợ; tốc độ game; giữ F tự đi theo mũi tên.
## Chạy: godot --headless --path . -s tests/test_ban_phim.gd

var m: Node3D
var fails := 0
var _cu := {}


func _init() -> void:
	PlayMode.day = "thu_hai"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	GameState.use_test_save("user://luu_game_test_ban_phim.cfg")
	_run.call_deferred()


func _run() -> void:
	for k in ["ban_phim", "ho_tro_tu_di", "ho_tro_muc", "ho_tro_toc_do"]:
		_cu[k] = GameSettings.get_value(k)
	BanPhim.mac_dinh()
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	current_scene = m  # tốc độ game chỉ áp khi cảnh hiện tại có Bơ
	await _frames(30)

	# 1. Mặc định giống phím cũ của từng cảnh
	_check(_co_phim("jump", KEY_SPACE) and _co_nut("jump", JOY_BUTTON_A), "nhảy: Space + A")
	_check(_co_phim("move_forward", KEY_W) and _co_phim("move_forward", KEY_UP), "đi lên: W + mũi tên")
	_check(_co_phim("deliver", KEY_E) and _co_nut("deliver", JOY_BUTTON_Y), "giao: E + Y")
	_check(InputMap.has_action("tu_di_pho") and _co_phim("tu_di_pho", KEY_F), "phím tự đi F đã khai")
	_check(_co_nut("ui_accept", JOY_BUTTON_A) and _co_nut("ui_cancel", JOY_BUTTON_B), "menu: A chọn, B quay lại")

	# 2. Đổi phím nhảy sang G
	BanPhim.dat_phim("jump", KEY_G)
	_check(_co_phim("jump", KEY_G) and not _co_phim("jump", KEY_SPACE), "nhảy đổi sang G")
	_check(BanPhim.chu_phim("Space") == "G", "chữ phím Space trên bảng hướng dẫn thành G (%s)" % BanPhim.chu_phim("Space"))
	_check(BanPhim.chu_phim("Giữ R") == "Giữ R", "chữ Giữ R giữ nguyên")

	# 3. Gán G cho giao bánh: trùng với nhảy nên nhảy nhận E (phím cũ của giao)
	var doi: Array = BanPhim.dat_phim("deliver", KEY_G)
	_check(doi == ["jump"], "trùng phím thì báo việc bị đổi chỗ (%s)" % str(doi))
	_check(_co_phim("deliver", KEY_G) and _co_phim("jump", KEY_E), "giao = G, nhảy = E")
	_check(not _co_phim("jump", KEY_G), "nhảy không còn G")

	# 4. Bếp và phố khác lúc: E cho "Làm (bếp)" không đụng phím phố
	BanPhim.dat_phim("interact", KEY_G)
	_check(BanPhim.phim("deliver") == KEY_G and BanPhim.phim("interact") == KEY_G, "bếp và phố được dùng chung G")

	# 5. Phím chính trùng phím phụ của việc khác thì phím phụ bị bỏ
	BanPhim.dat_phim("sprint", KEY_UP)
	_check(_co_phim("sprint", KEY_UP) and not _co_phim("move_forward", KEY_UP), "Shift→mũi tên lên: đi lên mất mũi tên phụ")

	# 6. Nút tay cầm
	var doi2: Array = BanPhim.dat_nut("jump", JOY_BUTTON_Y)
	_check(_co_nut("jump", JOY_BUTTON_Y) and _co_nut("deliver", JOY_BUTTON_A) and "deliver" in doi2, "A↔Y đổi chỗ (%s)" % str(doi2))
	_check(_co_nut("sprint", JOY_BUTTON_X), "chạy nhanh còn nút phụ X")

	# 7. Lưu lại: chỉ phần khác mặc định
	var luu: Dictionary = GameSettings.get_value("ban_phim")
	_check(luu.has("jump") and luu.has("deliver") and not luu.has("sneak"), "lưu phần đã đổi (%s)" % str(luu.keys()))

	# 8. Về mặc định
	BanPhim.mac_dinh()
	_check(_co_phim("jump", KEY_SPACE) and _co_phim("move_forward", KEY_UP) and _co_nut("jump", JOY_BUTTON_A), "về mặc định")
	_check(BanPhim.chu_phim("Space") == "Space", "chữ phím về như cũ")

	# 9. B3 Mực không đớp
	DoKho.force_ho_tro = {"ho_tro_muc": true}
	var dog: CharacterBody3D = m.dog
	var bo: CharacterBody3D = m.player
	var bit := [0]
	dog.bit_player.connect(func(): bit[0] += 1)
	bo.global_position = dog.global_position + Vector3(0.3, 0.05, 0)
	dog._set_state(dog.State.CHASE)
	await _frames(10)
	_check(bit[0] == 0 and dog.state != dog.State.BITE, "bật hỗ trợ: Mực đuổi kịp không đớp (trạng thái %d)" % dog.state)
	DoKho.force_ho_tro = {}
	dog._set_state(dog.State.CHASE)
	await _frames(10)
	_check(bit[0] == 1, "tắt hỗ trợ: Mực đớp như cũ")
	await _frames(40)

	# 10. Tốc độ game: chỉ lúc chơi
	DoKho.force_ho_tro = {"ho_tro_toc_do": 70}
	await _frames(30)
	_check(is_equal_approx(Engine.time_scale, 0.7), "tốc độ 70%% (time_scale %.2f)" % Engine.time_scale)
	DoKho.force_ho_tro = {}
	await _frames(30)
	_check(is_equal_approx(Engine.time_scale, 1.0), "về 100%")

	# 11. Giữ F tự đi theo mũi tên
	m.hud.show_playing_ui(true)
	bo.global_position = City.BAKERY_POINT + Vector3(0, 0.1, 2.5)
	bo.velocity = Vector3.ZERO
	bo.can_move = true
	var dich: Vector3 = m.orders[0].pos
	m.hud.set_goal(dich + Vector3.UP)
	await _frames(5)
	var d0 := _xa(bo.global_position, dich)
	Input.action_press("tu_di_pho")
	await _frames(60)
	_check(_xa(bo.global_position, dich) > d0 - 1.0, "chưa bật hỗ trợ thì giữ F không đi")
	DoKho.force_ho_tro = {"ho_tro_tu_di": true}
	await _frames(240)
	var d1 := _xa(bo.global_position, dich)
	_check(d1 < d0 - 4.0, "bật hỗ trợ: giữ F 4 giây Bơ tự đi gần đích (%.1f → %.1f m)" % [d0, d1])
	Input.action_release("tu_di_pho")
	await _frames(30)
	var p := bo.global_position
	await _frames(30)
	_check(_xa(bo.global_position, p) < 0.3, "thả F là đứng lại")
	DoKho.force_ho_tro = {}
	_end()


func _end() -> void:
	for k in _cu:
		GameSettings.set_value(k, _cu[k])
	BanPhim.ap_dung()
	print("BAN PHIM TEST %s (%d lỗi)" % ["OK" if fails == 0 else "FAIL", fails])
	quit(0 if fails == 0 else 1)


func _xa(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _co_phim(action: String, k: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and e.physical_keycode == k:
			return true
	return false


func _co_nut(action: String, b: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == b:
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1
