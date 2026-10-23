extends SceneTree
## Chụp Chó Mực ở chỗ khoảnh khắc từng ngày (scripts/muc_tuan.gd): Thứ Ba sạp khô cá, Thứ Tư dưới mái hiên,
## Thứ Năm dưới cây dầu cạnh chén nước, Thứ Hai miếng chả cá ở đầu hẻm 42, và Bơ ngủ trưa cạnh Mực.
## Chạy: xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
##   -s tools/chup_muc_tuan.gd -- --chup=<thư_mục_ảnh>

var out := "anh_muc_tuan"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chup="):
			out = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	DoKho.force = -1
	GameState.use_test_save("user://luu_game_chup_muc_tuan.cfg")
	_run.call_deferred()


func _run() -> void:
	for day in ["thu_ba", "thu_tu", "thu_nam"]:
		var m := await _load(day)
		var mt: MucTuan = m.get_node("MucTuan")
		var spot: Vector3 = mt._moment.spot
		var face: Vector3 = mt._moment.get("face", spot + Vector3.FORWARD)
		var back := (spot - face).normalized()
		m.player.global_position = spot + back.cross(Vector3.UP) * 1.2 + Vector3(0, 0.1, 0)
		var cam := spot - back * 3.2 + back.cross(Vector3.UP) * 1.5 + Vector3(0, 1.4, 0)
		if day == "thu_ba":
			cam = spot + Vector3(-1.2, 1.5, -3.2)  # từ lòng đường nhìn vào sạp khô cá
		await _shot(m, day + "_gan", cam, spot + Vector3(0, 0.4, 0))
		await _shot(m, day + "_xa", spot - back * 9.0 + Vector3(0, 5.0, 0), spot)
		m.queue_free()
	var m := await _load("thu_hai")
	var mt: MucTuan = m.get_node("MucTuan")
	m.order_index = 4
	m._pick_up(m.orders[4])
	m.player.global_position = MucTuan.CHA_CA_SPOT + Vector3(0.8, 0.1, -1.6)
	await _frames(5)
	mt.drop_cha_ca()
	await _shot(m, "cha_ca_tha", MucTuan.CHA_CA_SPOT + Vector3(0.8, 1.4, -3.0), MucTuan.CHA_CA_SPOT + Vector3(0, 0.3, 1.5))
	for i in 60 * 6:
		await process_frame
		if mt._ctl == "snack_sleep":
			break
	await _shot(m, "cha_ca_ngu", MucTuan.CHA_CA_SPOT + Vector3(0.6, 1.3, 2.6), MucTuan.CHA_CA_SPOT + Vector3(0, 0.25, 0.3))
	m.queue_free()
	m = await _load("thu_hai")
	mt = m.get_node("MucTuan")
	m.dog.awake = false
	m.player.global_position = m.dog.global_position + Vector3(0.9, 0.1, 0)
	m.player.velocity = Vector3.ZERO
	for i in 60 * 7:
		await process_frame
		if mt._napping and mt._nap_t > 2.0:
			break
	var d: Vector3 = m.dog.global_position
	await _shot(m, "ngu_trua", d + Vector3(2.6, 2.0, -2.6), d + Vector3(0.45, 0.2, 0), true)
	quit()


func _load(day: String) -> Node:
	PlayMode.day = day
	GameState.day = day  # chợ Thứ Ba đọc GameState.day
	PlayMode.mode = PlayMode.Mode.DELIVERY
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(20)
	scene.state = scene.State.PLAY
	scene.player.can_move = true
	for layer in scene.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	return scene


func _shot(m: Node, shot_name: String, cam_pos: Vector3, look: Vector3, game_cam := false) -> void:
	var cam: Camera3D
	if not game_cam:
		cam = Camera3D.new()
		cam.fov = 55.0
		cam.far = 300.0
		m.add_child(cam)
		cam.global_position = cam_pos
		cam.look_at(look)
		cam.make_current()
	await _frames(15)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
	print("[chup] ", shot_name)
	if cam:
		cam.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
