extends SceneTree
## Leo thật (phím ảo, vật lý thật) trên các chỗ leo của Thứ Năm, ở Thong thả:
## nóc tủ báo Chú Tư (bám mép rồi kéo lên), cửa cuốn tiệm xe chặn mặt tiền, đạp tường trong khe hông lên mái tôn
## (nhiệm vụ dap_lien), đi từ cửa sau vào tới võng Anh Hùng, bậc thùng → cục nóng → gác lửng Chị Mây,
## đường mát lên dãy mái hiên khối 1.
## Chạy: godot --headless --path . -s tests/test_thu_nam.gd

var m: Node3D
var tn: ThuNam
var bo: CharacterBody3D
var fails := 0


func _init() -> void:
	DoKho.force = -1
	PlayMode.day = "thu_nam"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	GameState.use_test_save("user://luu_game_test_thu_nam.cfg")
	_run.call_deferred()


func _run() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(30)
	tn = m.get_node("ThuNam")
	bo = m.player
	bo.can_move = true
	_check(bo.climb_moves, "cả ngày Thứ Năm bật động tác leo")
	await _shelf()
	await _shutter()
	await _khe()
	await _back_door()
	await _loft()
	await _shade()
	# Thử thách: tủ báo cao 1,9 m, với mép 0,95 m; vẫn lên được tủ và gác lửng
	m.queue_free()
	await _frames(5)
	DoKho.force = 1
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(30)
	tn = m.get_node("ThuNam")
	bo = m.player
	bo.can_move = true
	print("  -- Thử thách")
	await _shelf()
	await _loft()
	print("THU NAM TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


## Đứng trước tủ báo, nhảy và đẩy về phía tủ: bám mép, Space kéo lên nóc.
func _shelf() -> void:
	var h: float = DoKho.v("shelf_height", 1.9)
	await _put(ThuNam.SHELF + Vector3(0, 0.1, 1.0))
	var grabbed := await _jump_grab("move_forward", 50)
	_check(grabbed, "bám được mép tủ báo cao %.1f m" % h)
	await _hold("jump", 3)
	await _frames(int(bo.pull_time * 60) + 25)
	_check(absf(bo.global_position.y - h) < 0.15, "leo lên nóc tủ báo (y = %.2f)" % bo.global_position.y)
	var reach_hard: float = 1.3 + 0.95
	_check(reach_hard > 1.9, "Thử thách: nhảy 1,3 + với 0,95 = %.2f m tới nóc 1,9 m" % reach_hard)


## Cửa cuốn kéo xuống: giữ W từ vỉa hè, Bơ không lọt vào tiệm.
func _shutter() -> void:
	await _put(Vector3(32.3, 0.1, 25.6))
	await _hold("move_forward", 120)
	_check(bo.global_position.z > ThuNam.SHUTTER_Z, "cửa cuốn chặn mặt tiền (z = %.2f)" % bo.global_position.z)


## Trong khe hông: nhảy rồi đạp qua lại hai vách, cuối cùng đẩy về phía bắc lên mái tôn. Không chạm đất.
func _khe() -> void:
	tn._carrying = 1
	tn.dap_ok = false
	await _put(Vector3(28.9, 0.1, 21.4))
	var top := 0.0
	await _hold("jump", 12)
	for k in 4:
		var side := "move_right" if k % 2 == 0 else "move_left"
		Input.action_press(side)
		for i in 40:
			await physics_frame
			top = maxf(top, bo.global_position.y)
			if bo.is_on_wall() and bo.velocity.y < 3.0:
				break
		Input.action_release(side)
		Input.action_press("jump")
		Input.action_press("move_forward")
		await _frames(12)
		Input.action_release("jump")
		top = maxf(top, bo.global_position.y)
		if bo.global_position.y > ThuNam.TIN_ROOF_Y - 0.6:
			break
		Input.action_release("move_forward")
	Input.action_press("move_forward")
	for i in 60:
		await physics_frame
		top = maxf(top, bo.global_position.y)
		if bo.climb == "hang":
			Input.action_press("jump")
		elif bo.is_on_floor():
			break
	_release()
	await _frames(int(bo.pull_time * 60) + 20)
	_check(bo.global_position.y > ThuNam.TIN_ROOF_Y - 0.15, "đạp tường lên mái tôn (cao nhất %.2f, đứng y %.2f)" % [top, bo.global_position.y])
	_check(tn.dap_ok, "nhiệm vụ đạp tường một mạch đạt")
	tn._carrying = -1


## Từ hẻm sau, qua cửa sau đi thẳng tới võng Anh Hùng.
func _back_door() -> void:
	await _put(Vector3(32.3, 0.1, 15.6))
	var goal := tn.hung.global_position + Vector3(1.0, 0, 0)
	var ok := await _walk_to(goal, 6.0)
	_check(ok, "cửa sau → võng Anh Hùng (tới %s)" % bo.global_position)


## Bậc thùng → thùng → cục nóng → gác lửng: cứ nhảy về phía tây (bám mép thì Space kéo lên).
func _loft() -> void:
	var first: Vector3 = ThuNam.LOFT_STEPS[0]
	await _put(Vector3(first.x + 0.9, 0.1, first.z))
	var path := await _climb("move_left", ThuNam.LOFT_Y, 6)
	_check(absf(bo.global_position.y - ThuNam.LOFT_Y) < 0.15, "lên gác lửng sau %d cú nhảy (y: %s)" % [path.size(), path])


## Đường mát về lò: thùng → cục nóng (nhảy về phía tây) → mái hiên khối 1 (nhảy về phía bắc), rồi đi trên mái.
func _shade() -> void:
	var a: Vector3 = ThuNam.SHADE_STEPS[0]
	var b: Vector3 = ThuNam.SHADE_STEPS[1]
	await _put(Vector3(a.x + 0.9, 0.1, a.z))
	var path := await _climb("move_left", b.y, 4)
	_check(absf(bo.global_position.y - b.y) < 0.15, "lên cục nóng (y: %s, x %.2f)" % [path, bo.global_position.x])
	path = await _climb("move_forward", 2.9, 2)
	_check(bo.global_position.y > 2.8, "lên mái hiên khối 1 (y: %s)" % [path])
	var start_x := bo.global_position.x
	await _hold("move_left", 90)
	_check(bo.global_position.y > 2.8 and bo.global_position.x < start_x - 3.0, "đi trên mái hiên về phía lò (x %.1f → %.1f, y %.2f)" % [start_x, bo.global_position.x, bo.global_position.y])


## Nhảy liên tiếp theo hướng dir tới khi đứng ở độ cao y_goal; trả về độ cao sau mỗi cú.
func _climb(dir: String, y_goal: float, tries: int) -> Array:
	var ys := []
	for t in tries:
		Input.action_press(dir)
		await _hold("jump", 12)
		for i in 70:
			await physics_frame
			if bo.climb == "hang":
				Input.action_release(dir)  # như người chơi: bám rồi thì buông hướng, bấm Space kéo lên
				await _hold("jump", 3)
				await _frames(int(bo.pull_time * 60) + 10)
				break
			if bo.is_on_floor():
				break
		Input.action_release(dir)
		await _frames(8)
		ys.append(snappedf(bo.global_position.y, 0.01))
		if bo.global_position.y > y_goal - 0.15:
			break
	return ys


# ---------------------------------------------------------------- tiện ích

func _jump_grab(dir: String, frames: int) -> bool:
	Input.action_press(dir)
	await _hold("jump", 12)
	var grabbed := false
	for i in frames:
		await physics_frame
		if bo.climb == "hang":
			grabbed = true
			break
		if bo.is_on_floor() and i > 5:
			break
	Input.action_release(dir)
	return grabbed


func _walk_to(goal: Vector3, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		var p := bo.global_position
		var d := Vector2(goal.x - p.x, goal.z - p.z)
		if d.length() < 0.5:
			_release()
			return true
		var v := d.normalized()
		_axis("move_right", "move_left", v.x)
		_axis("move_back", "move_forward", v.y)
		await physics_frame
		t += 1.0 / 60.0
	_release()
	return false


func _axis(pos: String, neg: String, value: float) -> void:
	Input.action_release(pos)
	Input.action_release(neg)
	if value > 0.05:
		Input.action_press(pos, value)
	elif value < -0.05:
		Input.action_press(neg, -value)


func _put(p: Vector3) -> void:
	_release()
	bo.climb = ""
	bo.global_position = p
	bo.velocity = Vector3.ZERO
	m.rig.yaw = 0.0
	await _frames(15)


func _hold(action: String, n: int) -> void:
	Input.action_press(action)
	await _frames(n)
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _release() -> void:
	for a in ["move_right", "move_left", "move_back", "move_forward", "sprint", "jump"]:
		Input.action_release(a)


func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  SAI ") + what)
	if not ok:
		fails += 1
