extends SceneTree
## Chụp màn Chọn màn ra PNG (có và chưa có kỷ lục) để soát lại.
## Chạy (cần màn hình, trên máy đám mây dùng xvfb-run):
##   godot --path . --rendering-driver opengl3 -s tools/chup_chon_man.gd -- <thư_mục_ra>

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
	var menu := current_scene
	menu.level_select.open()
	await _shot("1_chon_man_chua_choi")
	menu.level_select.close()

	# Giả một file lưu đã chơi vài lần
	GameState.set_day("sao_cao_nhat", 12)
	GameState.set_day("hang_cao_nhat", "gion")
	GameState.set_day("boa_cao_nhat", 73000)
	GameState.set_day("so_lan_choi", 3)
	GameState.set_day("sao_bep", 2)
	GameState.set_day("sao_don", [3, 3, 2, 3, 1])
	GameState.set_day("ky_luc_don", [9.4, 15.2, 12.8, 21.6, 19.0])
	menu.level_select.open()
	await _shot("2_chon_man_da_choi")
	menu.level_select._select("thu_bay")
	await _shot("3_ngay_sap_co")
	DirAccess.remove_absolute(GameState.save_path)
	quit()
