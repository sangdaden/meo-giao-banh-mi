extends SceneTree
## Camera không chui vào mái hiên và tường (A1, video Sang quay 22/10 ở mái hiên Thứ Bảy):
## - vật mỏng che giữa camera và Bơ (mái hiên, chồng thùng) thì mờ đi, camera giữ khoảng cách;
## - tường nhà dày thì camera vẫn kéo lại gần như cũ;
## - Bơ đứng trên mái hiên, buông chuột thì camera bớt chúc thẳng xuống.
## Ảnh trước/sau (cần GPU): tools/chup_camera_che.gd
## Chạy: godot --headless --path . -s tests/test_camera_che.gd

var m: Node3D
var bo: CharacterBody3D
var rig: Node3D
var fails := 0


func _init() -> void:
	PlayMode.day = "thu_bay"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	GameState.use_test_save("user://luu_game_test_camera_che.cfg")
	_run.call_deferred()


func _run() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(30)
	bo = m.player
	rig = m.get_node("CameraRig")
	rig.first_person = false  # cài đặt máy có thể đang để góc thứ nhất (test khác bấm V)
	var aw := _awning_near(Vector2(-3.5, -6.55))
	_check(aw != null, "tìm thấy mái hiên khối 2 (sạp báo Chú Tư)")
	if aw == null:
		quit(1)
		return
	var size: Vector3 = ((aw.get_child(0) as CollisionShape3D).shape as BoxShape3D).size
	var top := aw.global_position.y + size.y / 2.0
	var x0 := aw.global_position.x - size.x / 2.0

	print("Mái hiên che giữa camera và Bơ")
	# Bơ đứng dưới đất sát đầu tây mái hiên, camera chếch phía đông trên cao: tia nhìn cắt qua mái hiên
	await _put(Vector3(x0 - 0.3, 0.05, aw.global_position.z), PI / 2.0, -1.0)
	_check(rig.arm.spring_length > rig.distance - 0.1, "camera giữ khoảng cách (%.2f m), không kéo sát vào Bơ" % rig.arm.spring_length)
	_check(rig.occluded and rig.cutter.amount > 0.9, "mái hiên che thì bật làm mờ")
	_check(_swapped_any(), "mesh mái hiên (đã gộp) đổi sang vật liệu cắt")
	await _put(Vector3(x0 - 4.0, 0.05, aw.global_position.z + 3.0), PI / 2.0, -0.32)
	await _frames(40)
	_check(rig.cutter.amount == 0.0 and not _swapped_any(), "hết che thì trả vật liệu gốc như cũ")

	print("Trên mái hiên")
	await _put(Vector3(aw.global_position.x, top + 0.05, aw.global_position.z), 0.0, -1.15)
	_check(bo.is_on_floor(), "Bơ đứng trên mái hiên (y %.2f)" % bo.global_position.y)
	await _frames(int((rig.high_wait + 2.0) * 60))
	_check(rig.pitch > rig.high_pitch - 0.08, "buông chuột thì camera nâng lên góc vừa phải (pitch %.2f)" % rig.pitch)
	_check(rig.arm.spring_length > rig.distance - 0.1, "trên mái hiên camera giữ khoảng cách (%.2f m)" % rig.arm.spring_length)
	_check(rig.occluded, "trên mái luôn bật làm mờ (bảng hiệu trên mái hiên không có va chạm)")
	await _put(Vector3(aw.global_position.x, 0.05, aw.global_position.z + 4.0), 0.0, -1.15)
	await _frames(int((rig.high_wait + 2.0) * 60))
	_check(rig.pitch < -1.0, "dưới đất thì camera giữ góc người chơi chọn (pitch %.2f)" % rig.pitch)

	print("Tường nhà dày")
	# Bơ quay lưng vào tường dưới mái hiên, camera thụt vào phía nhà: phải kéo lại gần
	var wall_z := aw.global_position.z - size.z / 2.0
	await _put(Vector3(aw.global_position.x, 0.05, wall_z + 0.45), PI, -0.2)
	_check(rig.arm.spring_length < 1.2, "tường đặc thì camera kéo lại gần (%.2f m)" % rig.arm.spring_length)

	print("Chồng thùng che")
	var st := City.CORNER_STAIR
	await _put(st + Vector3(1.6, 0.05, 0), -PI / 2.0, -0.25)
	_check(rig.arm.spring_length > rig.distance - 0.1, "chồng thùng không kéo camera sát (%.2f m)" % rig.arm.spring_length)
	_check(rig.occluded, "chồng thùng che thì bật làm mờ")

	print("CAMERA CHE TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _awning_near(p: Vector2) -> StaticBody3D:
	var best: StaticBody3D = null
	var bd := 3.0
	for n in m.get_tree().get_nodes_in_group("mai_hien"):
		var b := n as StaticBody3D
		var d := Vector2(b.global_position.x, b.global_position.z).distance_to(p)
		if d < bd:
			bd = d
			best = b
	return best


func _swapped_any() -> bool:
	return not rig.cutter._swapped.is_empty()


func _put(p: Vector3, yaw: float, pitch: float) -> void:
	bo.climb = ""
	bo.velocity = Vector3.ZERO
	bo.global_position = p
	rig.yaw = yaw
	rig.pitch = pitch
	rig._manual_ms = -100000
	rig._snap()
	await _frames(45)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1
