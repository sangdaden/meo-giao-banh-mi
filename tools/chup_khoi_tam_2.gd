extends SceneTree
## Chụp các chỗ "Khối tạm vòng 2" (D1 cột đèn, D3 đồ Thứ Bảy, D4 giá cục nóng gác lửng) ra PNG để soát.
## Vỏ chung cư Hoa Sữa (D2) chụp bằng tools/chup_chung_cu.gd.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_khoi_tam_2.gd -- <thư_mục_ra> [thu_bay|thu_nam]

var out := "user://chup_khoi_tam_2"
var day := "thu_bay"
var cam: Camera3D
var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		day = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	PlayMode.day = day
	GameState.use_test_save("user://luu_game_chup_khoi_tam_2.cfg")
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String, from: Vector3, at: Vector3, fov := 55.0) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(at)
	await _wait(40)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [day, name]))
	print("đã chụp ", name)


func _bo(p: Vector3) -> void:
	main.player.global_position = p
	main.player.velocity = Vector3.ZERO


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(30)
	main = current_scene
	main.hud.visible = false
	cam = Camera3D.new()
	main.add_child(cam)
	cam.current = true
	if day == "thu_nam":
		var a: Vector3 = ThuNam.LOFT_STEPS[2]
		_bo(Vector3(a.x - 1.2, 0.1, a.z - 1.0))
		await _shot("d4_gia_cuc_nong", Vector3(a.x - 0.6, 1.7, a.z - 3.0), Vector3(a.x, 1.1, a.z))
		await _shot("d4_gia_cuc_nong_xa", Vector3(a.x - 4.0, 3.2, a.z - 5.0), Vector3(a.x - 0.5, 1.6, a.z))
		quit()
		return
	# D1: cột đèn ngã tư phía tây, góc xe về đông và góc xe lên bắc
	var c: Vector2 = preload("res://scripts/traffic.gd").CROSSINGS[0]
	_bo(Vector3(c.x - 6.0, 0.1, 7.2))
	await _shot("d1_cot_den_gan", Vector3(c.x - 6.8, 2.6, 6.6), Vector3(c.x - 4.3, 2.8, 5.3), 50.0)
	await _shot("d1_nga_tu", Vector3(c.x - 10.0, 4.5, 11.0), Vector3(c.x, 1.5, 0.0), 60.0)
	await _shot("d1_cot_den_dem_so", Vector3(c.x + 1.5, 2.6, 7.0), Vector3(c.x + 4.3, 2.4, 5.3), 40.0)
	var tb: Node = main.get_node("ThuBay")
	# D3: chỗ ngủ trưa trên mái hiên khối 5
	var nap := ViecNho.surface(main.get_world_3d(), ThuBay.NAP_SPOT.x, ThuBay.NAP_SPOT.y)
	_bo(nap + Vector3(1.4, 0.05, 0.0))
	await _shot("d3_cho_ngu_trua", nap + Vector3(0.0, 3.0, 0.6), nap, 45.0)
	# D3: tờ báo Chú Tư bay ở chặng đầu, rồi Bơ ngậm bản cuộn
	tb._start("chutu")
	await _wait(60)
	var paper: Vector3 = tb._active.targets[0].pos
	_bo(paper + Vector3(1.5, 0.05, 0.5))
	await _shot("d3_to_bao_bay", paper + Vector3(0.0, 1.6, 0.4), paper, 40.0)
	tb._active._index = 2
	tb._active._pick_carry()
	_bo(paper + Vector3(0.8, 0.05, 0.0))
	await _shot("d3_to_bao_cuon", main.player.global_position + Vector3(0.2, 1.3, 0.9), main.player.global_position + Vector3(0, 0.35, 0))
	# D3: quân cờ lăn dưới gầm ghế đá, bụi cây, xe đạp; Bơ ngậm một quân về bàn
	tb._start("ongbay")
	await _wait(20)
	for i in 3:
		var p: Vector3 = tb._active.targets[i].pos
		_bo(p + Vector3(1.6, 0.1, 0.8))
		await _shot("d3_quan_co_%d" % (i + 1), p + Vector3(-0.5, 0.45, 0.6), p + Vector3(0, 0.05, 0))
	tb._active._index = 1
	tb._active._pick_carry()
	await _shot("d3_quan_co_ngam", main.player.global_position + Vector3(-0.6, 0.6, 0.8), main.player.global_position + Vector3(0, 0.35, 0))
	quit()
