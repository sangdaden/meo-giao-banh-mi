class_name GiongThat
extends RefCounted
## Giọng thật (ElevenLabs) cho những câu nghe nhiều nhất. GiongUO.noi() hỏi bảng này trước: người nói
## và câu thoại khớp đúng một dòng thì phát file ghi sẵn, không khớp thì vẫn nói bằng giọng ú ớ như cũ.
## Nghe thử, duyệt: trang "Giọng thật Mèo Giao Bánh Mì". Casting và nguồn: assets/audio/NGUON.md.
##
## Thêm câu: tạo giọng cùng casting, cắt lặng và cân độ to như tools/giong_that/chuyen_ogg.sh, chép vào
## assets/audio/giong/<mã>.ogg rồi thêm một dòng [người nói, câu đúng như trong code, mã] vào cuối CAU.

const DIR := "res://assets/audio/giong/"
const LEVEL_DB := -4.0       ## file đã cân -16 LUFS; cân với giọng ú ớ (GiongUO.LEVEL_DB) và nhạc
const MAX_DIST := 26.0

const CAU := [
	["Cô Ba", "Chào Bơ! Sáng nay có 5 đơn, giao lúc bánh còn giòn nha!", "coba_chao"],
	["Cô Ba", "Ngoan quá, Bơ của cô!", "coba_ngoan"],
	["Cô Ba", "Vô ca rồi Bơ! Bột cô ủ sẵn, qua bàn nhào nặn bánh nha.", "coba_vo_ca"],
	["Cô Ba", "Đẹp quá! Mang khay qua lò nướng nha.", "coba_khay"],
	["Cô Ba", "Bánh vàng giòn thơm phức! Đem lên bàn ráp nha.", "coba_banh_vang"],
	["Cô Ba", "Ổ thứ nhất ngon lành! Làm thêm ổ nữa nha.", "coba_o_mot"],
	["Cô Ba", "Xong 2 ổ rồi! Bơ giỏi quá, đi giao thôi!", "coba_xong"],
	["Cô Ba", "Ủa, mèo ở đâu mà ngoan dữ vậy nè?", "coba_ua"],
	["Cô Ba", "Quàng cái khăn này cho ấm cổ nghe con.", "coba_khan"],
	["Cô Ba", "Phụ cô giao bánh cho bà con trong xóm được hông?", "coba_phu"],
	["Cô Ba", "Sáng nay có năm đơn. Đi từ từ thôi, không ai hối đâu!", "coba_nam_don"],
	["Cô Ba", "Giỏi quá trời. Cả tuần cực rồi ha.", "coba_ca_tuan"],
	["Cô Ba", "Ngủ ngon nghe Bơ.", "coba_ngu_ngon"],
	["Chú Tư", "Ừm. Đúng giờ. Được lắm.", "chutu_dung_gio"],
	["Chú Tư", "Cảm ơn Bơ nha!", "chutu_cam_on"],
	["Bé Na", "Bánh còn nóng nè! Cảm ơn Bơ!", "bena_nong"],
	["Bé Na", "Cảm ơn Bơ nha!", "bena_cam_on"],
	["Chị Mây", "Cụng ly nè, nhân viên giỏi nhất phố!", "may_cung_ly"],
	["Chị Mây", "Cảm ơn Bơ nha!", "may_cam_on"],
	["Anh Hùng", "Đập tay cái coi! Ngon lành!", "hung_dap_tay"],
	["Anh Hùng", "Cảm ơn Bơ nha!", "hung_cam_on"],
	["Bà Sáu", "Con mèo ngoan của bà.", "basau_ngoan"],
	["Bà Sáu", "Mực, đừng làm bé mèo sợ!", "basau_muc"],
	["Bà Sáu", "Cảm ơn Bơ nha!", "basau_cam_on"],
	["Cô Hai", "Boa thêm nè, đừng nói Cô Ba nha!", "cohai_boa"],
	["Ông Bảy", "Ổ bánh này… nước đi hay.", "ongbay_nuoc_di"],
	["Ông Bảy", "Ê con mèo này!", "ongbay_e"],
	["Ông Bảy", "Suỵt!", "ongbay_suyt"],
	["Ông Bảy", "Chiếu tướng!", "ongbay_chieu"],
	["Ông Tám", "Quạt cho mát nè con.", "ongtam_quat"],
	["Ông Tám", "Đổ bàn cờ bây giờ!", "ongtam_do_ban"],
	["Ông Tám", "Suỵt!", "ongtam_suyt"],
	["Ông Tám", "Chiếu tướng!", "ongtam_chieu"],
]

static var _bang := {}     ## "người|câu đã chuẩn hóa" -> mã file
static var _dang := {}     ## người -> AudioStreamPlayer đang phát


## Câu đã chuẩn hóa để so: bỏ ngoặc kép, khoảng trắng thừa, "…" thành "...".
static func chuan(text: String) -> String:
	return text.replace("\"", "").replace("“", "").replace("”", "").replace("…", "...").strip_edges()


static func ma(who: String, text: String) -> String:
	if _bang.is_empty():
		for c: Array in CAU:
			_bang["%s|%s" % [c[0], chuan(c[1])]] = c[2]
	return _bang.get("%s|%s" % [who, chuan(text)], "")


## Phát giọng thật nếu có. Trả về true khi đã phát (hoặc người nói ở quá xa, im luôn cho khớp giọng ú ớ).
static func phat(mgr: Node, who: String, text: String, at: Node3D) -> bool:
	var id := ma(who, text)
	if id == "" or mgr == null:
		return false
	var path := DIR + id + ".ogg"
	if not ResourceLoader.exists(path):
		return false
	dung(who)
	var db := LEVEL_DB
	if at != null and is_instance_valid(at) and mgr.is_inside_tree():
		var cam := mgr.get_viewport().get_camera_3d()
		var d := cam.global_position.distance_to(at.global_position) if cam else 0.0
		if d > MAX_DIST:
			return true
		db += -20.0 * log(maxf(d, 4.0) / 4.0) / log(10.0)
	var p := AudioStreamPlayer.new()
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	p.stream = load(path)
	p.volume_db = db
	p.finished.connect(func():
		if _dang.get(who) == p:
			_dang.erase(who)
		p.queue_free())
	_dang[who] = p
	if mgr.is_inside_tree():
		mgr.add_child(p)
		p.play()
	else:
		mgr.add_child.call_deferred(p)
		p.play.call_deferred()
	return true


static func dung(who: String) -> void:
	var p = _dang.get(who)
	_dang.erase(who)
	if p != null and is_instance_valid(p):
		p.stop()
		p.queue_free()


static func dang_noi(who := "") -> bool:
	for k in _dang.keys():
		if not is_instance_valid(_dang[k]):
			_dang.erase(k)
	return not _dang.is_empty() if who == "" else _dang.has(who)
