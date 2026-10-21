extends SceneTree
## Chụp người dân trong Godot (đúng model và animation game dùng) để soát rig, tư thế.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 -s tools/chup_nguoi.gd -- <thư_mục_ra> [id,id:nhe,id:dong...] [anim,anim...]
## Mỗi animation một ảnh, mỗi ảnh xếp các người cạnh nhau, chụp ở 3 thời điểm (20%, 50%, 80%).

var out := "user://chup_nguoi"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred(args)


func _wait(frames := 5) -> void:
	for i in frames:
		await process_frame


func _run(args: Array) -> void:
	var ids: Array = Array(args[1].split(",")) if args.size() > 1 and args[1] != "all" else Nguoi.IDS
	var root3d := Node3D.new()
	root.add_child(root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#9CCBC1")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#C9D6D0")
	env.environment.ambient_light_energy = 0.45
	root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	sun.light_energy = 0.8
	root3d.add_child(sun)
	Blocks.solid_box(root3d, Vector3(40, 0.1, 10), Vector3(0, -0.05, 0), Color("#8CBFB4"))
	var people: Array[Nguoi] = []
	for i in ids.size():
		var p := Nguoi.make(ids[i].get_slice(":", 0), "dung_yen")  # "id:nhe" chụp bản nhẹ
		p.ban = ids[i].get_slice(":", 1) if ":" in ids[i] else ""
		p.position = Vector3((i - (ids.size() - 1) / 2.0) * 1.0, 0, 0)
		root3d.add_child(p)
		if Nguoi.SEAT.has(p.id):
			Blocks.box(root3d, Vector3(0.36, Nguoi.SEAT[p.id], 0.36), p.position + Vector3(0, Nguoi.SEAT[p.id] / 2.0, -0.1), Color("#C8412F"))
		people.append(p)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	var w := ids.size() * 1.0
	cam.fov = 35
	cam.position = Vector3(-0.6, 1.5, maxf(3.4, w * 1.15))
	cam.look_at(Vector3(0, 0.75, 0))
	cam.current = true
	root.get_viewport().size = Vector2i(maxi(420, ids.size() * 260), 560)
	await _wait(5)
	var anims: Array = Array(args[2].split(",")) if args.size() > 2 else people[0].anim.get_animation_list()
	for a in anims:
		for frac in [0.2, 0.5, 0.8]:
			for p in people:
				if not p.anim.has_animation(a):
					continue
				p.anim.play(a, 0.0)
				p.anim.seek(p.anim.current_animation_length * frac, true)
				p.anim.pause()
			await _wait(4)
			var img := root.get_viewport().get_texture().get_image()
			img.save_png(out.path_join("%s_%02d.png" % [a, int(frac * 100)]))
	print("xong ", anims)
	quit()
