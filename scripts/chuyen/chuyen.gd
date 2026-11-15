class_name Chuyen
extends Node
## Chuyện tuần "Bí mật cho Cô Ba" (R2, mức S2: không rẽ nhánh, không chặn chơi, không mất sao).
## Dữ liệu câu ở scripts/chuyen/kich_ban.gd; node này diễn theo ngày đang chơi:
## - sau mỗi lần giao (đơn lấy đồ: lúc nhận đồ) hiện các câu của nhịp đó bằng phụ đề (scripts/chuyen/hud_chuyen.gd),
##   câu cảm ơn mới (O3) thì khoảnh khắc giao bánh đọc qua Chuyen.cau_giao();
## - đầu ngày: tít báo Chú Tư và góc "Còn N ngày ★" (O1), rồi câu Cô Ba suýt biết;
## - đơn cuối ngày: giữ bảng kết quả lại cho tới khi hết câu (bấm E, Enter hay Space để qua nhanh), qua main.hand_off;
## - cuối ngày: bưu thiếp (O2) cạnh bảng kết quả, kèm thiệp mừng đang có mấy chữ ký;
## - thư Hùng và Mây (L3): việc phụ tùy chọn, bấm E trong 4 giây để nhận, thư tới tay +2.000đ (lần đầu), không đụng sao.
## Thứ Bảy nghe theo Sổ hàng xóm (việc nhờ Cô Ba, Chị Thu ký thiệp, chương Mực); Chủ Nhật: scripts/chuyen/bat_ngo.gd.
## main.gd nạp node này qua khóa "nodes" của Thứ Hai (nạp cho mọi ngày); ngày không có trong kịch bản thì node tự gỡ.

const KB := preload("res://scripts/chuyen/kich_ban.gd")
const HudChuyenScript := preload("res://scripts/chuyen/hud_chuyen.gd")
const GROUP := "chuyen"

## Khóa lưu [chung]: các bước thư Hùng–Mây đã qua ("nhan1", "toi1", "nhan2", "toi2", "nhan3", "toi3")
const THU_KEY := "thu_hung_may"
const THU_BOA := 2000
const HOI_GIAY := 4.0
## Thiệp mừng mặt trong theo ngày (texture phác thảo đã duyệt)
const THIEP := {"thu_hai": "thiep_trong_3", "thu_ba": "thiep_trong_8", "thu_tu": "thiep_trong_8", "thu_nam": "thiep_trong_8",
	"thu_sau": "thiep_trong_8", "thu_bay": "thiep_trong_du", "chu_nhat": "thiep_trong_du"}
## Người ký thiệp ở Thứ Bảy khi giúp xong việc nhờ (ai khác đã ký từ Thứ Hai tới Thứ Sáu)
const CHUA_KY := {"chithu": "Chị Thu"}

var main: Node
var ui: Node                 ## HudChuyen
var day_id := ""
var data := {}
var autotest := false

var _queue: Array = []       ## câu chờ hiện
var _t := 0.0                ## giây còn lại của câu đang hiện
var _hoi := 0                ## đang hỏi nhận thư số mấy
var _hoi_t := 0.0
var _giu := false            ## đang giữ cuối ngày (hoặc buổi bất ngờ) chờ hết câu
var _xong := Callable()
var _buu_da := false
var _sang_t := -1.0
# Thứ Bảy
var _t7_t := 0.0
var _t7_done: Array = []
var _t7_viec := ""
var _t7_muc := false


func _init() -> void:
	name = "Chuyen"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	main = get_parent()
	if main == null or not "day" in main or not main.has_signal("order_delivered"):
		queue_free()
		return
	day_id = str(main.day.get("id", ""))
	data = ngay(day_id)
	if data.is_empty():
		queue_free()
		return
	add_to_group(GROUP)
	autotest = "--autotest" in OS.get_cmdline_user_args()
	_setup.call_deferred()


func _setup() -> void:
	if not is_instance_valid(main) or main.get("hud") == null:
		queue_free()
		return
	ui = HudChuyenScript.new()
	add_child(ui)
	add_child(DoChuyen.new())  # thư ở miệng Bơ, báo Chú Tư, bảng đồng (scripts/chuyen/do_chuyen.gd)
	main.order_delivered.connect(_on_delivered)
	main.order_picked_up.connect(_on_picked_up)
	var oi: int = int(main.get("order_index"))
	var orders: Array = main.get("orders")
	if oi > 0 and oi <= orders.size() and bool(orders[oi - 1].get("quick_assemble", false)):
		dien_nhip("ve_bep")  # vừa ráp nhanh trong bếp về
	elif oi == 0 or orders.is_empty():
		_sang_t = 0.1 if autotest else 5.2  # sau thẻ mở đầu ngày
	if day_id == "thu_bay":
		_t7_done = SoHangXom.done_ids().duplicate()
		_t7_muc = SoHangXom.muc_friend()


# ---------------------------------------------------------------- dữ liệu

static func ngay(id: String) -> Dictionary:
	return KB.NGAY.get(id, {})


## Câu cảm ơn mới (O3) cho khoảnh khắc giao bánh; không có thì trả mac_dinh (câu có sẵn theo tính cách).
static func cau_giao(id: String, index: int, mac_dinh: String) -> String:
	var lines: Array = ngay(id).get("nhip", {}).get(index, [])
	for l: Dictionary in lines:
		if l.k == "giao" and not l.get("co_san", false):
			return str(l.c)
	return mac_dinh


static func thu() -> Array:
	return GameState.get_global(THU_KEY, []) as Array


static func co_thu(n: int) -> bool:
	var s := thu()
	return ("nhan%d" % n) in s and not ("toi%d" % n) in s


static func da_thu(n: int) -> bool:
	return ("toi%d" % n) in thu()


static func _them_thu(buoc: String) -> bool:
	var s := thu().duplicate()
	if buoc in s:
		return false
	s.append(buoc)
	GameState.set_global(THU_KEY, s)
	return true


## Thư N tới tay người nhận: lần đầu +2.000đ vào ví. Thư 1 tới thì Mây gửi lại thư 2 trong túi.
static func thu_toi(n: int) -> bool:
	var moi := _them_thu("toi%d" % n)
	if n == 1:
		_them_thu("nhan2")
	if moi:
		GameState.set_global("vi_tien_boa", int(GameState.get_global("vi_tien_boa", 0)) + THU_BOA)
	GameState.write_save()
	return moi


static func nhan_thu(n: int) -> void:
	_them_thu("nhan%d" % n)
	GameState.write_save()


func _dk(l: Dictionary) -> bool:
	var dk := str(l.get("dk", ""))
	if dk == "":
		return true
	if dk == "lan":
		return co_lan()
	var p := dk.split(":")
	var n := int(p[1]) if p.size() > 1 else 0
	match p[0]:
		"co": return co_thu(n)
		"da": return da_thu(n)
	return true


## Chị Lan (con gái Chú Năm) đã có model trong game chưa.
static func co_lan() -> bool:
	return ResourceLoader.exists("res://assets/models/nguoi/chilan.glb")


# ---------------------------------------------------------------- nhịp trong ngày

func _last_index() -> int:
	return PlayMode.last_order((main.get("orders") as Array).size())


func _nhip(key: Variant) -> Array:
	return data.get("nhip", {}).get(key, [])


func _on_picked_up(index: int, order: Dictionary) -> void:
	if str(order.get("kind", "")) == "errand":
		_xep(_nhip(index), false)  # đơn lấy đồ: câu nói lúc nhận đồ ở chỗ khách


func _on_delivered(index: int, order: Dictionary) -> void:
	var cuoi := index >= _last_index()
	var lines: Array = []
	if str(order.get("kind", "")) != "errand":
		lines = _nhip("cuoi") if cuoi and data.get("nhip", {}).has("cuoi") else _nhip(index)
	if cuoi:
		lines = lines + _nhip("phim")
	var kk := get_tree().get_first_node_in_group("khoanh_khac_giao")
	var bo_giao: bool = kk != null and kk.has_method("sap_dien") and kk.sap_dien()
	_xep(lines, bo_giao)
	if cuoi and not _queue.is_empty() and main.get("_after_orders") == null and main.has_method("hand_off") and int(main.get("state")) == int(main.State.PLAY):
		main.hand_off(self)  # main gọi begin_after_orders() thay cho bảng kết quả


## main.gd: hết đơn, đang giữ bảng kết quả cho tới khi hết câu.
func begin_after_orders() -> void:
	_giu = true
	_xong = func() -> void:
		main.set("_after_orders", null)
		main.call("_end_game")
	main.player.can_move = false
	if _queue.is_empty() and _t <= 0.0:
		_ket_thuc()


## Diễn một nhịp có tên (buổi bất ngờ, về bếp...). xong: gọi khi hết câu (giữ màn chờ tới lúc đó).
func dien_nhip(key: String, xong := Callable()) -> void:
	_xep(_nhip(key), false)
	if xong.is_valid():
		_giu = true
		_xong = xong
		if _queue.is_empty() and _t <= 0.0:
			_ket_thuc()


func _xep(lines: Array, bo_giao: bool) -> void:
	for l: Dictionary in lines:
		if l.k == "giao" and bo_giao:
			continue  # khoảnh khắc giao bánh đã nói câu này
		_queue.append(l)


func _ket_thuc() -> void:
	_giu = false
	ui.an()
	var cb := _xong
	_xong = Callable()
	if cb.is_valid():
		cb.call()


func _process(delta: float) -> void:
	if ui == null:
		return
	var paused := get_tree().paused
	ui.visible = not paused
	if paused:
		return
	if _sang_t > 0.0:
		_sang_t -= delta
		if _sang_t <= 0.0:
			_dau_ngay()
	if day_id == "thu_bay":
		_t7_t -= delta
		if _t7_t <= 0.0:
			_t7_t = 0.5
			_thu_bay_step()
	if _hoi > 0:
		_hoi_t -= delta
		if autotest or Input.is_action_just_pressed("deliver"):
			nhan_thu(_hoi)
			ui.hoi(0)
			_hoi = 0
			_t = 0.0
		elif _hoi_t <= 0.0:
			ui.hoi(0)
			_hoi = 0
			_t = 0.0
		return
	if _t > 0.0:
		_t -= delta
		if _giu and _bo_qua():
			_t = 0.0
		if _t > 0.0:
			return
	if _queue.is_empty():
		if _t <= 0.0 and ui.dang_noi():
			ui.an()
		if _giu:
			_ket_thuc()
		elif not _buu_da and int(main.get("state")) == int(main.State.END):
			_buu_da = true
			_buu_thiep()
		return
	_hien(_queue.pop_front())


func _bo_qua() -> bool:
	return Input.is_action_just_pressed("deliver") or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump")


func _hien(l: Dictionary) -> void:
	if not _dk(l):
		return
	var cau := str(l.c)
	var ai := str(l.ai)
	if l.has("thay"):
		cau = cau % l.thay
	ui.noi(ai, cau, str(l.k), str(l.get("anh", "")))
	if ai != "" and ai != "Cả xóm" and not autotest:
		GiongUO.noi(ai, tr(cau))
	_t = 0.06 if autotest else clampf(1.8 + cau.length() * 0.05, 2.6, 6.5)
	if l.has("anh"):
		_t = maxf(_t, 0.06 if autotest else 4.5)
	var viec := str(l.get("viec", ""))
	if viec.begins_with("hoi:"):
		_hoi = int(viec.substr(4))
		_hoi_t = HOI_GIAY
		ui.hoi(_hoi)
	elif viec.begins_with("toi:"):
		if thu_toi(int(viec.substr(4))) and main.get("hud"):
			main.hud.show_toast("Thư tới tay rồi! +%s" % Shop.money(THU_BOA), 2.5)
	if autotest:
		print("[chuyen] %s: %s" % [ai if ai != "" else "-", cau])


# ---------------------------------------------------------------- đầu ngày, cuối ngày

func _dau_ngay() -> void:
	var bao: Array = data.get("bao", [])
	if bao.size() >= 2:
		ui.bao(GameState.DAY_NAMES.get(day_id, ""), str(bao[0]), str(bao[1]), 0.1 if autotest else 7.0)
	_xep(_nhip("sang"), false)


func _buu_thiep() -> void:
	if PlayMode.single_order() or day_id == "chu_nhat":
		return
	var buu: Array = data.get("buu", [])
	if buu.size() < 2:
		return
	var dong2 := str(buu[1])
	if data.has("buu_khac") and not ("nhan1" in thu()):
		dong2 = str(data.buu_khac)
	ui.buu_thiep(str(buu[0]), dong2, str(data.get("ky", "")), str(THIEP.get(day_id, "")))


# ---------------------------------------------------------------- Thứ Bảy: nghe theo Sổ hàng xóm

func _thu_bay_step() -> void:
	var tb := main.get_node_or_null("ThuBay")
	if tb and tb.has_method("active_id"):
		var a := str(tb.active_id())
		if a != _t7_viec:
			_t7_viec = a
			if a == "coba":
				_xep(_nhip("viec_co_ba"), false)
	var done := SoHangXom.done_ids()
	for id in done:
		if not id in _t7_done:
			_t7_done.append(id)
			if CHUA_KY.has(id):
				for l: Dictionary in _nhip("ky_viec"):
					var x := l.duplicate()
					x["thay"] = CHUA_KY[id]
					_queue.append(x)
	if not _t7_muc and SoHangXom.muc_friend():
		_t7_muc = true
		_sang_t = -1.0
		get_tree().create_timer(0.1 if autotest else 4.8).timeout.connect(func() -> void: _xep(_nhip("muc"), false))
