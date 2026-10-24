extends SceneTree
## Ảnh so sánh mỗi PR (mã P2): chụp những góc cố định của từng ngày để CI so ảnh trên main và trên PR.
## Mỗi ngày: một ảnh nhìn từ trên cao, một ảnh lò bánh Cô Ba, và một ảnh ở chỗ khách của mỗi đơn
## (camera lùi ra phía thoáng nhất quanh chỗ khách, cao ~1,8 m, như camera sau lưng mèo lúc giao).
## Thêm màn bếp và màn hình chính. Giao diện 2D bị tắt, trừ ảnh màn hình chính.
##
## Chạy (cần màn hình, máy đám mây dùng xvfb-run; --fixed-fps cho mỗi khung bước thời gian như nhau):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --fixed-fps 30 \
##     -s tools/so_anh/chup.gd -- --chup=<thư_mục_ảnh> [--ngay=thu_hai,thu_ba] [--khong-bep] [--khong-menu]
## Rồi so hai thư mục: python3 tools/so_anh/so_sanh.py (xem đầu file đó, và docs/so-anh.md).
##
## Script này chỉ dùng thứ có từ lâu (PlayMode.day, Days.orders, City.BAKERY_POINT) vì CI chép nó sang
## bản main cũ để chụp cùng góc. Đổi góc chụp thì cả hai bên đổi theo, không báo khác giả.

const DAYS := ["thu_hai", "thu_ba", "thu_tu", "thu_nam", "thu_sau", "thu_bay", "chu_nhat"]
const SIZE := Vector2i(960, 540)
## Khung chờ sau khi nạp cảnh (đèn, bóng, người dân đứng vào chỗ) và sau mỗi lần đặt camera
const LOAD_FRAMES := 45
const SETTLE_FRAMES := 8
## Chụp thêm vài ảnh sau chừng này khung (cách nhau lệch nhịp, để bắt cả thứ lắc theo chu kỳ): chỗ nào tự đổi giữa
## các ảnh (người đi, đuôi mèo vẫy, mũi tên nhún, mưa) là chỗ động, so_sanh.py không tính chỗ đó là khác.
## Ảnh phụ tên <góc>.sau1.png, <góc>.sau2.png...
const MOVE_FRAMES := [7, 13, 19]
## Góc chung mỗi ngày: tên, vị trí camera, điểm nhìn
const SHOTS_DAY := [
	["tren_cao", Vector3(-40, 22, 30), Vector3(-5, 0, -2)],
	["lo_banh", Vector3(-33, 1.7, -1.0), Vector3(-33, 0.9, -6.5)],
]
const SHOTS_BEP := [
	["bep_toan_canh", Vector3(0, 2.6, 4.3), Vector3(0, 0.0, -0.3)],
]
## Camera ở chỗ khách: thử 8 hướng quanh khách, chọn hướng thoáng nhất (tia không vướng tường), lùi tối đa BACK m
const BACK := 4.0
const CAM_H := 1.8
const LOOK_H := 0.6

var out := ""
var days: Array = DAYS.duplicate()
var bep := true
var menu := true
var shots := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chup="):
			out = a.substr(7)
		elif a.begins_with("--ngay="):
			days = Array(a.substr(7).split(",", false))
		elif a == "--khong-bep":
			bep = false
		elif a == "--khong-menu":
			menu = false
	if out == "":
		push_error("[so anh] thiếu --chup=<thư_mục>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	seed(12345)
	_run.call_deferred()


func _run() -> void:
	root.size = SIZE
	if DisplayServer.get_name() == "headless":
		print("[so anh] --headless không vẽ gì; chạy bằng xvfb-run, không dùng --headless")
		quit(1)
		return
	for d in days:
		PlayMode.day = d
		var list: Array = SHOTS_DAY.duplicate()
		var i := 0
		for o in Days.orders(d):
			i += 1
			if o.get("pos") is Vector3:
				list.append(["don%d" % i, null, o.pos])
		await _scene(PlayMode.DELIVERY_SCENE, d + "_", list)
	PlayMode.day = DAYS[0]
	if bep:
		await _scene("res://scenes/kitchen.tscn", "", SHOTS_BEP)
	if menu:
		await _scene("res://scenes/menu.tscn", "", [["menu_chinh", null, null]])
	print("[so anh] xong %d ảnh vào %s" % [shots, out])
	print("SO ANH CHUP OK")
	quit(0)


func _scene(path: String, prefix: String, list: Array) -> void:
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in LOAD_FRAMES:
		await process_frame
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layers := scene.find_children("*", "CanvasLayer", true, false)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 300.0
	cam.cull_mask = 0xFFFFF & ~(1 << 11)  # như camera sau lưng mèo: không vẽ chân trước góc thứ nhất
	scene.add_child(cam)
	for s in list:
		var keep_ui: bool = s[1] == null and s[2] == null
		for l in layers:
			if is_instance_valid(l):
				l.visible = keep_ui
		if not keep_ui:
			cam.make_current()
			if s[1] == null:
				var p: Vector3 = s[2]
				cam.position = _clear_spot(scene, p)
				cam.look_at(p + Vector3(0, LOOK_H, 0))
			else:
				cam.position = s[1]
				cam.look_at(s[2])
		for i in SETTLE_FRAMES:
			await process_frame
		await _save(prefix + s[0] + ".png")
		for k in MOVE_FRAMES.size():
			for i in MOVE_FRAMES[k]:
				await process_frame
			await _save(prefix + s[0] + ".sau%d.png" % (k + 1))
		shots += 1
		print("[so anh] ", prefix + s[0])
	root.remove_child(scene)
	scene.free()
	current_scene = null
	for i in 3:
		await process_frame


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img and not img.is_empty():
		img.save_png(out.path_join(file))


## Chỗ đặt camera quanh khách: hướng nào tia từ khách bay xa nhất (tối đa BACK m) thì lùi ra hướng đó.
## Hòa nhau thì giữ hướng đầu tiên trong danh sách cố định, để hai lần chạy chọn y như nhau.
func _clear_spot(scene: Node, p: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = scene.get_viewport().world_3d.direct_space_state
	var from := p + Vector3(0, CAM_H, 0)
	var best := from + Vector3(0, 0, BACK)
	var best_d := -1.0
	for k in 8:
		var a := k * TAU / 8.0
		var dir := Vector3(sin(a), 0.25, cos(a)).normalized()
		var to := from + dir * BACK
		var q := PhysicsRayQueryParameters3D.create(from, to)
		var hit := space.intersect_ray(q)
		var d := BACK if hit.is_empty() else from.distance_to(hit.position) - 0.3
		if d > best_d + 0.05:
			best_d = d
			best = from + dir * maxf(d, 1.2)
	return best
