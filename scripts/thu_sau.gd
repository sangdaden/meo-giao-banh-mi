class_name ThuSau
extends Node3D
## Thứ Sáu chiều tà, đám giỗ Bà Sáu (gói việc thiet-ke-man/goi-viec-thu-sau.md, trang thiết kế màn mục 06–07).
## Bản khối tạm: model thật tới sau từ "Phác thảo tiệm xe chiều tà" (G6) và "Phác thảo đám giỗ" (G7).
## main.gd thêm node này mọi ngày, ngày khác tự gỡ. Phần giao của ba cách giao mới ở đây,
## deliveries.gd chỉ chuyển qua (deliveries.thu_sau.step):
## - call: tới gần khách, bấm Q ngồi kêu "meo" (clip ngoi_goi), khách nghe (trong call_radius, không bị tường che)
##   thì nhận bánh. Chị Mây ở quầy kín khách, Bà Sáu ở cổng sân giỗ. Lại sát khách bấm E cũng được.
## - lift: Anh Hùng ngồi trên giàn sửa xe cao 1,5 m. Cầu nâng lên xuống theo nhịp lift_period:
##   đứng lên cầu cho nó đưa lên, tới tay anh thì bấm E. Vòi hơi thổi ngang lối vào, lốp lăn ra đường.
## - gio_table: chuyến giỗ cuối: đặt túi 3 ổ lên bàn dài trong sân. Leo giàn bông giấy (gai làm chậm)
##   vào sân từ trên cao thì khỏi qua con nít chạy theo và bình tưới của Bà Sáu.
## Đơn giỗ (khóa "gio": true) ngậm túi 3 ổ (player.carry_tui3). Thử thách: các đơn "gio_group" dùng
## chung một đồng hồ gio_shared_time giây (chạy cả lúc về lò lấy chuyến sau). Thong thả: mỗi chuyến giờ riêng.
## Ngồi gọi Q: player.sit_call() (phát player.called). Số dễ/khó: DoKho.EASY, khóa ghi ở bảng gói việc.

const DAY_ID := "thu_sau"
const KINDS := ["call", "lift", "gio_table"]

## Tiệm xe Anh Hùng (CityProps._tiem_xe: x 29,5..35, mặt tiền z ≈ 25,1, lối đi giữa x 31,4..33,2)
const LIFT_SPOT := Vector3(32.3, 0, 24.4)       ## chỗ đứng trước cầu nâng (mũi tên chỉ tới đây)
const LIFT_POS := Vector3(32.3, 0, 23.3)        ## tâm cầu nâng
const LIFT_SIZE := Vector3(0.8, 1.6, 1.0)       ## trụ cầu nâng (mặt cầu là mặt trên, phía dưới đặc nên không chui được)
const LIFT_LOW := 0.12
const LIFT_HIGH := 1.45
const HUNG_DECK := Vector3(34.2, 1.5, 24.0)     ## mặt giàn sửa xe Anh Hùng ngồi
const HUNG_DECK_SIZE := Vector3(1.0, 1.5, 0.9)
const HUNG_REACH := 2.0                         ## đứng cao từ 1,1 m, cách Anh Hùng dưới mức này thì đưa được
const HOSE_ZONE := Rect2(30.0, 24.3, 5.0, 0.8)  ## luồng hơi thổi ngang lối vào (x, z), cao tới 1,2 m
const HOSE_PERIOD := 3.5
const HOSE_ON := 1.0
const TYRE_LANE_X := 33.15
const TYRE_FROM_Z := 19.6
const TYRE_TO_Z := 29.0
const TYRE_EVERY := 4.5
const TYRE_SPEED := 2.4
const TYRE_R := 0.28

## Sân giỗ cuối hẻm 42 (x -20..-17): cổng sân z 18,8, cổng nhà Bà Sáu z 24,4
const GIO_GATE := Vector3(-18.5, 0, 18.3)       ## đứng đây ngồi gọi Bà Sáu
const GIO_TABLE := Vector3(-18.75, 0, 20.55)    ## đứng cạnh bàn dài đặt túi
const YARD := Rect2(-20.0, 18.8, 3.0, 5.6)
const TABLE_POS := Vector3(-19.45, 0, 20.55)
const TABLE_SIZE := Vector3(0.7, 0.72, 2.4)
const ALTAR_POS := Vector3(-18.5, 0, 24.15)
const BA_SAU_SEAT := Vector3(-19.5, 0.08, 22.7) ## ghế mây CityProps
const POTS := [Vector3(-17.35, 0, 20.5), Vector3(-17.35, 0, 21.3)]
## Giàn bông giấy leo được: hai bậc thùng gỗ cạnh tường đông rồi lên mái giàn cao 2,4 m chạy vào sân
const TRELLIS := Rect2(-17.75, 17.6, 0.7, 5.0)
const TRELLIS_TOP := 2.4
const STEPS := [{"pos": Vector3(-17.4, 0.4, 16.85), "size": Vector3(0.6, 0.8, 0.5)},
	{"pos": Vector3(-17.4, 0.8, 17.35), "size": Vector3(0.6, 1.6, 0.5)}]
const KID_SPEED := 1.8
const KID_TRIP_CD := 2.5
const SPRAY_EVERY := 4.0
const SPRAY_ON := 1.6

## Người tan tầm trên vỉa hè đường lớn: [z, x từ, x tới]
const WALK_LANES := [[-6.4, -12.0, 11.0], [-6.4, -12.0, 11.0], [5.7, -12.0, 3.6], [5.7, -12.0, 3.6], [5.7, 7.2, 11.5]]
const WALKER_IDS := ["dicho1", "dicho2", "dicho3", "cho6", "xemco"]
const WALK_SPEED := 1.2

const RED := Color("#C8412F")
const WOOD := Color("#9B6A3A")
const BAMBOO := Color("#B9A05A")
const STEEL := Color("#7C8584")
const YELLOW := Color("#E3B23C")
const WATER := Color(0.62, 0.8, 0.95, 0.55)
const AIR := Color(1, 1, 1, 0.35)

var _main: Node
var player: CharacterBody3D
var deliveries: Node
var hud: CanvasLayer
var dog: Node
var orders: Array = []
var autotest := false

var _base_walk := 5.0
var _base_sprint := 8.0
var _prompt: Label3D
var _speech: Label3D
var _speech_until := 0.0

# Cầu nâng, vòi hơi, lốp
var _lift: AnimatableBody3D
var _lift_t := 0.0
var _lift_period := 3.5
var _hose_t := 0.0
var _jets: Array[MeshInstance3D] = []
var _gust_done := false
var _push_left := 0.0
var _tyres: Array = []             # {"node", "spin", "z"}
var _tyre_t := 0.0
var _tyre_cd := 0.0
var _hose_hint := false
var _tyre_hint := false

# Người
var _may: Nguoi
var _hung: Nguoi
var _sau: Nguoi
var _helper: Nguoi                 # khách giỗ ra cổng nhận túi thay Bà Sáu (Bà Sáu chưa có dáng đứng, chờ G7)
var _helper_home := Vector3.ZERO
var _kids: Array = []              # {"node", "home", "cd"}
var _walkers: Array = []           # {"node", "lane", "dir", "cd"}

# Bình tưới của Bà Sáu
var _spray_t := 0.0
var _spray_target := 0
var _spray: MeshInstance3D
var _wet_cd := 0.0

# Đơn đang làm
var _current := -1
var _calls := 0
var _bumps := 0
var _hung_calls := 0
var _via_trellis := false
var _ground_entry := false
var _altar_hint := false
var _thorn_hint := false
var _nhang: Node3D
var _bags_on_table := 0
var _shared_left := 0.0
var _shared_on := false
var _pending := false              # đã giao, đang diễn cảnh nhận bánh


func _ready() -> void:
	_main = get_parent()
	if _main == null or not "day" in _main or _main.day.get("id", "") != DAY_ID:
		queue_free()
		return
	name = "ThuSau"
	add_to_group("thu_sau")
	orders = _main.orders
	player = _main.player
	deliveries = _main.deliveries
	dog = _main.dog
	autotest = "--autotest" in OS.get_cmdline_user_args()
	if not InputMap.has_action("goi"):
		InputMap.add_action("goi", 0.2)
		var k := InputEventKey.new()
		k.physical_keycode = KEY_Q
		InputMap.action_add_event("goi", k)
		var b := InputEventJoypadButton.new()
		b.button_index = JOY_BUTTON_LEFT_SHOULDER
		InputMap.action_add_event("goi", b)
	_build_shop()
	_build_cafe()
	_build_yard()
	_build_walkers()
	_prompt = Blocks.label(self, "", Vector3.ZERO, 28, Color("#F2C14E"))
	_prompt.no_depth_test = true
	_prompt.visible = false
	_speech = Blocks.label(self, "", Vector3.ZERO, 40, Color("#FFF8EA"))
	_speech.visible = false
	_setup.call_deferred()


## Sau khi main dựng xong HUD và deliveries.setup.
func _setup() -> void:
	hud = _main.hud
	deliveries.thu_sau = self
	while deliveries.side_ok.size() < orders.size():
		deliveries.side_ok.append(false)
	_more_dots()
	_base_walk = player.walk_speed
	_base_sprint = player.sprint_speed
	if _main.day.extras.get("dog_alert", false) and dog:
		# Mực bữa nay ngủ chập chờn: ngủ ngắn hơn, hé mắt lâu hơn
		dog.sleep_time = float(DoKho.v("dog_sleep_t6", 4.0))
		dog.peek_time = float(DoKho.v("dog_peek_t6", 3.0))
	var trips := _gio_orders().size()
	if trips != int(DoKho.v("gio_trips", 4)):
		push_warning("Thứ Sáu: số chuyến giỗ trong days.gd (%d) khác DoKho gio_trips" % trips)
	_main.order_picked_up.connect(_on_pick_up)
	_main.order_delivered.connect(_on_delivered)
	if player.has_signal("called"):
		player.called.connect(_on_called)
	player.bumped.connect(on_bump)


## HUD có 5 ổ bánh; Thử thách 7 đơn thì thêm ổ cho đủ.
func _more_dots() -> void:
	if not "dots" in hud or hud.dots.is_empty():
		return
	var first: Control = hud.dots[0]
	while hud.dots.size() < orders.size():
		var d: Control = first.get_script().new()
		d.custom_minimum_size = first.custom_minimum_size
		first.get_parent().add_child(d)
		first.get_parent().move_child(d, hud.dots[-1].get_index() + 1)
		hud.dots.append(d)
	hud.set_progress(_main.results)


func _gio_orders() -> Array:
	var out := []
	for i in orders.size():
		if orders[i].get("gio", false):
			out.append(i)
	return out


# ---------------------------------------------------------------- dựng cảnh

## Tiệm xe chiều tà: cầu nâng chạy nhịp, giàn Anh Hùng ngồi sửa xe, vòi hơi, lốp lăn.
func _build_shop() -> void:
	_lift_period = float(DoKho.v("lift_period", 2.5))
	_lift = AnimatableBody3D.new()
	_lift.name = "CauNang"
	_lift.collision_layer = Blocks.LAYER_PROP
	_lift.sync_to_physics = true
	add_child(_lift)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = LIFT_SIZE
	shape.shape = bs
	_lift.add_child(shape)
	Blocks.box(_lift, Vector3(LIFT_SIZE.x + 0.1, 0.08, LIFT_SIZE.z + 0.1), Vector3(0, LIFT_SIZE.y / 2.0 - 0.04, 0), YELLOW)
	Blocks.box(_lift, Vector3(0.3, LIFT_SIZE.y, 0.3), Vector3.ZERO, STEEL)
	_lift.position = LIFT_POS + Vector3(0, LIFT_LOW - LIFT_SIZE.y / 2.0, 0)
	# Giàn sửa xe, ghế đẩu và Anh Hùng ngồi trên đó, quay về phía cầu nâng
	Blocks.solid_box(self, HUNG_DECK_SIZE, HUNG_DECK - Vector3(0, HUNG_DECK_SIZE.y / 2.0, 0), WOOD, Blocks.LAYER_PROP)
	Blocks.solid_box(self, Vector3(0.32, 0.28, 0.32), HUNG_DECK + Vector3(0.18, 0.14, 0), Color("#D94F3D"), Blocks.LAYER_PROP)
	if _has_order("lift"):
		_hung = _person("hung", HUNG_DECK + Vector3(0.1, 0, 0), -PI / 2.0, "viec_rieng")
		_hung.add_collision(Vector3(0.5, 1.1, 0.6), Vector3(0, 0.55, 0.1))
		Blocks.label(self, _title("lift"), HUNG_DECK + Vector3(0, 1.9, 0), 40)
	# Vòi hơi: máy nén có sẵn trong tiệm, ống dây dọc vách tây, đầu vòi thổi ngang lối vào
	Blocks.box(self, Vector3(0.06, 0.06, 5.6), Vector3(29.75, 0.05, 21.9), Color("#2B2622"))
	Blocks.solid_box(self, Vector3(0.25, 0.5, 0.25), Vector3(29.8, 0.25, HOSE_ZONE.position.y + HOSE_ZONE.size.y / 2.0), Color("#C8412F"), Blocks.LAYER_PROP)
	for k in 5:
		var jet := Blocks.box(self, Vector3(0.9, 0.04, 0.04), Vector3.ZERO, AIR)
		jet.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		jet.visible = false
		_jets.append(jet)


## Cà phê Mây giờ tan tầm: bốn khách đứng kín quầy, Chị Mây sau quầy.
func _build_cafe() -> void:
	if not _has_order("call"):
		return
	var i := _first_index("call")
	if orders[i].who != "Chị Mây":
		return
	var c := CityProps.CAFE_COUNTER
	_may = _person("may", Vector3(c.x - 0.2, 0, c.z + 0.5), PI, "viec_rieng")
	_may.add_collision(Vector3(0.5, 1.6, 0.35), Vector3(0, 0.8, 0))
	var crowd := ["cho4", "cho7", "dicho3", "dicho2"]
	for k in crowd.size():
		var n := _person(crowd[k], Vector3(c.x - 0.85 + k * 0.55, 0, c.z - 0.7), 0.0, ["xem", "noi", "dung_chon", "xem"][k], "dong")
		n.add_collision(Vector3(0.45, 1.6, 0.3), Vector3(0, 0.8, 0))
	Blocks.label(self, _title("call", "Chị Mây"), c + Vector3(0, 1.4, 0.3), 40)


## Sân giỗ cuối hẻm 42: bàn dài dọn cỗ, bàn thờ (không leo được), giàn bông giấy leo được,
## Bà Sáu ngồi ghế mây cầm bình tưới, hai đứa nhỏ chạy theo Bơ, khách giỗ đứng nói chuyện.
func _build_yard() -> void:
	# Cổng sân: hai cột tre, băng vải đỏ
	for x in [YARD.position.x + 0.15, YARD.end.x - 0.15]:
		Blocks.solid_box(self, Vector3(0.08, 2.2, 0.08), Vector3(x, 1.1, YARD.position.y - 0.05), BAMBOO, Blocks.LAYER_PROP)
	Blocks.box(self, Vector3(YARD.size.x - 0.3, 0.32, 0.03), Vector3(YARD.get_center().x, 2.05, YARD.position.y - 0.05), RED)
	Blocks.label(self, "ĐÁM GIỖ", Vector3(YARD.get_center().x, 2.05, YARD.position.y - 0.08), 28, Color("#FFE7A8"))
	# Bàn dài phủ khăn, mâm cỗ
	Blocks.solid_box(self, TABLE_SIZE, TABLE_POS + Vector3(0, TABLE_SIZE.y / 2.0, 0), WOOD, Blocks.LAYER_PROP)
	Blocks.box(self, Vector3(TABLE_SIZE.x + 0.06, 0.02, TABLE_SIZE.z + 0.06), TABLE_POS + Vector3(0, TABLE_SIZE.y + 0.01, 0), RED.lightened(0.15))
	var dishes := [Color("#F2E3B8"), Color("#7FB069"), Color("#E39C7A"), Color("#D7A9C4"), Color("#F2C14E"), Color("#A9C7E8")]
	for k in dishes.size():
		var plate := CylinderMesh.new()
		plate.top_radius = 0.13
		plate.bottom_radius = 0.1
		plate.height = 0.05
		plate.radial_segments = 10
		plate.rings = 1
		Blocks.mesh(self, plate, TABLE_POS + Vector3(0.12 * (1 if k % 2 else -1), TABLE_SIZE.y + 0.045, -0.95 + k * 0.38), dishes[k])
	# Bàn thờ sát cổng nhà: lư hương, chân nến, mâm trái cây. Hộp chặn vô hình cao 2,3 m nên Bơ không nhảy lên được.
	Blocks.solid_box(self, Vector3(1.2, 1.0, 0.4), ALTAR_POS + Vector3(0, 0.5, 0), Color("#6B2A1E"), Blocks.LAYER_PROP)
	Blocks.collider(self, Vector3(1.3, 1.3, 0.5), ALTAR_POS + Vector3(0, 1.65, 0), Blocks.LAYER_PROP)
	Blocks.box(self, Vector3(0.14, 0.1, 0.14), ALTAR_POS + Vector3(0, 1.05, 0), YELLOW)
	for sx in [-0.4, 0.4]:
		Blocks.box(self, Vector3(0.04, 0.22, 0.04), ALTAR_POS + Vector3(sx, 1.11, 0), Color("#FFF8EA"))
	Blocks.box(self, Vector3(0.3, 0.12, 0.2), ALTAR_POS + Vector3(-0.2, 1.06, 0.05), Color("#E39C7A"))
	var smoke := Blocks.box(self, Vector3(0.02, 0.45, 0.02), ALTAR_POS + Vector3(0, 1.32, 0), Color(0.9, 0.9, 0.9, 0.5))
	smoke.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Giàn bông giấy: bậc thùng gỗ, cột tre, mái giàn đứng được, chùm bông phủ hai mép
	for s in STEPS:
		Blocks.solid_box(self, s.size, s.pos, Color("#A8774A"), Blocks.LAYER_PROP)
	var tc := TRELLIS.get_center()
	for z in [TRELLIS.position.y + 0.1, TRELLIS.end.y - 0.1]:
		for x in [TRELLIS.position.x + 0.05, TRELLIS.end.x - 0.05]:
			Blocks.box(self, Vector3(0.06, TRELLIS_TOP, 0.06), Vector3(x, TRELLIS_TOP / 2.0, z), BAMBOO)
	Blocks.solid_box(self, Vector3(TRELLIS.size.x, 0.1, TRELLIS.size.y), Vector3(tc.x, TRELLIS_TOP - 0.05, tc.y), BAMBOO, Blocks.LAYER_PROP)
	for k in 8:
		var s := SphereMesh.new()
		s.radius = 0.2
		s.height = 0.26
		s.radial_segments = 8
		s.rings = 4
		var side := TRELLIS.position.x if k % 2 == 0 else TRELLIS.end.x
		Blocks.mesh(self, s, Vector3(side, TRELLIS_TOP + 0.05, TRELLIS.position.y + 0.3 + k * 0.6), CityProps.BOUGAIN)
	# Chậu hoa phía tây cho Bà Sáu tưới
	PhoModels.put(self, "chau_boug", Vector3(-19.75, 0, 21.95))
	if _gio_orders().is_empty():
		return
	_sau = _person("basau", BA_SAU_SEAT, PI, "viec_rieng")
	_sau.add_collision(Vector3(0.5, 1.15, 0.65), Vector3(0, 0.58, 0.08))
	Blocks.label(self, _title("gio_table", "Bà Sáu"), BA_SAU_SEAT + Vector3(0, 2.2, 0), 40)
	_spray = Blocks.box(self, Vector3(0.05, 0.05, 1.0), Vector3.ZERO, WATER)
	_spray.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spray.visible = false
	# Khách giỗ: một người ra cổng nhận túi thay Bà Sáu, hai người đứng nói chuyện
	_helper_home = Vector3(-18.9, 0, 22.0)
	_helper = _person("cho4", _helper_home, PI, "noi", "dong")
	_person("cho6", Vector3(-19.45, 0, 19.0), 0.0, "noi", "dong")
	_person("dicho1", Vector3(-17.6, 0, 22.4), PI / 2.0, "xem", "dong")
	# Hai đứa nhỏ
	for k in 2:
		var home := Vector3(-18.6 + k * 0.6, 0, 19.6 + k * 2.6)
		var kid := _person(["cho5", "bena"][k], home, PI, "vui")
		_kids.append({"node": kid, "home": home, "cd": 0.0})


## Người tan tầm đi qua lại trên vỉa hè đường lớn (va vào thì khựng nhẹ).
func _build_walkers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	for k in WALK_LANES.size():
		var lane: Array = WALK_LANES[k]
		var n := _person(WALKER_IDS[k], Vector3(rng.randf_range(lane[1], lane[2]), 0.04, lane[0]), 0.0, "di_bo", "dong")
		_walkers.append({"node": n, "lane": lane, "dir": 1.0 if k % 2 == 0 else -1.0, "cd": 0.0})


func _person(id: String, pos: Vector3, yaw: float, idle: String, ban := "") -> Nguoi:
	var n := Nguoi.make(id, idle)
	n.ban = ban
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	return n


func _has_order(kind: String) -> bool:
	return _first_index(kind) >= 0


func _first_index(kind: String) -> int:
	for i in orders.size():
		if orders[i].get("delivery", "") == kind:
			return i
	return -1


func _title(kind: String, who := "") -> String:
	for i in orders.size():
		if orders[i].get("delivery", "") == kind and (who == "" or orders[i].who == who):
			return "%d. %s\n%s" % [i + 1, orders[i].who, orders[i].place]
	return ""


# ---------------------------------------------------------------- vòng đơn

func _on_pick_up(i: int, order: Dictionary) -> void:
	_current = i
	_calls = 0
	_bumps = 0
	_hung_calls = 0
	_via_trellis = false
	_ground_entry = false
	_pending = false
	if order.get("gio", false):
		player.carry_tui3(true)
		var trips := _gio_orders()
		_toast("Chuyến giỗ %d/%d: ngậm túi 3 ổ tới nhà Bà Sáu!" % [trips.find(i) + 1, trips.size()], 2.5, 1.0)
		if order.get("gio_group", false) and float(DoKho.v("gio_shared_time", 120.0)) > 0.0:
			if not _shared_on:
				_shared_on = true
				_shared_left = float(DoKho.v("gio_shared_time", 120.0)) + Scoring.bonus_seconds(i)
			_main.time_left = _shared_left
	if order.get("dog_start", "") == "peek" and dog and dog.state == dog.State.SLEEP:
		dog._set_state(dog.State.PEEK)  # chuyến hai: Mực đã dè chừng, nằm hé mắt sẵn
	if order.get("errand_item", "") == "nhang":
		_nhang = Node3D.new()
		deliveries._mouth.add_child(_nhang)
		Blocks.box(_nhang, Vector3(0.2, 0.025, 0.025), Vector3(0, -0.02, 0.02), Color("#C8412F"))
		Blocks.box(_nhang, Vector3(0.07, 0.05, 0.04), Vector3(0.05, -0.05, 0.03), Color("#F2E3B8"))
		deliveries._body_layer(_nhang)
	if order.get("delivery", "") == "lift":
		_toast("Anh Hùng ngồi trên giàn cao. Đứng lên cầu nâng cho nó đưa lên!", 3.0, 2.6)
	elif order.get("delivery", "") == "call":
		_toast("Tới gần rồi bấm Q ngồi kêu meo, %s sẽ nghe thấy." % order.who, 3.0, 2.6)


func _on_delivered(i: int, order: Dictionary) -> void:
	if is_instance_valid(_nhang):
		_nhang.queue_free()
		_toast("Cô Ba gói nhang, đèn cầy vô mâm cỗ cho Bà Sáu.", 2.5, 2.2)
	if order.get("gio_group", false):
		_shared_left = _main.time_left
		var group := _gio_orders().filter(func(k): return orders[k].get("gio_group", false))
		if not group.is_empty() and i == group[-1]:
			_shared_on = false
	if order.get("gio", false) and i == _gio_orders()[-1]:
		# Chuyến chót: Bà Sáu cảm ơn, Mực nằm xuống nhìn theo Bơ (gieo chương Thứ Bảy)
		_say(_sau, "\"Đủ cỗ rồi! Cảm ơn Bơ nha. Mực, nằm yên đó!\"", 4.0, 2.0)
		if dog and dog.has_method("play_clip"):
			get_tree().create_timer(2.5).timeout.connect(func(): dog.play_clip("nam_buon"))
	_current = -1


## deliveries.step chuyển qua đây cho ba cách giao của Thứ Sáu. Trả true khi khách đã nhận.
func step(i: int, in_zone: bool, _delta: float) -> bool:
	var kind: String = orders[i].get("delivery", "")
	var pressed := Input.is_action_just_pressed("deliver")
	var ready := false
	var hint := ""
	match kind:
		"call":
			var who := _call_target(i)
			var near := who != null and _flat(player.global_position, who.global_position) < 1.6
			ready = in_zone or near
			hint = "[E] Đưa bánh" if near else "[Q] Ngồi kêu meo"
			if autotest and in_zone:
				_calls = 1
				return _deliver_call(i)
			if pressed and near:
				return _deliver_call(i)
			if _pending:
				_pending = false
				return _deliver_call(i)
		"lift":
			var up := _hung and player.global_position.y > 1.1 and _flat(player.global_position, _hung.global_position) < HUNG_REACH
			ready = in_zone or up
			hint = "[E] Đưa bánh cho Anh Hùng" if up else "Nhảy lên cầu nâng, đợi nó đưa lên"
			if (pressed and up) or (autotest and in_zone):
				return _deliver_lift(i)
		"gio_table":
			var near_table := _flat(player.global_position, TABLE_POS) < 1.0 and player.global_position.y < 1.6
			ready = in_zone or near_table
			hint = "[E] Đặt túi lên bàn cỗ" if near_table else "Mang túi tới bàn cỗ"
			if (pressed and near_table) or (autotest and in_zone):
				return _deliver_table(i)
	_prompt.visible = ready and hint != ""
	if _prompt.visible:
		_prompt.text = hint
		_prompt.global_position = player.global_position + Vector3(0, 0.9, 0)
	return false


## Ai nghe tiếng gọi của đơn i: Chị Mây, hoặc Bà Sáu (người khác ra cổng nhận giùm).
func _call_target(i: int) -> Node3D:
	return _may if orders[i].who == "Chị Mây" else _sau


## Bơ vừa ngồi kêu meo (player.called). Đơn "call" đang mang mà khách nghe được thì giao.
func _on_called(pos: Vector3) -> void:
	if _current < 0 or not player.carrying or orders[_current].get("delivery", "") != "call":
		return
	var who := _call_target(_current)
	if who == null:
		return
	var d := _flat(pos, who.global_position)
	if d > float(DoKho.v("call_radius", 5.0)) * 1.8:
		return  # gọi ở xa quá, không tính là gọi khách này
	_calls += 1
	if d <= float(DoKho.v("call_radius", 5.0)) and _can_see(pos, who.global_position):
		_pending = true  # step() giao ở nhịp kế
	else:
		_toast("Chưa ai nghe thấy. Lại gần hơn chút rồi gọi lại!", 2.0)


func _can_see(from: Vector3, to: Vector3) -> bool:
	if _flat(from, to) < 3.0:
		return true
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.4, 0), to + Vector3(0, 1.2, 0), Blocks.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _deliver_call(i: int) -> bool:
	_prompt.visible = false
	var order: Dictionary = orders[i]
	match order.get("side_quest", ""):
		"goi_mot_tieng":
			deliveries.side_ok[i] = _calls == 1
		"muc_ngu_yen":
			deliveries.side_ok[i] = not _dog_woke()
	if order.get("gio", false):
		# Khách giỗ ra cổng nhận túi, mang vào đặt lên bàn cỗ
		_say(_sau, "\"Bơ tới rồi đó! Cô Năm ra lấy giùm bà.\"", 2.5)
		_handover_bag(_helper, _helper_home)
	else:
		_play_deliver("hand")
		deliveries._hand_bread(_hand(_may))
		if _may:
			_may.play_once("nhan_banh", "vui", 2.0)
		_toast("Chị Mây cúi qua đầu khách nhận bánh: \"Mèo giỏi quá!\"" if deliveries.side_ok[i] else "Chị Mây nghe rồi, cúi xuống nhận bánh.", 2.5, 1.8)
	return true


func _deliver_lift(i: int) -> bool:
	_prompt.visible = false
	deliveries.side_ok[i] = _hung_calls < 2
	_play_deliver("hand")
	deliveries._hand_bread(_hand(_hung))
	if _hung:
		_hung.play_once("nhan_banh", "vui", 2.0)
	_say(_hung, "\"Kịp lắm! Bơ ngồi chơi chút nha.\"" if deliveries.side_ok[i] else "\"Tới rồi hả, cảm ơn Bơ!\"", 2.5, 0.8)
	return true


func _deliver_table(i: int) -> bool:
	_prompt.visible = false
	if orders[i].get("side_quest", "") == "vao_tu_gian":
		deliveries.side_ok[i] = _via_trellis and not _ground_entry
	if player.has_method("play_clip"):
		player.play_clip("dua_tui")
	_place_bag(0.6)
	if _sau:
		_sau.play_for("vui", 2.5)
	if deliveries.side_ok[i]:
		_toast("Vào sân từ giàn bông giấy, chẳng đụng ai!", 2.0, 1.8)
	return true


## Người nhận đi ra chỗ Bơ, cầm túi (Bơ nhả túi), đi về đặt lên bàn cỗ.
func _handover_bag(n: Nguoi, home: Vector3) -> void:
	if n == null:
		_place_bag(0.5)
		return
	var to := player.global_position + (n.global_position - player.global_position).normalized() * 0.7
	to.y = 0.0
	var go := maxf(_flat(n.global_position, to) / 1.4, 0.3)
	n.play("di_bo")
	_face(n, to)
	var tw := create_tween()
	tw.tween_property(n, "position", to, go)
	tw.tween_callback(func():
		n.play_once("nhan_banh", "di_bo")
		if player.has_method("play_clip"):
			player.play_clip("dua_tui")
		_face(n, home)
	)
	tw.tween_interval(1.0)
	tw.tween_property(n, "position", home, maxf(_flat(to, home) / 1.4, 0.3))
	tw.tween_callback(func():
		_place_bag(0.0)
		n.rotation.y = PI
		n.play("noi")
	)


func _place_bag(delay: float) -> void:
	var slot := _bags_on_table
	_bags_on_table += 1
	get_tree().create_timer(maxf(delay, 0.01)).timeout.connect(func():
		var bag: Node3D = preload("res://assets/models/giao/tui_3o.glb").instantiate()
		add_child(bag)
		bag.position = TABLE_POS + Vector3(0.05, TABLE_SIZE.y + 0.02, -0.9 + (slot % 4) * 0.55)
		bag.rotation.y = PI / 2.0
	)


func _play_deliver(kind: String) -> void:
	if player.has_method("play_deliver"):
		player.play_deliver(kind)


func _hand(n: Nguoi) -> Vector3:
	if n and n.skeleton:
		var b := n.skeleton.find_bone("hand.R")
		if b >= 0:
			return (n.skeleton.global_transform * n.skeleton.get_bone_global_pose(b)) * Vector3(0, 0.07, 0)
	return (n.global_position if n else player.global_position) + Vector3(0, 0.9, 0)


func _dog_woke() -> bool:
	return dog != null and "woke_up_this_order" in dog and dog.woke_up_this_order


# ---------------------------------------------------------------- mỗi nhịp

func _physics_process(delta: float) -> void:
	if player == null or hud == null:
		return
	var playing: bool = _main.state == _main.State.PLAY
	if playing and Input.is_action_just_pressed("goi") and player.has_method("sit_call"):
		player.sit_call()
	_update_shared(delta)
	_update_lift(delta)
	_update_hose(delta)
	_update_tyres(delta)
	_update_walkers(delta)
	_update_yard(delta)
	_update_order()
	if _speech.visible and Time.get_ticks_msec() / 1000.0 > _speech_until:
		_speech.visible = false
	if not (_current >= 0 and player.carrying):
		_prompt.visible = false


## Thử thách: đồng hồ chung của các chuyến giỗ chạy cả lúc về lò lấy chuyến sau.
func _update_shared(delta: float) -> void:
	if not _shared_on:
		return
	_shared_left = maxf(_shared_left - delta, 0.0)
	if _current >= 0 and player.carrying and orders[_current].get("gio_group", false):
		_main.time_left = _shared_left
	elif not player.carrying and _main.order_index < orders.size() and orders[_main.order_index].get("gio_group", false):
		hud.set_timer(_shared_left, float(DoKho.v("gio_shared_time", 120.0)), true)


func _update_lift(delta: float) -> void:
	_lift_t = fmod(_lift_t + delta, _lift_period)
	# Đứng lại một chút ở dưới và ở trên cho dễ nhảy lên, dễ đưa bánh
	var k := clampf(0.5 - 0.62 * cos(TAU * _lift_t / _lift_period), 0.0, 1.0)
	var top := lerpf(LIFT_LOW, LIFT_HIGH, k)
	_lift.position = LIFT_POS + Vector3(0, top - LIFT_SIZE.y / 2.0, 0)


func _update_hose(delta: float) -> void:
	_hose_t = fmod(_hose_t + delta, HOSE_PERIOD)
	var on := _hose_t < HOSE_ON
	if not on:
		_gust_done = false
	var z := HOSE_ZONE.position.y + HOSE_ZONE.size.y / 2.0
	for k in _jets.size():
		var jet := _jets[k]
		jet.visible = on
		if on:
			var f := fmod(_hose_t * 3.0 + k * 0.2, 1.0)
			jet.position = Vector3(HOSE_ZONE.position.x + 0.5 + f * (HOSE_ZONE.size.x - 1.0), 0.3 + 0.15 * (k % 3), z - 0.25 + 0.12 * k)
	var p := player.global_position
	if on and not _gust_done and p.y < 1.2 and HOSE_ZONE.has_point(Vector2(p.x, p.z)):
		_gust_done = true
		_push_left = float(DoKho.v("air_push", 1.2))
		if not _hose_hint:
			_hose_hint = true
			_toast("Phì! Vòi hơi thổi Bơ dạt ra. Canh lúc vòi tắt mà qua.", 2.5)
	if _push_left > 0.0:
		var stepx := minf(_push_left, 5.0 * delta)
		_push_left -= stepx
		player.move_and_collide(Vector3(stepx, 0, 0))


func _update_tyres(delta: float) -> void:
	_tyre_cd = maxf(_tyre_cd - delta, 0.0)
	_tyre_t += delta
	if _tyre_t >= TYRE_EVERY:
		_tyre_t = 0.0
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position = Vector3(TYRE_LANE_X, TYRE_R, TYRE_FROM_Z)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var c := CylinderMesh.new()
		c.top_radius = TYRE_R
		c.bottom_radius = TYRE_R
		c.height = 0.16
		c.radial_segments = 14
		c.rings = 1
		var mi := Blocks.mesh(spin, c, Vector3.ZERO, Color("#2B2622"))
		mi.rotation.z = PI / 2.0
		Blocks.box(spin, Vector3(0.17, 0.2, 0.06), Vector3.ZERO, STEEL)
		_tyres.append({"node": pivot, "spin": spin})
	var p := player.global_position
	for t in _tyres.duplicate():
		var node: Node3D = t.node
		node.position.z += TYRE_SPEED * delta
		(t.spin as Node3D).rotation.x += TYRE_SPEED / TYRE_R * delta
		if node.position.z > TYRE_TO_Z:
			node.queue_free()
			_tyres.erase(t)
			continue
		if _tyre_cd <= 0.0 and p.y < 0.7 and _flat(p, node.position) < TYRE_R + 0.22:
			_tyre_cd = 1.0
			player.bump("cart", node.position - Vector3(0, 0, 0.3), float(DoKho.v("tyre_stun", 0.5)))
			if not _tyre_hint:
				_tyre_hint = true
				_toast("Lốp lăn ra đường! Né sang bên nha.", 2.0)


func _update_walkers(delta: float) -> void:
	var p := player.global_position
	for w in _walkers:
		var n: Nguoi = w.node
		var lane: Array = w.lane
		w.cd = maxf(w.cd - delta, 0.0)
		n.position.x += w.dir * WALK_SPEED * delta
		if n.position.x > lane[2] or n.position.x < lane[1]:
			w.dir = -w.dir
			n.position.x = clampf(n.position.x, lane[1], lane[2])
		n.rotation.y = PI / 2.0 * w.dir
		if w.cd <= 0.0 and p.y < 1.0 and _flat(p, n.global_position) < 0.5:
			w.cd = 1.5
			n.play_once("va", "di_bo")
			player.bump("person", n.global_position, float(DoKho.v("market_bump_stun", 0.4)))


## Sân giỗ: con nít chạy theo, Bà Sáu tưới cây, gai giàn bông giấy, bàn thờ.
func _update_yard(delta: float) -> void:
	var p := player.global_position
	var in_yard := YARD.has_point(Vector2(p.x, p.z))
	var on_trellis := TRELLIS.grow(0.1).has_point(Vector2(p.x, p.z)) and p.y > TRELLIS_TOP - 0.3
	var slow := 1.0
	if on_trellis:
		slow = float(DoKho.v("thorn_slow", 0.5))
		if _current >= 0:
			_via_trellis = true
		if not _thorn_hint:
			_thorn_hint = true
			_toast("Gai bông giấy, đi chậm thôi!", 2.0)
	if in_yard and p.y < 0.6 and _current >= 0 and not _via_trellis:
		_ground_entry = true
	if _flat(p, ALTAR_POS) < 1.3 and p.y < 0.6:
		slow = minf(slow, 0.6)  # đi ngang bàn thờ thì chậm lại
		if not _altar_hint:
			_altar_hint = true
			_toast("Bơ đi chậm lại, cúi đầu trước bàn thờ.", 2.0)
	player.walk_speed = _base_walk * slow
	player.sprint_speed = _base_sprint * slow
	_update_kids(delta, in_yard and p.y < 0.6)
	_update_spray(delta)


func _update_kids(delta: float, chase: bool) -> void:
	var p := player.global_position
	for kd in _kids:
		var n: Nguoi = kd.node
		kd.cd = maxf(kd.cd - delta, 0.0)
		var goal: Vector3 = p if chase else kd.home
		goal.y = 0.0
		goal.x = clampf(goal.x, -19.0, -17.7)
		goal.z = clampf(goal.z, 18.9, 23.5)
		var to := goal - n.position
		to.y = 0.0
		var stop := 0.35 if chase else 0.1
		if to.length() > stop:
			n.position += to.normalized() * minf(KID_SPEED * delta, to.length() - stop)
			n.rotation.y = atan2(to.x, to.z)
			n.play("di_bo")
		elif not n.busy():
			n.play("vui")
		if chase and kd.cd <= 0.0 and _flat(p, n.position) < 0.45:
			kd.cd = KID_TRIP_CD
			player.bump("kid", n.position, float(DoKho.v("kid_trip_stun", 0.4)))
			n.play_for("vui", 1.0)


## Bà Sáu ngồi ghế tưới: tia nước quét qua lối đi tới chậu bên kia. Dính nước thì khựng (Thong thả: không khựng).
func _update_spray(delta: float) -> void:
	if _sau == null:
		return
	_wet_cd = maxf(_wet_cd - delta, 0.0)
	_spray_t += delta
	if _spray_t >= SPRAY_EVERY:
		_spray_t = 0.0
		_spray_target = (_spray_target + 1) % POTS.size()
	var on: bool = _spray_t < SPRAY_ON and not (_current >= 0 and orders[_current].get("gio", false) and _helper and _helper.position.distance_to(_helper_home) > 0.2)
	_spray.visible = on
	if not on:
		return
	var a := BA_SAU_SEAT + Vector3(0.35, 0.75, -0.3)
	var b: Vector3 = POTS[_spray_target] + Vector3(0, 0.35, 0)
	_spray.position = (a + b) / 2.0
	_spray.look_at_from_position(_spray.position, b, Vector3.UP)
	_spray.scale = Vector3(1, 1, a.distance_to(b))
	var p := player.global_position
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var t := clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var closest := Vector2(a.x, a.z) + ab * t
	if _wet_cd <= 0.0 and p.y < 1.0 and closest.distance_to(Vector2(p.x, p.z)) < 0.3:
		_wet_cd = 2.0
		var stun := float(DoKho.v("water_stun", 0.5))
		if stun > 0.0:
			player.bump("water", Vector3(closest.x, 0, closest.y), stun)
		if player.has_method("play_clip"):
			player.play_clip("giu_nuoc")
		_toast("Ướt rồi! Bơ giũ nước phành phạch.", 1.8)


## Lời gọi của Anh Hùng theo đồng hồ (nhiệm vụ phụ: giao trước lần gọi thứ hai).
func _update_order() -> void:
	if _current < 0 or not player.carrying:
		return
	var order: Dictionary = orders[_current]
	if order.get("errand_item", "") == "nhang" and order.get("side_quest", "") == "khong_dung_nguoi":
		deliveries.side_ok[_current] = _bumps == 0
	if order.get("delivery", "") == "lift" and _hung:
		var ratio: float = _main.time_left / maxf(_main._time_limit(order), 0.1)
		if _hung_calls == 0 and ratio < 0.7:
			_hung_calls = 1
			_hung.play_for("vay", 1.5)
			_say(_hung, "\"Bơ ơi, bánh tới chưa con?\"", 2.5)
		elif _hung_calls == 1 and ratio < 0.35:
			_hung_calls = 2
			_hung.play_for("sot_ruot", 2.0)
			_say(_hung, "\"Bơ ơiii! Đói bụng quá!\"", 2.5)


## Đếm va người trong đơn mua nhang (nhiệm vụ phụ "khong_dung_nguoi").
func on_bump(kind: String) -> void:
	if kind == "person" and _current >= 0:
		_bumps += 1


func _say(n: Node3D, text: String, seconds := 2.5, delay := 0.0) -> void:
	if n == null:
		return
	var show := func():
		if not is_instance_valid(n):
			return
		_speech.text = text
		_speech.global_position = n.global_position + Vector3(0, 2.0, 0)
		_speech.visible = true
		_speech_until = Time.get_ticks_msec() / 1000.0 + seconds
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(show)
	else:
		show.call()


func _toast(text: String, seconds := 2.0, delay := 0.0) -> void:
	if hud == null:
		return
	if delay <= 0.0:
		hud.show_toast(text, seconds)
	else:
		get_tree().create_timer(delay).timeout.connect(func(): hud.show_toast(text, seconds))


static func _face(n: Node3D, to: Vector3) -> void:
	var d := to - n.global_position
	if Vector2(d.x, d.z).length() > 0.01:
		n.rotation.y = atan2(d.x, d.z)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
