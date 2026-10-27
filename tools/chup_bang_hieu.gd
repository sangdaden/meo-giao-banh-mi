extends SceneTree
## Chụp bảng hiệu vòng 3 trong game: 4 quán trong truyện (lò bánh, cà phê Mây, tiệm xe, tạp hóa) và dọc đường lớn.
## Chạy (cần màn hình, máy đám mây dùng xvfb-run):
##   godot --path . --rendering-driver opengl3 -s tools/chup_bang_hieu.gd -- <thư_mục_ra> [buổi, mặc định pho_sang]

var out := "user://chup_bang_hieu"
var buoi := "pho_sang"

## tên ảnh, vị trí camera, điểm nhìn, góc nhìn
const SHOTS := [
	["lo_banh", Vector3(-33.0, 1.8, 1.0), Vector3(-33.0, 4.0, -7.0), 62.0],
	["cafe_may", Vector3(7.0, 1.8, -1.0), Vector3(7.0, 4.0, 7.0), 62.0],
	["tiem_xe", Vector3(32.0, 1.8, 32.0), Vector3(32.0, 4.0, 24.0), 62.0],
	["tap_hoa", Vector3(7.8, 1.8, -31.0), Vector3(7.8, 4.0, -24.0), 62.0],
	["duong_lon_khoi_2", Vector3(-12.0, 1.8, 2.0), Vector3(0.0, 4.0, -7.0), 62.0],
	["duong_lon_khoi_5", Vector3(10.0, 1.8, -1.5), Vector3(-2.0, 4.0, 7.0), 62.0],
	["xa_khoi_2", Vector3(-40.0, 1.8, 1.0), Vector3(0.0, 4.0, -3.0), 60.0],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		buoi = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	City.build(world)
	Blocks.merge_static(world, 24.0)
	AnhSang.build(world, buoi)
	VanhPho.set_sky(self, VanhPho.SKY_FOR.get(buoi, "sang"))
	var cam := Camera3D.new()
	cam.far = 400.0
	world.add_child(cam)
	cam.current = true
	for s in SHOTS:
		cam.fov = s[3]
		cam.position = s[1]
		cam.look_at(s[2], Vector3.UP)
		for i in 8:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(s[0] + ".png"))
		print("đã chụp ", s[0])
	print("CHUP BANG HIEU OK")
	quit()
