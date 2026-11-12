class_name NhacKetNgay
extends RefCounted
## GC5: thẻ nhắc ở màn kết ngày (HudKetQua.build gắn vào cột trái, dưới lời khen).
##   1. Món đang "Để dành" trong tủ đồ: còn thiếu bao nhiêu tiền boa (hay đã đủ tiền mua).
##   2. Ngày kế tiếp có gì mới: khóa "moi" trong scripts/ngay/<mã>.gd (thiếu thì lấy "blurb").
##      Bản demo (Days.demo) hết Thứ Ba thì báo hết bản demo và các ngày có trong bản đầy đủ.
## Chỉ đọc file lưu, không ghi gì. Không có gì để nhắc thì trả null.

const T = preload("res://scripts/ui/ui_theme.gd")
const INK := Color("#1F3A3D")
const PAPER := Color("#FFF8EA")


static func build(day_id: String) -> Control:
	var wish := wish_line()
	var next := next_line(day_id)
	if wish.is_empty() and next.is_empty():
		return null
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", T.box(PAPER, 18, 14, INK, 3, 5))
	card.custom_minimum_size.x = 400
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	if not wish.is_empty():
		v.add_child(_text(wish.text, 15, INK, "bold"))
		if wish.has("have"):
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 10)
			bar.max_value = maxi(int(wish.need), 1)
			bar.value = mini(int(wish.have), int(wish.need))
			bar.add_theme_stylebox_override("background", T.box(T.SAND, 999, 0, INK, 2))
			bar.add_theme_stylebox_override("fill", T.box(T.LEAF, 999, 0, INK, 2))
			v.add_child(bar)
	if not next.is_empty():
		if not wish.is_empty():
			var sep := HSeparator.new()
			sep.add_theme_constant_override("separation", 2)
			v.add_child(sep)
		v.add_child(_text(next.head, 15, T.TEAL if not next.get("demo_end", false) else Color("#C8412F"), "display"))
		v.add_child(_text(next.body, 13, T.MUTED, "bold"))
	return card


## Dòng nhắc món để dành gần mua được nhất: {text, have, need} hoặc {} nếu không để dành gì.
static func wish_line() -> Dictionary:
	var best := ""
	var best_gap := 1 << 40
	for id: String in Shop.wishlist():
		if Shop.owned(id) or Shop.price(id) <= 0:
			continue
		var gap := Shop.price(id) - Shop.wallet()
		if gap < best_gap:
			best_gap = gap
			best = id
	if best == "":
		return {}
	var item := item_name(best)
	var c := Shop.check(best)
	if c.ok:
		return {"text": "Đủ tiền mua %s! Mở Tủ đồ ở trang chủ để mua." % item}
	if best_gap > 0:
		return {"text": "Để dành %s: còn thiếu %s" % [item, Shop.money(best_gap)],
			"have": Shop.wallet(), "need": Shop.price(best)}
	return {"text": "Để dành %s: %s" % [item, str(c.text)]}


## Tên hiển thị của một món trong tủ đồ (giống mèo, phụ kiện, đồ trang trí tiệm).
static func item_name(id: String) -> String:
	if Tiem.NAMES.has(id):
		return Tiem.NAMES[id]
	for b in Outfit.BREEDS:
		if b[0] == id:
			return "mèo %s" % b[1]
	var a := Outfit.acc(id)
	return str(a[1]).to_lower() if not a.is_empty() else id


## Ngày kế tiếp: {head, body, demo_end?} hoặc {} nếu không có ngày kế (ngày ngoài tuần).
static func next_line(day_id: String) -> Dictionary:
	if not day_id in Days.ORDER:
		return {}
	if Days.demo() and day_id == Days.DEMO_DAYS[-1]:
		return {"head": "Hết bản demo. Cảm ơn bạn đã giao bánh cùng Bơ!",
			"body": "Bản đầy đủ còn 5 ngày: mưa chiều, leo chung cư, đám giỗ Bà Sáu, dạo phố và Hội mèo.",
			"demo_end": true}
	var n := PlayMode.next_of(day_id)
	var nid: String = n[0]
	var d := Days.data(nid)
	if d.is_empty():
		return {}
	var head := "Tuần mới · %s" % GameState.DAY_NAMES.get(nid, nid) if n[1] \
		else "Ngày mai · %s: %s" % [GameState.DAY_NAMES.get(nid, nid), str(d.get("title", ""))]
	return {"head": head, "body": str(d.get("moi", d.get("blurb", "")))}


static func _text(s: String, size: int, color: Color, kind: String) -> Label:
	var l := T.label(s, size, color, kind)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 370
	return l
