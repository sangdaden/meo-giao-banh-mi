extends SceneTree
## Chụp sân giỗ nhà Bà Sáu (model G7) cuối hẻm 42 ra PNG để soát bố cục.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 -s tools/chup_san_gio.gd -- <thư_mục_ra> --ngay=thu_sau

var out := "user://chup_san_gio"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out = args[0]
	for a in args:
		if a.begins_with("--ngay="):
			PlayMode.day = a.trim_prefix("--ngay=")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(cam: Camera3D, from: Vector3, at: Vector3, file: String, frames := 60) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.current = true
	await _wait(frames)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(PlayMode.day + "_" + file))
	print("đã chụp ", file)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(30)
	var main: Node = current_scene
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 60
	main.player.can_move = false
	main.player.global_position = Vector3(-18.5, 0.1, 19.5)
	await _shot(cam, Vector3(-18.5, 2.2, 15.5), Vector3(-18.5, 1.2, 23.0), "1_tu_hem.png")
	await _shot(cam, Vector3(-18.5, 6.5, 19.0), Vector3(-18.5, 0.0, 24.5), "2_tren_cao.png")
	await _shot(cam, Vector3(-16.3, 2.0, 22.6), Vector3(-19.5, 0.6, 25.5), "3_trong_san.png")
	await _shot(cam, Vector3(-20.6, 2.6, 22.7), Vector3(-17.0, 0.9, 26.0), "4_ban_tho.png")
	quit()
