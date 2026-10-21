extends SceneTree
## Kiểm tra động tác của Bơ: chui (tự chui khi gặp gầm thấp), rón rén, tiếng động, giao bánh, trượt dầu.
## Chạy: godot --headless --path . -s tests/test_dong_tac_bo.gd

const PlayerScript := preload("res://scripts/player.gd")

var bo: CharacterBody3D
var noises := []
var fails := 0


func _init() -> void:
	# Phím như main.gd::_setup_input (main.gd cần autoload nên không nạp được ở chế độ -s)
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "sneak", "deliver"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	_run.call_deferred()


func _box(size: Vector3, pos: Vector3, layer := Blocks.LAYER_WORLD) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = layer
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	b.position = pos
	root.add_child(b)


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _walk(action: String, secs: float, extra := "") -> void:
	Input.action_press("move_forward")
	if extra != "":
		Input.action_press(extra)
	await _frames(int(secs * 60))
	Input.action_release("move_forward")
	if extra != "":
		Input.action_release(extra)


func _run() -> void:
	_box(Vector3(40, 1, 40), Vector3(0, -0.5, 0))
	# Gầm thấp (như gầm ba gác): mặt dưới cao 0,32 m, dài 2 m theo trục Z, ở z từ -4 đến -6
	_box(Vector3(3, 0.3, 2), Vector3(0, 0.47, -5))
	# Thùng hàng (lớp đồ nhỏ) để thử tiếng đụng
	_box(Vector3(1, 1, 1), Vector3(6, 0.5, -3), Blocks.LAYER_PROP)
	bo = PlayerScript.new()
	root.add_child(bo)
	bo.global_position = Vector3(0, 0.05, 0)
	bo.can_move = true
	bo.noise_made.connect(func(p, r): noises.append(r))
	await _frames(10)

	print("Đi bộ:")
	bo.global_position = Vector3(-12, 0.05, 0)
	await _frames(5)
	noises.clear()
	await _walk("", 1.0)
	_check(bo.stance == "walk", "dáng đi = walk (%s)" % bo.stance)
	_check(noises.size() >= 2 and noises.max() == bo.noise_walk, "bước chân kêu %s m (%d tiếng)" % [bo.noise_walk, noises.size()])

	print("Tự chui qua gầm thấp:")
	bo.global_position = Vector3(0, 0.05, -2)
	bo.velocity = Vector3.ZERO
	await _frames(5)
	Input.action_press("move_forward")
	var crouched_under := false
	for i in 150:
		await physics_frame
		if bo.global_position.z < -4.5 and bo.global_position.z > -5.5:
			crouched_under = crouched_under or bo.stance == "crouch"
	Input.action_release("move_forward")
	_check(bo.global_position.z < -6.3, "chui lọt qua gầm (z = %.2f)" % bo.global_position.z)
	_check(crouched_under, "đang chui khi ở dưới gầm")
	await _frames(20)
	_check(bo.stance == "walk", "ra khỏi gầm thì đứng dậy")

	print("Ở dưới gầm thì thả phím chui vẫn chui:")
	bo.global_position = Vector3(0, 0.05, -5)
	Input.action_press("crouch")
	await _frames(10)
	Input.action_release("crouch")
	await _frames(10)
	_check(bo.stance == "crouch", "vẫn chui khi trên đầu bị chắn")
	_check(bo.global_position.y < 0.2, "không bị đẩy trồi lên gầm (y = %.2f)" % bo.global_position.y)

	print("Rón rén:")
	bo.global_position = Vector3(-5, 0.05, 5)
	await _frames(10)
	noises.clear()
	var z0 := bo.global_position.z
	await _walk("", 1.0, "sneak")
	var v := (z0 - bo.global_position.z) / 1.0
	_check(noises.size() > 0 and noises.max() == bo.noise_sneak, "rón rén kêu %s m" % bo.noise_sneak)
	_check(v < bo.sneak_speed + 0.1, "chậm (%.2f m/s)" % v)

	print("Chạy nhanh:")
	noises.clear()
	bo.global_position = Vector3(-5, 0.05, 15)
	await _walk("", 1.0, "sprint")
	_check(noises.max() == bo.noise_sprint, "chạy nhanh kêu %s m" % bo.noise_sprint)

	print("Đáp đất từ 1,5 m:")
	noises.clear()
	bo.global_position = Vector3(-8, 1.5, 8)
	bo.velocity = Vector3.ZERO
	await _frames(60)
	_check(bo.noise_land in noises, "đáp đất kêu %s m" % bo.noise_land)

	print("Đụng thùng khi đang chạy:")
	noises.clear()
	bo.global_position = Vector3(6, 0.05, 0)
	await _walk("", 1.0)
	_check(bo.noise_bump in noises, "đụng thùng kêu %s m" % bo.noise_bump)

	print("Giao bánh:")
	var got := []
	bo.deliver_finished.connect(func(k): got.append(k))
	for kind in ["hand", "basket", "counter", "under_car", "chair"]:
		bo.play_deliver(kind)
		await _frames(80)
	_check(got == ["hand", "basket", "counter", "under_car", "chair"], "đủ 5 kiểu giao: %s" % [got])

	print("Giật mình:")
	var st := [false]
	bo.startled.connect(func(): st[0] = true)
	bo.play_startle()
	await _frames(50)
	_check(st[0], "phát startled")

	print("Trượt dầu:")
	bo.global_position = Vector3(-10, 0.05, 15)
	await _frames(10)
	bo.enter_oil()
	await _walk("", 0.8)
	await _frames(12)
	var hs := Vector2(bo.velocity.x, bo.velocity.z).length()
	bo.exit_oil()
	_check(hs > 1.5, "thả phím vẫn trượt tiếp (%.2f m/s)" % hs)

	print("KẾT QUẢ: " + ("TẤT CẢ OK" if fails == 0 else "%d LỖI" % fails))
	quit(1 if fails else 0)
