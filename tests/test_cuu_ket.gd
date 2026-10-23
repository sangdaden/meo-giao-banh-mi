extends SceneTree
## Nút cứu kẹt (A2): giữ R 1 giây là Bơ về chỗ đứng vững gần đây nhất; bấm lại liền thì lùi thêm một chỗ;
## treo/kẹt yên hơn 4 giây thì tự nhắc; rơi khỏi bản đồ cũng về chỗ an toàn.
## Chạy: godot --headless --path . -s tests/test_cuu_ket.gd

var m: Node3D
var bo: CharacterBody3D
var ck: CuuKet
var fails := 0


func _init() -> void:
	PlayMode.day = "thu_hai"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	GameState.use_test_save("user://luu_game_test_cuu_ket.cfg")
	_run.call_deferred()


func _run() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(30)
	bo = m.player
	bo.can_move = true
	var rig = m.get_node_or_null("CameraRig")
	if rig:
		rig.yaw = 0.0
	ck = bo.get_node_or_null("CuuKet")
	_check(ck != null, "Bơ có nút cứu kẹt")
	if ck == null:
		quit(1)
		return

	# 1. Đi loanh quanh: ghi được vài chỗ an toàn
	await _frames(40)
	for dir in ["move_left", "move_left", "move_back"]:
		Input.action_press(dir)
		await _frames(25)
		Input.action_release(dir)
		await _frames(45)
	var n := ck.points.size()
	_check(n >= 2, "đi loanh quanh ghi được chỗ an toàn (%d chỗ)" % n)
	if n < 2:
		_end()
		return
	var newest: Vector3 = ck.points[-1]

	# 2. Kẹt lơ lửng trong tư thế bám mép, không bấm gì: 4 giây sau tự nhắc
	bo.global_position = newest + Vector3(0.4, 2.5, 0.3)
	bo.velocity = Vector3.ZERO
	bo.climb = "hang"
	await _frames(30)
	_check(not ck.hint_on, "chưa tới 4 giây thì chưa nhắc")
	await _frames(int(CuuKet.HINT_AFTER * 60))
	_check(ck.hint_on, "kẹt yên hơn 4 giây thì nhắc giữ R")

	# 3. Bấm R rồi thả sớm: chưa cứu
	Input.action_press(CuuKet.ACTION)
	await _frames(30)
	Input.action_release(CuuKet.ACTION)
	await _frames(2)
	_check(bo.climb == "hang", "thả R trước 1 giây thì chưa cứu")

	# 4. Giữ R đủ 1 giây: về chỗ an toàn mới nhất, hết treo, đứng trên nền
	Input.action_press(CuuKet.ACTION)
	await _frames(int(CuuKet.HOLD * 60) + 5)
	Input.action_release(CuuKet.ACTION)
	await _frames(15)
	_check(bo.climb == "", "hết treo mép")
	_check(bo.global_position.distance_to(newest) < 0.2, "về đúng chỗ an toàn mới nhất (lệch %.2f m)" % bo.global_position.distance_to(newest))
	_check(bo.is_on_floor(), "đứng trên nền")
	_check(not ck.hint_on, "tắt lời nhắc")

	# 5. Bấm lại ngay: lùi về chỗ cũ hơn
	Input.action_press(CuuKet.ACTION)
	await _frames(int(CuuKet.HOLD * 60) + 5)
	Input.action_release(CuuKet.ACTION)
	await _frames(15)
	var older: Vector3 = ck.points[-2]
	_check(bo.global_position.distance_to(older) < 0.2, "bấm lại liền thì lùi một chỗ (lệch %.2f m)" % bo.global_position.distance_to(older))

	# 6. Rơi khỏi bản đồ: về chỗ an toàn, không về tọa độ cũ cố định
	await _frames(int(CuuKet.STEP_BACK_TIME * 60) + 10)
	bo.global_position = Vector3(200, -12, 200)
	await _frames(10)
	_check(bo.global_position.y > -1.0 and bo.global_position.distance_to(Vector3(-33, 1, -2)) > 0.5 \
		and _near_point(), "rơi khỏi bản đồ thì về chỗ an toàn (%s)" % bo.global_position)
	_end()


func _near_point() -> bool:
	for p in ck.points:
		if bo.global_position.distance_to(p) < 0.3:
			return true
	return false


func _end() -> void:
	print("CUU KET TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1
