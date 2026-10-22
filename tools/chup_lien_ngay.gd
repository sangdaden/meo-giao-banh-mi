extends SceneTree
## Chụp chơi liền các ngày ra PNG để soát: trang chủ "Chơi tiếp", màn Chọn ngày (Esc), bảng tổng kết có nút sang ngày kế.
## Chạy (cần màn hình, trên máy đám mây dùng xvfb-run):
##   godot --path . --rendering-driver opengl3 -s tools/chup_lien_ngay.gd -- <thư_mục_ra>

var out := "user://chup"


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
	await _wait(6)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("đã chụp ", name)


func _run() -> void:
	GameState.use_test_save("user://luu_game_chup.cfg")  # file lưu riêng, không đụng file thật
	change_scene_to_file("res://scenes/menu.tscn")
	await _wait(30)
	await _shot("1_trang_chu_moi")

	GameState.set_global("ngay_tiep", "thu_ba")
	change_scene_to_file("res://scenes/menu.tscn")
	await _wait(30)
	await _shot("2_trang_chu_choi_tiep")
	current_scene.level_select.open()
	await _shot("3_esc_chon_ngay")

	# Bảng tổng kết Thứ Hai trong mạch tuần
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(60)
	var main := current_scene
	PlayMode.continuous = true
	GameState.day = "thu_hai"
	main.state = main.State.END
	var rows := []
	for i in 5:
		var o: Dictionary = main.orders[i]
		rows.append({"who": o.who, "place": o.place, "item": o.item, "color": o.color, "stars": 3, "note": "dư 6 giây",
			"index": i + 1, "tip": 15000, "side_quest": o.get("side_quest", ""), "side_ok": true, "late": false})
	main.hud.show_results(rows, {"stars": 15, "stars_max": 15, "tip": 95000, "bonus": 20000, "rank": "vang", "stamps": 5,
		"stamps_total": 5, "stamps_all": 5, "new_record": true, "day": "Thứ Hai", "wallet": 95000})
	await _shot("4_tong_ket_sang_thu_ba")
	DirAccess.remove_absolute(GameState.save_path)
	quit()
