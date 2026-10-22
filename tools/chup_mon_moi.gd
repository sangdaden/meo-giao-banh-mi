extends SceneTree
## Soát 7 món bán theo gói (giỏ mây, cà mèn, giỏ đan, bao lì xì, cành mai, khăn len, khăn huy hiệu)
## (hoặc các món truyền vào) trên vài giống đực/cái: góc 3/4 trước và 3/4 sau; giỏ chụp thêm lúc mang bánh,
## đồ cổ và đuôi chụp thêm lúc chạy nhanh.
## Ảnh ra: <thư_mục>/<giống>_<giới>__<món>_<góc>.png
##   godot --path . -s tools/chup_mon_moi.gd -- <thư_mục_ra> [giống_giới,..] [món,..]

const ITEMS := ["giomay", "camen", "giodan", "baolixi", "canhmai", "khanlen", "huyhieu"]


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
	var cats: Array = ["bo_duc", "bo_cai", "vobanh_duc", "lantet_duc"]
	if args.size() > 1:
		cats = Array(args[1].split(","))
	var items: Array = ITEMS
	if args.size() > 2:
		items = Array(args[2].split(","))
	DirAccess.make_dir_recursive_absolute(out)
	var p := BoPreview.new()
	p.show_hint = false
	p.size = Vector2(400, 400)
	root.add_child(p)
	await process_frame
	var c = p.cat
	c.set_process(false)
	p.set_process(false)
	c.preview = false
	for cat in cats:
		var b: String = cat.get_slice("_", 0)
		var sex: String = cat.get_slice("_", 1)
		for id in items:
			var a := Outfit.acc(id)
			var worn := {a[3]: id}
			if a[3] != "neck":
				worn["neck"] = "khando"
			c.set_breed(b, worn, sex)
			var poses := [["dung", 0.0, false]]
			if id in ["giomay", "giodan"]:
				poses.append(["mangbanh", 0.0, true])
			if a[3] in ["neck", "tail", "feet"]:
				poses.append(["chay", 8.0, false])  # vải bay, đồ treo lắc, cổ tất theo cẳng chân, bánh patin lăn
			for pose in poses:
				c.carrying = pose[2]
				for i in 90:
					c._animate(1.0 / 60.0, pose[1], 0.0, true)
				var views := [["truoc", PI - 0.7], ["sau", 0.9]]
				if a[3] == "face":
					views = [["thang", PI], ["truoc", PI - 0.7]]   # đồ mặt: nhìn thẳng mặt và 3/4
				for view in views:
					c.visual.rotation.y = view[1]
					var t := Vector3(0, 0.3, 0.02)
					var dist := 1.25
					if a[3] == "feet":
						t = Vector3(0, 0.07, 0.02); dist = 0.75   # đồ chân: chụp gần bàn chân
					elif a[3] == "face":
						t = Vector3(0, 0.4, 0.1); dist = 0.9
					p.cam.position = t + Vector3(0, 0.3, 1.0).normalized() * dist
					p.cam.look_at(t)
					await _snap(p, out, "%s__%s_%s_%s.png" % [cat, id, pose[0], view[0]])
	print("đã chụp ", out)
	quit()
