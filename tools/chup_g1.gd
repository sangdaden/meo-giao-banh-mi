extends SceneTree
## Chụp các chỗ G1 thay khối tạm trên phố (ngày Thứ Bảy: phố đủ đồ + võng Chị Thu + bồn nước kết ngày) ra PNG để soát.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_g1.gd -- <thư_mục_ra>

var out := "user://chup_g1"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	PlayMode.day = "thu_bay"
	GameState.use_test_save("user://luu_game_chup_g1.cfg")
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	await _wait(40)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % name))
	print("đã chụp ", name)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(30)
	var main: Node = current_scene
	var tb: ThuBay = main.get_node("ThuBay")
	main.hud.visible = false
	main.player.global_position = Vector3(-30.0, 0.1, 0.0)
	cam = Camera3D.new()
	main.add_child(cam)
	cam.fov = 55
	cam.current = true
	var c := CityProps.BA_SAU_CHAIR
	await _shot("1_ghe_may_ba_sau", c + Vector3(1.6, 1.4, -1.8), c + Vector3(0, 0.5, 0))
	c = CityProps.CAFE_COUNTER
	await _shot("2_quay_ca_phe", c + Vector3(1.2, 1.0, -2.4), c)
	await _shot("3_ghe_da_cong_vien", Vector3(-36.0, 1.6, 12.5), Vector3(-38.0, 0.3, 10.0))
	await _shot("4_lu_nuoc_hem", Vector3(-37.0, 1.6, -15.8), Vector3(-40.5, 0.4, -16.25))
	c = ThuBay.HAMMOCK
	await _shot("5_vong_chi_thu", c + Vector3(-3.4, 2.4, 0.7), c + Vector3(0, 0.5, 0))
	tb._show_end_spot()
	c = tb._end_pos()
	await _shot("6_bon_nuoc_ket_ngay", c + Vector3(1.8, 1.8, 2.8), c + Vector3(-0.9, 0.8, -0.15))
	await _shot("7_khach_ca_phe", Vector3(-1.0, 1.7, 1.0), Vector3(-3.0, 0.5, 6.0))
	# Giao thông đứng hình: xe gần ngã tư nhất, chụp ngang và chéo; người bán xe đẩy
	var traffic: Node3D
	for n in main.get_children():
		if n.has_method("_build_carts"):
			traffic = n
	traffic.set_physics_process(false)
	var bikes: Array = traffic.get("_bikes").filter(func(b): return b.active and not b.bus)
	bikes.sort_custom(func(a, b): return a.xf.origin.distance_to(Vector3(-24, 0, 2)) < b.xf.origin.distance_to(Vector3(-24, 0, 2)))
	for k in 2:
		var b = bikes.filter(func(x): return x.pillion == (k == 1))[0]
		var o: Vector3 = b.xf.origin
		await _shot("8_nguoi_lai_%d" % k, o + b.xf.basis.x * 2.6 + b.xf.basis.z * -1.2 + Vector3(0, 1.3, 0), o + Vector3(0, 0.9, 0))
	var cart: Node3D = traffic.get("_carts")[0].body
	await _shot("9_nguoi_ban_xe_day", cart.global_position + cart.global_basis.z * 3.0 + cart.global_basis.x * 1.8 + Vector3(0, 1.4, 0),
		cart.global_position + Vector3(0, 0.9, 0))
	quit()
