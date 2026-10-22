class_name ThuNam
extends Node3D
## Thứ Năm · Lên tầng năm (gói việc thiet-ke-man/goi-viec-thu-nam.md). Khối tạm tới khi có model (trang G1 bản 2).
## main.gd thêm node này mọi ngày, ngày khác tự gỡ. Cả ngày bật động tác leo (bám mép, đạp tường).
## deliveries.gd chuyển bốn cách giao mới qua đây (deliveries.thu_nam.step):
## - shelf: Chú Tư ngủ gật trước sạp báo. Đặt bánh lên nóc tủ báo cao shelf_height: nhảy, đẩy về phía tủ để
##   bám mép rồi Space kéo lên. Rón rén cho Chú Tư ngủ yên (nhiệm vụ tu_ngu_yen).
## - shutter: trưa tiệm xe kéo cửa cuốn. Vào bằng khe 1,2 m bên hông (ThuSau.build_khe), ra hẻm sau, vào cửa sau,
##   đưa cho Anh Hùng nằm võng trong tiệm. Mái tôn 3 m trên khe: lên tới đó chỉ bằng đạp tường (dap_lien).
## - đơn ngược "da" (delivery errand_da): bịch đá Cô Hai tan dần theo ice_melt_time (chỉ để nhìn và nhiệm vụ phụ).
##   Đường tắt mát: thùng, cục nóng lên dãy mái hiên khối 1 rồi đi trên mái về lò.
## - loft: Chị Mây nghỉ trên gác lửng quán cà phê. Thùng → cục nóng → bám mép gác. Thong thả: đứng trước quầy
##   bấm Q gọi thì chị thả giỏ xuống (loft_call_basket), nhưng mất nhiệm vụ len_gac.
## - scene: đơn 5 Bé Na. Tới cổng LÔ B chung cư thì sang cảnh chung_cu.tscn (giữ sao, boa, tem của ngày),
##   giao xong ở cửa 5B-1 thì quay về phố tổng kết. chung_cu.gd hỏi ThuNam.in_day().
## Trưa oi (chỉ Thử thách): đứng ngoài nắng trên mặt đường lâu thì Bơ đi chậm lại (heat_slow), vào bóng râm là hết.

const DAY := "thu_nam"
const KINDS := ["shelf", "shutter", "loft", "scene"]

## Đơn 1 · sạp báo (mặt tiền khối 2 ở z = -7): ghế Chú Tư, sạp, tủ báo cao bên trái ghế
const TU_SEAT := Vector3(-1.0, 0, -6.63)
const SHELF := Vector3(-2.3, 0, -6.62)          ## chân tủ báo
const SHELF_SIZE := Vector2(0.9, 0.6)
const TU_WAKE_NOISE := 6.0                      ## Thử thách: tiếng đi thường trở lên làm Chú Tư thức
## Đơn 2 · tiệm xe (x 29,5..35, mặt tiền z 24, cửa sau z 16,7), khe hông x 28,3..29,5
const SHOP := Rect2(29.6, 16.8, 5.3, 7.15)
const SHUTTER_Z := 24.06
const HAMMOCK := Vector3(30.7, 0, 23.25)        ## giữa võng, căng dọc trục x
const HUNG_REACH := 1.7
const TIN_ROOF := Rect2(28.3, 17.0, 1.2, 3.5)   ## mái tôn trên khe, phía sau cổng tôn
const TIN_ROOF_Y := 3.0
## Đơn 3 · đường tắt mát: hai bậc ở góc đông khối 1, lên dãy mái hiên (y 2,96) đi về lò
const SHADE_STEPS := [Vector3(-24.5, 0.7, -5.55), Vector3(-25.3, 1.75, -5.55)]
## Đơn 4 · cà phê Mây (mặt tiền khối 5 ở z = 7, mái hiên z 6..7 cao 2,9 m)
const LOFT := Rect2(6.4, 5.0, 2.4, 2.0)         ## sàn gác lửng (khối tạm, dày 0,4 m để bám mép) nhô ra trên mái hiên
const LOFT_Y := 3.05
const MAY_LOFT := Vector3(7.5, LOFT_Y, 6.75)
const LOFT_STEPS := [Vector3(10.6, 0.6, 5.3), Vector3(9.9, 1.2, 5.3), Vector3(9.2, 1.9, 5.35)]
const COUNTER_CALL := Vector3(5.4, 0, 5.5)      ## đứng trước quầy gọi Chị Mây
const BASKET_TIME := 1.4
## Đơn 5 · cổng LÔ B chung cư trên bản đồ (x cảnh chung cư = x bản đồ − 22, cổng cảnh x 18,1)
const GATE := Vector3(40.1, 0, -15.0)

const WOOD := Color("#9B6A3A")
const STEEL := Color("#8C949A")
const GUIDE := Color("#F6C945")

## Tiến độ ngày cất lại khi sang cảnh chung cư, biến static nên còn nguyên khi đổi scene.
static var _scene_order := -1
static var _scene_late := false
static var _stash := {}
static var _result := {}

var main: Node3D
var player: CharacterBody3D
var hud: Node
var deliveries: Node
var orders: Array = []
var autotest := false

var tu: Nguoi
var hung: Nguoi
var may: Nguoi
var tu_woke := false
var _tu_zzz: Label3D
var _shelf_loaf: Node3D
## Đạp tường lên mái tôn mà chưa chạm đất (y < 0,3) lần nào kể từ lúc rời đất
var _kicked := false
var dap_ok := false
var ice_left := 1.0
var _ice_half_told := false
var _ice_bag: MeshInstance3D
var _basket: Node3D
var _basket_t := -1.0
var called_may := false
var _sun_t := 0.0
var _heat_on := false
var _switching := false
var _carrying := -1
var _prompt: Label3D
var _told := {}


## Đang chơi đơn chung cư trong ngày Thứ Năm (không phải chơi thử cảnh riêng từ màn Chọn màn).
static func in_day() -> bool:
	return _scene_order >= 0


## Chỉ số đơn chung cư trong ngày (để Scoring ghi đúng ô).
static func scene_order() -> int:
	return maxi(_scene_order, 0)


## Đường phố tới cổng chung cư đã trễ giờ: cảnh chung cư tính trễ luôn.
static func scene_late() -> bool:
	return _scene_late


## chung_cu.gd gọi khi Bé Na nhận bánh: cất kết quả rồi quay về phố.
static func finish_scene(tree: SceneTree, r: Dictionary, note: String) -> void:
	_result = {"r": r, "note": note}
	tree.paused = false
	tree.change_scene_to_file(PlayMode.DELIVERY_SCENE)


## main.gd hỏi lúc bắt đầu: vừa từ cảnh chung cư về, có kết quả chờ chấm.
static func pending() -> bool:
	return not _stash.is_empty() and not _result.is_empty()


## Lấy lại tiến độ ngày, ghi đơn chung cư rồi đi tiếp (thường là tổng kết ngày).
static func resume(m: Node) -> void:
	var s := _stash
	var res := _result
	_stash = {}
	_result = {}
	_scene_order = -1
	m.order_index = s.order_index
	m.results = s.results
	m.result_notes = s.result_notes
	m.score_rows = s.score_rows
	var ok: Array = s.side_ok
	for k in mini(ok.size(), m.deliveries.side_ok.size()):
		m.deliveries.side_ok[k] = ok[k]
	var i: int = m.order_index
	var r: Dictionary = res.r
	m.deliveries.side_ok[i] = r.get("side_ok", false)
	m.score_rows.append(r)
	m.results.append(r.stars)
	m.result_notes.append(res.note)
	m.player.global_position = GATE + Vector3(0, 0.1, 1.4)
	m.player.carrying = false
	m.player.can_move = true
	if not m._autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	m.hud.start_screen.visible = false
	m.hud.show_playing_ui(true)
	m._show_progress()
	m.residents.order_done(r.stars, r.get("late", false))
	m.hud.show_toast("Giao xong cho Bé Na! %d sao · boa %s" % [r.stars, m._money(r.get("tip", 0))], 2.5)
	m._leaving = true  # đứng yên một chút ở cổng chung cư rồi mới tổng kết
	m.get_tree().create_timer(1.6).timeout.connect(func():
		m._leaving = false
		m.order_delivered.emit(i, m.orders[i])
		m._next_order())


func _ready() -> void:
	name = "ThuNam"
	main = get_parent()
	if main == null or not "day" in main or main.day.get("id", "") != DAY:
		queue_free()
		return
	if not pending():
		_scene_order = -1  # bỏ dở cảnh chung cư lần trước (về menu giữa chừng)
		_stash = {}
	orders = main.orders
	player = main.player
	deliveries = main.deliveries
	autotest = "--autotest" in OS.get_cmdline_user_args()
	if not InputMap.has_action("goi"):
		InputMap.add_action("goi", 0.2)
		var k := InputEventKey.new()
		k.physical_keycode = KEY_Q
		InputMap.action_add_event("goi", k)
		var b := InputEventJoypadButton.new()
		b.button_index = JOY_BUTTON_LEFT_SHOULDER
		InputMap.action_add_event("goi", b)
	if _has("shelf"):
		_build_shelf()
	if _has("shutter"):
		_build_shop()
	if _has_errand("da"):
		_build_shade_path()
	if _has("loft"):
		_build_loft()
	if _has("scene"):
		Blocks.label(self, "%d. Bé Na\nChung cư LÔ B · tầng 5" % (_index("scene") + 1), GATE + Vector3(0, 2.6, 0), 40)
	_prompt = Blocks.label(self, "", Vector3.ZERO, 28, Color("#F2C14E"))
	_prompt.no_depth_test = true
	_prompt.visible = false
	_setup.call_deferred()


## Sau khi main dựng xong HUD và deliveries.setup.
func _setup() -> void:
	hud = main.hud
	deliveries.thu_nam = self
	# Cả ngày leo được, số dễ giống cảnh chung cư (DoKho)
	player.climb_moves = true
	player.ledge_reach = DoKho.v("ledge_reach", player.ledge_reach)
	player.wall_kick_max = DoKho.v("wall_kick_max", player.wall_kick_max)
	player.wall_gap_max = DoKho.v("wall_gap_max", player.wall_gap_max)
	player.pipe_speed = DoKho.v("pipe_speed", player.pipe_speed)
	player.ledge_grabbed.connect(func(): _tell("bam", "Đang bám mép: Space để leo lên, S để buông.", 3.0))
	player.wall_kicked.connect(func(_n): _kicked = true)
	player.noise_made.connect(_on_noise)
	main.order_picked_up.connect(_on_pick_up)
	main.order_delivered.connect(func(_i, _o):
		_carrying = -1
		_prompt.visible = false
		if _ice_bag:
			_ice_bag.visible = false)


func _has(kind: String) -> bool:
	return _index(kind) >= 0


func _index(kind: String) -> int:
	for i in orders.size():
		if orders[i].get("delivery", "") == kind:
			return i
	return -1


func _has_errand(item: String) -> bool:
	for o in orders:
		if o.get("kind", "") == "errand" and o.get("errand_item", "") == item:
			return true
	return false


# ---------------------------------------------------------------- dựng cảnh (khối tạm)

## Sạp báo trưa vắng: Chú Tư ngủ gật trên ghế, sạp thấp bên phải, tủ báo cao bên trái.
func _build_shelf() -> void:
	var i := _index("shelf")
	var h: float = DoKho.v("shelf_height", 1.9)
	Blocks.solid_box(self, Vector3(0.42, 0.45, 0.42), TU_SEAT + Vector3(0, 0.225, -0.07), Color("#3D7FC1"), Blocks.LAYER_PROP)
	var stand := Blocks.collider(self, Vector3(1.7, 0.95, 0.7), TU_SEAT + Vector3(1.4, 0.475, 0.03), Blocks.LAYER_PROP)
	PhoModels.put(stand, "sap_bao", Vector3(0, -0.475, 0))
	# Tủ báo: thân gỗ, cửa kính, nóc phẳng đặt bánh
	Blocks.solid_box(self, Vector3(SHELF_SIZE.x, h, SHELF_SIZE.y), SHELF + Vector3(0, h / 2.0, 0), Color("#7A5230"), Blocks.LAYER_PROP)
	Blocks.box(self, Vector3(SHELF_SIZE.x - 0.12, h - 0.3, 0.02), SHELF + Vector3(0, h / 2.0 + 0.05, SHELF_SIZE.y / 2.0 + 0.01), Color("#BFD8DC"))
	for k in 4:
		Blocks.box(self, Vector3(0.22, 0.3, 0.03), SHELF + Vector3(-0.3 + k * 0.2, 0.4 + (k % 2) * 0.55, SHELF_SIZE.y / 2.0 + 0.03), Color("#EDE6D6"))
	_shelf_loaf = Node3D.new()
	_shelf_loaf.position = SHELF + Vector3(0.1, h + 0.06, 0.05)
	add_child(_shelf_loaf)
	Blocks.box(_shelf_loaf, Vector3(0.3, 0.1, 0.12), Vector3.ZERO, Color("#D9A35A"))
	_shelf_loaf.visible = false
	tu = Nguoi.make("chutu", "viec_rieng")
	tu.position = TU_SEAT
	add_child(tu)
	tu.add_collision(Vector3(0.5, 1.15, 0.65), Vector3(0, 0.58, 0.08))
	_tu_zzz = Blocks.label(self, "z z Z", TU_SEAT + Vector3(0.1, 1.55, 0.1), 36, Color("#DDE6F0"))
	Blocks.label(self, "%d. Chú Tư\nSạp báo · nóc tủ" % (i + 1), SHELF + Vector3(0.6, h + 0.9, 0.2), 40)


## Tiệm xe trưa nghỉ: cửa cuốn kéo xuống kín mặt tiền, Anh Hùng nằm võng trong tiệm, mái tôn trên khe hông.
func _build_shop() -> void:
	var i := _index("shutter")
	var w := 35.0 - 29.5
	Blocks.solid_box(self, Vector3(w, 3.2, 0.1), Vector3(29.5 + w / 2.0, 1.6, SHUTTER_Z), Color("#A9B0B3"))
	for k in 14:
		Blocks.box(self, Vector3(w, 0.03, 0.02), Vector3(29.5 + w / 2.0, 0.2 + k * 0.21, SHUTTER_Z + 0.06), Color("#868D90"))
	Blocks.box(self, Vector3(w + 0.1, 0.25, 0.25), Vector3(29.5 + w / 2.0, 3.15, SHUTTER_Z + 0.08), Color("#6E7477"))
	Blocks.label(self, "Trưa nghỉ · vô cửa sau\n← khe hông", Vector3(31.0, 1.9, SHUTTER_Z + 0.12), 34, GUIDE)
	# Mái tôn trên khe, sau cổng tôn: chỉ lên được bằng đạp tường hoặc từ nóc cổng
	Blocks.solid_box(self, Vector3(TIN_ROOF.size.x, 0.35, TIN_ROOF.size.y), Vector3(TIN_ROOF.get_center().x, TIN_ROOF_Y - 0.175, TIN_ROOF.get_center().y), Color("#B7C2C4"), Blocks.LAYER_PROP)
	Blocks.label(self, "↑ mái tôn: đạp tường", Vector3(28.9, 2.3, 22.6), 28, GUIDE)
	Blocks.label(self, "cửa sau →", Vector3(30.6, 1.6, 15.9), 30, GUIDE)
	# Võng giữa hai cột, Anh Hùng ngồi võng ngủ trưa (dáng nằm võng chờ luồng "Người dân vào game")
	for sx in [-0.85, 0.85]:
		Blocks.solid_box(self, Vector3(0.08, 1.4, 0.08), HAMMOCK + Vector3(sx, 0.7, 0), STEEL, Blocks.LAYER_PROP)
	Blocks.box(self, Vector3(1.5, 0.06, 0.5), HAMMOCK + Vector3(0, 0.42, 0), Color("#4F8F6A"))
	hung = Nguoi.make("hung", "viec_rieng")
	hung.position = HAMMOCK + Vector3(0, 0.14, 0)
	hung.rotation.y = PI / 2.0  # nhìn về phía đông, ra lối đi giữa tiệm
	add_child(hung)
	hung.add_collision(Vector3(0.5, 1.1, 0.6), Vector3(0, 0.55, 0.1))
	Blocks.label(self, "%d. Anh Hùng\nNằm võng trong tiệm" % (i + 1), HAMMOCK + Vector3(0, 2.0, 0), 40)


## Đường tắt mát về lò: thùng gỗ, cục nóng trên giá, rồi lên dãy mái hiên khối 1 (cao 2,9 m) đi về phía tây.
func _build_shade_path() -> void:
	var a: Vector3 = SHADE_STEPS[0]
	Blocks.solid_box(self, Vector3(0.7, a.y, 0.7), Vector3(a.x, a.y / 2.0, a.z), WOOD, Blocks.LAYER_PROP)
	var b: Vector3 = SHADE_STEPS[1]
	Blocks.solid_box(self, Vector3(0.8, 0.5, 0.55), Vector3(b.x, b.y - 0.25, b.z), Color("#E4E7E2"), Blocks.LAYER_PROP)
	Blocks.box(self, Vector3(0.06, b.y - 0.5, 0.06), Vector3(b.x, (b.y - 0.5) / 2.0, b.z), STEEL)
	Blocks.label(self, "đường mát ↑ mái hiên", Vector3(-24.9, 2.4, -5.2), 30, GUIDE)


## Gác lửng quán Mây (khối tạm nhô ra trên mái hiên), lan can, Chị Mây ngồi nghỉ; thùng và cục nóng làm bậc.
func _build_loft() -> void:
	var i := _index("loft")
	var c := LOFT.get_center()
	Blocks.solid_box(self, Vector3(LOFT.size.x, 0.4, LOFT.size.y), Vector3(c.x, LOFT_Y - 0.2, c.y), WOOD, Blocks.LAYER_PROP)
	Blocks.box(self, Vector3(LOFT.size.x, 0.5, 0.03), Vector3(c.x, LOFT_Y + 0.25, LOFT.position.y + 0.02), Color(0.3, 0.2, 0.12, 0.5))
	for k in LOFT_STEPS.size():
		var s: Vector3 = LOFT_STEPS[k]
		var col := WOOD if k < 2 else Color("#E4E7E2")
		var size := Vector3(0.7, s.y, 0.7) if k < 2 else Vector3(0.75, 0.5, 0.5)
		Blocks.solid_box(self, size, Vector3(s.x, s.y - size.y / 2.0, s.z), col, Blocks.LAYER_PROP)
	Blocks.box(self, Vector3(0.06, 1.4, 0.06), Vector3(9.2, 0.7, 5.35), STEEL)
	may = Nguoi.make("may", "viec_rieng")
	may.position = MAY_LOFT
	may.rotation.y = PI  # nhìn ra đường (phía bắc)
	add_child(may)
	may.add_collision(Vector3(0.5, 1.6, 0.35), Vector3(0, 0.8, 0))
	_basket = Node3D.new()
	_basket.position = MAY_LOFT + Vector3(-0.6, 0, -1.0)
	add_child(_basket)
	Blocks.box(_basket, Vector3(0.3, 0.2, 0.25), Vector3.ZERO, Color("#C99A52"))
	Blocks.box(_basket, Vector3(0.015, 1.0, 0.015), Vector3(0, 0.6, 0), Color("#F2E3B8"))
	_basket.visible = false
	Blocks.label(self, "%d. Chị Mây\nGác lửng Cà phê Mây" % (i + 1), MAY_LOFT + Vector3(0, 2.0, -0.3), 40)
	Blocks.label(self, "bậc lên gác →", Vector3(10.3, 1.6, 5.0), 28, GUIDE)


# ---------------------------------------------------------------- vòng đơn

func _on_pick_up(i: int, order: Dictionary) -> void:
	_carrying = i
	_kicked = false
	dap_ok = false
	called_may = false
	_basket_t = -1.0
	ice_left = 1.0
	_ice_half_told = false
	match order.get("delivery", ""):
		"shelf":
			tu_woke = false
			deliveries.side_ok[i] = true
			_toast("Chú Tư đang ngủ gật. Rón rén (Alt) lại tủ báo, nhảy rồi bám mép để đặt bánh lên nóc tủ.", 3.5, 2.4)
		"shutter":
			_toast("Trưa tiệm xe kéo cửa cuốn. Vô khe hông bên trái, ra hẻm sau rồi vào cửa sau nha!", 3.5, 2.4)
		"loft":
			_toast("Chị Mây nghỉ trên gác lửng. Leo thùng → cục nóng → bám mép gác" + (", hoặc đứng trước quầy bấm Q gọi chị." if DoKho.v("loft_call_basket", false) else "."), 3.5, 2.4)
		"scene":
			_toast("Chạy tới cổng LÔ B chung cư rồi leo lên tầng 5 cho Bé Na!", 3.0, 2.4)
	if order.get("errand_item", "") == "da":
		deliveries.side_ok[i] = true
		_show_ice(true)
		_toast("Đá tan dần đó! Về lò lẹ, đi dưới bóng mát hoặc lên mái hiên cho đỡ nắng.", 3.0, 2.4)


## Gọi mỗi nhịp khi đang mang bánh đơn i có cách giao của Thứ Năm. Trả true khi khách đã nhận.
func step(i: int, in_zone: bool, delta: float) -> bool:
	var kind: String = orders[i].get("delivery", "")
	var pressed := Input.is_action_just_pressed("deliver")
	var p := player.global_position
	var ready := false
	var hint := ""
	match kind:
		"shelf":
			var h: float = DoKho.v("shelf_height", 1.9)
			var on_top := player.is_on_floor() and p.y > h - 0.25 and _flat(p, SHELF) < 0.7
			ready = on_top
			hint = "[E] Đặt bánh lên nóc tủ"
			if not on_top and _flat(p, SHELF) < 1.6 and p.y < 0.5:
				_tell("tu_bam", "Nhảy về phía tủ báo, giữ W để bám mép rồi Space leo lên.", 3.0)
			if ready and (pressed or autotest):
				player.play_deliver("hand")
				_shelf_loaf.visible = true
				deliveries.side_ok[i] = not tu_woke
				if not tu_woke:
					_toast("Đặt êm ru, Chú Tư vẫn ngáy khò khò!", 2.0, 1.4)
				return _done()
		"shutter":
			var inside := SHOP.has_point(Vector2(p.x, p.z)) and p.y < 1.0
			ready = inside and p.distance_to(hung.global_position + Vector3(0.3, 0, 0)) < HUNG_REACH
			hint = "[E] Đưa bánh cho Anh Hùng"
			if not inside and p.x > 29.5 and p.x < 35.0 and p.z > SHUTTER_Z and p.z < SHUTTER_Z + 1.8:
				_tell("cua_cuon", "Cửa cuốn đóng rồi! Vô khe hông bên trái tiệm, đạp tường hoặc leo thùng qua cổng tôn.", 3.0)
			if ready and (pressed or autotest):
				player.play_deliver("hand")
				hung.play_once("nhan_banh", "vui", 2.5)
				deliveries.side_ok[i] = dap_ok
				return _done()
		"loft":
			var on_loft := player.is_on_floor() and p.y > LOFT_Y - 0.25 and LOFT.grow(0.2).has_point(Vector2(p.x, p.z))
			ready = on_loft and p.distance_to(may.global_position) < 1.8
			hint = "[E] Đưa bánh cho Chị Mây"
			var at_counter := p.y < 0.6 and _flat(p, COUNTER_CALL) < 1.8
			if at_counter and _basket_t < 0.0:
				ready = true
				hint = "[Q] Kêu meo gọi Chị Mây" if DoKho.v("loft_call_basket", false) else "Chị Mây ở trên gác, leo lên thôi!"
			if _basket_t >= 0.0:
				_basket_t += delta
				var k := clampf(_basket_t / BASKET_TIME, 0.0, 1.0)
				_basket.position.y = lerpf(LOFT_Y + 0.1, 0.2, k)
				if k >= 1.0:
					player.play_deliver("hand")
					deliveries.side_ok[i] = false
					_toast("Chị Mây kéo giỏ lên: \"Cảm ơn Bơ nha!\"", 2.0)
					return _done()
			elif at_counter and Input.is_action_just_pressed("goi"):
				if DoKho.v("loft_call_basket", false):
					if player.has_method("sit_call"):
						player.sit_call()
					called_may = true
					_basket_t = 0.0
					_basket.visible = true
					_basket.position = Vector3(COUNTER_CALL.x + 0.6, LOFT_Y + 0.1, COUNTER_CALL.z + 0.3)
					_toast("Chị Mây thả giỏ xuống. Lần sau leo lên gác thử nha!", 2.0)
				else:
					_toast("Chị Mây đang nghỉ trên gác, không nghe. Leo thùng → cục nóng → bám mép gác!", 2.5)
			elif ready and on_loft and (pressed or autotest):
				player.play_deliver("hand")
				may.play_once("nhan_banh", "vui", 2.5)
				deliveries.side_ok[i] = true
				_toast("Giao tận gác, Chị Mây mừng rỡ!", 2.0, 1.4)
				return _done()
		"scene":
			if in_zone and not _switching:
				_go_scene(i)
	_prompt.visible = ready and hint != ""
	if _prompt.visible:
		_prompt.text = hint
		_prompt.global_position = p + Vector3(0, 0.9, 0)
	return false


func _done() -> bool:
	_prompt.visible = false
	return true


## Chỗ Bơ cần đứng để giao (autotest dịch chuyển tới).
func stand_point(i: int) -> Vector3:
	match orders[i].get("delivery", ""):
		"shelf":
			return SHELF + Vector3(0, float(DoKho.v("shelf_height", 1.9)) + 0.05, 0)
		"shutter":
			return hung.global_position + Vector3(1.1, -0.1, 0)
		"loft":
			return MAY_LOFT + Vector3(0, 0.05, -0.8)
	return orders[i].pos


## Tới cổng chung cư: cất tiến độ ngày rồi sang cảnh leo chung cư.
func _go_scene(i: int) -> void:
	_switching = true
	_scene_order = i
	_scene_late = main.late
	_result = {}
	_stash = {"order_index": i, "results": main.results.duplicate(), "result_notes": main.result_notes.duplicate(),
		"score_rows": main.score_rows.duplicate(), "side_ok": deliveries.side_ok.duplicate()}
	main._leaving = true
	player.can_move = false
	_prompt.visible = false
	hud.show_toast("Tới chung cư rồi! Lên căn 5B-1 tầng 5 cho Bé Na.", 1.5)
	get_tree().create_timer(0.3 if autotest else 1.0).timeout.connect(func():
		get_tree().change_scene_to_file(PlayMode.CHUNG_CU_SCENE))


func _physics_process(delta: float) -> void:
	if player == null or hud == null:
		return
	_update_heat(delta)
	if _carrying < 0:
		return
	var p := player.global_position
	var on_floor := player.is_on_floor()
	# Mái tôn khe hông: đạp tường lên mà chưa chạm đất
	if on_floor and p.y < 0.3:
		_kicked = false
	if on_floor and _kicked and p.y > TIN_ROOF_Y - 0.2 and TIN_ROOF.grow(0.1).has_point(Vector2(p.x, p.z)) and not dap_ok:
		dap_ok = true
		_toast("Đạp tường lên mái tôn một mạch, giỏi quá!", 2.0)
	if orders[_carrying].get("errand_item", "") == "da":
		ice_left = maxf(ice_left - delta / float(DoKho.v("ice_melt_time", 45.0)), 0.0)
		deliveries.side_ok[_carrying] = ice_left > 0.5
		if _ice_bag:
			_ice_bag.scale = Vector3.ONE * lerpf(0.45, 1.0, ice_left)
		if ice_left <= 0.5 and not _ice_half_told:
			_ice_half_told = true
			_toast("Bịch đá tan còn nửa rồi!", 2.0)


## Bịch đá trong miệng Bơ (khối tạm, chờ model trang G1 bản 2), thay cho ổ bánh.
func _show_ice(on: bool) -> void:
	if on and _ice_bag == null:
		var mouth: Node3D = deliveries.get("_mouth") if deliveries.get("_mouth") else player
		_ice_bag = Blocks.box(mouth, Vector3(0.16, 0.14, 0.12), Vector3(0, -0.05, 0.05), Color(0.85, 0.95, 1.0, 0.75))
	if _ice_bag:
		_ice_bag.visible = on
	if on and "bread" in player and player.bread:
		player.bread.visible = false


## Chú Tư nghe tiếng Bơ: Thong thả chỉ tiếng to (chạy nhanh, đáp mạnh), Thử thách cả tiếng đi thường.
func _on_noise(pos: Vector3, radius: float) -> void:
	if tu == null or tu_woke or _carrying < 0 or orders[_carrying].get("delivery", "") != "shelf":
		return
	if radius < float(DoKho.v("tu_wake_noise", TU_WAKE_NOISE)) or pos.distance_to(TU_SEAT) > radius:
		return
	tu_woke = true
	deliveries.side_ok[_carrying] = false
	_tu_zzz.text = "!"
	tu.play_once("sot_ruot", "viec_rieng", 1.5)
	_toast("Chú Tư giật mình thức giấc. Lần sau rón rén (Alt) nha!", 2.0)


## Trưa oi (chỉ Thử thách, heat_slow < 1): đứng trên mặt đường ngoài nắng quá 3 s thì đi chậm lại.
func _update_heat(delta: float) -> void:
	var slow: float = DoKho.v("heat_slow", 0.85)
	if slow >= 1.0:
		return
	var sunny := player.is_on_floor() and player.global_position.y < 0.3 and not _in_shade()
	_sun_t = clampf(_sun_t + (delta if sunny else -2.0 * delta), 0.0, 4.0)
	var hot := _sun_t > 3.0
	if hot != _heat_on:
		_heat_on = hot
		player.speed_scale = slow if hot else 1.0
		if hot:
			_tell("nang", "Mặt đường nóng quá, Bơ đi chậm lại! Tìm bóng râm hoặc leo lên cao.", 2.5)


func _in_shade() -> bool:
	var from := player.global_position + Vector3.UP * 0.6
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.35, 8.0, 0.2), player.collision_mask, [player.get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _tell(id: String, text: String, secs := 2.5) -> void:
	if _told.has(id):
		return
	_told[id] = true
	_toast(text, secs)


func _toast(text: String, secs := 2.0, delay := 0.0) -> void:
	if hud == null or autotest:
		if autotest:
			print("[thu nam] ", text)
		return
	if delay <= 0.0:
		hud.show_toast(text, secs)
	else:
		get_tree().create_timer(delay).timeout.connect(func(): hud.show_toast(text, secs))
