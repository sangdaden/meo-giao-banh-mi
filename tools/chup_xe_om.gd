extends SceneTree
## Chụp xe ôm Chú Năm chở Chị Thảo (khối xe như deliveries.gd _build_xe_om) để soát chỗ ngồi.
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 -s tools/chup_xe_om.gd -- <thư_mục_ra>

const SEAT := 0.78  # = Deliveries.XE_OM_SEAT


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args()[0])


func _run(out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var r := Node3D.new()
	root.add_child(r)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#9CCBC1")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#C9D6D0")
	env.environment.ambient_light_energy = 0.45
	r.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	r.add_child(sun)
	Blocks.box(r, Vector3(10, 0.1, 10), Vector3(0, -0.05, 0), Color("#8CBFB4"))
	var y := SEAT
	var red := Color("#2F5E9E")
	Blocks.box(r, Vector3(0.36, y - 0.36, 1.2), Vector3(0, (y + 0.36) / 2.0, 0.05), red)
	Blocks.box(r, Vector3(0.34, 0.08, 0.95), Vector3(0, y - 0.04, 0.2), Color("#2B2622"))
	Blocks.box(r, Vector3(0.3, 0.5, 0.2), Vector3(0, y + 0.05, -0.62), red)
	Blocks.box(r, Vector3(0.7, 0.04, 0.04), Vector3(0, y + 0.32, -0.66), Color("#5E6F6C"))
	for wz in [-0.6, 0.62]:
		Blocks.box(r, Vector3(0.1, 0.46, 0.46), Vector3(0, 0.23, wz), Color("#2B2622"))
	var nam := Nguoi.make("chunam", "cho_di")
	nam.position = Vector3(0, 0, -0.18)
	nam.rotation.y = PI / 2
	r.add_child(nam)
	var thao := Nguoi.make("khachxeom", "ngoi_sau")
	thao.position = Vector3(0, y + 0.09 - 0.95, 0.38)
	thao.rotation.y = PI
	r.add_child(thao)
	var cam := Camera3D.new()
	r.add_child(cam)
	cam.fov = 35
	cam.current = true
	root.get_viewport().size = Vector2i(640, 560)
	for k in 5:
		await process_frame
	var shots := {"ben_trai": Vector3(-3.6, 1.4, 0.3), "phia_truoc": Vector3(-2.0, 1.6, -3.0), "phia_sau": Vector3(1.6, 1.8, 3.2)}
	for anim_set in [["cho_di", "ngoi_sau"], ["cho_khach", "nhan_banh"], ["cho_khach", "xuong_xe"]]:
		nam.play(anim_set[0], 0.0)
		thao.anim.play(anim_set[1], 0.0)
		thao.anim.seek(thao.anim.current_animation_length * 0.6, true)
		thao.anim.pause()
		for nm in shots:
			cam.position = shots[nm]
			cam.look_at(Vector3(0, 0.9, 0.1))
			for k in 4:
				await process_frame
			root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [anim_set[1], nm]))
	quit()
