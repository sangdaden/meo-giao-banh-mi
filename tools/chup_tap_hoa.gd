extends SceneTree
## Chụp tạp hóa Cô Hai và Bơ ngậm túi trứng (khối tạm) ra PNG để soát bố cục.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 -s tools/chup_tap_hoa.gd -- <thư_mục_ra> --ngay=thu_ba

var out := "user://chup_tap_hoa"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(cam: Camera3D, from: Vector3, at: Vector3, file: String) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.current = true
	await _wait(60)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(file))
	print("đã chụp ", file)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(20)
	var main: Node = current_scene
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 60
	var cx := (ShopTapHoa.X0 + ShopTapHoa.X1) / 2.0
	var front := ShopTapHoa.FRONT_Z
	# Bơ ngậm túi trứng đứng giữa lối đi trong tiệm, quay ra cửa
	var i := 1
	main.order_index = i
	main.player.global_position = ShopTapHoa.COUNTER_POINT + Vector3(0, 0.1, 0)
	main.player.carrying = true
	main.time_left = 99.0
	main.deliveries.on_pick_up(i)
	main.player.global_position = Vector3(cx - 0.4, 0.1, front + 3.0)
	main.player.velocity = Vector3.ZERO
	main.player.can_move = false
	await _wait(30)
	main.player.visual.rotation.y = 0.0  # nhìn về -z (ra cửa)
	await _shot(cam, Vector3(cx + 1.5, 3.0, front - 6.0), Vector3(cx, 1.2, front + 2.0), "1_mat_tien.png")
	await _shot(cam, Vector3(cx - 0.6, 1.7, front + 0.6), Vector3(cx + 0.2, 0.8, front + 6.0), "2_trong_tiem.png")
	await _shot(cam, main.player.global_position + Vector3(0.5, 0.35, -0.8), main.player.global_position + Vector3(0, 0.15, 0), "3_bo_ngam_tui_trung.png")
	# Vỡ hai quả: vệt trứng trên nền, túi còn 4
	main.player.bump("person")
	await _wait(40)
	main.player.bump("cart")
	await _wait(10)
	await _shot(cam, main.player.global_position + Vector3(0.6, 0.5, -0.9), main.player.global_position + Vector3(0, 0.05, 0), "4_vo_trung.png")
	quit()
