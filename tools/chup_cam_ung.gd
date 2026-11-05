extends SceneTree
## Chụp nút cảm ứng G3 (scripts/cam_ung.gd) ở khung điện thoại nằm ngang 19.5:9: ngoài phố (đang giữ cần đi) và trong bếp.
## Chạy: xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1560x720 -s tools/chup_cam_ung.gd -- --cam-ung <thư_mục_ra>

var out := "user://chup_cam_ung"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	PlayMode.day = "thu_hai"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	GameState.use_test_save("user://luu_game_chup_cam_ung.cfg")
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String, frames := 40) -> void:
	await _wait(frames)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % name))
	print("đã chụp ", name)


func _cham(i: int, p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = root.get_final_transform() * p
	e.pressed = pressed
	Input.parse_input_event(e)


func _run() -> void:
	CamUng.bat = true
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(30)
	current_scene.start_game()
	await _wait(240)  # chờ thẻ mở đầu ngày tắt
	var vs := root.get_visible_rect().size
	_cham(0, Vector2(220, vs.y - 200), true)
	var d := InputEventScreenDrag.new()
	d.position = root.get_final_transform() * Vector2(270, vs.y - 250)
	Input.parse_input_event(d)
	await _shot("pho")
	_cham(0, Vector2(270, vs.y - 250), false)
	change_scene_to_file("res://scenes/kitchen.tscn")
	await _wait(30)
	current_scene.start_game()
	await _shot("bep", 120)
	quit()
