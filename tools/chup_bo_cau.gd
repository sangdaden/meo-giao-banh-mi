extends SceneTree
## Chụp bồ câu Thứ Bảy (K1 rắc vụn bánh, K2 bồ câu non lạc đàn và chuồng trên mái khối 2) ra PNG để soát.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_bo_cau.gd -- <thư_mục_ra>

var out := "user://chup_bo_cau"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	PlayMode.day = "thu_bay"
	GameState.use_test_save("user://luu_game_chup_bo_cau.cfg")
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await _wait(40)
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var tris := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % name))
	print("đã chụp %s · %d lệnh vẽ · %d tam giác" % [name, draws, tris])


func _look(cam: Camera3D, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.current = true


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(200)  # chờ thẻ "Thứ Bảy · Dạo phố" tắt
	var main: Node = current_scene
	var tb: ThuBay = main.get_node("ThuBay")
	var p: CharacterBody3D = main.player
	main.hud.visible = true
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 55
	# 1. Rắc vụn bánh: đàn sà xuống quanh chân Bơ
	var home := ThuBay.PIGEON_HOME
	p.global_position = home + Vector3(3.0, 0.1, 1.0)
	await _wait(10)
	tb.pigeons.on_called(p.global_position)
	await _wait(60)
	var mid: Vector3 = tb.pigeons._feed_at
	_look(cam, mid + Vector3(2.6, 1.6, -1.6), mid + Vector3(0, 0.2, 0))
	await _shot("1_rac_vun_banh")
	# 2. Bồ câu non lạc ở vỉa hè khối 5, chữ chíp chíp
	var non: BoCauNon = tb.baby_pigeon
	p.global_position = BoCauNon.LOST_AT + Vector3(2.5, 0.1, 0.4)
	_look(cam, BoCauNon.LOST_AT + Vector3(2.0, 1.2, -2.4), BoCauNon.LOST_AT + Vector3(0, 0.2, 0))
	await _shot("2_bo_cau_non_lac")
	# 3. Bồ câu non theo sau Bơ
	p.global_position = BoCauNon.LOST_AT + Vector3(0.4, 0.1, 0)
	await _wait(20)
	p.global_position = BoCauNon.LOST_AT + Vector3(0.4, 0.1, -2.5)
	await _wait(40)
	_look(cam, p.global_position + Vector3(2.5, 1.3, 1.0), p.global_position + Vector3(0, 0.2, 1.0))
	await _shot("3_theo_sau_bo")
	# 4. Đang dẫn: mẹ gù gù trên gờ mái khối 2, nhìn từ vỉa hè bên kia đường
	var below := non.below_coop()
	_look(cam, Vector3(below.x + 3.0, 1.6, 4.5), non.ledge + Vector3(0, 0.3, 0))
	await _shot("4_me_goi_tren_mai_khoi_2")
	non._settle()
	p.global_position = below + Vector3(0, 0.1, 0)
	await _shot("4b_ve_voi_me")
	_look(cam, non.coop + Vector3(1.6, 1.4, 2.4), non.coop + Vector3(0, 0.5, 0))
	await _shot("5_me_con_truoc_chuong")
	quit()
