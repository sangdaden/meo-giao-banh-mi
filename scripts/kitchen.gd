extends Node3D
## Màn bếp Cô Ba: Bơ làm 2 ổ bánh mì trước khi đi giao.
## Camera đứng cố định ngoài xe bánh mì (tủ kính) nhìn vào bếp. Bơ chạy giữa các trạm, mỗi lần cầm một món:
## bao bột → bàn nhào (nhào, ủ, tạo hình) → lò gạch → bàn đồ chua → kệ (rổ rau, chả, thịt) → bồn rửa → thớt
## → bàn ráp → xe bánh mì. Tới trạm bấm E: camera lướt vào cận cảnh, mỗi bước có một kiểu thao tác
## (scripts/kitchen_input.gd: bấm, giữ, giữ-thả, xen kẽ, nhúng, canh giờ, vuốt, xoay, chọn) và hai chân trước
## của Bơ làm theo từng nhịp. Điểm bếp (0–3 sao) cộng giờ vào các đơn giao (GameState.kitchen_bonus).
##
## Đồ bếp là .glb kiểu D thật (assets/models/bep/, scripts/kitchen_models.gd). Các bước theo phạm vi
## "Bản đầu" trên trang phác thảo game: ổ bánh, dưa leo, ngò, đồ chua, ớt, chả, thịt, pate, xì dầu, ráp.
##
## Thong thả (mặc định, Sang duyệt 21/10, trang "Bếp Cô Ba dễ chơi"): không thua, đồng hồ chỉ quyết định
## sao thứ ba và dừng trong cận cảnh, bánh không cháy. Bước nào cũng còn cận cảnh nhưng chỉ bấm hoặc giữ E;
## các động tác phụ (mở lò, cắt lạt…) Bơ tự làm (EASY_AUTO). Cô Ba đứng góc bếp: chuẩn bị sẵn đồ theo ngày
## (PREP), đưa nguyên liệu, mang nhân sang bàn ráp, mang ổ ráp xong vào tủ kính, nhắc việc khi Bơ đứng lâu.
## Chỉ đường: dấu chân vàng trên sàn, bong bóng trên trạm kế, giữ Tab là Bơ tự đi tới.
## Chế độ thử thách (DoKho.hard()) giữ 9 kiểu thao tác và mốc 3:30 cũ, cũng không thua.

const PlayerScript := preload("res://scripts/player.gd")
const NguoiScript := preload("res://scripts/nguoi.gd")
const CameraScript := preload("res://scripts/kitchen_camera.gd")
const HudScript := preload("res://scripts/kitchen_hud.gd")
const KM := preload("res://scripts/kitchen_models.gd")
const KI := preload("res://scripts/kitchen_input.gd")

@export var time_limit := 210.0   ## 3 phút 30 giây cho 2 ổ (bản đầu nhiều bước hơn bản khối)
@export var bake_time := 6.0      ## lò nướng chín sau 6 giây
@export var burn_after := 15.0    ## Thử thách: để thêm quá 15 giây là cháy (Thong thả không cháy)
@export var proof_time := 8.0     ## ủ bột 8 giây
@export var spare_for_star := 45.0  ## còn dư từ chừng này giây thì được sao thứ ba
const LOAVES := 2
const EASY_TIME := 300.0   ## Thong thả: xong trong 5 phút là sao thứ ba (không có thua)
## Thong thả: Bơ tự diễn các bước này, người chơi không phải bấm
const EASY_AUTO := ["do_bot", "mo_cua", "xit", "dong_cua", "deo_gang", "chia", "lay", "nhung", "lat", "cat_dau",
	"cat_lat", "boc_la", "cat_doi", "boc_giay", "xep_quat", "khui", "khuay", "xi_dau"]
## Thong thả: Cô Ba làm sẵn từ sáng theo ngày (bot = xúc và ủ bột, do_chua, pate = khui hộp); ngày sau tự làm thêm
const PREP := {
	"thu_hai": ["bot", "do_chua", "pate"],
	"thu_ba": ["bot", "do_chua", "pate"],
	"thu_tu": ["bot", "pate"],
	"thu_nam": ["pate"],
}
const CO_BA_POS := Vector3(2.3, 0, -1.3)   ## góc phải sau, cạnh kệ nguyên liệu
const IDLE_NAG := 9.0      ## đứng không làm gì chừng này giây thì Cô Ba nhắc việc
const TRAIL_PAWS := 14
const USE_RADIUS := 0.32
const STAR_SECONDS := 2.0

const DOUGH_TINT := Color("#F2CF98")  ## bột sống ấm màu kem bơ, tách khỏi khay và sàn kem
const TRAY_TINT := Color("#9C958C")   ## khay nướng: xám ấm như thép đã ám, không cháy trắng dưới đèn
const BAKE_TINT := Color(1.0, 0.82, 0.6)
const PATE := Color("#9B6A4A")
const WATER := Color(0.62, 0.82, 0.92, 0.6)

# Bố cục (mét, cỡ mèo): bàn cao 34 cm, lò và xe bánh mì cỡ thật.
const BAO := Vector3(-2.2, 0, -1.45)
const NHOI := Vector3(-1.25, 0.341, -1.4)   ## mặt bàn nhào
const LO := Vector3(0.3, 0, -1.33)
const KE := Vector3(1.55, 0.341, -1.4)      ## mặt bàn nguyên liệu
const RUA := Vector3(2.42, 0, -0.35)
const THOT := Vector3(2.2, 0.386, 0.55)     ## mặt thớt
const CHUA := Vector3(-2.3, 0.341, 0.15)    ## mặt bàn đồ chua
const RAP := Vector3(0.3, 0.399, 0.15)      ## mặt bàn ráp
const XE := Vector3(-1.2, 0, 1.2)
const TRAY_OUT := -0.72   ## z của khay khi kéo ra đặt trên cửa lò
const TRAY_IN := -1.3     ## z của khay khi nằm trong lò

enum State { MENU, PLAY, END }

var state := State.MENU
var paw_breed := ""         ## giống mèo của hai chân cận cảnh; "" = giống đang dùng trong tủ đồ
var time_left := 0.0
var holding := ""          ## món đang cầm: "", bot, khay_song, khay_chin, khay_chay, rau, rau_sach, cha, thit, *_xong, do_chua, banh_mi
var flour_taken := false
var dough_state := "none"  ## none, proofing, risen, shaped
var proof_t := 0.0
var oven_state := "trong"  ## trong, nuong, chin, chay
var oven_t := 0.0
var bread_burnt := false
var pate_open := false
var do_chua_done := false
var loaf_stars: Array[int] = []   ## sao từng ổ, ghi lúc bỏ ổ vào xe bánh mì
var taken := {"rau": false, "cha": false, "thit": false}
var on_rap := {"rau": false, "cha": false, "thit": false, "do_chua": false}
var loaves_on_rap := 0
var made := 0
var mistakes := 0
var easy := true           ## Thong thả (mặc định); false = Chế độ thử thách
var first_shift := false   ## ca bếp đầu tiên: Cô Ba dẫn từng việc, không tính giờ
var co_ba: Node3D          ## Nguoi "coba"
var _chain := ""           ## cận cảnh xong thì vào luôn cận cảnh trạm này (Cô Ba đưa món kế)
var _idle_t := 0.0
var _said := {}            ## lời dẫn ca đầu đã nói
var trail: MultiMeshInstance3D
var bubble: Label3D
var _trail_t := 0.0
var _auto_walk := false
var _auto_path: Array[Vector3] = []
var _auto_goal := ""
var _start_ms := 0

# Phiếu ghi món (Thứ Ba): ổ thứ i của ca làm cho đơn loaf_orders[i]; ổ có phiếu được làm trước.
var loaf_orders: Array[int] = []
var loaf_note_ok: Array[bool] = []
var _note_ok := true          ## ổ đang ráp còn đúng phiếu không
# Ráp nhanh (Thứ Ba sau đơn 2): chỉ ráp 1 ổ trứng ở bàn ráp rồi về phố
var quick := false
var quick_order := -1
const QUICK_TIME := 40.0
const QUICK_SPARE := 10.0     ## ráp xong còn dư chừng này giây thì 3 sao
const NOTE_NAMES := {"khong_ot": "không ớt", "them_pate": "thêm pate", "nhieu_do_chua": "nhiều đồ chua"}

var player: CharacterBody3D
var cam: Node3D
var hud: CanvasLayer
var stations := {}   ## id -> {name, use, work, cam, look, ring}
var carry_node: Node3D
var input: KI

# Cận cảnh: chuỗi bước của trạm đang làm
var seq: Array = []
var seq_station := ""
var seq_index := 0

# Chân Bơ trong cận cảnh
var paw_rig: Node3D
var paw_l: Node3D
var paw_r: Node3D
const PAW_L_REST := Vector3(-0.1, 0.05, 0.15)   ## chân chờ hai bên mép khung, chừa món ở giữa
const PAW_R_REST := Vector3(0.1, 0.05, 0.15)
const CLOSE_BACK := 0.5    ## camera cận cảnh lùi về phía Bơ đứng bao nhiêu mét so với điểm làm việc
const CLOSE_UP := 0.44     ## và cao hơn điểm làm việc bao nhiêu mét (ngang tầm mắt Bơ đứng hai chân)
const CLOSE_AHEAD := 0.0
const PAW_SIZE := 0.8      ## chân trước nhỏ lại cho hợp đồ bếp cỡ mèo (thớt 38 cm, hộp pate 10 cm)

# Đồ động ở các trạm
var n := {}                ## tên -> Node3D (đồ cận cảnh ở các trạm)
var balls: Array[Node3D] = []
var raw_loaves: Array[Node3D] = []
var slashes: Array[Node3D] = []
var oven_loaves: Array[Dictionary] = []   ## mỗi ổ: {song, vang, chay}
var rap_loaves: Array[Node3D] = []
var case_slots: Array[Node3D] = []
var board := {}            ## đồ trên thớt của món đang sơ chế
var loaf := {}             ## ổ đang ráp: base, lid, smear, pieces, done, paper
var flour_puff: CPUParticles3D
var mist: CPUParticles3D
var smoke: CPUParticles3D
var drops: CPUParticles3D
var oven_label: Label3D
var fire_light: OmniLight3D

# Tự chơi: --autotest-bep (kiểm tra, thoát khi xong) hoặc --demo-bep (để quay clip)
var _bot := false
var _bot_quit := false
var _bot_path: Array[Vector3] = []
var _bot_goal := ""
var _bot_wait := 0.0
var _grid: AStarGrid2D
const GRID := 0.1
const GRID_ORIGIN := Vector2(-2.6, -1.7)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args and GameState.quick_assemble_request < 0:
		# Kiểm tra vòng giao bánh như cũ: bỏ qua bếp (trừ lúc main gửi sang ráp nhanh ổ trứng giữa ca)
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		return
	_bot = "--autotest-bep" in args or "--demo-bep" in args or "--autotest-rap-nhanh" in args or "--demo-rap-nhanh" in args
	_bot = _bot or "--autotest" in args  # autotest Thứ Ba của main: bot ráp nhanh rồi tự về phố
	_bot_quit = "--autotest-bep" in args or "--autotest-rap-nhanh" in args
	for a in args:
		if a.begins_with("--ngay="):   # bot thử bếp của ngày khác, vd --ngay=thu_ba (phiếu ghi món)
			GameState.day = a.trim_prefix("--ngay=")
		elif a.begins_with("--giong="):  # chụp thử chân cận cảnh của giống khác, vd --giong=mun
			paw_breed = a.trim_prefix("--giong=")
	if "--autotest-rap-nhanh" in args or "--demo-rap-nhanh" in args:
		GameState.day = "thu_ba"
		GameState.quick_assemble_request = 2
		GameState.eggs_brought = 3 if "--it-trung" in args else 6
	quick = GameState.quick_assemble_request >= 0
	quick_order = GameState.quick_assemble_request
	if "--thu-thach" in args:   # bot thử Chế độ thử thách
		DoKho.force = 1
	easy = not DoKho.hard()
	if quick:
		time_limit = QUICK_TIME
	elif easy:
		time_limit = EASY_TIME
		first_shift = "--ca-dau" in args or (not _bot and int(GameState.get_day("sao_bep", -1)) < 0)
	_load_notes()

	_setup_input()
	_setup_environment()
	var room := Node3D.new()
	room.name = "Phong"
	add_child(room)
	_build_room(room)
	_build_stations(room)
	Blocks.merge_static(room)
	_build_grid()

	player = PlayerScript.new()
	player.name = "Bo"
	player.walk_speed = 2.0   # bếp cỡ mèo 5 × 3,4 m
	player.sprint_speed = 3.0
	player.position = Vector3(-0.5, 0.05, 0.45)
	add_child(player)
	if paw_breed != "" and player.has_method("set_breed"):
		player.set_breed(paw_breed)

	cam = CameraScript.new()
	cam.name = "CameraBep"
	cam.main_pos = Vector3(0, 2.75, 3.45)   # gần hơn bản đầu (2.6, 4.3): Bơ to gấp rưỡi trên màn hình
	cam.main_look = Vector3(0, 0.0, -0.35)
	cam.follow = 0.4
	cam.target = player
	AnhSang.watch_close_up(self, cam)  # cận cảnh: bóng nét hơn, bớt chói
	add_child(cam)
	player.camera_rig = cam

	_build_paws()
	oven_label.visible = not easy   # Thong thả: lò báo bằng viên trạng thái, bong bóng và lời Cô Ba
	_build_co_ba()
	_build_guides()

	input = KI.new()
	input.bot = _bot
	input.miss_lock = 0.0 if easy else KI.MISS_LOCK
	input.hit.connect(_on_hit)
	input.progress.connect(_on_progress)
	input.miss.connect(_on_miss)
	input.picked_changed.connect(_show_step)
	input.wrong_pick.connect(_on_wrong_pick)

	hud = HudScript.new()
	add_child(hud)
	hud.start_pressed.connect(start_game)
	hud.go_delivery_pressed.connect(_go_delivery)
	hud.menu_pressed.connect(func(): PlayMode.back_to_menu(get_tree()))
	hud.option_pressed.connect(func(i: int): input.choose(i))
	if PlayMode.kitchen_only():
		for b in hud.end_screen.find_children("*", "Button", true, false):
			b.text = "Về chọn màn (Enter)"
	if easy and hud.start_text:
		hud.start_text.text = ("Trước giờ giao, Bơ phụ Cô Ba làm 2 ổ bánh mì.\n\n"
			+ "Cứ đi theo dấu chân vàng tới trạm có bong bóng (giữ Tab là Bơ tự đi), rồi bấm E.\n"
			+ "Mỗi bước chỉ cần bấm hoặc giữ E như thẻ góc phải, chân Bơ làm hết động tác.\n"
			+ "Cô Ba ở góc bếp đưa đồ, mang nhân và bánh giúp, quên việc thì cô nhắc.\n\n"
			+ ("Ca đầu không tính giờ." if first_shift else "Không có thua: xong trong 5 phút thì thêm sao thứ ba.")
			+ " Mỗi sao bếp cộng giây cho các đơn giao.")
	_update_hud()

	if quick:
		hud.start_screen.visible = false
		start_game.call_deferred()
	elif _bot:
		print("[bep] tự chơi")
		if _bot_quit:
			start_game.call_deferred()
		else:
			get_tree().create_timer(2.5).timeout.connect(start_game)  # quay clip: để thấy màn hình bắt đầu


func start_game() -> void:
	if state == State.PLAY:
		return
	state = State.PLAY
	_start_ms = Time.get_ticks_msec()
	time_left = time_limit
	player.can_move = true
	hud.start_screen.visible = false
	hud.show_playing_ui(true)
	_sound("music", "kitchen")
	_sound("ambience", "kitchen")
	if quick:
		_start_quick()
		return
	if not easy:
		hud.show_toast("Tới bao bột xúc bột trước nhé!", 2.5)
		return
	_apply_prep()
	if first_shift:
		_co_ba_say("Bơ ơi, phụ cô làm 2 ổ bánh mì nha! Bột cô ủ sẵn rồi, đi theo dấu chân vàng tới bàn nhào nè.", "vay", 5.0)
	else:
		_co_ba_say("Vô ca rồi Bơ! Bột cô ủ sẵn, qua bàn nhào nặn bánh nha.", "vay")


## Thong thả: Cô Ba làm sẵn từ sáng các việc của ngày (PREP).
func _apply_prep() -> void:
	var prep: Array = PREP.get(GameState.day, [])
	if "bot" in prep:
		flour_taken = true
		dough_state = "risen"
		n.thau.visible = false
		n.flour.visible = false
		n.water.visible = false
		n.dough.visible = false
		n.proof_bowl.visible = true
		n.proof_bowl.scale = Vector3(1.0, 1.15, 1.0)
	if "do_chua" in prep:
		do_chua_done = true
		on_rap.do_chua = true
		n.chua_jar.visible = false
		n.chua_shreds.visible = false
		_refresh_rap()
	if "pate" in prep:
		pate_open = true
		n.pate_lid.visible = false
		n.pate_fill.visible = true


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
			elif _bot:
				pass
			elif not seq.is_empty():
				input.screen_center = get_viewport().get_visible_rect().size * 0.5
				input.handle(event)
			elif event.is_action_pressed("interact") and not (event is InputEventMouseButton):
				_interact()


func _physics_process(delta: float) -> void:
	if state != State.PLAY:
		return
	# Thong thả: đồng hồ dừng trong cận cảnh và cả ca đầu; hết giờ không thua, chỉ mất sao thứ ba
	if not (easy and (first_shift or not seq.is_empty())):
		time_left = maxf(time_left - delta, 0.0)
	_update_oven(delta)
	_update_proof(delta)
	if not seq.is_empty():
		input.update(delta)
		_show_step()
	if _bot:
		_bot_step(delta)
	elif seq.is_empty():
		_auto_walk_step(delta)
		_update_idle(delta)
	_update_hud()


func _process(_delta: float) -> void:
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
	_update_guides(_delta, goal, near)


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
	_idle_t = 0.0
	_begin(id, _ease(steps))


## Thong thả: đổi bước sang kiểu dễ. Xen kẽ, nhúng, canh giờ thành bấm E (mỗi lần bấm chạy liền nhiều
## nhịp); giữ-thả, vuốt, xoay thành giữ E; chọn thì ô đúng tự sáng; bước trong EASY_AUTO Bơ tự làm.
func _ease(steps: Array) -> Array:
	if not easy:
		return steps
	var out := []
	for st: Dictionary in steps:
		var e := st.duplicate()
		var k: int = int(e.get("n", 1))
		match e.type:
			"tap", "alt", "dip", "timing":
				e.type = "tap"
				e.per = k if k <= 6 else ceili(k / 2.0)
			"hold_release":
				e.type = "hold"
			"swipe", "rotate":
				e.type = "hold"
				e.dur = 0.6
			"pick":
				e.guide = true
		if e.id in EASY_AUTO:
			e.auto = true
		out.append(e)
	return out


## Trả về danh sách bước; rỗng nếu chưa làm được (kèm lời nhắc), hoặc nếu là việc đặt đồ làm ngay.
func _steps_for(id: String) -> Array:
	match id:
		"bot":
			if holding != "":
				return _no("Tay đang cầm %s rồi" % _item_name(holding))
			if flour_taken:
				return _no("Bột đủ cho 2 ổ rồi")
			return [_s("xuc", "Xúc bột", "tap", {"n": 2})]
		"nhoi":
			if holding == "bot":
				return [_s("do_bot", "Đổ bột vào thau", "tap"),
					_s("rot_nuoc", "Rót nước", "hold_release", {"dur": 1.6, "zone": [0.7, 0.88]}),
					_s("nhao", "Nhào bột", "alt", {"n": 12}),
					_s("u", "Phủ khăn ủ bột", "tap")]
			if dough_state == "proofing":
				return _no("Bột đang ủ, còn %d giây. Tranh thủ làm việc khác!" % ceili(proof_time - proof_t))
			if dough_state == "risen":
				if holding != "":
					return _no("Đặt %s xuống trước đã" % _item_name(holding))
				return [_s("chia", "Chia bột", "tap", {"n": 2}),
					_s("lan", "Nặn và lăn dài", "alt", {"n": 8}),
					_s("rach", "Rạch mặt bánh", "timing", {"n": 2, "zone": [0.4, 0.6], "speed": 3.0})]
			if dough_state == "none":
				return _no("Cần mang bột tới bàn nhào")
			return _no("Bàn nhào xong việc rồi")
		"lo":
			match oven_state:
				"nuong":
					return _no("Bánh đang nướng, còn %d giây" % ceili(bake_time - oven_t))
				"chin", "chay":
					if holding != "":
						return _no("Đặt %s xuống trước đã" % _item_name(holding))
					return [_s("deo_gang", "Đeo găng, mở cửa lò", "tap"),
						_s("rut_khay", "Rút khay ra", "hold", {"dur": 1.0})]
				_:
					if holding != "khay_song":
						return _no("Cần mang khay bánh sống tới lò")
					return [_s("mo_cua", "Mở cửa lò", "tap"),
						_s("xit", "Xịt hơi nước", "tap", {"n": 3}),
						_s("day_khay", "Đẩy khay vào lò", "hold", {"dur": 1.2}),
						_s("dong_cua", "Đóng cửa lò", "tap")]
		"rau", "cha", "thit":
			if taken[id]:
				return _no("Lấy %s rồi" % _item_name(id))
			if holding != "":
				return _no("Tay đang cầm %s rồi" % _item_name(holding))
			return [_s("lay", "Lấy %s" % _item_name(id), "tap")]
		"rua":
			if easy and holding == "" and not taken.rau:   # Cô Ba đưa rổ rau tới bồn
				taken.rau = true
				n.ke_rau.visible = false
				_set_holding("rau")
				_co_ba("cho_banh")
			if holding != "rau":
				return _no("Mang rổ rau tới bồn rửa" if holding == "" else "Bồn rửa chỉ để rửa rau")
			return [_s("chai_rua", "Chà rửa dưa leo", "alt", {"n": 6}),
				_s("nhung", "Nhúng lắc ngò", "dip", {"n": 6}),
				_s("lat", "Lặt ngò", "pick", {"order": ["Bỏ rễ", "Bỏ lá úa", "Ngắt nhánh nhỏ"], "wrong": ["Bỏ ngọn"]})]
		"thot":
			if easy and holding == "":   # Cô Ba đặt chả, thịt lên thớt
				if not taken.rau:
					return _no("Rửa rau ở bồn trước nha")
				var next := _next_board_item()
				if next == "":
					return _no("Thớt xong việc rồi, qua bàn ráp nha")
				_give_board_item(next)
			match holding:
				"rau":
					return _no("Rửa rau ở bồn trước đã")
				"rau_sach":
					return [_s("cat_dau", "Cắt hai đầu dưa leo", "tap", {"n": 2}),
						_s("che_doc", "Chẻ dọc dưa leo", "timing", {"n": 3, "zone": [0.38, 0.62], "speed": 2.4}),
						_s("cat_ot", "Cắt ớt", "tap", {"n": 4})]
				"cha":
					return [_s("cat_lat", "Cắt lạt buộc", "tap", {"n": 2}),
						_s("boc_la", "Bóc lá chuối", "hold", {"dur": 1.2}),
						_s("cat_doi", "Cắt đôi đòn chả", "tap"),
						_s("thai_cha", "Thái chả", "timing", {"n": 4, "zone": [0.4, 0.6], "speed": 2.4})]
				"thit":
					return [_s("boc_giay", "Bóc giấy gói thịt", "hold", {"dur": 1.0}),
						_s("thai_thit", "Thái thịt", "timing", {"n": 4, "zone": [0.4, 0.6], "speed": 2.4}),
						_s("xep_quat", "Xếp thịt hình quạt", "alt", {"n": 4})]
			return _no("Mang dưa leo, chả hoặc thịt tới thớt")
		"do_chua":
			if do_chua_done:
				return _no("Đồ chua làm rồi")
			if holding != "":
				return _no("Tay đang cầm %s rồi" % _item_name(holding))
			return [_s("got", "Gọt cà rốt", "swipe", {"n": 3}),
				_s("bao", "Bào sợi", "swipe", {"n": 3}),
				_s("pha", "Pha giấm đường", "rotate", {"n": 2})]
		"rap":
			if holding in ["khay_chin", "khay_chay"]:
				loaves_on_rap = LOAVES
				bread_burnt = holding == "khay_chay"
				_set_holding("")
				_refresh_rap()
				hud.show_toast("Đặt bánh lên bàn ráp")
				return []
			if holding.ends_with("_xong") or holding == "do_chua":
				var k := holding.trim_suffix("_xong")
				on_rap[k] = true
				_set_holding("")
				_refresh_rap()
				hud.show_toast("Đặt %s lên bàn ráp" % _item_name(k))
				return []
			if holding != "":
				return _no("Phải sơ chế %s trước" % _item_name(holding) if holding in ["rau", "rau_sach", "cha", "thit"] else "Bàn ráp chưa cần %s" % _item_name(holding))
			var missing := []
			if loaves_on_rap == 0:
				missing.append("bánh nướng")
			for k in on_rap:
				if not on_rap[k]:
					missing.append(_item_name(k))
			if not missing.is_empty():
				return _no("Còn thiếu: " + ", ".join(missing))
			var steps := [_s("xe", "Xẻ bánh", "hold_release", {"dur": 1.6, "zone": [0.7, 0.9]})]
			if not pate_open:
				steps.append(_s("khui", "Khui hộp pate", "swipe"))
				steps.append(_s("khuay", "Khuấy pate", "rotate"))
			steps.append_array(_assemble_steps(["Thịt nguội", "Chả lụa", "Dưa leo", "Đồ chua", "Ngò", "Ớt"], ["Trứng", "Xíu mại"]))
			return steps
		"tu":
			if holding != "banh_mi":
				return _no("Ráp xong ổ bánh mì rồi mới bỏ vào xe")
			return [_s("bo_vao", "Bỏ vào tủ kính", "tap")]
	return []


## Các bước ráp sau khi xẻ: phết pate, xếp nhân theo phiếu, xì dầu, gói. Phiếu đổi thứ tự nhân:
## "không ớt" bỏ Ớt (chọn Ớt là sai phiếu), "thêm pate" thêm một lượt pate, "nhiều đồ chua" thêm đồ chua.
func _assemble_steps(fillings: Array, wrong: Array) -> Array:
	var note := _current_note()
	var order := fillings.duplicate()
	var bad := wrong.duplicate()
	match note:
		"khong_ot":
			order.erase("Ớt")
			bad.append("Ớt")
		"them_pate":
			order.push_front("Thêm pate")
		"nhieu_do_chua":
			order.insert(order.find("Đồ chua") + 1, "Thêm đồ chua")
	var pick_name: String = "Xếp nhân" + (" · phiếu: " + NOTE_NAMES[note] if note != "" else "")
	return [_s("pate", "Phết pate", "hold", {"dur": 1.2}),
		_s("xep_nhan", pick_name, "pick", {"order": order, "wrong": bad}),
		_s("xi_dau", "Rưới xì dầu", "tap", {"n": 2}),
		_s("goi", "Gói giấy", "alt", {"n": 4})]


## Phiếu của ổ đang ráp ("" nếu không có).
func _current_note() -> String:
	var k := quick_order if quick else (loaf_orders[made] if made < loaf_orders.size() else -1)
	return GameState.bread_notes[k] if k >= 0 and k < GameState.bread_notes.size() else ""


## Đọc phiếu ghi món của ngày (Days, gói T3-1) và chọn ổ nào làm cho đơn nào.
func _load_notes() -> void:
	var orders: Array = []
	if ResourceLoader.exists("res://scripts/days.gd"):
		orders = load("res://scripts/days.gd").orders(GameState.day)
	if not quick or GameState.bread_notes.size() != GameState.ORDERS_PER_DAY:
		var notes: Array[String] = []
		var oks: Array[bool] = []
		for i in GameState.ORDERS_PER_DAY:
			notes.append(str(orders[i].get("note", "")) if i < orders.size() else "")
			oks.append(true)
		GameState.bread_notes = notes
		GameState.bread_note_ok = oks
	# Ổ có phiếu làm trước, rồi tới các đơn đầu ngày; bỏ đơn mua đồ (errand)
	var noted: Array[int] = []
	var rest: Array[int] = []
	for i in GameState.ORDERS_PER_DAY:
		if i < orders.size() and orders[i].get("kind", "deliver") == "errand":
			continue
		(noted if GameState.bread_notes[i] != "" else rest).append(i)
	noted.append_array(rest)
	loaf_orders = noted.slice(0, LOAVES)
	loaf_orders.sort()


## Thong thả: món kế Cô Ba đặt lên thớt ("" = hết).
func _next_board_item() -> String:
	for k in ["cha", "thit"]:
		if not taken[k]:
			return k
	return ""


func _give_board_item(k: String) -> void:
	taken[k] = true
	n["ke_" + k].visible = false
	_set_holding(k)
	_co_ba("cho_banh")


func _s(id: String, title: String, type: String, extra := {}) -> Dictionary:
	var d := {"id": id, "name": title, "type": type, "n": 1}
	d.merge(extra, true)
	return d


func _no(msg: String) -> Array:
	if _bot:
		print("[bep] %5.1fs %s" % [time_limit - time_left, msg])
	if easy:
		_co_ba_say(msg, "noi", 2.5)
	else:
		hud.show_toast(msg)
	return []


func _begin(id: String, steps: Array) -> void:
	seq = steps
	seq_station = id
	seq_index = 0
	player.can_move = false
	player.velocity = Vector3.ZERO
	var st: Dictionary = stations[id]
	var to: Vector3 = st.work - player.global_position
	player.visual.rotation.y = atan2(-to.x, -to.z)
	cam.close_up(st.cam, st.look)
	_place_paws(st)
	player.visual.visible = false  # cận cảnh chỉ thấy hai chân trước, thân Bơ không che camera
	_set_holding_visible(false)
	_on_begin(id)
	_start_step()
	if first_shift and not _said.has("vao"):
		_said.vao = true
		_co_ba_say("Làm theo thẻ góc phải dưới nha: bấm hoặc giữ E là chân con làm hết.", "noi", 4.5)


func _start_step() -> void:
	var step: Dictionary = seq[seq_index]
	input.bot = _bot or step.get("auto", false)
	input.start(step)
	_on_step_start(step.id)
	_show_step()


## Một nhịp xong (một lần bấm trúng, một nhát vuốt, một vòng xoay...): chân Bơ diễn nhịp đó.
func _on_hit(index: int, last: bool) -> void:
	if seq.is_empty():
		return
	input.locked = true
	var step: Dictionary = seq[seq_index]
	var tw := _beat(step.id, index, last)
	tw.finished.connect(_beat_done.bind(last), CONNECT_ONE_SHOT)


func _beat_done(last: bool) -> void:
	input.locked = false
	if not last or seq.is_empty():
		return
	seq_index += 1
	if seq_index < seq.size():
		_start_step()
		return
	var id := seq_station
	seq = []
	seq_station = ""
	_chain = ""
	_finish(id)
	if _chain != "" and state == State.PLAY:   # Cô Ba đưa món kế: làm luôn, khỏi ra cảnh chính
		var c := _chain
		_chain = ""
		var steps := _steps_for(c)
		if not steps.is_empty():
			_begin(c, _ease(steps))
			return
	hud.hide_step()
	cam.back_to_main()
	paw_rig.visible = false
	player.visual.visible = true
	player.can_move = state == State.PLAY
	_set_holding_visible(true)
	_idle_t = 0.0
	if first_shift and not _said.has("ra"):
		_said.ra = true
		_co_ba_say("Giỏi lắm! Thấy dấu chân vàng không? Cứ đi theo, hoặc giữ Tab là Bơ tự đi.", "vui", 4.5)


func _on_miss(text: String) -> void:
	if not easy:
		mistakes += 1
	hud.flash(text)
	_sound("play", "fail")
	if seq.is_empty():
		return
	var step: Dictionary = seq[seq_index]
	if step.id == "rot_nuoc" and text.begins_with("Quá"):
		drops.global_position = n.thau.global_position + Vector3(0, 0.08, 0)
		drops.restart()


func _on_wrong_pick(option: String) -> void:
	if _current_note() == "khong_ot" and option == "Ớt":
		_note_ok = false
		hud.flash("Phiếu ghi KHÔNG ỚT! Ổ này sai phiếu rồi")


func _show_step() -> void:
	if seq.is_empty():
		return
	var step: Dictionary = seq[seq_index]
	hud.show_step(step.name, seq_index, seq.size(), ["Bơ tự làm…"] if step.get("auto", false) else input.hint())
	match input.kind:
		"hold", "swipe", "rotate":
			hud.set_meter(input.value)
		"hold_release":
			hud.set_meter(input.value, input.zone)
		"timing":
			hud.set_meter(0.0, input.zone, input.value)
		_:
			hud.set_meter(-1.0)
	if input.kind == "pick":
		var done := []
		for i in input.options.size():
			done.append(input.is_picked(i))
		hud.set_pick(input.options, done, input.cursor)
	else:
		hud.set_pick([], [], 0)


## Kết quả sau khi làm xong cả chuỗi bước ở một trạm.
func _finish(id: String) -> void:
	if _bot:
		print("[bep] %5.1fs xong trạm %s (cầm %s)" % [time_limit - time_left, id, holding])
	match id:
		"bot":
			flour_taken = true
			_set_holding("bot")
		"nhoi":
			if holding == "bot":
				_set_holding("")
				dough_state = "proofing"
				proof_t = 0.0
				hud.show_toast("Ủ bột %d giây. Tranh thủ làm đồ chua!" % int(proof_time), 2.5)
			else:
				dough_state = "shaped"
				n.tray_raw.visible = false
				_set_holding("khay_song")
				if easy:
					_co_ba_say("Đẹp quá! Mang khay qua lò nướng nha.", "vui")
		"lo":
			if holding == "khay_song":
				_set_holding("")
				oven_state = "nuong"
				oven_t = 0.0
				_sound("loop", "oven_fire")
				if easy:
					_co_ba_say("Trong lúc nướng, qua bồn rửa rau nha. Cô đưa rổ rau cho.", "noi")
				else:
					hud.show_toast("Nướng %d giây. Tranh thủ đi lấy rau, chả, thịt!" % int(bake_time), 2.5)
			else:
				var burnt := oven_state == "chay"
				_set_holding("khay_chay" if burnt else "khay_chin")
				oven_state = "trong"
				n.oven_tray.visible = false
				smoke.emitting = false
				_sound("stop_loop", "oven_fire")
				n.mitt.reparent(self)
				var tw := create_tween()
				tw.tween_property(n.oven_door, "rotation:x", 0.0, 0.4)
				tw.parallel().tween_property(n.mitt, "global_position", n.mitt_rest, 0.3)
				if easy:
					_co_ba_say("Bánh vàng giòn thơm phức! Đem lên bàn ráp nha.", "vui")
				else:
					hud.show_toast("Ôi cháy mất rồi! Đành dùng tạm..." if burnt else "Bánh vàng giòn thơm phức!", 2.5)
		"rau", "cha", "thit":
			taken[id] = true
			_set_holding(id)
		"rua":
			_set_holding("rau_sach")
			n.wash_cuke.visible = false
			n.wash_herb.visible = false
		"thot":
			if easy:   # Cô Ba mang món đã thái sang bàn ráp, đặt món kế lên thớt
				var k := holding.trim_suffix("_sach")
				on_rap[k] = true
				_set_holding("")
				_clear_board()
				_refresh_rap()
				var next := _next_board_item()
				if next != "":
					_give_board_item(next)
					_chain = "thot"
					_co_ba_say("Để cô mang qua bàn ráp. Thêm %s nè!" % _item_name(next), "cho_banh", 2.5)
				else:
					_co_ba_say("Nhân đủ hết rồi! %s" % ("Lấy bánh ra lò rồi lên bàn ráp nha." if loaves_on_rap == 0 else "Qua bàn ráp nha."), "vui")
			else:
				_set_holding(holding.trim_suffix("_sach") + "_xong")
				_clear_board()
		"do_chua":
			do_chua_done = true
			n.chua_jar.visible = false
			n.chua_shreds.visible = false
			_set_holding("do_chua")
		"rap":
			loaves_on_rap -= 1
			_set_holding("banh_mi")
			_reset_loaf()
			_refresh_rap()
			if quick:
				_end_quick(true)
			elif easy:   # Cô Ba nhận ổ bỏ vào tủ kính
				_put_in_case()
				if state == State.PLAY:
					_chain = "rap"
					_co_ba_say("Ổ thứ nhất ngon lành! Làm thêm ổ nữa nha.", "nhan_banh", 3.0)
		"tu":
			_put_in_case()


## Ổ vừa ráp vào tủ kính, chấm sao ổ đó; đủ ổ thì xong ca.
func _put_in_case() -> void:
	_set_holding("")
	case_slots[made].visible = true
	loaf_note_ok.append(_note_ok)
	_note_ok = true
	made += 1
	# Sao của ổ này: 1 vì làm xong, +1 nếu không cháy, +1 nếu bỏ xe khi còn dư đủ giờ
	loaf_stars.append(1 + int(not bread_burnt) + int(_fast_enough()))
	if made >= LOAVES:
		_end(true)
	elif not easy:
		hud.show_toast("Xong ổ 1! Quay lại bàn ráp làm ổ 2")


## Sao thứ ba: Thong thả là xong trước khi hết 5 phút (ca đầu luôn được), Thử thách là còn dư spare_for_star.
func _fast_enough() -> bool:
	if easy:
		return first_shift or time_left > 0.0
	return time_left >= spare_for_star


# ---------------------------------------------------------------- ráp nhanh ổ trứng (Thứ Ba, sau đơn 2)

## Vào thẳng cận cảnh bàn ráp: bánh, nhân, pate đã sẵn; đập trứng, đánh trứng rồi ráp như thường.
func _start_quick() -> void:
	loaves_on_rap = 1
	bread_burnt = false
	pate_open = true
	n.pate_lid.visible = false
	n.pate_fill.visible = true
	for k in on_rap:
		on_rap[k] = true
	_refresh_rap()
	var eggs := clampi(GameState.eggs_brought, 1, 2)
	n.egg_bowl.visible = true
	for i in n.eggs.size():
		n.eggs[i].visible = i < eggs
	player.global_position = stations.rap.use
	hud.show_toast("Ráp nhanh ổ trứng cho đơn %d!" % (quick_order + 1), 2.5)
	var steps := [_s("dap_trung", "Đập trứng", "tap", {"n": eggs}),
		_s("khuay_trung", "Đánh trứng", "rotate"),
		_s("xe", "Xẻ bánh", "hold_release", {"dur": 1.6, "zone": [0.7, 0.9]})]
	steps.append_array(_assemble_steps(["Trứng", "Dưa leo", "Đồ chua", "Ngò", "Ớt"], ["Chả lụa", "Xíu mại"]))
	_begin("rap", steps)


func _end_quick(done: bool) -> void:
	if state == State.END:
		return
	state = State.END
	player.can_move = false
	hud.hide_step()
	var stars := 1
	var lines := ""
	if done:
		stars = 3 if time_left >= QUICK_SPARE else 2
		lines += "★ Ráp xong ổ trứng, còn dư %d giây\n" % int(time_left)
		if stars == 3:
			lines += "★ Nhanh tay (dư từ %d giây)\n" % int(QUICK_SPARE)
	else:
		lines += "Hết giờ! Ổ trứng đành gói vội\n"
	if GameState.eggs_brought <= 3:
		stars = mini(stars, 1)
		lines += "✗ Chỉ còn %d quả trứng nguyên: ổ trứng tối đa 1 sao\n" % GameState.eggs_brought
	var note := _current_note()
	if note != "":
		lines += ("✓ Đúng phiếu \"%s\"\n" if _note_ok else "✗ Sai phiếu \"%s\": đơn đó mất sao nguyên vẹn\n") % NOTE_NAMES[note]
	var per: Array[int] = GameState.kitchen_stars_per_bread.duplicate()
	while per.size() < GameState.ORDERS_PER_DAY:
		per.append(GameState.kitchen_stars)
	per[quick_order] = stars
	GameState.kitchen_stars_per_bread = per
	while GameState.bread_note_ok.size() < GameState.ORDERS_PER_DAY:
		GameState.bread_note_ok.append(true)
	GameState.bread_note_ok[quick_order] = _note_ok if done else true
	GameState.quick_assemble_request = -1
	lines += "\n%d/3 sao bếp cho ổ trứng của đơn %d" % [stars, quick_order + 1]
	hud.show_end(lines)
	for b in hud.end_screen.find_children("*", "Button", true, false):
		b.text = "Mang bánh đi giao (Enter)"
	_sound("music", "jingle_win" if done else "jingle_lose")
	print("[bep] rap_nhanh don=%d sao=%d trung=%d dung_phieu=%s con_lai=%.1fs truot=%d" % [quick_order + 1, stars, GameState.eggs_brought, _note_ok, time_left, mistakes])
	if _bot_quit:
		print("AUTOTEST RAP NHANH ", "OK" if done else "FAIL")
		get_tree().quit(0 if done else 1)
	elif _bot:
		get_tree().create_timer(3.0).timeout.connect(_go_delivery)


func _update_proof(delta: float) -> void:
	if dough_state != "proofing":
		return
	proof_t += delta
	var k := clampf(proof_t / proof_time, 0.0, 1.0)
	n.proof_bowl.scale = Vector3(1.0, 0.9 + 0.25 * k, 1.0)
	if proof_t >= proof_time:
		dough_state = "risen"
		_sound("play", "oven_ding")
		hud.show_toast("Bột nở rồi! Về bàn nhào tạo hình", 2.0)


func _update_oven(delta: float) -> void:
	match oven_state:
		"nuong", "chin", "chay":
			oven_t += delta
			if oven_t < bake_time:
				_loaf_look("song", BAKE_TINT.lerp(DOUGH_TINT, 1.0 - oven_t / bake_time))
				oven_label.text = "Đang nướng %d" % ceili(bake_time - oven_t)
				oven_label.modulate = Color("#FFE2A8")
			elif easy:   # Thong thả: lò tự hạ lửa giữ ấm, bánh không cháy
				if oven_state == "nuong":
					oven_state = "chin"
					_sound("play", "oven_ding")
					_co_ba_say("Bánh chín rồi Bơ ơi! Rảnh thì qua lấy, lò giữ ấm, không cháy đâu.", "noi")
				oven_t = bake_time
				_loaf_look("vang", Color.WHITE)
				oven_label.text = "CHÍN! Lấy ra"
				oven_label.modulate = Color("#9BE38B")
			elif oven_t < bake_time + burn_after:
				if oven_state == "nuong":
					oven_state = "chin"
					_sound("play", "oven_ding")
					hud.show_toast("Bánh chín rồi! Lấy ra kẻo cháy", 2.0)
				_loaf_look("vang", Color.WHITE.lerp(Color(0.7, 0.6, 0.55), (oven_t - bake_time) / burn_after))
				oven_label.text = "CHÍN! Lấy ra (%d)" % ceili(bake_time + burn_after - oven_t)
				oven_label.modulate = Color("#9BE38B") if fmod(oven_t, 0.5) < 0.3 else Color.WHITE
			else:
				if oven_state != "chay":
					oven_state = "chay"
					smoke.emitting = true
					_sound("play", "burn")
					hud.show_toast("Khói kìa! Bánh cháy rồi!", 2.0)
				_loaf_look("chay", Color.WHITE)
				oven_label.text = "CHÁY!"
				oven_label.modulate = Color("#C8412F")
		_:
			oven_label.text = ""
	fire_light.light_energy = 1.1 if oven_state != "trong" else 0.45


## Ổ trong lò: hiện dạng sống/vàng/cháy, nhuộm thêm màu cho mượt lúc chuyển.
func _loaf_look(kind: String, tint: Color) -> void:
	for l in oven_loaves:
		for k in l:
			l[k].visible = k == kind
		(l[kind].material_override as StandardMaterial3D).albedo_color = tint


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
		if _fast_enough():
			stars += 1
			if easy:
				lines += "★ Ca đầu, Cô Ba tặng sao\n" if first_shift else "★ Xong trong 5 phút\n"
			else:
				lines += "★ Còn dư %d giây (từ %d giây mới được sao)\n" % [int(time_left), int(spare_for_star)]
		elif easy:
			lines += "☆ Quá 5 phút một chút, lần sau nhanh tay hơn nha\n"
		else:
			lines += "☆ Chỉ dư %d giây (cần từ %d giây)\n" % [int(time_left), int(spare_for_star)]
	else:
		lines += "Hết giờ! Mới xong %d/%d ổ.\n" % [made, LOAVES]
	if mistakes > 0:
		lines += "Bấm trượt %d lần (mỗi lần mất chút thời gian)\n" % mistakes
	if easy and success:
		_co_ba_say("Xong 2 ổ rồi! Bơ giỏi quá, đi giao thôi!", "vui", 6.0)
	GameState.kitchen_stars = stars
	if not _bot:  # sao bếp cao nhất cho màn Chọn màn
		GameState.set_day("sao_bep", maxi(int(GameState.get_day("sao_bep", -1)), stars))
		GameState.write_save()
	# Sao từng ổ cho 5 đơn giao. Bếp mới làm LOAVES ổ: các đơn sau dùng số sao chung của ca.
	var per_bread: Array[int] = []
	for i in GameState.ORDERS_PER_DAY:
		per_bread.append(stars)
	for i in loaf_stars.size():
		per_bread[loaf_orders[i]] = loaf_stars[i]
		GameState.bread_note_ok[loaf_orders[i]] = loaf_note_ok[i]
		var note: String = GameState.bread_notes[loaf_orders[i]]
		if note != "":
			if loaf_note_ok[i]:
				lines += "✓ Ổ %d đúng phiếu \"%s\"\n" % [i + 1, NOTE_NAMES[note]]
			else:
				lines += "✗ Ổ %d sai phiếu \"%s\": đơn đó mất sao nguyên vẹn\n" % [i + 1, NOTE_NAMES[note]]
	GameState.kitchen_stars_per_bread = per_bread
	GameState.kitchen_bonus = stars * STAR_SECONDS
	lines += "\n%d/3 sao · ổ bánh 3 sao giúp đơn đó được cộng thêm %d giây" % [stars, int(Scoring.KITCHEN_BONUS_SECONDS)]
	hud.show_end(lines)
	_sound("stop_loop", "oven_fire")
	_sound("music", "jingle_win" if success else "jingle_lose")
	for i in stars:
		get_tree().create_timer(0.5 + 0.45 * i).timeout.connect(_sound.bind("play", "star_%d" % (i + 1)))
	print("[bep] thong_tha=%s ca_dau=%s that=%.1fs" % [easy, first_shift, (Time.get_ticks_msec() - _start_ms) / 1000.0])
	print("[bep] xong=%d/%d sao=%d tung_o=%s con_lai=%.1fs chay=%s truot=%d o_cho_don=%s phieu=%s dung_phieu=%s" % [made, LOAVES, stars,
		per_bread, time_left, bread_burnt, mistakes, loaf_orders, GameState.bread_notes, GameState.bread_note_ok])
	if _bot_quit:
		success = hud.self_test_menu() and success
		print("AUTOTEST BEP ", "OK" if success else "FAIL")
		get_tree().quit(0 if success else 1)
	elif _bot:
		get_tree().create_timer(3.0).timeout.connect(_go_delivery)


func _go_delivery() -> void:
	if state != State.END:
		return
	if quick:
		GameState.from_quick_assemble = true
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	if PlayMode.kitchen_only() and not _bot:
		PlayMode.back_to_menu(get_tree())
		return
	GameState.from_kitchen = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _set_holding_visible(v: bool) -> void:
	if carry_node:
		carry_node.visible = v


func _set_holding(kind: String) -> void:
	holding = kind
	if carry_node:
		carry_node.queue_free()
		carry_node = null
	if kind != "":
		_sound("play", "pickup")
		carry_node = _carry_model(kind)
		carry_node.position = Vector3(0, 0.4, 0.02)
		player.visual.add_child(carry_node)
		carry_node.scale = Vector3.ONE * 0.2
		create_tween().tween_property(carry_node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Món đang cầm, đội trên lưng Bơ (thu nhỏ cho vừa người mèo).
func _carry_model(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"bot":
			KM.place(root, "bot_dong", Vector3.ZERO, 0, 0.45)
		"khay_song", "khay_chin", "khay_chay":
			var m: String = {"khay_song": "bot_phoi", "khay_chin": "banh_vang", "khay_chay": "banh_chay"}[kind]
			KM.place(root, "khay_inox", Vector3.ZERO, 90, 0.7)
			KM.place(root, m, Vector3(-0.035, 0.02, 0), 90, 0.5)
			KM.place(root, m, Vector3(0.035, 0.02, 0), 90, 0.5)
		"rau":
			KM.place(root, "ro_tre", Vector3.ZERO, 0, 0.5)
			KM.place(root, "dua_leo", Vector3(0, 0.03, 0), 90, 0.5)
			KM.place(root, "ngo_bo", Vector3(0.03, 0.03, 0), 30, 0.4)
		"rau_sach":
			KM.place(root, "dua_leo", Vector3.ZERO, 90, 0.6)
			KM.place(root, "ngo_bo", Vector3(0.03, 0.02, 0), 30, 0.5)
			KM.place(root, "ot", Vector3(-0.03, 0.02, 0), 60, 0.6)
		"rau_xong":
			KM.place(root, "dua_leo_lat", Vector3.ZERO, 90, 0.6)
			KM.place(root, "ngo_bo", Vector3(0.03, 0.02, 0), 30, 0.4)
		"cha":
			KM.place(root, "cha_cay", Vector3.ZERO, 90, 0.5)
		"cha_xong":
			KM.place(root, "cha_khoanh", Vector3.ZERO, 90, 0.6)
		"thit":
			KM.place(root, "thit_nguoi", Vector3.ZERO, 90, 0.7)
		"thit_xong":
			KM.place(root, "thit_lat", Vector3.ZERO, 90, 0.6)
		"do_chua":
			KM.place(root, "hu_do_chua", Vector3.ZERO, 0, 0.5)
		"banh_mi":
			var w := _wrapped_loaf(root, bread_burnt)
			w.rotation_degrees.y = 90
			w.scale = Vector3.ONE * 0.6
	return root


func _item_name(kind: String) -> String:
	return {
		"bot": "bột", "khay_song": "khay bánh sống", "khay_chin": "khay bánh nướng", "khay_chay": "khay bánh cháy",
		"rau": "rổ rau", "rau_sach": "rau đã rửa", "cha": "chả lụa", "thit": "thịt nguội", "rau_xong": "dưa leo, ngò, ớt",
		"cha_xong": "chả đã thái", "thit_xong": "thịt đã thái", "do_chua": "đồ chua", "banh_mi": "ổ bánh mì",
	}.get(kind, kind)


## Trạm nên tới tiếp, dùng cho gợi ý dưới màn hình, vòng sáng và bot tự chơi.
func _suggest() -> String:
	match holding:
		"bot":
			return "nhoi"
		"khay_song":
			return "lo"
		"khay_chin", "khay_chay", "rau_xong", "cha_xong", "thit_xong", "do_chua":
			return "rap"
		"rau":
			return "rua"
		"rau_sach", "cha", "thit":
			return "thot"
		"banh_mi":
			return "tu"
	if easy:
		return _suggest_easy()
	if oven_state in ["chin", "chay"]:
		return "lo"
	if not flour_taken:
		return "bot"
	if dough_state == "risen":
		return "nhoi"
	if not do_chua_done:
		return "do_chua"
	for k in ["rau", "cha", "thit"]:
		if not taken[k]:
			return k
	if loaves_on_rap > 0:
		return "rap"
	if oven_state == "nuong":
		return "lo"
	if dough_state == "proofing":
		return "nhoi"
	return ""


## Thong thả: việc kế theo thứ tự bột → lò → rau → thớt → lấy bánh → ráp (Cô Ba lo phần mang vác).
func _suggest_easy() -> String:
	if not flour_taken:
		return "bot"
	if dough_state == "risen":
		return "nhoi"
	if dough_state == "proofing":
		return "nhoi"
	if not do_chua_done:
		return "do_chua"
	if not taken.rau:
		return "rua"
	if _next_board_item() != "":
		return "thot"
	if oven_state in ["chin", "chay"]:
		return "lo"
	if loaves_on_rap > 0:
		return "rap"
	if oven_state == "nuong":
		return "lo"
	return ""


## Một dòng việc bây giờ cho thẻ trái trên.
func _task_text() -> String:
	match holding:
		"bot":
			return "Mang bột tới bàn nhào"
		"khay_song":
			return "Cho khay bánh vào lò"
		"khay_chin", "khay_chay":
			return "Đem bánh lên bàn ráp"
		"rau":
			return "Rửa rau ở bồn"
		"rau_sach", "cha", "thit":
			return "Thái %s ở thớt" % _item_name(holding)
		"rau_xong", "cha_xong", "thit_xong", "do_chua":
			return "Đặt %s lên bàn ráp" % _item_name(holding)
		"banh_mi":
			return "Bỏ ổ bánh vào tủ kính"
	var g := _suggest()
	match g:
		"bot":
			return "Xúc bột ở bao bột"
		"nhoi":
			if dough_state == "proofing":
				return "Chờ bột nở (%d giây), làm việc khác trước" % ceili(proof_time - proof_t)
			return "Nặn bánh ở bàn nhào" if dough_state == "risen" else "Nhào bột ở bàn nhào"
		"do_chua":
			return "Làm đồ chua"
		"rau", "cha", "thit":
			return "Lấy %s ở kệ" % _item_name(g)
		"rua":
			return "Rửa rau ở bồn"
		"thot":
			return "Thái chả, thịt ở thớt"
		"lo":
			if oven_state == "nuong":
				return "Chờ bánh chín (%d giây)" % ceili(bake_time - oven_t)
			return "Lấy bánh ra khỏi lò"
		"rap":
			return "Ráp ổ %d ở bàn giữa" % (made + 1)
		"tu":
			return "Bỏ ổ bánh vào tủ kính"
	return "Xong rồi!" if made >= LOAVES else ""


func _update_hud() -> void:
	hud.set_timer(time_left, time_limit, state == State.PLAY)
	if easy and not quick:
		if first_shift:
			hud.set_clock(true, "Ca đầu · không tính giờ")
		elif not seq.is_empty():
			hud.set_clock(false, "Đồng hồ dừng khi đang làm")
		elif time_left > 0.0:
			hud.set_clock(false, "Xong trước khi hết giờ: thêm 1 sao")
		else:
			hud.set_clock(false, "Hết giờ cũng không sao, cứ làm tiếp")
		var held := _item_name(holding) if holding != "" else ""
		hud.set_task("VIỆC BÂY GIỜ · Ổ %d/%d" % [made, LOAVES], _task_text(), held)
		var oven_s: String = {"trong": "", "nuong": "Lò · đang nướng %d" % ceili(bake_time - oven_t), "chin": "Lò · bánh chín!", "chay": "Lò · cháy!"}[oven_state]
		hud.set_status(oven_s)
		_update_prompt()
		return
	var tick := func(ok: bool) -> String: return "✓" if ok else "○"
	var baked := loaves_on_rap > 0 or made > 0 or holding in ["khay_chin", "khay_chay", "banh_mi"]
	var text := "Bếp Cô Ba · 2 ổ bánh mì\n"
	text += "%s Xúc bột, nhào, ủ, tạo hình\n" % tick.call(dough_state == "shaped")
	text += "%s Nướng %d giây\n" % [tick.call(baked), int(bake_time)]
	text += "%s Đồ chua: gọt, bào, pha\n" % tick.call(on_rap.do_chua)
	text += "%s Rau: rửa, lặt ngò, cắt dưa leo, ớt\n" % tick.call(on_rap.rau)
	text += "%s Chả: cắt lạt, bóc lá, thái\n" % tick.call(on_rap.cha)
	text += "%s Thịt: bóc giấy, thái, xếp\n" % tick.call(on_rap.thit)
	text += "%s Ráp và bỏ xe: %d/%d ổ\n" % [tick.call(made >= LOAVES), made, LOAVES]
	var notes := []
	for i in loaf_orders.size():
		var note: String = GameState.bread_notes[loaf_orders[i]] if loaf_orders[i] < GameState.bread_notes.size() else ""
		if note != "":
			notes.append("ổ %d %s" % [i + 1, NOTE_NAMES[note]])
	if not notes.is_empty():
		text += "Phiếu: " + ", ".join(notes) + "\n"
	text += "\nĐang cầm: %s" % (_item_name(holding) if holding != "" else "không")
	if quick:
		text = "Ráp nhanh · 1 ổ trứng cho đơn %d\nTrứng còn nguyên: %d quả%s" % [quick_order + 1, GameState.eggs_brought,
			"\nPhiếu: " + NOTE_NAMES[_current_note()] if _current_note() != "" else ""]
	hud.set_recipe(text)
	var oven_txt: String = {"trong": "trống", "nuong": "đang nướng", "chin": "CHÍN, lấy ra!", "chay": "CHÁY!"}[oven_state]
	var dough_txt := "đang ủ %d giây" % ceili(proof_time - proof_t) if dough_state == "proofing" else ("nở rồi!" if dough_state == "risen" else "")
	hud.set_status("Ổ xong: %d/%d\nLò: %s%s" % [made, LOAVES, oven_txt, "\nBột: " + dough_txt if dough_txt != "" else ""])
	_update_prompt()


func _update_prompt() -> void:
	if seq.is_empty():
		var near := _near_station()
		if near != "":
			hud.set_prompt(stations[near].name, true)
		else:
			var g := _suggest()
			var to: String = stations[g].name.to_lower() if g != "" else ""
			if easy and to != "":
				hud.set_prompt("Giữ Tab: tự đi tới %s" % to, false)
			else:
				hud.set_prompt("Tới %s" % to if to != "" else "", false)


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


# ---------------------------------------------------------------- cận cảnh: chân Bơ

func _build_paws() -> void:
	paw_rig = Node3D.new()
	paw_rig.name = "ChanBo"
	add_child(paw_rig)
	paw_l = BoPaw.create(-1.0, PAW_SIZE, "bep", paw_breed)
	paw_rig.add_child(paw_l)
	paw_r = BoPaw.create(1.0, PAW_SIZE, "bep", paw_breed)
	paw_rig.add_child(paw_r)
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


## Điểm thế giới trong hệ chân (để đưa chân tới đúng món).
func _w(p: Vector3) -> Vector3:
	return paw_rig.to_local(p)


func _at(node: Node3D, up := 0.04) -> Vector3:
	return _w(node.global_position + Vector3(0, up, 0))


func _reach(tw: Tween, paw: Node3D, local: Vector3, dur := 0.2, parallel := false) -> void:
	var t := tw.parallel() if parallel else tw
	t.tween_property(paw, "position", local, dur).set_trans(Tween.TRANS_SINE)


func _rest(tw: Tween, dur := 0.2) -> void:
	tw.tween_property(paw_l, "position", PAW_L_REST, dur).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(paw_r, "position", PAW_R_REST, dur).set_trans(Tween.TRANS_SINE)


## Chân nhấc lên rồi ấn xuống một điểm.
func _tap(tw: Tween, paw: Node3D, target: Vector3, rest: Vector3, dur := 0.35) -> void:
	tw.tween_property(paw, "position", target + Vector3(0, 0.06, 0), dur * 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(paw, "position", target, dur * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(paw, "position", rest, dur * 0.35).set_trans(Tween.TRANS_SINE)


## Dao chặt một nhát xuống điểm p (thế giới), chân phải cầm cán.
func _chop(tw: Tween, knife: Node3D, p: Vector3) -> void:
	tw.tween_property(knife, "global_position", p + Vector3(0, 0.08, 0), 0.1)
	tw.parallel().tween_property(paw_r, "position", _w(p + Vector3(0.1, 0.09, 0.02)), 0.1)
	tw.tween_property(knife, "global_position", p + Vector3(0, 0.005, 0), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(paw_r, "position", _w(p + Vector3(0.1, 0.015, 0.02)), 0.07)
	_sound("play", "chop")


func _on_begin(id: String) -> void:
	match id:
		"nhoi":
			if dough_state == "risen":
				n.proof_bowl.visible = false
				n.towel.global_position = n.towel_rest
				n.towel.rotation = Vector3.ZERO
				n.towel.visible = true
				n.dough.visible = true
				n.dough.global_position = NHOI + Vector3(-0.3, 0, 0.06)
				n.dough.scale = Vector3(1.3, 1.25, 1.3)
				n.tray_raw.visible = true
		"lo":
			if holding == "khay_song":
				_loaf_look("song", DOUGH_TINT)   # khay hiện lúc bắt đầu đẩy vào lò
		"rua":
			n.wash_cuke.visible = true
			n.wash_herb.visible = true
			n.wash_herb.scale = Vector3.ONE * 0.8
		"thot":
			_setup_board(holding)
		"rap":
			_reset_loaf()
			loaf.base.visible = true
			_refresh_rap()
			for l in rap_loaves:   # chồng bánh chờ ráp che camera cận cảnh: cất đi trong lúc ráp
				l.visible = false


## Chuẩn bị đồ cho một bước (gọi khi bước bắt đầu).
func _on_step_start(id: String) -> void:
	match id:
		"day_khay":
			n.oven_tray.visible = true
			n.oven_tray.position.z = TRAY_OUT
		"pate":
			n.pate_knife.visible = true
		"goi":
			loaf.paper.visible = true
			loaf.paper.rotation = Vector3.ZERO
			loaf.paper.scale = Vector3(1.6, 1, 1.4)


## Bước liên tục (giữ, giữ-thả, vuốt, xoay): độ đầy v (0..1) điều khiển động tác.
func _on_progress(v: float) -> void:
	if seq.is_empty():
		return
	var id: String = seq[seq_index].id
	match id:
		"rot_nuoc":  # bê ca nước nghiêng rót vào thau, nước dâng
			var k := clampf(v * 3.0, 0.0, 1.0)
			var over: Vector3 = n.thau.global_position + Vector3(0.12, 0.13, 0)
			n.jug.global_position = (n.jug_rest as Vector3).lerp(over, k)
			n.jug.rotation.z = lerpf(0.0, 1.2, clampf(v * 2.0 - 0.2, 0.0, 1.0))
			n.stream.visible = v > 0.25
			n.water.visible = v > 0.25
			n.water.scale = Vector3(1, maxf(v, 0.05), 1)
			paw_r.position = _w(n.jug.global_position + Vector3(0.04, 0.06, 0.04))
		"day_khay", "rut_khay":  # hai chân đẩy (kéo) khay vào (ra) lò
			var z := lerpf(TRAY_OUT, TRAY_IN, v) if id == "day_khay" else lerpf(TRAY_IN, TRAY_OUT, v)
			n.oven_tray.position.z = z
			var front := Vector3(LO.x, 0.25, z + 0.25)
			paw_l.position = _w(front + Vector3(-0.12, 0.02, 0))
			paw_r.position = _w(front + Vector3(0.12, 0.02, 0))
		"boc_la":  # lớp lá chuối nhấc lên, lật ra sau, lộ đòn chả trắng
			var wrap: Node3D = board.wrap
			wrap.position = board.wrap_rest + Vector3(0, 0.1 * v, -0.15 * v)
			wrap.rotation.x = -1.4 * v
			paw_l.position = _w(wrap.global_position + Vector3(-0.05, 0.05, 0.03))
			paw_r.position = _w(wrap.global_position + Vector3(0.05, 0.05, 0.03))
		"boc_giay":  # giấy gói thịt bóc dần ra sau
			var paper: Node3D = board.paper
			paper.position = board.paper_rest + Vector3(0, 0.05 * v, -0.18 * v)
			paper.rotation.x = -1.6 * v
			paw_r.position = _w(paper.global_position + Vector3(0.04, 0.03, 0.04))
		"got":  # dao gọt chạy dọc củ cà rốt (sang phải theo hướng nhìn của Bơ), vỏ bong ra
			var a: Vector3 = n.carrot.global_position + Vector3(0, 0.05, 0.12)
			var b: Vector3 = n.carrot.global_position + Vector3(0, 0.05, -0.1)
			n.peeler.global_position = a.lerp(b, v)
			paw_r.position = _w(n.peeler.global_position + Vector3(0.03, 0.03, 0))
		"bao":  # chà cà rốt lên bàn bào, sợi rơi vào tô
			var g: Vector3 = n.grater.global_position
			n.carrot.global_position = g + Vector3(0.06, 0.15 - 0.1 * v, 0)
			n.carrot.rotation = Vector3(0, deg_to_rad(90), deg_to_rad(70))
			paw_r.position = _w(n.carrot.global_position + Vector3(0.05, 0.05, 0))
			paw_l.position = _w(g + Vector3(0.02, 0.12, 0.04))
		"pha", "khuay", "khuay_trung":  # que khuấy vẽ vòng trong tô (hộp pate, tô trứng)
			var c: Vector3 = {"pha": n.bowl_mix.global_position + Vector3(0, 0.07, 0),
				"khuay": n.pate_can.global_position + Vector3(0, 0.09, 0),
				"khuay_trung": n.egg_bowl.global_position + Vector3(0, 0.05, 0)}[id]
			var r := 0.045 if id == "pha" else (0.035 if id == "khuay_trung" else 0.025)
			var a := (input.count + v) * TAU
			var stick: Node3D = n.stirrer
			stick.visible = true
			stick.global_position = c + Vector3(cos(a) * r, 0, sin(a) * r)
			stick.rotation = Vector3(deg_to_rad(80), 0, 0)
			paw_r.position = _w(stick.global_position + Vector3(0, 0.1, 0.02))
			if id == "pha":
				n.chua_shreds.rotation.y = a * 0.3
		"khui":  # vuốt nắp hộp pate trượt ra
			n.pate_lid.position = n.pate_lid_rest + Vector3(0.09 * v, 0.02 * v, 0)
			paw_r.position = _w(n.pate_lid.global_position + Vector3(0.0, 0.03, 0.02))
		"pate":  # quệt pate dọc ruột bánh
			loaf.smear.visible = true
			loaf.smear.scale = Vector3(maxf(v, 0.02), 1, 1)
			paw_r.position = _w(loaf.base.global_position + Vector3(-0.15 + 0.3 * v, 0.07, 0.03))
			n.pate_knife.global_position = paw_r.global_position + Vector3(-0.03, -0.02, -0.02)
		"xe":  # dao xẻ dọc ổ bánh; thả sai vùng là dao quay về đầu ổ
			var p0: Vector3 = loaf.base.global_position + Vector3(-0.17, 0.045, 0.0)
			n.rap_knife.global_position = p0 + Vector3(0.34 * minf(v, 1.0), 0, 0)
			n.rap_knife.rotation = Vector3(0, 0, 0)
			paw_r.position = _w(n.rap_knife.global_position + Vector3(0.12, 0.03, 0.02))
			paw_l.position = _w(loaf.base.global_position + Vector3(0.06, 0.08, 0.02))


## Một nhịp animation cho bước `step`. i = nhịp thứ mấy (0..n-1).
func _beat(step: String, i: int, last: bool) -> Tween:
	var tw := create_tween()
	match step:
		"xuc":  # thò chân vào miệng bao, bột tung lên
			var top := BAO + Vector3(0, 0.26, 0)
			_reach(tw, paw_r, _w(top + Vector3(0, 0.1, 0.02)), 0.18)
			_reach(tw, paw_r, _w(top - Vector3(0, 0.03, 0)), 0.12)
			tw.tween_callback(func(): flour_puff.restart())
			tw.tween_property(paw_r, "position", PAW_R_REST + Vector3(0, 0.05, 0), 0.25).set_delay(0.1)
			_sound("play", "knead")
		"do_bot":  # trút bột vào thau
			n.flour.visible = true
			n.flour.scale = Vector3.ONE * 0.05
			_reach(tw, paw_r, _at(n.thau, 0.12), 0.18)
			_reach(tw, paw_l, _at(n.thau, 0.12) + Vector3(-0.06, 0, 0), 0.18, true)
			tw.tween_property(n.flour, "scale", Vector3.ONE * 0.5, 0.35).set_trans(Tween.TRANS_BACK)
			tw.parallel().tween_callback(func(): flour_puff.global_position = n.thau.global_position + Vector3(0, 0.08, 0); flour_puff.restart())
			_rest(tw)
		"rot_nuoc":  # rót xong: đặt ca về chỗ
			tw.tween_callback(func(): n.stream.visible = false)
			tw.tween_property(n.jug, "rotation:z", 0.0, 0.2)
			tw.tween_property(n.jug, "global_position", n.jug_rest, 0.25)
			_rest(tw)
			_sound("play", "water")
		"nhao":  # hai chân thay nhau ấn, cục bột bẹp rồi phồng lại
			if i == 0:
				n.flour.visible = false
				n.water.visible = false
				n.dough.visible = true
				n.dough.global_position = n.thau.global_position + Vector3(0, 0.02, 0)
				n.dough.scale = Vector3(1.2, 0.7, 1.2)
			var paw := paw_l if i % 2 == 0 else paw_r
			var rest := PAW_L_REST if i % 2 == 0 else PAW_R_REST
			_tap(tw, paw, _at(n.dough, 0.06) + Vector3(0.025 * (1 if i % 2 else -1), 0, 0), rest, 0.28)
			tw.parallel().tween_property(n.dough, "scale", Vector3(1.35, 0.6, 1.25), 0.1).set_delay(0.1)
			tw.tween_property(n.dough, "scale", Vector3(1.0 + i * 0.015, 0.85, 1.0), 0.1).set_trans(Tween.TRANS_BACK)
			_sound("play", "knead")
		"u":  # khăn bay tới phủ lên thau, thau đổi thành tô ủ có khăn
			_reach(tw, paw_r, _w(n.towel_rest + Vector3(0, 0.03, 0.03)), 0.15)
			tw.tween_property(n.towel, "global_position", n.thau.global_position + Vector3(0, 0.1, 0), 0.3).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(paw_r, "position", _at(n.thau, 0.12), 0.3)
			tw.tween_callback(func():
				n.towel.visible = false
				n.thau.visible = false
				n.dough.visible = false
				n.proof_bowl.visible = true
				n.proof_bowl.scale = Vector3(1, 0.9, 1)
			)
			_rest(tw)
		"chia":  # dao cắt bột cắt một viên, viên bột lăn sang khay
			var b := balls[i]
			var p0: Vector3 = n.dough.global_position
			if i == 0:
				n.towel.visible = false
			tw.tween_property(n.scraper, "global_position", p0 + Vector3(0.05, 0.12, 0), 0.12)
			tw.parallel().tween_property(paw_r, "position", _w(p0 + Vector3(0.1, 0.13, 0.03)), 0.12)
			tw.tween_property(n.scraper, "global_position", p0 + Vector3(0.05, 0.01, 0), 0.08)
			tw.parallel().tween_property(paw_r, "position", _w(p0 + Vector3(0.1, 0.02, 0.03)), 0.08)
			tw.tween_callback(func():
				b.visible = true
				b.global_position = p0 + Vector3(0.06, 0, 0)
				n.dough.scale *= 0.7
				if i == balls.size() - 1:
					n.dough.visible = false
			)
			tw.tween_property(b, "global_position", raw_loaves[i].global_position, 0.25)
			tw.parallel().tween_property(n.scraper, "global_position", n.scraper_rest, 0.25)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.25)
			_sound("play", "chop")
		"lan":  # hai chân lăn viên bột thành ổ dài
			var k := i / 4
			var b := balls[k]
			var l := raw_loaves[k]
			var tgt := _at(l, 0.04)
			if i % 4 == 0:
				b.visible = false
				l.visible = true
				l.scale = Vector3(0.45, 1.2, 1.4)
			var dz := 0.03 if i % 2 == 0 else -0.03
			tw.tween_property(paw_l, "position", tgt + Vector3(-0.06, 0, dz), 0.12)
			tw.parallel().tween_property(paw_r, "position", tgt + Vector3(0.06, 0, -dz), 0.12)
			tw.parallel().tween_property(l, "scale", Vector3(0.45 + 0.55 * float(i % 4 + 1) / 4.0, 1.2 - 0.2 * float(i % 4 + 1) / 4.0, 1.4 - 0.4 * float(i % 4 + 1) / 4.0), 0.12)
			tw.parallel().tween_property(l, "rotation:x", dz * 8.0, 0.12)
			if i % 4 == 3:
				tw.tween_property(l, "rotation:x", 0.0, 0.08)
				_rest(tw, 0.12)
		"rach":  # dao rạch đường xéo trên mặt ổ
			var l := raw_loaves[i]
			var p: Vector3 = l.global_position + Vector3(0, 0.07, 0)
			tw.tween_property(n.scraper, "global_position", p + Vector3(-0.12, 0.02, 0), 0.1)
			tw.parallel().tween_property(paw_r, "position", _w(p + Vector3(-0.06, 0.04, 0.03)), 0.1)
			tw.tween_property(n.scraper, "global_position", p + Vector3(0.1, -0.015, 0), 0.18)
			tw.parallel().tween_property(paw_r, "position", _w(p + Vector3(0.14, 0.02, 0.03)), 0.18)
			tw.tween_callback(func(): slashes[i].visible = true)
			tw.tween_property(n.scraper, "global_position", n.scraper_rest, 0.2)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.2)
		"mo_cua", "deo_gang":  # (đeo găng) nắm mép trên cửa lò, kéo cửa lật xuống
			var top: Vector3 = n.oven_door.global_position + Vector3(0, 0.28, 0.04)
			if step == "deo_gang":
				tw.tween_property(n.mitt, "global_position", paw_r.global_position + Vector3(0, -0.01, 0), 0.25)
				tw.tween_callback(func(): n.mitt.reparent(paw_r))
			_reach(tw, paw_r, _w(top), 0.2)
			tw.tween_property(n.oven_door, "rotation:x", PI * 0.5, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(paw_r, "position", _w(top + Vector3(0, -0.22, 0.22)), 0.4)
			tw.tween_callback(func():
				if holding == "":   # mở lò lấy bánh: khay đang trong lò
					n.oven_tray.visible = true
					n.oven_tray.position.z = TRAY_IN
				mist.restart()
			)
			_rest(tw)
			_sound("play", "oven_open")
		"xit":  # bình xịt phun hơi nước vào miệng lò
			var s0: Vector3 = n.spray_rest
			var aim := Vector3(LO.x + 0.1, 0.42, -0.75)
			tw.tween_property(n.spray, "global_position", aim, 0.15 if i > 0 else 0.25)
			tw.parallel().tween_property(paw_r, "position", _w(aim + Vector3(0.03, 0.1, 0.04)), 0.15 if i > 0 else 0.25)
			tw.tween_callback(func(): mist.restart())
			tw.tween_property(n.spray, "rotation:x", -0.35, 0.06)
			tw.tween_property(n.spray, "rotation:x", 0.0, 0.08)
			if last:
				tw.tween_property(n.spray, "global_position", s0, 0.2)
				tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.2)
			_sound("play", "spray")
		"day_khay", "rut_khay":
			if step == "rut_khay":
				tw.tween_callback(func(): mist.restart())
				_sound("play", "crunch")
			_rest(tw)
		"dong_cua":
			var top: Vector3 = n.oven_door.global_position + Vector3(0, 0.03, 0.3)
			_reach(tw, paw_r, _w(top), 0.2)
			tw.tween_property(n.oven_door, "rotation:x", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(paw_r, "position", _w(n.oven_door.global_position + Vector3(0, 0.3, 0.05)), 0.35)
			_rest(tw)
		"lay":  # vươn chân nhấc món trên bàn nguyên liệu
			var item: Node3D = n["ke_" + seq_station]
			var p0 := item.position
			_reach(tw, paw_r, _at(item, 0.05), 0.2)
			_reach(tw, paw_l, _at(item, 0.05) + Vector3(-0.06, 0, 0), 0.2, true)
			tw.tween_property(item, "position", p0 + Vector3(0, 0.1, 0.12), 0.25)
			tw.parallel().tween_property(paw_r, "position", _at(item, 0.05) + Vector3(0, 0.1, 0.12), 0.25)
			tw.parallel().tween_property(paw_l, "position", _at(item, 0.05) + Vector3(-0.06, 0.1, 0.12), 0.25)
			tw.tween_callback(func(): item.visible = false; item.position = p0)
			_rest(tw)
		"chai_rua":  # chà dưa leo trong bồn, nước bắn
			var c: Node3D = n.wash_cuke
			var paw := paw_l if i % 2 == 0 else paw_r
			var rest := PAW_L_REST if i % 2 == 0 else PAW_R_REST
			tw.tween_callback(func(): drops.global_position = c.global_position + Vector3(0, 0.05, 0); drops.restart())
			_tap(tw, paw, _at(c, 0.03) + Vector3(0.03 * (1 if i % 2 else -1), 0, 0), rest, 0.22)
			tw.parallel().tween_property(c, "rotation:x", c.rotation.x + 1.2, 0.22)
			if i == 0:
				_sound("play", "water")
		"nhung":  # nhúng bó ngò xuống nước rồi nhấc lên lắc
			var h: Node3D = n.wash_herb
			var down := i % 2 == 0
			var y: float = RUA.y + (0.15 if down else 0.27)
			tw.tween_property(h, "global_position:y", y, 0.14).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(paw_r, "position", _w(Vector3(h.global_position.x, y + 0.06, h.global_position.z + 0.02)), 0.14)
			tw.parallel().tween_property(h, "rotation:z", 0.0 if down else 0.25 * (1 if i % 4 == 1 else -1), 0.14)
			if not down:
				tw.tween_callback(func(): drops.global_position = h.global_position; drops.restart())
			if last:
				tw.tween_property(h, "global_position:y", RUA.y + 0.22, 0.12)
				tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.12)
		"lat":  # ngắt một phần bó ngò, ném đi
			var h: Node3D = n.wash_herb
			var bit := KM.place(self, "ngo_bo", h.global_position + Vector3(0.05 - 0.05 * i, 0.02, 0), 40.0 * i, 0.3)
			_reach(tw, paw_r, _at(bit, 0.02), 0.14)
			tw.tween_property(bit, "global_position", h.global_position + Vector3(0.3, 0.25, 0.1), 0.3).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(paw_r, "position", _w(h.global_position + Vector3(0.12, 0.12, 0.08)), 0.25)
			tw.parallel().tween_property(h, "scale", Vector3.ONE * (0.8 - 0.07 * (i + 1)), 0.2)
			tw.tween_callback(bit.queue_free)
			tw.tween_property(paw_r, "position", PAW_R_REST, 0.15)
		"cat_dau":  # chặt một đầu dưa leo, mẩu đầu văng ra
			var c: Node3D = board.cuke
			var side := -1.0 if i == 0 else 1.0
			var p: Vector3 = c.global_position + Vector3(side * 0.085, 0.02, 0)
			_chop(tw, board.knife, p)
			tw.tween_callback(func():
				var end := KM.place(self, "dua_leo", p + Vector3(side * 0.015, -0.02, 0), 0, 1.0)
				end.scale = Vector3(0.12, 1, 1)
				board.bits.append(end)
				var tw2 := create_tween()
				tw2.tween_property(end, "global_position", end.global_position + Vector3(side * 0.08, 0, 0.04), 0.2)
				c.scale.x -= 0.08
			)
			tw.tween_property(board.knife, "global_position", board.knife_rest, 0.15)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.15)
		"che_doc":  # chẻ dọc: lần cuối dưa leo tách thành 4 lát
			var c: Node3D = board.cuke
			_chop(tw, board.knife, c.global_position + Vector3(0, 0.02, 0))
			tw.tween_callback(func():
				if last:
					c.visible = false
					board.strips.visible = true
				else:
					c.scale.z *= 0.8
			)
			tw.tween_property(board.knife, "global_position", board.knife_rest, 0.12)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.12)
		"cat_ot":  # thái ớt thành khoanh
			var o: Node3D = board.chili
			var p: Vector3 = o.global_position + Vector3(0.04 - 0.02 * i, 0.01, 0)
			_chop(tw, board.knife, p)
			tw.tween_callback(func():
				var s: Node3D = board.chili_slices[i]
				s.visible = true
				o.scale.x = maxf(o.scale.x - 0.22, 0.15)
				if last:
					o.visible = false
			)
			tw.tween_property(board.knife, "global_position", board.knife_rest, 0.1)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.1)
		"cat_lat":  # cắt sợi lạt buộc đòn chả
			var band: Node3D = board.bands[i]
			_chop(tw, board.knife, band.global_position + Vector3(0, 0.06, 0))
			tw.tween_callback(func(): band.visible = false)
			tw.tween_property(board.knife, "global_position", board.knife_rest, 0.12)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.12)
		"boc_la":
			tw.tween_callback(func(): board.wrap.visible = false)
			_rest(tw)
		"cat_doi":  # chặt đôi đòn chả
			var c: Node3D = board.cha
			_chop(tw, board.knife, c.global_position + Vector3(0, 0.05, 0))
			tw.tween_callback(func():
				c.visible = false
				for h in board.halves:
					h.visible = true
				var tw2 := create_tween()
				tw2.tween_property(board.halves[0], "position:x", board.halves[0].position.x - 0.03, 0.15)
				tw2.parallel().tween_property(board.halves[1], "position:x", board.halves[1].position.x + 0.03, 0.15)
			)
			tw.tween_property(board.knife, "global_position", board.knife_rest, 0.15)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.15)
		"thai_cha", "thai_thit":  # thái một lát, lát mới xếp ra
			var src: Node3D = board.halves[0] if step == "thai_cha" else board.meat
			_chop(tw, board.knife, src.global_position + Vector3(0.03, 0.04, 0))
			tw.tween_callback(func():
				if step == "thai_cha":
					board.slices.visible = true
					board.slices.scale = Vector3(float(i + 1) / 4.0, 1, 1)
					for h in board.halves:
						h.scale.x = maxf(h.scale.x - 0.12, 0.3)
					if last:
						for h in board.halves:
							h.visible = false
				else:
					board.meat_slices[i].visible = true
					src.scale.x = maxf(src.scale.x - 0.18, 0.2)
					if last:
						src.visible = false
			)
			tw.tween_property(board.knife, "global_position", board.knife_rest, 0.1)
			tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.1)
		"boc_giay":
			tw.tween_callback(func(): board.paper.visible = false)
			_rest(tw)
		"xep_quat":  # gạt từng lát thịt xoè ra hình quạt
			var s: Node3D = board.meat_slices[i]
			var paw := paw_l if i % 2 == 0 else paw_r
			var rest := PAW_L_REST if i % 2 == 0 else PAW_R_REST
			_reach(tw, paw, _at(s, 0.02), 0.1)
			tw.tween_property(s, "rotation:y", deg_to_rad(-45 + 30 * i), 0.15)
			tw.parallel().tween_property(s, "global_position", THOT + Vector3(-0.02 + 0.015 * i, 0.003 * i, 0.02), 0.15)
			tw.parallel().tween_property(paw, "position", _w(THOT + Vector3(-0.02 + 0.015 * i, 0.03, 0.05)), 0.15)
			tw.tween_property(paw, "position", rest, 0.1)
		"got":  # một dải vỏ bong ra
			var peel := KM.place(self, "ca_rot", n.peeler.global_position + Vector3(0, -0.01, 0), 90, 1.0)
			peel.scale = Vector3(0.5, 0.15, 0.2)
			tw.tween_property(peel, "global_position", peel.global_position + Vector3(0.12, 0.08, 0), 0.2)
			tw.tween_callback(peel.queue_free)
			_reach(tw, paw_r, PAW_R_REST, 0.12)
			_sound("play", "chop")
		"bao":  # củ cà rốt ngắn dần, tô đầy sợi
			tw.tween_callback(func():
				n.carrot.scale = Vector3(maxf(1.0 - 0.3 * (i + 1), 0.1), 1, 1)
				n.chua_shreds.visible = true
				n.chua_shreds.scale = Vector3.ONE * (0.35 + 0.2 * (i + 1))
				if last:
					n.carrot.visible = false
			)
			_rest(tw, 0.12)
			_sound("play", "chop")
		"dap_trung":  # cầm quả trứng gõ vào miệng tô, trứng rơi vào tô
			var egg: Node3D = n.eggs[i]
			var rim: Vector3 = n.egg_bowl.global_position + Vector3(0.05, 0.08, 0)
			_reach(tw, paw_r, _at(egg, 0.03), 0.15)
			tw.tween_property(egg, "global_position", rim + Vector3(0, 0.05, 0), 0.2)
			tw.parallel().tween_property(paw_r, "position", _w(rim + Vector3(0.03, 0.08, 0.03)), 0.2)
			tw.tween_property(egg, "global_position", rim, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				egg.visible = false
				n.egg_in_bowl.visible = true
				n.egg_in_bowl.scale = Vector3.ONE * (0.45 + 0.15 * i)
				_sound("play", "crunch")
			)
			_rest(tw)
		"pha", "khuay", "khuay_trung":
			if last:
				tw.tween_callback(func(): n.stirrer.visible = false)
				_rest(tw)
			else:
				tw.tween_interval(0.02)
		"khui":
			tw.tween_property(n.pate_lid, "position", n.pate_lid_rest + Vector3(0.14, -0.02, 0.04), 0.15)
			tw.tween_callback(func(): n.pate_lid.visible = false; n.pate_fill.visible = true; pate_open = true)
			_rest(tw, 0.12)
		"pate":
			tw.tween_callback(func(): n.pate_knife.visible = false)
			_rest(tw)
		"xe":  # xẻ xong: nắp bánh mở ra
			tw.tween_callback(func():
				loaf.lid.visible = true
				loaf.lid.rotation.x = 0.0
			)
			tw.tween_property(loaf.lid, "rotation:x", -0.9, 0.25).set_trans(Tween.TRANS_BACK)
			tw.parallel().tween_property(n.rap_knife, "global_position", n.rap_knife_rest, 0.25)
			_rest(tw)
			_sound("play", "crunch")
		"xep_nhan":  # gắp đúng món, thả vào ổ
			var name: String = input.order[i]
			var piece: Node3D = loaf.pieces.get(name)
			if piece:
				var goal := piece.position
				piece.visible = true
				piece.position = goal + Vector3(0, 0.12, 0.08)
				_reach(tw, paw_r, _w(piece.global_position + Vector3(0, 0.03, 0.02)), 0.12)
				tw.tween_property(piece, "position", goal, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(paw_r, "position", _w(loaf.base.global_position + Vector3(0, 0.08, 0.04)), 0.15)
			if last:
				tw.tween_callback(func():
					for k in loaf.pieces:
						loaf.pieces[k].visible = false
					loaf.base.visible = false
					loaf.lid.visible = false
					loaf.smear.visible = false
					loaf.done.visible = true
				)
				_rest(tw)
		"xi_dau":  # chai xì dầu nghiêng rưới dọc ổ
			var s0: Vector3 = n.sauce_rest
			var over: Vector3 = loaf.done.global_position + Vector3(0.1 - 0.15 * i, 0.15, 0.02)
			tw.tween_property(n.sauce, "global_position", over, 0.18)
			tw.parallel().tween_property(paw_r, "position", _w(over + Vector3(0.03, 0.03, 0.03)), 0.18)
			tw.tween_property(n.sauce, "rotation:z", 2.2, 0.12)
			tw.tween_callback(func(): drops.global_position = over + Vector3(-0.05, -0.04, 0); drops.restart())
			tw.tween_property(n.sauce, "rotation:z", 0.0, 0.12)
			if last:
				tw.tween_property(n.sauce, "global_position", s0, 0.2)
				tw.parallel().tween_property(paw_r, "position", PAW_R_REST, 0.2)
			_sound("play", "sauce")
		"goi":  # giấy cuộn dần quanh ổ, nhịp cuối thành ổ gói giấy
			var paw := paw_l if i % 2 == 0 else paw_r
			var rest := PAW_L_REST if i % 2 == 0 else PAW_R_REST
			_tap(tw, paw, _at(loaf.paper, 0.04) + Vector3(0.04 * (1 if i % 2 else -1), 0, 0), rest, 0.22)
			tw.parallel().tween_property(loaf.paper, "scale", Vector3(1.6 - 0.15 * (i + 1), 1, 1.4 - 0.2 * (i + 1)), 0.2)
			if last:
				tw.tween_callback(func():
					loaf.done.visible = false
					loaf.paper.visible = false
					loaf.wrapped.visible = true
				)
			_sound("play", "wrap")
		"bo_vao":  # đẩy ổ đã gói vào tủ kính xe bánh mì
			var slot := case_slots[made]
			var w := _wrapped_loaf(self, bread_burnt)
			w.global_position = paw_rig.to_global(Vector3(0, 0.03, 0.08))
			tw.tween_property(w, "global_position", slot.global_position, 0.35).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(paw_r, "position", _w(slot.global_position + Vector3(0, 0.04, -0.06)), 0.35)
			tw.tween_callback(w.queue_free)
			_rest(tw)
	tw.tween_interval(0.04)
	return tw


# ---------------------------------------------------------------- trạng thái đồ ở trạm

func _setup_board(kind: String) -> void:
	_clear_board()
	board.knife = KM.place(self, "dao", THOT + Vector3(0.0, 0.0, 0.17), 0)
	board.knife_rest = board.knife.global_position
	board.bits = []
	match kind:
		"rau_sach":
			board.cuke = KM.place(self, "dua_leo", THOT + Vector3(0, 0, -0.04), 0)
			board.strips = KM.place(self, "dua_leo_lat", THOT + Vector3(0, 0, -0.04), 0)
			board.strips.visible = false
			board.chili = KM.place(self, "ot", THOT + Vector3(0.0, 0, 0.07), 0)
			board.chili_slices = []
			for i in 4:
				var s := KM.place(self, "ot_lat", THOT + Vector3(-0.07 + 0.025 * i, 0, 0.1), 90)
				s.visible = false
				board.chili_slices.append(s)
		"cha":
			board.cha = KM.place(self, "cha_boc", THOT + Vector3(0, 0, -0.02), 0)
			board.cha.scale = Vector3(2.4, 0.9, 0.9)
			var wrap := Node3D.new()
			add_child(wrap)
			wrap.global_position = THOT + Vector3(0, 0, -0.02)
			KM.place(wrap, "cha_cay", Vector3(0, -0.012, 0), 0)
			board.wrap = wrap
			board.wrap_rest = wrap.position
			board.bands = []
			for x in [-0.07, 0.07]:
				var band := Blocks.box(self, Vector3(0.008, 0.13, 0.13), THOT + Vector3(x, 0.055, -0.02), Color("#C9A877"))
				board.bands.append(band)
			board.halves = []
			for x in [-0.055, 0.055]:
				var h := KM.place(self, "cha_boc", THOT + Vector3(x, 0, -0.02), 0)
				h.scale = Vector3(1.15, 0.9, 0.9)
				h.visible = false
				board.halves.append(h)
			board.slices = KM.place(self, "cha_khoanh", THOT + Vector3(0, 0, 0.09), 0, 0.8)
			board.slices.visible = false
		"thit":
			board.meat = KM.place(self, "thit_nguoi", THOT + Vector3(0, 0, -0.03), 90)
			var paper := Node3D.new()
			add_child(paper)
			paper.global_position = THOT + Vector3(0, 0.1, -0.03)
			KM.place(paper, "giay_goi", Vector3.ZERO, 90, 0.9)
			board.paper = paper
			board.paper_rest = paper.position
			board.meat_slices = []
			for i in 4:
				var s := KM.place(self, "thit_lat", THOT + Vector3(-0.1 + 0.05 * i, 0.002 * i, 0.1), 90, 0.55)
				s.visible = false
				board.meat_slices.append(s)


func _clear_board() -> void:
	for k in board:
		var v = board[k]
		if v is Node:
			v.queue_free()
		elif v is Array:
			for x in v:
				if x is Node:
					x.queue_free()
	board.clear()


func _reset_loaf() -> void:
	for k in ["base", "lid", "smear", "done", "paper", "wrapped"]:
		loaf[k].visible = false
	for k in loaf.pieces:
		loaf.pieces[k].visible = false
	var burnt := bread_burnt
	loaf.base.get_child(0).visible = not burnt
	loaf.base.get_child(1).visible = burnt
	loaf.lid.get_child(0).visible = not burnt
	loaf.lid.get_child(1).visible = burnt


func _refresh_rap() -> void:
	for i in rap_loaves.size():
		rap_loaves[i].visible = i < loaves_on_rap
		rap_loaves[i].get_child(0).visible = not bread_burnt
		rap_loaves[i].get_child(1).visible = bread_burnt
	for k in on_rap:
		n["rap_" + k].visible = on_rap[k]


## Ổ bánh gói giấy (như ổ giao cho khách): bánh nằm trong ống giấy trắng sọc đỏ.
func _wrapped_loaf(parent: Node, burnt: bool) -> Node3D:
	var w := Node3D.new()
	parent.add_child(w)
	KM.place(w, "banh_chay" if burnt else "banh_vang", Vector3.ZERO)
	for side in [-1, 1]:
		var p := KM.place(w, "giay_goi", Vector3(0.0, 0.0, side * 0.04), 0, 1.0)
		p.rotation_degrees.x = 90 * side
		p.scale = Vector3(0.85, 1, 0.5)
	var top := KM.place(w, "giay_goi", Vector3(0, 0.078, 0), 0, 1.0)
	top.scale = Vector3(0.85, 1, 0.5)
	return w


# ---------------------------------------------------------------- dựng phòng và trạm

func _build_room(room: Node3D) -> void:
	# Sàn gạch bông 40 cm: kem xen hồng như thẻ p_soche (khối phẳng: 1 viên gach_bong.glb 600 tam giác,
	# lát cả sàn thì quá nặng cho bản web)
	for x in range(-7, 7):
		for z in range(-5, 5):
			var c := Color("#F3E9D8") if (x + z) % 2 == 0 else Color("#EBD6C0")
			var p := Vector3(x * 0.4 + 0.2, -0.02, z * 0.4 + 0.2)
			Blocks.box(room, Vector3(0.39, 0.04, 0.39), p, c)
			Blocks.box(room, Vector3(0.09, 0.042, 0.09), p, Color("#E39AA0") if (x + z) % 2 == 0 else Color("#7FB7A4"))
	var floor_body := StaticBody3D.new()
	room.add_child(floor_body)
	var fs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(8, 0.2, 6)
	fs.shape = fb
	fs.position.y = -0.1
	floor_body.add_child(fs)

	Blocks.solid_box(room, Vector3(5.6, 2.4, 0.1), Vector3(0, 1.2, -1.8), Color("#F2D9A6"))
	Blocks.solid_box(room, Vector3(0.1, 2.4, 3.6), Vector3(-2.7, 1.2, 0), Color("#EBCB8E"))
	Blocks.solid_box(room, Vector3(0.1, 2.4, 3.6), Vector3(2.7, 1.2, 0), Color("#EBCB8E"))
	Blocks.box(room, Vector3(5.6, 0.36, 0.02), Vector3(0, 0.18, -1.74), Color("#7FB7A4"))
	for i in 14:
		Blocks.box(room, Vector3(0.015, 0.36, 0.022), Vector3(-2.6 + i * 0.4, 0.18, -1.73), Color("#5F978A"))
	# Cửa sổ sau bếp, nắng chiếu vào
	Blocks.box(room, Vector3(0.8, 0.55, 0.02), Vector3(-1.25, 1.1, -1.74), Color("#BFE3EE"))
	Blocks.box(room, Vector3(0.88, 0.05, 0.05), Vector3(-1.25, 0.8, -1.72), Color("#8A5A30"))
	Blocks.box(room, Vector3(0.04, 0.55, 0.03), Vector3(-1.25, 1.1, -1.72), Color("#8A5A30"))
	# Lịch treo tường
	Blocks.box(room, Vector3(0.28, 0.38, 0.02), Vector3(1.55, 1.0, -1.74), Color("#FFF8EA"))
	Blocks.box(room, Vector3(0.28, 0.08, 0.022), Vector3(1.55, 1.15, -1.73), Color("#C8412F"))
	Blocks.invisible_wall(room, Vector3(6, 2, 0.2), Vector3(0, 1, 1.8))
	# Đèn thả đỏ, sọt rác, củi cạnh lò, cây cán bột
	for p in [Vector3(-1.25, 1.35, -1.25), Vector3(0.3, 1.35, 0.15)]:
		KM.place(room, "den_treo", p)
	KM.solid(room, "thung_rac", Vector3(2.3, 0, 1.45))
	KM.place(room, "lo_cui", Vector3(-0.45, 0, -1.55), 10)
	KM.place(room, "cay_can", CHUA + Vector3(0.0, 0, -0.42), 90)
	KM.place(room, "cu_cai", CHUA + Vector3(-0.12, 0, -0.32), 70)
	KM.place(room, "hu_men", NHOI + Vector3(0.42, 0, -0.18))


func _station(id: String, title: String, use: Vector3, work: Vector3) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.17
	torus.outer_radius = 0.21
	torus.rings = 24
	torus.ring_segments = 4
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.2)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.position = use + Vector3(0, 0.02, 0)
	add_child(ring)
	# Camera cận cảnh đặt ngay trên đầu Bơ nhìn xuống bàn, như Bơ nhìn chân mình
	var back := Vector3(use.x - work.x, 0, use.z - work.z).normalized()
	var cam_pos := work + back * CLOSE_BACK + Vector3.UP * CLOSE_UP
	var look := work - back * CLOSE_AHEAD
	stations[id] = {"name": title, "use": use, "work": work, "cam": cam_pos, "look": look, "ring": ring}


func _build_stations(room: Node3D) -> void:
	# 1. Bao bột
	KM.solid(room, "bao_bot", BAO)
	_station("bot", "Bao bột", Vector3(BAO.x, 0, -1.0), BAO + Vector3(0, 0.25, 0))
	flour_puff = _particles(BAO + Vector3(0, 0.28, 0), Color(1, 1, 1, 0.85), 24, 0.012, -0.6)

	# 2. Bàn nhào: thau bột, ca nước, khăn ủ, dao cắt bột, khay bánh sống
	KM.solid(room, "ban_nhao", Vector3(NHOI.x, 0, NHOI.z))
	_station("nhoi", "Bàn nhào bột", Vector3(NHOI.x, 0, -0.82), NHOI + Vector3(-0.1, 0, 0.07))
	n.thau = KM.place(self, "thau", NHOI + Vector3(-0.3, 0, 0.06))
	n.flour = KM.place(self, "bot_dong", NHOI + Vector3(-0.3, 0.01, 0.06), 0, 0.5)
	n.flour.visible = false
	n.water = Blocks.mesh(self, _disc(0.1, 0.03), NHOI + Vector3(-0.3, 0.02, 0.06), WATER)
	n.water.visible = false
	n.dough = KM.place(self, "bot_khoi_nhao", NHOI + Vector3(-0.3, 0.02, 0.06))
	n.dough.visible = false
	n.proof_bowl = KM.place(self, "bot_u_to", NHOI + Vector3(-0.3, 0, 0.06))
	n.proof_bowl.visible = false
	n.jug_rest = NHOI + Vector3(0.4, 0, -0.12)
	n.jug = KM.place(self, "ca_nuoc", n.jug_rest, 0)
	n.stream = Blocks.mesh(self, _disc(0.008, 0.13), NHOI + Vector3(-0.22, 0.08, 0.06), WATER)
	n.stream.visible = false
	n.towel_rest = NHOI + Vector3(0.4, 0, 0.14)
	n.towel = KM.place(self, "khan_u", n.towel_rest, 0, 0.6)
	n.scraper_rest = NHOI + Vector3(-0.42, 0, -0.18)
	n.scraper = KM.place(self, "dao_lam", n.scraper_rest, 90)
	n.tray_raw = Node3D.new()
	add_child(n.tray_raw)
	n.tray_raw.global_position = NHOI + Vector3(0.08, 0, 0.0)
	KM.own(n.tray_raw, "khay_inox", Vector3.ZERO, 0, 1.25, TRAY_TINT)
	for i in LOAVES:
		var lp := Vector3(0.0, 0.02, -0.06 + i * 0.12)
		var b := KM.place(n.tray_raw, "bot_khoi_nhao", lp, 0, 0.55)
		b.visible = false
		balls.append(b)
		var l := KM.own(n.tray_raw, "bot_phoi", lp, 0, 0.75, DOUGH_TINT)
		l.visible = false
		raw_loaves.append(l)
		var sl := Node3D.new()
		l.add_child(sl)
		for k in 3:
			var cut := Blocks.box(sl, Vector3(0.006, 0.012, 0.045), Vector3(-0.07 + k * 0.07, 0.075, 0), Color("#C9A877"))
			cut.rotation_degrees.y = 35
		sl.visible = false
		slashes.append(sl)
	n.tray_raw.visible = false

	# 3. Lò gạch: cửa lật xuống (bản lề ở mép dưới), khay trượt, lửa phát sáng, bình xịt, găng
	KM.solid(room, "lo_gach", LO)
	_station("lo", "Lò gạch", Vector3(LO.x, 0, -0.5), Vector3(LO.x, 0.3, -0.86))
	n.oven_door = KM.place(self, "lo_cua", LO + Vector3(0, 0.23, 0.385))
	var fire := KM.own(self, "lo_lua", LO + Vector3(0, 0.235, -0.1), 0, 0.9)
	var fm: StandardMaterial3D = fire.material_override
	fm.emission_enabled = true
	fm.emission = Color("#FF8A2A")
	fm.emission_energy_multiplier = 1.6
	n.oven_tray = Node3D.new()
	add_child(n.oven_tray)
	n.oven_tray.position = Vector3(LO.x, 0.25, TRAY_OUT)
	KM.own(n.oven_tray, "lo_khay", Vector3.ZERO, 0, 1.0, TRAY_TINT)  # khay sẫm hơn để bột kem nổi lên
	for i in LOAVES:
		var d := {}
		for k in ["song", "vang", "chay"]:
			var model: String = {"song": "bot_phoi", "vang": "banh_vang", "chay": "banh_chay"}[k]
			d[k] = KM.own(n.oven_tray, model, Vector3(0, 0.012, -0.08 + i * 0.16), 0, 0.8 if k == "song" else 0.75, DOUGH_TINT if k == "song" else Color.WHITE)
		oven_loaves.append(d)
	n.oven_tray.visible = false
	oven_label = Blocks.label(self, "", LO + Vector3(0, 1.0, 0.25), 40)
	oven_label.pixel_size = 0.0035   # chữ nhỏ trên nóc lò, không đè đồng hồ
	n.spray_rest = LO + Vector3(0.62, 0, 0.42)
	n.spray = KM.place(self, "binh_xit", n.spray_rest)
	n.mitt_rest = LO + Vector3(0.62, 0, 0.6)
	n.mitt = KM.place(self, "gang_lo", n.mitt_rest, -30)
	mist = _particles(LO + Vector3(0, 0.42, 0.4), Color(1, 1, 1, 0.5), 30, 0.015, 0.2)
	smoke = _particles(LO + Vector3(0, 0.62, 0.42), Color(0.25, 0.25, 0.25, 0.6), 30, 0.035, 0.4)
	smoke.one_shot = false
	smoke.lifetime = 1.6
	smoke.explosiveness = 0.0
	smoke.emitting = false

	# 4. Bàn nguyên liệu: rổ tre (dưa leo, ngò, ớt), đòn chả gói lá trên khay, khúc thịt nguội trên khay
	KM.solid(room, "ban_nhao", Vector3(KE.x, 0, KE.z))
	var ke := {"rau": -0.33, "cha": 0.02, "thit": 0.35}
	for k in ke:
		var p: Vector3 = KE + Vector3(ke[k], 0, 0.02)
		if k != "rau":
			KM.place(room, "khay_inox", p, 90, 1.0)
		var item := Node3D.new()
		add_child(item)
		item.position = p + Vector3(0, 0.0 if k == "rau" else 0.03, 0)
		match k:
			"rau":
				KM.place(item, "ro_tre", Vector3.ZERO, 0, 0.9)
				KM.place(item, "dua_leo", Vector3(-0.03, 0.03, 0.03), 20)
				KM.place(item, "ngo_bo", Vector3(0.04, 0.035, -0.04), 60, 0.7)
				KM.place(item, "ot", Vector3(0.03, 0.04, 0.06), -30)
			"cha":
				KM.place(item, "cha_cay", Vector3.ZERO, 90, 0.75)
			"thit":
				KM.place(item, "thit_nguoi", Vector3.ZERO, 90)
		n["ke_" + k] = item
		var title: String = {"rau": "Rổ rau", "cha": "Chả lụa", "thit": "Thịt nguội"}[k]
		_station(k, title, Vector3(p.x, 0, -0.82), p + Vector3(0, 0.04, 0.05))

	# 5. Bồn rửa sát tường phải, vòi quay vào bếp
	KM.solid(room, "bon_rua", RUA, -90)
	_station("rua", "Bồn rửa", Vector3(1.95, 0, RUA.z), RUA + Vector3(-0.02, 0.17, 0))
	n.wash_cuke = KM.place(self, "dua_leo", RUA + Vector3(-0.02, 0.16, 0.06), 90)
	n.wash_herb = KM.place(self, "ngo_bo", RUA + Vector3(-0.02, 0.22, -0.07), 90, 0.8)
	n.wash_cuke.visible = false
	n.wash_herb.visible = false

	# 6. Bàn thớt: thớt gỗ tròn
	KM.solid(room, "ban_nhao", Vector3(2.25, 0, THOT.z), 90)
	KM.place(room, "thot", Vector3(THOT.x, 0.341, THOT.z))
	_station("thot", "Thớt", Vector3(1.66, 0, THOT.z), THOT)
	drops = _particles(THOT + Vector3(0, 0.2, 0), Color(0.5, 0.75, 0.95, 0.8), 24, 0.006, -3.0)
	drops.direction = Vector3.UP
	drops.spread = 60.0

	# 7. Bàn đồ chua sát tường trái: hũ đồ chua, tô trộn, bàn bào, cà rốt, dao gọt
	KM.solid(room, "ban_nhao", Vector3(CHUA.x, 0, CHUA.z), 90)
	_station("do_chua", "Bàn đồ chua", Vector3(-1.72, 0, CHUA.z), CHUA + Vector3(0.05, 0, 0.05))
	n.chua_jar = KM.place(self, "hu_do_chua", CHUA + Vector3(-0.1, 0, 0.42))
	n.bowl_mix = KM.place(self, "to_phoi", CHUA + Vector3(0.05, 0, -0.12))
	n.chua_shreds = KM.place(self, "do_chua_chen", CHUA + Vector3(0.05, 0.02, -0.12), 0, 0.5)
	n.chua_shreds.visible = false
	n.grater = KM.place(self, "ban_bao", CHUA + Vector3(-0.08, 0, 0.1), 90)
	n.carrot_rest = CHUA + Vector3(0.12, 0, 0.2)
	n.carrot = KM.place(self, "ca_rot", n.carrot_rest, 90)
	n.peeler = KM.place(self, "dao_lam", CHUA + Vector3(0.18, 0, 0.42), 0)
	n.stirrer = KM.place(self, "dao_lam", Vector3.ZERO, 0)
	n.stirrer.visible = false

	# 8. Bàn ráp: 3 bát nhân sẵn trên bàn, ổ bánh nướng, hộp pate, chai xì dầu
	KM.solid(room, "ban_rap", Vector3(RAP.x, 0, RAP.z))
	_station("rap", "Bàn ráp bánh", Vector3(RAP.x, 0, 0.75), RAP + Vector3(0, 0, 0.08))
	for i in LOAVES:
		var l := Node3D.new()
		add_child(l)
		l.global_position = RAP + Vector3(0.0, 0.075 * i, -0.0)
		KM.place(l, "banh_vang", Vector3.ZERO, 0, 0.85)
		KM.place(l, "banh_chay", Vector3.ZERO, 0, 0.85)
		rap_loaves.append(l)
	n.rap_cha = KM.place(self, "cha_khoanh", RAP + Vector3(-0.2, 0.03, -0.1), 0, 0.45)
	n.rap_rau = KM.place(self, "dua_leo_lat", RAP + Vector3(0.0, 0.03, -0.1), 0, 0.5)
	n.rap_thit = KM.place(self, "thit_lat", RAP + Vector3(0.2, 0.03, -0.1), 0, 0.45)
	n.rap_do_chua = KM.place(self, "do_chua_chen", RAP + Vector3(0.29, 0, 0.0), 0, 0.45)
	n.pate_can = KM.place(self, "pate_hop", RAP + Vector3(-0.28, 0, 0.13))
	n.pate_lid_rest = RAP + Vector3(-0.28, 0.108, 0.13)
	n.pate_lid = Blocks.mesh(self, _disc(0.047, 0.006), n.pate_lid_rest, Color("#E8913A"))
	n.pate_fill = Blocks.mesh(self, _disc(0.044, 0.004), n.pate_lid_rest - Vector3(0, 0.002, 0), PATE)
	n.pate_fill.visible = false
	n.pate_knife = KM.place(self, "dao_lam", RAP + Vector3(-0.2, 0.0, 0.2), 0)
	n.pate_knife.visible = false
	n.sauce_rest = RAP + Vector3(0.3, 0, 0.16)
	n.sauce = KM.place(self, "chai_xi_dau", n.sauce_rest)
	n.rap_knife_rest = RAP + Vector3(0.18, 0, 0.2)
	n.rap_knife = KM.place(self, "dao", n.rap_knife_rest, 0, 0.8)
	# Trứng cho ráp nhanh (chỉ hiện ở chế độ ráp nhanh)
	n.egg_bowl = KM.place(self, "to_bo_trung", RAP + Vector3(-0.02, 0, -0.01))
	n.egg_bowl.visible = false
	n.egg_in_bowl = KM.place(self, "trung_vo", RAP + Vector3(-0.02, 0.02, -0.01), 0, 0.5)
	n.egg_in_bowl.visible = false
	n.eggs = []
	for i in 2:
		var e := KM.place(self, "trung", RAP + Vector3(-0.15 - 0.045 * i, 0, 0.0 + 0.035 * i))
		e.visible = false
		n.eggs.append(e)
	var lp := RAP + Vector3(0, 0, 0.12)
	loaf.base = _loaf_pair(lp, 1.0)
	loaf.lid = _loaf_pair(lp + Vector3(0, 0.035, -0.035), 1.0)
	loaf.lid.scale = Vector3(1, 0.6, 0.85)
	loaf.smear = Blocks.box(self, Vector3(0.28, 0.006, 0.03), lp + Vector3(0, 0.07, 0), PATE)
	loaf.done = KM.place(self, "banh_bo", lp, 0)
	loaf.paper = KM.place(self, "giay_goi", lp + Vector3(0, -0.002, 0), 0)
	loaf.wrapped = _wrapped_loaf(self, false)
	loaf.wrapped.global_position = lp
	loaf.pieces = {
		"Thịt nguội": KM.place(self, "thit_lat", lp + Vector3(0, 0.07, 0), 0, 0.55),
		"Chả lụa": KM.place(self, "cha_khoanh", lp + Vector3(0, 0.075, 0), 0, 0.55),
		"Dưa leo": KM.place(self, "dua_leo_lat", lp + Vector3(0, 0.085, 0.01), 0, 0.65),
		"Đồ chua": KM.place(self, "do_chua_chen", lp + Vector3(0.09, 0.08, 0), 0, 0.3),
		"Ngò": KM.place(self, "ngo_bo", lp + Vector3(-0.07, 0.09, 0), 0, 0.45),
		"Ớt": KM.place(self, "ot_lat", lp + Vector3(0.03, 0.1, 0), 0, 1.2),
		"Trứng": KM.place(self, "trung_vo", lp + Vector3(0, 0.07, 0), 0, 0.55),
		"Thêm pate": Blocks.box(self, Vector3(0.24, 0.01, 0.034), lp + Vector3(0, 0.076, 0), PATE),
		"Thêm đồ chua": KM.place(self, "do_chua_chen", lp + Vector3(-0.09, 0.08, 0), 0, 0.3),
	}
	_reset_loaf()
	_refresh_rap()

	# 9. Xe bánh mì (tủ kính) phía trước: camera nhìn xuyên kính vào bếp
	var cart := KM.solid(room, "xe_banh_mi", XE)
	cart.get_child(0).reparent(self)   # thân xe tách khỏi phòng để tách kính trong
	var cart_mesh: MeshInstance3D = get_child(get_child_count() - 1)
	KM.split_glass(cart_mesh, Color("bee5e7"))
	_station("tu", "Xe bánh mì", Vector3(XE.x, 0, 0.6), XE + Vector3(0, 0.53, -0.12))
	for i in LOAVES:
		var slot := Node3D.new()
		add_child(slot)
		slot.global_position = XE + Vector3(-0.2 + i * 0.4, 0.53, 0.0)
		var w := _wrapped_loaf(slot, false)
		w.rotation_degrees.y = 8
		slot.visible = false
		case_slots.append(slot)


## Ổ bánh nướng hai dạng (vàng, cháy) chồng nhau; bật tắt theo bread_burnt.
func _loaf_pair(pos: Vector3, s: float) -> Node3D:
	var l := Node3D.new()
	add_child(l)
	l.global_position = pos
	KM.place(l, "banh_vang", Vector3.ZERO, 0, s)
	KM.place(l, "banh_chay", Vector3.ZERO, 0, s)
	return l


func _disc(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 16
	c.rings = 1
	return c


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
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.4
	p.gravity = Vector3(0, gravity_y, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	add_child(p)
	return p


# ---------------------------------------------------------------- môi trường, phím

func _setup_environment() -> void:
	AnhSang.build(self, "bep_sang")  # nắng xiên qua cửa sổ sau: scripts/anh_sang.gd
	for p in [Vector3(-1.25, 1.2, -1.25), Vector3(0.3, 1.2, 0.15)]:
		var lamp := OmniLight3D.new()
		lamp.position = p
		lamp.light_color = Color("#FFC98A")
		lamp.light_energy = 0.22 if AnhSang.is_compat() else 0.4  # đèn bàn chỉ ấm nhẹ, mạnh hơn thì mặt bàn và sàn kem bị lóa
		lamp.light_specular = 0.2
		lamp.omni_range = 2.6
		add_child(lamp)
	fire_light = OmniLight3D.new()
	fire_light.position = LO + Vector3(0, 0.4, 0.6)
	fire_light.light_color = Color("#FF8A3A")
	fire_light.light_energy = 0.45
	fire_light.omni_range = 1.2
	add_child(fire_light)


func _setup_input() -> void:
	_action("move_forward", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_action("move_back", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_action("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("jump", [KEY_SPACE], [JOY_BUTTON_A], [])
	_action("sprint", [KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_X], [])
	_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START], [])
	_action("interact", [KEY_E, KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_B], [])
	_action("tu_di", [KEY_TAB], [JOY_BUTTON_Y], [])
	# Chuột trái cũng là E trong cận cảnh (bấm, giữ, canh giờ); kéo chuột để vuốt, vẽ vòng để xoay
	var has_mouse := false
	for e in InputMap.action_get_events("interact"):
		has_mouse = has_mouse or e is InputEventMouseButton
	if not has_mouse:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("interact", mb)


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


# ---------------------------------------------------------------- Cô Ba và chỉ đường

## Cô Ba đứng góc phải sau bếp, nhìn theo Bơ (người thật, cao 1,55 m; bếp cỡ mèo nhưng tường cao 2,4 m).
func _build_co_ba() -> void:
	if not ResourceLoader.exists("res://assets/models/nguoi/coba.glb"):
		return
	co_ba = NguoiScript.make("coba", "dung_yen")
	co_ba.position = CO_BA_POS
	var to := Vector3(0.2, 0, 0.2) - CO_BA_POS
	co_ba.rotation.y = atan2(to.x, to.z)
	add_child(co_ba)
	co_ba.look_target = player
	co_ba.add_collision(Vector3(0.45, 1.5, 0.35), Vector3(0, 0.75, 0))


## Cô Ba làm một động tác (noi, vay, vui, cho_banh, nhan_banh) rồi về đứng yên.
func _co_ba(anim_name: String) -> void:
	if co_ba == null:
		return
	if anim_name in NguoiScript.ONE_SHOT:
		co_ba.play_once(anim_name)
	else:
		co_ba.play_for(anim_name, 2.2)


## Cô Ba nói (thẻ lời giữa trên) kèm động tác.
func _co_ba_say(text: String, anim_name := "noi", secs := 3.5) -> void:
	if _bot:
		print("[bep] %5.1fs Cô Ba: %s" % [time_limit - time_left, text])
	hud.say(text, secs)
	_co_ba(anim_name)


## Đứng không làm gì lâu (không đi, không cận cảnh): Cô Ba nhắc việc kế.
func _update_idle(delta: float) -> void:
	if not easy or quick or state != State.PLAY:
		return
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.2
	_idle_t = 0.0 if moving else _idle_t + delta
	if _idle_t >= (IDLE_NAG * 0.6 if first_shift else IDLE_NAG):
		_idle_t = 0.0
		var t := _task_text()
		if t != "":
			_co_ba_say("Bơ ơi, %s nha! Giữ Tab là tự đi tới đó." % t.to_lower(), "noi", 3.5)


## Dấu chân vàng trên sàn tới trạm kế (một MultiMesh: nệm chân + 3 ngón) và bong bóng trên trạm.
func _build_guides() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.004
	disc.radial_segments = 12
	disc.rings = 1
	mm.mesh = disc
	mm.instance_count = TRAIL_PAWS * 4
	mm.visible_instance_count = 0
	trail = MultiMeshInstance3D.new()
	trail.name = "DauChan"
	trail.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#F7D35E", 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail.material_override = mat
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)
	bubble = Label3D.new()
	bubble.name = "BongBong"
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.fixed_size = true
	bubble.pixel_size = 0.0009
	bubble.font_size = 40
	bubble.outline_size = 18
	bubble.modulate = Color("#1F3A3D")
	bubble.outline_modulate = Color("#F7D35E")
	bubble.render_priority = 5
	bubble.visible = false
	add_child(bubble)


func _update_guides(delta: float, goal: String, near: String) -> void:
	if trail == null:
		return
	var show := easy and not quick and state == State.PLAY and seq.is_empty() and goal != "" and near != goal
	bubble.visible = easy and not quick and state == State.PLAY and seq.is_empty() and goal != ""
	if bubble.visible:
		var st: Dictionary = stations[goal]
		bubble.text = st.name
		bubble.global_position = st.work + Vector3(0, 0.42 + 0.03 * sin(Time.get_ticks_msec() * 0.005), 0)
	if not show:
		trail.multimesh.visible_instance_count = 0
		return
	_trail_t -= delta
	if _trail_t > 0.0:
		return
	_trail_t = 0.25
	var path := _route(player.global_position, stations[goal].use)
	path.push_front(player.global_position)
	# Rải dấu chân cách nhau 0,2 m dọc đường, so le trái phải, bỏ đoạn sát chân Bơ
	var k := 0
	var walked := 0.0
	var next_at := 0.35
	for i in range(1, path.size()):
		var a: Vector3 = path[i - 1]
		var b: Vector3 = path[i]
		var seg := Vector2(b.x - a.x, b.z - a.z)
		var len := seg.length()
		if len < 0.001:
			continue
		var dir := seg / len
		while next_at <= walked + len and k < TRAIL_PAWS:
			var p := a.lerp(b, (next_at - walked) / len)
			var side := Vector2(-dir.y, dir.x) * (0.05 if k % 2 == 0 else -0.05)
			var yaw := atan2(dir.x, dir.y)
			var base := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x + side.x, 0.025, p.z + side.y))
			_paw_print(k, base)
			k += 1
			next_at += 0.26
		walked += len
	trail.multimesh.visible_instance_count = k * 4


func _paw_print(k: int, base: Transform3D) -> void:
	var mm := trail.multimesh
	mm.set_instance_transform(k * 4, base * Transform3D(Basis.from_scale(Vector3(0.048, 1, 0.04)), Vector3.ZERO))
	for t in 3:
		var off := Vector3((t - 1) * 0.04, 0, 0.055 + (0.01 if t == 1 else 0.0))
		mm.set_instance_transform(k * 4 + 1 + t, base * Transform3D(Basis.from_scale(Vector3(0.019, 1, 0.021)), off))


## Giữ Tab: Bơ tự đi theo đường tới trạm kế (như bot), thả Tab là đứng lại.
func _auto_walk_step(_delta: float) -> void:
	var want := easy and state == State.PLAY and Input.is_action_pressed("tu_di")
	var goal := _suggest() if want else ""
	if goal == "" or _near_station() == goal:
		if _auto_walk:
			_auto_walk = false
			_auto_goal = ""
			_bot_release()
		return
	if not _auto_walk or goal != _auto_goal or _auto_path.is_empty():
		_auto_walk = true
		_auto_goal = goal
		_auto_path = _route(player.global_position, stations[goal].use)
	var p := player.global_position
	var next: Vector3 = _auto_path[0]
	var d := Vector2(next.x - p.x, next.z - p.z)
	if d.length() < (0.08 if _auto_path.size() == 1 else 0.15):
		_auto_path.pop_front()
		return
	var dir := d.normalized() * clampf(d.length() * 3.0, 0.35, 1.0)
	_bot_axis("move_right", "move_left", dir.x)
	_bot_axis("move_back", "move_forward", dir.y)


# ---------------------------------------------------------------- tự chơi

## Lưới đi được cho bot: ô 10 cm, chặn chỗ có bàn, lò, xe (nới thêm bằng bán kính thân Bơ).
func _build_grid() -> void:
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, int(5.2 / GRID), int(3.4 / GRID))
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	var edge := int(0.25 / GRID)
	for gx in _grid.region.size.x:
		for gy in _grid.region.size.y:
			if gx < edge or gy < edge or gx >= _grid.region.size.x - edge or gy >= _grid.region.size.y - edge:
				_grid.set_point_solid(Vector2i(gx, gy))
	for body: StaticBody3D in find_children("*", "StaticBody3D", true, false):
		if body.collision_layer != Blocks.LAYER_PROP:
			continue
		for cs: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
			var box := cs.shape as BoxShape3D
			if box == null:
				continue
			var xf := cs.global_transform
			var half := box.size * 0.5
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					var c := xf * Vector3(half.x * sx, 0, half.z * sz)
					lo = lo.min(Vector2(c.x, c.z))
					hi = hi.max(Vector2(c.x, c.z))
			lo -= Vector2.ONE * 0.24
			hi += Vector2.ONE * 0.24
			for gx in range(_cell(lo).x, _cell(hi).x + 1):
				for gy in range(_cell(lo).y, _cell(hi).y + 1):
					if _grid.is_in_boundsv(Vector2i(gx, gy)):
						_grid.set_point_solid(Vector2i(gx, gy))


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - GRID_ORIGIN.x) / GRID), floori((p.y - GRID_ORIGIN.y) / GRID))


func _route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var path: Array[Vector3] = []
	var a := _cell(Vector2(from.x, from.z))
	var b := _cell(Vector2(to.x, to.z))
	if _grid.is_point_solid(a):
		_grid.set_point_solid(a, false)  # Bơ đứng sát mép vùng cấm: cho đi ra
	var pts := _grid.get_id_path(a, b)
	for k in range(1, pts.size() - 1, 2):
		var c: Vector2i = pts[k]
		path.append(Vector3(GRID_ORIGIN.x + (c.x + 0.5) * GRID, 0, GRID_ORIGIN.y + (c.y + 0.5) * GRID))
	path.append(to)
	return path


## Bot đi theo gợi ý _suggest(): tìm đường trên lưới tới trạm, bấm E, để KitchenInput tự làm từng bước.
func _bot_step(delta: float) -> void:
	if not seq.is_empty():
		_bot_release()
		return
	var goal := _suggest()
	if oven_state == "nuong" and holding == "":
		goal = "lo"  # bot đứng canh lò cho khỏi cháy (người chơi thì tranh thủ đi lấy nhân)
	if goal == "":
		_bot_release()
		return
	var waiting := (goal == "lo" and oven_state == "nuong") or (goal == "nhoi" and dough_state == "proofing")
	if waiting and _near_station() == goal:
		_bot_release()  # đứng chờ bánh chín, bột nở
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
	if d.length() < (0.08 if _bot_path.size() == 1 else 0.15):
		_bot_path.pop_front()
		return
	var dir := d.normalized() * clampf(d.length() * 3.0, 0.35, 1.0)
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
