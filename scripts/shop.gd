class_name Shop
## Cửa hàng tủ đồ: mua giống mèo và phụ kiện bằng tiền boa kiếm được khi giao bánh (không dùng tiền thật).
## Hồ sơ người chơi nằm ở mục [chung] của user://luu_game.cfg (GameState):
##   vi_tien_boa (đồng trong ví), tong_sao (tổng sao mọi lần chơi), don_kip (số đơn giao kịp giờ),
##   kip_ca_5 (đã có ngày giao kịp cả 5 đơn), da_mua (id giống và phụ kiện đã mua).
## Bảng giá là đề xuất ban đầu, Sang chốt lại thì chỉ sửa PRICE_ACC, PRICE_BREED và GOALS.

## Giá phụ kiện theo độ hiếm (đồng). Một ngày giao tốt được khoảng 60.000–110.000đ.
const PRICE_ACC := {"mac": 0, "thuong": 15000, "hiem": 40000, "dacbiet": 90000}
## Giá giống mèo theo độ hiếm. Giống đặc biệt mở bằng thành tích (GOALS), không bán.
const PRICE_BREED := {"mac": 0, "thuong": 60000, "hiem": 150000}
## Phụ kiện đặc biệt cần đủ tổng sao mới được mua.
const SPECIAL_ACC_STARS := 60
## Món mở bằng thành tích, miễn phí: id -> [khóa trong hồ sơ, số cần đạt, mô tả]
const GOALS := {
	"vobanh": ["kip_ca_5", 1, "Giao kịp cả 5 đơn trong một ngày"],
	"thantai": ["don_kip", 50, "Giao kịp đủ 50 đơn"],
}
## Đồ sự kiện chỉ mở theo dịp (Tết, Trung thu, Halloween, sinh nhật), bản này chưa bán.
const EVENT := "sukien"


static func wallet() -> int:
	return int(GameState.get_global("vi_tien_boa", 0))


static func total_stars() -> int:
	return int(GameState.get_global("tong_sao", 0))


static func stat(key: String) -> int:
	return int(GameState.get_global(key, 0))


static func bought() -> Array:
	return GameState.get_global("da_mua", [])


## Đã có món này chưa: đồ mặc định, đồ đã mua, hoặc đồ thành tích đã đạt.
static func owned(id: String) -> bool:
	var r := rarity(id)
	if r == "mac" or id in bought():
		return true
	return GOALS.has(id) and _goal_met(id)


static func is_breed(id: String) -> bool:
	for b in Outfit.BREEDS:
		if b[0] == id:
			return true
	return false


static func rarity(id: String) -> String:
	for b in Outfit.BREEDS:
		if b[0] == id:
			return b[3]
	var a := Outfit.acc(id)
	return a[2] if not a.is_empty() else ""


## Giá của món, -1 nếu không bán (sự kiện, thành tích).
static func price(id: String) -> int:
	var r := rarity(id)
	if r == EVENT or GOALS.has(id):
		return -1
	var table := PRICE_BREED if is_breed(id) else PRICE_ACC
	return int(table.get(r, -1))


## Kiểm tra mua được chưa. Trả về {ok: bool, text: chữ cho nút hoặc lý do}.
static func check(id: String) -> Dictionary:
	if owned(id):
		return {"ok": false, "text": "Đã có"}
	if GOALS.has(id):
		var g: Array = GOALS[id]
		return {"ok": false, "text": "%s (%d/%d)" % [g[2], mini(stat(g[0]), g[1]), g[1]]}
	var p := price(id)
	if p < 0:
		return {"ok": false, "text": "Mở theo dịp lễ, chưa bán"}
	if not is_breed(id) and rarity(id) == "dacbiet" and total_stars() < SPECIAL_ACC_STARS:
		return {"ok": false, "text": "Cần %d sao (đang có %d)" % [SPECIAL_ACC_STARS, total_stars()]}
	if wallet() < p:
		return {"ok": false, "text": "Thiếu %s" % money(p - wallet())}
	return {"ok": true, "text": "Mua · " + money(p)}


## Mua một món: trừ ví, ghi vào da_mua và lưu ngay. Trả về true nếu mua được.
static func buy(id: String) -> bool:
	if not check(id).ok:
		return false
	var list := bought().duplicate()
	list.append(id)
	GameState.set_global("da_mua", list)
	GameState.set_global("vi_tien_boa", wallet() - price(id))
	GameState.write_save()
	return true


## Cộng số liệu hồ sơ sau mỗi lần chơi (Scoring gọi).
static func add_stats(stars: int, on_time: int, all_five_on_time: bool) -> void:
	GameState.set_global("tong_sao", total_stars() + stars)
	GameState.set_global("don_kip", stat("don_kip") + on_time)
	if all_five_on_time:
		GameState.set_global("kip_ca_5", 1)


static func _goal_met(id: String) -> bool:
	var g: Array = GOALS[id]
	return stat(g[0]) >= g[1]


## 25000 -> "25.000đ"
static func money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out + "đ"


## Kiểm tra nhanh (autotest gọi, dùng file lưu tự kiểm tra): mua được khi đủ tiền, trừ đúng ví.
static func self_test() -> bool:
	var before := wallet()
	GameState.set_global("vi_tien_boa", 20000)
	var ok: bool = price("kinhram") == 15000 and check("kinhram").ok and buy("kinhram")
	ok = ok and owned("kinhram") and wallet() == 5000 and not buy("kinhram")
	ok = ok and not check("mubaohiem").ok and price("muphuthuy") == -1 and owned("khando")
	ok = ok and money(110000) == "110.000đ"
	GameState.set_global("da_mua", bought().filter(func(x): return x != "kinhram"))
	GameState.set_global("vi_tien_boa", before)
	if not ok:
		push_error("Shop: tự kiểm tra mua đồ sai")
	return ok
