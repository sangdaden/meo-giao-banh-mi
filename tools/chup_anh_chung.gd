extends SceneTree
## Chụp bong bóng G9 và 10 tấm ảnh chung Thứ Bảy (bố cục AnhChung) ra PNG để soát.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_anh_chung.gd -- <thư_mục_ra>

var out := "user://chup_anh_chung"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	PlayMode.day = "thu_bay"
	GameState.use_test_save("user://luu_game_chup_anh_chung.cfg")
	GameState.set_day("so_trang", [], "thu_bay")
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String, frames := 40) -> void:
	await _wait(frames)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % name))
	print("đã chụp ", name)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(30)
	var main: Node = current_scene
	var tb: ThuBay = main.get_node("ThuBay")
	var p: CharacterBody3D = main.player
	main.hud.visible = true
	# Bong bóng: Cô Ba "cho", Chú Tư "dang"
	p.global_position = City.BAKERY_POINT + Vector3(1.5, 0.1, 2.5)
	tb._start("chutu")
	await _shot("0_bong_bong")
	for id in ["coba", "chutu", "bena", "may", "hung", "basau", "ongbay", "cohai", "chunam", "chithu"]:
		var n: Node3D = tb.people.get(id)
		if n:
			p.global_position = n.global_position + n.global_basis.z * 1.2 + Vector3(0, 0.1, 0)
		await _wait(5)
		tb._on_finished(id)
		await _shot("anh_" + id, 24)
		await _wait(80)
	await _shot("z_bong_xong")
	quit()
