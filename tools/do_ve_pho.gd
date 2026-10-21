extends SceneTree
## Đếm lệnh vẽ và tam giác của màn giao bánh ở vài góc nhìn (bản Compatibility như web).
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 -s tools/do_ve_pho.gd [-- <thư_mục_lưu_ảnh>]

const VIEWS := [
	["lo_banh", Vector3(-33, 2.0, -1.0), Vector3(-33, 2.0, -7.0)],
	["duong_lon", Vector3(-40, 2.0, 0.0), Vector3(0, 2.0, 0.0)],
	["nga_tu", Vector3(-10, 3.0, 8.0), Vector3(20, 0.0, -10.0)],
	["hem_42", Vector3(-18.5, 2.0, 8.0), Vector3(-18.5, 1.0, 20.0)],
	["tren_cao", Vector3(0, 40, 30), Vector3(0, 0, 0)],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.far = 400.0
	cam.current = true
	for v in VIEWS:
		cam.global_position = v[1]
		cam.look_at(v[2])
		for i in 6:
			await process_frame
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var obj := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		var tri := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		if OS.get_cmdline_user_args().size() > 0:
			root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(v[0] + ".png"))
		print("[do_ve] %s: %d lệnh vẽ, %d vật, %d tam giác" % [v[0], dc, obj, tri])
	quit()
