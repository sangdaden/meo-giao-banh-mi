extends SceneTree
## Chụp góc cờ tướng (khối tạm) ở 4 trạng thái: đánh cờ, suỵt, mắng, chiếu tướng.
## Chạy (cần màn hình, trên máy đám mây dùng xvfb-run):
##   godot --path . --rendering-driver opengl3 -s tools/chup_goc_co.gd -- <thư_mục_ra>

var out := "user://chup_goc_co"
var C := CityProps.CHESS_CORNER


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
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#BFD3DA")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#BFD3DA")
	env.environment.ambient_light_energy = 0.5
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("#FFE8C4")
	sun.shadow_enabled = true
	world.add_child(sun)
	City.build(world)
	ChessCorner.build_static(world)
	var chess := ChessCorner.new()
	world.add_child(chess)
	var bo: CharacterBody3D = preload("res://scripts/player.gd").new()
	bo.preview = true  # đứng yên làm thước đo, không cần phím điều khiển
	bo.position = ChessCorner.DROP + Vector3(0.6, 0.0, -1.2)
	bo.rotation.y = PI * 0.8
	world.add_child(bo)
	chess.setup(bo)
	chess.begin_order()
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 50
	cam.global_position = C + Vector3(3.2, 2.6, -4.2)
	cam.look_at(C + Vector3(0, 0.6, 0))
	cam.current = true
	await _wait(60)
	_shot("1_danh_co")
	bo.noise_made.emit(C + Vector3(0.4, 0, -2.2), 6.0)
	await _secs(0.5)
	_shot("2_suyt")
	await _secs(2.5)
	bo.noise_made.emit(C + Vector3(0.2, 0, -0.4), 8.0)
	await _secs(0.6)
	_shot("3_mang")
	await _secs(3.5)
	chess.checkmate_now()
	await _secs(0.6)
	_shot("4_chieu_tuong")
	quit()


func _secs(t: float) -> void:
	await create_timer(t).timeout
	await _wait(2)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("đã chụp ", name)
