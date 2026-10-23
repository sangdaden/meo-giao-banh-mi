extends Node3D
## Người dân ngoài 5 khách Thứ Hai: Cô Ba ở quầy lò bánh và mấy hàng xóm cho phố đông vui.
## Cô Ba: chào đầu ca, đưa phiếu khi Bơ nhận bánh, khen khi Bơ quay về, tổng kết cuối ngày.
## Thêm vào main SAU Blocks.merge_static (người có xương không gộp được).
## Ghế đẩu nhựa P4 và bàn đá góc cờ (DoThem, gói G1).

## Hàng xóm đứng/ngồi quanh phố (Thứ Hai chỉ để nhìn, chưa có đơn).
## seat: dựng ghế nhựa thấp dưới người ngồi; table: bàn cờ giữa hai ông.
const AMBIENT := [
	# Cô Hai trước tiệm tạp hóa khối 2, vỉa hè đường lớn, nhìn ra đường
	{"id": "cohai", "pos": Vector3(8.6, 0.04, -6.35), "yaw": 0.0, "idle": "viec_rieng"},
	# Chú Năm xe ôm ngồi chờ khách ở góc công viên, đầu hẻm 42
	{"id": "chunam", "pos": Vector3(-22.9, 0.04, 6.4), "yaw": deg_to_rad(-30.0), "idle": "viec_rieng", "seat": true},
	# Ông Bảy, Ông Tám đánh cờ ở góc công viên: ngày nào cũng do chess_corner.gd dựng (bàn đá, ghế đá, người xem)
]
## Tên khách trong days.gd -> id người dân, để không dựng hai lần người đang là khách của ngày.
const WHO_ID := {"Chú Tư": "chutu", "Bé Na": "bena", "Chị Mây": "may", "Anh Hùng": "hung", "Bà Sáu": "basau",
	"Chú Năm": "chunam", "Cô Hai": "cohai", "Ông Bảy, Ông Tám": "ongbay,ongtam"}


var coba: Nguoi
var people: Array[Nguoi] = []
var _bubble: Label3D
var _bubble_until := 0.0
var _player: Node3D
var _praise := ""
var _busy_ids: Array[String] = []  ## người đang là khách hôm nay (deliveries.gd dựng)


## Gọi trước add_child: bỏ hàng xóm đang là khách trong danh sách đơn của ngày.
func set_orders(orders: Array) -> void:
	for o in orders:
		for id in String(WHO_ID.get(o.who, "")).split(",", false):
			_busy_ids.append(id)


func _ready() -> void:
	# Cô Ba đứng sau tủ bánh, cách mặt tiền lò gần nửa mét, nhìn ra đường (hướng nam, +Z);
	# ngày mưa cùng xe vào trong gian hàng lò (XeCoBa.coba_pos)
	coba = Nguoi.make("coba", "viec_rieng")
	coba.position = XeCoBa.coba_pos()
	add_child(coba)
	coba.add_collision(Vector3(0.5, 1.6, 0.35), Vector3(0, 0.8, 0))
	people.append(coba)
	for a in AMBIENT:
		if a.id in _busy_ids:
			continue
		var n := Nguoi.make(a.id, a.idle)
		n.position = a.pos
		n.rotation.y = a.yaw
		add_child(n)
		people.append(n)
		if a.get("seat", false):
			var h: float = Nguoi.SEAT[a.id]
			# Ghế đặt lùi sau gốc người một chút (mông ngồi sau trục chân)
			var back := Vector3(0, 0, -0.08).rotated(Vector3.UP, a.yaw)
			DoThem.stool(self, a.pos + back, h, a.yaw)
			n.add_collision(Vector3(0.5, 1.1, 0.6), Vector3(0, 0.55, 0.1))
		else:
			n.add_collision(Vector3(0.5, 1.6, 0.35), Vector3(0, 0.8, 0))
		if a.has("table"):
			var t: Vector3 = a.table
			DoThem.solid(self, "../goc_co/ban_da", Vector3(0.5, 0.42, 0.5), t + Vector3(0, 0.21, 0), 0.0, Vector3(0.7, 0.875, 0.7))
			PhoModels.put(self, "../goc_co/ban_co_go", t + Vector3(0, 0.42, 0), PI / 2.0, Vector3(0.6, 1, 0.6))  # bàn cờ gỗ
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 40
	_bubble.pixel_size = 0.004
	_bubble.outline_size = 12
	_bubble.modulate = Color("#FFF8EA")
	_bubble.outline_modulate = Color("#3D2A1E")
	_bubble.width = 520
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.position = coba.position + Vector3(0, 2.05, 0)
	_bubble.visible = false
	add_child(_bubble)


## Gắn Bơ để mọi người quay đầu nhìn theo.
func setup(player: Node3D) -> void:
	_player = player
	for n in people:
		n.look_target = player


func _process(_delta: float) -> void:
	if _bubble.visible and Time.get_ticks_msec() / 1000.0 > _bubble_until:
		_bubble.visible = false


## Cô Ba nói một câu: bong bóng chữ trên đầu + động tác (mặc định "noi").
func say(text: String, seconds := 3.0, anim_name := "noi") -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_until = Time.get_ticks_msec() / 1000.0 + seconds
	GiongUO.noi("Cô Ba", text, coba)
	if anim_name == "nhan_banh":
		coba.play_once(anim_name)
	else:
		coba.play_for(anim_name, seconds)


## Đầu ca: Cô Ba vẫy chào, nói số đơn hôm nay.
func greet_shift(orders: int) -> void:
	say("Chào Bơ! Sáng nay có %d đơn, giao lúc bánh còn giòn nha!" % orders, 3.5, "vay")


## Bơ tới quầy nhận bánh: Cô Ba chìa phiếu (tay đưa ra), dặn chỗ giao.
## Đơn lấy hàng (errand) nhận ở chỗ khách, không phải ở quầy, nên Cô Ba không nói.
func hand_ticket(order: Dictionary, index: int) -> void:
	if order.get("kind", "") == "errand":
		return
	var line := "Đơn %d: %s cho %s, %s." % [index + 1, order.item, order.who, order.place]
	if _praise != "":
		line = _praise + " " + line
		_praise = ""
	if order.get("boss", false):
		line += " Hẻm 42 có Chó Mực, đi rón rén!"
	_bubble.text = line
	_bubble.visible = true
	_bubble_until = Time.get_ticks_msec() / 1000.0 + 3.0
	GiongUO.noi("Cô Ba", line, coba)
	coba.play_for("cho_banh", 1.0)
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(coba):
			coba.play_for("noi", 2.0))


## Giao xong một đơn: Cô Ba nhắc lại lúc Bơ về lò nhận đơn sau.
func order_done(stars: int, late: bool) -> void:
	if late:
		_praise = "Lần trước hơi trễ, lần này nhanh nha!"
	elif stars >= 3:
		_praise = "Giỏi quá Bơ ơi!"
	else:
		_praise = "Được lắm!"


## Hết ca: tổng kết sao và tiền boa.
func day_summary(stars: int, max_stars: int, tip_text: String) -> void:
	var line := "Xong ca rồi! %d/%d sao, được boa %s." % [stars, max_stars, tip_text]
	line += " Mai lại nha Bơ!" if stars * 2 >= max_stars else " Mai mình làm lại nha!"
	say(line, 6.0, "vui")
