extends Node3D
## Màn chơi thử: dựng khu phố, mèo, camera, Chó Mực, khách, HUD và vòng giao 5 đơn.
## Toàn bộ dựng bằng code cho bản khối thô; khi có model thật sẽ tách thành các scene .tscn riêng.

const PlayerScript := preload("res://scripts/player.gd")
const CameraRigScript := preload("res://scripts/camera_rig.gd")
const DogScript := preload("res://scripts/dog.gd")
const HudScript := preload("res://scripts/hud.gd")

## 5 đơn theo bản đồ trong sổ phác thảo. "time" là số giây được phép sau khi nhận bánh.
const ORDERS := [
	{"who": "Chú Tư", "place": "Sạp báo", "item": "1 ổ pate", "pos": Vector3(-1, 0, -6), "time": 18.0, "color": Color("#3D5A80")},
	{"who": "Bé Na", "place": "Chung cư", "item": "2 ổ trứng", "pos": Vector3(21, 0, -16), "time": 24.0, "color": Color("#D7A9C4")},
	{"who": "Chị Mây", "place": "Cà phê Mây", "item": "2 ổ thịt nguội", "pos": Vector3(4, 0, 6), "time": 20.0, "color": Color("#7FB7A4")},
	{"who": "Anh Hùng", "place": "Sửa xe", "item": "3 ổ xíu mại", "pos": Vector3(32, 0, 25), "time": 30.0, "color": Color("#5E6F6C")},
	{"who": "Bà Sáu", "place": "Nhà bông giấy", "item": "1 ổ chả cá", "pos": Vector3(-19.5, 0, 22), "time": 24.0, "color": Color("#C8412F"), "boss": true},
]
const DOG_HOME := Vector3(-18, 0, 15)
const BITE_PENALTY := 3.0

enum State { MENU, PLAY, END }

@export var time_multiplier := 1.0  ## tăng lên nếu thấy đơn quá gấp khi chơi thử

var state := State.MENU
var order_index := 0
var time_left := 0.0
var results: Array = []  # số sao từng đơn, 0 là trễ
var result_notes: Array = []  # ghi chú từng đơn cho màn kết quả ("dư 6 giây", "trễ"...)
var carry_time := 0.0  # số giây đã mang bánh, để tính bánh còn nóng hay nguội
var bites := 0  # số lần bị Chó Mực đớp trong đơn hiện tại

var player: CharacterBody3D
var rig: Node3D
var dog: CharacterBody3D
var hud: CanvasLayer
var bakery_zone: Area3D
var customer_zones: Array[Area3D] = []
var arrow: Node3D
var beacon: MeshInstance3D

var _autotest := false
var _autotest_frames := 0
var _bitten := false
var _dog_states: Array[int] = []  # autotest: các trạng thái Chó Mực đã đi qua


func _ready() -> void:
	_setup_input()
	_setup_environment()
	City.build(self)
	_build_bakery()
	_build_customers()
	Blocks.merge_static(self)  # gộp khối tĩnh để giảm lệnh vẽ, phải gọi trước khi thêm mèo, chó

	player = PlayerScript.new()
	player.name = "Bo"
	player.position = City.BAKERY_POINT + Vector3(0, 0.1, 2.5)
	add_child(player)

	rig = CameraRigScript.new()
	rig.name = "CameraRig"
	rig.target = player
	rig.yaw = 0.0  # camera phía nam nhìn lên, thấy mặt tiền lò bánh
	add_child(rig)
	player.camera_rig = rig

	dog = DogScript.new()
	dog.name = "ChoMuc"
	dog.position = DOG_HOME
	dog.player = player
	add_child(dog)
	dog.bit_player.connect(_on_dog_bite)
	dog.state_changed.connect(_on_dog_state)

	_build_arrow()

	hud = HudScript.new()
	add_child(hud)
	hud.start_pressed.connect(start_game)
	hud.restart_pressed.connect(restart)
	add_child(preload("res://scripts/sound_director.gd").new())  # nhạc và tiếng động
	hud.menu_pressed.connect(_to_menu)

	GameSettings.apply_graphics(get_tree())
	GameSettings.apply_camera(get_tree())
	GameSettings.watch_camera(get_tree())

	# Màn hình chính nằm ở scenes/menu.tscn, nên mở cảnh này là vào chơi luôn.
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	if _autotest:
		print("[autotest] bắt đầu")
	start_game()
	if GameState.from_kitchen and GameState.kitchen_bonus > 0.0:
		# Vừa làm xong màn bếp: đồng hồ mỗi đơn được cộng điểm bếp
		hud.show_toast("Bếp được %d sao: mỗi đơn cộng thêm %d giây!" % [GameState.kitchen_stars, int(GameState.kitchen_bonus)], 3.0)


func _unhandled_input(event: InputEvent) -> void:
	match state:
		State.MENU:
			if event.is_action_pressed("ui_accept"):
				start_game()
		State.END:
			if event.is_action_pressed("ui_accept"):
				restart()
		State.PLAY:
			if event.is_action_pressed("pause"):
				hud.set_pause_info(_pause_info())
				hud.toggle_pause()
			elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func start_game() -> void:
	state = State.PLAY
	order_index = 0
	results.clear()
	result_notes.clear()
	player.carrying = false
	player.can_move = true
	if not _autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.start_screen.visible = false
	hud.show_playing_ui(true)
	hud.set_progress(results)
	hud.show_toast("Chạy tới lò bánh Cô Ba nhận đơn 1!")


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _pause_info() -> String:
	if order_index >= ORDERS.size():
		return ""
	var order: Dictionary = ORDERS[order_index]
	if player.carrying:
		return "Đơn %d/%d · %s · đồng hồ đứng ở 0:%02d" % [order_index + 1, ORDERS.size(), order.who, int(ceil(time_left))]
	return "Đơn %d/%d · đang về lò nhận bánh" % [order_index + 1, ORDERS.size()]


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	if state != State.PLAY:
		return
	if _autotest:
		_autotest_step()
	var order: Dictionary = ORDERS[order_index]
	if not player.carrying:
		if bakery_zone.overlaps_body(player):
			_pick_up(order)
	else:
		time_left -= delta
		carry_time += delta
		if customer_zones[order_index].overlaps_body(player):
			_deliver(order)
		elif time_left <= 0.0:
			_fail(order)
	_update_hud()


func _process(delta: float) -> void:
	# Mũi tên trên đầu mèo xoay về phía mục tiêu
	if state == State.PLAY and order_index < ORDERS.size():
		var goal := _current_goal()
		arrow.visible = true
		arrow.global_position = arrow.global_position.lerp(player.smooth_position() + Vector3.UP * 1.15, 1.0 - exp(-20.0 * delta))
		var flat_goal := Vector3(goal.x, arrow.global_position.y, goal.z)
		if arrow.global_position.distance_to(flat_goal) > 0.5:
			arrow.look_at(flat_goal, Vector3.UP)
		arrow.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.06)
		beacon.visible = true
		beacon.global_position = Vector3(goal.x, 15, goal.z)
	else:
		arrow.visible = false
		beacon.visible = false


func _current_goal() -> Vector3:
	return ORDERS[order_index].pos if player.carrying else City.BAKERY_POINT


func _pick_up(order: Dictionary) -> void:
	player.carrying = true
	time_left = _time_limit(order)
	carry_time = 0.0
	bites = 0
	dog.awake = order.get("boss", false)
	hud.show_toast("Nhận %s! Giao cho %s ở %s" % [order.item, order.who, order.place])
	if dog.awake:
		hud.show_toast("Nhận %s! Coi chừng Chó Mực canh hẻm!" % order.item, 2.5)


## Thời gian cho một đơn: số giây gốc nhân hệ số, cộng điểm màn bếp (0–6 giây).
func _time_limit(order: Dictionary) -> float:
	return order.time * time_multiplier + GameState.kitchen_bonus


func _deliver(order: Dictionary) -> void:
	var ratio: float = time_left / _time_limit(order)
	var stars: int = 3 if ratio >= 0.5 else (2 if ratio >= 0.25 else 1)
	results.append(stars)
	var note := "dư %d giây" % int(ceil(time_left))
	if order.get("boss", false):
		note = "qua mặt Chó Mực" + (", bị đớp %d lần" % bites if bites > 0 else "")
	result_notes.append(note)
	hud.show_toast("Giao xong cho %s! %d sao" % [order.who, stars])
	_next_order()


func _fail(order: Dictionary) -> void:
	results.append(0)
	result_notes.append("hết giờ")
	hud.show_toast("Trễ đơn của %s rồi! Quay về lò nhận đơn tiếp." % order.who, 2.5)
	_next_order()


func _next_order() -> void:
	player.carrying = false
	dog.awake = false
	order_index += 1
	hud.set_progress(results)
	if order_index >= ORDERS.size():
		_end_game()


func _end_game() -> void:
	state = State.END
	player.can_move = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var rows := []
	var total := 0
	for i in ORDERS.size():
		var s: int = results[i]
		total += s
		rows.append({"who": ORDERS[i].who, "place": ORDERS[i].place, "item": ORDERS[i].item,
			"color": ORDERS[i].color, "stars": s, "note": result_notes[i]})
	hud.show_results(rows)
	_save_record(total)
	print("[ket qua] ", results, " tong ", total)
	if _autotest:
		# Chó Mực phải đi đúng: nghe tiếng thì nghi ngờ, còn tiếng thì đuổi, rồi đớp
		# (phần mệt về ổ thử riêng trong tools/dog_test.gd)
		var dog_ok := _dog_states.slice(0, 3) == [dog.State.SUSPICIOUS, dog.State.CHASE, dog.State.BITE]
		print("[autotest] Chó Mực: ", _dog_states.map(func(s): return dog.STATE_NAMES[s]))
		var ok := results.size() == 5 and results.all(func(s): return s > 0) and _bitten and dog_ok
		print("AUTOTEST ", "OK" if ok else "FAIL")
		get_tree().quit(0 if ok else 1)


## Lưu kỷ lục sao để màn hình chính hiện.
func _save_record(total: int) -> void:
	var cf := ConfigFile.new()
	cf.load("user://ky_luc.cfg")
	if total > int(cf.get_value("ky_luc", "sao", -1)):
		cf.set_value("ky_luc", "sao", total)
		cf.save("user://ky_luc.cfg")


func _on_dog_bite() -> void:
	_bitten = true
	bites += 1
	time_left = maxf(time_left - BITE_PENALTY, 0.1)
	player.knockback(dog.global_position)
	hud.show_toast("Chó Mực đớp mất %d giây!" % int(BITE_PENALTY))


func _on_dog_state(s: int) -> void:
	_dog_states.append(s)
	if s == dog.State.CHASE:
		hud.show_toast("Chó Mực thức rồi! Chạy nhanh hoặc nhảy lên chỗ cao!", 2.0)


func _update_hud() -> void:
	if order_index >= ORDERS.size():
		return
	var order: Dictionary = ORDERS[order_index]
	if player.carrying:
		hud.set_order(order_index, ORDERS.size(), "%s · %s" % [order.who, order.place], order.item, order.color)
		hud.set_timer(time_left, _time_limit(order), true)
		hud.set_distance(player.global_position.distance_to(order.pos), order.place)
		hud.set_goal(order.pos + Vector3.UP)
		hud.set_bread(true, order.item, 1.0 - carry_time / 45.0)  # nguội hẳn sau 45 giây
	else:
		hud.set_order(order_index, ORDERS.size(), "Lò bánh Cô Ba", "Tới lò nhận " + order.item, Color("#D98E2B"), "B")
		hud.set_timer(0, 1, false)
		hud.set_distance(player.global_position.distance_to(City.BAKERY_POINT), "Lò bánh Cô Ba")
		hud.set_goal(City.BAKERY_POINT + Vector3.UP)
		hud.set_bread(false)


# ---------------------------------------------------------------- dựng cảnh

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#6FAFD0")
	sky_mat.sky_horizon_color = Color("#F2D9A6")
	sky_mat.ground_horizon_color = Color("#F2D9A6")
	sky_mat.ground_bottom_color = Color("#8F8B80")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#BFD3DA")
	# Bản web chạy renderer Compatibility (WebGL), cùng thông số thì sáng chói hơn hẳn Forward+,
	# nên giảm sáng và bỏ filmic để hai bản nhìn gần giống nhau.
	var compat := RenderingServer.get_rendering_device() == null
	env.ambient_light_energy = 0.3 if compat else 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR if compat else Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.fog_enabled = false
	env.fog_light_color = Color("#F2D9A6")
	env.fog_density = 0.006
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)  # nắng sáng sớm, bóng dài
	sun.light_color = Color("#FFE8C4")
	sun.light_energy = 0.55 if compat else 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 35.0  # bóng ở xa không cần, đỡ tốn
	add_child(sun)


func _build_bakery() -> void:
	var p := City.BAKERY_POINT
	# Xe/tủ kính bánh mì trước lò
	var cart := Blocks.solid_box(self, Vector3(1.6, 0.9, 0.7), Vector3(p.x + 2.4, 0.45, p.z - 0.2), Color("#2E7C80"), Blocks.LAYER_PROP)
	Blocks.box(cart, Vector3(1.5, 0.5, 0.6), Vector3(0, 0.7, 0), Color(0.75, 0.9, 0.91, 0.5))
	var loaf := CapsuleMesh.new()
	loaf.radius = 0.07
	loaf.height = 0.4
	for i in 3:
		loaf.radial_segments = 8
		loaf.rings = 2
		var m := Blocks.mesh(cart, loaf, Vector3(-0.45 + i * 0.45, 0.55, 0), Color("#D98E2B"))
		m.rotation_degrees.z = 90
	# Cô Ba đứng sau tủ
	_person(Vector3(p.x + 2.4, 0, p.z - 1.0), Color("#C8412F"), "Cô Ba")
	Blocks.label(self, "LÒ BÁNH CÔ BA", Vector3(p.x, 4.2, p.z - 1.0), 96, Color("#D98E2B"))
	bakery_zone = _zone(p, 1.8)
	# Vòng tròn đánh dấu chỗ nhận bánh
	_ring(p, Color("#D98E2B"))


func _build_customers() -> void:
	for i in ORDERS.size():
		var o: Dictionary = ORDERS[i]
		_person(o.pos + Vector3(0, 0, 0), o.color, "%d. %s\n%s" % [i + 1, o.who, o.place])
		customer_zones.append(_zone(o.pos, 1.6))
		_ring(o.pos, Color("#C8412F"))


## Người khối tạm: thân hộp, đầu cầu, cao khoảng 1,6 m (to gần 3 lần mèo Bơ)
func _person(pos: Vector3, shirt: Color, title: String) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Blocks.LAYER_PROP
	body.position = pos
	add_child(body)
	Blocks.box(body, Vector3(0.45, 0.8, 0.3), Vector3(0, 0.4, 0), Color("#3D4A4A"))     # quần
	Blocks.box(body, Vector3(0.5, 0.6, 0.32), Vector3(0, 1.1, 0), shirt)                # áo
	var head := SphereMesh.new()
	head.radius = 0.17
	head.height = 0.34
	head.radial_segments = 10
	head.rings = 5
	Blocks.mesh(body, head, Vector3(0, 1.58, 0), Color("#E7B98F"))
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 1.6, 0.35)
	shape.shape = bs
	shape.position.y = 0.8
	body.add_child(shape)
	Blocks.label(body, title, Vector3(0, 2.2, 0), 40)


func _zone(pos: Vector3, radius: float) -> Area3D:
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2  # chỉ phát hiện mèo
	var shape := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = 3.0
	shape.shape = s
	shape.position.y = 1.0
	area.add_child(shape)
	add_child(area)
	return area


func _ring(pos: Vector3, color: Color) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 1.25
	torus.outer_radius = 1.45
	torus.rings = 32
	torus.ring_segments = 4
	Blocks.mesh(self, torus, pos + Vector3(0, 0.05, 0), color, true)


func _build_arrow() -> void:
	arrow = Node3D.new()
	arrow.name = "MuiTen"
	add_child(arrow)
	var red := Color("#C8412F")
	Blocks.box(arrow, Vector3(0.12, 0.06, 0.35), Vector3(0, 0, 0.05), red)
	var head := PrismMesh.new()
	head.size = Vector3(0.32, 0.28, 0.06)
	var h := Blocks.mesh(arrow, head, Vector3(0, 0, -0.25), red)
	h.rotation.x = -PI / 2  # đỉnh tam giác chỉ về -Z, hướng look_at()
	# Cột sáng ở mục tiêu, nhìn thấy từ xa
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 30.0
	cyl.radial_segments = 12
	cyl.rings = 1
	beacon = Blocks.mesh(self, cyl, Vector3.ZERO, Color(1.0, 0.85, 0.4, 0.28), true)
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Phím điều khiển được khai báo bằng code để mở project là chơi được ngay.
## Muốn đổi phím: sửa ở đây, hoặc vào Project > Project Settings > Input Map.
func _setup_input() -> void:
	_action("move_forward", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_action("move_back", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_action("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("jump", [KEY_SPACE], [JOY_BUTTON_A], [])
	_action("sprint", [KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_X], [])
	_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START], [])
	_action("cam_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_action("cam_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_action("cam_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_action("cam_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]])


func _action(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(action, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(action, e)


# ---------------------------------------------------------------- tự kiểm tra

## Chạy: godot --headless -- --autotest
## Mèo tự "dịch chuyển" tới lò rồi tới khách, ghé qua Chó Mực ở đơn 5 để thử bị đớp.
func _autotest_step() -> void:
	_autotest_frames += 1
	if _autotest_frames % 20 != 0:
		return
	rig.first_person = not rig.first_person  # thử đổi góc nhìn liên tục
	var goal := _current_goal()
	if player.carrying and ORDERS[order_index].get("boss", false) and not _bitten:
		goal = dog.global_position + Vector3(0.3, 0, 0.3)
		dog.hear(goal, 10.0)  # giả tiếng chạy nhanh sát ổ: Mực nghi ngờ rồi đuổi
	player.global_position = goal + Vector3(0, 0.2, 0)
	player.velocity = Vector3.ZERO
