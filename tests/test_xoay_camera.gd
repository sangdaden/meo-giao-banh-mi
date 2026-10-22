extends SceneTree
## Kiểm tra xoay camera ở màn leo chung cư (Thứ Năm): ngoài hẻm và trong lồng cầu thang (camera tự nhìn
## về hướng dễ leo nhưng phải nhường khi người chơi tự xoay). Chuột chưa khóa thì kéo giữ nút để xoay.
## Chạy: godot --headless --path . -s tests/test_xoay_camera.gd

var fails := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## Gửi thẳng vào rig: Input.parse_input_event chạy headless lặp lại sự kiện chuột nhiều lần.
func _drag(rig: Node, dx: float) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(dx, 0)
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	rig._unhandled_input(ev)
	await _frames(2)


func _run() -> void:
	var s: Node = load("res://scenes/chung_cu.tscn").instantiate()
	root.add_child(s)
	await _frames(20)
	var rig = s.rig
	var p = s.player

	print("Ngoài hẻm")
	var y0: float = rig.yaw
	await _drag(rig, -150)
	_check(absf(rig.yaw - y0) > 0.3, "kéo chuột xoay được camera (%.2f → %.2f)" % [y0, rig.yaw])
	var y1: float = rig.yaw
	await _frames(60)
	_check(absf(rig.yaw - y1) < 0.01, "ngoài cầu thang camera giữ nguyên hướng người chơi chọn")

	print("Trong lồng cầu thang")
	p.global_position = Vector3((s.TX0 + s.TX1) / 2.0 - 0.6, 0.2, -2.5)
	p.velocity = Vector3.ZERO
	rig.yaw = 0.0
	await _frames(240)  # đợi qua thời gian chờ để camera về hướng dễ leo
	_check(s._in_stairwell(), "Bơ đang ở trong lồng cầu thang")
	await _drag(rig, -250)
	var y2: float = rig.yaw
	_check(absf(y2) > 0.5, "trong cầu thang vẫn xoay được (yaw %.2f)" % y2)
	await _frames(60)
	_check(absf(rig.yaw - y2) < 0.05, "1 s sau khi xoay camera không bị kéo về (yaw %.2f)" % rig.yaw)
	await _frames(int((s.STAIR_CAM_WAIT + 2.5) * 60))
	_check(absf(wrapf(rig.yaw, -PI, PI)) < 0.3, "buông chuột một lúc thì camera tự quay về hướng dễ leo (yaw %.2f)" % rig.yaw)

	print("XOAY CAMERA OK" if fails == 0 else "XOAY CAMERA LỖI: %d" % fails)
	quit(1 if fails else 0)
