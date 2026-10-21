extends SceneTree
## Chụp ảnh model chân trước Bơ (scripts/bo_paw.gd) từ nhiều góc để làm bản phác duyệt.
## Chạy: godot --path . --rendering-driver opengl3 -s tools/paw_preview.gd -- <thư mục ra> [bep|dung]

var views := {
	"tren": [Vector3(0, 0.35, 0.25), Vector3(0, 0.0, 0.02)],
	"truoc": [Vector3(0, 0.08, -0.4), Vector3(0, 0.0, 0.05)],
	"ngang": [Vector3(0.45, 0.05, 0.08), Vector3(0, -0.03, 0.08)],
	"duoi": [Vector3(0.0, -0.3, -0.12), Vector3(0, 0.0, 0.0)],
	"canh": [Vector3(0.0, 0.62, 0.95), Vector3(0, 0.0, -0.1)],
	"xien": [Vector3(0.55, 0.32, 0.5), Vector3(-0.02, 0.0, -0.02)],
	"xien2": [Vector3(0.3, 0.3, 0.6), Vector3(0.0, 0.0, -0.02)],
}


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var root3 := Node3D.new()
	root.add_child(root3)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#7FB7A4")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#FFE6C4")
	env.environment.ambient_light_energy = 0.35
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.9
	root3.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(30, 200, 0)
	fill.light_energy = 0.3
	root3.add_child(fill)
	var pose: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "bep"
	for s in [-1.0, 1.0]:
		var p := BoPaw.create(s, 1.0, pose)
		p.position = Vector3(s * 0.1, 0, 0)
		root3.add_child(p)
	if pose == "dung":
		views = {
			"dung_ngang": [Vector3(0.7, 0.2, 0.0), Vector3(0, 0.13, 0)],
			"dung_truoc": [Vector3(0.1, 0.25, -0.7), Vector3(0, 0.13, 0)],
			"dung_fp": [Vector3(0.0, 0.44, 0.1), Vector3(0, 0.0, -0.35)],
		}
	var cam := Camera3D.new()
	cam.fov = 40
	cam.near = 0.01
	root3.add_child(cam)
	cam.make_current()
	for i in 3:
		await process_frame
	for key in views:
		var v: Array = views[key]
		cam.global_transform = Transform3D(Basis.looking_at(v[1] - v[0]), v[0])
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("paw_%s.png" % key))
	quit()
