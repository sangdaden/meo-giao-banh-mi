extends SceneTree
## Chụp 5 chỗ giao bánh (deliveries.gd) ra PNG để soát bố cục khối tạm.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_giao_banh.gd -- <thư_mục_ra>
## (--fixed-fps: máy ảo vẽ chậm, delta lớn làm lò xo hoạt hình Bơ chạy sai)

var out := "user://chup_giao"
## Góc chụp từng đơn: vị trí camera so với chỗ giao, và điểm nhìn
const VIEWS := [
	[Vector3(2.5, 2.2, 4.0), Vector3(0, 0.8, -0.7)],
	[Vector3(5.0, 2.2, 0.9), Vector3(1.2, 2.0, 0)],
	[Vector3(-1.0, 1.8, -3.2), Vector3(-2.5, 0.5, 0.6)],
	[Vector3(2.5, 2.0, 4.0), Vector3(0, 0.4, 0)],
	[Vector3(2.0, 2.4, -4.0), Vector3(-0.5, 1.0, 0.6)],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(20)
	var main: Node = current_scene
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 60
	for i in VIEWS.size():
		var p: Vector3 = main.ORDERS[i].pos
		# Đang giao đơn i: khách chìa tay, giỏ thòng xuống
		main.order_index = i
		main.player.carrying = true
		main.time_left = 99.0
		main.deliveries.on_pick_up(i)
		main.player.global_position = main.deliveries.stand_point(i) + Vector3(0, 0.1, 0.9 if i != 1 else 0.0)
		main.player.velocity = Vector3.ZERO
		cam.global_position = p + VIEWS[i][0]
		cam.look_at(p + VIEWS[i][1])
		cam.current = true
		await _wait(110)
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out.path_join("giao_%d.png" % (i + 1)))
		print("đã chụp đơn ", i + 1)
	quit()
