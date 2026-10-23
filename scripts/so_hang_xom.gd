class_name SoHangXom
## Sổ hàng xóm Thứ Bảy (gói việc thiet-ke-man/goi-viec-thu-bay.md): mỗi người dân một trang, giúp xong thì dán ảnh
## chung, được một tim thân thiết và một món quà. Trang thứ 11 là Chó Mực (sau chương làm bạn).
## Dữ liệu trang lấy từ Days.favours("thu_bay"); tiến độ lưu ở mục [thu_bay] của file lưu (GameState):
##   so_trang: id các trang đã dán (thứ tự giúp), muc_ban: đã làm bạn với Mực, banh_mi_bo: 3 nhân Cô Ba chọn,
##   anh_trang: id trang -> đường dẫn ảnh (bản máy tính), anh_bia: ảnh dán bìa (ảnh tự do chụp gần nhất).
## Chủ Nhật đọc SoHangXom.full(): đủ 10 trang thì Bơ ngồi hàng ghế đầu và có huy chương "Hàng xóm thân".
## Việc chưa làm vẫn nằm trong sổ cho "Tuần mới".

const DAY := "thu_bay"
const MUC := "muc"
const PEOPLE_PAGES := 10
## Quà đã có trong tủ đồ (mua rồi) thì đổi thành tiền boa
const GIFT_MONEY := 15000
const ANH_DIR := "user://anh_thu_bay"

## Ảnh chụp trong phiên chơi: tên -> Image. Bản web không ghi file, chỉ giữ ở đây.
static var photos := {}


static func pages() -> Array:
	return Days.favours(DAY)


static func page(id: String) -> Dictionary:
	for p in pages():
		if p.id == id:
			return p
	return {}


static func done_ids() -> Array:
	return GameState.get_day("so_trang", [], DAY)


static func is_done(id: String) -> bool:
	return id in done_ids()


## Số tim thân thiết (trang người đã dán, không tính trang Mực).
static func hearts() -> int:
	return done_ids().filter(func(x): return x != MUC).size()


static func full() -> bool:
	return hearts() >= PEOPLE_PAGES


static func muc_friend() -> bool:
	return bool(GameState.get_day("muc_ban", false, DAY))


## Dán trang `id`, trao quà. Trả về {"gift": tên quà, "money": tiền boa đổi quà (0 nếu nhận đồ)}.
static func mark(id: String) -> Dictionary:
	if is_done(id):
		return {"gift": "", "money": 0}
	var list := done_ids().duplicate()
	list.append(id)
	GameState.set_day("so_trang", list, DAY)
	var out := {"gift": "", "money": 0}
	if id == MUC:
		GameState.set_day("muc_ban", true, DAY)
		ConVat.meet(MUC)  # trang "Bạn bốn chân"
	else:
		var p := page(id)
		out = grant_gift(str(p.get("gift", "")))
		out.gift = str(p.get("gift_name", ""))
	GameState.write_save()
	return out


## Quà phụ kiện: chưa có thì cho vào tủ đồ (da_mua), có rồi thì đổi 15.000đ vào ví.
## Món mới (nón phớt, kính bảo hộ, ly cà phê đội đầu) chưa có model vẫn ghi vào da_mua, có model là hiện trong tủ.
static func grant_gift(gift: String) -> Dictionary:
	if gift == "" or gift == "cong_thuc":
		return {"gift": "", "money": 0}
	if Shop.owned(gift) and Outfit.acc(gift).size() > 0:
		GameState.set_global("vi_tien_boa", Shop.wallet() + GIFT_MONEY)
		return {"gift": "", "money": GIFT_MONEY}
	var list := Shop.bought().duplicate()
	if not gift in list:
		list.append(gift)
	GameState.set_global("da_mua", list)
	return {"gift": "", "money": 0}


## Giữ ảnh chụp: trong bộ nhớ (mọi bản) và ghi file PNG (bản máy tính). key = id trang, hoặc "bia".
static func keep_photo(key: String, img: Image) -> void:
	if img == null or img.is_empty():
		return
	if img.get_width() > 640:
		img.resize(640, int(640.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
	photos[key] = img
	if OS.has_feature("web"):
		return
	DirAccess.make_dir_recursive_absolute(ANH_DIR)
	var path := "%s/%s.png" % [ANH_DIR, key]
	if img.save_png(path) == OK:
		var map: Dictionary = GameState.get_day("anh_trang", {}, DAY)
		map = map.duplicate()
		map[key] = path
		GameState.set_day("anh_trang", map, DAY)


## Ảnh của trang (phiên này, hoặc file đã lưu lần trước). null nếu chưa có.
static func photo(key: String) -> Image:
	if photos.has(key):
		return photos[key]
	var path := str((GameState.get_day("anh_trang", {}, DAY) as Dictionary).get(key, ""))
	if path != "" and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img and not img.is_empty():
			photos[key] = img
			return img
	return null


## Dòng tóm tắt cho màn Chọn màn.
static func summary_line() -> String:
	var n := hearts()
	if n == 0 and not muc_friend():
		return "Sổ hàng xóm còn trống · 10 người đang chờ Bơ giúp"
	var s := "Sổ hàng xóm %d/%d trang" % [n, PEOPLE_PAGES]
	if muc_friend():
		s += " · đã làm bạn với Chó Mực"
	return s
