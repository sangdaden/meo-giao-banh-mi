extends SceneTree
## Chụp khu phố bản khối từ vài góc (toàn cảnh, hẻm 42, quán cà phê, tiệm xe, chung cư) để soát bản đồ.
## Chạy (cần màn hình, trên máy đám mây dùng xvfb-run):
##   godot --path . --rendering-driver opengl3 -s tools/chup_ban_do.gd -- <thư_mục_ra>

var out := "user://chup_ban_do"

## tên ảnh, vị trí camera, điểm nhìn, góc nhìn (0 = nhìn thẳng từ trên xuống bằng camera trực giao)
const SHOTS := [
	["ban_do_toan_canh", Vector3(0, 80, 0.01), Vector3.ZERO, 0.0],
	["hem_42", Vector3(-18.5, 6.5, 5.0), Vector3(-18.5, 0, 17.0), 60.0],
	["hem_42_tren_cao", Vector3(-12.0, 16.0, 16.0), Vector3(-18.5, 0, 16.5), 55.0],
	["ca_phe_may", Vector3(-1.0, 3.2, 0.5), Vector3(0.5, 0.5, 6.2), 60.0],
	["hem_khoi_6_cua_sau_tiem_xe", Vector3(22.5, 2.2, 15.5), Vector3(32.0, 0.8, 16.0), 60.0],
	["tiem_xe_mat_tien", Vector3(32.2, 2.4, 29.0), Vector3(32.2, 1.0, 19.0), 60.0],
	["chung_cu_ban_cong_be_na", Vector3(31.0, 4.0, -14.8), Vector3(24.5, 3.0, -16.0), 65.0],
	["mai_hien_khoi_2", Vector3(-14.0, 4.5, -2.0), Vector3(-4.0, 2.9, -6.5), 60.0],
	["lo_banh_co_ba", Vector3(-33.0, 1.6, 1.5), Vector3(-33.0, 3.0, -7.0), 65.0],
	["duong_lon_nhin_dong", Vector3(-40.0, 1.2, 0.0), Vector3(0.0, 3.0, 0.0), 60.0],
	["nha_ba_sau_cuoi_hem", Vector3(-18.5, 1.0, 16.0), Vector3(-18.5, 2.5, 26.0), 65.0],
	["tren_cao_khoi_5", Vector3(0.0, 22.0, -8.0), Vector3(0.0, 0.0, 12.0), 60.0],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	City.build(world)
	Blocks.merge_static(world, 24.0)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#BFE3F0")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	for s in SHOTS:
		if s[3] == 0.0:
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 64.0
		else:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = s[3]
		cam.position = s[1]
		cam.look_at(s[2], Vector3.UP if s[3] != 0.0 else Vector3.FORWARD)
		for i in 8:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(s[0] + ".png"))
		print("đã chụp ", s[0])
	quit()
