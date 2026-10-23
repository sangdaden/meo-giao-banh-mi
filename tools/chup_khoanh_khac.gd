extends SceneTree
## Chụp khoảnh khắc giao bánh (scripts/khoanh_khac_giao.gd) của từng đơn trong ngày ra PNG để soát khung hình.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_khoanh_khac.gd -- <thư_mục_ra> [ngày] [trễ]
## Mỗi đơn: Bơ đứng chỗ giao, diễn động tác giao, main chấm đơn; chụp 3 khung: 0,1 s, 0,6 s, 1,2 s sau khi máy lại gần.
## Thêm "tre" để chụp bản giao trễ (Bơ xin_loi, 1 sao vàng 2 sao trống).

var out := "user://chup_khoanh_khac"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		PlayMode.day = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.set_value("khoanh_khac", 0)
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _run() -> void:
	var late := "tre" in OS.get_cmdline_user_args()
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(20)
	var main: Node = current_scene
	main.start_game()
	main.hud.visible = false  # chỉ soát khung hình 3D: tấm giới thiệu ngày, mẹo, bảng đơn không che
	await _wait(10)
	var kk: Node = main.get_node("KhoanhKhacGiao")
	for i in main.orders.size() - 1:
		var order: Dictionary = main.orders[i]
		if str(order.get("kind", "")) == "errand":
			continue
		main.order_index = i
		main._pick_up(order)
		var at: Vector3 = main.deliveries.stand_point(i) + Vector3(0, 0.1, 0)
		if str(order.get("delivery", "")) == "basket":
			at = CityProps.BE_NA_BIKE + Vector3(1.0, 0.1, 0.3)  # đứng đất cạnh xe máy, dưới ban công Bé Na
		main.player.global_position = at
		main.player.velocity = Vector3.ZERO
		await _wait(30)
		main.late = late
		main.player.play_deliver("hand")
		main.order_index = i
		main._deliver(order)
		for f in 120:  # động tác giao 1,6 s (khung hình cố định 30/giây)
			if kk._dang:
				break
			await process_frame
		print("đơn %d: khách %s" % [i + 1, kk._khach])
		for k in [3, 15, 33]:
			while kk._dang and kk._t < k / 30.0:
				await process_frame
			var img := root.get_viewport().get_texture().get_image()
			img.save_png(out.path_join("don_%d_%02d%s.png" % [i + 1, k, "_tre" if late else ""]))
		while kk._dang:
			await process_frame
		await _wait(10)
		print("đã chụp đơn ", i + 1)
	quit()
