extends SceneTree
## Chụp bộ ráp nhà P2 trong game: dãy phố, bảng hiệu, đồ gắn tường, nhà mốc, vành phố (ánh sáng như màn phố).
## Chạy (cần màn hình, máy đám mây dùng xvfb-run):
##   godot --path . --rendering-driver opengl3 -s tools/chup_nha_rap.gd -- <thư_mục_ra> [buổi, mặc định pho_sang]

var out := "user://chup_nha_rap"
var buoi := "pho_sang"

## tên ảnh, vị trí camera, điểm nhìn, góc nhìn
const SHOTS := [
	["1_duong_lon_khoi_2", Vector3(-12.0, 1.8, 2.0), Vector3(0.0, 4.0, -7.0), 62.0],
	["2_duong_lon_khoi_5", Vector3(10.0, 1.8, -1.5), Vector3(-2.0, 4.0, 7.0), 62.0],
	["3_bang_hieu_can_canh", Vector3(-4.0, 2.2, -1.5), Vector3(-6.0, 3.6, -7.0), 55.0],
	["4_nha_dang_xay", Vector3(-4.0, 3.0, 29.5), Vector3(-9.0, 4.0, 23.0), 62.0],
	["5_mieu_dau_hem_42", Vector3(-12.0, 1.5, 3.2), Vector3(-15.35, 0.9, 7.6), 60.0],
	["6_chung_cu_ngoc_lan", Vector3(18.0, 3.0, -14.0), Vector3(32.0, 8.0, -36.0), 70.0],
	["7_biet_thu_mau_giao", Vector3(26.0, 2.0, 27.5), Vector3(34.0, 4.0, 37.0), 70.0],
	["8_vanh_tay_bac", Vector3(-40.0, 2.0, -24.0), Vector3(-30.0, 6.0, -45.0), 65.0],
	["9_tren_cao", Vector3(0.0, 45.0, 55.0), Vector3(0.0, 0.0, 0.0), 55.0],
	["10_hem_khoi_2", Vector3(-12.5, 1.6, -15.5), Vector3(0.0, 2.5, -15.5), 60.0],
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
	print("nha rap: %d căn, miếu %s, bỏ: %s" % [NhaRap.houses.size(), NhaRap.mieu_at, ChiTietPho.skipped.filter(func(t): return t.begins_with("mieu"))])
	quit()
