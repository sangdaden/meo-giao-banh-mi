extends SceneTree
## Quay từng cảnh cho trailer: Bơ tự chạy theo kịch bản bằng phím ảo (không dịch chuyển), camera là camera game
## bám sau lưng hoặc camera điện ảnh (bám theo, đứng yên, lia thẳng). Ẩn HUD cho hình sạch.
## Chạy (máy đám mây; Movie Maker ghi đúng 30 hình/giây dù máy render chậm):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 \
##     --write-movie <ra.avi> -s tools/trailer/quay_canh.gd -- <tên_cảnh>
## Tên cảnh là khóa trong SHOTS. Bản đồ đổi thì sửa tọa độ trong SHOTS rồi quay lại cảnh đó (tools/trailer/README.md).

## Khóa của một cảnh:
##   scene: "main" (mặc định) | "chung_cu";  day: mã ngày;  setup: tên hàm chuẩn bị bên dưới (tùy chọn)
##   start: chỗ Bơ đứng;  yaw: hướng camera game (0 = nhìn về bắc −z);  seconds: độ dài
##   cam: {"mode": "follow"} | {"mode": "track", "offset", "look"} | {"mode": "fixed", "from", "at"}
##        | {"mode": "dolly", "from", "to", "at", "at_to"} (lia mượt từ from tới to suốt cảnh);  "fov" tùy chọn
##   steps: ["go", điểm, "sprint"|"walk"|"sneak"] | ["jump"] | ["wait", giây] | ["deliver"] | ["call", tên_hàm]
const SHOTS := {
	# 1. Mở: Bơ ngồi liếm chân trước lò bánh, camera tiến chậm vào mặt
	"mo_dau": {
		"day": "thu_hai", "start": Vector3(-29.6, 0.05, -4.2), "yaw": 0.0, "seconds": 5.5, "setup": "_ngoi_liem",
		"cam": {"mode": "dolly", "from": Vector3(-30.3, 0.55, -2.0), "to": Vector3(-29.9, 0.42, -2.95),
			"at": Vector3(-29.6, 0.35, -4.2), "at_to": Vector3(-29.6, 0.32, -4.2), "fov": 40.0},
		"steps": [["wait", 4.6], ["call", "_dung_day"]],
	},
	# 3. Lao ra phố: camera bám ngang, Bơ chạy dọc vỉa hè và nhảy
	"chay_ra_pho": {
		"day": "thu_hai", "start": Vector3(-33, 0.1, -3.6), "yaw": -PI / 2, "seconds": 5.0,
		"cam": {"mode": "track", "offset": Vector3(-0.6, 1.0, 3.0), "look": Vector3(1.2, 0.4, 0), "fov": 50.0},
		"steps": [["go", Vector3(-28, 0, -3.6), "sprint"], ["jump"], ["go", Vector3(-22, 0, -3.6), "sprint"], ["jump"],
			["go", Vector3(-15, 0, -3.6), "sprint"], ["jump"], ["go", Vector3(2, 0, -3.6), "sprint"]],
	},
	"nga_tu": {
		"day": "thu_hai", "setup": "_no_traffic", "start": Vector3(-18.0, 0.1, -13.0), "yaw": PI, "seconds": 3.0,
		"cam": {"mode": "track", "offset": Vector3(2.6, 0.7, -0.6), "look": Vector3(0, 0.3, 0.8), "fov": 50.0},
		"steps": [["go", Vector3(-18.0, 0, 8.0), "sprint"]],
	},
	"tren_cao": {
		"day": "thu_hai", "start": Vector3(-30, 0.1, -3.2), "yaw": -PI / 2, "seconds": 4.0,
		"cam": {"mode": "dolly", "from": Vector3(-34, 16, 14), "to": Vector3(-14, 18, 12), "at": Vector3(-30, 0, -3), "at_to": Vector3(-12, 0, -3)},
		"steps": [["go", Vector3(-10, 0, -3.2), "sprint"]],
	},
	# 4. Giao bánh: mỗi cảnh một đơn, Bơ cầm bánh chạy tới chỗ đứng giao rồi bấm E
	"giao_be_na": {
		"day": "thu_hai", "setup": "_cam_banh", "order": 1, "seconds": 3.5, "start": Vector3(29.2, 0.1, -14.6), "yaw": PI / 2,
		"cam": {"mode": "track", "offset": Vector3(2.2, 0.9, 0.3), "look": Vector3(-1.0, 0.9, 0), "fov": 55.0},
		"steps": [["go_stand", "walk"], ["deliver"], ["wait", 2.0]],
	},
	"giao_anh_hung": {
		"day": "thu_hai", "setup": "_cam_banh", "order": 3, "seconds": 4.0, "approach": 3.0,
		"cam": {"mode": "track", "offset": Vector3(-1.8, 0.8, 1.6), "look": Vector3(0, 0.25, 0), "fov": 55.0},
		"steps": [["go_stand", "walk"], ["deliver"], ["wait", 2.0]],
	},
	"giao_chi_may": {
		"day": "thu_hai", "setup": "_cam_banh", "order": 2, "seconds": 4.5, "start": Vector3(5.4, 0.1, 1.6), "yaw": PI,
		"cam": {"mode": "track", "offset": Vector3(-1.8, 1.0, -1.4), "look": Vector3(0, 0.6, 0.4), "fov": 55.0},
		"steps": [["go_stand", "walk"], ["deliver"], ["wait", 2.0]],
	},
	"giao_chu_tu": {
		"day": "thu_hai", "setup": "_cam_banh", "order": 0, "seconds": 4.0, "approach": 4.0,
		"cam": {"mode": "track", "offset": Vector3(1.8, 1.0, 1.6), "look": Vector3(0, 0.5, 0), "fov": 55.0},
		"steps": [["go_stand", "walk"], ["deliver"], ["wait", 2.0]],
	},
	# 5. Hẻm 42: rón rén ngang qua Chó Mực đang ngủ, Mực thức, sủa, Bơ phóng đi
	"muc": {
		"day": "thu_hai", "setup": "_cam_banh", "order": 4, "start": Vector3(-17.5, 0.1, 14.0), "yaw": PI, "seconds": 7.0,
		"cam": {"mode": "dolly", "from": Vector3(-17.5, 0.9, 18.6), "to": Vector3(-17.9, 1.3, 20.0),
			"at": Vector3(-18.0, 0.3, 14.5), "at_to": Vector3(-18.3, 0.3, 16.0), "fov": 50.0},
		"steps": [["go", Vector3(-17.5, 0, 15.3), "sneak"], ["wait", 0.9], ["go", Vector3(-17.5, 0, 16.6), "sneak"],
			["call", "_muc_thuc"], ["wait", 0.8],
			["go", Vector3(-18.9, 0, 20.9), "sprint"], ["wait", 4.0]],
	},
	# 6. Bảy ngày
	"thu_ba": {
		"day": "thu_ba", "setup": "_cho_em", "start": Vector3(-12, 0.1, 0.0), "yaw": -PI / 2, "seconds": 3.5,
		"cam": {"mode": "track", "offset": Vector3(-1.4, 2.2, 2.6), "look": Vector3(2.0, 0.2, 0), "fov": 55.0},
		"steps": [["go", Vector3(10, 0, 0.0), "sprint"]],
	},
	"thu_tu": {
		"day": "thu_tu", "setup": "_mua_ngap", "start": Vector3(-23.75, 3.0, -3.0), "yaw": PI, "seconds": 3.5,
		"cam": {"mode": "track", "offset": Vector3(-2.6, 0.7, 1.4), "look": Vector3(0, 0.2, 0.8), "fov": 50.0},
		"steps": [["go", Vector3(-23.75, 0, 3.5), "walk"]],
	},
	"thu_sau": {
		"day": "thu_sau", "start": Vector3(30.5, 0.1, 27.5), "yaw": -0.57, "seconds": 3.5,
		"cam": {"mode": "dolly", "from": Vector3(30.0, 2.4, 31.5), "to": Vector3(31.5, 2.0, 29.0), "at": Vector3(32.2, 1.0, 21.0), "at_to": Vector3(33.2, 0.8, 21.5)},
		"steps": [["go", Vector3(33.2, 0, 23.3), "walk"]],
	},
	"thu_bay": {
		"day": "thu_bay", "setup": "_hoang_hon", "start": Vector3(-36.0, 0.1, 13.0), "yaw": -PI / 2, "seconds": 3.5,
		"cam": {"mode": "track", "offset": Vector3(-1.0, 1.2, 3.2), "look": Vector3(1.5, 0.4, 0), "fov": 52.0},
		"steps": [["go", Vector3(-21.0, 0, 13.0), "walk"]],
	},
	"chu_nhat": {
		"day": "chu_nhat", "setup": "_hoi_meo", "seconds": 4.5,
		"cam": {"mode": "dolly", "from": Vector3(-33.0, 1.6, 16.0), "to": Vector3(-33.0, 1.3, 19.2), "at": Vector3(-33.0, 0.9, 22.4), "at_to": Vector3(-33.0, 0.8, 22.3)},
		"steps": [["wait", 0.5], ["call", "_nhan_huy_chuong"], ["wait", 3.0]],
	},
	"thu_nam": {
		"scene": "chung_cu", "setup": "_leo_ong", "seconds": 3.5,
		"cam": {"mode": "track", "offset": Vector3(-1.6, -0.4, 1.3), "look": Vector3(0, 0.3, 0), "fov": 50.0},
		"steps": [["hold", "move_forward", 3.4]],
	},
	# 8. Kết: hoàng hôn, Bơ trên bồn nước nhìn phố, camera kéo lùi lên cao
	"ket": {
		"day": "chu_nhat", "setup": "_hoi_meo", "seconds": 9.0,
		"cam": {"mode": "dolly", "from": Vector3(-33.0, 0.95, 20.9), "to": Vector3(-33.0, 8.5, 9.0), "at": Vector3(-33.0, 0.75, 22.2), "at_to": Vector3(-33.0, 1.6, 21.0), "fov": 50.0},
		"steps": [["wait", 0.3], ["call", "_nhan_huy_chuong"], ["wait", 7.0]],
	},
}

var shot: Dictionary
var main: Node
var p: CharacterBody3D
var rig: Node3D
var cam: Camera3D
var _late: Node                  # chạy sau mọi node khác trong khung: đặt camera theo chỗ Bơ đang được vẽ
var _track := []                 # --debug: vị trí Bơ trên màn hình từng khung, để đo giật


## Node chạy cuối khung (process_priority cao): camera đặt sau khi Bơ đã nội suy vị trí vẽ, khỏi lệch một khung.
class LateCam extends Node:
	var on_frame: Callable

	func _process(_delta: float) -> void:
		on_frame.call()
var t := 0.0
var _held := []
var _debug := false


func _initialize() -> void:
	var name := "chay_ra_pho"
	for a in OS.get_cmdline_user_args():
		if a == "--debug":
			_debug = true
		elif not a.begins_with("--"):
			name = a
	shot = SHOTS[name].duplicate(true)
	PlayMode.day = shot.get("day", "thu_hai")
	GameState.day = PlayMode.day  # chợ sáng Thứ Ba dựng theo GameState.day
	GameState.use_test_save("user://luu_game_trailer.cfg")
	_run.call_deferred()


func _run() -> void:
	# Tắt nhạc nền của game, giữ tiếng động (bước chân, xe, mưa, tiếng sủa) để trộn dưới nhạc trailer
	var music := AudioServer.get_bus_index("Music")
	if music != -1:
		AudioServer.set_bus_mute(music, true)
	if shot.get("scene", "main") == "chung_cu":
		change_scene_to_file("res://scenes/chung_cu.tscn")
	else:
		change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	main = current_scene
	p = main.player
	rig = main.rig
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if rig.first_person:
		rig.first_person = false
	if shot.has("setup"):
		await call(shot.setup)
	if shot.has("start"):
		_put(shot.start)
	if shot.has("yaw"):
		rig.yaw = shot.yaw
	rig.global_position = p.global_position + Vector3.UP
	if shot.cam.mode != "follow":
		cam = Camera3D.new()
		main.add_child(cam)
		cam.current = true
	if cam:
		cam.fov = shot.cam.get("fov", 55.0)
	# Cho cảnh ổn định (bóng, người dân vào chỗ) trước khi diễn; Movie Maker vẫn ghi nên đoạn này cắt bỏ lúc dựng
	_hide_hud()
	_late = LateCam.new()
	_late.process_priority = 10000
	_late.on_frame = _camera
	main.add_child(_late)
	for i in 15:
		await process_frame
	_hide_hud()
	_clean()
	_steps.call()  # diễn song song với vòng ghi hình
	var total := int(shot.seconds * 30.0)
	for i in total:
		t = i / 30.0
		if i % 10 == 0:
			_clean()  # thẻ chữ hiện thêm giữa chừng (lời nhắc giao bánh)
		if _debug and i % 15 == 0:
			var hit := p.get_last_slide_collision()
			print("%.1fs Bơ %s vận tốc %.1f %s chạm %s" % [t, p.global_position, p.velocity.length(), p.stance,
				("%s @%s" % [hit.get_collider().get_path(), hit.get_position()]) if hit else ""])
			if i == 0 and "deliveries" in main:
				for k in main.orders.size():
					print("  đơn %d đứng giao %s khách %s" % [k, main.deliveries.stand_point(k), main.orders[k].pos])
		await process_frame
	if _debug:
		_report_jitter()
	quit()


func _steps() -> void:
	for s in shot.steps:
		match s[0]:
			"go":
				await _go(s[1], s[2] if s.size() > 2 else "sprint")
			"go_stand":
				var goal: Vector3 = main.deliveries.stand_point(shot.order)
				await _go(goal, s[1])
			"jump":
				await _tap("jump")
			"deliver":
				await _tap("deliver")
			"hold":
				_hold(s[1])
				await create_timer(s[2]).timeout
				_release_all()
			"wait":
				await create_timer(s[1]).timeout
			"call":
				await call(s[1])
	_release_all()


func _tap(action: String) -> void:
	Input.action_press(action)
	await process_frame
	await process_frame
	Input.action_release(action)


func _go(goal: Vector3, how: String) -> void:
	_release_all()
	_hold("move_forward")
	if how == "sprint":
		_hold("sprint")
	elif how == "sneak":
		_hold("sneak")
	var guard := 0
	while Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z).length() > 0.35 and guard < 900:
		rig.yaw = lerp_angle(rig.yaw, _yaw_to(goal), 0.3)
		guard += 1
		await process_frame
	_release_all()


func _yaw_to(goal: Vector3) -> float:
	var d := goal - p.global_position
	return atan2(-d.x, -d.z)


func _hold(action: String) -> void:
	Input.action_press(action)
	_held.append(action)


func _release_all() -> void:
	for a in _held:
		Input.action_release(a)
	_held.clear()


func _put(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	if "_prev_pos" in p:
		p._prev_pos = pos
		p._curr_pos = pos


func _camera() -> void:
	if cam == null:
		return
	var c: Dictionary = shot.cam
	var k := clampf(t / shot.seconds, 0.0, 1.0)
	match c.mode:
		"track":
			var at: Vector3 = p.visual.global_position  # chỗ Bơ đang được vẽ (đã nội suy), không phải thân vật lý
			var goal: Vector3 = at + c.offset
			cam.global_position = goal if t == 0.0 else cam.global_position.lerp(goal, 0.15)
			cam.look_at(at + c.look)
		"fixed":
			cam.global_position = c.from
			cam.look_at(c.at)
		"dolly":
			var e := k * k * (3.0 - 2.0 * k)
			cam.global_position = c.from.lerp(c.to, e)
			cam.look_at(c.at.lerp(c.get("at_to", c.at), e))
	if _debug and cam.is_position_in_frustum(p.visual.global_position):
		_track.append(cam.unproject_position(p.visual.global_position + Vector3.UP * 0.25))


## Đo giật: gia tốc vị trí Bơ trên màn hình (điểm ảnh/khung²). Chạy đều thì nhỏ và êm; giật thì có đỉnh lẻ.
func _report_jitter() -> void:
	var acc := []
	for i in range(2, _track.size()):
		acc.append((_track[i] - 2.0 * _track[i - 1] + _track[i - 2]).length())
	if acc.is_empty():
		print("[giat] không thấy Bơ trong khung")
		return
	var sorted := acc.duplicate()
	sorted.sort()
	var med: float = sorted[sorted.size() / 2]
	var peaks := 0
	var at := []
	for i in acc.size():
		if acc[i] > maxf(4.0, med * 4.0):
			peaks += 1
			at.append("%.2fs:%.0f" % [(i + 2) / 30.0, acc[i]])
	print("[giat] đỉnh lúc ", " ".join(at))
	print("[giat] khung=%d trung_vi=%.2f lon_nhat=%.1f dinh=%d" % [acc.size(), med, sorted[-1], peaks])


func _hide_hud() -> void:
	if "hud" in main and main.hud:
		main.hud.visible = false
	for n in main.find_children("*", "CanvasLayer", true, false):
		n.visible = false


## Bỏ dấu chỉ đường của HUD 3D (vòng nhận/giao, cột sáng, mũi tên, thẻ tên đơn) cho hình sạch; giữ chữ "z z z" của Mực.
func _clean() -> void:
	for m in main.find_children("*", "MeshInstance3D", true, false):
		if m.mesh is TorusMesh:
			m.visible = false
	var dog: Node = main.get("dog")
	for l in main.find_children("*", "Label3D", true, false):
		if dog == null or not dog.is_ancestor_of(l):
			l.visible = false
	for n in ["beacon", "arrow"]:
		if n in main and main.get(n):
			main.get(n).visible = false


# ---------------------------------------------------------------- chuẩn bị từng cảnh

func _no_traffic() -> void:
	var gt: Node = main.get_node_or_null("GiaoThong")
	if gt:
		gt.process_mode = Node.PROCESS_MODE_DISABLED
		gt.visible = false


## Chợ Thứ Ba: Bơ chạy xuyên qua người mua mà không bị va, đỡ khựng hình giữa cảnh
func _cho_em() -> void:
	for n in main.get_children():
		if n.get_script() and n.get_script().resource_path.ends_with("market.gd"):
			n.set("_bump_cd", 1.0e9)
			for bk in n.get("_baskets"):
				bk.spilled = true  # chỉ tắt việc đổ thúng, thúng vẫn đầy hàng


func _ngoi_liem() -> void:
	_no_traffic()
	p.preview = true
	p.visual.rotation.y = PI
	p.play_idle_action("lick", 4.2)


func _dung_day() -> void:
	p.play_idle_action("", 5.0)


## Đang cầm bánh của đơn shot.order, đứng cách chỗ giao vài mét
func _cam_banh() -> void:
	var i: int = shot.order
	main.order_index = i
	main.player.carrying = true
	main.time_left = 30.0
	if not shot.has("start"):
		var stand: Vector3 = main.deliveries.stand_point(i)
		var back := Vector3(0, 0, shot.get("approach", 3.0))
		var toward: Vector3 = (stand - main.orders[i].pos)
		toward.y = 0
		if toward.length() > 0.1:
			back = toward.normalized() * shot.get("approach", 3.0)
		shot.start = stand + back + Vector3(0, 0.1, 0)
		shot.yaw = atan2(back.x, back.z)
	await process_frame


func _muc_thuc() -> void:
	var dog: Node = main.dog
	# Mực sủa đuổi nhưng không đớp: cú đớp hất Bơ lùi làm hình khựng giữa cảnh
	if dog.bit_player.is_connected(main._on_dog_bite):
		dog.bit_player.disconnect(main._on_dog_bite)
	dog.awake = true
	dog._set_state(dog.State.SUSPICIOUS)
	await create_timer(0.5).timeout
	dog._set_state(dog.State.CHASE)


func _mua_ngap() -> void:
	var tt: Node = main.get_node("ThuTu")
	if tt.thoi_tiet:
		tt.thoi_tiet.ngap(0.25, 0.0)


func _hoang_hon() -> void:
	var tb: Node = main.get_node("ThuBay")
	tb._sky_t = 1.0
	tb._sky_goal = 1.0
	tb._apply_sky(1.0)


func _hoi_meo() -> void:
	var cn: Node = main.get_node("ChuNhat")
	cn.hud = main.hud
	for c in cn.contests:
		c.hud = main.hud
	cn.phase = "hoi"
	cn._start_festival()
	await process_frame
	var spot: Vector3 = cn.STAGE + cn.POSE_SPOT + Vector3(0, cn.STAGE_H + 0.05, 0)
	cn.put_player(spot, spot + Vector3(0, 0, -3))
	shot.start = spot


func _nhan_huy_chuong() -> void:
	p.play_clip("nhan_huy_chuong")


func _leo_ong() -> void:
	main.playing = true
	var y := 4.0
	_put(Vector3(-0.32, y, main.PIPE.z))
	for i in 3:
		await physics_frame
	_put(Vector3(-0.32, y, main.PIPE.z))
	p.climb = "pipe"
	p._pipe = p._pipes[0] if p._pipes.size() > 0 else null
	p._wall_n = Vector3.LEFT
	p.visual.rotation.y = PI / 2.0
	rig.yaw = PI / 2.0
	shot.erase("start")
