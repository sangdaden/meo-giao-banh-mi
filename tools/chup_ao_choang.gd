extends SceneTree
## Chụp áo choàng siêu nhân (đồ vải bay, shaders/vai_bay.gdshader) trên Bơ khi đứng, đi, chạy, nhảy, rơi, quẹo,
## và một chuỗi khung hình lúc đi rồi chạy để ghép GIF. Ảnh ra: <thư_mục>/<dáng>_<ngang|tren>.png, <thư_mục>/gif/####.png
##   godot --path . -s tools/chup_ao_choang.gd -- <thư_mục_ra> [id_phụ_kiện=aochoang]
## Thêm --rendering-driver opengl3 để xem bản web (Compatibility).

const POSES := [
	# tên, tốc độ ngang (m/s), vận tốc dọc, chạm đất, tốc độ quẹo
	["dung_yen", 0.0, 0.0, true, 0.0],
	["di", 5.0, 0.0, true, 0.0],
	["chay_nhanh", 8.0, 0.0, true, 0.0],
	["nhay_len", 5.0, 6.0, false, 0.0],
	["roi_xuong", 5.0, -6.0, false, 0.0],
	["que", 6.0, 0.0, true, 3.0],
]


func _initialize() -> void:
	_go.call_deferred()


func _snap(p, out: String, name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	p.vp.get_texture().get_image().save_png(out.path_join(name))


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var id: String = args[1] if args.size() > 1 else "aochoang"
	DirAccess.make_dir_recursive_absolute(out.path_join("gif"))
	var p := BoPreview.new()
	p.show_hint = false
	p.size = Vector2(640, 520)
	root.add_child(p)
	await process_frame
	var c = p.cat
	c.apply_outfit({"back": id, "neck": "khando"})
	c.set_process(false)
	p.set_process(false)
	c.preview = false
	c.stance = "walk"
	for pose in POSES:
		for i in 120:
			c._yaw_rate = pose[4]
			c._animate(1.0 / 60.0, pose[1], pose[2], pose[3])
		for view in [["ngang", PI * 0.5, 0.06, 2.0], ["tren", PI + 0.7, 0.5, 2.2]]:
			c.visual.rotation.y = view[1]
			p.cam.position = p.target + Vector3(0, sin(view[2]), cos(view[2])) * view[3]
			p.cam.look_at(p.target)
			await _snap(p, out, "%s_%s.png" % [pose[0], view[0]])
	# Chuỗi GIF: đứng 1 s, đi 1,5 s, chạy nhanh 2 s, nhảy 1 s; góc chéo sau lưng
	c.visual.rotation.y = PI + 0.9
	p.cam.position = p.target + Vector3(0, sin(0.25), cos(0.25)) * 2.0
	p.cam.look_at(p.target)
	var seq := []
	for i in 20: seq.append([0.0, 0.0, true])
	for i in 30: seq.append([5.0, 0.0, true])
	for i in 40: seq.append([8.0, 0.0, true])
	for i in 20:
		var vy := 6.0 - i * 0.6
		seq.append([6.0, vy, i == 19])
	var n := 0
	for s in seq:
		for k in 3:
			c._yaw_rate = 0.0
			c._animate(1.0 / 60.0, s[0], s[1], s[2])
		await _snap(p, out, "gif/%04d.png" % n)
		n += 1
	print("đã chụp ", out)
	quit()
