extends SceneTree
## Bot tự chơi một ngày (mã I1 "Bot tự chơi cả tuần"): chạy autotest sẵn có của ngày đó, đứng ngoài ghi lại
## từng đơn (giờ còn dư, trễ, sao), chụp ảnh lúc giao, và báo đỏ khi Bơ rơi khỏi bản đồ.
## Có --bot-di thì Bơ CHẠY BỘ THẬT tới lò và tới khách theo lưới đường đi (navmesh nướng từ va chạm của phố)
## thay cho kiểu dịch chuyển của autotest, nên "giờ dư" là số thật người chơi chạy nhanh có được.
## Chỗ không đi bộ tới được (phải leo, nhảy) hoặc bị kẹt quá lâu thì bot dịch chuyển qua và ghi vào báo cáo.
##
## Chạy một ngày:  godot --path . -s tests/bot_ca_tuan.gd -- --autotest --ngay=thu_ba --bot-di
##                   [--bot-anh=thư/mục/ảnh] [--bot-bao=bao_cao.json]
## Cả tuần:        tools/bot_ca_tuan.py (gọi script này cho 7 ngày rồi gộp báo cáo).
## Chụp ảnh cần chạy có màn hình (CI dùng xvfb-run); --headless thì bỏ qua ảnh.
##
## Khi chạy bộ, script bật TuChoiPho.walk_bot để bot autotest (scripts/tu_choi_pho.gd) thôi dịch chuyển Bơ;
## phần chấm cuối ngày (in "AUTOTEST ... OK") vẫn là của TuChoiPho.verdict.

## Vùng chơi 96 x 60 m (City.SIZE) và vành phố tới cầu kênh x -62 (VanhPho). Ra ngoài khung này là rơi khỏi map.
const OUT_X := 70.0
const OUT_Z := 50.0
const OUT_Y := -5.0
## Cảnh không có đơn giao: chụp mỗi 15 giây, tối đa 8 ảnh
const VIEW_EVERY_MS := 15000
const VIEW_MAX := 8
## Vùng nướng lưới đường đi
const NAV_AABB := AABB(Vector3(-56, -2, -38), Vector3(112, 24, 76))
const CELL := 0.15
const CELL_H := 0.1

## Đi tới điểm đường (waypoint) trong bán kính này thì sang điểm kế
const WP_REACH := 0.45
## Tới gần đích (ngang) bao nhiêu thì đứng lại chờ giao
const GOAL_REACH := 0.6
## Điểm cuối đường đi cách đích xa hơn mức này (ngang/dọc) thì coi như không đi bộ tới được
const UNREACH_H := 1.2
const UNREACH_V := 0.7
## Đứng yên (đi được dưới STUCK_MOVE m trong STUCK_WINDOW giây) thì nhảy thử; kẹt quá STUCK_GIVEUP giây thì dịch chuyển
const STUCK_MOVE := 0.35
const STUCK_WINDOW := 1.2
const STUCK_GIVEUP := 6.0
## Kẹt ngay sát đích (thường là chỗ đứng giao phải nhảy lên: yên xe ôm, kệ) thì bỏ cuộc sớm hơn
const NEAR_GOAL := 2.0
const STUCK_NEAR := 2.4
## Đứng ở đích mà đơn không nhúc nhích quá lâu thì đặt Bơ đúng chỗ autotest cũ đặt
const WAIT_GIVEUP := 6.0

var day_id := "thu_hai"
var walk := false
var shot_dir := ""
var report_path := ""

var report := {}
var _scene: Node
var _main: Node  ## main.gd đang chạy (null khi ở cảnh khác: bếp, chung cư)
var _player: Node3D
var _frames := 0
var _scene_frames := 0
var _start_ms := 0
var _shots := 0
var _fell := false
var _cur := {}  ## đơn đang chơi: ghi lúc nhận, chốt lúc giao
var _next_view_ms := 0  ## lần chụp kế ở cảnh không có đơn (dạo phố, chung cư, Hội mèo)
var _views := 0
var _side_clock := []  ## [giờ còn, giờ tối đa, trễ] của cảnh có đồng hồ riêng (chung cư Thứ Năm)

# Đi bộ
static var _nav_cache: NavigationMesh  ## nướng một lần mỗi ngày (main.tscn nạp lại sau bếp, sau chung cư)
var _region := RID()
var _nav_ready := false
var _path := PackedVector3Array()
var _wp := 0
var _path_goal := Vector3.INF
var _path_age := 0.0
var _unreachable := false
var _stuck_t := 0.0
var _stuck_ref := Vector3.ZERO
var _stuck_clock := 0.0
var _wait_t := 0.0
var _jump_hold := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ngay="):
			day_id = arg.substr(7)
		elif arg == "--bot-di":
			walk = true
		elif arg.begins_with("--bot-anh="):
			shot_dir = arg.substr(10)
		elif arg.begins_with("--bot-bao="):
			report_path = arg.substr(10)
	if DisplayServer.get_name() == "headless":
		shot_dir = ""
	if shot_dir != "":
		DirAccess.make_dir_recursive_absolute(shot_dir)
	PlayMode.day = day_id
	TuChoiPho.walk_bot = walk
	report = {"day": day_id, "expected": Days.orders(day_id).size(), "title": Days.get_day(day_id).get("title", ""), "walk": walk, "orders": [],
		"falls": [], "teleports": [], "scenes": [], "shots": [], "seconds": 0.0}
	_start_ms = Time.get_ticks_msec()
	print("[bot] ngày ", day_id, " · ", "chạy bộ thật" if walk else "theo autotest (dịch chuyển)")
	change_scene_to_file.call_deferred(PlayMode.DELIVERY_SCENE)


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene != _scene:
		_attach(current_scene)
	_scene_frames += 1
	if _main == null and _scene and "time_left" in _scene and "time_limit" in _scene:
		_side_clock = [_scene.time_left, _scene.time_limit, _scene.get("late") == true]
	if shot_dir != "" and (_main == null or _main.orders.is_empty()) and _scene_frames > 30 and _views < VIEW_MAX \
			and Time.get_ticks_msec() >= _next_view_ms:
		_views += 1
		_next_view_ms = Time.get_ticks_msec() + VIEW_EVERY_MS
		_shot("%s_canh%d" % [day_id, _views])
	_check_fall()
	return false


func _physics_process(delta: float) -> bool:
	if not walk or _main == null or not is_instance_valid(_main):
		return false
	if _main.state != _main.State.PLAY or _main.orders.is_empty() or _main.get("_leaving"):
		_release_keys()
		return false
	if not _nav_ready:
		if _scene_frames > 3:
			_build_nav()
		return false
	_walk_step(delta)
	return false


func _finalize() -> void:
	_release_keys()
	report.seconds = snappedf((Time.get_ticks_msec() - _start_ms) / 1000.0, 0.1)
	# Kết luận của bot: giao đủ đơn của ngày và Bơ không rơi khỏi map
	report.ok = report.orders.size() >= report.expected and report.falls.is_empty()
	if report_path != "":
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(report, "  "))
	print("[bot] xong ngày ", day_id, ": ", report.orders.size(), " đơn, ", report.falls.size(), " lần rơi khỏi map, ",
		report.teleports.size(), " lần bot phải dịch chuyển")


# ---------------------------------------------------------------- theo dõi cảnh và đơn

func _attach(scene: Node) -> void:
	_scene = scene
	_scene_frames = 0
	_main = null
	_player = null
	_nav_ready = false
	_path = PackedVector3Array()
	_release_keys()
	if scene == null:
		return
	report.scenes.append(scene.scene_file_path.get_file())
	var p = scene.get("player")
	if p is Node3D:
		_player = p
	if scene.has_signal("order_delivered") and "orders" in scene:
		_main = scene
		scene.order_picked_up.connect(_on_picked)
		scene.order_delivered.connect(_on_delivered)


func _on_picked(i: int, order: Dictionary) -> void:
	_cur = {"index": i + 1, "who": order.get("who", ""), "place": order.get("place", ""),
		"limit": snappedf(_main._time_limit(order), 0.1), "teleports": 0, "picked_ms": Time.get_ticks_msec()}


func _on_delivered(i: int, order: Dictionary) -> void:
	if _cur.get("index", -1) != i + 1:
		_on_picked(i, order)  # cảnh nạp lại giữa đơn (Thứ Năm về từ chung cư)
	var row: Dictionary = _main.score_rows[-1] if not _main.score_rows.is_empty() else {}
	_cur.left = snappedf(_main.time_left, 0.1)
	_cur.late = _main.late
	_cur.untimed = _main._untimed(order)
	if order.get("delivery", "") == "scene" and not _side_clock.is_empty():
		# Đơn sang cảnh riêng (chung cư Thứ Năm): giờ là đồng hồ của cảnh đó
		_cur.left = snappedf(_side_clock[0], 0.1)
		_cur.limit = snappedf(_side_clock[1], 0.1)
		_cur.late = _side_clock[2]
		_cur.scene = true
		_side_clock = []
	_cur.stars = row.get("stars", 0)
	_cur.carry = snappedf(row.get("time", 0.0), 0.1)
	_cur.bites = _main.bites
	_cur.intact = _main.intact
	_cur.side_ok = row.get("side_ok", false)
	_cur.erase("picked_ms")
	_cur.shot = _shot("%s_don%d" % [day_id, i + 1])
	report.orders.append(_cur)
	var left_txt := "không tính giờ" if _cur.untimed else ("TRỄ" if _cur.late else "dư %.1f/%.0f s" % [_cur.left, _cur.limit])
	print("[bot] đơn %d %s: %s · %d sao · bot dịch chuyển %d lần" % [i + 1, _cur.who, left_txt, _cur.stars, _cur.teleports])
	_cur = {}
	_path = PackedVector3Array()


func _check_fall() -> void:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	var p := _player.global_position
	var out := p.y < OUT_Y or absf(p.x) > OUT_X or absf(p.z) > OUT_Z
	if out and not _fell:
		_fell = true
		var info := {"scene": _scene.scene_file_path.get_file(), "pos": _v(p),
			"order": _main.order_index + 1 if _main and is_instance_valid(_main) else _cur.get("index", 0),
			"shot": _shot("%s_roi_khoi_map" % day_id)}
		report.falls.append(info)
		print("[bot] RƠI KHỎI MAP ở ", info.pos, " (", info.scene, ", đơn ", info.order, ")")
	elif not out:
		_fell = false


func _shot(name: String) -> String:
	if shot_dir == "":
		return ""
	_shots += 1
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		return ""
	img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
	var file := "%02d_%s.jpg" % [_shots, name]
	img.save_jpg(shot_dir.path_join(file), 0.8)
	report.shots.append(file)
	return file


static func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)]


# ---------------------------------------------------------------- chạy bộ

func _build_nav() -> void:
	var map: RID = _main.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, CELL)
	NavigationServer3D.map_set_cell_height(map, CELL_H)
	if _nav_cache == null:
		var t := Time.get_ticks_msec()
		var nm := NavigationMesh.new()
		nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		nm.geometry_collision_mask = Blocks.LAYER_WORLD | Blocks.LAYER_PROP
		nm.cell_size = CELL
		nm.cell_height = CELL_H
		nm.agent_radius = 0.3
		nm.agent_height = 0.5  # Bơ đứng cao ~0,45 m; gầm thấp hơn thì phải chui, bot không đi
		nm.agent_max_climb = 0.35
		nm.agent_max_slope = 40.0
		nm.region_min_size = 4.0
		nm.filter_baking_aabb = NAV_AABB
		var src := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(nm, src, _main)
		NavigationServer3D.bake_from_source_geometry_data(nm, src)
		_nav_cache = nm
		print("[bot] nướng lưới đường đi: %d đa giác, %d ms" % [nm.get_polygon_count(), Time.get_ticks_msec() - t])
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_region, map)
	NavigationServer3D.region_set_navigation_mesh(_region, _nav_cache)
	_nav_ready = true
	_path = PackedVector3Array()
	_stuck_ref = _player.global_position


## Đích bot nhắm tới: chỗ đứng giao như autotest của main.gd. Khác autotest, bot không cố ghé Chó Mực cho bị đớp,
## không nhặt tem, không làm nhiệm vụ phụ: chỉ chạy đường ngắn nhất như người chơi vội.
func _goal() -> Vector3:
	var m := _main
	var oi: int = m.order_index
	var goal: Vector3 = m._current_goal()
	if m.player.carrying and not m.get("_finishing") and not m._is_errand(m.orders[oi]):
		goal = m.deliveries.stand_point(oi)
	return goal


func _walk_step(delta: float) -> void:
	var p: Node3D = _main.player
	var pos := p.global_position
	var goal := _goal()
	_path_age += delta
	if _path.is_empty() or _flat(goal - _path_goal) > 0.5 or _path_age > 2.0:
		_plan(pos, goal)
	var to_goal := _flat(goal - pos)
	if to_goal < GOAL_REACH and absf(goal.y - pos.y) < UNREACH_V:
		# Tới nơi: đứng chờ giao (giỏ Bé Na, chiếu tướng...). Đứng lâu không xong thì đặt đúng chỗ như autotest cũ.
		_release_keys()
		_wait_t += delta
		if _wait_t > WAIT_GIVEUP:
			_teleport(goal, "đứng ở đích %d giây mà đơn chưa xong" % int(WAIT_GIVEUP))
		return
	_wait_t = 0.0
	var wp := goal
	if _wp < _path.size():
		wp = _path[_wp]
		while _flat(wp - pos) < WP_REACH and _wp < _path.size():
			_wp += 1
			wp = _path[_wp] if _wp < _path.size() else goal
	if _wp >= _path.size() and _unreachable:
		# Hết đường đi bộ mà chưa tới đích: chỗ phải leo, nhảy
		_teleport(goal, "không có đường đi bộ (phải leo/nhảy)")
		return
	_press_toward(wp - pos, p)
	# Kẹt: không nhích được thì nhảy thử, lâu quá thì dịch chuyển tới điểm đường kế
	_stuck_clock += delta
	if _stuck_clock >= STUCK_WINDOW:
		if pos.distance_to(_stuck_ref) < STUCK_MOVE:
			_stuck_t += _stuck_clock
			_jump_hold = 8
		else:
			_stuck_t = 0.0
		_stuck_ref = pos
		_stuck_clock = 0.0
	if _jump_hold > 0:
		_jump_hold -= 1
		Input.action_press("jump")
	else:
		Input.action_release("jump")
	if _stuck_t > STUCK_GIVEUP or (_stuck_t > STUCK_NEAR and to_goal < NEAR_GOAL):
		if to_goal < NEAR_GOAL:
			_teleport(goal, "sát đích mà không lên được (chỗ đứng giao cao hơn đất %.1f m)" % (goal.y - pos.y))
			return
		_teleport(_path[mini(_wp + 1, _path.size() - 1)] if _wp + 1 < _path.size() else goal, "kẹt ở %s" % [_v(pos)])


func _plan(from: Vector3, goal: Vector3) -> void:
	var map: RID = _main.get_world_3d().navigation_map
	_path = NavigationServer3D.map_get_path(map, from, goal, true)
	_path_goal = goal
	_path_age = 0.0
	_wp = 1 if _path.size() > 1 else 0
	var end := _path[-1] if not _path.is_empty() else from
	# Không tới được thì vẫn đi bộ tới chỗ gần nhất trên lưới rồi mới dịch chuyển phần phải leo
	_unreachable = _path.is_empty() or _flat(end - goal) > UNREACH_H or absf(end.y - goal.y) > UNREACH_V


## Bấm phím di chuyển theo hướng thế giới, đổi sang hệ camera (player.gd xoay phím theo camera_rig.yaw).
func _press_toward(d: Vector3, p: Node3D) -> void:
	d.y = 0.0
	if d.length() < 0.001:
		_release_keys()
		return
	var yaw: float = p.camera_rig.yaw if p.get("camera_rig") else 0.0
	var local := d.normalized().rotated(Vector3.UP, -yaw)
	_axis("move_right", "move_left", local.x)
	_axis("move_back", "move_forward", local.z)
	Input.action_press("sprint")


static func _axis(pos_action: String, neg_action: String, v: float) -> void:
	if v > 0.05:
		Input.action_press(pos_action, minf(v * 1.5, 1.0))
		Input.action_release(neg_action)
	elif v < -0.05:
		Input.action_press(neg_action, minf(-v * 1.5, 1.0))
		Input.action_release(pos_action)
	else:
		Input.action_release(pos_action)
		Input.action_release(neg_action)


func _release_keys() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back", "sprint", "jump"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _teleport(to: Vector3, why: String) -> void:
	var p: CharacterBody3D = _main.player
	var info := {"order": _main.order_index + 1, "carrying": p.carrying, "from": _v(p.global_position), "to": _v(to), "why": why}
	report.teleports.append(info)
	if not _cur.is_empty():
		_cur.teleports += 1
	print("[bot] dịch chuyển (đơn %d): %s" % [info.order, why])
	p.global_position = to + Vector3(0, 0.2, 0)
	p.velocity = Vector3.ZERO
	_release_keys()
	_path = PackedVector3Array()
	_stuck_t = 0.0
	_wait_t = 0.0
	_stuck_ref = p.global_position


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
