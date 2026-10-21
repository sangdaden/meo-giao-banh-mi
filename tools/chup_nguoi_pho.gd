extends SceneTree
## Chụp người dân trong màn giao bánh: Cô Ba ở quầy và hàng xóm (scripts/residents.gd).
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_nguoi_pho.gd -- <thư_mục_ra>

var out := "user://chup_nguoi_pho"


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
	cam.fov = 50
	main.hud.visible = false
	var r: Node3D = main.residents
	var shots: Array = r.people.duplicate()
	for i in main.orders.size():
		if main.deliveries.person(i):
			shots.append(main.deliveries.person(i))
	for k in shots.size():
		var n: Nguoi = shots[k]
		var p: Vector3 = n.global_position
		var i: int = k - r.people.size()
		if i >= 0:
			# Đang giao đơn i: khách chờ bánh
			main.order_index = i
			main.player.carrying = true
			main.time_left = 99.0
			main.deliveries.on_pick_up(i)
		var fwd := n.global_transform.basis.z
		# Bơ đứng trước mặt người dân 1,5 m để đầu họ quay nhìn
		main.player.global_position = p + fwd * 1.5 + Vector3(0.3, 0.1, 0)
		main.player.velocity = Vector3.ZERO
		if n.id == "coba":
			r.greet_shift(5)
		cam.global_position = p + fwd * 3.2 + fwd.cross(Vector3.UP) * 1.4 + Vector3(0, 1.4, 0)
		if p.y > 1.0:  # Bé Na trên ban công: chụp từ chỗ Bơ đứng dưới đường
			cam.global_position = main.deliveries.stand_point(i) + fwd * 1.0 + Vector3(-1.2, 1.4, 0)
		cam.look_at(p + Vector3(0, 0.8, 0))
		cam.current = true
		await _wait(60)
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out.path_join("pho_%02d_%s.png" % [k, n.id]))
		print("đã chụp ", n.id)
	quit()
