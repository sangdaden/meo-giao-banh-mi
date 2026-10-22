class_name Outfit
extends RefCounted
## Đồ Bơ đang mặc, lưu ở user://tu_do.cfg. Danh mục 19 giống, 35 phụ kiện, 6 ô gắn và 8 bộ đồ
## chép từ luồng "Skin mèo và phụ kiện" (meo-3d/skins/olddata.js).
## Món mặc được trong game = đã có (mặc định hoặc mua ở Shop) và có hình (IN_GAME hoặc model ở OutfitView).
## Giống mèo đang dùng cũng lưu ở đây.

const PATH := "user://tu_do.cfg"
const SLOTS := [["head", "Đầu"], ["face", "Mặt"], ["neck", "Cổ"], ["back", "Lưng"], ["tail", "Đuôi"], ["feet", "Chân"]]
const RARITY := {"mac": "Mặc định", "thuong": "Thường", "hiem": "Hiếm", "dacbiet": "Đặc biệt", "sukien": "Sự kiện", "goi": "Gói"}

# id, tên, độ hiếm, ô gắn
const ACCS := [
	["khando", "Khăn quàng đỏ", "mac", "neck"],
	["tuibanh", "Túi bánh", "mac", "back"],
	["kinhram", "Kính râm tròn", "thuong", "face"],
	["kinhcan", "Kính cận gọng vuông", "thuong", "face"],
	["mudaubep", "Mũ đầu bếp", "thuong", "head"],
	["munlen", "Mũ len quả bông", "thuong", "head"],
	["nobuom", "Nơ bướm", "thuong", "neck"],
	["noduoi", "Nơ đuôi", "thuong", "tail"],
	["tatsoc", "Tất sọc", "thuong", "feet"],
	["mubaohiem", "Mũ bảo hiểm", "hiem", "head"],
	["kinhphicong", "Kính phi công", "hiem", "face"],
	["khautrang", "Khẩu trang", "thuong", "face"],
	["thung", "Thùng giao hàng", "hiem", "back"],
	["ungmua", "Ủng đi mưa", "hiem", "feet"],
	["nonla", "Nón lá", "hiem", "head"],
	["mucoi", "Mũ cối", "hiem", "head"],
	["khanran", "Khăn rằn", "hiem", "neck"],
	["dongganh", "Đòn gánh", "dacbiet", "back"],
	["deptoong", "Dép tổ ong", "thuong", "feet"],
	["hoadambut", "Hoa dâm bụt cài tai", "thuong", "head"],
	["vonghoa", "Vòng hoa", "hiem", "neck"],
	["phaovit", "Phao bơi con vịt", "hiem", "back"],
	["bangdo", "Băng đô thể thao", "thuong", "head"],
	["giaypatin", "Giày patin", "hiem", "feet"],
	["coduua", "Cờ đua ca rô", "hiem", "tail"],
	["muphuthuy", "Mũ phù thủy", "sukien", "head"],
	["vuongmien", "Vương miện", "dacbiet", "head"],
	["bitmat", "Bịt mắt cướp biển", "thuong", "face"],
	["riamep", "Ria mép giả", "thuong", "face"],
	["aochoang", "Áo choàng siêu nhân", "hiem", "back"],
	["canhthienthan", "Cánh thiên thần", "dacbiet", "back"],
	["nonsinhnhat", "Nón sinh nhật", "sukien", "head"],
	["chuong", "Vòng chuông", "sukien", "neck"],
	["denlong", "Đèn lồng ông sao", "sukien", "tail"],
	["bongbay", "Bóng bay buộc đuôi", "sukien", "tail"],
]
## Phụ kiện Bơ vẽ sẵn bằng code (player.gd), không cần model phụ kiện
const IN_GAME := ["khando", "tuibanh"]

# tên bộ, mô tả, các món
const SETS := [
	["Mặc định", "Bơ mặc sẵn khi bắt đầu.", ["khando", "tuibanh"]],
	["Cơ bản", "Đồ rẻ, mua sớm bằng xu.", ["kinhram", "kinhcan", "mudaubep", "munlen", "nobuom", "noduoi", "tatsoc"]],
	["Bộ Giao Hàng", "Shipper chuyên nghiệp.", ["mubaohiem", "kinhphicong", "khautrang", "thung", "ungmua"]],
	["Bộ Quê Nhà", "Bánh mì gánh rong.", ["nonla", "mucoi", "khanran", "dongganh", "deptoong"]],
	["Bộ Đi Biển", "Nghỉ hè ở Vũng Tàu.", ["hoadambut", "vonghoa", "phaovit"]],
	["Bộ Thể Thao", "Chỉ đổi dáng, không tăng tốc.", ["bangdo", "giaypatin", "coduua"]],
	["Bộ Hóa Trang", "Cosplay vui, bán dịp Halloween và qua thành tích.", ["muphuthuy", "vuongmien", "bitmat", "riamep", "aochoang", "canhthienthan"]],
	["Bộ Lễ Hội", "Chỉ bán dịp Tết, Trung thu và sinh nhật.", ["nonsinhnhat", "chuong", "denlong", "bongbay"]],
]

# id, tên, giống, độ hiếm, màu lông, màu bụng, màu mắt, điều kiện mở
const BREEDS := [
	["bo", "Bơ", "Mèo ta cam vằn", "mac", "#E8913A", "#FBE3C2", "#E9A23B", "Có sẵn"],
	["muop", "Mướp", "Mèo ta mướp xám", "thuong", "#8E8A80", "#E6E1D6", "#8FAE3C", "Mua bằng xu"],
	["mun", "Mun", "Mèo ta đen thon", "thuong", "#2A292F", "#3A3940", "#E6B422", "Mua bằng xu"],
	["tuyet", "Tuyết", "Mèo Ba Tư trắng", "thuong", "#F4F1EA", "#FFFFFF", "#5FA8D8", "Mua bằng xu"],
	["khoaimon", "Khoai Môn", "Mèo Anh lông ngắn", "thuong", "#8C96A3", "#A9B1BC", "#E8962E", "Mua bằng xu"],
	["caphesua", "Cà Phê Sữa", "Mèo Miến Điện", "thuong", "#8A5A3C", "#C29673", "#E6B422", "Mua bằng xu"],
	["xoigac", "Xôi Gấc", "Mèo ta cam trắng", "thuong", "#D9622B", "#FFFFFF", "#C99A2E", "Mua bằng xu"],
	["tamthe", "Tam Thể", "Mèo Nhật cụt đuôi", "hiem", "#F7F2E8", "#E8913A", "#C99A2E", "Hiếm"],
	["bosua", "Bò Sữa", "Mèo Anh tai cụp", "hiem", "#2A292F", "#FFFFFF", "#9CBF4A", "Hiếm"],
	["xiem", "Xiêm", "Mèo Xiêm", "hiem", "#EFE2CB", "#5A4030", "#4F9BE0", "Hiếm"],
	["suadac", "Sữa Đặc", "Mèo Ragdoll", "hiem", "#F6F0E4", "#8A6A50", "#4F9BE0", "Hiếm"],
	["chalua", "Chả Lụa", "Mèo Sphynx", "hiem", "#E9C3B5", "#F0D2C6", "#7FB24A", "Hiếm"],
	["hocon", "Hổ Con", "Mèo Bengal", "hiem", "#D9A45A", "#F2DDB4", "#8FAE3C", "Hiếm"],
	["que", "Quế", "Mèo Abyssinian", "hiem", "#C0703A", "#E8B88A", "#D9A02E", "Hiếm"],
	["vobanh", "Vỏ Bánh Giòn", "Mèo Munchkin", "dacbiet", "#D98E2B", "#F4E3C1", "#3A2418", "Giao kịp cả 5 đơn"],
	["thantai", "Thần Tài", "Mèo ta vàng kim", "dacbiet", "#E8B83A", "#FFE7A0", "#C8412F", "Giao đủ 50 đơn"],
	["lantet", "Lân Tết", "Maine Coon hóa lân", "sukien", "#C8412F", "#FFE3A0", "#F7D35E", "Mở dịp Tết"],
	["thongoc", "Thỏ Ngọc", "Mèo trắng tai thỏ", "sukien", "#F2F2F6", "#FFFFFF", "#C8412F", "Mở dịp Trung thu"],
	["bingo", "Bí Ngô", "Mèo đen vằn cam", "sukien", "#26242A", "#E8913A", "#7CFF6A", "Mở dịp Halloween"],
]

## Giống mặc định là mèo cái khi người chơi chưa tự chọn (mèo tam thể gần như luôn là mèo cái)
const FEMALE_DEFAULT := ["tamthe"]

const DEFAULT_WORN := {"neck": "khando", "back": "tuibanh"}

static var _worn := {}
static var _breed := "bo"
static var _sex := ""  # "duc", "cai"; "" = theo giống (Tam Thể mặc định cái, còn lại đực)
static var _loaded := false


static func acc(id: String) -> Array:
	for a in ACCS:
		if a[0] == id:
			return a
	return []


static func slot_name(slot: String) -> String:
	for s in SLOTS:
		if s[0] == slot:
			return s[1]
	return slot


## Đã có và mặc được trong màn chơi.
static func in_game(id: String) -> bool:
	return Shop.owned(id) and (id in IN_GAME or OutfitView.has_model(id))


## Giống đã có (mặc định, mua hoặc mở bằng thành tích) và có model.
static func breed_ready(id: String) -> bool:
	return id == "bo" or (Shop.owned(id) and OutfitView.has_breed(id))


## Giống mèo đang dùng.
static func breed() -> String:
	_ensure()
	return _breed


## Giới tính đang chọn cho giống `id` (mặc định giống đang dùng). Đổi miễn phí; mua giống là có cả đực lẫn cái.
static func sex(id := "") -> String:
	_ensure()
	if _sex != "":
		return _sex
	return "cai" if (id if id != "" else _breed) in FEMALE_DEFAULT else "duc"


static func choose_sex(s: String) -> void:
	if s not in ["duc", "cai"]:
		return
	_ensure()
	_sex = s
	_save()


static func choose_breed(id: String) -> void:
	if not breed_ready(id):
		return
	_ensure()
	_breed = id
	_save()


## Món đang gắn ở một ô ("" = để trống).
static func worn(slot: String) -> String:
	_ensure()
	return _worn.get(slot, "")


static func is_worn(id: String) -> bool:
	var a := acc(id)
	return not a.is_empty() and worn(a[3]) == id


## Đeo một món vào ô của nó (thay món cũ ở ô đó). Món chưa có hình thì bỏ qua.
static func wear(id: String) -> void:
	var a := acc(id)
	if a.is_empty() or not in_game(id):
		return
	_ensure()
	_worn[a[3]] = id
	_save()


static func take_off(slot: String) -> void:
	_ensure()
	_worn[slot] = ""
	_save()


## Bấm vào một món: đang đeo thì tháo, chưa đeo thì đeo.
static func toggle(id: String) -> void:
	if is_worn(id):
		take_off(acc(id)[3])
	else:
		wear(id)


static func worn_names() -> PackedStringArray:
	var out := PackedStringArray()
	for s in SLOTS:
		var id := worn(s[0])
		if id != "":
			out.append(acc(id)[1])
	return out


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_worn = DEFAULT_WORN.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		var b := str(cfg.get_value("giong", "dang_dung", "bo"))
		_breed = b if breed_ready(b) else "bo"
		_sex = str(cfg.get_value("giong", "gioi_tinh", ""))
		for s in SLOTS:
			var id: String = str(cfg.get_value("worn", s[0], _worn.get(s[0], "")))
			_worn[s[0]] = id if (id == "" or in_game(id)) else ""


static func _save() -> void:
	var cfg := ConfigFile.new()
	for s in SLOTS:
		cfg.set_value("worn", s[0], _worn.get(s[0], ""))
	cfg.set_value("giong", "dang_dung", _breed)
	cfg.set_value("giong", "gioi_tinh", _sex)
	cfg.save(PATH)
