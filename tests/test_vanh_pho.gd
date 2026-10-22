extends SceneTree
## Kiểm tra vành phố P1 (scripts/vanh_pho.gd): mép mềm chặn Bơ mà không chặn camera, 6 đầu đường cho Bơ quay đầu
## và nói câu nhắc, xe máy chạy qua cầu kênh theo mặt cầu, phông chân trời đổi ảnh theo buổi.
## Chạy: godot --headless --path . -s tests/test_vanh_pho.gd

var fails := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame
	var player: CharacterBody3D = main.get("player")
	var space := player.get_world_3d().direct_space_state

	# Tường mép: Bơ (lớp đồ) bị chặn ở cả 4 phía, camera (lớp thế giới) không bị kéo vào ở các đầu đường
	var probes := [
		[Vector3(46.0, 0.5, 0.0), Vector3(52.0, 0.5, 0.0), "đông"],
		[Vector3(-18.0, 0.5, -28.0), Vector3(-18.0, 0.5, -34.0), "bắc chợ"],
		[Vector3(16.0, 0.5, -28.0), Vector3(16.0, 0.5, -34.0), "bắc x 16"],
		[Vector3(16.0, 0.5, 28.0), Vector3(16.0, 0.5, 34.0), "nam x 16"],
		[Vector3(-46.0, 0.5, 0.0), Vector3(-52.0, 0.5, 0.0), "cầu kênh"],
	]
	for p in probes:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p[0], p[1], Blocks.LAYER_PROP))
		_check(not hit.is_empty(), "tường mép chặn Bơ ở đầu đường %s" % p[2])
		var cam := space.intersect_ray(PhysicsRayQueryParameters3D.create(p[0] + Vector3(0, 2, 0), p[1] + Vector3(0, 2, 0), Blocks.LAYER_WORLD))
		_check(cam.is_empty(), "camera không vướng tường mép ở đầu đường %s" % p[2])
	# Nền va chạm phủ tới mép (Bơ không rơi khỏi bản đồ ở dải vỉa hè ngoài 96 x 60 m)
	for g in [Vector3(-48.3, 2, 10), Vector3(48.6, 2, 0), Vector3(-30, 2, -31.0), Vector3(30, 2, 31.0)]:
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(g, g - Vector3(0, 4, 0), Blocks.LAYER_WORLD))
		_check(not down.is_empty() and absf(down.position.y) < 0.05, "có nền đứng ở %s" % g)
	# Nhà vành dãy đầu có hộp va chạm (camera không chui vào nhà)
	var house := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-5, 3, -29), Vector3(-5, 3, -40), Blocks.LAYER_WORLD))
	_check(not house.is_empty() and house.position.z < -31.0, "nhà vành bắc có hộp va chạm sau mép")

	# Đầu đường: đứng trong vùng chạm thì Bơ quay đầu về vùng chơi và nói câu nhắc
	var edge: Node = main.find_child("MepMem", true, false)
	_check(edge != null, "có node mép mềm")
	for e: Dictionary in VanhPho.EXITS:
		var r: Rect2 = e.rect
		if e.name == "hem_nam":
			continue  # sau nhà Bà Sáu (mặt tiền z 26,6), Bơ không tới được; vùng chạm chỉ để dự phòng
		player.global_position = Vector3(r.get_center().x, 0.1, r.get_center().y)
		player.velocity = Vector3.ZERO
		await physics_frame
		await physics_frame
		var back: Vector3 = e.back
		var v := Vector3(player.velocity.x, 0, player.velocity.z)
		_check(v.length() > 0.5 and v.normalized().dot(back) > 0.9, "Bơ quay đầu ở %s (vận tốc %s)" % [e.name, v])
		var bubble: Label3D = null
		for c in edge.get_children():
			if c is Label3D:
				bubble = c
		_check(bubble != null and bubble.visible and bubble.text == e.say, "câu nhắc ở %s" % e.name)
	player.global_position = City.BAKERY_POINT + Vector3(0, 0.1, 2.5)

	# Mặt cầu kênh vồng 0,45 m, ngoài cầu bằng 0
	_check(is_equal_approx(VanhPho.road_y(-55.3, 0.0), 0.45), "đỉnh cầu cao 0,45 m")
	_check(VanhPho.road_y(-40.0, 0.0) == 0.0 and VanhPho.road_y(-55.0, 20.0) == 0.0, "ngoài cầu mặt đường bằng 0")

	# Phông chân trời đổi theo buổi
	VanhPho.set_sky(self, "toi")
	var sky: MeshInstance3D = main.find_child("ChanTroi", true, false)
	_check(sky != null and sky.get_meta("buoi") == "toi", "phông chân trời đổi sang buổi tối")
	_check(sky != null and sky.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "phông chân trời không đổ bóng")

	if fails == 0:
		print("TEST VANH PHO OK")
	else:
		print("TEST VANH PHO: %d lỗi" % fails)
	quit(1 if fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  LỖI: ", what)
