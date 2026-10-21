extends Node3D
## Màn chơi thử: dựng khu phố, mèo, camera, Chó Mực, khách, HUD và vòng giao 5 đơn.
## Toàn bộ dựng bằng code cho bản khối thô; khi có model thật sẽ tách thành các scene .tscn riêng.

const PlayerScript := preload("res://scripts/player.gd")
const CameraRigScript := preload("res://scripts/camera_rig.gd")
const DogScript := preload("res://scripts/dog.gd")
const HudScript := preload("res://scripts/hud.gd")
const DeliveriesScript := preload("res://scripts/deliveries.gd")
const StampsScript := preload("res://scripts/stamps.gd")
const GhostScript := preload("res://scripts/ghost.gd")

## 5 đơn theo bản đồ trong sổ phác thảo. "time" là số giây được phép sau khi nhận bánh.
## "delivery": cách giao (hand | basket | counter | under_car | chair), "side_quest": nhiệm vụ phụ,
## cả hai xử lý trong scripts/deliveries.gd.
const ORDERS := [
	{"who": "Chú Tư", "place": "Sạp báo", "item": "1 ổ pate", "pos": Vector3(-1, 0, -6), "time": 18.0, "color": Color("#3D5A80"), "delivery": "hand", "side_quest": "bao_co_ba"},
	{"who": "Bé Na", "place": "Chung cư", "item": "2 ổ trứng", "pos": Vector3(24.0, 0, -15.6), "time": 24.0, "color": Color("#D7A9C4"), "delivery": "basket", "side_quest": "gio_nhip_dau"},
	{"who": "Chị Mây", "place": "Cà phê Mây", "item": "2 ổ thịt nguội", "pos": Vector3(5.4, 0, 5.4), "time": 20.0, "color": Color("#7FB7A4"), "delivery": "counter", "side_quest": "khong_do_ly"},
	{"who": "Anh Hùng", "place": "Sửa xe", "item": "3 ổ xíu mại", "pos": Vector3(30.6, 0, 25.3), "time": 30.0, "color": Color("#5E6F6C"), "delivery": "under_car", "side_quest": "khong_dau"},
	{"who": "Bà Sáu", "place": "Nhà bông giấy", "item": "1 ổ chả cá", "pos": Vector3(-19.5, 0, 22), "time": 24.0, "color": Color("#C8412F"), "delivery": "chair", "side_quest": "muc_ngu_yen", "boss": true},
]
const DOG_HOME := Vector3(-18, 0, 15)
const BITE_PENALTY := 3.0
## Rơi từ cao hơn mức này khi đang mang bánh thì mất sao nguyên vẹn.
const FALL_BREAK_HEIGHT := 3.0

enum State { MENU, PLAY, END }

@export var time_multiplier := 1.0  ## tăng lên nếu thấy đơn quá gấp khi chơi thử

var state := State.MENU
var order_index := 0
var time_left := 0.0
var results: Array = []  # số sao từng đơn (trễ vẫn được 1 sao)
var score_rows: Array = []  # kết quả chấm từng đơn từ Scoring.order_done
var result_notes: Array = []  # ghi chú từng đơn cho màn kết quả ("dư 6 giây", "trễ"...)
var carry_time := 0.0  # số giây đã mang bánh, để tính bánh còn nóng hay nguội
var bites := 0  # số lần bị Chó Mực đớp trong đơn hiện tại
var late := false  # đồng hồ đơn hiện tại đã về 0, khách vẫn nhận nhưng chỉ 1 sao
var intact := true  # bánh nguyên vẹn: chưa bị đớp, chưa rơi từ trên 3 m
## Nhiệm vụ phụ của đơn hiện tại đã đạt chưa; luồng giao bánh (deliveries.gd) đặt biến này.
var side_quest_ok := false
var _air_top := 0.0  # độ cao cao nhất từ lúc rời đất, để đo cú rơi
var _was_on_floor := true
var _ghost_path := PackedVector3Array()  # đường chạy đơn hiện tại, 10 điểm mỗi giây
var _ghost_clock := 0.0

var player: CharacterBody3D
var rig: Node3D
var dog: CharacterBody3D
var hud: CanvasLayer
var bakery_zone: Area3D
var customer_zones: Array[Area3D] = []
var arrow: Node3D
var beacon: MeshInstance3D
var deliveries: Node3D
var stamps: Node3D
var ghost: Node3D

var _autotest := false
var _autotest_frames := 0
var _bitten := false
var _dog_states: Array[int] = []  # autotest: các trạng thái Chó Mực đã đi qua


func _ready() -> void:
	_setup_input()
	_setup_environment()
	City.build(self)
	_build_bakery()
	deliveries = DeliveriesScript.new()
	deliveries.name = "Deliveries"
	deliveries.build_static(self, ORDERS)  # người dân, ghế, xe, quầy... đứng yên nên được gộp
	_build_customers()
	Blocks.merge_static(self, 24.0)  # gộp khối tĩnh (model nhà theo ô 24 m) để giảm lệnh vẽ, phải gọi trước khi thêm mèo, chó
	add_child(deliveries)  # phần chuyển động (giỏ, ly, tay, tờ báo) thêm sau khi gộp

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
	add_child(preload("res://scripts/traffic.gd").new())  # xe máy, đèn giao thông, người đi bộ

	stamps = StampsScript.new()
	stamps.name = "TemCoBa"
	stamps.player = player
	add_child(stamps)
	stamps.collected.connect(_on_stamp)
	ghost = GhostScript.new()
	ghost.name = "BongMo"
	add_child(ghost)

	_build_arrow()

	hud = HudScript.new()
	add_child(hud)
	hud.start_pressed.connect(start_game)
	hud.restart_pressed.connect(restart)
	add_child(preload("res://scripts/sound_director.gd").new())  # nhạc và tiếng động
	add_child(FirstHints.new())  # mẹo lần đầu: gầm thấp, gần Chó Mực, tới khách
	hud.menu_pressed.connect(_to_menu)
	deliveries.setup(player, dog, hud, "--autotest" in OS.get_cmdline_user_args())

	GameSettings.apply_graphics(get_tree())
	GameSettings.apply_camera(get_tree())
	GameSettings.watch_camera(get_tree())

	# Màn hình chính nằm ở scenes/menu.tscn, nên mở cảnh này là vào chơi luôn.
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	if _autotest:
		print("[autotest] bắt đầu")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--don="):  # vào thẳng một đơn khi thử: -- --autotest --don=5
			PlayMode.mode = PlayMode.Mode.ORDER
			PlayMode.order = clampi(int(arg.substr(6)) - 1, 0, ORDERS.size() - 1)
	start_game()
	if GameState.from_kitchen and not GameState.kitchen_stars_per_bread.is_empty():
		hud.show_toast("Ổ nào được 3 sao bếp thì đơn đó cộng thêm %d giây!" % int(Scoring.KITCHEN_BONUS_SECONDS), 3.0)
	elif GameState.from_kitchen and GameState.kitchen_bonus > 0.0:
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
	order_index = PlayMode.first_order()  # màn Chọn màn có thể cho vào thẳng một đơn
	results.clear()
	result_notes.clear()
	score_rows.clear()
	if _autotest:
		GameState.use_test_save("user://luu_game_autotest.cfg")
	Scoring.begin_day("thu_hai")
	player.carrying = false
	player.can_move = true
	if not _autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.start_screen.visible = false
	hud.show_playing_ui(true)
	_show_progress()
	hud.show_toast("Chạy tới lò bánh Cô Ba nhận đơn %d!" % (order_index + 1))


func _to_menu() -> void:
	PlayMode.back_to_menu(get_tree())


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
		time_left = maxf(time_left - delta, 0.0)
		carry_time += delta
		_track_fall()
		_record_ghost(delta)
		if deliveries.step(order_index, customer_zones[order_index].overlaps_body(player), delta):
			_deliver(order)
		elif time_left <= 0.0 and not late:
			_go_late(order)
	stamps.set_active(not player.carrying)
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
	late = false
	intact = true
	side_quest_ok = false
	_air_top = player.global_position.y
	_ghost_path = PackedVector3Array([player.global_position])
	_ghost_clock = 0.0
	ghost.play(Scoring.best_ghost(order_index))
	dog.awake = order.get("boss", false)
	deliveries.on_pick_up(order_index)
	hud.show_toast("Nhận %s! Giao cho %s ở %s" % [order.item, order.who, order.place])
	if dog.awake:
		hud.show_toast("Nhận %s! Coi chừng Chó Mực canh hẻm!" % order.item, 2.5)


## Thời gian cho một đơn: số giây gốc nhân hệ số, cộng giây thưởng của ổ bánh từ màn bếp.
func _time_limit(order: Dictionary) -> float:
	return order.time * time_multiplier + Scoring.bonus_seconds(order_index)


func _deliver(order: Dictionary) -> void:
	_ghost_path.append(player.global_position)
	side_quest_ok = deliveries.side_ok[order_index]
	var r := Scoring.order_done(order_index, {
		"time_ratio": 0.0 if late else time_left / _time_limit(order),
		"late": late,
		"intact": intact and not deliveries.star_lost(order_index),  # góc cờ: bị mắng thì mất 1 sao
		"kitchen_star": Scoring.kitchen_star_for(order_index),
		"side_quest": order.get("side_quest", ""),
		"side_quest_ok": side_quest_ok,
		"time": carry_time,
	})
	Scoring.set_ghost(order_index, _ghost_path)
	score_rows.append(r)
	results.append(r.stars)
	var note := "trễ giờ" if late else "dư %d giây" % int(ceil(time_left))
	if order.get("boss", false):
		note = "qua mặt Chó Mực" + (", bị đớp %d lần" % bites if bites > 0 else "")
	elif not intact:
		note += ", bánh bị dập"
	if deliveries.star_lost(order_index):
		note += ", bị hai ông mắng"
	result_notes.append(note)
	if late:
		hud.show_toast("Giao trễ cho %s: 1 sao, không có tiền boa." % order.who, 2.5)
	else:
		var extra := " · kỷ lục mới!" if r.new_best and r.best_time >= 0.0 else ""
		hud.show_toast("Giao xong cho %s! %d sao · boa %s%s" % [order.who, r.stars, _money(r.tip), extra])
	_next_order()


## Hết giờ: không thua, Bơ vẫn chạy tới khách để giao trễ.
func _go_late(order: Dictionary) -> void:
	late = true
	hud.show_toast("Hết giờ rồi! Vẫn mang bánh tới %s nhé, giao trễ được 1 sao." % order.who, 2.5)


## Đo cú rơi khi mang bánh: rơi từ trên 3 m thì bánh bị dập.
func _track_fall() -> void:
	var on_floor := player.is_on_floor()
	var y := player.global_position.y
	if on_floor:
		if not _was_on_floor and _air_top - y > FALL_BREAK_HEIGHT and intact:
			intact = false
			hud.show_toast("Rơi cao quá, bánh bị dập mất rồi!")
		_air_top = y
	else:
		_air_top = maxf(_air_top, y)
	_was_on_floor = on_floor


func _record_ghost(delta: float) -> void:
	_ghost_clock += delta
	while _ghost_clock >= 1.0 / GhostScript.SAMPLE_RATE:
		_ghost_clock -= 1.0 / GhostScript.SAMPLE_RATE
		if _ghost_path.size() < 1200:  # tối đa 2 phút, file lưu không phình ra khi đi lòng vòng
			_ghost_path.append(player.global_position)


func _on_stamp(_index: int, count: int) -> void:
	hud.show_toast("Tem Cô Ba %d/%d!" % [count, Scoring.STAMPS_PER_DAY])


## 25000 -> "25.000đ"
static func _money(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out + "đ"


func _next_order() -> void:
	player.carrying = false
	dog.awake = false
	ghost.stop()
	order_index += 1
	_show_progress()
	if order_index > PlayMode.last_order(ORDERS.size()):
		_end_game()


## Dãy ổ bánh trên HUD. Chơi một đơn lẻ thì chỉ ổ của đơn đó sáng, các ổ khác để trống.
func _show_progress() -> void:
	if not PlayMode.single_order() or not "dots" in hud:
		hud.set_progress(results)
		return
	for i in hud.dots.size():
		var d: Control = hud.dots[i]
		if i == PlayMode.order:
			d.state = ("done" if results[0] > 0 else "late") if not results.is_empty() else "current"
		else:
			d.state = "todo"
		d.queue_redraw()


## Nhiệm vụ phụ xong sau lúc giao (tờ báo Chú Tư về tới lò ở đơn sau): ghi lại vào kết quả và tiền boa.
func _settle_side_quests() -> void:
	for i in score_rows.size():
		var r: Dictionary = score_rows[i]  # cùng một Dictionary với Scoring.orders[r.index]
		var ok: bool = deliveries.side_ok[r.index] and str(r.side_quest) != ""
		if ok != r.side_ok:
			r.side_ok = ok
			r.tip = Scoring.tip_for(r.stars, r.late, ok)


func _end_game() -> void:
	state = State.END
	player.can_move = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_settle_side_quests()
	var rows := []
	for k in score_rows.size():
		var i: int = score_rows[k].index
		var row := {"who": ORDERS[i].who, "place": ORDERS[i].place, "item": ORDERS[i].item,
			"color": ORDERS[i].color, "stars": results[k], "note": result_notes[k]}
		row.merge(score_rows[k])
		rows.append(row)
	print("[nhiem vu phu] ", deliveries.side_ok)
	var summary: Dictionary
	if PlayMode.single_order():
		# Một đơn lẻ: lưu kỷ lục đơn, không tính vào kỷ lục cả ngày
		summary = Scoring.end_practice()
		summary.day = "%s · đơn %d" % [summary.day, order_index]
		summary.rows_title = "Đơn %d · %s" % [order_index, ORDERS[order_index - 1].who]
	else:
		summary = Scoring.end_day(ORDERS.size() * Scoring.STARS_PER_ORDER)
	# Bảng kết quả mới (luồng Giao diện) nhận thêm summary; bản cũ chỉ nhận rows.
	if hud.get_method_argument_count("show_results") >= 2:
		hud.show_results(rows, summary)
	else:
		hud.show_results(rows)
	print("[ket qua] ", results, " tong ", summary.stars, " boa ", summary.tip, " hang ", summary.rank, " tem ", summary.stamps)
	if _autotest and PlayMode.single_order():
		# Một đơn lẻ (-- --autotest --don=N): giao được, lưu sao đơn, không đụng kỷ lục cả ngày
		var ok1: bool = results.size() == 1 and results[0] > 0 and Scoring.best_stars(PlayMode.order) == results[0]
		ok1 = ok1 and GameState.get_day("so_lan_choi", 0) == 0 and int(GameState.get_day("sao_cao_nhat", -1)) == -1
		print("AUTOTEST DON ", PlayMode.order + 1, " ", "OK" if ok1 else "FAIL")
		get_tree().quit(0 if ok1 else 1)
	elif _autotest:
		# Chó Mực phải đi đúng: nghe tiếng thì nghi ngờ, còn tiếng thì đuổi, rồi đớp
		# (phần mệt về ổ thử riêng trong tools/dog_test.gd)
		var dog_ok := _dog_states.slice(0, 3) == [dog.State.SUSPICIOUS, dog.State.CHASE, dog.State.BITE]
		print("[autotest] Chó Mực: ", _dog_states.map(func(s): return dog.STATE_NAMES[s]))
		var ok := results.size() == 5 and results.all(func(s): return s > 0) and _bitten and dog_ok
		ok = ok and summary.tip > 0 and summary.stamps >= 1 and Scoring.self_test()
		ok = ok and GameState.get_day("so_lan_choi", 0) == 1 and Scoring.best_time(0) > 0.0
		# Autotest bị Chó Mực đớp ở đơn 5 nên nhiệm vụ phụ đơn đó trượt; 4 đơn đầu phải đạt cả
		ok = ok and deliveries.side_ok.slice(0, 4).all(func(v): return v) and score_rows[0].side_ok
		print("AUTOTEST ", "OK" if ok else "FAIL")
		get_tree().quit(0 if ok else 1)


func _on_dog_bite() -> void:
	_bitten = true
	bites += 1
	intact = false
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
	if "stance" in player:  # dáng rón rén/chui do luồng động tác của Bơ thêm vào player.gd
		hud.set_stance(player.stance)
	var order: Dictionary = ORDERS[order_index]
	if player.carrying:
		hud.set_order(order_index, ORDERS.size(), "%s · %s" % [order.who, order.place], order.item, order.color)
		hud.set_timer(time_left, _time_limit(order), true)
		hud.set_distance(player.global_position.distance_to(order.pos), order.place)
		hud.set_goal(order.pos + Vector3.UP)
		hud.set_bread(true, order.item, 1.0 - carry_time / 45.0)  # nguội hẳn sau 45 giây
		if hud.has_method("set_kitchen_stars"):
			hud.set_kitchen_stars(Scoring.kitchen_star_for(order_index))
	else:
		hud.set_order(order_index, ORDERS.size(), "Lò bánh Cô Ba", "Tới lò nhận " + order.item, Color("#D98E2B"), "B")
		hud.set_timer(0, 1, false)
		hud.set_distance(player.global_position.distance_to(City.BAKERY_POINT), "Lò bánh Cô Ba")
		hud.set_goal(City.BAKERY_POINT + Vector3.UP)
		hud.set_bread(false)
		if hud.has_method("set_kitchen_stars"):
			hud.set_kitchen_stars(-1)


# ---------------------------------------------------------------- dựng cảnh

func _setup_environment() -> void:
	AnhSang.build(self, "pho_sang")  # nắng sớm, trời, sương, bóng đổ: scripts/anh_sang.gd


func _build_bakery() -> void:
	var p := City.BAKERY_POINT
	# Xe tủ kính bánh mì trước lò (model xe_banh_mi, kính cao 1,3 m nên hộp va chạm cao bằng)
	var cart := Blocks.collider(self, Vector3(1.6, 1.3, 0.7), Vector3(p.x + 2.4, 0.65, p.z + 0.2), Blocks.LAYER_PROP)
	PhoModels.put(cart, "xe_banh_mi", Vector3(0, -0.65, 0))
	# Cô Ba đứng sau tủ, cách mặt tiền lò gần nửa mét (mặt tiền ở z = -7, trước đây lưng Cô Ba dính vào cửa cuốn)
	_person(Vector3(p.x + 2.4, 0, p.z - 0.55), Color("#C8412F"), "Cô Ba")
	bakery_zone = _zone(p, 1.8)
	# Vòng tròn đánh dấu chỗ nhận bánh
	_ring(p, Color("#D98E2B"))


func _build_customers() -> void:
	for i in ORDERS.size():
		var o: Dictionary = ORDERS[i]
		# Người dân và đồ giao bánh do deliveries.gd dựng theo từng cách giao
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
	# Ctrl+W đóng tab trên bản web nên có thêm phím C để chui
	_action("crouch", [KEY_CTRL, KEY_C], [JOY_BUTTON_B], [])
	_action("sneak", [KEY_ALT, KEY_Z], [JOY_BUTTON_LEFT_STICK], [])
	_action("deliver", [KEY_E], [JOY_BUTTON_Y], [])
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
	if player.carrying:
		goal = deliveries.stand_point(order_index)
	if player.carrying and ORDERS[order_index].get("boss", false) and not _bitten:
		goal = dog.global_position + Vector3(0.3, 0, 0.3)
		dog.hear(goal, 10.0)  # giả tiếng chạy nhanh sát ổ: Mực nghi ngờ rồi đuổi
	elif not player.carrying and order_index == 1 and Scoring.stamps_today.is_empty() and not stamps.remaining().is_empty():
		goal = stamps.remaining()[0] - Vector3(0, 0.2, 0)  # trên đường về lò ghé nhặt một con tem
	player.global_position = goal + Vector3(0, 0.2, 0)
	player.velocity = Vector3.ZERO
