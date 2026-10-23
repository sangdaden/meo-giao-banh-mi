extends SceneTree
## Chụp màu chiều tà/hoàng hôn quanh Bơ ra PNG để so trước/sau (luồng D1 "Màu chiều tà").
## Chạy: xvfb-run godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/chup_chieu_ta.gd \
##   -- <thư_mục_ra> --ngay=thu_sau [--buoi=pho_hoang_hon]
## Ảnh: 1 ngược nắng (Bơ trước nắng tây), 2 xuôi nắng, 3 cận Bơ, 4 nhìn lên trời phía ánh trời phụ
## (nơi từng có vệt đen), 5 nhìn lên trời phía mặt trời.

var out := "user://chup_chieu_ta"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	PlayMode.day = "thu_sau"
	for a in args:
		if a.begins_with("--ngay="):
			PlayMode.day = a.substr(7)
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


func _shot(cam: Camera3D, from: Vector3, at: Vector3, file: String, frames := 40) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.current = true
	await _wait(frames)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(file))
	print("đã chụp ", file)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(40)
	var main: Node = current_scene
	for ui in main.find_children("*", "CanvasLayer", true, false):
		ui.visible = false  # chỉ soát màu, ẩn HUD và thẻ việc
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 62
	var p: CharacterBody3D = main.player
	p.can_move = false
	var bo := Vector3(-4.0, 0.1, 3.5)  # vỉa hè trước dãy nhà phía nam đường lớn, trống hai phía
	p.global_position = bo
	await _wait(20)
	var tb := main.get_node_or_null("ThuBay")
	if tb:  # Thứ Bảy: đẩy trời thẳng tới hoàng hôn (nấc cuối) như khi đã giúp đủ việc
		tb._sky_goal = 1.0
		tb._sky_t = 1.0
		tb._apply_sky(1.0)
		await _wait(5)
	var sun: DirectionalLight3D = main.get_node("MatTroi")
	var fill: DirectionalLight3D = main.get_node_or_null("AnhTroi")
	# Hướng về phía mặt trời (ngược đường ánh sáng đi), chỉ lấy phần nằm ngang
	var to_sun := sun.global_transform.basis.z
	var flat := Vector3(to_sun.x, 0, to_sun.z).normalized()
	var c := bo + Vector3(0, 0.35, 0)
	await _shot(cam, c - flat * 3.2 + Vector3(0, 1.0, 0), c + flat * 4.0 + Vector3(0, 0.6, 0), "1_nguoc_nang.png")
	await _shot(cam, c + flat * 3.2 + Vector3(0, 1.0, 0), c - flat * 4.0 + Vector3(0, 0.6, 0), "2_xuoi_nang.png")
	var side := flat.cross(Vector3.UP)
	await _shot(cam, c - side * 1.3 - flat * 0.5 + Vector3(0, 0.3, 0), c, "3_can_bo.png")
	var mid := Vector3(c.x, 1.2, 0.0)  # giữa đường lớn cho trời thoáng
	if fill:
		var up := fill.global_transform.basis.z
		await _shot(cam, mid, mid + up * 10.0, "4_troi_anh_phu.png")
	await _shot(cam, mid, mid + to_sun * 10.0 + Vector3(0, 1.2, 0), "5_troi_mat_troi.png")
	quit()
