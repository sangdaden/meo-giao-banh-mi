extends SceneTree
## Chụp Bơ chào mèo hàng xóm bằng động tác luồng 7 (chạm mũi, cụng đầu, liếm đầu) để soát hai con không xuyên nhau.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 -s tools/chup_chao_meo.gd -- <thư_mục_ra>

var out := "user://chup_chao_meo"
## ngày, lần chào thứ mấy (0 = chạm mũi), các khung chụp (giây sau khi bấm Q)
const CANH := [["thu_ba", 0, [1.0, 1.3, 1.6]], ["thu_bay", 0, [1.4, 2.0, 2.6]], ["thu_sau", 0, [0.9, 1.5, 2.1]], ["thu_sau", 1, [0.9, 1.5, 2.1]]]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameState.use_test_save("user://luu_game_chup_chao_meo.cfg")
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _run() -> void:
	for c in CANH:
		PlayMode.day = c[0]
		change_scene_to_file("res://scenes/main.tscn")
		await _wait(30)
		var main: Node = current_scene
		var mhx: MeoHangXom = main.find_child("MeoHangXom", true, false)
		var m: MeoNpc = mhx.cats.values()[0]
		var p: CharacterBody3D = main.player
		if main.get("hud"):
			main.hud.visible = false
		m.set_pose("dung")
		var f := Vector3(sin(m.rotation.y), 0.0, cos(m.rotation.y))   # trước mặt mèo (mèo nhìn về -Z khi yaw 0)
		p.global_position = m.global_position - f * 1.2 + Vector3(0, 0.05, 0)
		await _wait(20)
		mhx.greeted[m.cast_id] = c[1]
		var mid: Vector3 = (m.global_position + p.global_position) * 0.5
		var side := Vector3(-f.z, 0.0, f.x)
		var cam := Camera3D.new()
		main.add_child(cam)
		cam.fov = 50.0
		# bên nào không vướng tường thì đặt máy bên đó
		var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
		var eye := mid + Vector3(0, 0.45, 0)
		var best := side * 1.5
		for d in [side, -side, (side + f).normalized(), (-side + f).normalized(), (side - f).normalized(), (-side - f).normalized()]:
			var q := PhysicsRayQueryParameters3D.create(eye, eye + d * 1.6)
			q.exclude = [p.get_rid()]
			if space.intersect_ray(q).is_empty():
				best = d * 1.5
				break
		cam.global_position = eye + best + Vector3(0, 0.15, 0)
		cam.look_at(mid + Vector3(0, 0.25, 0))
		cam.current = true
		mhx._greet(m)
		var t := 0.0
		for i in c[2].size():
			var at: float = c[2][i]
			await _wait(int((at - t) * 30.0))
			t = at
			var name := "%s_%d_%d" % [c[0], c[1], i]
			root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
			var dd := (m.global_position - p.global_position)
			dd.y = 0.0
			dd = dd.normalized()
			print("  Bơ đầu ra trước ", snappedf((_head(p) - p.global_position).dot(dd), 0.001), " mèo ", snappedf((_head(m) - m.global_position).dot(-dd), 0.001), " cao ", snappedf(_head(p).y - p.global_position.y, 0.001), " ", snappedf(_head(m).y - m.global_position.y, 0.001), " clip t ", snappedf(p.get("_clip_t"), 0.01), " lệch ngang ", snappedf((_head(m) - _head(p)).dot(Vector3(-dd.z, 0, dd.x)), 0.001), " Bơ cao hơn mèo ", snappedf(p.global_position.y - m.global_position.y, 0.001))
			print("đã chụp ", name, " Bơ: ", p.clip, " mèo: ", m.get("_clip"), " hai đầu cách ", snappedf(_head(p).distance_to(_head(m)), 0.01), " cách ", snappedf(Vector2(m.global_position.x - p.global_position.x, m.global_position.z - p.global_position.z).length(), 0.01))
	print("CHUP CHAO MEO XONG")
	quit()


## Vị trí xương đầu (tâm xoay đầu) của Bơ hay mèo
func _head(n: Node) -> Vector3:
	for sk in n.find_children("*", "Skeleton3D", true, false):
		var i: int = sk.find_bone("head")
		if i >= 0:
			return sk.global_transform * sk.get_bone_global_pose(i).origin
	return n.global_position
