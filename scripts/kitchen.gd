extends Node3D
## Màn bếp Cô Ba: Bơ làm 2 ổ bánh mì trong 2 phút 30 giây trước khi đi giao.
## Camera đứng cố định ngoài tủ kính nhìn vào bếp. Bơ chạy giữa các trạm, mỗi lần cầm một món:
## bao bột → bàn nhồi → lò gạch → kệ (rau, chả, thịt) → thớt → bàn ráp → tủ kính.
## Tới trạm bấm E: camera lướt vào cận cảnh, mỗi bước bấm E để hai chân trước của Bơ làm.
## Điểm bếp (0–3 sao) cộng 2 giây/sao vào đồng hồ mọi đơn giao (GameState.kitchen_bonus).
##
## Toàn bộ đồ bếp là khối tạm (scripts/kitchen_props.gd) theo màu thẻ đồ bếp kiểu D.

const PlayerScript := preload("res://scripts/player.gd")
const CameraScript := preload("res://scripts/kitchen_camera.gd")
const HudScript := preload("res://scripts/kitchen_hud.gd")
const P := preload("res://scripts/kitchen_props.gd")

@export var time_limit := 150.0   ## 2 phút 30 giây cho 2 ổ
@export var bake_time := 6.0      ## lò nướng chín sau 6 giây
@export var burn_after := 5.0     ## để thêm quá 5 giây là cháy
@export var spare_for_star := 45.0  ## còn dư từ chừng này giây thì được sao thứ ba
const LOAVES := 2
const USE_RADIUS := 0.6
const STAR_SECONDS := 2.0

enum State { MENU, PLAY, END }

var state := State.MENU
var time_left := 0.0
var holding := ""          ## món đang cầm: "", bot, khay_song, khay_chin, khay_chay, rau, cha, thit, rau_xong..., banh_mi
var dough_started := false
var oven_state := "trong"  ## trong, nuong, chin, chay
var oven_t := 0.0
var bread_burnt := false
var loaf_stars: Array[int] = []   ## sao từng ổ, ghi lúc bỏ ổ vào tủ kính
var taken := {"rau": false, "cha": false, "thit": false}
var on_rap := {"rau": false, "cha": false, "thit": false}
var loaves_on_rap := 0
var made := 0

var player: CharacterBody3D
var cam: Node3D
var hud: CanvasLayer
var stations := {}   ## id -> {name, use, work, cam, ring}
var carry_node: Node3D

# Cận cảnh: chuỗi bước của trạm đang làm
var seq: Array = []
var seq_station := ""
var seq_index := 0
var presses_left := 0
var busy := false

# Đồ động ở các trạm (cận cảnh dùng)
var paw_rig: Node3D
var paw_l: Node3D
var paw_r: Node3D
var flour_puff: CPUParticles3D
var heap: MeshInstance3D
var dough: MeshInstance3D
var balls: Array[MeshInstance3D] = []
var raw_loaves: Array[MeshInstance3D] = []
var slashes: Array[Node3D] = []
var jug: Node3D
var stream: MeshInstance3D
var cloth: MeshInstance3D
var cutter: Node3D
var oven_door: Node3D
var oven_fire: MeshInstance3D
var oven_tray: Node3D
var oven_loaves: Array[MeshInstance3D] = []
var oven_label: Label3D
var spray: Node3D
var mist: CPUParticles3D
var smoke: CPUParticles3D
var shelf_items := {}
var board_knife: Node3D
var board_item: Node3D
var board_slices: Array[MeshInstance3D] = []
var drops: CPUParticles3D
var rap_tray: Node3D
var rap_loaves: Array[MeshInstance3D] = []
var rap_bowls := {}
var work_loaf: Node3D
var work_parts := {}
var pate_jar: Node3D
var sauce: Node3D
var case_slots: Array[Node3D] = []
var paper: MeshInstance3D

const PAW_L_REST := Vector3(-0.09, 0.06, 0.15)
const PAW_R_REST := Vector3(0.09, 0.06, 0.15)
const CLOSE_BACK := 0.42   ## camera cận cảnh lùi về phía Bơ đứng bao nhiêu mét so với điểm làm việc
const CLOSE_UP := 0.34     ## và cao hơn điểm làm việc bao nhiêu mét (ngang tầm mắt Bơ)
const CLOSE_AHEAD := 0.08  ## camera nhìn hơi vượt qua điểm làm việc để chân nằm ở nửa dưới khung

# Tự chơi: --autotest-bep (kiểm tra, thoát khi xong) hoặc --demo-bep (để quay clip)
var _bot := false
var _bot_quit := false
var _bot_path: Array[Vector3] = []
var _bot_goal := ""
var _bot_wait := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		# Kiểm tra vòng giao bánh như cũ: bỏ qua bếp
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	_bot = "--autotest-bep" in args or "--demo-bep" in args
	_bot_quit = "--autotest-bep" in args

	_setup_input()
	_setup_environment()
	var room := Node3D.new()
	room.name = "Phong"
	add_child(room)
	_build_room(room)
	_build_stations(room)
	Blocks.merge_static(room)

	player = PlayerScript.new()
	player.name = "Bo"
	player.walk_speed = 2.6   # bếp nhỏ, chạy 5 m/s thì vọt qua trạm
	player.sprint_speed = 4.0
	player.position = Vector3(-1.0, 0.1, 0.9)
	add_child(player)

	cam = CameraScript.new()
	cam.name = "CameraBep"
	cam.target = player
	add_child(cam)
	player.camera_rig = cam

	_build_paws()

	hud = HudScript.new()
	add_child(hud)
	hud.start_pressed.connect(start_game)
	hud.go_delivery_pressed.connect(_go_delivery)
	hud.menu_pressed.connect(func(): PlayMode.back_to_menu(get_tree()))
	if PlayMode.kitchen_only():
		for b in hud.end_screen.find_children("*", "Button", true, false):
			b.text = "Về chọn màn (Enter)"
	_update_hud()

	if _bot:
		print("[bep] tự chơi")
		if _bot_quit:
			start_game.call_deferred()
		else:
			get_tree().create_timer(2.5).timeout.connect(start_game)  # quay clip: để thấy màn hình bắt đầu


func start_game() -> void:
	if state == State.PLAY:
		return
	state = State.PLAY
	time_left = time_limit
	player.can_move = true
	hud.start_screen.visible = false
	hud.show_playing_ui(true)
	hud.show_toast("Tới bao bột xúc bột trước nhé!", 2.5)
	_sound("music", "kitchen")
	_sound("ambience", "kitchen")


func _unhandled_input(event: InputEvent) -> void:
	match state:
		State.MENU:
			if event.is_action_pressed("ui_accept"):
				start_game()
		State.END:
			if event.is_action_pressed("ui_accept"):
				_go_delivery()
		State.PLAY:
			if event.is_action_pressed("pause"):
				hud.toggle_pause()
			elif event.is_action_pressed("interact") and not _bot:
				if seq.is_empty():
					_interact()
				else:
					_press()


func _physics_process(delta: float) -> void:
	if state != State.PLAY:
		return
	time_left -= delta
	_update_oven(delta)
	if _bot:
		_bot_step(delta)
	if time_left <= 0.0:
		time_left = 0.0
		_end(false)
	_update_hud()


func _process(delta: float) -> void:
	# Vòng tròn dưới chân trạm: trạm nên tới sáng cam nhấp nháy, trạm đang đứng sáng vàng
	var near := _near_station()
	var goal := _suggest()
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
	for id in stations:
		var ring: MeshInstance3D = stations[id].ring
		var mat: StandardMaterial3D = ring.material_override
		if state == State.PLAY and id == near:
			mat.albedo_color = Color("#FFE27A")
		elif state == State.PLAY and id == goal:
			mat.albedo_color = Color(0.85, 0.56, 0.17, pulse)
		else:
			mat.albedo_color = Color(1, 1, 1, 0.18)


# ---------------------------------------------------------------- luật chơi

## Bấm E ở trạm: xem trạm cho làm gì với món đang cầm.
func _interact() -> void:
	var id := _near_station()
	if id == "":
		hud.show_toast("Lại gần một trạm (vòng tròn dưới đất) rồi bấm E")
		return
	var steps := _steps_for(id)
	if steps.is_empty():
		return
	_begin(id, steps)


## Trả về danh sách bước; rỗng nếu chưa làm được (kèm lời nhắc), hoặc nếu là việc đặt đồ làm ngay.
func _steps_for(id: String) -> Array:
	match id:
		"bot":
			if holding != "":
				return _no("Tay đang cầm %s rồi" % _item_name(holding))
			if dough_started:
				return _no("Bột đủ cho 2 ổ rồi")
			return [_s("xuc", "Xúc bột", 1)]
		"nhoi":
			if holding != "bot":
				return _no("Cần mang bột tới bàn nhồi")
			return [_s("do_nuoc", "Đổ nước", 1), _s("nhoi", "Nhồi bột", 4), _s("u", "Ủ bột", 1),
				_s("chia", "Chia bột", 1), _s("ve", "Vê thành ổ", 2), _s("khia", "Khía mặt bánh", 2)]
		"lo":
			match oven_state:
				"nuong":
					return _no("Bánh đang nướng, còn %d giây" % ceili(bake_time - oven_t))
				"chin", "chay":
					if holding != "":
						return _no("Đặt %s xuống trước đã" % _item_name(holding))
					return [_s("mo_cua", "Mở cửa lò", 1), _s("keo_khay", "Kéo khay ra", 1)]
				_:
					if holding != "khay_song":
						return _no("Cần mang khay bánh sống tới lò")
					return [_s("mo_cua", "Mở cửa lò", 1), _s("phun", "Phun hơi nước", 1),
						_s("day_khay", "Đẩy khay vào lò", 1), _s("dong_cua", "Đóng cửa lò", 1)]
		"rau", "cha", "thit":
			if taken[id]:
				return _no("Lấy %s rồi" % _item_name(id))
			if holding != "":
				return _no("Tay đang cầm %s rồi" % _item_name(holding))
			return [_s("lay", "Lấy %s" % _item_name(id), 1)]
		"thot":
			match holding:
				"rau":
					return [_s("rua", "Rửa rau", 1), _s("nhat", "Nhặt lá úa", 1), _s("cat", "Cắt rau", 3)]
				"cha":
					return [_s("boc_la", "Bóc lá chuối", 1), _s("cat", "Thái chả", 3)]
				"thit":
					return [_s("cat", "Thái thịt", 3), _s("xep", "Xếp ra đĩa", 1)]
			return _no("Mang rau, chả hoặc thịt sống tới thớt")
		"rap":
			if holding in ["khay_chin", "khay_chay"]:
				loaves_on_rap = LOAVES
				bread_burnt = holding == "khay_chay"
				_set_holding("")
				_refresh_rap()
				hud.show_toast("Đặt bánh lên bàn ráp")
				return []
			if holding.ends_with("_xong"):
				var k := holding.trim_suffix("_xong")
				on_rap[k] = true
				_set_holding("")
				_refresh_rap()
				hud.show_toast("Đặt %s lên bàn ráp" % _item_name(k))
				return []
			if holding != "":
				return _no("Phải sơ chế %s trên thớt trước" % _item_name(holding) if holding in taken else "Bàn ráp chưa cần %s" % _item_name(holding))
			var missing := []
			if loaves_on_rap == 0:
				missing.append("bánh nướng")
			for k in ["rau", "cha", "thit"]:
				if not on_rap[k]:
					missing.append(_item_name(k))
			if not missing.is_empty():
				return _no("Còn thiếu: " + ", ".join(missing))
			return [_s("xe", "Xẻ bánh", 1), _s("pate", "Phết pate", 1), _s("kep", "Kẹp chả, thịt", 1),
				_s("them_rau", "Thêm rau", 1), _s("tuong", "Rưới nước tương", 1)]
		"tu":
			if holding != "banh_mi":
				return _no("Ráp xong ổ bánh mì rồi mới bỏ vào tủ")
			return [_s("goi", "Gói giấy", 1), _s("bo_vao", "Bỏ vào tủ kính", 1)]
	return []


func _s(id: String, title: String, presses: int) -> Dictionary:
	return {"id": id, "name": title, "n": presses}


func _no(msg: String) -> Array:
	if _bot:
		print("[bep] %5.1fs %s" % [time_limit - time_left, msg])
	hud.show_toast(msg)
	return []


func _begin(id: String, steps: Array) -> void:
	seq = steps
	seq_station = id
	seq_index = 0
	presses_left = steps[0].n
	busy = false
	player.can_move = false
	player.velocity = Vector3.ZERO
	var st: Dictionary = stations[id]
	var to: Vector3 = st.work - player.global_position
	player.visual.rotation.y = atan2(-to.x, -to.z)
	cam.close_up(st.cam, st.look)
	_place_paws(st)
	player.visual.visible = false  # cận cảnh chỉ thấy hai chân trước, thân Bơ không che camera
	_on_begin(id)
	_show_step()


## Một lần bấm E trong cận cảnh: chân Bơ làm một nhịp của bước hiện tại.
func _press() -> void:
	if busy or seq.is_empty():
		return
	var step: Dictionary = seq[seq_index]
	var beat: int = step.n - presses_left
	presses_left -= 1
	busy = true
	_show_step()
	var tw := _beat(seq_station, step.id, beat)
	tw.finished.connect(_beat_done, CONNECT_ONE_SHOT)


func _beat_done() -> void:
	busy = false
	if presses_left > 0:
		_show_step()
		return
	seq_index += 1
	if seq_index < seq.size():
		presses_left = seq[seq_index].n
		_show_step()
		return
	var id := seq_station
	seq = []
	seq_station = ""
	hud.hide_step()
	cam.back_to_main()
	paw_rig.visible = false
	player.visual.visible = true
	player.can_move = true
	_finish(id)


func _show_step() -> void:
	var step: Dictionary = seq[seq_index]
	hud.show_step(step.name, seq_index, seq.size(), presses_left, busy)


## Kết quả sau khi làm xong cả chuỗi bước ở một trạm.
func _finish(id: String) -> void:
	if _bot:
		print("[bep] %5.1fs xong trạm %s (cầm %s)" % [time_limit - time_left, id, holding])
	match id:
		"bot":
			dough_started = true
			_set_holding("bot")
		"nhoi":
			_set_holding("khay_song")
			_reset_kneading()
		"lo":
			if holding == "khay_song":
				_set_holding("")
				oven_state = "nuong"
				oven_t = 0.0
				_sound("loop", "oven_fire")
				hud.show_toast("Nướng 6 giây. Tranh thủ đi lấy rau, chả, thịt!", 2.5)
			else:
				var burnt := oven_state == "chay"
				_set_holding("khay_chay" if burnt else "khay_chin")
				oven_state = "trong"
				oven_tray.visible = false
				smoke.emitting = false
				_sound("stop_loop", "oven_fire")
				create_tween().tween_property(oven_door, "rotation:y", 0.0, 0.4)
				hud.show_toast("Ôi cháy mất rồi! Đành dùng tạm..." if burnt else "Bánh vàng giòn thơm phức!", 2.5)
		"rau", "cha", "thit":
			taken[id] = true
			_set_holding(id)
		"thot":
			_set_holding(holding + "_xong")
			_clear_board()
		"rap":
			loaves_on_rap -= 1
			_set_holding("banh_mi")
			work_loaf.visible = false
			_refresh_rap()
		"tu":
			_set_holding("")
			case_slots[made].visible = true
			paper.visible = false
			made += 1
			# Sao của ổ này: 1 vì làm xong, +1 nếu không cháy, +1 nếu bỏ tủ khi còn dư đủ giờ
			loaf_stars.append(1 + int(not bread_burnt) + int(time_left >= spare_for_star))
			if made >= LOAVES:
				_end(true)
			else:
				hud.show_toast("Xong ổ 1! Quay lại bàn ráp làm ổ 2")


func _update_oven(delta: float) -> void:
	var c := P.DOUGH
	match oven_state:
		"nuong", "chin", "chay":
			oven_t += delta
			if oven_t < bake_time:
				c = P.DOUGH.lerp(P.CRUST, oven_t / bake_time)
				oven_label.text = "Đang nướng %d" % ceili(bake_time - oven_t)
				oven_label.modulate = Color("#FFE2A8")
			elif oven_t < bake_time + burn_after:
				if oven_state == "nuong":
					oven_state = "chin"
					_sound("play", "oven_ding")
					hud.show_toast("Bánh chín rồi! Lấy ra kẻo cháy", 2.0)
				c = P.CRUST.lerp(P.CRUST.darkened(0.3), (oven_t - bake_time) / burn_after)
				oven_label.text = "CHÍN! Lấy ra (%d)" % ceili(bake_time + burn_after - oven_t)
				oven_label.modulate = Color("#9BE38B") if fmod(oven_t, 0.5) < 0.3 else Color.WHITE
			else:
				if oven_state != "chay":
					oven_state = "chay"
					smoke.emitting = true
					_sound("play", "burn")
					hud.show_toast("Khói kìa! Bánh cháy rồi!", 2.0)
				c = P.BURNT
				oven_label.text = "CHÁY!"
				oven_label.modulate = P.RED
			for l in oven_loaves:
				(l.material_override as StandardMaterial3D).albedo_color = c
		_:
			oven_label.text = ""
	oven_fire.visible = oven_state != "trong"


func _end(success: bool) -> void:
	if state == State.END:
		return
	state = State.END
	player.can_move = false
	var stars := 0
	var lines := ""
	if success:
		stars = 1
		lines += "★ Làm đủ 2 ổ trước giờ\n"
		if not bread_burnt:
			stars += 1
			lines += "★ Bánh vàng giòn, không cháy\n"
		else:
			lines += "☆ Bánh bị cháy\n"
		if time_left >= spare_for_star:
			stars += 1
			lines += "★ Còn dư %d giây (từ %d giây mới được sao)\n" % [int(time_left), int(spare_for_star)]
		else:
			lines += "☆ Chỉ dư %d giây (cần từ %d giây)\n" % [int(time_left), int(spare_for_star)]
	else:
		lines += "Hết giờ! Mới xong %d/%d ổ.\n" % [made, LOAVES]
	GameState.kitchen_stars = stars
	if not _bot:  # sao bếp cao nhất cho màn Chọn màn
		GameState.set_day("sao_bep", maxi(int(GameState.get_day("sao_bep", -1)), stars))
		GameState.write_save()
	# Sao từng ổ cho 5 đơn giao. Bếp mới làm LOAVES ổ: các đơn sau dùng số sao chung của ca.
	var per_bread: Array[int] = []
	for i in GameState.ORDERS_PER_DAY:
		per_bread.append(loaf_stars[i] if i < loaf_stars.size() else stars)
	GameState.kitchen_stars_per_bread = per_bread
	GameState.kitchen_bonus = stars * STAR_SECONDS
	lines += "\n%d/3 sao · ổ bánh 3 sao giúp đơn đó được cộng thêm %d giây" % [stars, int(Scoring.KITCHEN_BONUS_SECONDS)]
	hud.show_end(lines)
	_sound("stop_loop", "oven_fire")
	_sound("music", "jingle_win" if success else "jingle_lose")
	for i in stars:
		get_tree().create_timer(0.5 + 0.45 * i).timeout.connect(_sound.bind("play", "star_%d" % (i + 1)))
	print("[bep] xong=%d/%d sao=%d tung_o=%s con_lai=%.1fs chay=%s" % [made, LOAVES, stars, per_bread, time_left, bread_burnt])
	if _bot_quit:
		print("AUTOTEST BEP ", "OK" if success else "FAIL")
		get_tree().quit(0 if success else 1)
	elif _bot:
		get_tree().create_timer(3.0).timeout.connect(_go_delivery)


func _go_delivery() -> void:
	if state != State.END:
		return
	if PlayMode.kitchen_only() and not _bot:
		PlayMode.back_to_menu(get_tree())
		return
	GameState.from_kitchen = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _set_holding(kind: String) -> void:
	holding = kind
	if carry_node:
		carry_node.queue_free()
		carry_node = null
	if kind != "":
		_sound("play", "pickup")
		carry_node = P.carry_item(kind)
		carry_node.position = Vector3(0, 0.42, 0.04)
		player.visual.add_child(carry_node)
		carry_node.scale = Vector3.ONE * 0.2
		create_tween().tween_property(carry_node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _item_name(kind: String) -> String:
	return {
		"bot": "bột", "khay_song": "khay bánh sống", "khay_chin": "khay bánh nướng", "khay_chay": "khay bánh cháy",
		"rau": "rau", "cha": "chả lụa", "thit": "thịt nguội", "rau_xong": "rau đã cắt", "cha_xong": "chả đã thái",
		"thit_xong": "thịt đã thái", "banh_mi": "ổ bánh mì",
	}.get(kind, kind)


## Trạm nên tới tiếp, dùng cho gợi ý dưới màn hình, vòng sáng và bot tự chơi.
func _suggest() -> String:
	match holding:
		"bot":
			return "nhoi"
		"khay_song":
			return "lo"
		"khay_chin", "khay_chay", "rau_xong", "cha_xong", "thit_xong":
			return "rap"
		"rau", "cha", "thit":
			return "thot"
		"banh_mi":
			return "tu"
	if oven_state in ["chin", "chay"]:
		return "lo"
	if not dough_started:
		return "bot"
	for k in ["rau", "cha", "thit"]:
		if not taken[k]:
			return k
	if loaves_on_rap > 0:
		return "rap"
	if oven_state == "nuong":
		return "lo"
	return ""


func _update_hud() -> void:
	hud.set_timer(time_left, time_limit, state == State.PLAY)
	var tick := func(ok: bool) -> String: return "✓" if ok else "○"
	var baked := loaves_on_rap > 0 or made > 0 or holding in ["khay_chin", "khay_chay", "banh_mi"]
	var text := "Bếp Cô Ba · 2 ổ bánh mì\n"
	text += "%s Xúc bột, nhồi, tạo hình\n" % tick.call(dough_started and holding != "bot")
	text += "%s Nướng 6 giây\n" % tick.call(baked)
	for k in ["rau", "cha", "thit"]:
		text += "%s %s\n" % [tick.call(on_rap[k]), {"rau": "Rau: rửa, nhặt, cắt", "cha": "Chả: bóc lá, thái", "thit": "Thịt: thái, xếp"}[k]]
	text += "%s Ráp và bỏ tủ: %d/%d ổ\n" % [tick.call(made >= LOAVES), made, LOAVES]
	text += "\nĐang cầm: %s" % (_item_name(holding) if holding != "" else "không")
	hud.set_recipe(text)
	var oven_txt: String = {"trong": "trống", "nuong": "đang nướng", "chin": "CHÍN, lấy ra!", "chay": "CHÁY!"}[oven_state]
	hud.set_status("Ổ xong: %d/%d\nLò: %s" % [made, LOAVES, oven_txt])
	if seq.is_empty():
		var near := _near_station()
		if near != "":
			hud.set_prompt("E · %s" % stations[near].name, true)
		else:
			var g := _suggest()
			hud.set_prompt("Tới %s" % stations[g].name.to_lower() if g != "" else "", false)


func _near_station() -> String:
	if not player:
		return ""
	var best := ""
	var best_d := USE_RADIUS
	var p := player.global_position
	for id in stations:
		var u: Vector3 = stations[id].use
		var d := Vector2(p.x - u.x, p.z - u.z).length()
		if d < best_d:
			best_d = d
			best = id
	return best


func _sound(method: String, sound_name: String) -> void:
	var s := get_node_or_null("/root/Sound")
	if s and s.has_method(method):
		s.call(method, sound_name)


# ---------------------------------------------------------------- cận cảnh: chân Bơ làm từng nhịp

func _build_paws() -> void:
	paw_rig = Node3D.new()
	paw_rig.name = "ChanBo"
	add_child(paw_rig)
	paw_l = P.paw(paw_rig, -1.0)
	paw_r = P.paw(paw_rig, 1.0)
	paw_rig.visible = false


## Đặt hai chân trước ở điểm làm việc của trạm; +Z cục bộ hướng về chỗ Bơ đứng.
func _place_paws(st: Dictionary) -> void:
	var work: Vector3 = st.work
	var d: Vector3 = work - (st.use as Vector3)
	d.y = 0
	paw_rig.global_transform = Transform3D(Basis.looking_at(d.normalized()), work)
	paw_l.position = PAW_L_REST
	paw_r.position = PAW_R_REST
	paw_l.rotation = Vector3.ZERO
	paw_r.rotation = Vector3.ZERO
	paw_rig.visible = true


## Toạ độ của một điểm thế giới trong hệ chân (để đưa chân tới đúng món).
func _at(node: Node3D, up := 0.04) -> Vector3:
	return paw_rig.to_local(node.global_position) + Vector3(0, up, 0)


func _on_begin(id: String) -> void:
	match id:
		"nhoi":
			heap.visible = true
			heap.scale = Vector3.ONE
		"lo":
			if holding == "khay_song":
				oven_tray.visible = true
				oven_tray.position.z = 0.75
				for l in oven_loaves:
					(l.material_override as StandardMaterial3D).albedo_color = P.DOUGH
		"thot":
			_setup_board(holding)
		"rap":
			work_loaf.visible = true
			for k in work_parts:
				work_parts[k].visible = false
			work_parts.top.rotation.x = 0.0
		"tu":
			paper.visible = false
	_set_holding_visible(false)


func _set_holding_visible(v: bool) -> void:
	if carry_node:
		carry_node.visible = v


## Chân đi tới rồi ấn xuống một điểm, rồi về chỗ cũ.
func _tap(tw: Tween, paw: Node3D, target: Vector3, rest: Vector3, dur := 0.35) -> void:
	tw.tween_property(paw, "position", target + Vector3(0, 0.07, 0), dur * 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(paw, "position", target, dur * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(paw, "position", rest, dur * 0.35).set_trans(Tween.TRANS_SINE)


## Một nhịp animation cho bước `step` ở trạm `id`. beat = lần bấm thứ mấy của bước (0..n-1).
func _beat(id: String, step: String, beat: int) -> Tween:
	var tw := create_tween()
	match step:
		"xuc":  # thò chân vào miệng bao, bột tung lên
			var top := paw_rig.to_local(stations.bot.work)
			tw.tween_property(paw_r, "position", top + Vector3(0, 0.12, 0), 0.25).set_trans(Tween.TRANS_SINE)
			tw.tween_property(paw_r, "position", top - Vector3(0, 0.02, 0), 0.15)
			tw.tween_callback(func(): flour_puff.restart())
			tw.tween_property(paw_r, "position", PAW_R_REST, 0.3).set_trans(Tween.TRANS_SINE).set_delay(0.15)
			_sound("play", "knead")
		"do_nuoc":  # bê bình rót nước vào ụ bột
			var j0 := jug.position
			var over := heap.position + Vector3(0.09, 0.2, 0)
			tw.tween_property(jug, "position", over, 0.3).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(paw_r, "position", _at_world(heap.global_position + Vector3(0.14, 0.18, 0.02)), 0.3)
			tw.tween_property(jug, "rotation:z", 1.2, 0.25)
			tw.tween_callback(func(): stream.visible = true; _sound("play", "water"))
			tw.tween_property(heap, "scale", Vector3(1.1, 0.85, 1.1), 0.5)
			tw.tween_callback(func(): stream.visible = false)
			tw.tween_property(jug, "rotation:z", 0.0, 0.2)
			tw.tween_property(jug, "position", j0, 0.3).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.3)
		"nhoi":  # hai chân thay nhau ấn, cục bột bẹp rồi phồng lại
			if beat == 0:
				heap.visible = false
				dough.visible = true
				dough.scale = Vector3(1.2, 0.6, 1.2)
			var paw := paw_l if beat % 2 == 0 else paw_r
			var rest := PAW_L_REST if beat % 2 == 0 else PAW_R_REST
			_tap(tw, paw, _at(dough, 0.05) + Vector3(0.03 * (1 if beat % 2 else -1), 0, 0), rest, 0.4)
			tw.parallel().tween_property(dough, "scale", Vector3(1.35, 0.55, 1.2), 0.15).set_delay(0.15)
			tw.tween_property(dough, "scale", Vector3(1.0 + beat * 0.03, 0.85, 1.0), 0.15).set_trans(Tween.TRANS_BACK)
			_sound("play", "knead")
		"u":  # phủ khăn, bột nở to
			cloth.visible = true
			cloth.scale = Vector3(0.01, 0.01, 0.01)
			tw.tween_property(cloth, "scale", Vector3.ONE, 0.25)
			tw.tween_property(dough, "scale", Vector3(1.35, 1.15, 1.3), 1.0).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(cloth, "position:y", cloth.position.y + 0.04, 1.0)
			tw.tween_property(cloth, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
			tw.tween_callback(func(): cloth.visible = false; cloth.position.y -= 0.04)
		"chia":  # dao chặt đôi cục bột
			var c0 := cutter.position
			tw.tween_property(cutter, "position", dough.position + Vector3(-0.1, 0.16, 0), 0.25)
			tw.parallel().tween_property(paw_r, "position", _at_world(dough.global_position + Vector3(0.0, 0.18, 0.02)), 0.25)
			tw.tween_property(cutter, "position", dough.position + Vector3(-0.1, 0.02, 0), 0.12)
			tw.parallel().tween_property(paw_r, "position", _at_world(dough.global_position + Vector3(0.0, 0.05, 0.02)), 0.12)
			tw.tween_callback(func():
				dough.visible = false
				for b in balls:
					b.visible = true
					b.position = dough.position
			)
			tw.tween_property(balls[0], "position", raw_loaves[0].position, 0.25)
			tw.parallel().tween_property(balls[1], "position", raw_loaves[1].position, 0.25)
			tw.parallel().tween_property(cutter, "position", c0, 0.3)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.3)
			_sound("play", "chop")
		"ve":  # hai chân lăn viên bột thành ổ dài
			var b := balls[beat]
			var l := raw_loaves[beat]
			var tgt := _at(l, 0.05)
			tw.tween_property(paw_l, "position", tgt + Vector3(-0.04, 0, 0), 0.15)
			tw.parallel().tween_property(paw_r, "position", tgt + Vector3(0.04, 0, 0), 0.15)
			tw.tween_callback(func(): b.visible = false; l.visible = true; l.scale = Vector3(0.5, 1.4, 1.0))
			for i in 2:
				tw.tween_property(paw_l, "position", tgt + Vector3(-0.08, 0, 0.03), 0.1)
				tw.parallel().tween_property(paw_r, "position", tgt + Vector3(0.08, 0, -0.03), 0.1)
				tw.tween_property(paw_l, "position", tgt + Vector3(-0.08, 0, -0.03), 0.1)
				tw.parallel().tween_property(paw_r, "position", tgt + Vector3(0.08, 0, 0.03), 0.1)
			tw.parallel().tween_property(l, "scale", Vector3(1, 1, 0.8), 0.4).set_delay(-0.3)
			tw.tween_property(paw_l, "position", PAW_L_REST, 0.2)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.2)
		"khia":  # dao rạch 3 đường chéo trên mặt ổ
			var l := raw_loaves[beat]
			var c0 := cutter.position
			tw.tween_property(cutter, "position", l.position + Vector3(-0.1, 0.07, 0), 0.2)
			tw.parallel().tween_property(paw_r, "position", _at_world(l.global_position + Vector3(0.05, 0.1, 0.02)), 0.2)
			tw.tween_property(cutter, "position", l.position + Vector3(-0.02, 0.045, 0), 0.25)
			tw.parallel().tween_property(paw_r, "position", _at_world(l.global_position + Vector3(0.12, 0.08, 0.02)), 0.25)
			tw.tween_callback(func(): slashes[beat].visible = true)
			tw.tween_property(cutter, "position", c0, 0.25)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.25)
		"mo_cua":
			var handle := _at_world(oven_door.global_position + oven_door.global_basis.x * 0.55)
			tw.tween_property(paw_r, "position", handle, 0.2)
			tw.tween_property(oven_door, "rotation:y", -1.9, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(paw_r, "position", handle + Vector3(-0.2, 0, 0.25), 0.4)
			tw.tween_property(paw_r, "position", PAW_R_REST, 0.2)
			_sound("play", "oven_open")
		"phun":  # bình xịt phun hơi nước vào lò cho vỏ giòn
			var s0 := spray.position
			tw.tween_property(spray, "position", spray.position + Vector3(0.1, 0.2, 0.1), 0.25)
			tw.parallel().tween_property(paw_r, "position", _at_world(spray.global_position + Vector3(0.1, 0.22, 0.14)), 0.25)
			tw.tween_callback(func(): mist.restart())
			tw.tween_property(spray, "rotation:x", -0.3, 0.1)
			tw.tween_property(spray, "rotation:x", 0.0, 0.1)
			tw.tween_callback(func(): mist.restart())
			tw.tween_property(spray, "rotation:x", -0.3, 0.1)
			tw.tween_property(spray, "rotation:x", 0.0, 0.1)
			tw.tween_property(spray, "position", s0, 0.25)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.25)
			_sound("play", "spray")
		"day_khay":  # hai chân đẩy khay vào sâu trong lò
			var front := _at(oven_tray, 0.03)
			tw.tween_property(paw_l, "position", front + Vector3(-0.12, 0, 0.12), 0.2)
			tw.parallel().tween_property(paw_r, "position", front + Vector3(0.12, 0, 0.12), 0.2)
			tw.tween_property(oven_tray, "position:z", 0.15, 0.45).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(paw_l, "position", front + Vector3(-0.12, 0, -0.4), 0.45).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(paw_r, "position", front + Vector3(0.12, 0, -0.4), 0.45).set_trans(Tween.TRANS_SINE)
			tw.tween_property(paw_l, "position", PAW_L_REST, 0.25)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.25)
		"dong_cua":
			var handle := _at_world(oven_door.global_position + oven_door.global_basis.x * 0.55)
			tw.tween_property(paw_r, "position", handle, 0.25)
			tw.tween_property(oven_door, "rotation:y", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(paw_r, "position", _at_world(oven_door.global_position + Vector3(0.55, 0, 0.06)), 0.35)
			tw.tween_property(paw_r, "position", PAW_R_REST, 0.2)
		"keo_khay":  # kéo khay ra, khói/hơi bốc lên
			var back := _at(oven_tray, 0.03)
			tw.tween_property(paw_l, "position", back + Vector3(-0.15, 0, 0), 0.2)
			tw.parallel().tween_property(paw_r, "position", back + Vector3(0.15, 0, 0), 0.2)
			tw.tween_property(oven_tray, "position:z", 0.75, 0.45).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(paw_l, "position", back + Vector3(-0.15, 0, 0.6), 0.45)
			tw.parallel().tween_property(paw_r, "position", back + Vector3(0.15, 0, 0.6), 0.45)
			tw.tween_callback(func(): mist.restart())
			tw.tween_property(oven_tray, "position:y", oven_tray.position.y + 0.15, 0.25)
			tw.tween_property(paw_l, "position", PAW_L_REST, 0.2)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.2)
			tw.tween_callback(func(): oven_tray.position.y -= 0.15)
			_sound("play", "crunch")
		"lay":  # vươn chân nhấc món trên kệ
			var item: Node3D = shelf_items[id]
			var p0 := item.position
			tw.tween_property(paw_r, "position", _at(item, 0.06), 0.25).set_trans(Tween.TRANS_SINE)
			tw.tween_property(item, "position", p0 + Vector3(0, 0.12, 0.1), 0.25)
			tw.parallel().tween_property(paw_r, "position", _at(item, 0.06) + Vector3(0, 0.12, 0.1), 0.25)
			tw.tween_callback(func(): item.visible = false; item.position = p0)
			tw.tween_property(paw_r, "position", PAW_R_REST, 0.2)
		"rua":  # nước nhỏ giọt, chân xoa bó rau
			tw.tween_callback(func(): drops.restart())
			for i in 3:
				tw.tween_property(paw_l, "position", _at(board_item, 0.05) + Vector3(-0.05, 0, 0), 0.12)
				tw.parallel().tween_property(board_item, "rotation:y", 0.2 * (1 if i % 2 else -1), 0.12)
				tw.tween_property(paw_l, "position", _at(board_item, 0.07) + Vector3(0.04, 0, 0), 0.12)
			tw.tween_property(board_item, "rotation:y", 0.0, 0.1)
			tw.parallel().tween_property(paw_l, "position", PAW_L_REST, 0.2)
			_sound("play", "water")
		"nhat":  # nhặt một lá úa vứt đi
			var leaf := P.sphere(board_item, 0.025, Vector3(0.04, 0.04, 0.02), Color("#B9A23A"))
			tw.tween_property(paw_r, "position", _at(leaf, 0.04), 0.2)
			tw.tween_callback(func(): leaf.reparent(paw_r))
			tw.tween_property(paw_r, "position", PAW_R_REST + Vector3(0.18, 0.15, 0), 0.3)
			tw.tween_callback(func(): leaf.queue_free())
			tw.tween_property(paw_r, "position", PAW_R_REST, 0.2)
		"cat":  # dao chặt một nhát, một lát rơi ra
			var i := beat
			var item_x := 0.07 - i * 0.05
			var hand := board_item.position + Vector3(item_x, 0.13, 0)
			tw.tween_property(board_knife, "position", hand, 0.12)
			tw.parallel().tween_property(paw_r, "position", _at_world(board_item.global_position + Vector3(item_x + 0.1, 0.15, 0.03)), 0.12)
			tw.tween_property(board_knife, "position", hand - Vector3(0, 0.1, 0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(paw_r, "position", _at_world(board_item.global_position + Vector3(item_x + 0.1, 0.05, 0.03)), 0.08)
			tw.tween_callback(func():
				var s := board_slices[i]
				s.visible = true
				board_item.scale.x = maxf(board_item.scale.x - 0.22, 0.25)
			)
			tw.tween_property(board_slices[i], "position:z", board_slices[i].position.z + 0.06, 0.12)
			tw.tween_property(board_knife, "position", hand + Vector3(0, 0.03, 0), 0.12)
			tw.parallel().tween_property(paw_l, "position", _at(board_item, 0.06) + Vector3(-0.08, 0, 0), 0.12)
			_sound("play", "chop")
		"boc_la":  # bóc lớp lá chuối gói chả
			var wrap: Node3D = board_item.get_node("La")
			tw.tween_property(paw_l, "position", _at(board_item, 0.06) + Vector3(-0.05, 0, 0), 0.15)
			tw.parallel().tween_property(paw_r, "position", _at(board_item, 0.06) + Vector3(0.05, 0, 0), 0.15)
			tw.tween_property(wrap, "position", wrap.position + Vector3(0, 0.12, -0.2), 0.4).set_trans(Tween.TRANS_BACK)
			tw.parallel().tween_property(wrap, "rotation:x", -1.2, 0.4)
			tw.parallel().tween_property(paw_r, "position", _at(board_item, 0.18) + Vector3(0.05, 0, -0.2), 0.4)
			tw.tween_callback(func(): wrap.visible = false)
			tw.tween_property(paw_l, "position", PAW_L_REST, 0.2)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.2)
		"xep":  # gạt các lát ra đĩa
			var plate := P.cylinder(board_item.get_parent(), 0.09, 0.012, board_item.position + Vector3(0, 0.0, 0.2), Color.WHITE)
			plate.name = "Dia"
			tw.tween_property(paw_r, "position", _at(board_slices[0], 0.03) + Vector3(0.05, 0, -0.05), 0.15)
			for s in board_slices:
				tw.parallel().tween_property(s, "position", plate.position + Vector3(randf_range(-0.04, 0.04), 0.02, randf_range(-0.03, 0.03)), 0.35)
			tw.parallel().tween_property(paw_r, "position", _at(plate, 0.05), 0.35)
			tw.tween_property(paw_r, "position", PAW_R_REST, 0.2)
		"xe":  # xẻ dọc ổ bánh, nắp trên mở ra
			tw.tween_property(paw_r, "position", _at(work_loaf, 0.06) + Vector3(-0.1, 0, 0), 0.15)
			tw.tween_property(paw_r, "position", _at(work_loaf, 0.06) + Vector3(0.12, 0, 0), 0.35)
			tw.parallel().tween_property(work_parts.top, "rotation:x", -0.7, 0.35)
			tw.tween_property(paw_r, "position", PAW_R_REST, 0.2)
			_sound("play", "crunch")
		"pate":  # quệt pate dọc ruột bánh
			tw.tween_property(paw_r, "position", _at(pate_jar, 0.08), 0.15)
			tw.tween_property(paw_r, "position", _at(work_loaf, 0.05) + Vector3(-0.08, 0, 0), 0.2)
			tw.tween_callback(func(): work_parts.pate.visible = true; work_parts.pate.scale = Vector3(0.1, 1, 1))
			tw.tween_property(paw_r, "position", _at(work_loaf, 0.05) + Vector3(0.09, 0, 0), 0.3)
			tw.parallel().tween_property(work_parts.pate, "scale", Vector3.ONE, 0.3)
			tw.tween_property(paw_r, "position", PAW_R_REST, 0.2)
		"kep":  # gắp chả và thịt từ bát bỏ vào ổ
			for k in ["cha", "thit"]:
				var bowl: Node3D = rap_bowls[k]
				tw.tween_property(paw_r, "position", _at(bowl, 0.06), 0.18)
				tw.tween_property(paw_r, "position", _at(work_loaf, 0.07), 0.18)
				tw.tween_callback(func(): work_parts[k].visible = true)
			tw.tween_property(paw_r, "position", PAW_R_REST, 0.2)
		"them_rau":
			var bowl: Node3D = rap_bowls.rau
			tw.tween_property(paw_l, "position", _at(bowl, 0.06), 0.18)
			tw.tween_property(paw_l, "position", _at(work_loaf, 0.08), 0.2)
			tw.tween_callback(func(): work_parts.rau.visible = true)
			tw.tween_property(paw_l, "position", PAW_L_REST, 0.2)
		"tuong":  # chai nước tương nghiêng rưới
			var s0 := sauce.position
			tw.tween_property(sauce, "position", work_loaf.position + Vector3(0.08, 0.15, 0), 0.25)
			tw.parallel().tween_property(paw_r, "position", _at_world(work_loaf.global_position + Vector3(0.1, 0.15, 0.03)), 0.25)
			tw.tween_property(sauce, "rotation:z", 2.0, 0.2)
			tw.tween_callback(func(): drops.global_position = work_loaf.global_position + Vector3(0, 0.12, 0); drops.restart())
			tw.tween_property(sauce, "position:x", work_loaf.position.x - 0.08, 0.3)
			tw.tween_property(sauce, "rotation:z", 0.0, 0.15)
			tw.tween_property(sauce, "position", s0, 0.25)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.25)
			_sound("play", "sauce")
		"goi":  # giấy gói quấn quanh ổ
			paper.visible = true
			paper.scale = Vector3(0.1, 0.1, 0.1)
			tw.tween_property(paw_l, "position", _at(paper, 0.05) + Vector3(-0.06, 0, 0), 0.15)
			tw.parallel().tween_property(paw_r, "position", _at(paper, 0.05) + Vector3(0.06, 0, 0), 0.15)
			tw.tween_property(paper, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK)
			tw.parallel().tween_property(paw_l, "position", _at(paper, 0.08) + Vector3(-0.02, 0, 0), 0.35)
			tw.parallel().tween_property(paw_r, "position", _at(paper, 0.08) + Vector3(0.02, 0, 0), 0.35)
			tw.tween_property(paw_l, "position", PAW_L_REST, 0.2)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.2)
			_sound("play", "wrap")
		"bo_vao":  # đẩy ổ đã gói vào kệ tủ kính
			var slot := case_slots[made]
			tw.tween_property(paw_r, "position", _at(paper, 0.04), 0.15)
			tw.tween_property(paper, "global_position", slot.global_position, 0.35).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(paw_r, "position", _at_world(slot.global_position + Vector3(0, 0.04, -0.05)), 0.35)
			tw.tween_property(paw_r, "position", PAW_R_REST, 0.2)
	tw.tween_interval(0.05)
	return tw


func _at_world(p: Vector3) -> Vector3:
	return paw_rig.to_local(p)


# ---------------------------------------------------------------- trạng thái đồ ở trạm

func _reset_kneading() -> void:
	heap.visible = false
	dough.visible = false
	dough.scale = Vector3.ONE
	for b in balls:
		b.visible = false
	for l in raw_loaves:
		l.visible = false
	for s in slashes:
		s.visible = false


func _setup_board(kind: String) -> void:
	var board_top: Vector3 = stations.thot.work
	if board_item:
		board_item.queue_free()
	for s in board_slices:
		s.queue_free()
	board_slices.clear()
	board_item = Node3D.new()
	add_child(board_item)
	board_item.position = board_top + Vector3(0, 0.0, -0.02)
	var slice_col := P.LEAF
	match kind:
		"rau":
			for i in 7:
				P.sphere(board_item, 0.035, Vector3(-0.09 + i * 0.03, 0.03, randf_range(-0.02, 0.02)), P.LEAF.lerp(P.LEAF_DARK, randf()))
		"cha":
			var core := P.cylinder(board_item, 0.045, 0.2, Vector3(0, 0.045, 0), P.CHA)
			core.rotation_degrees.z = 90
			var wrap := P.cylinder(board_item, 0.05, 0.21, Vector3(0, 0.045, 0), P.LEAF_DARK)
			wrap.rotation_degrees.z = 90
			wrap.name = "La"
			slice_col = P.CHA
		"thit":
			P.sphere(board_item, 0.06, Vector3(0, 0.045, 0), P.HAM, Vector3(1.6, 0.8, 1.0))
			slice_col = P.HAM
	for i in 3:
		var s := P.cylinder(self, 0.035, 0.012, board_top + Vector3(0.07 - i * 0.05, 0.012, 0.05), slice_col, 12)
		s.visible = false
		board_slices.append(s)


func _clear_board() -> void:
	if board_item:
		board_item.queue_free()
		board_item = null
	for s in board_slices:
		s.queue_free()
	board_slices.clear()
	var plate := get_node_or_null("Dia")
	if plate:
		plate.queue_free()


func _refresh_rap() -> void:
	rap_tray.visible = loaves_on_rap > 0
	for i in rap_loaves.size():
		rap_loaves[i].visible = i < loaves_on_rap
		(rap_loaves[i].material_override as StandardMaterial3D).albedo_color = P.BURNT if bread_burnt else P.CRUST
	for k in rap_bowls:
		rap_bowls[k].get_child(1).visible = on_rap[k]
	(work_parts.base.material_override as StandardMaterial3D).albedo_color = P.BURNT if bread_burnt else P.CRUST
	(work_parts.top.get_child(0).material_override as StandardMaterial3D).albedo_color = P.BURNT if bread_burnt else P.CRUST


# ---------------------------------------------------------------- dựng phòng và trạm

func _build_room(room: Node3D) -> void:
	# Sàn gạch bông kem xen hồng như thẻ p_soche, tường vàng nhạt, chân tường gạch men xanh
	for x in range(-4, 4):
		for z in range(-3, 3):
			var c := Color("#F3E9D8") if (x + z) % 2 == 0 else Color("#EBD6C0")
			Blocks.box(room, Vector3(0.98, 0.04, 0.98), Vector3(x + 0.5, -0.02, z + 0.5), c)
			Blocks.box(room, Vector3(0.18, 0.042, 0.18), Vector3(x + 0.5, -0.02, z + 0.5), Color("#E39AA0") if (x + z) % 2 == 0 else Color("#7FB7A4"))
	var floor_body := StaticBody3D.new()
	room.add_child(floor_body)
	var fs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(10, 0.2, 8)
	fs.shape = fb
	fs.position.y = -0.1
	floor_body.add_child(fs)

	Blocks.solid_box(room, Vector3(7.6, 3.0, 0.2), Vector3(0, 1.5, -2.5), Color("#F2D9A6"))
	Blocks.solid_box(room, Vector3(0.2, 3.0, 5.2), Vector3(-3.8, 1.5, 0), Color("#EBCB8E"))
	Blocks.solid_box(room, Vector3(0.2, 3.0, 5.2), Vector3(3.8, 1.5, 0), Color("#EBCB8E"))
	Blocks.box(room, Vector3(7.6, 0.6, 0.02), Vector3(0, 0.3, -2.39), Color("#7FB7A4"))
	for i in 16:
		Blocks.box(room, Vector3(0.02, 0.6, 0.025), Vector3(-3.75 + i * 0.5, 0.3, -2.38), Color("#5F978A"))
	# Cửa sổ sau bếp, nắng chiếu vào
	Blocks.box(room, Vector3(1.2, 0.8, 0.03), Vector3(-1.75, 1.75, -2.38), Color("#BFE3EE"))
	Blocks.box(room, Vector3(1.3, 0.06, 0.06), Vector3(-1.75, 1.33, -2.36), Color("#8A5A30"))
	Blocks.box(room, Vector3(0.05, 0.8, 0.04), Vector3(-1.75, 1.75, -2.36), Color("#8A5A30"))
	# Lịch treo tường, kệ treo nồi
	Blocks.box(room, Vector3(0.4, 0.55, 0.02), Vector3(2.6, 1.6, -2.38), Color("#FFF8EA"))
	Blocks.box(room, Vector3(0.4, 0.12, 0.022), Vector3(2.6, 1.82, -2.37), P.RED)
	# Đèn thả đỏ như thẻ p_soche
	for x in [-1.6, 1.4]:
		Blocks.box(room, Vector3(0.01, 0.8, 0.01), Vector3(x, 2.6, -0.2), Color("#333333"))
		var shade := CylinderMesh.new()
		shade.top_radius = 0.04
		shade.bottom_radius = 0.2
		shade.height = 0.2
		shade.radial_segments = 16
		Blocks.mesh(room, shade, Vector3(x, 2.15, -0.2), P.RED)
	# Tủ kính phía trước (camera nhìn xuyên qua) và quầy gỗ thấp bên phải
	P.glass_case(room, Vector3(-1.95, 0, 2.0), 2.4)
	var counter := Blocks.solid_box(room, Vector3(2.8, 0.45, 0.5), Vector3(2.2, 0.225, 2.05), P.WOOD_DARK, Blocks.LAYER_PROP)
	Blocks.box(counter, Vector3(2.84, 0.04, 0.54), Vector3(0, 0.24, 0), P.WOOD)
	Blocks.invisible_wall(room, Vector3(8, 2, 0.2), Vector3(0, 1, 2.45))
	# Rổ, thùng trang trí trên quầy
	P.cylinder(room, 0.14, 0.12, Vector3(1.6, 0.53, 2.05), Color("#9B6A3A"))
	P.cylinder(room, 0.08, 0.2, Vector3(2.9, 0.57, 2.05), Color("#3D5A80"))


func _station(id: String, title: String, use: Vector3, work: Vector3, cam_off: Vector3) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.34
	torus.rings = 24
	torus.ring_segments = 4
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	var m := P.own_mat(Color(1, 1, 1, 0.2))
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.position = use + Vector3(0, 0.02, 0)
	add_child(ring)
	# Camera cận cảnh đặt ngay trên đầu Bơ nhìn xuống bàn, như Bơ nhìn chân mình:
	# chỉ thấy một đoạn cẳng tay ngắn và bàn chân ở gần mép dưới khung hình.
	var back := Vector3(use.x - work.x, 0, use.z - work.z).normalized()
	var cam := work + back * CLOSE_BACK + Vector3.UP * CLOSE_UP
	var look := work - back * CLOSE_AHEAD
	stations[id] = {"name": title, "use": use, "work": work, "cam": cam, "look": look, "ring": ring}


func _build_stations(room: Node3D) -> void:
	# 1. Bao bột
	P.flour_sack(room, Vector3(-3.05, 0, -1.85))
	_station("bot", "Bao bột", Vector3(-3.05, 0, -1.2), Vector3(-3.05, 0.66, -1.85), Vector3(0.35, 0.45, 0.7))
	flour_puff = _particles(Vector3(-3.05, 0.7, -1.85), Color(1, 1, 1, 0.85), 24, 0.02, -0.6)

	# 2. Bàn nhồi: ụ bột, cục bột, 2 viên, 2 ổ sống, bình nước, khăn ủ, dao chia bột, cây cán bột
	var t := Vector3(-1.75, 0.75, -1.95)
	P.table(room, Vector3(1.3, 0.75, 0.7), Vector3(t.x, 0, t.z))
	var rp := P.cylinder(room, 0.025, 0.36, t + Vector3(0.45, 0.03, 0.1), Color("#E8C58A"))
	rp.rotation_degrees.z = 90
	_station("nhoi", "Bàn nhồi bột", Vector3(-1.75, 0, -1.15), t + Vector3(-0.05, 0, 0.05), Vector3(0.0, 0.55, 0.62))
	var c := Vector3(-1.8, 0.75, -1.9)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.1
	cone.height = 0.08
	heap = Blocks.mesh(self, cone, c + Vector3(0, 0.04, 0), Color.WHITE)
	dough = P.sphere(self, 0.07, c + Vector3(0, 0.05, 0), P.DOUGH)
	for i in 2:
		balls.append(P.sphere(self, 0.045, c + Vector3(0, 0.04, 0), P.DOUGH))
		var l := P.loaf(self, c + Vector3(-0.08 + i * 0.16, 0.035, 0.08), P.DOUGH)
		l.rotation_degrees = Vector3(0, 90, 90)
		raw_loaves.append(l)
		var sl := Node3D.new()
		l.add_child(sl)
		for k in 3:
			var cut := Blocks.box(sl, Vector3(0.006, 0.035, 0.03), Vector3(0.034, -0.05 + k * 0.05, 0), Color("#C9A877"))
			cut.rotation_degrees.x = 30
		slashes.append(sl)
	jug = Node3D.new()
	jug.position = c + Vector3(0.35, 0.0, -0.15)
	add_child(jug)
	P.cylinder(jug, 0.045, 0.14, Vector3(0, 0.07, 0), P.WATER)
	P.cylinder(jug, 0.04, 0.1, Vector3(0, 0.05, 0), Color(0.45, 0.7, 0.9, 0.7))
	stream = P.cylinder(self, 0.008, 0.18, c + Vector3(0.02, 0.12, 0), P.WATER)
	cloth = Blocks.box(self, Vector3(0.24, 0.02, 0.24), c + Vector3(0, 0.15, 0), Color("#E8D9C2"))
	cutter = P.knife(self)
	cutter.position = c + Vector3(-0.35, 0.01, -0.1)
	_reset_kneading()
	stream.visible = false
	cloth.visible = false

	# 3. Lò gạch
	var oven := P.oven(room, Vector3(0.35, 0, -1.85))
	_station("lo", "Lò gạch", Vector3(0.35, 0, -0.85), Vector3(0.35, 0.55, -1.25), Vector3(0.25, 0.35, 0.85))
	# Cửa và lửa phải động nên đưa ra khỏi phòng (phòng bị gộp mesh)
	oven_door = oven.get_node("Cua")
	oven_door.reparent(self)
	oven_fire = oven.get_node("Lua")
	oven_fire.reparent(self)
	# Khay nằm trong một node đặt ở tâm lò: "position:z" = 0,15 là trong lò, 0,75 là ngoài miệng lò
	var holder := Node3D.new()
	holder.position = Vector3(0.35, 0, -1.85)
	add_child(holder)
	oven_tray = P.tray(holder, Vector3(0, 0.44, 0.75))
	for i in 2:
		oven_loaves.append(P.loaf(oven_tray, Vector3(0, 0.04, -0.05 + i * 0.1), P.DOUGH))
	oven_tray.visible = false
	oven_label = Blocks.label(self, "", Vector3(0.35, 1.55, -1.2), 32)
	spray = Node3D.new()
	spray.position = Vector3(0.95, 0.4, -1.2)
	add_child(spray)
	P.cylinder(spray, 0.03, 0.12, Vector3(0, 0.06, 0), Color.WHITE)
	P.cylinder(spray, 0.012, 0.05, Vector3(0, 0.14, 0), P.RED)
	Blocks.box(room, Vector3(0.3, 0.38, 0.3), Vector3(0.95, 0.19, -1.25), Color("#7A6A5E"))
	mist = _particles(Vector3(0.35, 0.65, -1.3), Color(1, 1, 1, 0.5), 30, 0.025, 0.2)
	smoke = _particles(Vector3(0.35, 1.0, -1.2), Color(0.25, 0.25, 0.25, 0.6), 30, 0.05, 0.4)
	smoke.one_shot = false
	smoke.lifetime = 1.6
	smoke.explosiveness = 0.0
	smoke.emitting = false

	# 4. Kệ nguyên liệu: rổ rau, đòn chả lụa gói lá, khúc thịt nguội
	P.shelf(room, Vector3(2.5, 0, -2.05), 1.7)
	var top := 0.72
	var items := {"rau": 1.95, "cha": 2.5, "thit": 3.05}
	for k in items:
		var x: float = items[k]
		var item := Node3D.new()
		item.position = Vector3(x, top, -2.0)
		add_child(item)
		match k:
			"rau":
				P.cylinder(item, 0.13, 0.08, Vector3(0, 0.04, 0), Color("#9B6A3A"))
				for i in 6:
					P.sphere(item, 0.045, Vector3(cos(i * 1.05) * 0.06, 0.1, sin(i * 1.05) * 0.06), P.LEAF)
			"cha":
				var cl := P.cylinder(item, 0.06, 0.22, Vector3(0, 0.06, 0), P.LEAF_DARK)
				cl.rotation_degrees.z = 90
				for i in 3:
					var band := P.cylinder(item, 0.062, 0.01, Vector3(-0.06 + i * 0.06, 0.06, 0), Color("#C9A877"))
					band.rotation_degrees.z = 90
			"thit":
				P.sphere(item, 0.08, Vector3(0, 0.06, 0), P.HAM, Vector3(1.3, 0.8, 1))
		shelf_items[k] = item
		var title: String = {"rau": "Rổ rau", "cha": "Chả lụa", "thit": "Thịt nguội"}[k]
		_station(k, title, Vector3(x, 0, -1.4), item.position + Vector3(0, 0.05, 0), Vector3(-0.1, 0.4, 0.6))

	# 5. Bàn thớt
	var bt := Vector3(3.0, 0.75, 0.4)
	P.table(room, Vector3(0.8, 0.75, 1.1), Vector3(bt.x, 0, bt.z))
	P.board(room, bt + Vector3(-0.05, 0, 0))
	_station("thot", "Thớt", Vector3(2.15, 0, 0.4), bt + Vector3(-0.05, 0.05, 0), Vector3(-0.6, 0.45, 0.3))
	board_knife = P.knife(self)
	board_knife.position = bt + Vector3(-0.1, 0.06, -0.32)
	drops = _particles(bt + Vector3(-0.05, 0.3, 0), Color(0.5, 0.75, 0.95, 0.8), 30, 0.012, -3.0)
	drops.direction = Vector3.DOWN
	drops.spread = 15.0

	# 6. Bàn ráp: khay bánh, 3 bát nhân, hũ pate, chai nước tương, ổ đang ráp
	var rt := Vector3(0.0, 0.75, 0.55)
	P.table(room, Vector3(1.5, 0.75, 0.7), Vector3(rt.x, 0, rt.z))
	_station("rap", "Bàn ráp bánh", Vector3(0.0, 0, 1.3), rt + Vector3(0, 0.02, 0.05), Vector3(0.0, 0.5, 0.6))
	rap_tray = P.tray(self, rt + Vector3(-0.5, 0.01, -0.1))
	for i in 2:
		rap_loaves.append(P.loaf(rap_tray, Vector3(0, 0.04, -0.05 + i * 0.1)))
	var bowl_x := {"rau": 0.35, "cha": 0.5, "thit": 0.65}
	for k in bowl_x:
		var bowl := Node3D.new()
		bowl.position = rt + Vector3(bowl_x[k] - 0.1, 0, -0.15)
		add_child(bowl)
		P.cylinder(bowl, 0.06, 0.04, Vector3(0, 0.02, 0), Color.WHITE)
		var fill := P.cylinder(bowl, 0.05, 0.02, Vector3(0, 0.035, 0), {"rau": P.LEAF, "cha": P.CHA, "thit": P.HAM}[k])
		fill.visible = false
		rap_bowls[k] = bowl
	pate_jar = Node3D.new()
	pate_jar.position = rt + Vector3(-0.25, 0, -0.2)
	add_child(pate_jar)
	P.cylinder(pate_jar, 0.04, 0.06, Vector3(0, 0.03, 0), Color("#E0B020"))
	P.cylinder(pate_jar, 0.041, 0.02, Vector3(0, 0.04, 0), P.RED)
	sauce = Node3D.new()
	sauce.position = rt + Vector3(0.3, 0, 0.15)
	add_child(sauce)
	P.cylinder(sauce, 0.022, 0.12, Vector3(0, 0.06, 0), Color("#5A2E1A"))
	P.cylinder(sauce, 0.012, 0.04, Vector3(0, 0.14, 0), P.RED)
	work_loaf = Node3D.new()
	work_loaf.position = rt + Vector3(0.0, 0.0, 0.08)
	add_child(work_loaf)
	work_parts.base = P.loaf(work_loaf, Vector3(0, 0.03, 0))
	work_parts.base.scale = Vector3(1.2, 1.3, 0.75)
	var top_half := Node3D.new()
	top_half.position = Vector3(0, 0.045, -0.035)
	work_loaf.add_child(top_half)
	var lid := P.loaf(top_half, Vector3(0, 0.0, 0.035))
	lid.scale = Vector3(0.7, 1.25, 0.5)
	work_parts.top = top_half
	work_parts.pate = Blocks.box(work_loaf, Vector3(0.2, 0.008, 0.035), Vector3(0, 0.052, 0), P.PATE)
	work_parts.cha = Blocks.box(work_loaf, Vector3(0.19, 0.012, 0.04), Vector3(0, 0.062, -0.004), P.CHA)
	work_parts.thit = Blocks.box(work_loaf, Vector3(0.18, 0.012, 0.04), Vector3(0, 0.072, 0.004), P.HAM)
	var greens := Node3D.new()
	work_loaf.add_child(greens)
	for i in 5:
		P.sphere(greens, 0.016, Vector3(-0.08 + i * 0.04, 0.085, 0), P.LEAF)
	work_parts.rau = greens
	work_loaf.visible = false
	_refresh_rap()

	# 7. Tủ kính: 2 chỗ xếp ổ đã gói, giấy gói
	_station("tu", "Tủ kính", Vector3(-2.05, 0, 1.25), Vector3(-2.05, 0.6, 1.95), Vector3(0.3, 0.45, -0.75))
	for i in LOAVES:
		var slot := Node3D.new()
		slot.position = Vector3(-2.45 + i * 0.5, 0.56, 2.0)
		add_child(slot)
		var w := Blocks.box(slot, Vector3(0.24, 0.07, 0.09), Vector3(0, 0.03, 0), Color("#FFF8EA"))
		w.rotation_degrees.y = 8
		Blocks.box(slot, Vector3(0.05, 0.075, 0.095), Vector3(0.0, 0.03, 0), P.RED)
		slot.visible = false
		case_slots.append(slot)
	paper = Blocks.box(self, Vector3(0.24, 0.07, 0.09), Vector3(-2.05, 0.6, 1.8), Color("#FFF8EA"))
	paper.visible = false


func _particles(pos: Vector3, color: Color, amount: int, size: float, gravity_y: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 0.85
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = Blocks.mat(color)
	p.mesh = m
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, gravity_y, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	add_child(p)
	return p


# ---------------------------------------------------------------- môi trường, phím

func _setup_environment() -> void:
	AnhSang.build(self, "bep_sang")  # nắng xiên qua cửa sổ sau: scripts/anh_sang.gd
	for x in [-1.6, 1.4]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 1.95, -0.2)
		lamp.light_color = Color("#FFC98A")
		lamp.light_energy = 0.8
		lamp.omni_range = 4.0
		add_child(lamp)
	var fire := OmniLight3D.new()
	fire.position = Vector3(0.35, 0.6, -1.0)
	fire.light_color = Color("#FF8A3A")
	fire.light_energy = 0.6
	fire.omni_range = 1.6
	add_child(fire)


func _setup_input() -> void:
	_action("move_forward", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_action("move_back", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_action("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("jump", [KEY_SPACE], [JOY_BUTTON_A], [])
	_action("sprint", [KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_X], [])
	_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START], [])
	_action("interact", [KEY_E, KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_B], [])


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


# ---------------------------------------------------------------- tự chơi

## Bot đi theo gợi ý _suggest(): đi theo lối giữa các bàn tới trạm, bấm E, bấm qua từng bước.
## Lối đi: bếp chia 3 dải theo Z (sau, giữa, trước). Dải giữa có bàn ráp và bàn thớt,
## nên muốn qua dải giữa phải đi theo lối trái (x = -1.5) hoặc lối phải (x = 1.5).
func _bot_step(delta: float) -> void:
	if not seq.is_empty():
		_bot_release()
		if not busy:
			_bot_wait -= delta
			if _bot_wait <= 0.0:
				_bot_wait = 0.12
				_press()
		return
	var goal := _suggest()
	if oven_state == "nuong" and holding == "":
		goal = "lo"  # bot đứng canh lò cho khỏi cháy (người chơi thì tranh thủ đi lấy nhân)
	if goal == "":
		_bot_release()
		return
	if goal == "lo" and oven_state == "nuong" and _near_station() == "lo":
		_bot_release()  # đứng chờ bánh chín
		return
	if goal != _bot_goal:
		_bot_goal = goal
		_bot_path = _route(player.global_position, stations[goal].use)
	if _bot_path.is_empty():
		_bot_release()
		if _near_station() == goal:
			_bot_wait -= delta
			if _bot_wait <= 0.0:
				_bot_wait = 0.25
				_bot_goal = ""
				_interact()
		else:
			_bot_path = _route(player.global_position, stations[goal].use)
		return
	var p := player.global_position
	var next: Vector3 = _bot_path[0]
	var d := Vector2(next.x - p.x, next.z - p.z)
	if d.length() < (0.12 if _bot_path.size() == 1 else 0.25):
		_bot_path.pop_front()
		return
	var dir := d.normalized() * clampf(d.length() * 2.5, 0.35, 1.0)
	_bot_axis("move_right", "move_left", dir.x)
	_bot_axis("move_back", "move_forward", dir.y)


func _bot_axis(pos_action: String, neg_action: String, v: float) -> void:
	if v > 0.01:
		Input.action_press(pos_action, v)
		Input.action_release(neg_action)
	elif v < -0.01:
		Input.action_press(neg_action, -v)
		Input.action_release(pos_action)
	else:
		Input.action_release(pos_action)
		Input.action_release(neg_action)


func _bot_release() -> void:
	for a in ["move_right", "move_left", "move_forward", "move_back"]:
		Input.action_release(a)


func _route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var path: Array[Vector3] = []
	var band_from := _band(from.z)
	var band_to := _band(to.z)
	if band_from == band_to and band_from != 1:
		path.append(to)
		return path
	var lane := -1.5 if absf(from.x + 1.5) + absf(to.x + 1.5) < absf(from.x - 1.5) + absf(to.x - 1.5) else 1.5
	path.append(Vector3(lane, 0, from.z))
	path.append(Vector3(lane, 0, to.z))
	path.append(to)
	return path


func _band(z: float) -> int:
	return 0 if z < -0.1 else (1 if z < 1.05 else 2)
