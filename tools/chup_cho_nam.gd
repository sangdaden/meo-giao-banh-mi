extends SceneTree
## Chụp các chỗ nằm ưa thích (U1, scripts/cho_nam.gd) của từng ngày: vệt nắng, Bơ cuộn tròn nằm trong vệt;
## thêm khung máy ảnh phím P ở Thứ Hai (U3) và trang "Chỗ nằm ưa thích" trong Sổ hàng xóm Thứ Bảy.
## Chạy: xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_cho_nam.gd -- <thư_mục_ra>

var out := "user://chup_cho_nam"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameState.use_test_save("user://luu_game_chup_cho_nam.cfg")
	GameState.set_global(ChoNam.SAVE_KEY, [])
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await _wait(30)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join("%s.png" % name))
	print("đã chụp ", name)


func _run() -> void:
	for day: String in (["thu_hai", "thu_nam", "thu_sau"] if "--vai" in OS.get_cmdline_user_args() else Days.ORDER):
		PlayMode.day = day
		PlayMode.mode = PlayMode.Mode.DELIVERY
		change_scene_to_file("res://scenes/main.tscn")
		await _wait(40)
		var main: Node = current_scene
		var cn: ChoNam = main.get_node_or_null("ChoNam")
		if cn == null:
			continue
		var p: CharacterBody3D = main.player
		main.hud.visible = false
		main.rig.process_mode = Node.PROCESS_MODE_DISABLED  # máy quay game đứng yên, dùng máy quay riêng
		var cam := Camera3D.new()
		main.add_child(cam)
		cam.fov = 55
		for i in cn.spots.size():
			var pos: Vector3 = cn.spots[i].pos
			var side := 1.0 if pos.z > 0 else -1.0  # nhìn từ phía lòng đường vào
			_look(cam, pos + Vector3(2.2, 2.6, -3.2 * side), pos + Vector3(0, 0.3, 0))
			p.global_position = pos + Vector3(2.5, 0.1, 0)
			await _shot("%s_%d_vet" % [day, i + 1])
			p.global_position = pos + Vector3(0, 0.1, 0)
			p.velocity = Vector3.ZERO
			await _wait(150)
			await _shot("%s_%d_nam" % [day, i + 1])
		if day == "thu_hai":
			cam.current = false
			cam.queue_free()
			main.rig.process_mode = Node.PROCESS_MODE_INHERIT
			main.hud.visible = true
			p.global_position = City.BAKERY_POINT + Vector3(1.5, 0.1, 2.5)
			await _wait(20)
			var c: ChupAnh = main.get_node("ChupAnh")
			c.open()
			await _shot("thu_hai_may_anh")
			c.close()
		if day == "thu_bay":
			var tb: Node = main.get_node("ThuBay")
			tb.ui.toggle_book()
			var scroll: ScrollContainer = tb.ui.find_children("*", "ScrollContainer", true, false)[0]
			await _wait(5)
			scroll.scroll_vertical = 100000
			await _shot("thu_bay_so_cho_nam")
			tb.ui.toggle_book()
	quit()


func _look(cam: Camera3D, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.current = true
