extends SceneTree
## Ảnh soát DK2/DK3: bụi khi đáp từ cao, bụi phanh, màn Cài đặt có các dòng mới.
## Chạy: xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
##   -s tools/chup_cam_giac_tay.gd -- <thu_muc_anh>

var out := "/tmp/chup_cam_giac_tay"


func _init() -> void:
	PlayMode.day = "thu_hai"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	GameState.use_test_save("user://luu_game_chup_cam_giac_tay.cfg")
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  chụp ", name)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var m: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await _frames(60)
	var bo: CharacterBody3D = m.player
	var rig = m.get_node("CameraRig")
	rig.first_person = false
	var start: Vector3 = City.BAKERY_POINT + Vector3(0, 0.1, 6.0)
	bo.global_position = start + Vector3.UP * 3.5
	rig.yaw = 0.6
	rig.pitch = -0.35
	for i in 200:
		await physics_frame
		if bo.is_on_floor():
			break
	rig.distance = 2.2
	rig._apply_view()
	await _frames(6)
	await _shot("bui_dap")
	await _frames(10)
	await _shot("bui_dap_2")
	rig.distance = 3.2
	rig._apply_view()
	await _frames(40)
	rig.yaw = PI / 2.0  # chạy dọc đường, khỏi đụng lề
	rig._manual_ms = Time.get_ticks_msec() + 100000
	await _frames(5)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for i in 50:
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _frames(4)
	print("  phanh: ", rig.get_node("CamGiacTay").so_lan_phanh)
	await _shot("bui_phanh")
	await _frames(8)
	await _shot("bui_phanh_2")
	m.queue_free()
	await _frames(5)
	var sp := SettingsPanel.new()
	root.add_child(sp)
	sp.open()
	sp._refresh()
	await _frames(10)
	var sc: ScrollContainer = sp.find_children("*", "ScrollContainer", true, false)[0]
	sc.scroll_vertical = 330
	await _frames(5)
	await _shot("cai_dat")
	quit()
