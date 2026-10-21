extends SceneTree
## Chụp chợ sáng Thứ Ba (market.gd) ra PNG để soát bố cục khối tạm, và in số lệnh vẽ của khung hình.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 -s tools/chup_cho.gd -- <thư_mục_ra> --cho
## Bỏ --cho để chụp cùng góc khi không có chợ (so số lệnh vẽ).

var out := "user://chup_cho"
## tên ảnh, vị trí camera, điểm nhìn, đơn (chỉ số) lúc chụp
const SHOTS := [
	["1_cho_toan_canh", Vector3(-16.0, 11.0, 1.5), Vector3(1.0, 0, 0), 0],
	["2_ngang_tam_meo", Vector3(-14.5, 1.0, -1.8), Vector3(-6.0, 0.6, -2.2), 0],
	["3_gam_sap", Vector3(-13.6, 0.3, -4.0), Vector3(-6.0, 0.3, -4.0), 0],
	["4_xe_bap_chan_hem", Vector3(18.5, 2.6, -15.4), Vector3(24.0, 0.6, -15.4), 0],
	["5_co_bay_ganh", Vector3(0, 1.4, 3.2), Vector3(0, 1.0, 0), 0],     # tính từ chỗ Cô Bảy
	["6_co_tu_ban_rau", Vector3(0.6, 1.2, 3.4), Vector3(0, 0.6, 0), 0],  # tính từ chỗ Cô Tư, z hướng ra lòng đường
	["7_cho_tan_don_4", Vector3(-16.0, 11.0, 1.5), Vector3(1.0, 0, 0), 3],
	["8_cho_tan_ba_gac", Vector3(-6.0, 5.0, -2.0), Vector3(-1.0, 0.4, 0.3), 4],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(20)
	var main: Node = current_scene
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 60
	main.player.global_position = Vector3(-15.0, 0.1, -4.0)  # Bơ đứng đầu chợ, sát dãy sạp bắc
	var traffic: Node = main.get_node("GiaoThong")
	for s in SHOTS:
		main.order_index = s[3]
		if s[0] == "4_xe_bap_chan_hem" and not traffic.blocked_alleys.is_empty():
			for i in 60 * 40:  # chờ tới lúc xe chè đứng chắn hẻm
				await physics_frame
				if traffic.blocked_alleys[0].blocked:
					break
		var base := Vector3.ZERO
		var off: Vector3 = s[1]
		var market: Node = main.get_node_or_null("ChoSang")
		if market and s[0].begins_with("5_"):
			base = market._ganh_shopper.pos
		elif market and s[0].begins_with("6_"):
			for sh in market._shoppers:
				if sh.person and sh.person.id == "bancho":
					base = sh.a
			off.z *= -signf(base.z)
		cam.global_position = base + off
		cam.look_at(base + s[2])
		cam.current = true
		await _wait(60 if s[3] == 0 else 60 * 14)
		var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		root.get_viewport().get_texture().get_image().save_png(out.path_join(s[0] + ".png"))
		print("đã chụp %s · %d lệnh vẽ" % [s[0], draws])
	quit()
