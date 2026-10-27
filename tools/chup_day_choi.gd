extends SceneTree
## Chụp màn dạy chơi (sân sau lò bánh) ở các chỗ hay lỗi hình: Bơ trên mái kho, chui gầm ba gác,
## rón rén, đứng dưới cửa sổ bếp (trạm 5). Ảnh ra: <thư_mục>/<tên>.png
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/chup_day_choi.gd -- <thư_mục_ra>

const SHOTS := [
	# tên, trạm, chỗ đứng của Bơ, hướng camera (yaw), dáng
	["mai_kho", 3, Vector3(13.0, 2.3, 2.2), PI * 0.5, "walk"],
	["mai_kho_ngang", 3, Vector3(12.6, 2.3, 2.8), PI, "walk"],
	["chui", 3, Vector3(11.5, 0.05, 6.0), PI * 0.5, "crouch"],
	["ron_ren", 4, Vector3(8.0, 0.05, 8.3), PI * 0.5, "sneak"],
	["cua_so", 5, Vector3(4.6, 0.05, 1.6), 0.25, "walk"],
]


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var scene: Node3D = load("res://scenes/day_choi.tscn").instantiate()
	root.add_child(scene)
	for i in 20:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for shot in SHOTS:
		if scene.station != shot[1]:
			scene._begin(shot[1])
		var crouch: bool = shot[4] == "crouch"
		var sneak: bool = shot[4] == "sneak"
		if crouch:
			Input.action_press("crouch")
		if sneak:
			Input.action_press("sneak")
		scene._put(shot[2])
		scene.rig.yaw = shot[3]
		for i in 90:
			await physics_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("%s.png" % shot[0]))
		print("%s: Bơ y=%.3f dáng=%s" % [shot[0], scene.player.global_position.y, scene.player.stance])
		Input.action_release("crouch")
		Input.action_release("sneak")
	print("đã chụp ", out)
	quit()
