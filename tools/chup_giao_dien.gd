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


func _wait_s(sec: float) -> void:
	await create_timer(sec).timeout


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
	var show: BoPreview = menu.showcase_cat
	show.cat.play_idle_action("lick", 4.0)
	await _wait_s(1.6)
	await _shot("1b_bo_liem_chan")
	show.cat.play_idle_action("sit", 5.0)
	await _wait_s(2.0)
	await _shot("1c_bo_ngoi")
	menu.settings.open()
	await _shot("2_cai_dat")
	menu.settings.close()
	menu.wardrobe.open()
	await _wait(30)
	await _shot("3_tu_do")
	var wd: WardrobePanel = menu.wardrobe
	wd.preview.yaw += PI * 0.6
	await _shot("3b_tu_do_xoay")
	wd.show_tab(1)
	await _shot("3c_phu_kien")
	wd.show_tab(1, "neck")
	Outfit.toggle("khando")
	wd._refresh()
	await _wait(10)
	await _shot("3d_thao_khan")
	Outfit.toggle("khando")
	wd.show_tab(2)
	await _shot("3e_bo_do")
	# Mặc thử món khoá (chỉ xem trên bục)
	wd.show_tab(1)
	wd.preview.yaw = wd.preview.start_yaw
	for id in ["munlen", "kinhram", "tatsoc", "noduoi"]:
		wd._try[Outfit.acc(id)[3]] = id
	wd._refresh()
	await _wait(10)
	await _shot("3f_mac_thu")
	wd.preview.yaw += PI * 0.7
	await _shot("3g_mac_thu_xoay")
	wd.preview.yaw -= PI * 0.7
	wd.show_tab(0)
	wd._try_breed = "muop"
	wd._refresh()
	await _wait(10)
	await _shot("3h_thu_giong")
	wd.close()

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
	main.hud.set_kitchen_stars(2)
	main.hud._playing = true
	main.hud.set_stance("sneak")
	await _wait(20)
	await _shot("5_hud_giao")
	main.hud.set_kitchen_stars(-1)
	main.hud.set_stance("walk")
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
	# Bảng kết quả Thứ Hai với dữ liệu mẫu của luồng chấm điểm
	var rows := []
	var sample := [
		["Chú Tư", "Sạp báo", "Bánh mì thịt", "#2E7C80", 3, 2, "Ngậm báo về cho Cô Ba", true, false, "dư 6 giây"],
		["Bé Na", "Ban công lầu 2", "Bánh mì trứng", "#E8913A", 3, 3, "Bỏ giỏ trúng nhịp đầu", true, false, "dư 4 giây"],
		["Chị Mây", "Quán cà phê", "Bánh mì xíu mại", "#C8412F", 2, 2, "Không đổ ly nào", false, false, "dư 2 giây · đụng bàn"],
		["Anh Hùng", "Tiệm sửa xe", "Bánh mì pate", "#3F8A5C", 1, 1, "Không giẫm dầu", false, true, "hết giờ"],
		["Bà Sáu", "Hẻm 42", "Bánh mì chả", "#7A5236", 3, 3, "Chó Mực không thức", true, false, "qua mặt Chó Mực"],
	]
	for x in sample:
		rows.append({"who": x[0], "place": x[1], "item": x[2], "color": Color(x[3]), "stars": x[4], "kitchen_stars": x[5],
			"side_quest": x[6], "side_ok": x[7], "late": x[8], "note": x[9], "tip": 0 if x[8] else x[4] * 5000 + (3000 if x[7] else 0)})
	main.hud.show_results(rows, {"stars": 12, "stars_max": 15, "tip": 64000, "bonus": 0, "rank": "gion",
		"stamps": 3, "stamps_total": 5, "stamps_all": 3, "new_record": true, "day": "Thứ Hai", "wallet": 64000})
	await _wait(10)
	await _shot("8b_ket_qua_thu_hai")

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
