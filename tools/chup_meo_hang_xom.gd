extends SceneTree
## Chụp mèo hàng xóm của từng ngày (scripts/meo_hang_xom.gd) ở chỗ đứng, để soát vị trí và cảnh chào.
## Chạy: xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 -s tools/chup_meo_hang_xom.gd -- <thư_mục_ra>

var out := "user://chup_meo_hang_xom"
const DAYS := ["thu_hai", "thu_ba", "thu_tu", "thu_nam", "thu_sau", "thu_bay"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameState.use_test_save("user://luu_game_chup_meo_hang_xom.cfg")
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(name: String, frames := 30) -> void:
	await _wait(frames)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % name))
	print("đã chụp ", name)


## Chỗ đặt máy quay trống nhất quanh `at` (8 hướng, tia dò không vướng nhà).
func _eye(main: Node3D, at: Vector3, dist: float, up: float) -> Vector3:
	var space := main.get_world_3d().direct_space_state
	var best := at + Vector3(0, up + 2.0, 0)
	var best_d := -1.0
	var from := at + Vector3(0, up, 0)
	for k in 8:
		var a := k * TAU / 8.0
		var to := from + Vector3(sin(a), 0, cos(a)) * dist
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
		var d := dist if hit.is_empty() else from.distance_to(hit.position) - 0.3
		if d > best_d + 0.01:
			best_d = d
			best = from + Vector3(sin(a), 0, cos(a)) * d
	return best


func _run() -> void:
	for d in DAYS:
		PlayMode.day = d
		change_scene_to_file("res://scenes/main.tscn")
		await _wait(40)
		var main: Node = current_scene
		var mhx: Node = main.find_child("MeoHangXom", true, false)
		if mhx == null:
			print("không có MeoHangXom ở ", d)
			continue
		main.hud.visible = false
		var cam := Camera3D.new()
		main.add_child(cam)
		cam.current = true
		cam.fov = 55
		for id in mhx.cats:
			var m: Node3D = mhx.cats[id]
			var f := m.global_basis.z * -1.0
			cam.global_position = _eye(main, m.global_position, 2.6, 1.1)
			cam.look_at(m.global_position + Vector3(0, 0.25, 0))
			await _shot("%s_%s_gan" % [d, id])
			cam.global_position = _eye(main, m.global_position, 8.0, 3.5)
			cam.look_at(m.global_position)
			await _shot("%s_%s_xa" % [d, id], 10)
			# chào kiểu mèo: Bơ đứng sát
			var p: CharacterBody3D = main.player
			p.global_position = m.global_position + f * 0.9 + Vector3(0, 0.05, 0)
			await _wait(10)
			mhx._on_q(m, p.global_position)
			cam.global_position = _eye(main, m.global_position, 2.0, 0.9)
			cam.look_at(m.global_position + Vector3(0, 0.25, 0))
			await _shot("%s_%s_chao" % [d, id], 25)
			p.global_position = City.BAKERY_POINT + Vector3(0, 0.1, 2.5)
	quit()
