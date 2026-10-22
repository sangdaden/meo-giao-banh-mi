extends SceneTree
## Chụp màn Thứ Bảy dạo phố (khối tạm việc nhờ, sổ, trời theo nấc, Mực đi theo, bồn nước kết ngày) ra PNG để soát.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_thu_bay.gd -- <thư_mục_ra>

var out := "user://chup_thu_bay"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	PlayMode.day = "thu_bay"
	GameState.use_test_save("user://luu_game_chup_thu_bay.cfg")
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await _wait(40)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join("%s.png" % name))
	print("đã chụp ", name)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(30)
	var main: Node = current_scene
	var tb: ThuBay = main.get_node("ThuBay")
	var p: CharacterBody3D = main.player
	main.hud.visible = true
	# 1. Sáng: Bơ trước lò bánh, dấu ! trên đầu Cô Ba, sổ góc trên
	p.global_position = City.BAKERY_POINT + Vector3(1.5, 0.1, 2.5)
	await _shot("1_sang_lo_banh")
	# 2. Sổ hàng xóm mở
	tb.ui.toggle_book()
	await _shot("2_so_hang_xom")
	tb.ui.toggle_book()
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 60
	# 3. Chú Tư: tờ báo trên mái hiên
	tb._start("chutu")
	p.global_position = Vector3(-2.0, 0.1, -3.5)
	_look(cam, Vector3(1.5, 4.5, -1.0), Vector3(-3.5, 2.6, -6.5))
	await _shot("3_chu_tu_to_bao_mai_hien")
	# 4. Anh Hùng: 4 xe tạm, ốc dưới gầm
	tb._start("hung")
	p.global_position = Vector3(31.0, 0.1, 26.6)
	_look(cam, Vector3(34.0, 2.6, 29.0), Vector3(33.0, 0.3, 25.0))
	await _shot("4_anh_hung_oc_gam_xe")
	# 5. Bà Sáu: giàn bông giấy, 5 chùm hoa, chồng thùng
	tb._start("basau")
	p.global_position = Vector3(-18.5, 0.1, 20.5)
	_look(cam, Vector3(-16.0, 3.0, 18.0), Vector3(-18.6, 2.0, 23.4))
	await _shot("5_ba_sau_gian_bong_giay")
	# 6. Cô Hai: lon lăn và tháp lon
	tb._start("cohai")
	p.global_position = Vector3(8.0, 0.1, -4.6)
	_look(cam, Vector3(7.5, 3.2, -1.0), Vector3(7.5, 0.2, -6.0))
	await _shot("6_co_hai_thap_lon")
	# 7. Cô Ba: bảng chọn nhân
	cam.current = false
	tb._start("coba")
	await _shot("7_co_ba_chon_nhan")
	tb.ui.close_choice()
	tb._active.queue_free()
	tb._active = null
	tb._active_id = ""
	# 8. Trưa → chiều: trời ngả nấc
	tb._sky_t = 0.5
	tb._sky_goal = 0.5
	tb._apply_sky(0.5)
	p.global_position = Vector3(-10.0, 0.1, 2.0)
	await _shot("8_troi_trua")
	# 9. Hoàng hôn, Mực đi theo, bồn nước và mèo lạ trên mái hiên cạnh lò
	tb._sky_t = 1.0
	tb._sky_goal = 1.0
	tb._apply_sky(1.0)
	tb._befriend(false)
	p.global_position = Vector3(-26.0, 0.1, -3.5)
	await _wait(60)
	_look(cam, Vector3(-24.0, 4.5, -0.5), Vector3(-28.5, 2.6, -6.5))
	await _shot("9_hoang_hon_bon_nuoc_meo_la")
	# 10. Mực đi theo Bơ ở công viên
	cam.current = false
	p.global_position = Vector3(-30.0, 0.1, 14.0)
	for i in 90:
		p.velocity = Vector3(2.5, 0, 0)
		await process_frame
	await _shot("10_muc_di_theo")
	print("Mực cách Bơ %.1f m" % main.dog.global_position.distance_to(p.global_position))
	quit()


func _look(cam: Camera3D, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.current = true
