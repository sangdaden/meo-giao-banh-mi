extends SceneTree
## Thử cú nhảy của Bơ: nhảy tới rồi giữa không trung bẻ phím sang phải, Bơ phải quay mặt và bay theo.
## Chạy: godot --headless --path . -s tests/test_nhay_bo.gd

const PlayerScript := preload("res://scripts/player.gd")

var bo: CharacterBody3D
var fails := 0


func _init() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "sneak", "deliver"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(200, 1, 200)
	cs.shape = bs
	b.add_child(cs)
	b.position = Vector3(0, -0.5, 0)
	root.add_child(b)
	print("Thong thả:")
	DoKho.force = -1
	await _jump_and_steer(true)
	print("Thử thách (số cũ):")
	DoKho.force = 1
	await _jump_and_steer(false)
	DoKho.force = 0
	print("NHAY TEST " + ("OK" if fails == 0 else "LỖI (%d)" % fails))
	quit(fails)


## Chạy tới, nhảy (giữ nút), bay được 0,1 s thì bẻ phím sang phải.
func _jump_and_steer(easy: bool) -> void:
	bo = PlayerScript.new()
	root.add_child(bo)
	bo.can_move = true
	await _frames(20)
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_press("jump")
	var y0 := bo.global_position.y
	var top := y0
	await _frames(6)
	Input.action_release("move_forward")
	Input.action_press("move_right")
	var air := 0
	var steer_at := -1.0
	var face_at := -1.0
	var max_s := 0.0
	var landed_scale := 1.0
	for i in 70:
		await physics_frame
		top = maxf(top, bo.global_position.y)
		if not bo.is_on_floor():
			air += 1
		var hv := Vector2(bo.velocity.x, bo.velocity.z)
		if steer_at < 0.0 and hv.length() > 0.5 and absf(angle_difference(hv.angle(), 0.0)) < deg_to_rad(15.0):
			steer_at = i / 60.0
		if face_at < 0.0 and absf(angle_difference(bo.visual.rotation.y, -PI / 2)) < deg_to_rad(15.0):
			face_at = i / 60.0
		max_s = maxf(max_s, absf(bo.visual.scale.y - 1.0))
		if bo.is_on_floor():
			landed_scale = minf(landed_scale, bo.visual.scale.y)
	Input.action_release("jump")
	Input.action_release("move_right")
	print("  cao %.2f m, bay %.2f s, bẻ hướng bay sau %.2f s, quay mặt sau %.2f s" % [top - y0, air / 60.0, steer_at, face_at])
	_check(top - y0 > 1.3, "nhảy cao hơn 1,3 m (mép, thùng các màn vẫn với tới)")
	_check(face_at >= 0.0 and face_at < 0.3, "trên không quay mặt theo phím trong 0,3 s")
	_check(max_s < 0.35, "co giãn khi nhảy không quá 35%")
	if easy:
		_check(steer_at >= 0.0 and steer_at < 0.25, "Thong thả: bẻ hướng bay theo phím trong 0,25 s")
		_check(air / 60.0 > 0.55, "Thong thả: bay lâu hơn 0,55 s (dễ canh chỗ đáp)")
		_check(landed_scale < 0.97, "Thong thả: tiếp đất có nén người")
	await _frames(40)
	_check(absf(bo.visual.scale.y - 1.0) < 0.02, "đứng yên thì hình về đúng cỡ")
	bo.queue_free()
	await _frames(2)
