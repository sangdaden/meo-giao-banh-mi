extends SceneTree
## Chụp tiệm xe chiều tà Thứ Sáu (model G6) và khe hông tiệm ra PNG để soát bố cục.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 -s tools/chup_tiem_xe.gd -- <thư_mục_ra> --ngay=thu_sau

var out := "user://chup_tiem_xe"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out = args[0]
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
	root.get_viewport().get_texture().get_image().save_png(out.path_join(file))
	print("đã chụp ", file)


func _run() -> void:
	PlayMode.day = "thu_sau"
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(30)
	var main: Node = current_scene
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 60
	var x := ThuSau.SHOP_X
	var f := ThuSau.SHOP_FRONT
	main.player.can_move = false
	main.player.global_position = ThuSau.LIFT_SPOT + Vector3(0, 0.1, 0.6)
	await _shot(cam, Vector3(x - 1.0, 2.6, f + 6.5), Vector3(x, 1.0, f - 3.0), "1_mat_tien.png")
	await _shot(cam, Vector3(x - 2.0, 1.8, f - 0.5), Vector3(x + 1.6, 0.6, f - 3.4), "2_cau_nang.png", 20)
	await _shot(cam, Vector3(x - 2.0, 1.8, f - 0.5), Vector3(x + 1.6, 0.6, f - 3.4), "3_cau_nang_sau.png", 75)
	await _shot(cam, Vector3(x + 2.0, 2.4, f - 7.0), Vector3(x - 1.0, 0.8, f - 1.0), "4_trong_ra.png")
	await _shot(cam, Vector3(28.9, 1.7, f + 3.5), Vector3(28.9, 1.0, f - 4.0), "5_khe_hong.png")
	await _shot(cam, Vector3(x - 1.5, 1.0, f + 4.0), Vector3(x - 1.9, 0.4, f + 1.0), "6_gia_lop.png")
	quit()
