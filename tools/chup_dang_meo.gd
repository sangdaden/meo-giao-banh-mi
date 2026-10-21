extends SceneTree
## Chụp Bơ (hoặc một giống mèo) ở 6 dáng chạy + 2 động tác chờ, góc ngang và góc trên, để duyệt model
## (quy trình duyệt model mèo, bước 4). Ảnh ra: <thư_mục>/<dáng>_<ngang|tren>.png
##   godot --path . -s tools/chup_dang_meo.gd -- <thư_mục_ra> [giống]
## Thêm --rendering-driver opengl3 để xem bản web (Compatibility).

const POSES := [
	# tên, tốc độ ngang (m/s), vận tốc dọc, chạm đất, tốc độ quẹo
	["dung_yen", 0.0, 0.0, true, 0.0],
	["di", 1.6, 0.0, true, 0.0],
	["chay_nhanh", 5.5, 0.0, true, 0.0],
	["nhay_len", 3.0, 3.5, false, 0.0],
	["roi_xuong", 3.0, -4.0, false, 0.0],
	["que", 4.0, 0.0, true, 3.0],
]


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var p := BoPreview.new()
	p.show_hint = false
	p.size = Vector2(640, 520)
	root.add_child(p)
	await process_frame
	var c = p.cat
	if args.size() > 1:
		c.set_breed(args[1])
	c.set_process(false)
	p.set_process(false)
	for pose in POSES + [["ngoi", 0.0, 0.0, true, 0.0], ["liem_chan", 0.0, 0.0, true, 0.0]]:
		c.preview = pose[0] in ["ngoi", "liem_chan"]
		if c.preview:
			c.play_idle_action("sit" if pose[0] == "ngoi" else "lick", 99.0)
		for i in 150:
			c._yaw_rate = pose[4]
			c._animate(1.0 / 60.0, pose[1], pose[2], pose[3])
		# Đi, chạy: chụp lúc chân vung xa nhất
		while pose[3] and pose[1] > 0.0 and absf(sin(c._phase)) < 0.9:
			c._animate(1.0 / 60.0, pose[1], pose[2], pose[3])
		for view in [["ngang", PI * 0.5, 0.06, 2.0], ["tren", PI + 0.7, 0.5, 2.2]]:
			c.visual.rotation.y = view[1]
			var dir := Vector3(0, sin(view[2]), cos(view[2]))
			p.cam.position = p.target + dir * view[3]
			p.cam.look_at(p.target)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			p.vp.get_texture().get_image().save_png(out.path_join("%s_%s.png" % [pose[0], view[0]]))
		c.preview = false
		c.play_idle_action("", 99.0)
		c._sit_w.x = 0.0
		c._lick_w.x = 0.0
		c._idle_action(0.0, 0.0)
	print("đã chụp ", out)
	quit()
