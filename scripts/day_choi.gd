extends Node3D
## Màn dạy chơi "Sân sau lò bánh" (B1, Sang duyệt trang thiết kế 23/10/2026:
## https://claude.ai/artifact/RRG8xqvcN7K1vHJtCUaJZY). 5 giờ 40 sáng thứ Hai, chừng 3 phút, không đồng hồ, không thua.
## Năm trạm theo thứ tự: 1 chạy quanh cây khế, 2 nhảy thùng lên mái kho đẩy rổ tre xuống, 3 chui gầm ba gác,
## 4 rón rén qua mèo Bột ngủ trên bao bột, 5 lấy ổ bánh ở cửa sổ bếp giao cho Chú Tư ở cổng sau.
## Hồ sơ mới bấm Bắt đầu thì vào đây trước bếp Thứ Hai (PlayMode.start_day), xong hay bỏ qua thì lưu "da_tap".
## Tập lại: mục "Tập chơi" ở màn Chọn màn. Bỏ qua: menu Esc > "Bỏ qua tập".
##
## Toạ độ cảnh: x = x sơ đồ (đông), z = y sơ đồ (nam), sân 14 × 10 m, tường sau lò ở z = 0, cổng sau ở x = 0.
## Đồ mới của sân (mặt sau lò, kho củi, cổng, tường rào, cây khế, bồn kiểng): model Sang duyệt 23/10/2026
## (https://claude.ai/artifact/TX3MsCCPYfw4SdBqzAsixc, tools/day_choi/), va chạm vẫn là hộp vô hình đúng số đo.
## Đồ cũ dùng lại: thùng gỗ, ba gác, bao gạo, lu nước, rổ tre, Cô Ba, Chú Tư, Bột (giống khoai môn của Hội mèo).
##
## Chạy thử: godot --headless --path . -- --autotest-tap   (in "DAY CHOI TEST OK")

const PlayerScript := preload("res://scripts/player.gd")
const CameraRigScript := preload("res://scripts/camera_rig.gd")
const HudScript := preload("res://scripts/hud.gd")
const Main := preload("res://scripts/main.gd")
const T = preload("res://scripts/ui/ui_theme.gd")
const M_LU := preload("res://assets/models/gio/lu_nuoc.glb")
const M_RO := preload("res://assets/models/bep/ro_tre.glb")
const M_MAT_SAU := preload("res://assets/models/day_choi/mat_sau_lo.glb")
const M_KHO_CUI := preload("res://assets/models/day_choi/kho_cui.glb")
const M_CONG := preload("res://assets/models/day_choi/cong_sau_mo.glb")
const M_RAO := preload("res://assets/models/day_choi/tuong_rao.glb")      ## đoạn 2 m, mặt trước nhìn +z
const M_KHE := preload("res://assets/models/day_choi/cay_khe.glb")
const M_BON := preload("res://assets/models/day_choi/bon_kieng.glb")      ## đoạn 2 m × 0,6 m

const SAVE_KEY := "da_tap"                 ## mục [chung] trong hồ sơ: đã tập (hoặc bỏ qua) rồi
const IDLE_NAG := 15.0                     ## đứng yên chừng này thì Cô Ba nhắc
const START := Vector3(7.1, 0.2, 1.0)      ## Bơ bước ra từ cửa sau
const DOOR := Vector3(7.1, 0, 0)
const WINDOW := Vector3(4.0, 0, 0)         ## cửa sổ bếp: Cô Ba đưa bánh qua bậu
const TREE := Vector3(7.0, 0, 5.1)
const LU := Vector3(5.7, 0, 4.2)
const SHED := Rect2(11.5, 0.0, 2.5, 4.0)   ## kho củi (x, z, rộng, sâu), nóc 1,8 m
const SHED_TOP := 1.8
const CRATES := [[Vector3(11.95, 0, 5.25), 1], [Vector3(12.65, 0, 4.65), 2], [Vector3(13.35, 0, 4.35), 3]]  ## [chỗ, số thùng chồng]
const CRATE := 0.45                        ## thùng gỗ phố 0,8 m thu nhỏ còn 0,45 (mỗi bậc)
const BASKET := Vector3(13.0, SHED_TOP, 1.5)
const BED := Rect2(3.0, 6.7, 7.6, 0.6)     ## bồn kiểng, cao 0,5 m
const BA_GAC := Vector3(11.9, 0, 7.0)      ## gầm thùng 0,32 m, x 10,55 → 12,65 chui được
const SACKS := Vector3(7.1, 0, 9.5)
const BOT_AT := Vector3(7.0, 0.44, 9.5)
const GATE_Z := Vector2(6.9, 8.3)          ## khoảng hở cổng sau trên tường tây
const GATE := Vector3(0.7, 0, 7.6)         ## vòng vàng chỗ giao
const CHU_TU := Vector3(-0.9, 0, 7.6)
const BOT_WAKE := 3.0                      ## Bột thức bao lâu rồi ngủ lại

const SKY_TOP := Color("#7E9FC8")          ## 5 giờ 40: trời xanh nhạt, chân trời vàng cam
const SKY_HORIZON := Color("#F2C99A")
const TILE := Color("#C46A48")
const PAW := Color("#F6C945")

## Lời từng trạm (trang thiết kế, mục "Năm trạm và lời Cô Ba"). nag = nhắc khi đứng yên.
const LINES := {
	"mo": "Bơ dậy rồi hả? Trời còn sớm, lò chưa nóng đâu. Ra sân sau tập chạy với cô chút cho dẻo chân nha!",
	"1": "Đi theo dấu chân vàng nè. Kéo chuột mà nhìn quanh sân.",
	"1_lu": "Giờ giữ Shift chạy một vòng cây khế coi!",
	"1_nag": "Bấm W là Bơ đi tới đó con.",
	"1_ok": "Lẹ dữ ha! Mai mốt giao bánh khỏi lo trễ.",
	"2": "Cái rổ tre của cô nằm trên mái kho củi. Nhảy lên mấy thùng gỗ, từng bậc một, đẩy nó xuống giùm cô.",
	"2_nag": "Giữ Space lâu thì nhảy cao hơn đó.",
	"2_rot": "Không sao, leo lại từ thùng thấp nhất.",
	"2_ok": "Chụp được rồi! Giỏi quá Bơ.",
	"3": "Xe chở bột của cô chắn lối rồi. Gầm xe thấp, giữ C mà chui qua.",
	"3_nag": "Chạy thẳng vô gầm là Bơ tự cúi người, hay giữ C cũng được.",
	"3_ok": "Gầm thấp cỡ nào Bơ cũng lọt ha.",
	"4": "Suỵt! Thằng Bột nhà bên ngủ trên bao bột kìa. Giữ Z mà đi rón rén, đừng chạy nha.",
	"4_thuc": "Ui, nó thức rồi. Chờ nó ngủ lại rồi đi êm hơn nha.",
	"4_nag": "Giữ Z rồi đi qua chỗ Bột nằm đó con.",
	"4_ok": "Êm ru! Thằng Mực ở hẻm 42 khó hơn chút, mà cách đi y chang vậy đó.",
	"5": "Chú Tư ghé lấy ổ pate trước khi mở sạp nè. Lại cửa sổ lấy bánh đi Bơ.",
	"5_cam": "Mũi tên đỏ trên đầu chỉ chỗ khách. Tới vòng vàng thì bấm E đưa bánh.",
	"5_nag": "Cổng sau ở góc bên kia kìa, coi mũi tên đỏ đó.",
	"5_chutu": "Bánh còn nóng hổi! Cảm ơn Bơ nha.",
	"5_ok": "Giao kịp giờ, còn dư giờ, bánh còn nguyên là đủ ba sao đó.",
	"ket": "Xong bài rồi! Lò nóng rồi đó, vô làm mẻ bánh đầu tiên với cô nha.",
}
## Phím hiện ở thẻ mẹo của từng trạm
const KEYS := {
	1: [["W A S D", "chạy"], ["Chuột", "nhìn quanh"], ["Shift", "chạy nhanh"]],
	2: [["Space", "nhảy"], ["giữ Space", "nhảy cao hơn"]],
	3: [["C", "giữ để chui"]],
	4: [["Z", "giữ để rón rén"]],
	5: [["E", "giao bánh"]],
}
const TITLES := {1: "Chạy và nhìn quanh", 2: "Nhảy lên mái kho", 3: "Chui gầm ba gác", 4: "Rón rén qua Bột", 5: "Giao thử cho Chú Tư"}
## Cô Ba đứng đâu ở mỗi trạm (đi bộ tới, không có va chạm)
const CO_BA_SPOT := {0: Vector3(5.3, 0, 1.7), 1: Vector3(5.3, 0, 1.7), 2: Vector3(10.6, 0, 5.9),
	3: Vector3(9.9, 0, 6.2), 4: Vector3(4.6, 0, 6.2)}

var player: CharacterBody3D
var rig: Node3D
var hud: CanvasLayer
var co_ba: Nguoi
var chu_tu: Nguoi
var bot: MeoNpc
var station := 0          ## 0 mở màn · 1..5 trạm · 6 xong
var done := false
var bot_awake := 0.0      ## > 0: Bột đang thức, đếm ngược
var bot_woke := 0         ## số lần Bột bị đánh thức (test đọc)
var under_cart := false   ## đã ở dưới gầm ba gác
var carrying := false
var lu_reached := false
var ring_seen := {}       ## 4 điểm quanh cây khế đã chạy qua
var _idle := 0.0
var _fall_said := -10.0
var _t := 0.0
var _air_top := 0.0
var _basket: Node3D
var _basket_fall := -1.0
var _paws: MultiMeshInstance3D
var _say_card: PanelContainer
var _say_who: Label
var _say_text: Label
var _say_t := 0.0
var _learned: Control
var _autotest := false
var _co_ba_path: Array = []


func _ready() -> void:
	Main._setup_input()
	_autotest = "--autotest-tap" in OS.get_cmdline_user_args()
	if _autotest:
		GameState.use_test_save("user://luu_game_autotest_tap.cfg")
	_setup_environment()
	_build_yard()
	Blocks.merge_static(self)
	_build_models()     # model có xương, glb: sau khi gộp (gộp sẽ ăn mất mesh có xương)

	player = PlayerScript.new()
	player.name = "Bo"
	player.position = START
	player.rotation.y = PI    # quay mặt ra sân (về phía nam, +z)
	add_child(player)
	rig = CameraRigScript.new()
	rig.name = "CameraRig"
	rig.target = player
	rig.yaw = PI
	add_child(rig)
	player.camera_rig = rig
	player.noise_made.connect(_on_noise)
	player.deliver_finished.connect(_on_delivered)
	co_ba.look_target = player
	chu_tu.look_target = player

	hud = HudScript.new()
	hud.help = HudTamDung.HELP_PHO
	hud.help_note = "Màn tập: không có đồng hồ, không mất sao. Bỏ qua được trong menu này."
	add_child(hud)
	hud.restart_pressed.connect(func(): get_tree().paused = false; get_tree().reload_current_scene())
	hud.menu_pressed.connect(func(): PlayMode.back_to_menu(get_tree()))
	player.stance_changed.connect(hud.set_stance)
	_add_skip_button.call_deferred()
	_build_ui()
	var snd := get_node_or_null("/root/Sound")
	if snd:
		player.jumped.connect(func(): snd.play("jump", 0.0, randf_range(0.96, 1.06)))
		player.landed.connect(func(): snd.play("land"))
	GameSettings.apply_graphics(get_tree())
	GameSettings.apply_camera(get_tree())
	GameSettings.watch_camera(get_tree())
	_start()
	if _autotest:
		_autotest_run.call_deferred()


func _start() -> void:
	player.can_move = true
	player.carrying = false
	if not _autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.start_screen.visible = false
	hud.show_playing_ui(true)
	hud.progress_row.visible = false
	hud.timer_ring.visible = false
	hud.distance_pill.visible = false   # chỉ hiện ở trạm 5 (đi giao thử)
	hud.set_order(0, 1, "Màn tập · Sân sau lò bánh", "Tập, không tính giờ", Color("#D98E2B"), "Tập")
	hud.set_bread(false)
	hud.set_goal(Vector3.ZERO, false)
	_say("mo", 5.0)
	co_ba.play_once("vay", "dung_yen")
	get_tree().create_timer(0.1 if _autotest else 3.5).timeout.connect(func(): if station == 0: _begin(1))


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	if event.is_action_pressed("pause"):
		hud.set_pause_info("Màn tập · trạm %d/5 · %s" % [clampi(station, 1, 5), TITLES.get(clampi(station, 1, 5), "")])
		hud.toggle_pause()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_t += delta
	_update_say(delta)
	_update_co_ba(delta)
	_update_bot(delta)
	_update_basket(delta)
	if done or player == null:
		return
	var p := player.global_position
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.3
	_idle = 0.0 if moving else _idle + delta
	if _idle > IDLE_NAG and station >= 1 and station <= 5:
		_idle = 0.0
		_say("%d_nag" % station if LINES.has("%d_nag" % station) else str(station), 4.0)
	match station:
		1: _station_run(p)
		2: _station_jump(p)
		3: _station_crouch(p)
		4: _station_sneak(p)
		5: _station_deliver(p)
	if Input.is_action_just_pressed("deliver"):
		_interact()


# ---------------------------------------------------------------- các trạm

func _begin(n: int) -> void:
	station = n
	_idle = 0.0
	if n <= 5:
		hud.show_tip("Trạm %d/5 · %s" % [n, TITLES[n]], LINES[str(n)], _keys(KEYS[n]), 9.0)
		_say(str(n), 6.0)
		_walk_co_ba(n)
	_build_paws(n)
	if n == 5:
		co_ba.visible = false   # vào trong bếp, ra cửa sổ
		_co_ba_path.clear()
		co_ba.position = WINDOW + Vector3(0, 0, -0.45)
		co_ba.rotation.y = 0.0
		co_ba.visible = true
		co_ba.play("vay")
		hud.set_goal(WINDOW + Vector3(0, 1.4, 0.3))
		hud.distance_pill.visible = true
		hud.set_distance(player.global_position.distance_to(WINDOW), "Cửa sổ bếp")


func _ok(n: int) -> void:
	_say("%d_ok" % n, 4.0)
	co_ba.play_once("vui", "dung_yen")
	print("[tap] xong trạm %d lúc %.1fs" % [n, _t])
	_begin(n + 1)


func _station_run(p: Vector3) -> void:
	if not lu_reached:
		if Vector2(p.x - LU.x, p.z - LU.z).length() < 1.4:
			lu_reached = true
			_say("1_lu", 4.0)
			_build_paws(1)
		return
	# 4 điểm quanh cây khế (bắc, đông, nam, tây, cách gốc 1,9 m): chạy qua đủ là xong vòng
	var d := Vector2(p.x - TREE.x, p.z - TREE.z)
	if d.length() > 0.9 and d.length() < 3.2:
		var q := int(round(fposmod(atan2(d.y, d.x), TAU) / (PI / 2.0))) % 4
		ring_seen[q] = true
	if ring_seen.size() >= 4:
		_ok(1)


func _station_jump(p: Vector3) -> void:
	var on_floor := player.is_on_floor()
	if on_floor and p.y < 0.15 and _air_top > 0.8 and _t - _fall_said > 8.0:
		_fall_said = _t
		_say("2_rot", 3.0)
	_air_top = p.y if on_floor else maxf(_air_top, p.y)
	if on_floor and p.y < 0.15:
		_air_top = 0.0
	if _basket_fall < 0.0 and p.y > SHED_TOP - 0.2 and Vector2(p.x - BASKET.x, p.z - BASKET.z).length() < 0.8:
		_basket_fall = 0.0   # rổ lăn khỏi mái, rơi vào tay Cô Ba (_update_basket)


func _station_crouch(p: Vector3) -> void:
	# Gầm thùng ba gác: x 10,55 → 12,65, z 6,3 → 7,7. Ở dưới gầm rồi ra phía nam là xong.
	if p.x > BA_GAC.x - 1.35 and p.x < BA_GAC.x + 0.75 and absf(p.z - BA_GAC.z) < 0.7 and p.y < 0.3:
		under_cart = true
	if under_cart and p.z > BA_GAC.z + 0.85:
		_ok(3)
	elif p.z > BED.position.y + BED.size.y + 0.2 and not under_cart and _t - _fall_said > 10.0:
		_fall_said = _t   # vòng qua bồn kiểng thay vì chui: nhắc chui một lần, không chặn
		_say("3_nag", 4.0)


func _station_sneak(p: Vector3) -> void:
	if p.x < BOT_AT.x - 2.6 and p.z > BED.position.y and bot_awake <= 0.0:
		_ok(4)


func _station_deliver(p: Vector3) -> void:
	if not carrying:
		hud.set_distance(p.distance_to(WINDOW), "Cửa sổ bếp")
		if Vector2(p.x - WINDOW.x, p.z - 0.6).length() < 1.1:
			carrying = true
			player.carrying = true
			co_ba.play_once("cho_banh", "dung_yen")
			hud.set_order(0, 1, "Chú Tư · Cổng sau", "1 ổ pate · tập, không tính giờ", Color("#3D5A80"), "T")
			hud.set_bread(true, "1 ổ pate", 1.0)
			hud.set_goal(CHU_TU + Vector3(0, 1.8, 0))
			_say("5_cam", 5.0)
			_paws.visible = false
	else:
		hud.set_distance(p.distance_to(GATE), "Chú Tư")
		if _in_gate(p):
			hud.show_toast("Bấm E để đưa bánh", 0.3)


func _in_gate(p: Vector3) -> bool:
	return Vector2(p.x - GATE.x, p.z - GATE.z).length() < 1.3


func _interact() -> void:
	if station == 5 and carrying and _in_gate(player.global_position) and player.get("_act") == "":
		player.play_deliver("hand")
		chu_tu.play("cho_banh")


func _on_delivered(_kind: String) -> void:
	if station != 5 or done:
		return
	carrying = false
	player.carrying = false
	hud.set_bread(false)
	hud.set_goal(Vector3.ZERO, false)
	chu_tu.play_once("nhan_bao", "dung_cho")
	_say_as("Chú Tư", LINES["5_chutu"], 3.0)
	hud.show_toast("★ ★ ★", 2.5)
	get_tree().create_timer(0.1 if _autotest else 3.0).timeout.connect(func():
		_say("5_ok", 4.5)
		get_tree().create_timer(0.1 if _autotest else 4.5).timeout.connect(_finish))


func _finish() -> void:
	if done:
		return
	done = true
	station = 6
	print("[tap] xong màn tập lúc %.1fs" % _t)
	player.can_move = false
	_say("ket", 5.0)
	_learned.visible = true
	mark_done()
	if _autotest:
		return
	get_tree().create_timer(5.0).timeout.connect(_leave)


## Lưu đã tập; mẹo lần đầu "Gầm thấp" và "Tới nhà khách" coi như đã xem (mẹo Chó Mực vẫn giữ).
static func mark_done() -> void:
	GameState.set_global(SAVE_KEY, true)
	GameState.write_save()
	var seen := PackedStringArray(str(GameSettings.get_value("tips_seen")).split(",", false))
	for id in ["gam", "khach"]:
		if not id in seen:
			seen.append(id)
	GameSettings.set_value("tips_seen", ",".join(seen))


## Đi tiếp: đang trong mạch tuần thì vào bếp Thứ Hai, tập lại từ Chọn màn thì về màn Chọn màn.
func _leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	PlayMode.after_tutorial(get_tree())


func skip() -> void:
	mark_done()
	_leave()


# ---------------------------------------------------------------- Bột, rổ tre, Cô Ba

func _on_noise(pos: Vector3, radius: float) -> void:
	if station != 4 or bot == null:
		return
	# Hiền hơn Chó Mực: rón rén, chui không bao giờ làm Bột thức; đi thường, chạy, đáp mạnh thì thức.
	if radius <= player.noise_sneak + 0.01 or pos.distance_to(bot.global_position) > radius:
		return
	if bot_awake > 0.0:
		bot_awake = BOT_WAKE
		return
	bot_awake = BOT_WAKE
	bot_woke += 1
	bot.set_pose("ngoi")
	bot.say("Ngoaoo… ồn quá à!", 2.5)
	_say("4_thuc", 4.0)


func _update_bot(delta: float) -> void:
	if bot_awake <= 0.0:
		return
	bot_awake -= delta
	if bot_awake <= 0.0:
		bot.set_pose("ngu")


func _update_basket(delta: float) -> void:
	if _basket_fall < 0.0 or _basket == null:
		return
	_basket_fall += delta
	var k := clampf(_basket_fall / 1.1, 0.0, 1.0)
	var to: Vector3 = CO_BA_SPOT[2] + Vector3(0, 1.0, 0)
	var a := BASKET + Vector3(0, 0.05, 0)
	var pos := a.lerp(to, k)
	pos.y += sin(k * PI) * 0.8
	_basket.position = pos
	_basket.rotation.x = k * TAU
	if k >= 1.0:
		_basket.visible = false
		_basket_fall = -2.0
		_basket = null
		if station == 2:
			_ok(2)


func _walk_co_ba(n: int) -> void:
	if not CO_BA_SPOT.has(n):
		return
	var to: Vector3 = CO_BA_SPOT[n]
	_co_ba_path = [to]
	# Đi vòng phía bắc cây khế và bồn kiểng, không xuyên qua đồ
	if n == 2:
		_co_ba_path = [Vector3(9.5, 0, 2.2), to]
	elif n == 4:
		_co_ba_path = [Vector3(7.0, 0, 6.2), to]
	co_ba.play("di_bo")


func _update_co_ba(delta: float) -> void:
	if co_ba == null or _co_ba_path.is_empty():
		return
	var to: Vector3 = _co_ba_path[0]
	var d := to - co_ba.position
	d.y = 0.0
	if d.length() < 0.05:
		_co_ba_path.pop_front()
		if _co_ba_path.is_empty():
			co_ba.play("dung_yen")
			var look := player.global_position - co_ba.position
			co_ba.rotation.y = atan2(look.x, look.z)
		return
	var step := minf(d.length(), 1.6 * delta)
	co_ba.position += d.normalized() * step
	co_ba.rotation.y = lerp_angle(co_ba.rotation.y, atan2(d.x, d.z), minf(1.0, delta * 8.0))


# ---------------------------------------------------------------- lời thoại, giao diện riêng

func _say(id: String, secs := 4.0) -> void:
	_say_as("Cô Ba", LINES.get(id, id), secs)
	if co_ba and id != "mo" and not co_ba.busy():
		co_ba.play_once("noi", "dung_yen")


func _say_as(who: String, text: String, secs := 4.0) -> void:
	if _autotest:
		print("[tap] %s: %s" % [who, text])
	if _say_card == null:
		return
	_say_who.text = who
	_say_text.text = text
	_say_t = secs
	_say_card.visible = true
	_say_card.modulate.a = 1.0


func _update_say(delta: float) -> void:
	if _say_card == null or _say_t <= 0.0:
		return
	_say_t -= delta
	if _say_t < 0.4:
		_say_card.modulate.a = maxf(_say_t / 0.4, 0.0)
	if _say_t <= 0.0:
		_say_card.visible = false


func _keys(pairs: Array) -> Array:
	var pad := not Input.get_connected_joypads().is_empty()
	var out := []
	for k in pairs:
		var key: String = k[0]
		if pad:
			key = {"Space": "A", "giữ Space": "giữ A", "C": "B", "Z": "L3", "E": "Y", "Chuột": "Cần phải",
				"W A S D": "Cần trái", "Shift": "RB"}.get(key, key)
		out.append([key, k[1]])
	return out


## Lời Cô Ba (thẻ giấy giữa đáy màn hình) và thẻ "Bơ đã biết" lúc xong. Dựng ở đây, không sửa hud.gd.
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_say_card = PanelContainer.new()
	_say_card.add_theme_stylebox_override("panel", T.box(T.PAPER, 18, 16, T.INK, 3, 5))
	T.place(_say_card, 0.5, 0.0, Rect2(-250, 24, 600, 0))   # trên giữa: đáy màn hình đã có thẻ mẹo, phím
	_say_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_say_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_say_card.add_child(v)
	_say_who = T.label("Cô Ba", 16, T.RED, "bold")
	v.add_child(_say_who)
	_say_text = T.label("", 20, T.INK)
	_say_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say_text.custom_minimum_size.x = 560
	v.add_child(_say_text)
	_say_card.visible = false

	_learned = PanelContainer.new()
	_learned.add_theme_stylebox_override("panel", T.box(T.PAPER, 22, 26, T.INK, 4, 8))
	T.place(_learned, 0.5, 0.5, Rect2(-260, -200, 520, 0))
	layer.add_child(_learned)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	_learned.add_child(lv)
	lv.add_child(T.label("Bơ đã biết", 40, T.INK, "display"))
	for k in _keys([["W A S D", "chạy"], ["Shift", "chạy nhanh"], ["Space", "nhảy"], ["C", "chui"], ["Z", "rón rén"], ["E", "giao bánh"]]):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(hud._keycap(k[0], 15))
		h.add_child(T.label(k[1], 18, T.INK))
		lv.add_child(h)
	lv.add_child(T.label("Giữ R nếu Bơ bị kẹt. Esc mở menu và bảng Cách chơi.", 15, T.MUTED))
	_learned.visible = false


## Thêm nút "Bỏ qua tập" vào menu Esc (sau nút Tiếp tục), không sửa hud_tam_dung.gd.
func _add_skip_button() -> void:
	if hud.pause_screen == null:
		return
	for b: Button in hud.pause_screen.find_children("*", "Button", true, false):
		if b.text.strip_edges() == "Tiếp tục":
			var sk := T.button("  Bỏ qua tập, vào bếp", "secondary", 56, 19)
			sk.pressed.connect(func(): get_tree().paused = false; skip())
			b.get_parent().add_child(sk)
			b.get_parent().move_child(sk, b.get_index() + 1)
			T.wire_clicks(sk)
			return


# ---------------------------------------------------------------- dấu chân vàng

## Dấu chân vàng tới đích của trạm n (một MultiMesh, như dấu chân trong bếp). Trạm 5 không có: chỉ có mũi tên đỏ.
func _build_paws(n: int) -> void:
	if _paws == null:
		_paws = MultiMeshInstance3D.new()
		_paws.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var disc := CylinderMesh.new()
		disc.top_radius = 0.07
		disc.bottom_radius = 0.07
		disc.height = 0.01
		disc.radial_segments = 10
		disc.rings = 1
		mm.mesh = disc
		_paws.multimesh = mm
		_paws.material_override = Blocks.mat(PAW, true)
		add_child(_paws)
	var route: Array = []
	match n:
		1:
			route = [START, Vector3(7.1, 0, 2.6), LU + Vector3(0.6, 0, -0.4)] if not lu_reached else \
				[LU, TREE + Vector3(-1.9, 0, 0), TREE + Vector3(0, 0, 1.9), TREE + Vector3(1.9, 0, 0), TREE + Vector3(0, 0, -1.9), TREE + Vector3(-1.9, 0, 0)]
		2:
			route = [TREE + Vector3(1.9, 0, 0), Vector3(11.2, 0, 5.6), Vector3(11.95, CRATE, 5.25), Vector3(12.65, CRATE * 2, 4.65),
				Vector3(13.35, CRATE * 3, 4.35), Vector3(13.2, SHED_TOP, 3.4), BASKET]
		3:
			route = [Vector3(11.5, 0, 5.8), Vector3(11.5, 0, 6.2), Vector3(11.5, 0, 7.8), Vector3(11.3, 0, 8.6)]
		4:
			route = [Vector3(11.0, 0, 8.6), Vector3(8.4, 0, 8.2), Vector3(5.6, 0, 8.2), Vector3(3.6, 0, 8.4)]
	var xfs: Array = []
	var step := 0.45
	var side := 1.0
	for i in route.size() - 1:
		var a: Vector3 = route[i]
		var b: Vector3 = route[i + 1]
		var seg := b - a
		var flat := Vector3(seg.x, 0, seg.z)
		var count := maxi(1, int(seg.length() / step))
		var right := flat.normalized().cross(Vector3.UP) if flat.length() > 0.01 else Vector3.RIGHT
		for k in count:
			var p := a + seg * (float(k) / count) + right * 0.08 * side
			side = -side
			p.y = _ground_y(p) + 0.012
			xfs.append(Transform3D(Basis(), p))
	var mm := _paws.multimesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	_paws.visible = xfs.size() > 0


## Mặt đứng dưới một điểm trên đường dấu chân (thùng, mái kho, hay nền sân).
func _ground_y(p: Vector3) -> float:
	if p.y > 0.05:
		return p.y
	return 0.0


# ---------------------------------------------------------------- dựng cảnh

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SKY_TOP
	sky_mat.sky_horizon_color = SKY_HORIZON
	sky_mat.ground_horizon_color = SKY_HORIZON
	sky_mat.ground_bottom_color = Color("#8F8B80")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#B8C6DE")
	var compat := RenderingServer.get_rendering_device() == null
	env.ambient_light_energy = 0.4 if compat else 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR if compat else Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, 100, 0)  # nắng sớm thấp, từ phía đông chiếu xiên qua sân
	sun.light_color = Color("#FFC98A")
	sun.light_energy = 0.75 if compat else 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)


func _build_yard() -> void:
	# Nền gạch tàu và hẻm ngoài cổng
	Blocks.solid_box(self, Vector3(14, 1, 10), Vector3(7, -0.5, 5), TILE)
	Blocks.solid_box(self, Vector3(4, 1, 14), Vector3(-2, -0.52, 5), Color("#9C978C"))
	# Mặt sau lò bánh (tường 3,6 m, x 2,6 → 10,6, cửa sổ bếp x 3,4 → 4,6 cao 1,1 → 2,1, cửa sau x 7,1, ống khói x 9,6)
	_model(M_MAT_SAU, Vector3(6.6, 0, 0))
	_wall(Vector3(2.6, 0, -0.25), Vector3(3.4, 3.6, 0))
	_wall(Vector3(4.6, 0, -0.25), Vector3(10.6, 3.6, 0))
	_wall(Vector3(3.4, 0, -0.25), Vector3(4.6, 1.1, 0))
	_wall(Vector3(3.4, 2.1, -0.25), Vector3(4.6, 3.6, 0))
	Blocks.collider(self, Vector3(1.3, 0.08, 0.3), Vector3(4.0, 1.06, 0.07))      # bậu đưa bánh
	Blocks.collider(self, Vector3(1.7, 0.15, 0.35), Vector3(7.1, 0.075, 0.18))    # bậc cửa sau
	# Tường rào 2 m quanh sân (bắc hai bên lò, nam, đông, tây chừa cổng)
	_fence(Vector3(0, 0, 0), Vector3(2.6, 0, 0), 0.0)
	_fence(Vector3(10.6, 0, 0), Vector3(14, 0, 0), 0.0)
	_fence(Vector3(0, 0, 10), Vector3(14, 0, 10), PI)
	_fence(Vector3(14, 0, 0), Vector3(14, 0, 10), -PI / 2.0)
	_fence(Vector3(0, 0, 0), Vector3(0, 0, GATE_Z.x - 0.35), PI / 2.0)
	_fence(Vector3(0, 0, GATE_Z.y + 0.35), Vector3(0, 0, 10), PI / 2.0)
	_model(M_CONG, Vector3(0, 0, (GATE_Z.x + GATE_Z.y) / 2.0), PI / 2.0)          # cánh mở vào sân
	for z in [GATE_Z.x - 0.175, GATE_Z.y + 0.175]:   # trụ cổng
		Blocks.collider(self, Vector3(0.35, 2.1, 0.35), Vector3(0, 1.05, z))
	Blocks.invisible_wall(self, Vector3(0.3, 4, 1.6), Vector3(-0.35, 2, (GATE_Z.x + GATE_Z.y) / 2.0))  # không ra hẻm
	# Không trèo qua tường ra ngoài. Dày 4 m để camera (A1) lùi ra sau tường thì gặp khối đặc mà rút vào trong sân
	Blocks.invisible_wall(self, Vector3(16, 6, 4), Vector3(7, 3, -2.4))
	Blocks.invisible_wall(self, Vector3(16, 6, 4), Vector3(7, 3, 12.3))
	Blocks.invisible_wall(self, Vector3(4, 6, 12), Vector3(16.3, 3, 5))
	Blocks.invisible_wall(self, Vector3(0.4, 6, 12), Vector3(-0.6, 5, 5))
	# Kho củi: nóc 1,8 m (mặt Bơ đứng), mái tôn sét, củi bên trong
	_model(M_KHO_CUI, Vector3(SHED.position.x + SHED.size.x / 2.0, 0, SHED.size.y / 2.0))
	Blocks.collider(self, Vector3(SHED.size.x, SHED_TOP, SHED.size.y), Vector3(SHED.position.x + SHED.size.x / 2.0, SHED_TOP / 2.0, SHED.size.y / 2.0))
	# Cây khế: va chạm ở thân và bồn gốc, tán không chặn
	_model(M_KHE, TREE)
	Blocks.collider(self, Vector3(0.9, 0.25, 0.9), TREE + Vector3(0, 0.125, 0))
	Blocks.collider(self, Vector3(0.26, 1.4, 0.26), TREE + Vector3(0, 0.95, 0))
	# Bồn kiểng 0,5 m: x 3 → 10,6 (chặn lối vòng qua ba gác), 4 đoạn 2 m co lại cho vừa
	for i in 4:
		var bon := _model(M_BON, Vector3(BED.position.x + BED.size.x * (i + 0.5) / 4.0, 0, BED.position.y + BED.size.y / 2.0))
		bon.scale = Vector3(BED.size.x / 8.0, 1, 1)
	Blocks.collider(self, Vector3(BED.size.x, 0.5, BED.size.y), Vector3(BED.position.x + BED.size.x / 2.0, 0.25, BED.position.y + BED.size.y / 2.0))
	Blocks.invisible_wall(self, Vector3(0.4, 3, 1.6), Vector3(13.9, 1.5, BA_GAC.z))   # khe 0,26 m sau đầu xe
	# Bao gạo dưới chỗ Bột nằm
	Blocks.collider(self, Vector3(1.6, 0.44, 0.7), SACKS + Vector3(0, 0.22, 0), Blocks.LAYER_PROP)


func _model(scene: PackedScene, pos: Vector3, rot_y := 0.0) -> Node3D:
	var n := scene.instantiate() as Node3D
	n.position = pos
	n.rotation.y = rot_y
	add_child(n)
	return n


## Tường rào từ a tới b bằng các đoạn 2 m (co giãn cho vừa); rot_y 0 = mặt trước nhìn +z, lưng lùi 0,2 m.
func _fence(a: Vector3, b: Vector3, rot_y: float) -> void:
	var n := maxi(1, int(round(a.distance_to(b) / 2.0)))
	for i in n:
		var seg := _model(M_RAO, a.lerp(b, (i + 0.5) / n), rot_y)
		seg.scale = Vector3(a.distance_to(b) / n / 2.0, 1, 1)
	var thick := Vector3(0, 0, -0.1).rotated(Vector3.UP, rot_y)
	var d := (b - a).abs()
	var size := Vector3(maxf(d.x, 0.2), 2.0, maxf(d.z, 0.2))
	Blocks.collider(self, size, (a + b) / 2.0 + thick + Vector3(0, 1.0, 0))


func _wall(a: Vector3, b: Vector3) -> void:
	Blocks.collider(self, (b - a).abs(), (a + b) / 2.0)


func _build_models() -> void:
	for crate: Array in CRATES:
		var at: Vector3 = crate[0]
		for i in int(crate[1]):
			PhoModels.put(self, "thung_go", at + Vector3(0, i * CRATE, 0), 0.1 * i, Vector3.ONE * (CRATE / 0.8))
		Blocks.collider(self, Vector3(CRATE, CRATE * int(crate[1]), CRATE), at + Vector3(0, CRATE * int(crate[1]) / 2.0, 0), Blocks.LAYER_PROP)
	CityProps._ba_gac(self, BA_GAC, 0.0)
	for i in 4:
		PhoModels.put(self, "bao_gao", SACKS + Vector3(-0.5 + (i % 3) * 0.55, 0.22 * int(i / 3), 0.05 * (i % 2)), 0.2 * i)
	var lu := M_LU.instantiate() as Node3D
	lu.position = LU
	add_child(lu)
	Blocks.collider(self, Vector3(0.6, 0.85, 0.6), LU + Vector3(0, 0.425, 0), Blocks.LAYER_PROP)
	_basket = M_RO.instantiate() as Node3D
	_basket.position = BASKET
	_basket.scale = Vector3.ONE * 1.6
	add_child(_basket)
	co_ba = Nguoi.make("coba", "dung_yen")
	add_child(co_ba)
	co_ba.position = CO_BA_SPOT[0]
	co_ba.rotation.y = PI * 0.8
	chu_tu = Nguoi.make("chutu", "dung_cho")
	add_child(chu_tu)
	chu_tu.position = CHU_TU
	chu_tu.rotation.y = PI / 2.0    # nhìn vào sân (+x)
	bot = MeoNpc.from_cast("bot")
	add_child(bot)
	bot.snap_ground = false
	bot.position = BOT_AT
	bot.rotation.y = -PI / 2.0
	bot.set_pose("ngu")


# ---------------------------------------------------------------- tự chơi thử

## Bot đi hết 5 trạm bằng cách đặt Bơ vào chỗ (không phụ thuộc tay lái), kiểm từng trạm xong đúng lúc.
func _autotest_run() -> void:
	var notes: Array = []
	var ok := true
	await _frames(10)
	ok = _expect(ok, notes, station == 1, "vào trạm 1")
	_put(LU + Vector3(0.6, 0.1, 0))
	await _frames(5)
	ok = _expect(ok, notes, lu_reached, "tới lu nước")
	for q in [Vector3(1.9, 0.1, 0), Vector3(0, 0.1, 1.9), Vector3(-1.9, 0.1, 0), Vector3(0, 0.1, -1.9)]:
		_put(TREE + q)
		await _frames(4)
	ok = _expect(ok, notes, station == 2, "chạy đủ vòng cây khế → trạm 2")
	# Đứng trên thùng cao nhất: phải đứng vững (thùng có va chạm đúng 1,35 m)
	_put(Vector3(13.35, CRATE * 3 + 0.2, 4.35))
	await _frames(30)
	ok = _expect(ok, notes, absf(player.global_position.y - CRATE * 3) < 0.15, "đứng trên chồng 3 thùng (y=%.2f)" % player.global_position.y)
	_put(BASKET + Vector3(0.3, 0.2, 0.3))
	await _frames(90)
	ok = _expect(ok, notes, station == 3, "đẩy rổ tre rơi → trạm 3")
	# Chui: giữ C dưới gầm thùng ba gác rồi ra phía nam
	Input.action_press("crouch")
	_put(Vector3(11.5, 0.05, 6.0))
	await _frames(10)
	_put(Vector3(11.5, 0.05, BA_GAC.z))
	await _frames(15)
	ok = _expect(ok, notes, under_cart and player.stance == "crouch", "ở dưới gầm ba gác, đang chui")
	_put(Vector3(11.5, 0.05, 8.3))
	await _frames(15)
	Input.action_release("crouch")
	ok = _expect(ok, notes, station == 4, "chui qua gầm → trạm 4")
	# Đi thường gần Bột: Bột thức, không phạt; rón rén thì không
	player.noise_made.emit(BOT_AT + Vector3(2, 0, -1), player.noise_walk)
	await _frames(3)
	ok = _expect(ok, notes, bot_woke == 1 and station == 4, "đi thường làm Bột thức, vẫn ở trạm 4")
	bot_awake = 0.01
	await _frames(3)
	player.noise_made.emit(BOT_AT + Vector3(0, 0, -1), player.noise_sneak)
	await _frames(3)
	ok = _expect(ok, notes, bot_woke == 1, "rón rén sát Bột không làm Bột thức")
	_put(Vector3(3.6, 0.05, 8.4))
	await _frames(5)
	ok = _expect(ok, notes, station == 5, "qua Bột → trạm 5")
	_put(WINDOW + Vector3(0, 0.05, 0.7))
	await _frames(5)
	ok = _expect(ok, notes, carrying and player.carrying, "lấy bánh ở cửa sổ bếp")
	_put(GATE + Vector3(0.2, 0.05, 0))
	await _frames(5)
	_interact()
	await _frames(150)
	ok = _expect(ok, notes, done and bool(GameState.get_global(SAVE_KEY, false)), "giao cho Chú Tư → xong màn, lưu đã tập")
	ok = _expect(ok, notes, "gam" in str(GameSettings.get_value("tips_seen")), "mẹo Gầm thấp coi như đã xem")
	for n in notes:
		print("[tap] ", n)
	print("DAY CHOI TEST OK" if ok else "DAY CHOI TEST FAIL")
	get_tree().quit(0 if ok else 1)


func _expect(ok: bool, notes: Array, cond: bool, what: String) -> bool:
	notes.append(("OK  " if cond else "SAI ") + what)
	return ok and cond


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _put(p: Vector3) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
