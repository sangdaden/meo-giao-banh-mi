extends Node3D
## Thứ Năm · Leo chung cư Hoa Sữa lô B: mang 2 ổ trứng lên căn 5B-1 (tầng 5) cho Bé Na.
## Ba đường lên, theo trang thiết kế màn chơi (mục 06) và trang thiết kế màn leo chung cư:
## - Cầu thang trong: chắc ăn nhưng chậm. Chiếu nghỉ tầng 2 có giá phơi đồ phải chui qua,
##   em bé ngủ võng ở hành lang tầng 3 nên đoạn cầu thang gần đó phải rón rén.
## - Thang máy lồng kính: bấm gọi rồi đợi 4–10 s, có lúc Ông Bảy xách lồng chim ra chắn cửa,
##   có lúc kẹt giữa tầng 3 và 4.
## - Ngoài tường hông tây: bật tường trong khe 1,2 m hoặc leo chồng thùng lên mái nhà bên,
##   rồi cục nóng, chuồng cọp, ống nước tới hành lang tầng 5, ngay cửa nhà Bé Na. Nhanh nhất, rơi là xuống tầng dưới.
## Toạ độ riêng của cảnh: x dọc nhà (tây → đông), z = 0 là mép hành lang nhìn ra hẻm (phía nam), y = 0 mặt đất.
## Khớp nhà trên bản đồ (4 căn × 4,2 m + khối cầu thang 2,6 m, 5 tầng × 3 m): x cảnh = x bản đồ − 22.
## Bản khối tạm: khi Sang duyệt phác thảo model (thang máy, võng em bé, giá phơi đồ, ống nước...) thì thay bằng .glb.

const PlayerScript := preload("res://scripts/player.gd")
const CameraRigScript := preload("res://scripts/camera_rig.gd")
const HudScript := preload("res://scripts/hud.gd")
const Main := preload("res://scripts/main.gd")

const UNIT_W := 4.2
const UNITS := 4
const FLOOR_H := 3.0
const FLOORS := 5
const W := UNIT_W * UNITS        ## 16,8 m dãy căn hộ
const CORR := 1.7                ## hành lang sâu 1,7 m
const DEPTH := 8.0
const TX0 := W                   ## khối cầu thang x 16,8 → 19,4
const TX1 := W + 2.6
const TOWER_BACK := -5.6
const SHAFT_X0 := TX1            ## lồng thang máy x 19,4 → 21,2, z −1,9 → 0
const SHAFT_X1 := TX1 + 1.8

const TIME_LIMIT := 30.0
const FALL_BREAK_HEIGHT := 3.0
const ORDER := {"who": "Bé Na", "place": "Chung cư, căn 5B-1", "item": "2 ổ trứng", "color": Color("#D7A9C4"),
	"side_quest": "em_be_ngu_yen"}
const START := Vector3(9.0, 0.1, 5.0)
const DOOR := Vector3(0.85, 12.0, -1.2)      ## chỗ đứng gõ cửa 5B-1
const BABY := Vector3(14.7, 6.6, -1.0)       ## võng em bé ở hành lang tầng 3 trước cửa 3B-4

## Đường ngoài tường hông tây (mặt x = 0): [tên, z0, z1, mặt trên, kiểu]. Bậc nhảy ≤ 1,2 m, bám mép 1,4–2,1 m.
const WALL_STEPS := [
	["A", -3.0, -2.2, 5.1, "ac"],      # từ mái nhà bên (3,9) nhảy sang
	["B", -5.6, -4.4, 6.8, "cage"],    # bám mép 1,7
	["C", -3.0, -2.2, 8.4, "ac_rung"], # bám mép 1,6 · cục nóng rung, đứng lâu bị hất
	["D", -5.6, -4.4, 10.0, "cage"],   # bám mép 1,6 (hoặc nhảy khỏi đầu ống nước)
	["E", -3.0, -2.2, 11.2, "ac"],     # nhảy 1,2
	["F", -1.4, -0.6, 12.3, "ac"],     # nhảy 1,1, ngay đầu hành lang tầng 5: nhảy qua lan can là tới cửa 5B-1
]
const NEIGHBOR_ROOF := 3.9
const PIPE := Vector3(-0.08, NEIGHBOR_ROOF, -6.6)
const PIPE_TOP := 10.8

const WALL := Color("#D9C9A0")
const WALL2 := Color("#C8B88E")
const FLOOR := Color("#E6DCC4")
const IRON := Color("#2B2F33")
const AC := Color("#E4E7E2")
const STEP := Color("#C9C3B3")
const RAIL := Color(0.17, 0.18, 0.2, 0.45)  ## lan can song sắt: nhìn xuyên được

enum Lift { IDLE, COMING, OPEN_GROUND, CLOSING, RIDING, STUCK, OPEN_TOP }
enum Baby { SLEEP, STIR, CRY }

var player: CharacterBody3D
var rig: Node3D
var hud: CanvasLayer
var playing := false
var time_left := TIME_LIMIT
var time_limit: float = TIME_LIMIT  ## Thong thả: 90 s (DoKho), Thử thách: 30 s
var late := false
var intact := true
var delivered := false
var _clock := 0.0
var _air_top := 0.0
var _was_on_floor := true

var baby := Baby.SLEEP
var baby_woke := false           ## đã thức lần nào trong đơn (nhiệm vụ phụ trượt)
var _baby_t := 0.0
var _baby_label: Label3D
var _hammock: Node3D
var _mom: Node3D

var lift := Lift.IDLE
var lift_floor := 4.0            ## vị trí cabin tính theo tầng (0 = trệt), lúc đầu ở tầng 5
var _lift_t := 0.0
var _lift_wait := 0.0
var _lift_blocked := false       ## lần này Ông Bảy ra chắn cửa
var _lift_stuck_done := false
var _lift_will_stick := false
var _cabin: AnimatableBody3D
var _cabin_zone: Area3D
var _lift_doors: Array[StaticBody3D] = []
var _lift_label: Label3D
var _ong_bay: StaticBody3D
var _call_zone: Area3D

var _door_zone: Area3D
var _be_na: Node3D
var _rattle: Area3D
var _rattle_t := 0.0
var _rattle_body: Node3D
var _rng := RandomNumberGenerator.new()
var _autotest := false


func _ready() -> void:
	Main._setup_input()
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	_rng.seed = 42 if _autotest else Time.get_ticks_usec()
	_setup_environment()
	_build_ground()
	_build_building()
	_build_tower()
	_build_west_wall()
	_build_neighbor()
	Blocks.merge_static(self)
	_build_elevator()      # phần chuyển động (cabin, cửa) thêm sau khi gộp
	_build_zones()

	player = PlayerScript.new()
	player.name = "Bo"
	player.position = START
	player.climb_moves = true
	add_child(player)
	rig = CameraRigScript.new()
	rig.name = "CameraRig"
	rig.target = player
	rig.yaw = 0.0
	add_child(rig)
	player.camera_rig = rig
	player.noise_made.connect(_on_noise)
	player.deliver_finished.connect(_on_delivered)

	hud = HudScript.new()
	add_child(hud)
	hud.restart_pressed.connect(func(): get_tree().paused = false; get_tree().reload_current_scene())
	hud.menu_pressed.connect(func(): PlayMode.back_to_menu(get_tree()))
	player.stance_changed.connect(hud.set_stance)
	var snd := get_node_or_null("/root/Sound")
	if snd:  # sound_director.gd gắn chặt với màn giao Thứ Hai, ở đây chỉ cần tiếng nhảy, đáp
		player.jumped.connect(func(): snd.play("jump", 0.0, randf_range(0.96, 1.06)))
		player.landed.connect(func(): snd.play("land"))
		player.ledge_grabbed.connect(func(): snd.play("land"))
	GameSettings.apply_graphics(get_tree())
	GameSettings.apply_camera(get_tree())
	GameSettings.watch_camera(get_tree())
	_start()
	if _autotest:
		_autotest_run()


func _start() -> void:
	if _autotest:
		GameState.use_test_save("user://luu_game_autotest.cfg")
	Scoring.begin_day("thu_nam")
	playing = true
	time_limit = DoKho.v("apartment_time", TIME_LIMIT)
	time_left = time_limit
	player.carrying = true
	player.can_move = true
	if not _autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.start_screen.visible = false
	hud.show_playing_ui(true)
	hud.set_order(0, 1, "%s · %s" % [ORDER.who, ORDER.place], ORDER.item, ORDER.color)
	hud.progress_row.visible = false  # cảnh một đơn: không cần dãy 5 ổ bánh của Thứ Hai
	hud.set_bread(true, ORDER.item, 1.0)
	hud.set_goal(DOOR + Vector3(0, 0.6, 0))
	hud.show_toast("Lên căn 5B-1 tầng 5: cầu thang, thang máy hay leo ngoài tường?", 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event.is_action_pressed("pause"):
		hud.set_pause_info("Thứ Năm · Leo chung cư · đồng hồ đứng ở 0:%02d" % int(ceil(time_left)))
		hud.toggle_pause()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_update_lift(delta)
	_update_baby(delta)
	_update_rattle(delta)
	if not playing:
		return
	if Input.is_action_just_pressed("deliver"):
		_interact()
	_clock += delta
	time_left -= delta
	if time_left <= 0.0 and not late:
		late = true
		hud.show_toast("Trễ rồi! Bé Na vẫn nhận bánh nhưng chỉ được 1 sao.", 2.5)
	hud.set_timer(time_left, time_limit, true)
	hud.set_distance(player.global_position.distance_to(DOOR), "Căn 5B-1")
	hud.set_bread(true, ORDER.item, clampf(1.0 - _clock / 60.0, 0.0, 1.0))
	# Rơi từ cao hơn 3 m thì bánh bẹp (mất sao nguyên vẹn), như màn giao Thứ Hai
	var on_floor: bool = player.is_on_floor() or player.climb != ""
	if on_floor and not _was_on_floor:
		if _air_top - player.global_position.y > float(DoKho.v("fall_break_height", FALL_BREAK_HEIGHT)) and intact:
			intact = false
			hud.show_toast("Rơi cao quá, bánh bẹp mất rồi!", 2.0)
	if on_floor:
		_air_top = player.global_position.y
	else:
		_air_top = maxf(_air_top, player.global_position.y)
	_was_on_floor = on_floor
	# Ở cạnh cửa 5B-1: nhắc gõ cửa
	if _door_zone.overlaps_body(player) and player._act == "":
		hud.show_toast("Bấm E để gõ cửa", 0.3)


## Phím E: gõ cửa 5B-1, hoặc bấm gọi thang máy ở tầng trệt.
func _interact() -> void:
	if delivered:
		return
	if _door_zone.overlaps_body(player):
		player.play_deliver("hand")
		_be_na.visible = true
		hud.show_toast("Cốc cốc! Bé Na ra mở cửa.", 1.2)
	elif _call_zone.overlaps_body(player):
		call_lift()


func _on_delivered(_kind: String) -> void:
	if delivered:
		return
	delivered = true
	playing = false
	player.carrying = false
	player.can_move = false
	hud.set_timer(time_left, time_limit, false)
	var ratio := clampf(time_left / time_limit, 0.0, 1.0)
	var r := Scoring.order_done(0, {"time_ratio": ratio, "late": late, "intact": intact, "kitchen_star": -1,
		"side_quest": ORDER.side_quest, "side_quest_ok": not baby_woke, "time": _clock})
	r.erase("kitchen_stars")  # cảnh riêng, không có ổ bánh từ bếp
	var note := "trễ" if late else "dư %d giây" % int(time_left)
	var row := {"who": ORDER.who, "place": ORDER.place, "item": ORDER.item, "color": ORDER.color,
		"stars": r.stars, "note": note}
	row.merge(r)
	var summary := Scoring.end_practice()
	summary.day = "Thứ Năm · leo chung cư"
	summary.rows_title = "Leo chung cư · Bé Na"
	hud.show_toast("Bé Na: \"Cảm ơn Bơ nha!\"", 2.0)
	await get_tree().create_timer(1.2).timeout
	hud.show_playing_ui(false)
	hud.show_results([row], summary)
	print("[chung cu] sao ", r.stars, " · ", "%.1f" % _clock, " s · nguyên vẹn ", intact, " · em bé ngủ yên ", not baby_woke)


# ---------------------------------------------------------------- em bé ngủ võng (tầng 3)

## Tiếng Bơ (bước chân, đáp đất, đạp tường) tới võng thì em bé trở mình; trở mình mà nghe tiếng nữa thì thức.
func _on_noise(pos: Vector3, radius: float) -> void:
	if pos.distance_to(BABY) > radius:
		return
	match baby:
		Baby.SLEEP:
			baby = Baby.STIR
			_baby_t = 0.0
			if playing:
				hud.show_toast("Suỵt! Em bé trở mình, rón rén (Alt) thôi!", 2.0)
		Baby.STIR:
			if _baby_t > 0.4:  # cùng một bước chân không tính hai lần
				_wake_baby()


func _wake_baby() -> void:
	baby = Baby.CRY
	_baby_t = 0.0
	if not baby_woke and playing:
		hud.show_toast("Em bé thức giấc khóc rồi! (nhiệm vụ phụ trượt)", 2.5)
	baby_woke = true


func _update_baby(delta: float) -> void:
	_baby_t += delta
	var swing := 0.06
	match baby:
		Baby.SLEEP:
			_baby_label.text = "z z"
			_baby_label.modulate = Color("#9FB8C8")
		Baby.STIR:
			_baby_label.text = "?"
			_baby_label.modulate = Color("#E8A33A")
			swing = 0.18
			if _baby_t > 3.0:
				baby = Baby.SLEEP
		Baby.CRY:
			_baby_label.text = "Oa oa!"
			_baby_label.modulate = Color("#C8412F")
			swing = 0.25
			_mom.visible = _baby_t > 1.5
			if _baby_t > 8.0:  # Chị Thu ru ngủ lại, nhưng nhiệm vụ phụ đã trượt
				baby = Baby.SLEEP
				_mom.visible = false
	_hammock.rotation.x = sin(Time.get_ticks_msec() * 0.0025) * swing


# ---------------------------------------------------------------- thang máy

## Bấm nút gọi ở tầng trệt. Cabin đang ở tầng 5, xuống mất 4–10 s (kể cả lúc dừng đón người tầng khác).
func call_lift() -> void:
	if lift != Lift.IDLE:
		return
	lift = Lift.COMING
	_lift_t = 0.0
	_lift_wait = _rng.randf_range(4.0, 10.0)
	_lift_blocked = _rng.randf() < 0.3
	_lift_will_stick = _rng.randf() < 0.2
	_lift_stuck_done = false
	if playing:
		hud.show_toast("Đã gọi thang máy... đợi chút.", 1.5)


func _update_lift(delta: float) -> void:
	_lift_t += delta
	match lift:
		Lift.COMING:
			lift_floor = lerpf(4.0, 0.0, clampf(_lift_t / _lift_wait, 0.0, 1.0))
			if _lift_t >= _lift_wait:
				lift_floor = 0.0
				lift = Lift.OPEN_GROUND
				_lift_t = 0.0
				_ong_bay.visible = _lift_blocked
				_ong_bay.get_child(0).disabled = not _lift_blocked
				_ong_bay.position = Vector3((SHAFT_X0 + SHAFT_X1) / 2.0, 0.6, -0.9)
		Lift.OPEN_GROUND:
			if _lift_blocked:
				# Ông Bảy xách lồng chim bước ra chậm rãi, đứng chắn cửa 2,5 s
				var u := clampf(_lift_t / 2.5, 0.0, 1.0)
				_ong_bay.position.x = lerpf((SHAFT_X0 + SHAFT_X1) / 2.0, TX1 - 0.9, u)
				if u >= 1.0:
					_lift_blocked = false
					_ong_bay.visible = false
					_ong_bay.get_child(0).disabled = true
					_lift_t = 0.0
			elif _cabin_zone.overlaps_body(player) and _lift_t > 0.5:
				lift = Lift.CLOSING
				_lift_t = 0.0
		Lift.CLOSING:
			if _lift_t > 0.8:
				lift = Lift.RIDING
				_lift_t = 0.0
		Lift.RIDING:
			lift_floor = minf(lift_floor + delta / 1.3, 4.0)
			if _lift_will_stick and not _lift_stuck_done and lift_floor >= 2.5:
				lift = Lift.STUCK
				_lift_t = 0.0
				_lift_stuck_done = true
				hud.show_toast("Thang máy kẹt giữa tầng 3 và 4!", 2.0)
			if lift_floor >= 4.0:
				lift = Lift.OPEN_TOP
				_lift_t = 0.0
		Lift.STUCK:
			_cabin.position.x = (SHAFT_X0 + SHAFT_X1) / 2.0 + sin(_lift_t * 40.0) * 0.01
			if _lift_t > 3.0:
				_cabin.position.x = (SHAFT_X0 + SHAFT_X1) / 2.0
				lift = Lift.RIDING
		Lift.OPEN_TOP:
			if not _cabin_zone.overlaps_body(player) and _lift_t > 3.0:
				lift = Lift.IDLE  # ở lại tầng 5, gọi lại thì xuống đón
	_cabin.position.y = lift_floor * FLOOR_H
	var open_at := -1
	if lift in [Lift.OPEN_GROUND, Lift.OPEN_TOP]:
		open_at = roundi(lift_floor)
	for f in _lift_doors.size():
		var d := _lift_doors[f]
		var open := f == open_at
		d.get_child(1).disabled = open
		d.visible = not open
	var shown := roundi(lift_floor) + 1
	_lift_label.text = {Lift.IDLE: "%d" % shown, Lift.COMING: "▼ %d" % shown, Lift.RIDING: "▲ %d" % shown,
		Lift.STUCK: "! %d" % shown}.get(lift, "%d" % shown)


# ---------------------------------------------------------------- cục nóng rung

func _update_rattle(delta: float) -> void:
	var on := _rattle.overlaps_body(player) and player.is_on_floor()
	_rattle_t = _rattle_t + delta if on else maxf(_rattle_t - delta * 2.0, 0.0)
	_rattle_body.position.x = -0.3 + (sin(Time.get_ticks_msec() * 0.08) * 0.015 if _rattle_t > 0.6 else 0.0)
	if on and _rattle_t > 0.6 and _rattle_t - delta <= 0.6 and playing:
		hud.show_toast("Cục nóng rung bần bật, nhảy tiếp đi!", 1.5)
	if on and _rattle_t > 1.4:
		player.velocity = Vector3(-3.0, 3.0, 0.0)  # bị hất văng ra ngoài
		player.play_startle()
		_rattle_t = 0.0


# ---------------------------------------------------------------- dựng cảnh

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#5FA7D6")    # trưa oi (Thứ Năm)
	sky_mat.sky_horizon_color = Color("#F4E3B8")
	sky_mat.ground_horizon_color = Color("#F4E3B8")
	sky_mat.ground_bottom_color = Color("#8F8B80")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#C9D6DA")
	var compat := RenderingServer.get_rendering_device() == null
	env.ambient_light_energy = 0.35 if compat else 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR if compat else Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, -20, 0)  # nắng trưa, bóng ngắn
	sun.light_color = Color("#FFF0D6")
	sun.light_energy = 0.6 if compat else 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)


func _build_ground() -> void:
	Blocks.solid_box(self, Vector3(70, 1, 40), Vector3(8, -0.5, 4), Color("#B9B2A2"))
	# Hẻm giữa khối 3 trước chung cư, vỉa hè
	Blocks.box(self, Vector3(70, 0.02, 3.2), Vector3(8, 0.01, 4.5), Color("#8F8B80"))
	# Tường rào phía nam của hẻm: 2,5 m, cao hơn tầm bám mép (2,2 m) nên Bơ không ra khỏi cảnh
	Blocks.solid_box(self, Vector3(70, 2.5, 0.3), Vector3(8, 1.25, 9.0), Color("#E3D2B0"))
	Blocks.invisible_wall(self, Vector3(1, 30, 30), Vector3(-8.5, 15, 0))
	Blocks.invisible_wall(self, Vector3(1, 30, 30), Vector3(25.0, 15, 0))
	Blocks.invisible_wall(self, Vector3(40, 30, 1), Vector3(8, 15, -9.5))
	# Xe máy đậu dọc hành lang tầng trệt (bậc nhảy 0,9 m, chỉ để trang trí đường đi)
	for i in 3:
		var bike := Blocks.solid_box(self, Vector3(0.5, 0.9, 1.6), Vector3(3.0 + i * 1.1, 0.45, 1.3), [Color("#C8412F"), Color("#3A6EA5"), Color("#2B2622")][i], Blocks.LAYER_PROP)
		Blocks.box(bike, Vector3(0.36, 0.08, 0.7), Vector3(0, 0.49, 0.1), Color("#2B2622"))


func _build_building() -> void:
	# Khối căn hộ đặc phía sau hành lang
	var back_d := DEPTH - CORR
	Blocks.solid_box(self, Vector3(W, FLOORS * FLOOR_H, back_d), Vector3(W / 2.0, FLOORS * FLOOR_H / 2.0, -CORR - back_d / 2.0), WALL)
	# Mái bằng: sàn, lan can, bồn nước
	Blocks.solid_box(self, Vector3(W + 0.4, 0.3, DEPTH + 0.3), Vector3(W / 2.0, FLOORS * FLOOR_H + 0.15, -DEPTH / 2.0 + 0.1), FLOOR)
	for i in 3:
		Blocks.box(self, Vector3(1.6, 1.0, 1.0), Vector3(2.0 + i * 5.5, FLOORS * FLOOR_H + 0.8, -6.0), Color("#3A6EA5"))
	Blocks.label(self, "CHUNG CƯ HOA SỮA", Vector3(W / 2.0, FLOORS * FLOOR_H - 0.5, 0.3), 60, Color("#8A3A2A"))
	for f in FLOORS:
		var y := f * FLOOR_H
		if f > 0:
			Blocks.solid_box(self, Vector3(W, 0.15, CORR), Vector3(W / 2.0, y - 0.075, -CORR / 2.0), FLOOR)
			# Lan can hành lang (mặt nam) và đầu hồi phía tây
			Blocks.solid_box(self, Vector3(W, 1.05, 0.06), Vector3(W / 2.0, y + 0.525, -0.03), RAIL)
			Blocks.solid_box(self, Vector3(0.06, 1.05, CORR), Vector3(0.03, y + 0.525, -CORR / 2.0), RAIL)
			Blocks.box(self, Vector3(W, 0.06, 0.1), Vector3(W / 2.0, y + 1.05, -0.03), IRON)  # tay vịn
		for u in UNITS:
			var x0 := u * UNIT_W
			var door_col: Color = [Color("#3E6E6E"), Color("#7A4E36"), Color("#4A5E7A")][(u + f) % 3]
			Blocks.box(self, Vector3(0.9, 2.1, 0.05), Vector3(x0 + 0.85, y + 1.05, -CORR + 0.02), door_col)
			Blocks.label(self, "%dB-%d" % [f + 1, u + 1], Vector3(x0 + 0.85, y + 2.4, -CORR + 0.4), 24, Color("#F4EAD2"))
			Blocks.box(self, Vector3(1.3, 1.1, 0.05), Vector3(x0 + 2.7, y + 1.5, -CORR + 0.02), Color("#3D4A4A"))  # cửa sổ lá sách
			if (u + f) % 2 == 0:  # kệ giày, chậu cây trước cửa (nhỏ, đi vòng được)
				Blocks.solid_box(self, Vector3(0.7, 0.5, 0.3), Vector3(x0 + 1.8, y + 0.25, -CORR + 0.18), Color("#6E8F5E"), Blocks.LAYER_PROP)
			if (u * 3 + f) % 4 == 1:  # dây phơi đồ trên cao, chỉ để nhìn
				for k in 4:
					Blocks.box(self, Vector3(0.4, 0.6, 0.02), Vector3(x0 + 0.9 + k * 0.6, y + 2.3, -0.6), [Color("#F2EFE6"), Color("#C8412F"), Color("#3A6EA5"), Color("#E8B23A")][k])
		# Cột hành lang
		for u in UNITS + 1:
			var cx := clampf(u * UNIT_W, 0.15, W - 0.15)
			Blocks.solid_box(self, Vector3(0.3, FLOOR_H, 0.3), Vector3(cx, y + FLOOR_H / 2.0, -0.15), FLOOR)
	# Xe đạp dựng ở hành lang tầng 4 (đi né)
	Blocks.solid_box(self, Vector3(1.6, 0.9, 0.4), Vector3(8.4, 9.45, -1.3), Color("#3A6EA5"), Blocks.LAYER_PROP)
	# Võng em bé hành lang tầng 3 (thấp 0,6 m, Bơ đi dưới được)
	_hammock = Node3D.new()
	_hammock.position = Vector3(BABY.x, 6.0 + 1.9, BABY.z)
	add_child(_hammock)
	var cloth := Blocks.box(_hammock, Vector3(1.4, 0.18, 0.55), Vector3(0, -1.2, 0), Color("#E8B7C9"))
	cloth.name = "Vong"
	Blocks.box(_hammock, Vector3(0.36, 0.16, 0.22), Vector3(0, -1.05, 0), Color("#F6D9C2"))  # em bé quấn khăn
	for sx in [-1.0, 1.0]:
		Blocks.box(_hammock, Vector3(0.02, 1.2, 0.02), Vector3(sx * 0.7, -0.6, 0), Color("#7A6A55"))
	_baby_label = Blocks.label(self, "z z", BABY + Vector3(0, 0.9, 0.3), 40, Color("#9FB8C8"))
	Blocks.label(self, "Suỵt! Em bé ngủ", Vector3(TX0 + 0.3, 6.0 + 2.4, -1.8), 26, Color("#E8A33A"))


## Khối cầu thang bên phải (đông): mỗi tầng hai vế 9 bậc, chiếu nghỉ ở giữa, tường gạch bông gió nhìn xuyên.
func _build_tower() -> void:
	var cx := (TX0 + TX1) / 2.0
	var h := FLOORS * FLOOR_H + 1.0
	Blocks.solid_box(self, Vector3(TX1 - TX0, h, 0.2), Vector3(cx, h / 2.0, TOWER_BACK - 0.1), WALL2)
	# Mặt nam: gạch bông gió (nhìn xuyên được, camera không né) + cổng tầng trệt x 17,3 → 18,9
	var lattice := Color(WALL2, 0.35)
	Blocks.solid_box(self, Vector3(0.5, h, 0.15), Vector3(TX0 + 0.25, h / 2.0, 0.075), lattice, Blocks.LAYER_PROP)
	Blocks.solid_box(self, Vector3(0.5, h, 0.15), Vector3(TX1 - 0.25, h / 2.0, 0.075), lattice, Blocks.LAYER_PROP)
	Blocks.solid_box(self, Vector3(1.6, h - 2.4, 0.15), Vector3(cx, 2.4 + (h - 2.4) / 2.0, 0.075), lattice, Blocks.LAYER_PROP)
	Blocks.box(self, Vector3(2.0, 0.2, 0.6), Vector3(cx, 2.5, 0.3), FLOOR)
	Blocks.label(self, "LÔ B · CẦU THANG", Vector3(cx, 2.9, 0.4), 30, Color("#8A3A2A"))
	# Vách giữa hai vế thang (không nhảy tắt từ vế này sang vế kia)
	Blocks.solid_box(self, Vector3(0.1, FLOORS * FLOOR_H, 2.4), Vector3(TX0 + 1.3, FLOORS * FLOOR_H / 2.0, -2.9), WALL2)
	var rise := FLOOR_H / 2.0
	for f in FLOORS:
		var y := f * FLOOR_H
		if f > 0:
			Blocks.solid_box(self, Vector3(TX1 - TX0, 0.15, CORR), Vector3(cx, y - 0.075, -CORR / 2.0), FLOOR)
		if f == FLOORS - 1:
			break
		_flight(TX0 + 0.1, TX0 + 1.25, -CORR, -4.1, y, y + rise)          # vế A: đi về phía bắc
		Blocks.solid_box(self, Vector3(2.4, 0.15, 1.4), Vector3(cx, y + rise - 0.075, -4.8), FLOOR)  # chiếu nghỉ
		_flight(TX0 + 1.35, TX1 - 0.1, -4.1, -CORR, y + rise, y + FLOOR_H)  # vế B: quay về phía nam
	# Giá phơi đồ chắn chiếu nghỉ tầng 2 (giữa tầng 2 và 3): áo quần thả tới cách sàn 0,32 m, phải chui
	var ly := FLOOR_H + rise
	var rack := Blocks.solid_box(self, Vector3(0.3, 2.45, 1.5), Vector3(cx, ly + 0.32 + 1.225, -4.8), Color("#C9CDD0"), Blocks.LAYER_PROP)
	for k in 5:
		Blocks.box(rack, Vector3(0.34, 0.9, 0.26), Vector3(0, -0.75, -0.6 + k * 0.3), [Color("#F2EFE6"), Color("#E8B23A"), Color("#3A6EA5"), Color("#C8412F"), Color("#7FB7A4")][k])
	Blocks.label(self, "Chui qua!", Vector3(cx - 0.6, ly + 0.9, -4.3), 22, Color("#F4EAD2"))


## Một vế thang: bậc thật để nhìn, va chạm là mặt dốc trơn (CharacterBody không tự bước lên bậc).
func _flight(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
	var n := 9
	var w := x1 - x0
	var cx := (x0 + x1) / 2.0
	var dz := (z1 - z0) / n
	var dy := (y1 - y0) / n
	for i in n:
		var top := y0 + dy * (i + 1)
		var zc := z0 + dz * (i + 0.5)
		Blocks.box(self, Vector3(w, 0.2, absf(dz)), Vector3(cx, top - 0.1, zc), STEP)
	var run := absf(z1 - z0)
	var length := sqrt(run * run + (y1 - y0) * (y1 - y0))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, 0.1, length)
	cs.shape = bs
	body.add_child(cs)
	var ang := atan2(y1 - y0, run)
	# Mặt dốc đi qua mép trước của từng bậc, nâng nửa bậc cho bàn chân không lún
	body.position = Vector3(cx, (y0 + y1) / 2.0 + dy * 0.5 - 0.05 / cos(ang), (z0 + z1) / 2.0)
	body.rotation.x = ang if z1 < z0 else -ang
	add_child(body)


## Hông tây: cục nóng, chuồng cọp cửa sổ (va chạm lớp đồ nhỏ để camera khỏi giật), ống nước.
func _build_west_wall() -> void:
	for s in WALL_STEPS:
		var z0: float = s[1]
		var z1: float = s[2]
		var top: float = s[3]
		var kind: String = s[4]
		var hgt := 1.0 if kind == "cage" else 0.55
		var size := Vector3(0.6, hgt, z1 - z0)
		var pos := Vector3(-0.3, top - hgt / 2.0, (z0 + z1) / 2.0)
		var body := Blocks.solid_box(self, size, pos, AC if kind != "cage" else IRON, Blocks.LAYER_PROP)
		body.name = "Bac" + s[0]
		if kind == "cage":
			Blocks.box(body, Vector3(0.05, hgt - 0.1, z1 - z0 - 0.2), Vector3(0.28, 0, 0), Color("#3D4A4A"))  # cửa sổ phía trong
		else:
			Blocks.box(body, Vector3(0.02, 0.4, 0.4), Vector3(-0.31, 0, 0.05), Color("#6E7471"))  # quạt cục nóng
		if kind == "ac_rung":
			_rattle_body = body
	# Ống nước gãy giữa chừng: từ mái nhà bên (3,9 m) lên 10,8 m
	var pipe_len := PIPE_TOP - PIPE.y
	Blocks.box(self, Vector3(0.12, pipe_len, 0.12), PIPE + Vector3(0, pipe_len / 2.0, 0), Color("#7A8A8E"))
	Blocks.box(self, Vector3(0.12, 0.12, 0.3), PIPE + Vector3(0.05, pipe_len, 0), Color("#7A8A8E"))  # khúc cong vào tường
	for i in int(pipe_len / 1.2):
		Blocks.box(self, Vector3(0.1, 0.05, 0.2), PIPE + Vector3(0.04, 0.6 + i * 1.2, 0), IRON)  # kẹp ống
	# Cửa sổ hông các tầng (để nhìn)
	for f in FLOORS:
		Blocks.box(self, Vector3(0.05, 1.0, 1.0), Vector3(-0.02, f * FLOOR_H + 1.5, -5.0), Color("#3D4A4A"))


## Nhà ống bên cạnh (2 tầng, mái bằng 3,9 m) cách hông chung cư 1,2 m: khe này bật tường được.
## Phía trước có mái hiên 2,8 m và chồng thùng để leo chậm mà chắc.
func _build_neighbor() -> void:
	var x0 := -5.4
	var x1 := -1.2
	var cx := (x0 + x1) / 2.0
	Blocks.solid_box(self, Vector3(x1 - x0, NEIGHBOR_ROOF, 7.5), Vector3(cx, NEIGHBOR_ROOF / 2.0, -4.25), Color("#E3B95E"))
	Blocks.box(self, Vector3(x1 - x0 - 0.8, 2.3, 0.05), Vector3(cx, 1.15, -0.48), Color("#5E6F6C"))  # cửa cuốn
	Blocks.solid_box(self, Vector3(x1 - x0, 0.12, 1.1), Vector3(cx, 2.74, 0.05), Color("#C8412F"), Blocks.LAYER_PROP)  # mái hiên
	Blocks.solid_box(self, Vector3(x1 - x0, 0.5, 0.12), Vector3(cx, NEIGHBOR_ROOF + 0.25, -7.94), Color("#E3B95E"))  # tường mái phía sau
	Blocks.solid_box(self, Vector3(0.8, 0.8, 0.8), Vector3(-4.4, 0.4, 1.3), Color("#B08550"), Blocks.LAYER_PROP)
	Blocks.solid_box(self, Vector3(0.8, 0.8, 0.8), Vector3(-3.4, 0.4, 1.3), Color("#9C7444"), Blocks.LAYER_PROP)
	Blocks.solid_box(self, Vector3(0.8, 0.8, 0.8), Vector3(-3.4, 1.2, 1.3), Color("#B08550"), Blocks.LAYER_PROP)
	Blocks.label(self, "Khe 1,2 m: bật tường!", Vector3(-0.6, 1.6, 0.4), 22, Color("#F4EAD2"))


func _person(parent: Node, pos: Vector3, h: float, body: Color, head := Color("#E9C4A0")) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	Blocks.box(n, Vector3(0.4, h * 0.55, 0.26), Vector3(0, h * 0.5, 0), body)
	Blocks.box(n, Vector3(0.3, h * 0.25, 0.22), Vector3(0, h * 0.12, 0), body.darkened(0.3))
	Blocks.mesh(n, SphereMesh.new(), Vector3(0, h * 0.87, 0), head).scale = Vector3.ONE * h * 0.17
	return n


func _build_elevator() -> void:
	var cx := (SHAFT_X0 + SHAFT_X1) / 2.0
	var h := FLOORS * FLOOR_H + 1.0
	var glass := Color("#9CC3C9", 0.25)
	# Lồng kính: Bơ và camera nhìn xuyên được (lớp đồ nhỏ)
	Blocks.solid_box(self, Vector3(0.08, h, 2.0), Vector3(SHAFT_X1, h / 2.0, -0.95), glass, Blocks.LAYER_PROP)
	Blocks.solid_box(self, Vector3(1.8, h, 0.08), Vector3(cx, h / 2.0, -1.95), glass, Blocks.LAYER_PROP)
	Blocks.solid_box(self, Vector3(1.8, h, 0.08), Vector3(cx, h / 2.0, 0.05), glass, Blocks.LAYER_PROP)
	for f in FLOORS:
		var y := f * FLOOR_H
		# Tường đông khối thang có ô cửa thang máy z −1,6 → −0,2
		Blocks.solid_box(self, Vector3(0.15, FLOOR_H, 3.9), Vector3(TX1, y + FLOOR_H / 2.0, -3.65), WALL2)
		Blocks.solid_box(self, Vector3(0.15, FLOOR_H - 2.2, 1.4), Vector3(TX1, y + 2.2 + (FLOOR_H - 2.2) / 2.0, -0.9), WALL2)
		Blocks.solid_box(self, Vector3(0.15, FLOOR_H, 0.2), Vector3(TX1, y + FLOOR_H / 2.0, -0.1), WALL2)
		# Cửa thang: tấm trượt sang nam khi mở
		var d := StaticBody3D.new()
		d.position = Vector3(TX1 - 0.12, y + 1.1, -0.9)
		add_child(d)
		Blocks.box(d, Vector3(0.06, 2.2, 1.4), Vector3.ZERO, Color("#A7B0B3"))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.1, 2.2, 1.4)
		cs.shape = bs
		d.add_child(cs)
		_lift_doors.append(d)
	_lift_label = Blocks.label(self, "5", Vector3(TX1 - 0.3, 2.6, -0.9), 36, Color("#E8A33A"))
	Blocks.box(self, Vector3(0.05, 0.25, 0.15), Vector3(TX1 - 0.1, 1.0, -1.85), Color("#E8A33A"))  # nút gọi
	Blocks.label(self, "THANG MÁY · E gọi", Vector3(TX1 - 0.3, 1.5, -1.85), 20, Color("#F4EAD2"))
	# Cabin: sàn + trần chuyển động, Bơ đứng trên sàn được chở theo
	_cabin = AnimatableBody3D.new()
	_cabin.sync_to_physics = true
	_cabin.position = Vector3(cx, lift_floor * FLOOR_H, -0.95)
	add_child(_cabin)
	for part in [[Vector3(1.7, 0.1, 1.9), Vector3(0, -0.05, 0)], [Vector3(1.7, 0.1, 1.9), Vector3(0, 2.35, 0)]]:
		Blocks.box(_cabin, part[0], part[1], Color("#8E8A80"))
		var c := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = part[0]
		c.shape = b
		c.position = part[1]
		_cabin.add_child(c)
	_cabin_zone = Area3D.new()
	_cabin_zone.collision_mask = 2
	var zs := CollisionShape3D.new()
	var zb := BoxShape3D.new()
	zb.size = Vector3(1.5, 1.2, 1.7)
	zs.shape = zb
	zs.position.y = 0.6
	_cabin_zone.add_child(zs)
	_cabin.add_child(_cabin_zone)
	# Ông Bảy xách lồng chim (khối tạm), có lúc bước ra chắn cửa
	_ong_bay = StaticBody3D.new()
	_ong_bay.collision_layer = Blocks.LAYER_PROP
	var oc := CollisionShape3D.new()
	var ob := BoxShape3D.new()
	ob.size = Vector3(0.5, 1.6, 0.5)
	oc.shape = ob
	oc.position.y = 0.2
	oc.disabled = true
	_ong_bay.add_child(oc)
	_person(_ong_bay, Vector3(0, -0.6, 0), 1.6, Color("#D7D2C4"))
	Blocks.box(_ong_bay, Vector3(0.3, 0.4, 0.3), Vector3(0.0, 0.0, 0.35), Color("#B08550"))  # lồng chim
	_ong_bay.visible = false
	add_child(_ong_bay)


func _area(pos: Vector3, size: Vector3) -> Area3D:
	var a := Area3D.new()
	a.collision_mask = 2  # lớp của Bơ
	a.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	a.add_child(cs)
	add_child(a)
	return a


func _build_zones() -> void:
	_door_zone = _area(DOOR + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 1.0))
	_call_zone = _area(Vector3(TX1 - 0.6, 0.5, -1.0), Vector3(1.0, 1.0, 1.6))
	_rattle = _area(Vector3(-0.3, WALL_STEPS[2][3] + 0.3, -2.6), Vector3(0.7, 0.5, 0.9))
	var pipe := _area(PIPE + Vector3(-0.17, (PIPE_TOP - PIPE.y) / 2.0, 0), Vector3(0.5, PIPE_TOP - PIPE.y, 0.6))
	pipe.position = PIPE
	pipe.get_child(0).position = Vector3(-0.17, (PIPE_TOP - PIPE.y) / 2.0, 0)
	pipe.set_meta("normal", Vector3.LEFT)
	pipe.set_meta("top", PIPE_TOP)
	pipe.body_entered.connect(func(b): if b.has_method("enter_pipe"): b.enter_pipe(pipe))
	pipe.body_exited.connect(func(b): if b.has_method("exit_pipe"): b.exit_pipe(pipe))
	# Bé Na ra mở cửa 5B-1 khi Bơ gõ
	_be_na = _person(self, Vector3(0.85, 12.0, -1.45), 1.15, Color("#F2A7C0"), Color("#F0CDB0"))
	_be_na.visible = false
	# Chị Thu (mẹ em bé) ra ru võng khi em bé khóc
	_mom = _person(self, Vector3(BABY.x - 1.0, 6.0, -1.3), 1.58, Color("#7FB7A4"))
	_mom.visible = false


# ---------------------------------------------------------------- tự chơi thử (CI)

## Chạy: godot --headless -- --autotest (main.gd tự chuyển sang cảnh này sau màn giao Thứ Hai).
## Thử động tác leo trên đúng bố cục cảnh, em bé, giao cho Bé Na, rồi đi thang máy.
func _autotest_run() -> void:
	print("[autotest chung cu] bắt đầu")
	var ok := true
	var notes := []
	playing = false  # đồng hồ đứng trong lúc thử động tác
	await _frames(20)

	# 0. Cầu thang: đi bộ lên vế A, qua vế B lên tầng 2, chui dưới giá phơi đồ ở chiếu nghỉ tầng 2
	await _put(Vector3(TX0 + 0.7, 0.1, -1.0), 0.0)
	await _hold("move_forward", 80)
	ok = _expect(ok, notes, absf(player.global_position.y - FLOOR_H / 2.0) < 0.15, "đi lên vế A tới chiếu nghỉ (y = %.2f)" % player.global_position.y)
	await _put(Vector3(TX0 + 1.9, FLOOR_H / 2.0 + 0.1, -4.6), PI)
	await _hold("move_forward", 80)
	ok = _expect(ok, notes, absf(player.global_position.y - FLOOR_H) < 0.15, "đi lên vế B tới tầng 2 (y = %.2f)" % player.global_position.y)
	await _put(Vector3(TX0 + 0.6, FLOOR_H * 1.5 + 0.1, -4.8), -PI / 2.0)
	var crawled := false
	Input.action_press("move_forward")
	for i in 120:
		await get_tree().physics_frame
		crawled = crawled or player.stance == "crouch"
	Input.action_release("move_forward")
	ok = _expect(ok, notes, crawled and player.global_position.x > TX0 + 1.6, "chui qua giá phơi đồ (x = %.2f)" % player.global_position.x)

	# 1. Bật tường trong khe giữa chung cư và nhà bên: lên được mái nhà bên (3,9 m)
	await _put(Vector3(-0.6, 0.1, -4.5), 0.0)
	var top := 0.0
	await _hold("jump", 12)
	for k in 3:
		var side := "move_right" if k % 2 == 0 else "move_left"
		Input.action_press(side)
		for i in 40:
			await get_tree().physics_frame
			top = maxf(top, player.global_position.y)
			if player.is_on_wall() and player.velocity.y < 3.0:
				break
		Input.action_release(side)
		await _hold("jump", 12)
	for i in 40:
		await get_tree().physics_frame
		top = maxf(top, player.global_position.y)
	ok = _expect(ok, notes, top + player.ledge_reach > NEIGHBOR_ROOF, "bật tường lên %.2f m (+ bám %.2f) tới mái %.1f" % [top, player.ledge_reach, NEIGHBOR_ROOF])

	# 2. Bám mép: đứng trên cục nóng C, nhảy về phía bắc bám chuồng cọp D, rồi leo lên
	var c: Array = WALL_STEPS[2]
	await _put(Vector3(-0.3, c[3] + 0.05, -2.4), 0.0)
	Input.action_press("move_forward")
	await _hold("jump", 12)
	for i in 50:
		await get_tree().physics_frame
		if player.climb == "hang":
			break
	Input.action_release("move_forward")
	ok = _expect(ok, notes, player.climb == "hang", "bám mép chuồng cọp D")
	await _hold("jump", 3)
	await _frames(int(player.pull_time * 60) + 20)
	ok = _expect(ok, notes, absf(player.global_position.y - WALL_STEPS[3][3]) < 0.15, "leo lên D (y = %.2f)" % player.global_position.y)

	# 3. Ống nước: từ mái nhà bên đi về phía đông, ôm ống leo lên
	await _put(Vector3(-1.6, NEIGHBOR_ROOF + 0.05, PIPE.z), -PI / 2.0)
	Input.action_press("move_forward")
	await _frames(150)
	Input.action_release("move_forward")
	ok = _expect(ok, notes, player.climb == "pipe" and player.global_position.y > NEIGHBOR_ROOF + 1.5, "leo ống nước (y = %.2f)" % player.global_position.y)
	player.climb = ""

	# 4. Từ cục nóng F nhảy qua lan can vào hành lang tầng 5
	var f: Array = WALL_STEPS[5]
	await _put(Vector3(-0.3, f[3] + 0.05, (f[1] + f[2]) / 2.0), -PI / 2.0)
	Input.action_press("move_forward")
	await _hold("jump", 14)
	await _frames(40)
	Input.action_release("move_forward")
	await _frames(20)
	ok = _expect(ok, notes, absf(player.global_position.y - 12.0) < 0.15 and player.global_position.x > 0.2, "vào hành lang tầng 5 (%.2f, %.2f)" % [player.global_position.x, player.global_position.y])

	# Các bước trên có đi thường ở cầu thang và đáp đất nên em bé đã bị đánh thức: cho ngủ lại rồi mới thử
	baby = Baby.SLEEP
	baby_woke = false
	_mom.visible = false
	# 5. Em bé: tiếng rón rén ở cầu thang không nghe; một tiếng bước thường thì trở mình rồi ngủ lại
	_on_noise(Vector3(TX0 + 0.7, 6.0, -0.8), player.noise_sneak)
	_on_noise(Vector3(TX0 + 1.2, 4.5, -4.8), player.noise_sneak)
	ok = _expect(ok, notes, baby == Baby.SLEEP, "rón rén: em bé ngủ yên")
	_on_noise(Vector3(TX0 + 0.7, 6.0, -0.8), player.noise_walk)
	ok = _expect(ok, notes, baby == Baby.STIR, "đi thường: em bé trở mình")
	await _frames(200)
	ok = _expect(ok, notes, baby == Baby.SLEEP and not baby_woke, "im lặng 3 s: ngủ lại")

	# 6. Giao: chạy đồng hồ, tới cửa 5B-1 gõ cửa
	playing = true
	time_limit = DoKho.v("apartment_time", TIME_LIMIT)
	time_left = time_limit
	_clock = 0.0
	await _put(DOOR + Vector3(0, 0.05, 0), 0.0)
	await _frames(30)
	await _hold("deliver", 3)
	await _frames(150)
	var rows: Array = Scoring.orders
	var r: Dictionary = rows[0] if rows.size() > 0 else {}
	ok = _expect(ok, notes, delivered and int(r.get("stars", 0)) == 3 and r.get("side_ok", false), "giao Bé Na 3 sao, em bé ngủ yên (%s)" % [r])

	# 7. Thang máy: gọi ở tầng trệt, đợi, vào cabin, lên tầng 5
	player.can_move = true
	await _put(Vector3(TX1 - 0.6, 0.1, -1.0), 0.0)
	call_lift()
	var waited := 0
	while lift != Lift.OPEN_GROUND and waited < 60 * 16:
		await get_tree().physics_frame
		waited += 1
	ok = _expect(ok, notes, lift == Lift.OPEN_GROUND, "thang máy xuống sau %.1f s" % (waited / 60.0))
	while _lift_blocked and waited < 60 * 20:
		await get_tree().physics_frame
		waited += 1
	await _put(Vector3((SHAFT_X0 + SHAFT_X1) / 2.0, 0.15, -0.95), 0.0)
	waited = 0
	while lift != Lift.OPEN_TOP and waited < 60 * 14:
		await get_tree().physics_frame
		waited += 1
	await _frames(10)
	ok = _expect(ok, notes, lift == Lift.OPEN_TOP and absf(player.global_position.y - 12.0) < 0.3, "đi thang máy lên tầng 5 (y = %.2f)" % player.global_position.y)

	for n in notes:
		print(n)
	print("AUTOTEST ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _expect(ok: bool, notes: Array, cond: bool, what: String) -> bool:
	notes.append(("  OK   " if cond else "  LỖI  ") + what)
	return ok and cond


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _hold(action: String, n: int) -> void:
	Input.action_press(action)
	await _frames(n)
	Input.action_release(action)


func _put(p: Vector3, yaw: float) -> void:
	player.climb = ""
	player.global_position = p
	player.velocity = Vector3.ZERO
	rig.yaw = yaw
	await _frames(10)
