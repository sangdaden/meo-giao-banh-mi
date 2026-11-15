extends SceneTree
## Chụp đồ 3D chuyện "Bí mật cho Cô Ba" trong game (scripts/chuyen/do_chuyen.gd): thư ở miệng Bơ, báo Chú Tư, bảng đồng trên cửa lò bánh.
## Dùng file lưu riêng (đã nhận thư 1, đã qua buổi bất ngờ Chủ Nhật), không đụng file thật.
## Chạy: xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_do_chuyen.gd -- <thư_mục_ra>

var out := "user://chup_do_chuyen"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("đã chụp ", name)


func _run() -> void:
	GameState.use_test_save("user://luu_game_chup_do_chuyen.cfg")
	GameState.set_global(Chuyen.THU_KEY, ["nhan1"])
	GameState.set_day("huy_chuong", [1], "chu_nhat")
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(30)
	var main: Node = current_scene
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 40
	cam.current = true
	main.hud.visible = false
	for c in main.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	# bảng đồng trên mi cửa lò bánh
	cam.global_position = City.BAKERY_POINT + Vector3(0.9, 1.6, 2.6)
	cam.look_at(City.BAKERY_POINT + Vector3(0, 2.4, -0.8))
	await _wait(40)
	_shot("bang_dong")
	# báo Chú Tư
	var paper: Node3D = main.deliveries.get("_tu_paper")
	if paper:
		cam.fov = 30
		cam.global_position = paper.global_position + Vector3(0.3, 0.2, 1.6)
		cam.look_at(paper.global_position)
		await _wait(20)
		_shot("bao_chu_tu")
	# thư ở miệng Bơ
	main.player.set_physics_process(false)
	await _wait(10)
	var fwd: Vector3 = -main.player.global_transform.basis.z
	var head: Vector3 = main.player.global_position + Vector3(0, 0.4, 0) + fwd * 0.3
	for v in [["thu_mieng_truoc", fwd * 1.1 + Vector3(0, 0.15, 0) + fwd.cross(Vector3.UP) * 0.4], ["thu_mieng_ngang", fwd.cross(Vector3.UP) * 1.0 + Vector3(0, 0.1, 0)]]:
		cam.fov = 35
		cam.global_position = head + v[1]
		cam.look_at(head)
		await _wait(15)
		_shot(v[0])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://luu_game_chup_do_chuyen.cfg"))
	print("CHUP DO CHUYEN OK")
	quit()
