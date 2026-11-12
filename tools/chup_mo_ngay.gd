extends SceneTree
## Chụp soát GC1 + GC5 + bản demo W2: Chọn màn khi Thứ Ba vừa mở, ngày còn khóa, bản demo, Cài đặt,
## bảng kết quả Thứ Hai (món để dành + ngày mai), bảng kết quả Thứ Ba bản demo (hết demo).
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/chup_mo_ngay.gd -- <thư_mục_ra> [--lang=en]
## Ảnh để ngoài thư mục project.

var out := "user://chup"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await _wait(8)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("đã chụp ", name)


func _run() -> void:
	GameState.use_test_save("user://luu_game_chup_mo_ngay.cfg")  # file lưu riêng, không đụng file thật
	var het: bool = GameSettings.get_value("mo_het_ngay")
	var da_xem: String = GameSettings.get_value("mo_khoa_da_xem")
	GameSettings.set_value("mo_het_ngay", false)
	GameSettings.set_value("mo_khoa_da_xem", "")
	GameState.set_day("so_lan_choi", 1, "thu_hai")
	GameState.set_day("sao_cao_nhat", 13, "thu_hai")
	GameState.set_global("ngay_tiep", "thu_ba")

	change_scene_to_file("res://scenes/menu.tscn")
	await _wait(30)
	current_scene.level_select.open()
	await _wait(4)
	await _shot("1_chon_man_thu_ba_moi_mo")
	current_scene.level_select._select("thu_tu")
	await _shot("2_chon_man_thu_tu_khoa")
	current_scene.level_select.close()
	current_scene.settings.open()
	await _shot("3_cai_dat_mo_het_ngay")
	current_scene.settings.close()

	ProjectSettings.set_setting("meo/ban_demo", true)
	change_scene_to_file("res://scenes/menu.tscn")
	await _wait(30)
	current_scene.level_select.open()
	current_scene.level_select._select("thu_tu")
	await _shot("4_demo_thu_tu_ban_day_du")
	ProjectSettings.set_setting("meo/ban_demo", false)

	# Bảng kết quả Thứ Hai: đang để dành kính râm (15.000đ), ví 10.000đ
	GameState.set_global("vi_tien_boa", 10000)
	GameState.set_global("de_danh", ["kinhram"])
	await _results("thu_hai", "Thứ Hai", "5_ket_qua_thu_hai")
	# Bản demo hết Thứ Ba
	ProjectSettings.set_setting("meo/ban_demo", true)
	GameState.set_global("de_danh", ["mubaohiem"])
	await _results("thu_ba", "Thứ Ba", "6_ket_qua_het_demo")
	ProjectSettings.set_setting("meo/ban_demo", false)

	GameSettings.set_value("mo_het_ngay", het)
	GameSettings.set_value("mo_khoa_da_xem", da_xem)
	DirAccess.remove_absolute(GameState.save_path)
	quit()


func _results(day: String, name: String, shot: String) -> void:
	PlayMode.day = day
	GameState.day = day
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(60)
	var main := current_scene
	PlayMode.continuous = true
	GameState.day = day
	main.state = main.State.END
	var rows := []
	for i in 5:
		var o: Dictionary = main.orders[i]
		rows.append({"who": o.who, "place": o.place, "item": o.item, "color": o.color, "stars": 3 if i != 2 else 2,
			"note": "dư 6 giây", "index": i + 1, "tip": 15000, "side_quest": o.get("side_quest", ""), "side_ok": i != 2,
			"late": false})
	main.hud.show_results(rows, {"stars": 14, "stars_max": 15, "tip": 75000, "bonus": 0, "rank": "vang", "stamps": 4,
		"stamps_total": 5, "stamps_all": 4, "new_record": true, "day": name, "wallet": GameState.get_global("vi_tien_boa", 0)})
	await _shot(shot)
