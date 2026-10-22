extends SceneTree
## Chụp các chỗ Thứ Năm dùng model G1 bản 2 (cửa cuốn, võng Anh Hùng, gác lửng Chị Mây, tủ báo Chú Tư) ra PNG.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 -s tools/chup_thu_nam.gd -- <thư_mục_ra>

var out := "user://chup_thu_nam"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(cam: Camera3D, from: Vector3, at: Vector3, file: String, frames := 40) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.current = true
	await _wait(frames)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(file))
	print("đã chụp ", file)


func _run() -> void:
	PlayMode.day = "thu_nam"
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(30)
	var main: Node = current_scene
	var tn: ThuNam = main.get_node("ThuNam")
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 60
	main.player.can_move = false
	main.player.global_position = ThuNam.LOFT_STEPS[0] + Vector3(0.9, 0.1, -0.6)
	await _shot(cam, Vector3(32.3, 1.8, 29.5), Vector3(32.3, 1.2, ThuNam.SHUTTER_Z), "1_cua_cuon.png")
	await _shot(cam, Vector3(33.8, 1.9, 19.5), ThuNam.HAMMOCK + Vector3(0, 0.6, 0), "2_vong_hung.png")
	await _shot(cam, Vector3(8.5, 2.6, 0.5), Vector3(8.3, 1.8, 6.4), "3_gac_lung.png")
	await _shot(cam, Vector3(13.0, 3.4, 2.0), Vector3(8.0, 2.6, 6.0), "3b_gac_ben.png")
	tn._basket_t = 0.0
	tn._lower_basket(0.7)
	await _shot(cam, Vector3(5.0, 1.8, 2.0), Vector3(6.2, 1.8, 5.6), "4_tha_gio.png")
	await _shot(cam, ThuNam.SHELF + Vector3(1.5, 1.8, 3.0), ThuNam.SHELF + Vector3(0.6, 0.9, 0), "5_tu_bao.png")
	tn._show_ice(true)
	tn._set_ice("nua")
	var bo: Node3D = main.player
	await _shot(cam, bo.global_position + Vector3(0.9, 0.7, 0.9), bo.global_position + Vector3(0, 0.35, 0), "6_bich_da.png")
	quit()
