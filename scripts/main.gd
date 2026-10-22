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
const ResidentsScript := preload("res://scripts/residents.gd")

## Đơn của ngày đang chơi lấy từ scripts/days.gd (Days.get_day(PlayMode.day)), khóa của đơn ghi ở đó.
## "delivery": cách giao, "side_quest": nhiệm vụ phụ, cả hai xử lý trong scripts/deliveries.gd.
## Đơn "kind": "errand" chạy ngược: tới chỗ khách lấy đồ (đồng hồ chạy từ đó) rồi mang về lò.
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

## Ngày đang chơi (Days.get_day) và danh sách đơn của ngày đó
var day: Dictionary
var orders: Array = []

## Nhận đồ (ở lò, hoặc ở chỗ khách với đơn errand) và giao xong một đơn. Các gói ngày sau móc vào đây.
signal order_picked_up(index: int, order: Dictionary)
signal order_delivered(index: int, order: Dictionary)

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
var residents: Node3D  ## Cô Ba ở quầy và hàng xóm (scripts/residents.gd)

## Tiến độ ngày cất lại khi sang bếp ráp nhanh ổ trứng giữa ca (Thứ Hai đơn 2 xong), main.tscn nạp lại thì lấy ra.
## Biến static nên còn nguyên khi đổi scene. Hợp đồng: thiet-ke-man/hop-dong-bep-thu-ba.md.
static var _resume := {}
var _leaving := false  # đang chờ đổi sang bếp ráp nhanh

## Một đơn lẻ đã giao xong nhưng nhiệm vụ phụ còn dở (tờ báo Chú Tư chưa về lò): chờ về lò rồi mới tổng kết.
var _finishing := false

var _autotest := false
var _autotest_frames := 0
var _bitten := false
var _dog_states: Array[int] = []  # autotest: các trạng thái Chó Mực đã đi qua


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ngay="):  # chọn ngày khi thử: -- --autotest --ngay=thu_ba
			PlayMode.day = arg.substr(7)
	day = Days.get_day(PlayMode.day)
	orders = day.orders
	_setup_input()
	_setup_environment()
	City.build(self)
	_build_bakery()
	deliveries = DeliveriesScript.new()
	deliveries.name = "Deliveries"
	deliveries.build_static(self, orders)  # người dân, ghế, xe, quầy... đứng yên nên được gộp
	_build_customers()
	Blocks.merge_static(self, 24.0)  # gộp khối tĩnh (model nhà theo ô 24 m) để giảm lệnh vẽ, phải gọi trước khi thêm mèo, chó
	add_child(deliveries)  # phần chuyển động (giỏ, ly, người dân có xương, tờ báo) thêm sau khi gộp
	residents = ResidentsScript.new()
	residents.name = "NguoiDan"
	residents.set_orders(orders)
	add_child(residents)

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
	residents.setup(player)

	dog = DogScript.new()
	dog.name = "ChoMuc"
	dog.position = DOG_HOME
	dog.player = player
	add_child(dog)
	dog.bit_player.connect(_on_dog_bite)
	dog.state_changed.connect(_on_dog_state)
	add_child(preload("res://scripts/traffic.gd").new())  # xe máy, đèn giao thông, người đi bộ
	add_child(preload("res://scripts/market.gd").new())  # chợ sáng Thứ Ba (ngày khác tự gỡ)

	stamps = StampsScript.new()
	stamps.name = "TemCoBa"
	stamps.player = player
	add_child(stamps)
	stamps.collected.connect(_on_stamp)
	ghost = GhostScript.new()
	ghost.name = "BongMo"
	ghost.player = player
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
			PlayMode.order = clampi(int(arg.substr(6)) - 1, 0, orders.size() - 1)
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
	if GameState.from_quick_assemble and not _resume.is_empty():
		_resume_after_kitchen()
		return
	GameState.from_quick_assemble = false
	_resume = {}
	order_index = PlayMode.first_order()  # màn Chọn màn có thể cho vào thẳng một đơn
	results.clear()
	result_notes.clear()
	score_rows.clear()
	if _autotest:
		GameState.use_test_save("user://luu_game_autotest.cfg")
	Scoring.begin_day(day.id)
	player.carrying = false
	player.can_move = true
	if not _autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.start_screen.visible = false
	hud.show_playing_ui(true)
	_show_progress()
	if day.intro != "" and order_index == 0 and not _autotest:
		if hud.has_method("show_day_card"):  # thẻ mở đầu ngày của luồng Giao diện
			var lines: Array[String] = []
			for o in orders:
				lines.append("%s · %s" % [o.who, _item_text(o)])
			hud.show_day_card("%s · %s" % [day.name, day.title], day.intro, lines)
		else:
			hud.show_toast(day.intro, 4.0)
	else:
		hud.show_toast("Chạy tới %s nhận đơn %d!" % [_pickup_name(orders[order_index]), order_index + 1])
	residents.greet_shift(PlayMode.last_order(orders.size()) - order_index + 1)


## Ráp nhanh xong quay về: lấy lại tiến độ ngày (Scoring giữ đơn đã chấm trong biến static) và chơi tiếp.
func _resume_after_kitchen() -> void:
	GameState.from_quick_assemble = false
	order_index = _resume.order_index
	results = _resume.results
	result_notes = _resume.result_notes
	score_rows = _resume.score_rows
	var ok: Array = _resume.side_ok
	for i in mini(ok.size(), deliveries.side_ok.size()):
		deliveries.side_ok[i] = ok[i]
	_resume = {}
	player.carrying = false
	player.can_move = true
	if not _autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.start_screen.visible = false
	hud.show_playing_ui(true)
	_show_progress()
	hud.show_toast("Ổ trứng ráp xong! Tới lò nhận bánh đơn %d." % (order_index + 1), 3.0)


## Đơn mua trứng vừa về lò và còn đơn sau: cất tiến độ, sang bếp ráp gấp ổ trứng cho đơn kế.
func _go_quick_assemble() -> void:
	_resume = {"order_index": order_index, "results": results.duplicate(), "result_notes": result_notes.duplicate(),
		"score_rows": score_rows.duplicate(), "side_ok": deliveries.side_ok.duplicate()}
	GameState.quick_assemble_request = order_index
	player.can_move = false
	_leaving = true
	hud.show_toast("Cô Ba: \"Có trứng rồi! Vô ráp gấp ổ trứng nha Bơ.\"", 2.0)
	get_tree().create_timer(1.2).timeout.connect(func(): get_tree().change_scene_to_file("res://scenes/kitchen.tscn"))


func _to_menu() -> void:
	PlayMode.back_to_menu(get_tree())


func _pause_info() -> String:
	if order_index >= orders.size():
		return ""
	var order: Dictionary = orders[order_index]
	if player.carrying:
		return "Đơn %d/%d · %s · đồng hồ đứng ở 0:%02d" % [order_index + 1, orders.size(), order.who, int(ceil(time_left))]
	return "Đơn %d/%d · đang tới %s" % [order_index + 1, orders.size(), _pickup_name(order)]


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	if state != State.PLAY or _leaving:
		return
	if _autotest:
		_autotest_step()
	if _finishing:
		_update_finishing()
		return
	var order: Dictionary = orders[order_index]
	var errand := _is_errand(order)
	if not player.carrying:
		# Đơn thường nhận bánh ở lò; đơn errand lấy đồ ở chỗ khách
		if (customer_zones[order_index] if errand else bakery_zone).overlaps_body(player):
			_pick_up(order)
	else:
		time_left = maxf(time_left - delta, 0.0)
		carry_time += delta
		_track_fall()
		_record_ghost(delta)
		var done: bool = bakery_zone.overlaps_body(player) if errand else deliveries.step(order_index, customer_zones[order_index].overlaps_body(player), delta)
		if done:
			_deliver(order)
		elif time_left <= 0.0 and not late:
			_go_late(order)
	stamps.set_active(not player.carrying)
	_update_hud()


func _process(delta: float) -> void:
	# Mũi tên trên đầu mèo xoay về phía mục tiêu
	if state == State.PLAY and order_index < orders.size():
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
	if _finishing:
		return City.BAKERY_POINT
	var order: Dictionary = orders[order_index]
	return _drop_point(order) if player.carrying else _pickup_point(order)


## Đơn ngược: tới chỗ khách lấy đồ rồi mang về lò (vd. mua túi trứng ở tạp hóa Cô Hai, Thứ Ba).
static func _is_errand(order: Dictionary) -> bool:
	return order.get("kind", "deliver") == "errand"


func _pickup_point(order: Dictionary) -> Vector3:
	return order.pos if _is_errand(order) else City.BAKERY_POINT


func _drop_point(order: Dictionary) -> Vector3:
	return City.BAKERY_POINT if _is_errand(order) else order.pos


func _pickup_name(order: Dictionary) -> String:
	return "%s ở %s" % [order.who, order.place] if _is_errand(order) else "lò bánh Cô Ba"


## Dòng món trên thẻ đơn, kèm ghi chú món nếu có ("1 ổ thịt nguội · không ớt").
static func _item_text(order: Dictionary) -> String:
	var note: String = order.get("note", "")
	return order.item + (" · " + Days.note_name(note) if note != "" else "")


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
	order_picked_up.emit(order_index, order)
	residents.hand_ticket(order, order_index)
	if _is_errand(order):
		hud.show_toast("%s đưa %s. Mang về lò cho Cô Ba!" % [order.who, order.item])
	else:
		hud.show_toast("Nhận %s! Giao cho %s ở %s" % [_item_text(order), order.who, order.place])
	if dog.awake:
		hud.show_toast("Nhận %s! Coi chừng Chó Mực canh hẻm!" % order.item, 2.5)


## Thời gian cho một đơn: số giây gốc nhân hệ số, cộng giây thưởng của ổ bánh từ màn bếp.
func _time_limit(order: Dictionary) -> float:
	return order.time * time_multiplier * float(day.time_mult) * float(DoKho.v("order_time_mult", 1.0)) + Scoring.bonus_seconds(order_index)


func _deliver(order: Dictionary) -> void:
	_ghost_path.append(player.global_position)
	side_quest_ok = deliveries.side_ok[order_index]
	var r := Scoring.order_done(order_index, {
		"time_ratio": 0.0 if late else time_left / _time_limit(order),
		"late": late,
		# Góc cờ: bị mắng thì mất 1 sao. Ổ ráp sai phiếu ghi món cũng mất sao nguyên vẹn.
		"intact": intact and not deliveries.star_lost(order_index) and _note_ok(order_index),
		"kitchen_star": -1 if _is_errand(order) else Scoring.kitchen_star_for(order_index),  # đơn mua trứng không có ổ bánh
		"side_quest": order.get("side_quest", ""),
		"side_quest_ok": side_quest_ok,
		"time": carry_time,
	})
	Scoring.set_ghost(order_index, _ghost_path)
	score_rows.append(r)
	residents.order_done(r.stars, late)
	results.append(r.stars)
	var note := "trễ giờ" if late else "dư %d giây" % int(ceil(time_left))
	if order.get("boss", false):
		note = "qua mặt Chó Mực" + (", bị đớp %d lần" % bites if bites > 0 else "")
	elif not intact:
		note += ", bánh bị dập"
	if deliveries.star_lost(order_index):
		note += ", bị hai ông mắng"
	result_notes.append(note)
	var to: String = "Cô Ba" if _is_errand(order) else order.who
	if late:
		hud.show_toast("Giao trễ cho %s: 1 sao, không có tiền boa." % to, 2.5)
	else:
		var extra := " · kỷ lục mới!" if r.new_best and r.best_time >= 0.0 else ""
		hud.show_toast("Giao xong cho %s! %d sao · boa %s%s" % [to, r.stars, _money(r.tip), extra])
	order_delivered.emit(order_index, order)
	_next_order()


## Hết giờ: không thua, Bơ vẫn chạy tới khách để giao trễ.
func _go_late(order: Dictionary) -> void:
	late = true
	deliveries.on_late(order_index)  # khách đứng sốt ruột chờ
	var to: String = "lò cho Cô Ba" if _is_errand(order) else order.who
	hud.show_toast("Hết giờ rồi! Vẫn mang tới %s nhé, giao trễ được 1 sao." % to, 2.5)


## Đo cú rơi khi mang bánh: rơi từ trên 3 m thì bánh bị dập.
func _track_fall() -> void:
	var on_floor := player.is_on_floor()
	var y := player.global_position.y
	if on_floor:
		# Đơn mua trứng tính vỡ trứng riêng (ShopTapHoa), không có ổ bánh để dập
		if not _was_on_floor and _air_top - y > float(DoKho.v("fall_break_height", FALL_BREAK_HEIGHT)) and intact and not _is_errand(orders[order_index]):
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
	var prev: Dictionary = orders[order_index - 1]
	if order_index <= PlayMode.last_order(orders.size()) and prev.get("errand_item", "") == "trung6" and ResourceLoader.exists(PlayMode.KITCHEN_SCENE):
		_go_quick_assemble()
		return
	if order_index > PlayMode.last_order(orders.size()):
		if PlayMode.single_order() and deliveries.side_pending():
			# Đơn lẻ: cho Bơ mang nốt tờ báo về lò rồi mới tổng kết
			_finishing = true
			hud.show_toast("Còn nhiệm vụ phụ: %s!" % deliveries.quest_title(order_index - 1), 3.0)
		else:
			_end_game()


## Chờ nhiệm vụ phụ còn dở của đơn lẻ xong (hoặc hỏng) rồi tổng kết.
func _update_finishing() -> void:
	hud.set_timer(0, 1, false)
	hud.set_distance(player.global_position.distance_to(City.BAKERY_POINT), "Lò bánh Cô Ba")
	hud.set_goal(City.BAKERY_POINT + Vector3.UP)
	if not deliveries.side_pending():
		_finishing = false
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
		var row := {"who": orders[i].who, "place": orders[i].place, "item": orders[i].item,
			"color": orders[i].color, "stars": results[k], "note": result_notes[k]}
		row.merge(score_rows[k])
		rows.append(row)
	print("[nhiem vu phu] ", deliveries.side_ok)
	var summary: Dictionary
	if PlayMode.single_order():
		# Một đơn lẻ: lưu kỷ lục đơn, không tính vào kỷ lục cả ngày
		summary = Scoring.end_practice()
		summary.day = "%s · đơn %d" % [summary.day, order_index]
		summary.rows_title = "Đơn %d · %s" % [order_index, orders[order_index - 1].who]
	else:
		summary = Scoring.end_day(orders.size() * Scoring.STARS_PER_ORDER)
	residents.day_summary(summary.stars, summary.get("stars_max", results.size() * Scoring.STARS_PER_ORDER), _money(summary.tip))
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
		if day.id == "thu_hai" and PlayMode.order == 0:
			ok1 = ok1 and score_rows[0].side_ok  # tờ báo Chú Tư phải về tới lò dù chơi lẻ
		print("AUTOTEST DON ", PlayMode.order + 1, " ", "OK" if ok1 else "FAIL")
		get_tree().quit(0 if ok1 else 1)
	elif _autotest and day.id != "thu_hai":
		# Ngày khác (-- --autotest --ngay=thu_ba): đủ 5 đơn, có boa, lưu đúng mục của ngày
		var ok2: bool = results.size() == orders.size() and results.all(func(s): return s > 0) and summary.tip > 0
		ok2 = ok2 and GameState.get_day("so_lan_choi", 0) == 1 and GameState.get_day("so_lan_choi", 0, "thu_hai") == 0
		print("AUTOTEST ", day.id.to_upper(), " ", "OK" if ok2 else "FAIL")
		get_tree().quit(0 if ok2 else 1)
	elif _autotest:
		# Chó Mực phải đi đúng: nghe tiếng thì nghi ngờ, còn tiếng thì đuổi, rồi đớp
		# (phần mệt về ổ thử riêng trong tools/dog_test.gd)
		var dog_ok := _dog_states.slice(0, 3) == [dog.State.SUSPICIOUS, dog.State.CHASE, dog.State.BITE]
		print("[autotest] Chó Mực: ", _dog_states.map(func(s): return dog.STATE_NAMES[s]))
		var ok := results.size() == 5 and results.all(func(s): return s > 0) and _bitten and dog_ok
		ok = ok and summary.tip > 0 and summary.stamps >= 1 and Scoring.self_test()
		ok = ok and Shop.total_stars() == summary.stars and Shop.self_test() and hud.self_test_menu()
		# Mèo cái chưa xuất model thì dùng bản đực, không được rơi về Bơ
		ok = ok and (OutfitView.has_sex_model("muop", "cai") or OutfitView.breed_scene("muop", "cai") == OutfitView.breed_scene("muop", "duc"))
		ok = ok and GameState.get_day("so_lan_choi", 0) == 1 and Scoring.best_time(0) > 0.0
		# Autotest bị Chó Mực đớp ở đơn 5 nên nhiệm vụ phụ đơn đó trượt; 4 đơn đầu phải đạt cả
		ok = ok and deliveries.side_ok.slice(0, 4).all(func(v): return v) and score_rows[0].side_ok
		if not ok:
			print("AUTOTEST FAIL")
			get_tree().quit(1)
			return
		# Màn giao đạt: chạy tiếp cảnh leo chung cư (Thứ Năm), cảnh đó in "AUTOTEST OK" khi xong
		print("AUTOTEST GIAO OK")
		get_tree().change_scene_to_file.call_deferred(PlayMode.CHUNG_CU_SCENE)


func _on_dog_bite() -> void:
	_bitten = true
	bites += 1
	intact = false
	var bite: float = DoKho.v("bite_penalty", BITE_PENALTY)
	time_left = maxf(time_left - bite, 0.1)
	player.knockback(dog.global_position)
	hud.show_toast("Chó Mực đớp mất %d giây!" % int(bite) if bite > 0.0 else "Chó Mực đớp trúng túi bánh! Ổ bánh hơi móp.")


func _on_dog_state(s: int) -> void:
	_dog_states.append(s)
	if s == dog.State.CHASE:
		hud.show_toast("Chó Mực thức rồi! Chạy nhanh hoặc nhảy lên chỗ cao!", 2.0)


func _update_hud() -> void:
	if order_index >= orders.size():
		return
	if "stance" in player:  # dáng rón rén/chui do luồng động tác của Bơ thêm vào player.gd
		hud.set_stance(player.stance)
	var order: Dictionary = orders[order_index]
	if hud.has_method("set_order_note"):
		var note: String = order.get("note", "")
		hud.set_order_note(Days.note_name(note) if note != "" else "", _note_ok(order_index))
	if _is_errand(order):
		_update_hud_errand(order)
		return
	if player.carrying:
		hud.set_order(order_index, orders.size(), "%s · %s" % [order.who, order.place], _item_text(order), order.color)
		hud.set_timer(time_left, _time_limit(order), true)
		hud.set_distance(player.global_position.distance_to(order.pos), order.place)
		hud.set_goal(order.pos + Vector3.UP)
		hud.set_bread(true, order.item, 1.0 - carry_time / float(DoKho.v("bread_cool", 45.0)))  # nguội hẳn sau 45 giây
		if hud.has_method("set_kitchen_stars"):
			hud.set_kitchen_stars(Scoring.kitchen_star_for(order_index))
	else:
		hud.set_order(order_index, orders.size(), "Lò bánh Cô Ba", "Tới lò nhận " + _item_text(order), Color("#D98E2B"), "B")
		hud.set_timer(0, 1, false)
		hud.set_distance(player.global_position.distance_to(City.BAKERY_POINT), "Lò bánh Cô Ba")
		hud.set_goal(City.BAKERY_POINT + Vector3.UP)
		hud.set_bread(false)
		if hud.has_method("set_kitchen_stars"):
			hud.set_kitchen_stars(-1)


## Ổ của đơn i có ráp đúng phiếu ghi món không (màn bếp ghi; chưa có thì coi như đúng).
func _note_ok(i: int) -> bool:
	return GameState.bread_note_ok[i] if i < GameState.bread_note_ok.size() else true


## Thẻ đơn của đơn errand: trước khi lấy đồ chỉ tới chỗ khách, lấy rồi thì chỉ về lò.
func _update_hud_errand(order: Dictionary) -> void:
	if hud.has_method("set_kitchen_stars"):
		hud.set_kitchen_stars(-1)
	if player.carrying:
		var detail := "Mang %s về lò" % order.item
		var eggs: int = deliveries.errand_eggs(order_index)
		if eggs >= 0:
			detail += " · còn %d/%d quả" % [eggs, ShopTapHoa.EGGS]
		hud.set_order(order_index, orders.size(), "Lò bánh Cô Ba", detail, Color("#D98E2B"), "B")
		hud.set_timer(time_left, _time_limit(order), true)
		hud.set_distance(player.global_position.distance_to(City.BAKERY_POINT), "Lò bánh Cô Ba")
		hud.set_goal(City.BAKERY_POINT + Vector3.UP)
		hud.set_bread(false)  # không mang ổ bánh; số trứng hiện trên thẻ đơn (và hud.set_eggs nếu có)
	else:
		hud.set_order(order_index, orders.size(), "%s · %s" % [order.who, order.place], "Tới lấy " + order.item, order.color)
		hud.set_timer(0, 1, false)
		hud.set_distance(player.global_position.distance_to(order.pos), order.place)
		hud.set_goal(order.pos + Vector3.UP)
		hud.set_bread(false)


# ---------------------------------------------------------------- dựng cảnh

func _setup_environment() -> void:
	# Mỗi ngày một buổi (Thứ Hai nắng sớm, Thứ Tư mưa...): trời, nắng, sương, bóng, mưa, đèn lồng: scripts/anh_sang.gd
	AnhSang.build(self, AnhSang.preset_for_day(day.id))


func _build_bakery() -> void:
	var p := City.BAKERY_POINT
	# Xe tủ kính bánh mì trước lò (model xe_banh_mi, kính cao 1,3 m nên hộp va chạm cao bằng)
	var cart := Blocks.collider(self, Vector3(1.6, 1.3, 0.7), Vector3(p.x + 2.4, 0.65, p.z + 0.2), Blocks.LAYER_PROP)
	PhoModels.put(cart, "xe_banh_mi", Vector3(0, -0.65, 0))
	# Cô Ba (người có xương) do scripts/residents.gd dựng sau khi gộp khối tĩnh
	bakery_zone = _zone(p, 1.8)
	# Vòng tròn đánh dấu chỗ nhận bánh
	_ring(p, Color("#D98E2B"))


func _build_customers() -> void:
	for i in orders.size():
		var o: Dictionary = orders[i]
		# Người dân và đồ giao bánh do deliveries.gd dựng theo từng cách giao
		customer_zones.append(_zone(o.pos, 1.6))
		_ring(o.pos, Color("#C8412F"))


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
## Static để cảnh khác (chung cư) dùng chung bộ phím.
static func _setup_input() -> void:
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


static func _action(action: String, keys: Array, buttons: Array, axes: Array) -> void:
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
	if player.carrying and not _finishing and not _is_errand(orders[order_index]):
		goal = deliveries.stand_point(order_index)
	if _finishing:
		pass
	elif player.carrying and orders[order_index].get("boss", false) and not _bitten:
		goal = dog.global_position + Vector3(0.3, 0, 0.3)
		dog.hear(goal, 10.0)  # giả tiếng chạy nhanh sát ổ: Mực nghi ngờ rồi đuổi
	elif not player.carrying and order_index == 1 and Scoring.stamps_today.is_empty() and not stamps.remaining().is_empty():
		goal = stamps.remaining()[0] - Vector3(0, 0.2, 0)  # trên đường về lò ghé nhặt một con tem
	player.global_position = goal + Vector3(0, 0.2, 0)
	player.velocity = Vector3.ZERO
