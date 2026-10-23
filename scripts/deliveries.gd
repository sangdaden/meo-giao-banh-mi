extends Node3D
## Năm cách giao bánh của Thứ Hai và nhiệm vụ phụ của từng đơn (gói 4, trang thiết kế màn mục 04).
## - hand: Chú Tư ngồi ghế nhựa đọc báo, hạ báo xuống, chìa tay nhận. Phụ: ngậm tờ báo về cho Cô Ba,
##   báo rơi nếu chạy nhanh qua vũng nước (đi về lò không tính giờ).
## - basket: Bé Na thòng giỏ nhựa từ ban công. Thong thả (mặc định, Sang 21/10 không muốn phải nhảy lên xe):
##   Bơ đứng dưới ban công bấm E kêu "meo", Bé Na thả giỏ xuống sát đất cạnh xe máy, Bơ bỏ bánh vào,
##   Bé Na kéo lên. Chế độ thử thách giữ kiểu cũ: giỏ đung đưa, đứng trên xe máy bấm E lúc giỏ đưa tới.
##   Trật thì đợi nhịp sau 1,5 s. Phụ: trúng ngay nhịp đầu.
## - counter: đặt túi lên quầy Cà phê Mây, Chị Mây đẩy lại chén sữa. Phụ: không đổ ly cà phê nào
##   (đụng bàn là ly rung, đụng mạnh hoặc nhảy lên bàn là đổ).
## - under_car: Anh Hùng nằm dưới gầm xe máy, thò tay ra. Chạy nhanh qua vũng dầu là trượt.
##   Phụ: không giẫm vũng dầu nào (giẫm là in dấu chân dầu).
## - chair: Bà Sáu ngồi ghế mây dưới giàn bông giấy, nhận bánh rồi gọi "Mực, đừng làm bé mèo sợ".
##   Phụ: qua hẻm mà Chó Mực không hề thức.
## - beside_tea (Thứ Ba): rón rén tới góc cờ, đặt túi cạnh ấm trà của Ông Bảy và Ông Tám
##   (scripts/chess_corner.gd). Phụ: đặt đúng lúc chiếu tướng. Bị mắng thì đơn mất 1 sao.
## Thứ Ba (gói T3-6 và phần giao của đơn 4, 5; trang thiết kế màn mục 13):
## - on_seat: Chú Năm xe ôm ngồi trên xe máy ở đầu hẻm 42. Bơ nhảy lên yên sau, bấm E đưa bánh.
##   Hết giờ thì chú chở khách đi mất, một lúc sau mới quay lại nhận (trễ, 1 sao).
##   Phụ: giao khi đồng hồ còn ít nhất một nửa (trước khi khách xe ôm tới). Mực ngủ cạnh xe cho vui.
## - Đơn có khóa "basket_period" thì giỏ đưa theo nhịp đó (Bé Na Thứ Ba nhanh hơn).
## - Nhiệm vụ phụ theo chợ sáng (market.gd, nhóm "cho_sang"): "khong_dung_nguoi" (không đụng người
##   đi chợ nào, đếm player.bumped("person")) và "khong_do_thung" (không làm đổ thúng nào,
##   đếm basket_spilled). Hai khóa này thay cho nhiệm vụ phụ mặc định của cách giao.
##
## Cách dùng trong main.gd:
##   build_static(self, orders) trước Blocks.merge_static (phần đứng yên được gộp lệnh vẽ),
##   add_child sau merge_static (phần chuyển động: giỏ, ly, tay, tờ báo...), rồi setup().
##   Mỗi nhịp vật lý lúc đang mang bánh: step(order_index, in_zone) trả true là đã giao xong.
##   Bố cục lấy theo CityProps (xe máy, ban công Bé Na, quầy và bàn cà phê, ghế mây Bà Sáu).
## Đồ giao bánh là model Sang duyệt 21/10 (assets/models/giao/*.glb, trang https://claude.ai/artifact/8TqKjyoKebvAqXgEUEU25X):
## ổ bánh gói giấy Bơ ngậm, giỏ, tờ báo, ly cà phê (và bản đổ), chén sữa. Người dân vẫn là khối tạm chờ duyệt tư thế.

## Tên nhiệm vụ phụ theo khóa "side_quest" của đơn (scripts/days.gd)
const QUESTS := {
	"bao_co_ba": "Ngậm tờ báo về cho Cô Ba",
	"gio_nhip_dau": "Bỏ bánh vào giỏ ngay nhịp đầu",
	"khong_do_ly": "Không làm đổ ly cà phê nào",
	"khong_dau": "Không giẫm vũng dầu nào",
	"muc_ngu_yen": "Qua hẻm mà Chó Mực không thức",
	"du_6_trung": "Về lò còn đủ 6 quả trứng",
	"dat_luc_chieu": "Đặt túi đúng lúc chiếu tướng",
	"kip_xe_om": "Giao trước khi khách xe ôm tới",
	"khong_dung_nguoi": "Không đụng người đi chợ nào",
	"khong_do_thung": "Không làm đổ thúng nào",
	"goi_mot_tieng": "Gọi đúng một tiếng là Chị Mây ra",
	"truoc_goi_hai": "Giao trước khi Anh Hùng gọi lần hai",
	"vao_tu_gian": "Vào sân giỗ từ giàn bông giấy",
}

const PAPER := Color("#E8E2D0")
## Tên khách trong days.gd -> id người dân (scripts/nguoi.gd) cho các đơn dùng _build_generic.
const WHO_ID := {"Chú Năm": "chunam", "Cô Hai": "cohai"}  # Cô Hai đơn ngược đứng trong tạp hóa (shop_tap_hoa.gd)
const WATER_TOP := Color("#8FB7C9")
const OIL_TOP := Color("#2B2724")

const MODELS := "res://assets/models/giao/%s.glb"
const SMALL_ITEM := 0.4          ## đồ nhỏ hơn chừng này (m) không đổ bóng, tắt khi xa
const SMALL_ITEM_VIEW := 18.0
## Điểm miệng Bơ trong toạ độ model bo.glb (mặt trước +Z), ổ bánh ngậm nằm ngang theo trục X
const MOUTH := Vector3(0, 0.368, 0.30)
const RELEASE_AT := 0.8          ## giây trong động tác giao thì Bơ nhả ổ bánh
const GIO_H := 0.66              ## giỏ kèm dây chụm cao bao nhiêu (gio_rong.glb)
const GLASS_WOBBLE := 0.5        ## ly rung bao lâu

## Vũng nước trên đường từ sạp báo về lò bánh (tờ báo rơi nếu chạy nhanh qua)
const PUDDLES := [
	{"pos": Vector3(-11.0, 0, -3.6), "size": Vector2(2.6, 1.6)},
	{"pos": Vector3(-20.5, 0, -3.2), "size": Vector2(2.2, 1.8)},
]

const BASKET_PERIOD := 3.0      ## giây cho một lượt đưa qua đưa lại
const BASKET_SWING := 0.6       ## giỏ lệch xa nhất bao nhiêu mét so với chỗ đứng trên xe
const BASKET_REACH := 0.42      ## giỏ cách Bơ dưới mức này thì bỏ bánh vào được
const BASKET_RETRY := 1.5       ## trật thì phải đợi
const BASKET_HANG_Y := 1.25     ## đáy giỏ khi thòng xuống hẳn (yên xe 0,9 m)
const GROUND_SIDE := 1.15       ## Thong thả: giỏ thả xuống đất cạnh xe máy, lệch về phía đông bao nhiêu
const GROUND_SWING := 0.08      ## Thong thả: giỏ sát đất chỉ lắc nhẹ
const GROUND_Y := 0.03          ## Thong thả: đáy giỏ cách mặt đất

const XE_OM_SEAT := 0.78        ## mặt yên xe ôm Chú Năm
const XE_OM_AWAY := 9.0         ## hết giờ thì Chú Năm chở khách đi bao lâu mới quay lại
const XE_OM_HALF := 0.5         ## nhiệm vụ phụ: giao khi đồng hồ còn ít nhất phần này
const XE_OM_ROAD_Z := 1.5       ## làn đường lớn Chú Năm chạy ra khi chở khách
const DOG_BY_XE_OM := Vector3(-1.4, 0, -0.6)  ## chỗ Mực nằm ngủ, tính từ xe ôm (trong miệng hẻm 42)

var orders: Array = []
var player: CharacterBody3D
var dog: Node
var hud: CanvasLayer
var autotest := false

var current := -1                ## đơn đang làm (main gán lúc nhận bánh)
var side_ok: Array[bool] = [false, false, false, false, false]
## Nhiệm vụ phụ của ngày khác: id -> Callable trả true khi đạt (Thứ Tư: scripts/thu_tu.gd đăng ký)
var extra_quests := {}
var _kind: Array[String] = []
## Đơn ngược ("kind": "errand", gói T3-3): tạp hóa Cô Hai, chỉ tạo khi trong ngày có đơn này
var shop: ShopTapHoa

# Vị trí từng phần, tính ở build_static để _ready dựng phần chuyển động
var _specs: Array = []           # người dân cần dựng: {"order", "id", "pos", "yaw", "idle", "col_size", "col_center"}
var _people := {}                # order -> Nguoi (người có xương, scripts/nguoi.gd)
var _hand_fallback := {}         # order -> vị trí bàn tay khi người chưa dựng
var _late := -1                  # đơn đang trễ giờ (khách sốt ruột)
var _chu_nam: Nguoi              # Chú Năm trên xe ôm (con của _xe_om)
var _prompt: Label3D
var _mouth: Node3D               # điểm miệng Bơ, bám theo xương đầu
var _scenes := {}                # tên model -> PackedScene
var _mat_solid: StandardMaterial3D
var _mat_glass: StandardMaterial3D
var _mat_wet: StandardMaterial3D
var _e_prev := false
var _hspeed_prev := 0.0

# Đơn 1: tờ báo
var _tu_paper: Node3D            # tờ báo trong tay Chú Tư (hạ xuống khi Bơ tới)
var _tu_paper_pos := Vector3.ZERO
var _mouth_paper: Node3D         # tờ báo Bơ ngậm
var _paper_state := ""           # "" | "handing" | "carry" | "wet" | "done"
var _in_puddle := false

# Đơn 2: giỏ
var _moto_na := Vector3.ZERO     # tâm yên xe máy dưới ban công
var _anchor := Vector3.ZERO      # móc dây trên ban công
var _ground := false             # Thong thả: kêu meo, giỏ thả xuống đất (không cần nhảy lên xe)
var _called := false             # Bơ đã kêu Bé Na thả giỏ chưa
var _hold := 0.0                 # giỏ đợi ổ bánh rơi vào rồi mới kéo lên
var _ground_spot := Vector3.ZERO # chỗ Bơ đứng đợi giỏ
var _pivot: Node3D
var _rope: MeshInstance3D
var _basket: Node3D
var _basket_empty: Node3D
var _basket_loaf: Node3D         # giỏ có bánh
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
var _milk_empty: Node3D

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

# Thứ Ba đơn 3: góc cờ tướng
var chess: ChessCorner
# Chú Năm xe ôm (Thứ Ba)
var _main: Node                  # main.gd: đọc time_left và late
var _xe_om_home := Vector3.ZERO  # chỗ đậu đầu hẻm 42
var _xe_om_color := Color.WHITE
var _xe_om_title := ""
var _xe_om: AnimatableBody3D     # xe + Chú Năm, chạy đi chở khách khi hết giờ
var _passenger: Nguoi            # Chị Thảo, khách xe ôm (chỉ hiện khi chú chở khách)
var _xe_om_state := ""           # "wait" | "away" (đang chở khách) | "back" (đang quay về)
var _xe_om_left := false         # đơn này chú đã chở khách đi một lần rồi (về thì đợi Bơ)
var _start_time := 0.0           # đồng hồ lúc nhận bánh

# Chợ sáng (Thứ Ba): đếm va người đi chợ và thúng đổ trong đơn hiện tại
var _market: Node
var _bumps := 0
var _spills := 0
var _basket_period := BASKET_PERIOD
## Thứ Sáu (scripts/thu_sau.gd): ngồi gọi, cầu nâng, bàn cỗ giỗ. ThuSau tự gán khi ngày đó chơi.
var thu_sau: ThuSau
## Thứ Năm (scripts/thu_nam.gd): tủ báo, cửa cuốn tiệm xe, gác lửng, cảnh chung cư. ThuNam tự gán.
var thu_nam: ThuNam


# ---------------------------------------------------------------- dựng cảnh

## Phần đứng yên: người dân, ghế, xe, quầy, bàn, vũng nước, vũng dầu. Gọi trước Blocks.merge_static.
func build_static(parent: Node3D, order_list: Array) -> void:
	orders = order_list
	for i in orders.size():
		var o: Dictionary = orders[i]
		# Đơn ngược mua trứng dùng tạp hóa ShopTapHoa; đơn ngược khác (nhang Thứ Sáu) theo khóa delivery
		var kind: String = "errand" if o.get("kind", "deliver") == "errand" and o.get("errand_item", "trung6") == "trung6" else o.get("delivery", "hand")
		_kind.append(kind)
		var p: Vector3 = o.pos
		var title := "%d. %s\n%s" % [i + 1, o.who, o.place]
		match kind:
			"hand":
				_build_tu(parent, i, p, o.color, title)
			"basket":
				_build_na(parent, i, p, o.color, title)
				_basket_period = float(o.get("basket_period", BASKET_PERIOD)) * float(DoKho.v("basket_period_mult", 1.0))
			"counter":
				_build_may(parent, i, p, o.color, title)
			"under_car":
				_build_hung(parent, i, p, o.color, title)
			"chair":
				_build_sau(parent, i, p, o.color, title)
			"errand":
				pass  # tiệm và Cô Hai do CityProps dựng (ô "tap_hoa"), phần chuyển động ở ShopTapHoa
			"beside_tea":
				if chess == null:
					ChessCorner.build_static(parent)
					chess = ChessCorner.new()
			"call", "lift", "gio_table":
				pass  # Thứ Sáu: khách và đồ do scripts/thu_sau.gd dựng
			"shelf", "shutter", "loft", "scene":
				pass  # Thứ Năm: khách và đồ do scripts/thu_nam.gd dựng
			"on_seat":
				# Xe và Chú Năm chạy đi được nên dựng trong _ready (không gộp lệnh vẽ)
				_xe_om_home = p
				_xe_om_color = o.color
				_xe_om_title = title
			_:
				_build_generic(parent, i, p, o.color, title)
	if chess == null:
		# Ngày không có đơn góc cờ thì hai ông vẫn ngồi đánh cờ ở công viên cho phố đông vui
		ChessCorner.build_static(parent)
		chess = ChessCorner.new()
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(WATER_TOP, 0.6)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	for k in PUDDLES.size():
		var pd: Dictionary = PUDDLES[k]
		_blob(parent, pd.pos + Vector3(0, 0.055, 0), pd.size / 2.0, water, k * 7)  # trên mặt vỉa hè 0,04 m


## Chú Tư: ngồi ghế nhựa xanh trên vỉa hè trước sạp báo, quay ra đường (hướng nam).
func _build_tu(parent: Node3D, i: int, p: Vector3, shirt: Color, title: String) -> void:
	var pos := p + Vector3(0, 0, -0.7)
	_chair(parent, pos, PI, Color("#3D7FC1"))
	_person(i, "chutu", pos, PI, "viec_rieng", true)
	_hand_fallback[i] = pos + Vector3(0.2, 0.75, 0.35)
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
	_ground = bool(DoKho.v("basket_ground", false))
	if _ground:
		_anchor.x += GROUND_SIDE  # giỏ xuống đất ngay cạnh xe, không rơi lên yên
		_anchor.z = CityProps.BE_NA_BIKE.z + 0.38  # ra ngoài mép sàn hành lang tầng dưới, dây không xuyên sàn
		_ground_spot = Vector3(_anchor.x, 0, _anchor.z + 0.45)
	_person(_i, "bena", CityProps.BE_NA_BALCONY + Vector3(0.45, 0.075, 0.1), PI, "viec_rieng", false)
	_hand_fallback[_i] = _anchor
	Blocks.label(parent, title, CityProps.BE_NA_BALCONY + Vector3(0, 2.0, 0.3), 40)


## Chị Mây: đứng sau quầy Cà phê Mây (CityProps.CAFE_COUNTER); ly cà phê đặt trên bàn nhựa thấp của quán.
func _build_may(parent: Node3D, _i: int, _p: Vector3, shirt: Color, title: String) -> void:
	_counter_top = CityProps.CAFE_COUNTER + Vector3(0.25, 0.04, 0)
	_person(_i, "may", Vector3(CityProps.CAFE_COUNTER.x - 0.2, 0, CityProps.CAFE_COUNTER.z + 0.5), 0.0, "viec_rieng", false)
	_hand_fallback[_i] = _counter_top
	Blocks.label(parent, title, CityProps.CAFE_COUNTER + Vector3(0, 1.4, 0.3), 40)


## Anh Hùng: nằm dưới gầm xe máy dựng trước tiệm sửa xe, chân thò ra, tay thò ra phía đường.
func _build_hung(parent: Node3D, i: int, p: Vector3, shirt: Color, title: String) -> void:
	var moto := p + Vector3(-0.1, 0, -0.8)  # trên vỉa hè trước nửa tây tiệm, chừa lối đi giữa x 31,4..33,2
	# Thân xe đặt trên chân chống, gầm cao 0,32 m
	var body := Blocks.collider(parent, Vector3(1.6, 0.6, 0.42), moto + Vector3(0, 0.64, 0), Blocks.LAYER_PROP)
	body.name = "XeAnhHung"
	PhoModels.put(body, "xe_may_do", Vector3(0, -0.64, 0))  # xe số đầu xe +X như khối cũ (tay lái ở x 0,75)
	# Anh Hùng ngồi ghế đẩu thấp ở đầu tây xe (phác thảo đã duyệt), mặt nhìn dọc thân xe, hơi xoay ra đường
	var seat := moto + Vector3(-1.15, 0, 0.12)
	var yaw := deg_to_rad(-110.0)  # hướng nhìn -Z cục bộ xoay về phía đông (đầu xe), hơi chếch ra đường
	_stool(parent, seat, yaw, 0.28)
	_person(i, "hung", seat, yaw, "viec_rieng", true)
	_hand_hung = seat + Vector3(0.35, 0.15, 0.3)
	_hand_fallback[i] = _hand_hung
	Blocks.label(parent, title, moto + Vector3(0, 1.8, 0), 40)
	# Vũng dầu trước tiệm, chừa lối vào ở giữa
	for o in [{"off": Vector3(-1.6, 0, 0.5), "r": 0.55}, {"off": Vector3(1.5, 0, 0.6), "r": 0.6}, {"off": Vector3(0.1, 0, 1.7), "r": 0.5}]:
		_blob(parent, p + o.off + Vector3(0, 0.055, 0), Vector2(o.r, o.r), _oil_mat(), int(o.r * 100.0))
		_oils.append({"pos": p + o.off, "r": o.r, "inside": false})


## Bà Sáu: ngồi ghế mây dưới giàn bông giấy cuối hẻm 42 (ghế, giàn do CityProps dựng), quay về phía hẻm.
func _build_sau(parent: Node3D, i: int, p: Vector3, shirt: Color, title: String) -> void:
	var pos := CityProps.BA_SAU_CHAIR + Vector3(0, 0.06, 0)  # đúng ghế mây CityProps, mặt ghế cao hơn ghế nhựa 6 cm
	_person(i, "basau", Vector3(pos.x, 0.08, pos.z), 0.0, "viec_rieng", true)  # mặt ghế mây CityProps cao 0,5 m
	_hand_fallback[i] = pos + Vector3(0.2, 0.75, -0.35)
	Blocks.label(parent, title, pos + Vector3(0, 3.0, 0), 40)


## Cách giao chưa có cảnh riêng (on_seat, errand... của Thứ Ba): người dân đứng/ngồi chờ, bấm E đưa.
## Các gói ngày sau thay bằng cảnh riêng của mình.
func _build_generic(parent: Node3D, i: int, p: Vector3, _shirt: Color, title: String) -> void:
	var id: String = WHO_ID.get(orders[i].who, "")
	var pos := p + Vector3(0, 0, -0.6)
	if id != "":
		if Nguoi.SEAT.has(id):
			_stool(parent, pos, PI, Nguoi.SEAT[id])
		_person(i, id, pos, PI, "viec_rieng", Nguoi.SEAT.has(id))
	_hand_fallback[i] = p + Vector3(0.2, 0.9, -0.45)
	Blocks.label(parent, title, p + Vector3(0, 2.2, -0.6), 40)


## Chú Năm xe ôm: xe máy đậu dọc vỉa hè đầu hẻm 42, đầu xe quay ra đường lớn (-Z), Chú Năm ngồi
## yên trước, đội nón bảo hiểm, chừa yên sau cho Bơ nhảy lên. Cả xe là AnimatableBody3D để chạy đi được.
func _build_xe_om() -> void:
	var i := _kind.find("on_seat")
	_xe_om = AnimatableBody3D.new()
	_xe_om.name = "XeOmChuNam"
	_xe_om.collision_layer = Blocks.LAYER_PROP
	_xe_om.sync_to_physics = false
	_xe_om.position = _xe_om_home
	add_child(_xe_om)
	var y := XE_OM_SEAT
	PhoModels.put(_xe_om, "xe_may_xanh", Vector3(0, 0, 0.05), PI / 2.0)  # model đầu xe +X: xoay cho đầu xe về -Z
	# Chú Năm (model người dân) tựa yên trước, quay mặt ra lề (+X), yên sau và baga ở bên phải chú
	_chu_nam = Nguoi.make("chunam", "cho_khach")
	_chu_nam.position = Vector3(0, 0, -0.18)
	_chu_nam.rotation.y = PI / 2
	_xe_om.add_child(_chu_nam)
	# Khách xe ôm: chỉ hiện khi chú chở khách đi
	# Chị Thảo ngồi yên sau quay mặt về đầu xe (-Z); khớp hông dáng ngoi_sau cao 0,95 m, cao hơn mặt yên ~9 cm
	var thao := Nguoi.make("khachxeom", "ngoi_sau")
	thao.position = Vector3(0, y + 0.09 - 0.95, 0.38)
	thao.rotation.y = PI
	_passenger = thao
	_xe_om.add_child(_passenger)
	_passenger.visible = false
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.42, y, 1.6)
	shape.shape = bs
	shape.position = Vector3(0, y / 2.0, 0)
	_xe_om.add_child(shape)
	var rider := CollisionShape3D.new()  # Chú Năm, chừa yên sau trống
	var rb := BoxShape3D.new()
	rb.size = Vector3(0.5, 1.1, 0.5)
	rider.shape = rb
	rider.position = Vector3(0, y + 0.55, -0.2)
	_xe_om.add_child(rider)
	Blocks.label(_xe_om, _xe_om_title, Vector3(0, 2.4, 0), 40)
	_xe_om_state = "wait"


## Ghế nhựa (chân, mặt ghế cao 0,45 m, lưng ghế), quay mặt về -Z cục bộ. Đứng yên nên gộp được.
func _chair(parent: Node3D, pos: Vector3, yaw: float, color: Color) -> void:
	var root := StaticBody3D.new()
	root.collision_layer = Blocks.LAYER_PROP
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	# Ghế dựa nhựa (G1): lưng model ở -Z, ghế này lưng ở +Z cục bộ nên xoay nửa vòng
	DoThem.put(root, "ghe_dua_nhua" if color.b >= color.r else "ghe_dua_nhua__do", Vector3(0, 0, 0.03), PI)


## Ghế đẩu nhựa thấp (mặt ghế cao h).
func _stool(parent: Node3D, pos: Vector3, yaw: float, h: float) -> void:
	DoThem.stool(parent, pos, h, yaw)


## Vũng loang hình mây (như ảnh renders/vung_top): tam giác quạt, bán kính lượn theo vài sóng sin.
func _blob(parent: Node3D, pos: Vector3, radius: Vector2, m: Material, seed_k: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var n := 28
	var ph := float(seed_k) * 1.7
	var pts: Array[Vector3] = []
	for k in n:
		var a := TAU * k / n
		var r := 1.0 + 0.16 * sin(3.0 * a + ph) + 0.08 * sin(5.0 * a + ph * 2.3)
		pts.append(Vector3(cos(a) * radius.x * r, 0, sin(a) * radius.y * r) / 1.1)
	for k in n:
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(pts[(k + 1) % n])
		st.add_vertex(pts[k])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Dầu nhớt: sẫm và bóng loáng.
func _oil_mat(alpha := 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(OIL_TOP, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic_specular = 0.9
	return m


## Dựng một model đồ giao bánh. Màu nằm ở màu đỉnh (COLOR_0) như đồ bếp; bản Compatibility (web)
## không tự đổi linear sang sRGB nên đổi tay như player.gd. glass: vỏ thủy tinh trong suốt.
func _model(model_name: String, parent: Node, pos := Vector3.ZERO, glass := false) -> Node3D:
	if not _scenes.has(model_name):
		_scenes[model_name] = load(MODELS % model_name)
	if _mat_solid == null:
		_mat_solid = StandardMaterial3D.new()
		_mat_solid.vertex_color_use_as_albedo = true
		_mat_solid.roughness = 0.8
		_mat_glass = StandardMaterial3D.new()
		_mat_glass.vertex_color_use_as_albedo = true
		_mat_glass.albedo_color = Color(1, 1, 1, 0.3)
		_mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_glass.roughness = 0.1
		_mat_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_wet = _mat_solid.duplicate()
		_mat_wet.albedo_color = Color(0.55, 0.58, 0.6)  # giấy ướt sẫm màu
	var n: Node3D = _scenes[model_name].instantiate()
	n.position = pos
	parent.add_child(n)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if RenderingServer.get_rendering_device() == null:
			_srgb(mi, model_name)
		mi.material_override = _mat_glass if glass else _mat_solid
		# Đồ nhỏ trên bàn (ly cà phê, chén sữa, tờ báo): 36 ly ở quán Mây từng ngốn ~54k tam giác ở góc ngã tư.
		# Không đổ bóng, tắt khi xa hơn 18 m (lúc đó ly chỉ còn vài điểm ảnh).
		var size := mi.get_aabb().size
		if maxf(size.x, maxf(size.y, size.z)) < SMALL_ITEM:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = SMALL_ITEM_VIEW
			mi.visibility_range_end_margin = 2.0
	return n


var _srgb_meshes := {}

func _srgb(mi: MeshInstance3D, key: String) -> void:
	if not _srgb_meshes.has(key):
		var src: ArrayMesh = mi.mesh
		# Dựng lại qua ImporterMesh để giữ LOD (add_surface_from_arrays bỏ mất LOD của file .glb)
		var im := ImporterMesh.new()
		for i in src.get_surface_count():
			var arrays := src.surface_get_arrays(i)
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for k in cols.size():
				cols[k] = cols[k].linear_to_srgb()
			arrays[Mesh.ARRAY_COLOR] = cols
			im.add_surface(src.surface_get_primitive_type(i), arrays)
		im.generate_lods(25, 60, [])
		_srgb_meshes[key] = im.get_mesh()
	mi.mesh = _srgb_meshes[key]


## Ghi lại một người dân cần dựng (dựng ở _ready, sau Blocks.merge_static vì mesh có xương không gộp được).
## yaw theo quy ước cũ của file này (mặt nhìn -Z cục bộ); model Nguoi nhìn +Z nên cộng PI.
## Người ngồi: pos là tâm mặt ghế, model dịch lên trước 7 cm để mông nằm giữa ghế.
func _person(i: int, id: String, pos: Vector3, yaw: float, idle: String, seated: bool) -> void:
	var fwd := Vector3(0, 0, -1).rotated(Vector3.UP, yaw)
	var spec := {"order": i, "id": id, "pos": pos + (fwd * 0.07 if seated else Vector3.ZERO), "yaw": yaw + PI, "idle": idle}
	if seated:
		spec.col_size = Vector3(0.5, 1.15, 0.65)
		spec.col_center = Vector3(0, 0.58, 0.08)
	else:
		spec.col_size = Vector3(0.5, 1.6, 0.35)
		spec.col_center = Vector3(0, 0.8, 0)
	_specs.append(spec)


## Bàn tay phải khách đơn i lúc nhận bánh (ổ bánh Bơ nhả ra bay tới đây).
func hand_point(i: int) -> Vector3:
	var n: Nguoi = _people.get(i)
	if n == null and i == _kind.find("on_seat"):
		n = _chu_nam
	if n and n.skeleton:
		var b := n.skeleton.find_bone("hand.R")
		var g := n.skeleton.global_transform * n.skeleton.get_bone_global_pose(b)
		return g * Vector3(0, 0.07, 0)  # giữa lòng bàn tay
	return _hand_fallback.get(i, orders[i].pos + Vector3(0, 0.9, 0))


## Khách đơn i (null nếu chưa dựng).
func person(i: int) -> Nguoi:
	return _people.get(i)


## Phần chuyển động, dựng khi node vào cây cảnh (sau merge_static nên không bị gộp).
func _ready() -> void:
	if chess:
		add_child(chess)
	for sp in _specs:
		var n := Nguoi.make(sp.id, sp.idle)
		n.position = sp.pos
		n.rotation.y = sp.yaw
		add_child(n)
		n.add_collision(sp.col_size, sp.col_center)
		_people[sp.order] = n

	if _tu_paper_pos != Vector3.ZERO:
		# Chú Tư cầm tờ báo mở (bao_mo, 60 x 42 cm) che mặt, mặt trước báo quay về phía đường
		_tu_paper = Node3D.new()
		_tu_paper.position = _tu_paper_pos + Vector3(0.05, -0.25, -0.02)
		_tu_paper_pos = _tu_paper.position
		add_child(_tu_paper)
		_model("bao_mo", _tu_paper)

	if _anchor != Vector3.ZERO:
		_pivot = Node3D.new()
		_pivot.position = _anchor
		add_child(_pivot)
		_rope = Blocks.box(_pivot, Vector3(0.015, 1.0, 0.015), Vector3.ZERO, Color("#F2E3B8"))
		_basket = Node3D.new()
		_pivot.add_child(_basket)
		# Giỏ nhựa kèm 4 dây chụm và đoạn dây 0,3 m (cao 0,66 m, gốc ở đáy); dây chính nối lên ban công
		_basket_empty = _model("gio_rong", _basket)
		_basket_loaf = _model("gio_co_banh", _basket)
		_basket_loaf.visible = false
		_set_rope(0.0)

	for table: Node3D in get_tree().get_nodes_in_group("ban_ca_phe"):
		# Mặt bàn CityProps: tâm ở 0,43 m, dày 4 cm, rộng 0,7 m
		var tp := table.global_position
		_tables.append({"pos": Vector3(tp.x, 0, tp.z), "size": Vector3(0.7, tp.y + 0.02, 0.7), "touching": false})
	for t in _tables.size():
		var tb: Dictionary = _tables[t]
		for g in 2:
			# Ly cà phê sữa đá: phần cà phê + vỏ thủy tinh trong; bản đổ (kèm vũng cà phê) nằm sẵn, ẩn
			var node := Node3D.new()
			var base: Vector3 = tb.pos + Vector3(-0.14 + g * 0.28, tb.size.y, 0.06 - g * 0.12)
			node.position = base
			node.rotation.y = g * 1.3
			add_child(node)
			_model("ly_caphe", node)
			_model("ly_caphe_vo", node, Vector3.ZERO, true)
			var spilt := Node3D.new()
			add_child(spilt)
			_model("ly_caphe_do", spilt)
			_model("ly_caphe_do_vo", spilt, Vector3.ZERO, true)
			spilt.visible = false
			_glasses.append({"node": node, "spilt": spilt, "table": t, "base": base, "wobble": 0.0, "fallen": false})

	if _counter_top != Vector3.ZERO:
		_milk = Node3D.new()
		_milk.position = _counter_top + Vector3(0, 0, 0.12)
		add_child(_milk)
		_model("chen_sua", _milk)
		_milk_empty = _model("chen_het", _milk)
		_milk_empty.visible = false
		_milk.visible = false

	if _xe_om_home != Vector3.ZERO:
		_build_xe_om()

	_prompt = Blocks.label(self, "", Vector3.ZERO, 28, Color("#F2C14E"))
	_prompt.no_depth_test = true  # không bị tường che
	_prompt.visible = false
	_speech = Blocks.label(self, "", Vector3.ZERO, 44, Color("#FFF8EA"))
	_speech.visible = false


## Gọi sau khi add_child: nối Bơ, Chó Mực, HUD.
func setup(p: CharacterBody3D, d: Node, h: CanvasLayer, is_autotest := false) -> void:
	player = p
	dog = d
	hud = h
	autotest = is_autotest
	_main = get_parent()
	for i in _people:
		_people[i].look_target = p
	if dog and dog.has_signal("bit_player"):
		dog.bit_player.connect(func(): _bites += 1)
	if player.has_signal("bumped"):
		player.bumped.connect(func(kind):
			if kind == "person" and _market == null:
				_bumps += 1  # chưa có chợ thì tự đếm; có chợ thì nghe person_bumped của chợ
		)
	if _xe_om and dog:
		# Thứ Ba không đơn nào qua hẻm 42: Mực ngủ say ở miệng hẻm cạnh xe ôm cho vui
		dog.position = _xe_om_home + DOG_BY_XE_OM
		dog.home = dog.position
	_mouth = _make_mouth()
	if chess:
		chess.setup(player, hud)
	if "errand" in _kind:
		shop = ShopTapHoa.new()
		add_child(shop)
		shop.setup(p, h, is_autotest)


## Điểm miệng Bơ: BoneAttachment3D theo xương "head" của bo.glb, lệch tới điểm MOUTH.
## Không tìm thấy xương (Bơ khối cũ) thì gắn thẳng vào hình Bơ ở trước mặt.
func _make_mouth() -> Node3D:
	var mouth := Node3D.new()
	mouth.name = "MiengBo"
	var skels: Array[Node] = player.visual.find_children("*", "Skeleton3D", true, false)
	var skel: Skeleton3D = skels[0] if skels.size() > 0 else null
	var idx: int = skel.find_bone("head") if skel else -1
	if idx < 0:
		player.visual.add_child(mouth)
		mouth.position = Vector3(0, 0.37, -0.3)
		mouth.rotation.y = PI
		return mouth
	# Gốc model bo.glb: tổ tiên của skeleton nằm ngay dưới thân Bơ
	var model: Node3D = skel
	while model.get_parent() and model.get_parent().get_parent() != player.visual:
		model = model.get_parent()
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	skel.add_child(att)
	att.add_child(mouth)
	var skel_from_model := skel.global_transform.affine_inverse() * model.global_transform
	mouth.transform = skel.get_bone_global_rest(idx).affine_inverse() * skel_from_model * Transform3D(Basis(), MOUTH)
	return mouth


## Bơ rút ổ bánh gói giấy ra ngậm, tới lúc nhả thì ổ bánh bay tới `to` (tay khách, giỏ, quầy) rồi gọi done.
## Player có tín hiệu bread_released (tự vẽ ổ bánh ngậm) thì đợi tín hiệu đó; chưa có thì tự gắn ổ bánh
## vào miệng và nhả sau RELEASE_AT giây.
func _hand_bread(to: Vector3, done := Callable()) -> void:
	var loaf: Node3D
	if player.has_signal("bread_released"):
		await player.bread_released
		loaf = _model("banh_goi", self)
		loaf.global_transform = _mouth.global_transform * Transform3D(Basis(), Vector3(0, -0.03, 0))
	else:
		loaf = _model("banh_goi", _mouth, Vector3(0, -0.03, 0))
		_body_layer(loaf)
		await get_tree().create_timer(RELEASE_AT).timeout
		if not is_instance_valid(loaf):
			return
		var at := loaf.global_transform
		loaf.get_parent().remove_child(loaf)
		add_child(loaf)
		loaf.global_transform = at
	var tw := create_tween()
	tw.tween_property(loaf, "global_position", to, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if done.is_valid():
			done.call()
	)
	tw.tween_interval(1.5)
	tw.tween_callback(loaf.queue_free)


## Đồ Bơ ngậm cũng ẩn ở góc nhìn thứ nhất như thân Bơ.
func _body_layer(n: Node3D) -> void:
	if not "LAYER_BO_BODY" in player:
		return
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.layers = player.LAYER_BO_BODY


# ---------------------------------------------------------------- vòng đơn

## Chỗ Bơ cần đứng để giao (cho autotest dịch chuyển tới).
func stand_point(i: int) -> Vector3:
	if thu_nam and _kind[i] in ThuNam.KINDS:
		return thu_nam.stand_point(i)
	if _kind[i] == "basket":
		return _ground_spot if _ground else _moto_na
	if _kind[i] == "on_seat":
		return _xe_om_home + Vector3(0, XE_OM_SEAT + 0.05, 0.45)
	return orders[i].pos


## Còn nhiệm vụ phụ đang làm dở sau khi giao (tờ báo Chú Tư đang ngậm về lò).
func side_pending() -> bool:
	return _paper_state in ["handing", "carry"]


## Đơn i bị trừ 1 sao vì lý do riêng của cách giao (góc cờ: hai ông mắng vì chạy nhanh, đụng bàn).
func star_lost(i: int) -> bool:
	return _kind[i] == "beside_tea" and chess != null and chess.scolded and bool(DoKho.v("chess_scold_star", true))


func is_errand(i: int) -> bool:
	return _kind[i] == "errand"


## Số trứng còn trong túi (đơn ngược), -1 nếu không phải đơn ngược.
func errand_eggs(i: int) -> int:
	return shop.eggs() if _kind[i] == "errand" else -1


## Tên nhiệm vụ phụ của đơn i.
func quest_title(i: int) -> String:
	return QUESTS.get(orders[i].get("side_quest", ""), "")


## Bơ vừa nhận bánh đơn i ở lò.
func on_pick_up(i: int) -> void:
	current = i
	_bites = 0
	_bumps = 0
	_spills = 0
	_xe_om_left = false
	_find_market()
	_start_time = float(_main.get("time_left")) if _main and _main.get("time_left") != null else 0.0
	match _kind[i]:
		"basket":
			_misses = 0
			_retry = 0.0
			_called = false
			_basket_done = false
			_basket_loaf.visible = false
			_basket_empty.visible = true
		"counter":
			_glass_broken = false
			_milk.visible = false
			for g in _glasses:
				_reset_glass(g)
		"under_car":
			_oiled = false
		"errand":
			shop.begin(i)
			side_ok[i] = true  # vỡ quả nào là trượt (ShopTapHoa)
		"beside_tea":
			chess.begin_order()
	if _kind[i] == "chair" and _speech:
		_speech.visible = false


## Gọi mỗi nhịp vật lý khi đang mang bánh đơn i. Trả true khi khách đã nhận bánh.
func step(i: int, in_zone: bool, _delta: float) -> bool:
	if thu_sau and _kind[i] in ThuSau.KINDS:
		return thu_sau.step(i, in_zone, _delta)
	if thu_nam and _kind[i] in ThuNam.KINDS:
		return thu_nam.step(i, in_zone, _delta)
	var kind := _kind[i]
	var pressed := _pressed()
	var ready := in_zone
	var hint := "[E] Đưa bánh"
	var mode := "ground" if kind == "basket" and _ground else kind
	match mode:
		"ground":
			var near := _flat_dist(player.global_position, _ground_spot) < 1.6
			ready = near or in_zone
			if not _called:
				hint = "[E] Kêu meo gọi Bé Na"
			elif _basket_hittable():
				hint = "[E] Bỏ bánh vào giỏ"
			else:
				hint = "Bé Na đang thả giỏ xuống..."
			if autotest:
				pressed = near and (not _called or _basket_hittable())
			if pressed and ready:
				if not _called:
					_call_na(i)
				elif _basket_hittable():
					_prompt.visible = false
					_deliver_basket(i)
					return true
				elif _flat_dist(player.global_position, _basket.global_position) > 1.0 and _lower >= 0.95:
					_toast("Lại gần giỏ hơn chút nữa!", 1.5)
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
					_deliver_basket(i)
					return true
				else:
					_misses += 1
					_retry = float(DoKho.v("basket_retry", BASKET_RETRY))
					_toast("Trật rồi! Đợi giỏ đưa lại...", 1.5)
		"counter":
			hint = "[E] Đặt bánh lên quầy"
		"under_car":
			hint = "[E] Đưa vào tay Anh Hùng"
		"beside_tea":
			hint = "[E] Đặt túi cạnh ấm trà"
		"on_seat":
			var on_seat := _on_xe_om()
			in_zone = on_seat and _xe_om_state == "wait"
			ready = in_zone or (_near_xe_om() and _xe_om_state == "wait")
			hint = "[E] Đưa bánh cho Chú Năm" if on_seat else "Nhảy lên yên sau xe ôm"
			if _xe_om_state != "wait" and pressed:
				_toast("Chú Năm chở khách đi rồi, đợi chú quay lại nha!", 2.0)
	if autotest and kind != "basket":
		pressed = in_zone
		if kind == "beside_tea":
			pressed = in_zone and chess.distracted  # autotest đợi chiếu tướng để thử nhiệm vụ phụ
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
			# Vũng dầu chỉ tính khi đơn có nhiệm vụ "khong_dau" (Thứ Ba đơn này có nhiệm vụ khác)
			side_ok[i] = not _oiled and orders[i].get("side_quest", "") == "khong_dau"
			_play_deliver(kind)
			_hand_bread(hand_point(i))
			_celebrate(i)
		"chair":
			_deliver_sau(i)
		"beside_tea":
			_play_deliver(kind)
			side_ok[i] = chess.deliver()
			_hand_bread(chess.bag_point(), chess.show_bag)
			if side_ok[i]:
				_toast("Đặt túi đúng lúc chiếu tướng, chẳng ai để ý!", 2.0, 1.8)
		"on_seat":
			_deliver_nam(i)
		_:
			_play_deliver(kind)
			_hand_bread(hand_point(i))
	_market_quest(i)
	current = -1
	return true


func _deliver_tu(i: int) -> void:
	_play_deliver("hand")
	_celebrate(i)
	if orders[i].get("side_quest", "") != "bao_co_ba":
		_hand_bread(hand_point(i))  # ngày khác Chú Tư chỉ nhận bánh, không gửi báo
		return
	side_ok[i] = false  # chỉ thành công khi tờ báo về tới lò
	_paper_state = "handing"  # Chú Tư đang gấp báo, chưa tới miệng Bơ
	_hand_bread(hand_point(i), func():
		# Nhận bánh xong Chú Tư gấp báo đưa cho Bơ ngậm về
		_tu_paper.visible = false
		_paper_state = "carry"
		_mouth_paper = _model("bao_gap", _mouth, Vector3(0, -0.02, 0.09))
		_mouth_paper.rotation.x = 0.12  # mép gấp trong miệng, tờ báo chúi nhẹ ra trước
		_body_layer(_mouth_paper)
	)
	_toast("Chú Tư gửi tờ báo cho Cô Ba. Về lò đừng chạy nhanh qua vũng nước nha!", 3.0, 1.8)


## Thong thả: Bơ kêu một tiếng, Bé Na ló ra lan can rồi thả giỏ xuống.
func _call_na(i: int) -> void:
	_called = true
	_play_deliver("hand")  # ngẩng đầu kêu lên ban công
	_sfx("meow", player.global_position)
	var na: Nguoi = _people.get(i)
	if na:
		na.play_for("keo_day", 2.0)
	_toast("Meo! Bé Na nghe rồi, đang thả giỏ xuống.", 2.0)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _deliver_basket(i: int) -> void:
	_play_deliver("basket")
	var na: Nguoi = _people.get(i)
	if na:
		na.play_for("keo_day", 1.6)  # kéo giỏ lên rồi mới vui
		get_tree().create_timer(1.6).timeout.connect(func(): na.play_for("vui", 2.5))
	side_ok[i] = _misses == 0
	_market_quest(i)
	_basket_done = true
	_hold = 2.0
	_hand_bread(_basket.global_position + Vector3(0, 0.08, 0), func():
		_basket_loaf.visible = true
		_basket_empty.visible = false
		_sfx("basket_drop", _basket.global_position)
	)
	if _ground:
		_toast("Bé Na kéo giỏ lên: \"Cảm ơn mèo nha!\"", 2.0, 1.8)
	elif side_ok[i]:
		_toast("Trúng ngay nhịp đầu! Bé Na kéo giỏ lên.", 2.0, 1.8)
	current = -1


func _deliver_may(i: int) -> void:
	_play_deliver("counter")
	_celebrate(i)
	side_ok[i] = not _glass_broken
	_hand_bread(_counter_top + Vector3(-0.3, 0, 0))
	# Chị Mây đẩy lại cho Bơ một chén sữa nhỏ (chỉ để xem), lát sau Bơ liếm sạch
	_milk.visible = true
	_milk_empty.visible = false
	_milk.get_child(0).visible = true
	_milk.global_position = _counter_top + Vector3(0, 0, 0.12)
	var tw := create_tween()
	tw.tween_property(_milk, "global_position", _counter_top + Vector3(-0.1, 0, -0.2), 0.6).set_delay(1.0)
	tw.tween_interval(3.0)
	tw.tween_callback(func():
		_milk.get_child(0).visible = false
		_milk_empty.visible = true
	)
	_toast("Chị Mây đẩy cho Bơ chén sữa nhỏ.", 2.0, 1.8)


func _deliver_sau(i: int) -> void:
	_play_deliver("chair")
	side_ok[i] = not _dog_woke()
	_hand_bread(hand_point(i))
	_celebrate(i, "goi_muc")  # nhận bánh rồi quay ra hẻm gọi Mực
	var sau: Nguoi = _people.get(i)
	_speech.text = "\"Mực, đừng làm bé mèo sợ!\""
	GiongUO.noi("Bà Sáu", _speech.text, sau)
	_speech.global_position = (sau.global_position + Vector3(0, 1.6, 0)) if sau else orders[i].pos + Vector3(0, 1.8, 0)
	_speech.visible = true
	get_tree().create_timer(3.5).timeout.connect(func(): _speech.visible = false)
	_toast("Bà Sáu gọi với ra hẻm: \"Mực, đừng làm bé mèo sợ!\"", 3.0, 1.8)


func _deliver_nam(i: int) -> void:
	_play_deliver("hand")
	var late: bool = _main != null and _main.get("late") == true
	var left: float = float(_main.get("time_left")) if _main and _main.get("time_left") != null else 0.0
	side_ok[i] = not late and _start_time > 0.0 and left >= _start_time * XE_OM_HALF
	_hand_bread(hand_point(i))
	_celebrate(i)
	if side_ok[i]:
		_toast("Kịp rồi! Chú Năm ăn xong mới có khách.", 2.0, 1.8)


## Nhiệm vụ phụ theo chợ sáng: thay kết quả mặc định của cách giao.
func _market_quest(i: int) -> void:
	match orders[i].get("side_quest", ""):
		"khong_dung_nguoi":
			side_ok[i] = _bumps == 0
		"khong_do_thung":
			side_ok[i] = _spills == 0
		_:
			# Nhiệm vụ phụ do màn ngày khác chấm (Thứ Tư: scripts/thu_tu.gd đăng ký)
			var judge: Callable = extra_quests.get(orders[i].get("side_quest", ""), Callable())
			if judge.is_valid():
				side_ok[i] = judge.call()


## Chợ sáng (market.gd của gói T3-4) chỉ có trong ngày họp chợ; tìm một lần rồi nghe tín hiệu.
func _find_market() -> void:
	if _market and is_instance_valid(_market):
		return
	_market = get_tree().get_first_node_in_group("cho_sang")
	if _market == null:
		return
	if _market.has_signal("person_bumped"):
		_market.connect("person_bumped", func(_pos): _bumps += 1)
	if _market.has_signal("basket_spilled"):
		_market.connect("basket_spilled", func(_pos): _spills += 1)


# ---------------------------------------------------------------- mỗi nhịp

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	_update_people(delta)
	_update_paper()
	_update_basket(delta)
	_update_glasses(delta)
	_update_oil(delta, hspeed)
	_update_xe_om()
	_e_prev = Input.is_physical_key_pressed(KEY_E)
	_hspeed_prev = hspeed


## Khách sống theo đơn: làm việc riêng khi rảnh; Bơ mang bánh của họ tới gần thì chìa tay chờ
## (Bé Na thả dây giỏ); đơn trễ giờ thì sốt ruột; nhận bánh xong thì vui rồi quay lại việc riêng.
func _update_people(delta: float) -> void:
	for i in _people:
		var n: Nguoi = _people[i]
		var now := n.current()
		if now in ["nhan_banh", "vui", "goi_muc"] or n.busy():
			continue
		var mine: bool = current == i and player.carrying
		var near: bool = mine and player.global_position.distance_to(n.global_position) < (6.0 if _kind[i] == "basket" else 3.5)
		if near:
			n.play("keo_day" if _kind[i] == "basket" else "cho_banh")
		elif mine and _late == i:
			n.play("sot_ruot")
		elif now != n.idle_anim:
			n.back_to_idle()
	# Chú Tư hạ tờ báo xuống khi Bơ tới
	if _tu_paper and _tu_paper.visible:
		var i0 := _kind.find("hand")
		var near0: bool = current == i0 and player.carrying and player.global_position.distance_to(_tu_paper.global_position) < 4.0
		_tu_paper.position.y = lerpf(_tu_paper.position.y, _tu_paper_pos.y - (0.4 if near0 else 0.0), 1.0 - exp(-6.0 * delta))


## Khách đơn i nhận bánh: động tác nhận theo phác thảo đã duyệt rồi vui một lúc.
func _celebrate(i: int, then_anim := "vui") -> void:
	var n: Nguoi = _people.get(i)
	if n:
		n.play_once("nhan_banh", then_anim, 2.5)
	elif _chu_nam and i == _kind.find("on_seat"):
		_chu_nam.play_once("nhan_xe")  # xoay sang baga nhận bánh, xong về chờ khách
	if _late == i:
		_late = -1


## main gọi khi đồng hồ đơn i về 0: khách sốt ruột chờ.
func on_late(i: int) -> void:
	_late = i


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
	_mouth_paper.global_position = Vector3(at.x, 0.06, at.z)
	_mouth_paper.rotation = Vector3(0, randf() * TAU, 0)
	_mouth_paper.scale = Vector3.ONE
	for mi: MeshInstance3D in _mouth_paper.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _mat_wet
		mi.layers = 1
	_mouth_paper = null


## Hết giờ mà Bơ chưa tới: Chú Năm đón khách chạy ra đường lớn, XE_OM_AWAY giây sau quay về đậu chỗ cũ.
func _update_xe_om() -> void:
	if _xe_om == null or _xe_om_state != "wait" or _xe_om_left:
		return
	var i := _kind.find("on_seat")
	if current != i or _main == null or _main.get("late") != true:
		return
	_xe_om_state = "away"
	_xe_om_left = true
	_passenger.visible = true
	_chu_nam.play("cho_di")
	_prompt.visible = false
	_sfx("moto_pass", _xe_om.global_position)
	var road := Vector3(_xe_om_home.x, 0, XE_OM_ROAD_Z)
	var far := road + Vector3(-28, 0, 0)
	var tw := create_tween()
	tw.tween_interval(0.8)  # khách leo lên yên sau
	tw.tween_property(_xe_om, "position", road, 1.0).set_ease(Tween.EASE_IN)
	tw.tween_property(_xe_om, "rotation:y", PI / 2.0, 0.3)
	tw.tween_property(_xe_om, "position", far, 2.0)
	tw.tween_callback(func():
		_xe_om.visible = false
		_passenger.visible = false
	)
	tw.tween_interval(float(DoKho.v("xe_om_away", XE_OM_AWAY)))
	tw.tween_callback(func():
		_xe_om_state = "back"
		_xe_om.visible = true
		_xe_om.rotation.y = -PI / 2.0
	)
	tw.tween_property(_xe_om, "position", road, 2.0)
	tw.tween_property(_xe_om, "rotation:y", 0.0, 0.3)
	tw.tween_property(_xe_om, "position", _xe_om_home, 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_xe_om_state = "wait"
		_chu_nam.play("cho_khach")
		if current == i:
			_toast("Chú Năm về rồi, đưa bánh đi!", 2.0)
	)
	_toast("Hết giờ, Chú Năm chở khách đi rồi! Đợi chú quay lại...", 2.5)


## Bơ đứng trên yên sau xe ôm (sau lưng Chú Năm).
func _on_xe_om() -> bool:
	if _xe_om == null:
		return false
	var local := _xe_om.global_transform.affine_inverse() * player.global_position
	return local.y > XE_OM_SEAT - 0.15 and absf(local.x) < 0.3 and local.z > 0.1 and local.z < 0.8


func _near_xe_om() -> bool:
	return _xe_om != null and player.global_position.distance_to(_xe_om.global_position) < 2.5


## Giỏ thòng xuống khi đang giao đơn Bé Na, đung đưa, xong thì kéo lên.
func _update_basket(delta: float) -> void:
	if _pivot == null:
		return
	var i := _kind.find("basket")
	_hold = maxf(_hold - delta, 0.0)
	var waiting: bool = current == i and player.carrying and not _basket_done and (_called or not _ground)
	var want := 1.0 if waiting or _hold > 0.0 else 0.0
	var before := _lower
	_lower = move_toward(_lower, want, delta / 1.6)
	if before == 0.0 and _lower > 0.0:
		_sfx("basket_lower", _anchor)
	_retry = maxf(_retry - delta, 0.0)
	_swing_t += delta
	_set_rope(_lower)
	if _lower <= 0.0 and _basket_done:
		_basket_loaf.visible = false  # Bé Na lấy bánh rồi
		_basket_empty.visible = true


func _set_rope(k: float) -> void:
	var full := _anchor.y - (GROUND_Y if _ground else BASKET_HANG_Y)
	var length := lerpf(0.5, full, k)
	var amp := asin(clampf((GROUND_SWING if _ground else BASKET_SWING) / full, 0.0, 0.9)) * k
	# Trật thì giỏ bị giật lệch ra xa một chút
	_pivot.rotation.z = sin(_swing_t * TAU / _basket_period) * amp + (0.06 if _retry > 0.0 else 0.0)
	# Dây chính từ lan can xuống tới nút dây của giỏ (giỏ cao GIO_H, gốc ở đáy)
	var rope := maxf(length - GIO_H, 0.05)
	_rope.scale.y = rope
	_rope.position.y = -rope / 2.0
	_basket.position.y = -length


func _basket_hittable() -> bool:
	if _lower < 0.95 or _retry > 0.0:
		return false
	var b := _basket.global_position
	var p := player.global_position
	var reach := float(DoKho.v("basket_reach", BASKET_REACH))
	if _ground:
		reach = maxf(reach, 1.0)  # giỏ nằm yên dưới đất, đứng gần là bỏ được
	return Vector2(b.x - p.x, b.z - p.z).length() < reach


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
						g.wobble = GLASS_WOBBLE
			_sfx("glass_tip" if knocked else "glass_rattle", tb.pos)
		tb.touching = touching
	for g in _glasses:
		if g.fallen:
			continue
		g.wobble = maxf(g.wobble - delta, 0.0)
		var n: Node3D = g.node
		# Lắc ±6° rồi tắt dần trong 0,5 s
		var w: float = g.wobble / GLASS_WOBBLE
		n.rotation.z = sin(w * 30.0) * deg_to_rad(6.0) * w
		n.rotation.x = cos(w * 24.0) * deg_to_rad(4.0) * w


func _tip_glass(g: Dictionary) -> void:
	g.fallen = true
	var n: Node3D = g.node
	var away := (n.global_position - player.global_position)
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	# Ly ngả ra rồi rơi xuống đất, chạm đất thì thay bằng ly đổ có vũng cà phê
	var spilt: Node3D = g.spilt
	var land := Vector3(n.global_position.x, 0.045, n.global_position.z) + away * 0.45
	var tw := create_tween().set_parallel()
	tw.tween_property(n, "global_position", land, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(n, "rotation", Vector3(PI / 2, atan2(away.x, away.z), 0), 0.3)
	tw.chain().tween_callback(func():
		n.visible = false
		spilt.global_position = land
		spilt.rotation.y = atan2(away.x, away.z)
		spilt.visible = true
	)
	if current == _kind.find("counter") and player.carrying:
		_glass_broken = true
		_toast("Xoảng! Đổ một ly cà phê rồi.", 1.8)


func _reset_glass(g: Dictionary) -> void:
	var n: Node3D = g.node
	g.fallen = false
	g.wobble = 0.0
	n.position = g.base
	n.rotation = Vector3.ZERO
	n.visible = true
	g.spilt.visible = false


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


var _paw_mesh: Mesh

## Dấu chân dầu (như ảnh renders/vung_top): đệm chân + 4 ngón, mờ dần rồi biến mất.
func _paw_print(at: Vector3, strength: float) -> void:
	var fwd := Vector3(player.velocity.x, 0, player.velocity.z).normalized()
	var side := Vector3(fwd.z, 0, -fwd.x) * 0.05 * _print_side
	_print_side = -_print_side
	if _paw_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		for d in [[Vector2(0, 0.012), 0.024], [Vector2(-0.027, -0.022), 0.01], [Vector2(-0.01, -0.033), 0.01],
				[Vector2(0.01, -0.033), 0.01], [Vector2(0.027, -0.022), 0.01]]:
			var c: Vector2 = d[0]
			var r: float = d[1]
			for k in 10:
				var a0 := TAU * k / 10.0
				var a1 := TAU * (k + 1) / 10.0
				st.add_vertex(Vector3(c.x, 0, c.y))
				st.add_vertex(Vector3(c.x + cos(a1) * r, 0, c.y + sin(a1) * r))
				st.add_vertex(Vector3(c.x + cos(a0) * r, 0, c.y + sin(a0) * r))
		_paw_mesh = st.commit()
	var m := MeshInstance3D.new()
	m.mesh = _paw_mesh
	var mat := _oil_mat(0.6 * strength + 0.3)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = Vector3(at.x, 0.07, at.z) + side
	m.rotation.y = atan2(-fwd.x, -fwd.z)  # ngón chân chỉ về hướng đi (-Z cục bộ)
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
