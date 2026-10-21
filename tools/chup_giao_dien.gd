extends SceneTree
## Chụp các màn giao diện ra PNG để soát lại so với bản phác thảo.
## Chạy (cần màn hình, trên máy đám mây dùng xvfb-run):
##   godot --path . --rendering-driver opengl3 -s tools/chup_giao_dien.gd -- <thư_mục_ra>

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
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("đã chụp ", name)


func _run() -> void:
	change_scene_to_file("res://scenes/menu.tscn")
	await _wait(30)
	await _shot("1_man_hinh_chinh")
	var menu := current_scene
	menu.settings.open()
	await _shot("2_cai_dat")
	menu.settings.close()
	menu.wardrobe.open()
	await _shot("3_tu_do")

	change_scene_to_file("res://scenes/main.tscn")
	await _wait(60)
	var main := current_scene
	await _shot("4_hud_ve_lo")
	main.player.global_position = Vector3(10, 0.2, 2)
	main._pick_up(main.ORDERS[2])
	main.order_index = 2
	main.results = [3, 2]
	main.result_notes = ["dư 6 giây", "dư 3 giây"]
	main.hud.set_progress(main.results)
	main.carry_time = 14.0
	main.time_left = 9.0
	await _wait(20)
	await _shot("5_hud_giao")
	main.rig.yaw += PI * 0.8
	await _wait(20)
	await _shot("5b_mui_ten_mep")
	main.hud.set_pause_info(main._pause_info())
	main.hud.toggle_pause()
	await _shot("6_tam_dung")
	main.hud.toggle_pause()
	main.results = [3, 2, 3, 0]
	main.result_notes = ["dư 6 giây", "dư 3 giây", "dư 8 giây", "hết giờ", ]
	main.order_index = 4
	main.bites = 1
	main.player.carrying = true
	main.time_left = 10.0
	main._deliver(main.ORDERS[4])
	await _wait(10)
	await _shot("8_ket_qua")

	var kh := KitchenHud.new()
	root.add_child(kh)
	main.hud.visible = false
	main.hud.end_screen.visible = false
	kh.set_clock("5:12 sáng", "Còn 2:04 tới giờ mở bán")
	var items := ["Bánh", "Pate", "Thịt", "Chả", "Dưa", "Ngò", "Ớt"]
	kh.set_tickets([
		{"title": "Ổ 1 · bánh mì thịt", "items": items, "done": [true, true, true, true, false, false, false], "current": 4},
		{"title": "Ổ 2 · bánh mì thịt", "items": items, "done": [], "current": -1},
	])
	kh.show_prompt("E", "Thái dưa leo")
	kh.set_held("Dưa leo đã rửa", Color("#3F8A5C"))
	kh.add_bubble("lo", main.player.global_position + Vector3(-2, 2, 0), "Lò · chín sau 4s", 0.7)
	kh.show_closeup("Chẻ dọc dưa leo", "bấm khi dao vào vùng xanh", 2, 3)
	kh.set_closeup_meter(0.47, 0.52, 0.68)
	await _shot("7_hud_bep")
	quit()
