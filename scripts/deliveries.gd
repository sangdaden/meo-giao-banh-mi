extends Node3D
## Năm cách giao bánh của Thứ Hai và nhiệm vụ phụ của từng đơn (gói 4, trang thiết kế màn mục 04).
## - hand: Chú Tư ngồi ghế nhựa đọc báo, hạ báo xuống, chìa tay nhận. Phụ: ngậm tờ báo về cho Cô Ba,
##   báo rơi nếu chạy nhanh qua vũng nước (đi về lò không tính giờ).
## - basket: Bé Na thòng giỏ nhựa từ ban công, giỏ đung đưa. Đứng trên xe máy, bấm E lúc giỏ đưa tới.
##   Trật thì đợi nhịp sau 1,5 s. Phụ: trúng ngay nhịp đầu.
## - counter: đặt túi lên quầy Cà phê Mây, Chị Mây đẩy lại chén sữa. Phụ: không đổ ly cà phê nào
##   (đụng bàn là ly rung, đụng mạnh hoặc nhảy lên bàn là đổ).
## - under_car: Anh Hùng nằm dưới gầm xe máy, thò tay ra. Chạy nhanh qua vũng dầu là trượt.
##   Phụ: không giẫm vũng dầu nào (giẫm là in dấu chân dầu).
## - chair: Bà Sáu ngồi ghế mây dưới giàn bông giấy, nhận bánh rồi gọi "Mực, đừng làm bé mèo sợ".
##   Phụ: qua hẻm mà Chó Mực không hề thức.
##
## Cách dùng trong main.gd:
##   build_static(self, ORDERS) trước Blocks.merge_static (phần đứng yên được gộp lệnh vẽ),
##   add_child sau merge_static (phần chuyển động: giỏ, ly, tay, tờ báo...), rồi setup().
##   Mỗi nhịp vật lý lúc đang mang bánh: step(order_index, in_zone) trả true là đã giao xong.
##   Bố cục lấy theo CityProps (xe máy, ban công Bé Na, quầy và bàn cà phê, ghế mây Bà Sáu).
## Toàn bộ là khối tạm; model giỏ, tờ báo, ly, chén sữa và tư thế 5 người dân chờ Sang duyệt phác thảo.

## Tên nhiệm vụ phụ theo khóa "side_quest" trong ORDERS
const QUESTS := {
	"bao_co_ba": "Ngậm tờ báo về cho Cô Ba",
	"gio_nhip_dau": "Bỏ bánh vào giỏ ngay nhịp đầu",
	"khong_do_ly": "Không làm đổ ly cà phê nào",
	"khong_dau": "Không giẫm vũng dầu nào",
	"muc_ngu_yen": "Qua hẻm mà Chó Mực không thức",
}

const PAPER := Color("#E8E2D0")
const INK := Color("#6E6A60")
const SKIN := Color("#E7B98F")
const PANTS := Color("#3D4A4A")
const WATER := Color(0.42, 0.62, 0.72, 0.55)
const OIL := Color(0.10, 0.08, 0.07, 0.85)
const BASKET := Color("#E05A7A")
const COFFEE := Color("#6B4A2E")

## Vũng nước trên đường từ sạp báo về lò bánh (tờ báo rơi nếu chạy nhanh qua)
const PUDDLES := [
	{"pos": Vector3(-11.0, 0, -3.6), "size": Vector2(2.6, 1.6)},
	{"pos": Vector3(-20.5, 0, -3.2), "size": Vector2(2.2, 1.8)},
]

const BASKET_PERIOD := 2.8      ## giây cho một lượt đưa qua đưa lại
const BASKET_SWING := 0.6       ## giỏ lệch xa nhất bao nhiêu mét so với chỗ đứng trên xe
const BASKET_REACH := 0.42      ## giỏ cách Bơ dưới mức này thì bỏ bánh vào được
const BASKET_RETRY := 1.5       ## trật thì phải đợi
const BASKET_HANG_Y := 1.25     ## đáy giỏ khi thòng xuống hẳn (yên xe 0,9 m)

var orders: Array = []
var player: CharacterBody3D
var dog: Node
var hud: CanvasLayer
var autotest := false

var current := -1                ## đơn đang làm (main gán lúc nhận bánh)
var side_ok: Array[bool] = [false, false, false, false, false]
var _kind: Array[String] = []

# Vị trí từng phần, tính ở build_static để _ready dựng phần chuyển động
var _arms: Array = []            # {"order", "pos", "yaw", "color"} → pivot vai
var _arm_nodes := {}             # order -> Node3D
var _prompt: Label3D
var _e_prev := false
var _hspeed_prev := 0.0

# Đơn 1: tờ báo
var _tu_paper: Node3D            # tờ báo trong tay Chú Tư (hạ xuống khi Bơ tới)
var _tu_paper_pos := Vector3.ZERO
var _mouth_paper: Node3D         # tờ báo Bơ ngậm
var _paper_state := ""           # "" | "carry" | "wet" | "done"
var _in_puddle := false

# Đơn 2: giỏ
var _moto_na := Vector3.ZERO     # tâm yên xe máy dưới ban công
var _anchor := Vector3.ZERO      # móc dây trên ban công
var _pivot: Node3D
var _rope: MeshInstance3D
var _basket: Node3D
var _basket_loaf: Node3D
var _lower := 0.0                # 0 = kéo lên ban công, 1 = thòng xuống hẳn
var _swing_t := 0.0
var _retry := 0.0
var _misses := 0
var _basket_done := false

# Đơn 3: ly cà phê
var _tables: Array = []          # bàn cà phê CityProps (nhóm "ban_ca_phe"): {"pos", "size", "touching"}
var _glasses: Array = []         # {"node", "table", "base", "wobble", "fallen"}
var _glass_broken := false
var _counter_top := Vector3.ZERO
var _milk: Node3D

# Đơn 4: vũng dầu
var _oils: Array = []            # {"pos", "r", "inside"}
var _oiled := false
var _oil_feet := 0.0             # còn bao lâu chân dính dầu
var _print_t := 0.0
var _print_side := 1.0
var _hand_hung := Vector3.ZERO

# Đơn 5: Bà Sáu, Chó Mực
var _bites := 0
var _speech: Label3D


# ---------------------------------------------------------------- dựng cảnh

## Phần đứng yên: người dân, ghế, xe, quầy, bàn, vũng nước, vũng dầu. Gọi trước Blocks.merge_static.
func build_static(parent: Node3D, order_list: Array) -> void:
	orders = order_list
	for i in orders.size():
		var o: Dictionary = orders[i]
		var kind: String = o.get("delivery", "hand")
		_kind.append(kind)
		var p: Vector3 = o.pos
		var title := "%d. %s\n%s" % [i + 1, o.who, o.place]
		match kind:
			"hand":
				_build_tu(parent, i, p, o.color, title)
			"basket":
				_build_na(parent, i, p, o.color, title)
			"counter":
				_build_may(parent, i, p, o.color, title)
			"under_car":
				_build_hung(parent, i, p, o.color, title)
			"chair":
				_build_sau(parent, i, p, o.color, title)
	for pd in PUDDLES:
		var m := Blocks.box(parent, Vector3(pd.size.x, 0.02, pd.size.y), pd.pos + Vector3(0, 0.055, 0), WATER)  # trên mặt vỉa hè 0,04 m
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Chú Tư: ngồi ghế nhựa xanh trên vỉa hè trước sạp báo, quay ra đường (hướng nam).
func _build_tu(parent: Node3D, i: int, p: Vector3, shirt: Color, title: String) -> void:
	var pos := p + Vector3(0, 0, -0.7)
	_seated(parent, pos, PI, shirt, Color("#3D7FC1"))
	_arms.append({"order": i, "pos": pos + Vector3(0.2, 1.05, 0.05), "yaw": PI, "color": shirt})
	_tu_paper_pos = pos + Vector3(-0.05, 1.15, 0.38)
	# Sạp báo (model sap_bao): tủ báo sát mặt tiền bên cạnh ghế, bảng kẹp báo dựa tường (mặt tiền ở z = -7)
	var stand := Blocks.collider(parent, Vector3(1.7, 0.95, 0.7), p + Vector3(1.4, 0.475, -0.6), Blocks.LAYER_PROP)
	PhoModels.put(stand, "sap_bao", Vector3(0, -0.475, -0.0))
	Blocks.collider(parent, Vector3(1.6, 2.25, 0.1), p + Vector3(1.4, 1.125, -0.96), Blocks.LAYER_PROP)
	Blocks.label(parent, title, pos + Vector3(0, 1.9, 0), 40)


## Bé Na: đứng trên ban công tầng 3 chung cư (CityProps), xe máy đậu ngay dưới, yên cao 0,9 m.
func _build_na(parent: Node3D, _i: int, _p: Vector3, shirt: Color, title: String) -> void:
	_moto_na = CityProps.BE_NA_BIKE + Vector3(0, 0.9, 0)
	_anchor = Vector3(CityProps.BE_NA_BIKE.x, CityProps.BE_NA_BALCONY.y + 1.0, CityProps.BE_NA_BIKE.z - 0.05)  # mép lan can
	_standing(parent, CityProps.BE_NA_BALCONY + Vector3(0.45, 0.08, 0.1), PI, shirt, 0.8)
	Blocks.label(parent, title, CityProps.BE_NA_BALCONY + Vector3(0, 2.0, 0.3), 40)


## Chị Mây: đứng sau quầy Cà phê Mây (CityProps.CAFE_COUNTER); ly cà phê đặt trên bàn nhựa thấp của quán.
func _build_may(parent: Node3D, _i: int, _p: Vector3, shirt: Color, title: String) -> void:
	_counter_top = CityProps.CAFE_COUNTER + Vector3(0.25, 0.04, 0)
	_standing(parent, Vector3(CityProps.CAFE_COUNTER.x - 0.2, 0, CityProps.CAFE_COUNTER.z + 0.5), 0.0, shirt)
	Blocks.label(parent, title, CityProps.CAFE_COUNTER + Vector3(0, 1.4, 0.3), 40)


## Anh Hùng: nằm dưới gầm xe máy dựng trước tiệm sửa xe, chân thò ra, tay thò ra phía đường.
func _build_hung(parent: Node3D, i: int, p: Vector3, shirt: Color, title: String) -> void:
	var moto := p + Vector3(-0.1, 0, -0.8)  # trên vỉa hè trước nửa tây tiệm, chừa lối đi giữa x 31,4..33,2
	# Thân xe đặt trên chân chống, gầm cao 0,32 m
	var body := Blocks.solid_box(parent, Vector3(1.6, 0.6, 0.42), moto + Vector3(0, 0.64, 0), Color("#C8412F"), Blocks.LAYER_PROP)
	body.name = "XeAnhHung"
	for wx in [-0.62, 0.62]:
		Blocks.box(parent, Vector3(0.42, 0.42, 0.1), moto + Vector3(wx, 0.21, 0), Color("#2B2622"))
	Blocks.box(parent, Vector3(0.06, 0.5, 0.06), moto + Vector3(0.75, 1.15, 0), Color("#5E6F6C"))
	# Người nằm ngửa dọc theo xe: thân dưới gầm, quần jean thò ra phía đông
	Blocks.box(parent, Vector3(0.7, 0.22, 0.4), moto + Vector3(-0.1, 0.11, 0), shirt)
	Blocks.box(parent, Vector3(0.95, 0.18, 0.34), moto + Vector3(0.95, 0.09, 0), Color("#3D5A80"))
	Blocks.box(parent, Vector3(0.16, 0.12, 0.3), moto + Vector3(1.48, 0.1, 0), Color("#2B2622"))  # dép
	_hand_hung = moto + Vector3(-0.15, 0.1, 0.32)
	_arms.append({"order": i, "pos": _hand_hung, "yaw": 0.0, "color": shirt, "lying": true})
	Blocks.label(parent, title, moto + Vector3(0, 1.8, 0), 40)
	# Vũng dầu trước tiệm, chừa lối vào ở giữa
	for o in [{"off": Vector3(-1.6, 0, 0.5), "r": 0.55}, {"off": Vector3(1.5, 0, 0.6), "r": 0.6}, {"off": Vector3(0.1, 0, 1.7), "r": 0.5}]:
		var c := CylinderMesh.new()
		c.top_radius = o.r
		c.bottom_radius = o.r
		c.height = 0.02
		c.radial_segments = 16
		c.rings = 1
		var m := Blocks.mesh(parent, c, p + o.off + Vector3(0, 0.055, 0), OIL)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_oils.append({"pos": p + o.off, "r": o.r, "inside": false})


## Bà Sáu: ngồi ghế mây dưới giàn bông giấy cuối hẻm 42 (ghế, giàn do CityProps dựng), quay về phía hẻm.
func _build_sau(parent: Node3D, i: int, p: Vector3, shirt: Color, title: String) -> void:
	var pos := Vector3(p.x, 0.06, 22.7)  # đúng ghế mây CityProps, mặt ghế cao hơn ghế nhựa 6 cm
	_seated(parent, pos, 0.0, shirt)
	_arms.append({"order": i, "pos": pos + Vector3(0.2, 1.05, -0.05), "yaw": 0.0, "color": shirt})
	Blocks.label(parent, title, pos + Vector3(0, 3.0, 0), 40)


## Người ngồi ghế, quay mặt về -Z cục bộ (yaw xoay cả người). Có màu ghế thì dựng ghế bên dưới.
func _seated(parent: Node3D, pos: Vector3, yaw: float, shirt: Color, chair := Color.TRANSPARENT) -> void:
	var root := StaticBody3D.new()
	root.collision_layer = Blocks.LAYER_PROP
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	if chair.a > 0.0:
		Blocks.box(root, Vector3(0.48, 0.4, 0.44), Vector3(0, 0.2, 0.02), chair.darkened(0.15))   # chân ghế
		Blocks.box(root, Vector3(0.5, 0.05, 0.48), Vector3(0, 0.42, 0.02), chair)                # mặt ghế
		Blocks.box(root, Vector3(0.5, 0.55, 0.05), Vector3(0, 0.72, 0.26), chair)                # lưng ghế
	Blocks.box(root, Vector3(0.44, 0.15, 0.44), Vector3(0, 0.52, -0.12), PANTS)              # đùi
	Blocks.box(root, Vector3(0.4, 0.42, 0.14), Vector3(0, 0.23, -0.34), PANTS)               # cẳng chân
	Blocks.box(root, Vector3(0.48, 0.55, 0.3), Vector3(0, 0.86, 0.06), shirt)                # áo
	Blocks.box(root, Vector3(0.1, 0.45, 0.1), Vector3(-0.3, 0.86, 0.06), shirt)              # tay trái thả
	_head(root, Vector3(0, 1.3, 0.04))
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.55, 1.2, 0.7)
	shape.shape = bs
	shape.position = Vector3(0, 0.6, -0.05)
	root.add_child(shape)


## Người đứng (như khối người trong main.gd), quay mặt về -Z cục bộ.
func _standing(parent: Node3D, pos: Vector3, yaw: float, shirt: Color, height := 1.0) -> void:
	var root := StaticBody3D.new()
	root.collision_layer = Blocks.LAYER_PROP
	root.position = pos
	root.rotation.y = yaw
	root.scale = Vector3.ONE * height
	parent.add_child(root)
	Blocks.box(root, Vector3(0.45, 0.8, 0.3), Vector3(0, 0.4, 0), PANTS)
	Blocks.box(root, Vector3(0.5, 0.6, 0.32), Vector3(0, 1.1, 0), shirt)
	_head(root, Vector3(0, 1.58, 0))
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 1.6, 0.35)
	shape.shape = bs
	shape.position.y = 0.8
	root.add_child(shape)


func _head(parent: Node3D, pos: Vector3) -> void:
	var head := SphereMesh.new()
	head.radius = 0.17
	head.height = 0.34
	head.radial_segments = 10
	head.rings = 5
	Blocks.mesh(parent, head, pos, SKIN)


## Phần chuyển động, dựng khi node vào cây cảnh (sau merge_static nên không bị gộp).
func _ready() -> void:
	for a in _arms:
		var pivot := Node3D.new()
		pivot.position = a.pos
		pivot.rotation.y = a.yaw
		add_child(pivot)
		if a.get("lying", false):
			# Tay thò ra từ gầm xe, nằm sát đất, ngón tay dính dầu
			Blocks.box(pivot, Vector3(0.09, 0.08, 0.3), Vector3(0, 0, 0.15), a.color)
			Blocks.box(pivot, Vector3(0.11, 0.06, 0.1), Vector3(0, 0, 0.33), SKIN.darkened(0.45))
		else:
			Blocks.box(pivot, Vector3(0.1, 0.45, 0.1), Vector3(0, -0.22, 0), a.color)
			Blocks.box(pivot, Vector3(0.1, 0.1, 0.1), Vector3(0, -0.48, 0), SKIN)
		_arm_nodes[a.order] = pivot

	if _tu_paper_pos != Vector3.ZERO:
		_tu_paper = Node3D.new()
		_tu_paper.position = _tu_paper_pos
		add_child(_tu_paper)
		_newspaper(_tu_paper, Vector3(0, 0, 0), 1.4).rotation.x = -PI / 2  # dựng đứng che mặt

	if _anchor != Vector3.ZERO:
		_pivot = Node3D.new()
		_pivot.position = _anchor
		add_child(_pivot)
		_rope = Blocks.box(_pivot, Vector3(0.015, 1.0, 0.015), Vector3.ZERO, Color("#F2E3B8"))
		_basket = Node3D.new()
		_pivot.add_child(_basket)
		var c := BASKET
		Blocks.box(_basket, Vector3(0.34, 0.03, 0.28), Vector3(0, 0.015, 0), c)            # đáy
		Blocks.box(_basket, Vector3(0.34, 0.22, 0.03), Vector3(0, 0.11, 0.125), c)         # thành
		Blocks.box(_basket, Vector3(0.34, 0.22, 0.03), Vector3(0, 0.11, -0.125), c)
		Blocks.box(_basket, Vector3(0.03, 0.22, 0.28), Vector3(0.155, 0.11, 0), c)
		Blocks.box(_basket, Vector3(0.03, 0.22, 0.28), Vector3(-0.155, 0.11, 0), c)
		Blocks.box(_basket, Vector3(0.02, 0.35, 0.02), Vector3(0, 0.37, 0), Color("#F2E3B8"))  # quai dây
		_basket_loaf = Node3D.new()
		_basket.add_child(_basket_loaf)
		Blocks.box(_basket_loaf, Vector3(0.26, 0.08, 0.1), Vector3(0, 0.12, 0), Color("#D98E2B"))
		_basket_loaf.visible = false
		_set_rope(0.0)

	for table: Node3D in get_tree().get_nodes_in_group("ban_ca_phe"):
		# Mặt bàn CityProps: tâm ở 0,43 m, dày 4 cm, rộng 0,7 m
		var tp := table.global_position
		_tables.append({"pos": Vector3(tp.x, 0, tp.z), "size": Vector3(0.7, tp.y + 0.02, 0.7), "touching": false})
	for t in _tables.size():
		var tb: Dictionary = _tables[t]
		for g in 2:
			var node := Node3D.new()
			var base: Vector3 = tb.pos + Vector3(-0.12 + g * 0.24, tb.size.y, 0.05 - g * 0.1)
			node.position = base
			add_child(node)
			var cup := CylinderMesh.new()
			cup.top_radius = 0.04
			cup.bottom_radius = 0.032
			cup.height = 0.13
			cup.radial_segments = 8
			cup.rings = 1
			Blocks.mesh(node, cup, Vector3(0, 0.065, 0), COFFEE)
			Blocks.box(node, Vector3(0.05, 0.02, 0.05), Vector3(0, 0.12, 0), Color("#F2E3B8"))  # bọt sữa
			_glasses.append({"node": node, "table": t, "base": base, "wobble": 0.0, "fallen": false})

	if _counter_top != Vector3.ZERO:
		_milk = Node3D.new()
		_milk.position = _counter_top + Vector3(0, 0, 0.12)
		add_child(_milk)
		var bowl := CylinderMesh.new()
		bowl.top_radius = 0.06
		bowl.bottom_radius = 0.04
		bowl.height = 0.04
		bowl.radial_segments = 10
		bowl.rings = 1
		Blocks.mesh(_milk, bowl, Vector3(0, 0.02, 0), Color("#FFF8EA"))
		_milk.visible = false

	_prompt = Blocks.label(self, "", Vector3.ZERO, 28, Color("#F2C14E"))
	_prompt.no_depth_test = true  # không bị tường che
	_prompt.visible = false
	_speech = Blocks.label(self, "", Vector3.ZERO, 44, Color("#FFF8EA"))
	_speech.visible = false


func _newspaper(parent: Node3D, pos: Vector3, scale_k := 1.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.scale = Vector3.ONE * scale_k
	parent.add_child(n)
	Blocks.box(n, Vector3(0.24, 0.015, 0.17), Vector3.ZERO, PAPER)
	for k in 3:
		Blocks.box(n, Vector3(0.18, 0.004, 0.012), Vector3(0, 0.01, -0.05 + k * 0.04), INK)
	return n


## Gọi sau khi add_child: nối Bơ, Chó Mực, HUD.
func setup(p: CharacterBody3D, d: Node, h: CanvasLayer, is_autotest := false) -> void:
	player = p
	dog = d
	hud = h
	autotest = is_autotest
	if dog and dog.has_signal("bit_player"):
		dog.bit_player.connect(func(): _bites += 1)


# ---------------------------------------------------------------- vòng đơn

## Chỗ Bơ cần đứng để giao (cho autotest dịch chuyển tới).
func stand_point(i: int) -> Vector3:
	if _kind[i] == "basket":
		return _moto_na
	return orders[i].pos


## Tên nhiệm vụ phụ của đơn i.
func quest_title(i: int) -> String:
	return QUESTS.get(orders[i].get("side_quest", ""), "")


## Bơ vừa nhận bánh đơn i ở lò.
func on_pick_up(i: int) -> void:
	current = i
	_bites = 0
	match _kind[i]:
		"basket":
			_misses = 0
			_retry = 0.0
			_basket_done = false
			_basket_loaf.visible = false
		"counter":
			_glass_broken = false
			_milk.visible = false
			for g in _glasses:
				_reset_glass(g)
		"under_car":
			_oiled = false
	if _kind[i] == "chair" and _speech:
		_speech.visible = false


## Gọi mỗi nhịp vật lý khi đang mang bánh đơn i. Trả true khi khách đã nhận bánh.
func step(i: int, in_zone: bool, _delta: float) -> bool:
	var kind := _kind[i]
	var pressed := _pressed()
	var ready := in_zone
	var hint := "[E] Đưa bánh"
	match kind:
		"basket":
			var on_moto := _on_moto_na()
			ready = on_moto or in_zone
			hint = "[E] Bỏ bánh vào giỏ" if on_moto else "Nhảy lên xe máy"
			if autotest:
				pressed = on_moto and _basket_hittable()
			if pressed and ready:
				if not on_moto:
					_toast("Nhảy lên yên xe máy rồi bấm E lúc giỏ đưa tới!", 2.0)
				elif _retry > 0.0:
					pass
				elif _basket_hittable():
					_prompt.visible = false
					_deliver_basket()
					return true
				else:
					_misses += 1
					_retry = BASKET_RETRY
					_toast("Trật rồi! Đợi giỏ đưa lại...", 1.5)
		"counter":
			hint = "[E] Đặt bánh lên quầy"
		"under_car":
			hint = "[E] Đưa vào tay Anh Hùng"
	if autotest and kind != "basket":
		pressed = in_zone
	_prompt.visible = ready
	if ready:
		_prompt.text = hint
		_prompt.global_position = player.global_position + Vector3(0, 0.9, 0)
	if kind == "basket" or not (pressed and in_zone):
		return false
	_prompt.visible = false
	match kind:
		"hand":
			_deliver_tu(i)
		"counter":
			_deliver_may(i)
		"under_car":
			side_ok[i] = not _oiled
			_play_deliver(kind)
		"chair":
			_deliver_sau(i)
		_:
			_play_deliver(kind)
	current = -1
	return true


func _deliver_tu(i: int) -> void:
	_play_deliver("hand")
	side_ok[i] = false  # chỉ thành công khi tờ báo về tới lò
	_tu_paper.visible = false
	_paper_state = "carry"
	_mouth_paper = _newspaper(player.visual, Vector3(0, 0.2, -0.3), 0.9)
	_mouth_paper.rotation.x = -0.6
	_toast("Chú Tư gửi tờ báo cho Cô Ba. Về lò đừng chạy nhanh qua vũng nước nha!", 3.0, 1.8)


func _deliver_basket() -> void:
	var i := current
	_play_deliver("basket")
	side_ok[i] = _misses == 0
	_basket_done = true
	_basket_loaf.visible = true
	_sfx("basket_drop", _basket.global_position)
	if side_ok[i]:
		_toast("Trúng ngay nhịp đầu! Bé Na kéo giỏ lên.", 2.0, 1.8)
	current = -1


func _deliver_may(i: int) -> void:
	_play_deliver("counter")
	side_ok[i] = not _glass_broken
	# Chị Mây đẩy lại cho Bơ một chén sữa nhỏ (chỉ để xem)
	_milk.visible = true
	_milk.global_position = _counter_top + Vector3(0, 0, 0.12)
	var tw := create_tween()
	tw.tween_property(_milk, "global_position", _counter_top + Vector3(-0.15, 0, -0.18), 0.6).set_delay(0.4)
	_toast("Chị Mây đẩy cho Bơ chén sữa nhỏ.", 2.0, 1.8)


func _deliver_sau(i: int) -> void:
	_play_deliver("chair")
	side_ok[i] = not _dog_woke()
	var arm: Node3D = _arm_nodes.get(i)
	_speech.text = "\"Mực, đừng làm bé mèo sợ!\""
	_speech.global_position = (arm.global_position if arm else orders[i].pos) + Vector3(0, 0.8, 0)
	_speech.visible = true
	get_tree().create_timer(3.5).timeout.connect(func(): _speech.visible = false)
	_toast("Bà Sáu gọi với ra hẻm: \"Mực, đừng làm bé mèo sợ!\"", 3.0, 1.8)


# ---------------------------------------------------------------- mỗi nhịp

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	_update_arms(delta)
	_update_paper()
	_update_basket(delta)
	_update_glasses(delta)
	_update_oil(delta, hspeed)
	_e_prev = Input.is_physical_key_pressed(KEY_E)
	_hspeed_prev = hspeed


## Khách chìa tay khi Bơ mang bánh của họ tới gần, rút tay sau khi nhận.
func _update_arms(delta: float) -> void:
	for i in _arm_nodes:
		var arm: Node3D = _arm_nodes[i]
		var near: bool = current == i and player.carrying and player.global_position.distance_to(arm.global_position) < 3.0
		if _kind[i] == "under_car":
			# Tay vẫy vẫy dưới gầm xe
			var wave := sin(Time.get_ticks_msec() * 0.008) * 0.4 if near else 0.0
			arm.rotation.y = lerp_angle(arm.rotation.y, wave, 1.0 - exp(-10.0 * delta))
		else:
			arm.rotation.x = lerpf(arm.rotation.x, 1.35 if near else 0.0, 1.0 - exp(-8.0 * delta))
	# Chú Tư hạ tờ báo xuống khi Bơ tới
	if _tu_paper and _tu_paper.visible:
		var i0 := _kind.find("hand")
		var near0: bool = current == i0 and player.carrying and player.global_position.distance_to(_tu_paper.global_position) < 4.0
		_tu_paper.position.y = lerpf(_tu_paper.position.y, _tu_paper_pos.y - (0.4 if near0 else 0.0), 1.0 - exp(-6.0 * delta))


## Tờ báo Bơ ngậm: rơi khi chạy nhanh qua vũng nước, tới lò thì Cô Ba nhận.
func _update_paper() -> void:
	if _paper_state != "carry":
		return
	var i := _kind.find("hand")
	var pos := player.global_position
	var inside := false
	for pd in PUDDLES:
		if absf(pos.x - pd.pos.x) < pd.size.x / 2.0 and absf(pos.z - pd.pos.z) < pd.size.y / 2.0:
			inside = true
	if inside and not _in_puddle and player.is_on_floor() and _sprinting():
		_paper_state = "wet"
		_drop_mouth_paper()
		_sfx("splash", pos)
		_toast("Tõm! Tờ báo rơi xuống vũng nước, ướt mất rồi.", 2.5)
	_in_puddle = inside
	if _paper_state == "carry" and Vector2(pos.x - City.BAKERY_POINT.x, pos.z - City.BAKERY_POINT.z).length() < 2.0:
		_paper_state = "done"
		side_ok[i] = true
		_mouth_paper.queue_free()
		_mouth_paper = null
		_toast("Cô Ba nhận tờ báo của Chú Tư. Cảm ơn Bơ!", 2.0, 1.6)


func _drop_mouth_paper() -> void:
	if _mouth_paper == null:
		return
	var at := _mouth_paper.global_position
	_mouth_paper.get_parent().remove_child(_mouth_paper)
	add_child(_mouth_paper)
	_mouth_paper.global_position = Vector3(at.x, 0.04, at.z)
	_mouth_paper.rotation = Vector3(0, randf() * TAU, 0)
	_mouth_paper = null


## Giỏ thòng xuống khi đang giao đơn Bé Na, đung đưa, xong thì kéo lên.
func _update_basket(delta: float) -> void:
	if _pivot == null:
		return
	var i := _kind.find("basket")
	var want := 1.0 if current == i and player.carrying and not _basket_done else 0.0
	var before := _lower
	_lower = move_toward(_lower, want, delta / 1.6)
	if before == 0.0 and _lower > 0.0:
		_sfx("basket_lower", _anchor)
	_retry = maxf(_retry - delta, 0.0)
	_swing_t += delta
	_set_rope(_lower)
	if _lower <= 0.0 and _basket_done:
		_basket_loaf.visible = false  # Bé Na lấy bánh rồi


func _set_rope(k: float) -> void:
	var full := _anchor.y - BASKET_HANG_Y
	var length := lerpf(0.5, full, k)
	var amp := asin(clampf(BASKET_SWING / full, 0.0, 0.9)) * k
	# Trật thì giỏ bị giật lệch ra xa một chút
	_pivot.rotation.z = sin(_swing_t * TAU / BASKET_PERIOD) * amp + (0.06 if _retry > 0.0 else 0.0)
	_rope.scale.y = length
	_rope.position.y = -length / 2.0
	_basket.position.y = -length


func _basket_hittable() -> bool:
	if _lower < 0.95 or _retry > 0.0:
		return false
	var b := _basket.global_position
	var p := player.global_position
	return Vector2(b.x - p.x, b.z - p.z).length() < BASKET_REACH


func _on_moto_na() -> bool:
	var p := player.global_position
	return p.y > 0.75 and absf(p.x - _moto_na.x) < 0.85 and absf(p.z - _moto_na.z) < 0.35


## Bàn cà phê: đụng là ly rung, đụng mạnh hay đứng lên bàn là đổ một ly.
func _update_glasses(delta: float) -> void:
	var p := player.global_position
	for t in _tables.size():
		var tb: Dictionary = _tables[t]
		var half: Vector3 = tb.size / 2.0
		var dx := absf(p.x - tb.pos.x)
		var dz := absf(p.z - tb.pos.z)
		var touching: bool = dx < half.x + 0.3 and dz < half.z + 0.3 and p.y < tb.size.y + 0.4
		var on_top: bool = dx < half.x and dz < half.z and p.y > tb.size.y - 0.08 and p.y < tb.size.y + 0.4
		var crawling: bool = "stance" in player and player.stance == "crouch" and p.y < 0.2  # chui gầm bàn thì không đụng
		if touching and not tb.touching and not crawling:
			var hard: bool = on_top or _hspeed_prev > player.walk_speed + 0.6
			var knocked := false
			for g in _glasses:
				if g.table == t and not g.fallen:
					if hard and not knocked:
						_tip_glass(g)
						knocked = true
					else:
						g.wobble = 0.9
			_sfx("glass_tip" if knocked else "glass_rattle", tb.pos)
		tb.touching = touching
	for g in _glasses:
		if g.fallen:
			continue
		g.wobble = maxf(g.wobble - delta, 0.0)
		var n: Node3D = g.node
		var w: float = g.wobble
		n.rotation.z = sin(w * 40.0) * 0.18 * w
		n.rotation.x = cos(w * 33.0) * 0.12 * w


func _tip_glass(g: Dictionary) -> void:
	g.fallen = true
	var n: Node3D = g.node
	var away := (n.global_position - player.global_position)
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var tw := create_tween().set_parallel()
	tw.tween_property(n, "global_position", Vector3(n.global_position.x, 0.04, n.global_position.z) + away * 0.4, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_property(n, "rotation", Vector3(PI / 2, atan2(away.x, away.z), 0), 0.35)
	if current == _kind.find("counter") and player.carrying:
		_glass_broken = true
		_toast("Xoảng! Đổ một ly cà phê rồi.", 1.8)


func _reset_glass(g: Dictionary) -> void:
	var n: Node3D = g.node
	g.fallen = false
	g.wobble = 0.0
	n.position = g.base
	n.rotation = Vector3.ZERO


## Vũng dầu: chân dính dầu in dấu trên đường vài giây; chạy nhanh qua thì trượt.
func _update_oil(delta: float, hspeed: float) -> void:
	var p := player.global_position
	var on_floor := player.is_on_floor()
	for o in _oils:
		var inside: bool = on_floor and Vector2(p.x - o.pos.x, p.z - o.pos.z).length() < o.r
		if inside and not o.inside:
			_oil_feet = 5.0
			if current == _kind.find("under_car") and player.carrying and not _oiled:
				_oiled = true
				_toast("Ối, giẫm dầu rồi! Dấu chân in khắp đường.", 1.8)
			if _sprinting():
				_slip()
		o.inside = inside
	_oil_feet = maxf(_oil_feet - delta, 0.0)
	if _oil_feet > 0.0 and on_floor and hspeed > 0.5:
		_print_t -= delta
		if _print_t <= 0.0:
			_print_t = 0.22
			_paw_print(p, _oil_feet / 5.0)


func _slip() -> void:
	_sfx("oil_slip", player.global_position)
	if player.has_method("play_slip"):
		player.play_slip()
		return
	# Chưa có động tác trượt (gói 1): đẩy Bơ trượt tới trước theo đà
	var v := Vector3(player.velocity.x, 0, player.velocity.z)
	player.knockback(player.global_position - v.normalized(), 7.0)


func _paw_print(at: Vector3, strength: float) -> void:
	var side := Vector3(player.velocity.z, 0, -player.velocity.x).normalized() * 0.05 * _print_side
	_print_side = -_print_side
	var c := CylinderMesh.new()
	c.top_radius = 0.035
	c.bottom_radius = 0.035
	c.height = 0.005
	c.radial_segments = 8
	c.rings = 1
	var m := MeshInstance3D.new()
	m.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(OIL.r, OIL.g, OIL.b, 0.7 * strength + 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = Vector3(at.x, 0.07, at.z) + side
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 2.0).set_delay(6.0)
	tw.tween_callback(m.queue_free)


# ---------------------------------------------------------------- tiện ích

## Phím giao bánh: action "deliver" của gói 1 nếu đã có, chưa có thì đọc thẳng phím E.
func _pressed() -> bool:
	if InputMap.has_action("deliver"):
		return Input.is_action_just_pressed("deliver")
	return Input.is_physical_key_pressed(KEY_E) and not _e_prev


func _sprinting() -> bool:
	if "stance" in player:
		return player.stance == "sprint"
	return _hspeed_prev > player.walk_speed + 0.5


func _dog_woke() -> bool:
	if dog and "woke_up_this_order" in dog:
		return dog.woke_up_this_order
	return _bites > 0  # Chó Mực bản cũ thức suốt đơn 5: tạm tính là "thức" khi bị đớp


func _play_deliver(kind: String) -> void:
	if player.has_method("play_deliver"):
		player.play_deliver(kind)  # tiếng "deliver" do sound_director phát khi main ghi kết quả


func _sfx(sound_name: String, at: Vector3) -> void:
	var s := get_node_or_null("/root/Sound")
	if s == null:
		return
	if s.has_method("play_at"):
		s.play_at(sound_name, at)
	else:
		s.play(sound_name)


## Hiện thông báo trên HUD, có thể trễ một chút để không đè thông báo "Giao xong" của main.
func _toast(text: String, seconds := 2.0, delay := 0.0) -> void:
	if hud == null:
		return
	if delay <= 0.0:
		hud.show_toast(text, seconds)
	else:
		get_tree().create_timer(delay).timeout.connect(func(): hud.show_toast(text, seconds))
