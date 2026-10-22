class_name ThuSau
extends Node3D
## Thứ Sáu chiều tà, đám giỗ Bà Sáu (gói việc thiet-ke-man/goi-viec-thu-sau.md, trang thiết kế màn mục 06–07).
## Tiệm xe dùng model G6 (Sang duyệt 22/10, bàn giao thiet-ke-man/goi-phac-thao/g6-tiem-xe/BAN-GIAO.md,
## file ở assets/models/thu_sau/). Sân giỗ dùng model G7 (Sang duyệt 22/10, bàn giao
## thiet-ke-man/goi-phac-thao/g7-dam-gio/BAN-GIAO.md, file ở assets/models/gio/); sân, giàn, lu, ghế mây
## có mọi ngày (CityProps), bàn cỗ, bàn thờ, khách giỗ chỉ dựng ở đây.
## main.gd thêm node này mọi ngày, ngày khác tự gỡ. Phần giao của ba cách giao mới ở đây,
## deliveries.gd chỉ chuyển qua (deliveries.thu_sau.step):
## - call: tới gần khách, bấm Q ngồi kêu "meo" (clip ngoi_goi), khách nghe (trong call_radius, không bị tường che)
##   thì nhận bánh. Chị Mây ở quầy kín khách, Bà Sáu ra cổng sân nhận. Lại sát khách bấm E cũng được.
## - lift: Anh Hùng đứng cạnh cầu nâng sửa xe. Cầu lên xuống theo nhịp lift_period: Bơ đứng lên dải thảm
##   của cầu cho nó nâng tới tay anh rồi bấm E. Vòi hơi thổi ngang lối vào, lốp lăn từ giá ra đường.
##   Lối tắt: khe 1,2 m bên hông tiệm (build_khe, đạp tường qua cổng tôn) ra hẻm sau, vào cửa sau.
## - gio_table: chuyến giỗ cuối: đặt túi 3 ổ lên mẹt đầu bàn dài trong sân. Leo thang giàn bông giấy
##   (gai làm chậm), đi hết ván rồi nhảy xuống mẹt thì khỏi băng sân qua con nít và bình tưới của Bà Sáu.
## Đơn giỗ (khóa "gio": true) ngậm túi 3 ổ (player.carry_tui3). Thử thách: các đơn "gio_group" dùng
## chung một đồng hồ gio_shared_time giây (chạy cả lúc về lò lấy chuyến sau). Thong thả: mỗi chuyến giờ riêng.
## Ngồi gọi Q: player.sit_call() (phát player.called). Số dễ/khó: DoKho.EASY, khóa ghi ở bảng gói việc.

const DAY_ID := "thu_sau"
const KINDS := ["call", "lift", "gio_table"]

## Tiệm xe Anh Hùng: model G6 dựng cho lòng tiệm sâu 8,4 m, mặt tiền z 25; ô tiệm trong phố là x 29,5..35,
## mặt tiền z 24, sâu 7,3 m nên toạ độ trong tiệm co theo G6_DEPTH. g6(x, y) đổi toạ độ Blender của cảnh G6
## (x sang phải, y vào trong tiệm, gốc giữa mép mặt tiền) sang toạ độ Godot.
const SHOP_X := 32.25
const SHOP_FRONT := 24.0
const G6_DEPTH := 7.3 / 8.4
const MODELS := "res://assets/models/thu_sau/%s.glb"
const LIFT_SPOT := Vector3(33.2, 0, 22.75)      ## chỗ đứng đầu cầu nâng (mũi tên chỉ tới đây)
const LIFT_AT := Vector2(1.6, 3.4)              ## cầu nâng (Blender), xoay -90°: dài 2,2 m theo z, dải thảm quay ra lối đi
const LIFT_DECK := Vector3(1.0, 1.2, 2.2)       ## khối va chạm dưới mặt cầu: đặc tới sàn, không chui được
const DECK_ABOVE_BONE := 0.05                   ## mặt cầu cao hơn xương "mat" (mặt thấp 0,30 m, cao 1,05 m)
const HUNG_AT := Vector2(0.62, 3.25)            ## Anh Hùng đứng cạnh cầu, quay mặt +x
const HUNG_REACH := 1.4                         ## Bơ đứng trên cầu (cao từ 0,8 m), cách Anh Hùng dưới mức này thì đưa được
const HUNG_CALL2 := 0.4                         ## gọi lần hai khi đồng hồ còn 40%
const HOSE_AT := Vector2(-1.35, 1.0)            ## vòi hơi thổi +x ngang lối vào, cao 0,32 m
const HOSE_REACH := Vector2(0.3, 2.2)           ## luồng gió từ x +0,3 tới +2,2 tính từ chân vòi
const HOSE_HALF_W := 0.4
const HOSE_CLIPS := [["bao_truoc", 0.66], ["thoi", 1.5], ["nghi", 2.0]]
const TYRES := ["lop_nho", "lop_vua", "lop_to"]
const TYRE_R := {"lop_nho": 0.28, "lop_vua": 0.25, "lop_to": 0.32}
const RACK_AT := Vector2(-1.9, -0.8)            ## giá lốp trên vỉa hè
const TYRE_EVERY := 4.5
const TYRE_ROLL := 4.0                          ## lăn 4 m thì đổ
## Khe hông tiệm (x 28,3..29,5): cổng tôn 1,9 m cách mặt tiền 3,4 m (G6), thùng gỗ 0,45 m làm bậc
const KHE_LEN := 8.4
const KHE_GATE := 3.4
const KHE_GATE_H := 1.9

## Sân giỗ nhà Bà Sáu (G7): cổng z 22,0, sân z 22,0..26,6. Tọa độ theo BAN-GIAO G7 mục 3.
const GIO_GATE := Vector3(-18.5, 0, 18.3)       ## đứng đây ngồi gọi Bà Sáu
const GIO_TABLE := Vector3(-17.9, 0, 23.5)      ## mẹt tre đầu bàn dài gần cổng, ngay dưới đầu ván giàn
const YARD := CityProps.BA_SAU_YARD
const TABLE_POS := Vector3(-17.9, 0, 24.4)      ## bàn dài kê dọc vào sân, z 23,2..25,6
const TABLE_SIZE := Vector3(0.87, 0.756, 2.47)
const MET_REACH := 0.6                          ## Bơ cách mẹt dưới mức này (trên bàn hay dưới đất) thì đặt được
const ALTAR_POS := Vector3(-16.6, 0, 26.25)     ## bàn thờ sát mặt tiền nhà, quay ra sân (nhà trong game đặc)
const ALTAR_TOP := 0.956
const BA_SAU_SEAT := CityProps.BA_SAU_CHAIR + Vector3(0, 0.08, 0)
const POTS := CityProps.BA_SAU_POTS
const GATE_INSIDE := Vector3(-18.5, 0, 22.45)   ## Bà Sáu đứng trong cổng nhận túi
## Giàn bông giấy (CityProps.gian_bong_giay): 2,6 × 1,2 m trùm lên cổng, ván nhô vào sân tới z 23,03
const TRELLIS := Rect2(-19.85, 21.35, 2.7, 1.7)
const TRELLIS_TOP := 2.3
const THORNS := [Vector2(-19.8, 21.4), Vector2(-17.2, 21.4)]  ## hai thân bông giấy có gai quấn cột trước
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
const YELLOW := Color("#E3B23C")
const WATER := Color(0.62, 0.8, 0.95, 0.55)

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
var _lift_skel: Skeleton3D
var _lift_bone := -1
var _hose: AnimationPlayer
var _hose_step := 0
var _hose_t := 0.0
var _hose_from := Vector3.ZERO
var _gust_done := false
var _push_left := 0.0
var _tyres: Array = []             # {"node", "spin", "speed", "r", "start", "fallen"}
var _tyre_t := 0.0
var _rng := RandomNumberGenerator.new()
var _tyre_cd := 0.0
var _hose_hint := false
var _tyre_hint := false

# Người
var _may: Nguoi
var _hung: Nguoi
var _sau: Nguoi
var _helper: Nguoi                 # khách giỗ ra cổng nhận túi khi Bà Sáu chưa có clip ra_cong_nhan
var _sau_stands := false           # basau.glb đã có clip G7 (tuoi_cay, ra_cong_nhan, chao_tien): đứng tưới cây, ra cổng
var _sau_home := Vector3.ZERO
var _ring: Node3D                  # vòng vàng quanh mẹt, hiện ở chuyến đặt bàn
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
	player.climb_moves = true  # khe hông tiệm xe: đạp tường qua cổng tôn; giàn bông giấy
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

## Toạ độ Godot của một điểm trong cảnh G6 (Blender: x sang phải, y vào trong tiệm).
static func g6(at: Vector2, y := 0.0) -> Vector3:
	return Vector3(SHOP_X + at.x, y, SHOP_FRONT - at.y * G6_DEPTH)


## Tiệm xe chiều tà (model G6): lòng tiệm, cầu nâng chạy nhịp, Anh Hùng đứng sửa xe, vòi hơi, giá lốp, đèn.
## CityProps._tiem_xe ngày Thứ Sáu bỏ bàn nâng, chồng lốp, máy nén cũ để model này thay vào.
func _build_shop() -> void:
	_rng.seed = 6
	put_model(self, "long_tiem", Vector3(SHOP_X, 0, SHOP_FRONT), 0.0, Vector3(1, 1, G6_DEPTH))
	Blocks.collider(self, Vector3(1.25, 0.98, 0.6), g6(Vector2(-1.43, 7.87), 0.49), Blocks.LAYER_PROP)   # bàn thợ máy
	Blocks.collider(self, Vector3(0.54, 0.75, 0.35), g6(Vector2(2.3, 0.55), 0.375), Blocks.LAYER_PROP)   # bàn thờ thần tài
	var door := put_model(self, "cua_sau", CityProps.SHOP_BACK_DOOR)
	_play_held(door, "mo_san")
	put_model(self, "may_nen_khi", g6(Vector2(1.8, 6.3)), PI)
	Blocks.collider(self, Vector3(0.9, 0.7, 0.46), g6(Vector2(1.8, 6.3), 0.35), Blocks.LAYER_PROP)
	for y in [2.2, 5.0]:
		put_model(self, "den_bong", g6(Vector2(0, y), 2.4))
	for x in [-1.6, 1.6]:
		var den := put_model(self, "den_long_ong", g6(Vector2(x, -0.55), 2.08))
		_play_loop(den, "lac", _rng.randf())
	put_model(self, "gia_lop", g6(RACK_AT), 0.2)
	Blocks.collider(self, Vector3(1.2, 1.18, 0.75), g6(RACK_AT, 0.59), Blocks.LAYER_PROP)
	put_model(self, "hang_nhot", g6(Vector2(2.25, -0.55)), -0.2)
	Blocks.collider(self, Vector3(0.84, 0.86, 0.5), g6(Vector2(2.25, -0.55), 0.43), Blocks.LAYER_PROP)
	put_model(self, "hang_lop", g6(Vector2(1.2, -0.75)), 0.3)
	Blocks.collider(self, Vector3(1.0, 0.64, 0.6), g6(Vector2(1.45, -0.75), 0.32), Blocks.LAYER_PROP)
	# Cầu nâng: AnimationPlayer chạy "chu_ky" lặp (2,5 s một lượt ở Thử thách), khối va chạm bám xương "mat"
	var lift := put_model(self, "cau_nang", g6(LIFT_AT), -PI / 2.0)
	_lift_skel = lift.find_children("*", "Skeleton3D", true, false)[0]
	_lift_bone = _lift_skel.find_bone("mat")
	var ap := _play_loop(lift, "chu_ky")
	if ap:
		ap.speed_scale = 2.5 / float(DoKho.v("lift_period", 2.5))
	_lift = AnimatableBody3D.new()
	_lift.name = "CauNang"
	_lift.collision_layer = Blocks.LAYER_PROP
	_lift.sync_to_physics = false
	_lift.top_level = true
	add_child(_lift)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = LIFT_DECK
	shape.shape = bs
	_lift.add_child(shape)
	_update_lift()
	if _has_order("lift"):
		# Anh Hùng đứng cạnh cầu (clip sua_xe, goi_1, goi_2, nhan_banh_cau do luồng "Người dân vào game" thêm vào hung.glb)
		_hung = _person("hung", g6(HUNG_AT), PI / 2.0, "sua_xe")
		_hung.add_collision(Vector3(0.5, 1.6, 0.35), Vector3(0, 0.8, 0))
		if ResourceLoader.exists("res://assets/models/nguoi/co_le.glb"):
			_attach_wrench.call_deferred(_hung)
		Blocks.label(self, _title("lift"), g6(HUNG_AT, 2.3), 40)
	# Vòi hơi: báo trước → thổi → nghỉ, luồng gió chỉ đẩy trong lúc "thoi"
	var hose := put_model(self, "voi_hoi", g6(HOSE_AT))
	_hose = hose.find_children("*", "AnimationPlayer", true, false)[0] if not hose.find_children("*", "AnimationPlayer", true, false).is_empty() else null
	_hose_from = g6(HOSE_AT)
	_hose_step = 2
	_hose_t = 0.0
	_next_hose_clip()


func _attach_wrench(n: Nguoi) -> void:
	if n.skeleton == null:
		return
	var at := n.attach("hand.R")
	at.add_child(load("res://assets/models/nguoi/co_le.glb").instantiate())


## Khe 1,2 m bên hông tiệm xe (gói G6): nhà bên trái hẹp lại, hai vách cách nhau 1,2 m để đạp tường,
## cổng tôn 1,9 m chắn ngang (không chui được), thùng gỗ 0,45 m làm bậc đầu. CityProps gọi khi dựng ô "khe_hong",
## mọi ngày đều có. front_z: mép vỉa hè (mặt tiền dãy nhà), depth: sâu tới hẻm giữa khối.
static func build_khe(parent: Node3D, x0: float, x1: float, front_z: float, depth: float) -> void:
	var cx := (x0 + x1) / 2.0
	var k := depth / KHE_LEN
	put_model(parent, "khe_hong", Vector3(cx, 0, front_z), 0.0, Vector3(1, 1, k))
	Blocks.collider(parent, Vector3(x1 - x0, KHE_GATE_H, 0.08), Vector3(cx, KHE_GATE_H / 2.0, front_z - KHE_GATE * k))
	Blocks.collider(parent, Vector3(0.45, 0.45, 0.45 * k), Vector3(cx - 0.275, 0.225, front_z - 2.325 * k), Blocks.LAYER_PROP)
	Blocks.collider(parent, Vector3(0.24, 0.3, 0.24), Vector3(cx + 0.35, 0.15, front_z - 1.4 * k), Blocks.LAYER_PROP)


static var _model_scenes := {}
static var _mats := {}


## Đặt model G6. Màu nằm ở màu đỉnh (COLOR_0); vật liệu tên "den_sang" thì tự sáng (chiều tối),
## "gio" trong mờ không đổ bóng. Bản web (Compatibility) đổi màu đỉnh linear sang sRGB như PhoModels.
static func put_model(parent: Node, model: String, pos: Vector3, rot_y := 0.0, scale := Vector3.ONE) -> Node3D:
	if not _model_scenes.has(model):
		_model_scenes[model] = load(MODELS % model)
	var n: Node3D = _model_scenes[model].instantiate()
	n.position = pos
	n.rotation.y = rot_y
	n.scale = scale
	parent.add_child(n)
	var web := RenderingServer.get_rendering_device() == null
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var src: Mesh = mi.mesh
		if web:
			mi.mesh = _srgb_mesh(src, model + ":" + str(mi.name))
		for i in src.get_surface_count():
			var mname := src.surface_get_material(i).resource_name if src.surface_get_material(i) else ""
			mi.set_surface_override_material(i, _material(mname))
			if mname == "gio":
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


static var _srgb_cache := {}

static func _srgb_mesh(src: Mesh, key: String) -> Mesh:
	if _srgb_cache.has(key):
		return _srgb_cache[key]
	var dst := ArrayMesh.new()
	for i in src.get_surface_count():
		var arrays := src.surface_get_arrays(i)
		if arrays[Mesh.ARRAY_COLOR] != null:
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for c in cols.size():
				cols[c] = cols[c].linear_to_srgb()
			arrays[Mesh.ARRAY_COLOR] = cols
		dst.add_surface_from_arrays(src.surface_get_primitive_type(i), arrays, [], {}, src.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		dst.surface_set_material(i, src.surface_get_material(i))
	_srgb_cache[key] = dst
	return dst


static func _material(mname: String) -> StandardMaterial3D:
	var kind := mname if mname in ["den_sang", "gio"] else "solid"
	if not _mats.has(kind):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if kind == "den_sang":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # bóng đèn, ô cửa sáng lúc chiều tối
		elif kind == "gio":
			m.albedo_color = Color(1, 1, 1, 0.5)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[kind] = m
	return _mats[kind]


static func _play_loop(n: Node, clip: String, offset := 0.0) -> AnimationPlayer:
	for ap: AnimationPlayer in n.find_children("*", "AnimationPlayer", true, false):
		if ap.has_animation(clip):
			ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
			ap.play(clip)
			ap.seek(offset * ap.get_animation(clip).length, true)
			return ap
	return null


static func _play_held(n: Node, clip: String) -> void:
	for ap: AnimationPlayer in n.find_children("*", "AnimationPlayer", true, false):
		if ap.has_animation(clip):
			ap.play(clip)


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


## Sân giỗ (G7): bàn dài dọn cỗ kê dọc dưới đầu ván giàn, mẹt tre giao túi, bàn thờ (không leo được),
## Bà Sáu tưới cây dọc tường trái, hai đứa nhỏ chạy theo Bơ, khách giỗ đứng nói chuyện.
func _build_yard() -> void:
	var gio := func(model: String, pos: Vector3, yaw := 0.0) -> MeshInstance3D: return PhoModels.put(self, CityProps.GIO % model, pos, yaw)
	# Bàn dài, sáu ghế đẩu, hai mâm cỗ, mẹt tre. Gầm bàn 0,63 m: chỉ mặt bàn có va chạm, Bơ chui được.
	gio.call("ban_dai", TABLE_POS, PI / 2.0)
	gio.call("ghe_dau_nhua", TABLE_POS, PI / 2.0)
	Blocks.collider(self, Vector3(TABLE_SIZE.x, 0.06, TABLE_SIZE.z), TABLE_POS + Vector3(0, TABLE_SIZE.y - 0.03, 0), Blocks.LAYER_PROP)
	for z in [0.25, 0.95]:
		gio.call("mam_co", TABLE_POS + Vector3(0, TABLE_SIZE.y, z), z)
	gio.call("dia_banh_mi", TABLE_POS + Vector3(0.22, TABLE_SIZE.y, -0.4))
	gio.call("ly_nuoc", TABLE_POS + Vector3(-0.25, TABLE_SIZE.y, -0.35), PI / 2.0)
	var top := Vector3(GIO_TABLE.x, TABLE_SIZE.y + 0.006, GIO_TABLE.z)
	gio.call("met_tre", top)
	_ring = Node3D.new()
	_ring.position = top + Vector3(0, 0.03, 0)
	add_child(_ring)
	var ring := PhoModels.put(_ring, CityProps.GIO % "vong_giao", Vector3.ZERO)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("#FFD45A")
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = glow
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	# Bàn thờ quay ra sân: hộp chặn cao 1,2 m che cả bàn, không cho leo; đi ngang thì chậm lại
	gio.call("ban_tho", ALTAR_POS, PI)
	Blocks.collider(self, Vector3(1.5, 1.2, 0.64), ALTAR_POS + Vector3(0, 0.6, 0), Blocks.LAYER_PROP)
	var t := ALTAR_POS + Vector3(0, ALTAR_TOP, 0)
	gio.call("di_anh", t + Vector3(0, 0, 0.17), PI)
	gio.call("lu_huong", t + Vector3(0, 0, -0.05), PI)
	for k in 3:
		gio.call("nhang_thap", t + Vector3(-0.018 + k * 0.018, 0.105, -0.05), PI)
	var smoke := gio.call("khoi", t + Vector3(0, 0.39, -0.05), PI) as MeshInstance3D
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gio.call("chan_nen", t + Vector3(0, 0, 0.06), PI)
	gio.call("mam_ngu_qua", t + Vector3(-0.48, 0, -0.08), PI)
	for x in [-0.62, 0.62]:
		gio.call("binh_cuc", t + Vector3(x, 0, 0.16), PI)
	gio.call("ly_nuoc", t + Vector3(0.3, 0, -0.18), PI)
	gio.call("dia_banh_mi", t + Vector3(0.5, 0, -0.16), PI)
	if _gio_orders().is_empty():
		return
	_build_sau()
	_spray = Blocks.box(self, Vector3(0.05, 0.05, 1.0), Vector3.ZERO, WATER)
	_spray.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spray.visible = false
	# Khách giỗ đứng nói chuyện hai bên sân; một người ra cổng nhận túi khi Bà Sáu chưa có clip ra cổng
	_helper_home = Vector3(-19.0, 0, 23.0)
	if not _sau_stands:
		_helper = _person("cho4", _helper_home, PI, "noi", "dong")
	_person("cho6", Vector3(-19.6, 0, 25.0), PI / 2.0, "noi", "dong")
	_person("dicho1", Vector3(-16.85, 0, 24.9), -PI / 2.0, "xem", "dong")
	# Hai đứa nhỏ
	for k in 2:
		var home := Vector3(-20.0 + k * 0.8, 0, 23.4 + k * 1.8)
		var kid := _person(["cho5", "bena"][k], home, PI, "vui")
		_kids.append({"node": kid, "home": home, "cd": 0.0})


## Bà Sáu: có clip G7 thì đứng tưới hàng chậu dọc tường trái, Bơ gọi thì ra cổng nhận túi;
## chưa có thì ngồi ghế mây cầm bình tưới như cũ (khách giỗ ra cổng nhận giùm).
func _build_sau() -> void:
	_sau = _person("basau", BA_SAU_SEAT, PI, "viec_rieng")
	_sau_stands = _sau.anim != null and _sau.anim.has_animation("ra_cong_nhan") and _sau.anim.has_animation("tuoi_cay")
	if _sau_stands:
		_sau_home = Vector3(-20.45, 0, 23.3)
		_sau.position = _sau_home
		_sau.rotation.y = -PI / 2.0
		_sau.idle_anim = "tuoi_cay"
		_sau.play("tuoi_cay", 0.0)
		_sau.add_collision(Vector3(0.45, 1.5, 0.35), Vector3(0, 0.75, 0))
	else:
		_sau.add_collision(Vector3(0.5, 1.15, 0.65), Vector3(0, 0.58, 0.08))
	Blocks.label(self, _title("gio_table", "Bà Sáu"), CityProps.BA_SAU_CHAIR + Vector3(0, 2.2, 0), 40)


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
		# Gói nhang + hộp đèn cầy G7, Bơ ngậm quai dây gai (quai cao 0,135 m trên đáy gói)
		PhoModels.put(_nhang, CityProps.GIO % "goi_nhang", Vector3(0, -0.12, 0.02), PI / 2.0, Vector3.ONE * 0.85)
		deliveries._body_layer(_nhang)
	if _ring:
		_ring.visible = order.get("delivery", "") == "gio_table"
	if order.get("delivery", "") == "lift":
		_toast("Anh Hùng ngồi trên giàn cao. Đứng lên cầu nâng cho nó đưa lên!", 3.0, 2.6)
	elif order.get("delivery", "") == "call":
		_toast("Tới gần rồi bấm Q ngồi kêu meo, %s sẽ nghe thấy." % order.who, 3.0, 2.6)


func _on_delivered(i: int, order: Dictionary) -> void:
	if _ring:
		_ring.visible = false
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
		if _sau_stands:
			_sau_walk(GATE_INSIDE, func(): _sau.play("chao_tien"), 1.5)
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
			var up := _hung and player.global_position.y > 0.8 and _flat(player.global_position, _hung.global_position) < HUNG_REACH
			ready = in_zone or up
			hint = "[E] Đưa bánh cho Anh Hùng" if up else "Nhảy lên cầu nâng, đợi nó đưa lên"
			if (pressed and up) or (autotest and in_zone):
				return _deliver_lift(i)
		"gio_table":
			var near_table := _flat(player.global_position, GIO_TABLE) < MET_REACH + (0.4 if player.global_position.y < 0.5 else 0.0) and player.global_position.y < 1.6
			ready = in_zone or near_table
			hint = "[E] Đặt túi lên mẹt" if near_table else "Mang túi tới mẹt đầu bàn cỗ"
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
	if order.get("gio", false) and _sau_stands:
		# Bà Sáu bỏ bình tưới, ra cổng cúi nhận túi qua khe cổng, mang vào đặt lên mẹt
		_say(_sau, "\"Bơ tới rồi đó! Đưa bà nè.\"", 2.5)
		_sau_receive()
	elif order.get("gio", false):
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
		_hung.play_once("nhan_banh_cau" if _hung.anim and _hung.anim.has_animation("nhan_banh_cau") else "nhan_banh", "vui", 2.0)
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


## Bà Sáu (clip G7) đi ra trong cổng, cúi nhận túi (ra_cong_nhan), đi về chỗ tưới cây; túi lên bàn cỗ.
func _sau_receive() -> void:
	var to := GATE_INSIDE
	var bo := player.global_position
	if bo.z > CityProps.BA_SAU_YARD.position.y:
		to = bo + (_sau.global_position - bo).normalized() * 0.6  # Bơ đã vào sân: bà ra tới chỗ Bơ
		to.y = 0.0
	_sau_walk(to, func():
		_face(_sau, Vector3(bo.x, 0, bo.z))
		_sau.play_once("ra_cong_nhan", "dung_yen")
		if player.has_method("play_clip"):
			player.play_clip("dua_tui")
		get_tree().create_timer(2.0).timeout.connect(func():
			_place_bag(0.0)
			_sau_walk(_sau_home, func():
				_sau.rotation.y = -PI / 2.0
				_sau.play("tuoi_cay"))))


## Bà Sáu đi tới chỗ to (clip di_bo nếu có), xong gọi then.
func _sau_walk(to: Vector3, then: Callable, delay := 0.0) -> void:
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func():
		_face(_sau, to)
		_sau.play("di_bo" if _sau.anim.has_animation("di_bo") else "dung_yen"))
	tw.tween_property(_sau, "position", to, maxf(_flat(_sau.position, to) / 0.9, 0.3))
	tw.tween_callback(then)


func _place_bag(delay: float) -> void:
	var slot := _bags_on_table
	_bags_on_table += 1
	get_tree().create_timer(maxf(delay, 0.01)).timeout.connect(func():
		var bag: Node3D = preload("res://assets/models/giao/tui_3o.glb").instantiate()
		add_child(bag)
		bag.position = TABLE_POS + Vector3(0.22 * (1 if slot % 2 else -1), TABLE_SIZE.y + 0.02, -0.45 + (slot % 4) * 0.4)
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
	_update_lift()
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


## Khối va chạm của mặt cầu bám theo xương "mat" (AnimationPlayer chạy ở nhịp vật lý nên không lệch nhau).
func _update_lift() -> void:
	if _lift_skel == null or _lift_bone < 0:
		return
	var top := (_lift_skel.global_transform * _lift_skel.get_bone_global_pose(_lift_bone)).origin
	_lift.global_transform = Transform3D(Basis.IDENTITY, Vector3(top.x, top.y + DECK_ABOVE_BONE - LIFT_DECK.y / 2.0, top.z))


func _next_hose_clip() -> void:
	_hose_step = (_hose_step + 1) % HOSE_CLIPS.size()
	_hose_t = 0.0
	if _hose and _hose.has_animation(HOSE_CLIPS[_hose_step][0]):
		_hose.play(HOSE_CLIPS[_hose_step][0])


func _update_hose(delta: float) -> void:
	_hose_t += delta
	if _hose_t >= HOSE_CLIPS[_hose_step][1]:
		_next_hose_clip()
	var on: bool = HOSE_CLIPS[_hose_step][0] == "thoi"
	if not on:
		_gust_done = false
	var p := player.global_position
	var dx := p.x - _hose_from.x
	if on and not _gust_done and p.y < 0.7 and dx > HOSE_REACH.x and dx < HOSE_REACH.y and absf(p.z - _hose_from.z) < HOSE_HALF_W:
		_gust_done = true
		_push_left = float(DoKho.v("air_push", 1.2))
		if not _hose_hint:
			_hose_hint = true
			_toast("Phì! Vòi hơi thổi Bơ dạt ra. Canh lúc vòi nghỉ mà qua.", 2.5)
	if _push_left > 0.0:
		var stepx := minf(_push_left, 5.0 * delta)
		_push_left -= stepx
		player.move_and_collide(Vector3(stepx, 0, 0))


## Lốp từ giá lăn ra đường (theo +z), 1,5–2,5 m/s, lăn 4 m thì đổ nằm rồi biến mất.
func _update_tyres(delta: float) -> void:
	_tyre_cd = maxf(_tyre_cd - delta, 0.0)
	_tyre_t += delta
	if _tyre_t >= TYRE_EVERY:
		_tyre_t = 0.0
		var model: String = TYRES[_rng.randi() % TYRES.size()]
		var r: float = TYRE_R[model]
		var start := g6(RACK_AT) + Vector3(_rng.randf_range(-0.4, 0.4), r, 0.45)
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position = start
		var spin := Node3D.new()
		pivot.add_child(spin)
		put_model(spin, model, Vector3(0, -r, 0), PI / 2.0)  # lốp đứng, trục bánh theo x
		_tyres.append({"node": pivot, "spin": spin, "speed": _rng.randf_range(1.5, 2.5), "r": r, "start": start.z, "fallen": false})
	var p := player.global_position
	for t in _tyres.duplicate():
		var node: Node3D = t.node
		if t.fallen:
			continue
		node.position.z += t.speed * delta
		(t.spin as Node3D).rotation.x += t.speed / t.r * delta
		if node.position.z - t.start > TYRE_ROLL:
			t.fallen = true
			var tw := create_tween()
			tw.tween_property(node, "rotation:z", PI / 2.0, 0.4).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(node, "position:y", 0.05, 0.4)
			tw.tween_interval(1.5)
			tw.tween_callback(func():
				node.queue_free()
				_tyres.erase(t))
			continue
		if _tyre_cd <= 0.0 and p.y < 0.7 and _flat(p, node.position) < t.r + 0.22:
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
	var in_thorns := false
	for t in THORNS:
		in_thorns = in_thorns or (Vector2(p.x, p.z).distance_to(t) < 0.3 and p.y > 0.3 and p.y < 2.2)
	var slow := 1.0
	if in_thorns:
		slow = float(DoKho.v("thorn_slow", 0.5))
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
		goal.x = clampf(goal.x, -21.0, -18.6)  # sân phía tây bàn cỗ
		goal.z = clampf(goal.z, 22.4, 26.0)
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
	if _sau_stands:
		if _sau.current() != "tuoi_cay":
			_spray.visible = false
			return
		a = _hand(_sau) + Vector3(-0.3, -0.1, 0)
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
		if _hung_calls == 0:
			_hung_calls = 1
			_hung_call("goi_1", "vay", "\"Bơ ơi, bánh tới chưa con?\"")
		elif _hung_calls == 1 and ratio < HUNG_CALL2:
			_hung_calls = 2
			_hung_call("goi_2", "sot_ruot", "\"Bơ ơiii! Đói bụng quá!\"")


## Anh Hùng gọi Bơ: clip đứng mới (hung.glb sau khi luồng "Người dân vào game" thêm), chưa có thì dùng clip cũ.
func _hung_call(clip: String, fallback: String, text: String) -> void:
	if _hung.anim and _hung.anim.has_animation(clip):
		_hung.play_once(clip, "sua_xe")
	else:
		_hung.play_for(fallback, 1.8)
	_say(_hung, text, 2.5)


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
