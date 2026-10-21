extends SceneTree
## Đo hiệu năng và chụp ảnh ánh sáng màn giao bánh (phố) và màn bếp từ các góc cố định.
## Mỗi góc ghi: tổng lệnh vẽ (draw call) và tam giác của cả khung, số vật thể ở lượt vẽ chính,
## phần của lượt bóng đổ (Forward+; Compatibility của Godot 4.3 không báo phần này), thời gian khung hình. Vượt ngân sách (docs/ngan-sach-hieu-nang.md) thì thoát mã 1.
##
## Chạy giống bản web (renderer Compatibility, OpenGL), máy đám mây không có màn hình dùng xvfb-run:
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
##     -s tools/do_hieu_nang.gd -- [--chup=<thư_mục_ảnh>] [--canh=pho|bep|menu] [--can-canh]
## Chạy giống bản PC (Forward+, cần Vulkan; máy đám mây cài mesa-vulkan-drivers):
##   xvfb-run -a godot --path . -s tools/do_hieu_nang.gd -- --chup=<thư_mục_ảnh>
##
## Số lệnh vẽ và tam giác không phụ thuộc máy nên kiểm được trong CI. FPS trong CI chạy bằng CPU
## (llvmpipe) nên chỉ in ra để tham khảo, không dùng để chấm đậu/rớt.

## Ngân sách mỗi khung hình ở bản web (Compatibility), chỉ chấm khi chạy renderer này.
## Giữ khớp với docs/ngan-sach-hieu-nang.md. Góc tên bắt đầu "tham_khao" chỉ in số, không chấm.
const BUDGET := {
	"draw_calls": 350,      # tổng mọi lượt vẽ trong khung (chính + bóng + giao diện)
	"objects": 450,         # vật thể 3D nhìn thấy ở lượt vẽ chính
	"triangles": 400000,    # tổng tam giác mọi lượt vẽ
}

## tên, vị trí camera, điểm nhìn. Đặt ở tầm camera sau lưng mèo (cao ~1,6 m, lùi ~3 m) cho giống lúc chơi.
const SHOTS_PHO := [
	["pho_bo_can_canh", Vector3(-32.0, 0.75, -1.9), Vector3(-33, 0.3, -3.3)],
	["pho_lo_banh", Vector3(-33, 1.7, -1.0), Vector3(-33, 0.9, -6.5)],
	["pho_nga_tu", Vector3(-24, 1.8, 2.5), Vector3(-10, 0.8, -1.0)],
	["pho_duong_ngang", Vector3(-6, 1.7, 1.5), Vector3(14, 1.0, 0.0)],
	["pho_hem_42", Vector3(-18.5, 1.6, 7.0), Vector3(-18.5, 0.6, 17.0)],
	["pho_ca_phe", Vector3(-1.0, 1.7, 1.0), Vector3(5.4, 0.6, 5.4)],
	["pho_chung_cu", Vector3(18.0, 1.8, -4.0), Vector3(24.0, 2.0, -15.6)],
	["pho_sua_xe", Vector3(30.6, 1.7, 30.0), Vector3(30.6, 0.8, 24.0)],
	["tham_khao_tren_cao", Vector3(-40, 22, 30), Vector3(-5, 0, -2)],
]
const SHOTS_BEP := [
	["bep_toan_canh", Vector3(0, 2.6, 4.3), Vector3(0, 0.0, -0.3)],
	["bep_lo", Vector3(0.5, 0.8, 0.3), Vector3(0.3, 0.3, -1.0)],
]
## Màn hình chính (có Bơ 3D, tủ đồ): dùng camera của chính màn đó.
const SHOTS_MENU := [
	["menu_chinh", null, null],
]
const SETTLE_FRAMES := 12
const MEASURE_FRAMES := 30

var out := ""
var which := "ca_hai"
var failed := false
var rows: Array = []
var compat := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chup="):
			out = a.substr(7)
		elif a.begins_with("--canh="):
			which = a.substr(7)
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	Engine.max_fps = 0
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	if DisplayServer.get_name() == "headless":
		print("[hieu nang] renderer giả (--headless) không vẽ gì, bỏ qua. Chạy bằng xvfb-run, không dùng --headless.")
		quit(0)
		return
	var method := "Forward+" if RenderingServer.get_rendering_device() else "Compatibility"
	print("[hieu nang] renderer: %s, GPU: %s" % [method, RenderingServer.get_video_adapter_name()])
	compat = method == "Compatibility"
	if which in ["ca_hai", "pho"]:
		await _scene("res://scenes/main.tscn", SHOTS_PHO)
	if which in ["ca_hai", "bep"]:
		await _scene("res://scenes/kitchen.tscn", SHOTS_BEP)
	if which in ["ca_hai", "menu"]:
		await _scene("res://scenes/menu.tscn", SHOTS_MENU)
	_report()
	quit(1 if failed else 0)


func _scene(path: String, shots: Array) -> void:
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 10:
		await process_frame
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Tắt giao diện để ảnh chỉ có cảnh 3D; HUD vẽ 2D nên không ảnh hưởng số đo 3D.
	for layer in scene.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 300.0
	cam.cull_mask = 0xFFFFF & ~(1 << 11)  # như camera sau lưng mèo: không vẽ chân trước góc thứ nhất
	scene.add_child(cam)
	var vp := root.get_viewport()
	if "stations" in scene and "--can-canh" in OS.get_cmdline_user_args():
		# Thêm góc cận cảnh từng trạm bếp (camera lướt vào khi Bơ làm), chỉ để soát ánh sáng
		shots = shots.duplicate()
		for id in scene.stations:
			var st: Dictionary = scene.stations[id]
			shots.append(["tham_khao_bep_" + str(id), st.cam, st.look])
	for s in shots:
		if s[1] != null:
			cam.make_current()
			cam.position = s[1]
			cam.look_at(s[2])
		else:
			# Giữ giao diện: màn hình chính vẽ Bơ 3D sau các nút
			for layer in scene.find_children("*", "CanvasLayer", true, false):
				layer.visible = true
		for i in SETTLE_FRAMES:
			await process_frame
		var r := {"name": s[0], "draw": 0, "obj": 0, "tri": 0, "sdraw": 0, "stri": 0}
		var t0 := Time.get_ticks_usec()
		for i in MEASURE_FRAMES:
			await process_frame
			r.draw = maxi(r.draw, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			r.obj = maxi(r.obj, vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME))
			r.tri = maxi(r.tri, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
			r.sdraw = maxi(r.sdraw, vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
			r.stri = maxi(r.stri, vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
		r["ms"] = (Time.get_ticks_usec() - t0) / 1000.0 / MEASURE_FRAMES
		rows.append(r)
		if out != "":
			vp.get_texture().get_image().save_png(out.path_join(s[0] + ".png"))
	root.remove_child(scene)
	scene.free()
	current_scene = null
	await process_frame


func _report() -> void:
	print("[hieu nang] %-18s %6s %6s %8s | %7s %8s | %7s" % ["góc", "vẽ", "vật", "tam giác", "bóng: vẽ", "tg", "ms/khung"])
	for r in rows:
		var draw: int = r.draw
		var tri: int = r.tri
		var over := []
		if not compat or r.name.begins_with("tham_khao"):
			print("[hieu nang] %-18s %6d %6d %8d | %7d %8d | %7.1f" % [r.name, r.draw, r.obj, r.tri, r.sdraw, r.stri, r.ms])
			continue
		if draw > BUDGET.draw_calls:
			over.append("lệnh vẽ %d > %d" % [draw, BUDGET.draw_calls])
		if r.obj > BUDGET.objects:
			over.append("vật thể %d > %d" % [r.obj, BUDGET.objects])
		if tri > BUDGET.triangles:
			over.append("tam giác %d > %d" % [tri, BUDGET.triangles])
		print("[hieu nang] %-18s %6d %6d %8d | %7d %8d | %7.1f %s" % [r.name, r.draw, r.obj, r.tri, r.sdraw, r.stri, r.ms, ("VƯỢT: " + ", ".join(over)) if over else ""])
		if over:
			failed = true
	if not compat:
		print("[hieu nang] Forward+: chỉ in số tham khảo, ngân sách chấm trên Compatibility (bản web)")
	print("[hieu nang] " + ("VƯỢT NGÂN SÁCH" if failed else "HIEU NANG OK"))
