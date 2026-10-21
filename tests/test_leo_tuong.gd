extends SceneTree
## Kiểm tra động tác leo của Bơ cho Thứ Năm (chung cư): bám mép, leo lên, bật tường trong khe hẹp, leo ống nước.
## Chạy: godot --headless --path . -s tests/test_leo_tuong.gd

const PlayerScript := preload("res://scripts/player.gd")

var bo: CharacterBody3D
var fails := 0


func _init() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "sneak", "deliver"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	_run.call_deferred()


func _box(size: Vector3, pos: Vector3) -> void:
	var b := StaticBody3D.new()
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


func _place(p: Vector3) -> void:
	bo.climb = ""
	bo.global_position = p
	bo.velocity = Vector3.ZERO
	await _frames(8)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


## Chạy tới tường và nhảy, giữ phím tới. Trả về true nếu bám được mép.
func _jump_at_wall(start: Vector3, secs := 1.2) -> bool:
	await _place(start)
	Input.action_press("move_forward")
	await _frames(6)
	Input.action_press("jump")
	var grabbed := false
	for i in int(secs * 60):
		await physics_frame
		if bo.climb == "hang":
			grabbed = true
			break
	Input.action_release("jump")
	Input.action_release("move_forward")
	return grabbed


func _run() -> void:
	_box(Vector3(60, 1, 60), Vector3(0, -0.5, 0))
	# Tường A: mép cao 2,0 m (bám được). Mặt tường ở z = -2,5
	_box(Vector3(3, 2.0, 1), Vector3(0, 1.0, -3))
	# Tường B: mép 2,6 m (quá tầm)
	_box(Vector3(3, 2.6, 1), Vector3(8, 1.3, -3))
	# Lan can mỏng 6 cm cao 1,05 m trên sàn hành lang cao 1,0 m (như từ cục nóng với lên hành lang)
	_box(Vector3(3, 1.0, 2), Vector3(16, 0.5, -4))
	_box(Vector3(3, 1.05, 0.06), Vector3(16, 1.0 + 0.525, -3.03))
	# Khe hẹp 1,2 m giữa hai bức tường cao 8 m (x = 29,4 và 30,6)
	_box(Vector3(1, 8, 4), Vector3(28.9, 4, 10))
	_box(Vector3(1, 8, 4), Vector3(31.1, 4, 10))
	# Một bức tường đứng giữa sân rộng (không bật được)
	_box(Vector3(1, 8, 4), Vector3(-20.5, 4, 10))

	bo = PlayerScript.new()
	root.add_child(bo)
	bo.can_move = true
	await _place(Vector3(0, 0.05, 0))

	print("Thứ Hai (climb_moves tắt): không bám mép")
	bo.climb_moves = false
	_check(not await _jump_at_wall(Vector3(0, 0.05, 0)), "không bám")
	bo.climb_moves = true

	print("Bám mép 2,0 m rồi leo lên:")
	var got := [0, 0]
	bo.ledge_grabbed.connect(func(): got[0] += 1)
	bo.ledge_climbed.connect(func(): got[1] += 1)
	_check(await _jump_at_wall(Vector3(0, 0.05, 0)), "bám được mép")
	_check(got[0] == 1, "phát ledge_grabbed")
	await _frames(30)
	_check(bo.climb == "hang" and absf(bo.global_position.y - 1.5) < 0.1, "treo yên dưới mép (y = %.2f)" % bo.global_position.y)
	await _tap("jump")
	await _frames(int(bo.pull_time * 60) + 15)
	_check(bo.climb == "" and absf(bo.global_position.y - 2.0) < 0.1, "đứng trên mép (y = %.2f)" % bo.global_position.y)
	_check(bo.global_position.z < -2.6, "đã lên hẳn mặt tường (z = %.2f)" % bo.global_position.z)
	_check(got[1] == 1, "phát ledge_climbed")

	print("Bám rồi buông (lùi):")
	await _jump_at_wall(Vector3(0, 0.05, 0))
	await _frames(15)
	Input.action_press("move_back")
	await _frames(40)
	Input.action_release("move_back")
	_check(bo.climb == "" and bo.global_position.y < 0.2, "rơi xuống đất (y = %.2f)" % bo.global_position.y)

	print("Mép 2,6 m quá tầm:")
	_check(not await _jump_at_wall(Vector3(8, 0.05, 0)), "không bám")

	print("Lan can hành lang 6 cm:")
	_check(await _jump_at_wall(Vector3(16, 0.05, -1.0)), "bám được lan can")
	await _tap("jump")
	await _frames(int(bo.pull_time * 60) + 50)
	_check(bo.climb == "" and absf(bo.global_position.y - 1.0) < 0.1 and bo.global_position.z < -3.1,
		"vào tới sàn hành lang (y = %.2f, z = %.2f)" % [bo.global_position.y, bo.global_position.z])

	print("Bật tường trong khe 1,2 m:")
	var kicks := []
	bo.wall_kicked.connect(func(c): kicks.append(c))
	await _place(Vector3(30, 0.05, 10))
	var top := 0.0
	Input.action_press("jump")
	await _frames(12)
	Input.action_release("jump")
	for k in 4:
		# đẩy vào một bên tường cho chạm, rồi bấm nhảy để đạp sang bên kia
		var side := "move_right" if k % 2 == 0 else "move_left"
		Input.action_press(side)
		for i in 40:
			await physics_frame
			top = maxf(top, bo.global_position.y)
			if bo.is_on_wall() and bo.velocity.y < 3.0:
				break
		Input.action_release(side)
		Input.action_press("jump")  # giữ nút nhảy như người chơi thật (thả sớm là nhảy thấp)
		await _frames(12)
		Input.action_release("jump")
		for i in 10:
			await physics_frame
			top = maxf(top, bo.global_position.y)
	for i in 60:
		await physics_frame
		top = maxf(top, bo.global_position.y)
	_check(kicks == [1, 2, 3], "đạp đúng tối đa 3 lần (%s)" % [kicks])
	_check(top > 3.0, "lên cao %.2f m" % top)

	print("Tường giữa sân rộng: không bật được")
	kicks.clear()
	await _place(Vector3(-19.5, 0.05, 10))
	Input.action_press("move_left")
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	await _frames(14)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	Input.action_release("move_left")
	await _frames(40)
	_check(kicks.is_empty(), "không đạp")

	print("Leo ống nước:")
	var wall := Vector3(22, 4, -10.5)
	_box(Vector3(3, 8, 1), wall)
	var pipe := Area3D.new()
	pipe.position = Vector3(22, 0, -9.92)
	pipe.collision_mask = 2  # lớp của Bơ
	pipe.set_meta("normal", Vector3.BACK)
	pipe.set_meta("top", 6.0)
	var ps := CollisionShape3D.new()
	var pb := BoxShape3D.new()
	pb.size = Vector3(0.5, 6, 0.6)
	ps.shape = pb
	ps.position.y = 3.0
	pipe.add_child(ps)
	pipe.body_entered.connect(func(b): if b.has_method("enter_pipe"): b.enter_pipe(pipe))
	pipe.body_exited.connect(func(b): if b.has_method("exit_pipe"): b.exit_pipe(pipe))
	root.add_child(pipe)
	await _place(Vector3(22, 0.05, -8.5))
	Input.action_press("move_forward")
	for i in 30:
		await physics_frame
	var y0 := bo.global_position.y
	await _frames(120)
	var climbed := bo.global_position.y - y0
	_check(bo.climb == "pipe", "đang ôm ống")
	_check(climbed > 2.3 and climbed < 3.3, "leo 2 giây được %.2f m" % climbed)
	await _frames(240)
	_check(bo.global_position.y <= 5.71, "dừng ở đầu ống (y = %.2f)" % bo.global_position.y)
	Input.action_release("move_forward")
	await _tap("jump")
	await _frames(10)
	_check(bo.climb == "" and bo.global_position.z > -9.5, "nhảy bật ra khỏi ống (z = %.2f)" % bo.global_position.z)
	await _frames(120)

	print("KẾT QUẢ: ", "TẤT CẢ OK" if fails == 0 else "%d LỖI" % fails)
	quit(0 if fails == 0 else 1)
