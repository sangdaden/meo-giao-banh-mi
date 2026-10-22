class_name WardrobePanel
extends Control
## Tủ đồ của Bơ (artboard 3). Bên trái: Bơ 3D trên bục, kéo chuột hoặc vuốt để xoay 360°,
## lăn chuột để phóng to; sáu ô gắn phụ kiện. Bên phải: bốn tab Giống mèo, Phụ kiện, Bộ đồ, Tiệm (đồ trang trí tiệm Cô Ba, Tiem).
## Danh mục và đồ đang mặc nằm ở Outfit. Món khoá mà đã có model (assets/models/skin, xem OutfitView)
## thì bấm để mặc thử trên bục: chỉ xem trước, "Xong" trả Bơ về đồ đã có. Món chưa xuất model hiện "Đang dựng".
## Đang thử món còn khoá thì chân trang có "Để dành" (lưu lại mua sau) và "Mua · giá" (tiền boa trong ví, Shop).
## Mua xong món chỉ vào đồ đã có, người chơi tự bấm để đeo. Món để dành hiện "Đủ tiền" khi ví đủ.

signal closed

const T = preload("res://scripts/ui/ui_theme.gd")
const TAGS := {
	"mac": ["#F7D35E", "#2A1A05"],
	"thuong": ["#E7DCC4", "#1F3A3D"],
	"hiem": ["#2E7C80", "#FFF8EA"],
	"dacbiet": ["#D98E2B", "#2A1A05"],
	"sukien": ["#C8412F", "#FFF8EA"],
	"goi": ["#3F8A5C", "#FFF8EA"],
}
const TAB_NAMES := ["Giống mèo · 19", "Phụ kiện · 35", "Bộ đồ · 8", "Tiệm · 4"]
const NOTES := [
	"Bấm giống mèo khoá để xem thử trên bục, đủ tiền boa thì bấm Mua. Giống đã có bấm để chọn.",
	"Bấm món đã có để đeo hoặc tháo. Món khoá bấm để mặc thử, đủ tiền boa thì bấm Mua.",
	"Bộ còn khoá thì mặc thử cả bộ trên bục. Bấm Xong để trả về đồ đã có.",
	"Đồ trang trí tiệm Cô Ba, chỉ để ngắm. Món khoá bấm để xem, đủ tiền boa thì bấm Mua. Món đã có bấm để bày hoặc cất.",
]
const TIEM_DESC := {
	"meo_vay_tay": "Đặt trên quầy Cô Ba, vẫy tay đón khách.",
	"chau_mai": "Đặt cạnh xe bánh mì trong bếp.",
	"den_long_tiem": "Hai chiếc treo trong bếp và dưới mái hiên Lò bánh, chiều tối thì sáng.",
	"bang_hieu_go": "Treo ở tường bếp và cạnh cửa Lò bánh.",
}

var tab := 0
var slot_filter := ""
var preview: BoPreview
var _tabs: Array[Button] = []
var _filters: HBoxContainer
var _scroll: ScrollContainer
var _list: Container
var _slots: HBoxContainer
var _worn_label: Label
var _note: Label
var _done: Button
var _untry: Button
var _buy: Button
var _wish: Button
var _wallet: Label
var _name: Label
var _sex_box: HBoxContainer  # nút Đực / Cái cạnh tên mèo
## Món vừa bấm thử (giống hoặc phụ kiện), nút Mua mua món này.
var _buy_id := ""
## Đồ mặc thử trên bục theo ô (chưa sở hữu, không mang vào màn chơi) và giống đang xem thử ("" = Bơ).
var _try := {}
var _try_breed := ""
## Tab Tiệm: món đang xem trên bục (bục đổi thành khung ảnh món) và món đang xem thử (chưa mua)
var _tiem_pick := ""
var _try_tiem := ""
var _tiem_view: PanelContainer
var _tiem_img: TextureRect
var _tiem_cap: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = T.make_theme()
	T.full_rect(self)
	var bg := ColorRect.new()
	bg.color = Color("#F3EFE4")
	add_child(T.full_rect(bg))

	var left := Panel.new()
	left.add_theme_stylebox_override("panel", T.box(Color("#9CCBC1"), 0, 0, Color(0, 0, 0, 0), 0))
	left.anchor_bottom = 1.0
	left.offset_right = 500
	left.clip_contents = true
	add_child(left)
	preview = BoPreview.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_bottom = -210
	left.add_child(preview)
	# Tab Tiệm: thay bục mèo bằng khung ảnh món trang trí
	_tiem_view = PanelContainer.new()
	_tiem_view.add_theme_stylebox_override("panel", T.box(T.PAPER, 22, 18, T.INK, 3, 6))
	T.place(_tiem_view, 0.0, 0.0, Rect2(40, 150, 420, 300))
	_tiem_view.visible = false
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	_tiem_view.add_child(tv)
	_tiem_img = TextureRect.new()
	_tiem_img.custom_minimum_size = Vector2(0, 220)
	_tiem_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tiem_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tv.add_child(_tiem_img)
	_tiem_cap = T.label("", 14, T.MUTED, "bold")
	_tiem_cap.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tiem_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(_tiem_cap)
	left.add_child(_tiem_view)
	var edge := ColorRect.new()
	edge.color = T.INK
	edge.anchor_bottom = 1.0
	edge.offset_left = 500
	edge.offset_right = 504
	add_child(edge)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.position = Vector2(28, 28)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	var back := T.icon_button("back", "Quay lại (Esc)")
	back.pressed.connect(close)
	head.add_child(back)
	var title := T.label("Tủ đồ của Bơ", 40, T.INK, "display")
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)

	var purse := PanelContainer.new()
	purse.add_theme_stylebox_override("panel", T.box(T.PAPER, 999, 14, T.INK, 3))
	purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	T.place(purse, 0.0, 0.0, Rect2(28, 96, 0, 0))
	_wallet = T.label("", 16, T.INK, "bold")
	_wallet.tooltip_text = "Tiền boa và sao kiếm được khi giao bánh, dùng mua đồ trong tủ"
	purse.add_child(_wallet)
	add_child(purse)

	var name_card := PanelContainer.new()
	name_card.add_theme_stylebox_override("panel", T.box(T.PAPER, 14, 14, T.INK, 3))
	T.place(name_card, 0.0, 1.0, Rect2(28, -200, 444, 74))
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 10)
	name_card.add_child(nrow)
	var nc := VBoxContainer.new()
	nc.add_theme_constant_override("separation", 0)
	nc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = T.label("Bơ · mèo ta cam", 24, T.INK, "display")
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nc.add_child(_name)
	_worn_label = T.label("", 14, T.MUTED, "bold")
	_worn_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nc.add_child(_worn_label)
	nrow.add_child(nc)
	# Đực / Cái: đổi miễn phí, mua giống một lần là có cả hai
	_sex_box = HBoxContainer.new()
	_sex_box.add_theme_constant_override("separation", 0)
	_sex_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nrow.add_child(_sex_box)
	add_child(name_card)

	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 8)
	T.place(_slots, 0.0, 1.0, Rect2(28, -112, 444, 84))
	add_child(_slots)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = 540
	right.offset_top = 28
	right.offset_right = -40
	right.offset_bottom = -28
	add_child(right)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	right.add_child(tabs)
	for i in TAB_NAMES.size():
		var b := T.button(TAB_NAMES[i], "secondary", 52, 17)
		b.pressed.connect(show_tab.bind(i))
		tabs.add_child(b)
		_tabs.append(b)

	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override("separation", 6)
	right.add_child(_filters)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)

	# Ghi chú nằm riêng một dòng trên hàng nút, để đủ chỗ cho Bỏ mặc thử, Để dành, Mua, Xong.
	_note = T.label("", 15, T.MUTED, "bold")
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_note)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	foot.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(foot)
	_untry = T.button("Bỏ mặc thử", "secondary", 60, 17)
	_untry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_untry.pressed.connect(func():
		_clear_try()
		_refresh()
		_note.text = "Đã bỏ đồ mặc thử.")
	foot.add_child(_untry)
	_wish = T.button("Để dành", "secondary", 60, 17)
	_wish.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wish.tooltip_text = "Lưu món này để mua sau khi đủ tiền boa"
	_wish.pressed.connect(_wish_tried)
	foot.add_child(_wish)
	_buy = T.button("Mua", "primary", 60, 17)
	_buy.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buy.clip_text = true
	_buy.custom_minimum_size.x = 180
	_buy.pressed.connect(_buy_tried)
	foot.add_child(_buy)
	_done = T.button("Xong", "primary", 60, 20)
	_done.custom_minimum_size.x = 150
	_done.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_done.pressed.connect(close)
	foot.add_child(_done)

	show_tab(0)
	T.wire_clicks(self)
	visibility_changed.connect(func():
		preview.set_active(visible)
		if visible:
			_done.grab_focus.call_deferred())
	preview.set_active(visible)


## Chuyển tab: 0 giống mèo, 1 phụ kiện, 2 bộ đồ.
func show_tab(i: int, filter := "") -> void:
	tab = i
	slot_filter = filter if i == 1 else ""
	for k in _tabs.size():
		var b := _tabs[k]
		var on := k == tab
		b.add_theme_stylebox_override("normal", T.box(T.INK if on else T.PAPER, 16, 20, T.INK, 3, 0 if on else 5))
		b.add_theme_stylebox_override("hover", T.box(T.INK if on else T.PAPER.lightened(0.1), 16, 20, T.INK, 3, 0 if on else 5))
		for c in ["font_color", "font_focus_color", "font_hover_color"]:
			b.add_theme_color_override(c, T.PAPER if on else T.INK)
	_note.text = NOTES[tab]
	_refresh()


## Đồ hiện trên bục: đồ đang đeo, ô nào có món mặc thử thì thay bằng món đó.
func _shown() -> Dictionary:
	var w := {}
	for s in Outfit.SLOTS:
		w[s[0]] = _try.get(s[0], Outfit.worn(s[0]))
	return w


func _trying() -> bool:
	return not _try.is_empty() or _try_breed != "" or _try_tiem != ""


func _clear_try() -> void:
	_try.clear()
	_try_breed = ""
	_try_tiem = ""
	_buy_id = ""


## Mua món đang thử. Món vào đồ đã có, chưa đeo: người chơi bấm vào ô để đeo khi muốn.
func _buy_tried() -> void:
	var id := _buy_id
	if id == "" or not Shop.buy(id):
		return
	if Shop.is_breed(id):
		_try_breed = ""
		_note.text = "Đã mua %s! Bấm vào ô giống mèo để chọn khi muốn đổi." % _breed(id)[1]
	elif id in Tiem.IDS:
		_try_tiem = ""
		_note.text = "Đã mua %s! Đã bày trong tiệm Cô Ba, bấm vào ô để cất khi muốn." % Tiem.NAMES[id].to_lower()
	else:
		var a := Outfit.acc(id)
		_try.erase(a[3])
		_note.text = "Đã mua %s! Bấm vào ô để đeo khi muốn." % a[1].to_lower()
	_buy_id = ""
	_refresh()


## Để dành món đang thử (bấm lần nữa để bỏ).
func _wish_tried() -> void:
	if _buy_id == "":
		return
	Shop.toggle_wish(_buy_id)
	var name: String = _breed(_buy_id)[1] if Shop.is_breed(_buy_id) else (Tiem.NAMES[_buy_id].to_lower() if _buy_id in Tiem.IDS else Outfit.acc(_buy_id)[1].to_lower())
	_note.text = ("Đã để dành %s. Khi đủ tiền boa, ô này hiện \"Đủ tiền\"." % name) if Shop.wished(_buy_id) else ("Đã bỏ %s khỏi danh sách để dành." % name)
	_refresh()


## Chữ trên dải khoá: giá nếu bán, không thì "bấm để thử". Món để dành ghi "Để dành", ví đủ thì "Đủ tiền".
func _lock_text(id: String, model: bool) -> String:
	if not model:
		return "Khoá · đang dựng"
	if Shop.pack(id) != "":
		return "Có trong gói " + Shop.pack(id)
	var p := Shop.price(id)
	if Shop.wished(id):
		return ("Đủ tiền · " if Shop.check(id).ok else "Để dành · ") + Shop.money(p)
	return "Khoá · " + (Shop.money(p) if p > 0 else "bấm để thử")


func _pick_sex(s: String) -> void:
	if s == Outfit.sex(_try_breed if _try_breed != "" else Outfit.breed()):
		return
	Outfit.choose_sex(s)
	var want := _try_breed if _try_breed != "" else Outfit.breed()
	var has_model := OutfitView.has_sex_model(want, s)
	_note.text = ("Đã đổi sang mèo %s." % ("cái" if s == "cai" else "đực")) + ("" if has_model else " Bản mèo cái của giống này đang dựng trong Blender, tạm hiện dáng mèo đực.")
	_refresh()


func _breed(id: String) -> Array:
	for b in Outfit.BREEDS:
		if b[0] == id:
			return b
	return Outfit.BREEDS[0]


func _refresh() -> void:
	_build_slots()
	var br := _breed(_try_breed if _try_breed != "" else Outfit.breed())
	_name.text = "%s · %s%s" % [br[1], br[2].to_lower(), " · xem thử" if _try_breed != "" else ""]
	var names := Outfit.worn_names()
	var cur_sex := Outfit.sex(br[0])
	for c in _sex_box.get_children():
		c.queue_free()
	for s in [["duc", "Đực"], ["cai", "Cái"]]:
		var sb := T.button(s[1], "primary" if s[0] == cur_sex else "secondary", 44, 16)
		sb.custom_minimum_size.x = 64
		sb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		sb.tooltip_text = "Mèo %s · đổi miễn phí" % s[1].to_lower()
		sb.pressed.connect(_pick_sex.bind(s[0]))
		_sex_box.add_child(sb)
	var txt := ("Cái · " if cur_sex == "cai" else "Đực · ") + ("đang đeo: " + ", ".join(names) if names.size() > 0 else "chưa đeo gì")
	if not _try.is_empty():
		var tried := PackedStringArray()
		for slot in _try:
			tried.append(Outfit.acc(_try[slot])[1])
		txt += " · thử: " + ", ".join(tried)
	_worn_label.text = txt
	_untry.visible = _trying()
	var wl := Shop.wishlist().size()
	_wallet.text = "Ví %s · %d sao" % [Shop.money(Shop.wallet()), Shop.total_stars()]
	if wl > 0:
		var ready := Shop.wish_ready()
		_wallet.text += " · để dành %d món%s" % [wl, (", %d món đủ tiền" % ready) if ready > 0 else ""]
	var still_tried := _buy_id != "" and (_try_breed == _buy_id or _try.values().has(_buy_id) or _try_tiem == _buy_id)
	_buy.visible = still_tried and not Shop.owned(_buy_id)
	_wish.visible = _buy.visible and Shop.price(_buy_id) > 0
	if _buy.visible:
		var c := Shop.check(_buy_id)
		# Điều kiện dài (thành tích, dịp lễ) ghi ở dòng ghi chú, nút chỉ ghi ngắn để giữ chiều cao bình thường
		_buy.text = c.text if c.ok or c.text.length() <= 16 else ("Có trong gói" if Shop.pack(_buy_id) != "" else "Chưa mở được")
		_buy.tooltip_text = c.text
		_buy.disabled = not c.ok
		_wish.text = "Bỏ để dành" if Shop.wished(_buy_id) else "Để dành"
	if preview.cat:
		var want := _try_breed if _try_breed != "" else Outfit.breed()
		if preview.cat.breed != want or preview.cat.sex != Outfit.sex(want):
			preview.cat.set_breed(want, _shown())
		else:
			preview.cat.apply_outfit(_shown())

	for c in _filters.get_children():
		c.queue_free()
	_filters.visible = tab == 1
	if tab == 1:
		_filters.add_child(_chip("Tất cả · %d" % Outfit.ACCS.size(), ""))
		for s in Outfit.SLOTS:
			var n := 0
			for a in Outfit.ACCS:
				if a[3] == s[0]:
					n += 1
			_filters.add_child(_chip("%s · %d" % [s[1], n], s[0]))

	var keep_scroll := _scroll.scroll_vertical
	if _list:
		_list.queue_free()
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match tab:
		0:
			grid.columns = 6
			for b in Outfit.BREEDS:
				grid.add_child(_breed_tile(b))
		1:
			grid.columns = 6
			for a in Outfit.ACCS:
				if slot_filter == "" or a[3] == slot_filter:
					grid.add_child(_acc_tile(a))
		2:
			grid.columns = 2
			for s in Outfit.SETS:
				grid.add_child(_set_card(s))
		3:
			grid.columns = 4
			for id in Tiem.IDS:
				grid.add_child(_tiem_tile(id))
	_tiem_view.visible = tab == 3
	preview.visible = tab != 3
	if tab == 3:
		var pick := _try_tiem if _try_tiem != "" else (_tiem_pick if _tiem_pick != "" else Tiem.IDS[0])
		_tiem_img.texture = load(TIEM_ICON % pick)
		var st := "Đang xem thử · " if pick == _try_tiem else ("Đang bày · " if Tiem.shown(pick) else ("Đã có, đang cất · " if Tiem.owned(pick) else ""))
		_tiem_cap.text = "%s\n%s%s" % [Tiem.NAMES[pick], st, TIEM_DESC[pick]]
	_list = grid
	_scroll.add_child(grid)
	_scroll.set_deferred("scroll_vertical", keep_scroll)
	T.wire_clicks(self)


# ---------------------------------------------------------------- ô gắn bên trái

func _build_slots() -> void:
	for c in _slots.get_children():
		c.queue_free()
	for s in Outfit.SLOTS:
		var id: String = _try.get(s[0], Outfit.worn(s[0]))
		var tried := _try.has(s[0])
		var active: bool = tab == 1 and slot_filter == s[0]
		var b := Button.new()
		b.custom_minimum_size = Vector2(66, 84)
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = "Ô %s: %s%s" % [s[1], Outfit.acc(id)[1] if id != "" else "trống, bấm để chọn", " (đang thử)" if tried else ""]
		var fill := Color("#DDF0EA") if tried else (Color("#FFF1D6") if id != "" else Color("#FBF3E2"))
		var border := T.TEAL if active or tried else (T.CRUST if id != "" else Color("#8A7B5C"))
		b.add_theme_stylebox_override("normal", T.box(fill, 18, 4, border, 4 if active or id != "" else 3))
		b.add_theme_stylebox_override("hover", T.box(fill.lightened(0.3), 18, 4, border, 4))
		b.add_theme_stylebox_override("pressed", T.box(fill.darkened(0.06), 18, 4, border, 4))
		b.add_theme_stylebox_override("focus", T.box(Color(0, 0, 0, 0), 20, 4, T.TEAL, 4))
		b.pressed.connect(show_tab.bind(1, s[0]))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(v)
		var ic := SlotIcon.new()
		ic.slot = s[0]
		ic.color = T.RED if id == "khando" else (T.TEAL if id != "" else Color("#B5A88A"))
		ic.plus = id == ""
		ic.custom_minimum_size = Vector2(40, 30)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ic)
		var l := T.label(s[1], 13, T.INK if id != "" else T.MUTED, "bold")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		_slots.add_child(b)


func _chip(text: String, slot: String) -> Button:
	var on := slot_filter == slot
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_override("font", T.font("bold"))
	b.add_theme_font_size_override("font_size", 14)
	var fill := T.TEAL if on else T.PAPER
	b.add_theme_stylebox_override("normal", T.box(fill, 999, 14, T.INK if not on else T.TEAL, 2))
	b.add_theme_stylebox_override("hover", T.box(fill.lightened(0.1), 999, 14, T.INK, 2))
	b.add_theme_stylebox_override("pressed", T.box(fill.darkened(0.1), 999, 14, T.INK, 2))
	b.add_theme_stylebox_override("focus", T.box(Color(0, 0, 0, 0), 999, 14, T.TEAL, 3))
	for c in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, T.PAPER if on else T.INK)
	b.pressed.connect(show_tab.bind(1, slot))
	return b


# ---------------------------------------------------------------- ô trong lưới

## Nút ô vuông: nền giấy viền mực, đang chọn thì viền vỏ bánh.
func _tile_button(size: Vector2, selected: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_ALL
	var fill := Color("#FFF1D6") if selected else T.PAPER
	var border := T.CRUST if selected else T.INK
	var w := 4 if selected else 3
	b.add_theme_stylebox_override("normal", T.box(fill, 18, 6, border, w))
	b.add_theme_stylebox_override("hover", T.box(fill.lightened(0.4), 18, 6, border, w))
	b.add_theme_stylebox_override("pressed", T.box(fill.darkened(0.05), 18, 6, border, w))
	var f := T.box(Color(0, 0, 0, 0), 20, 6, T.TEAL, 4)
	f.expand_margin_left = 3
	f.expand_margin_right = 3
	f.expand_margin_top = 3
	f.expand_margin_bottom = 3
	b.add_theme_stylebox_override("focus", f)
	return b


func _tile_body(b: Button) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 20
	b.add_child(v)
	return v


func _tag(rar: String) -> Control:
	var tag := PanelContainer.new()
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_stylebox_override("panel", T.box(Color(TAGS[rar][0]), 999, 8, Color(0, 0, 0, 0), 0))
	tag.add_child(T.label(Outfit.RARITY[rar], 11, Color(TAGS[rar][1]), "bold"))
	return tag


func _name_label(text: String) -> Label:
	var n := T.label(text, 13, T.INK, "bold")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


## Món chưa có: làm mờ nội dung, nền xám cát, dải mực "Khoá · ..." ở trên cùng (tên vẫn đọc được).
## Đang mặc thử thì không mờ, viền và dải màu xanh "Đang thử".
func _lock_cover(b: Button, body: Control, text: String, tried := false) -> void:
	if tried:
		for k in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(k, T.box(Color("#DDF0EA") if k != "hover" else Color("#E8F6F1"), 18, 6, T.TEAL, 4))
	else:
		body.modulate = Color(1, 1, 1, 0.5)
		for k in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(k, T.box(Color("#E9E2D2") if k != "hover" else Color("#F1EBDD"), 18, 6, Color("#8A7B5C"), 3))
	var rib := PanelContainer.new()
	rib.add_theme_stylebox_override("panel", T.box(T.TEAL if tried else T.INK, 8, 4, Color(0, 0, 0, 0), 0))
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rib.anchor_right = 1.0
	rib.offset_left = 8
	rib.offset_right = -8
	rib.offset_top = 8
	var ready_wish := text.begins_with("Đủ tiền")
	if ready_wish and not tried:
		rib.add_theme_stylebox_override("panel", T.box(T.AMBER, 8, 4, Color(0, 0, 0, 0), 0))
	var l := T.label("Đang thử · bấm để bỏ" if tried else text, 10, T.ON_CRUST if ready_wish and not tried else T.PAPER, "bold")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	rib.add_child(l)
	b.add_child(rib)


func _breed_tile(br: Array) -> Button:
	var ready: bool = Outfit.breed_ready(br[0])
	var model := OutfitView.has_breed(br[0])
	var tried: bool = _try_breed == br[0]
	var b := _tile_button(Vector2(104, 150), br[0] == Outfit.breed() and _try_breed == "")
	b.tooltip_text = "%s · %s" % [br[1], br[2]]
	var v := _tile_body(b)
	var face := CatFace.new()
	face.fur = Color(br[4])
	face.belly = Color(br[5])
	face.eye = Color(br[6])
	face.custom_minimum_size = Vector2(64, 56)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(face)
	v.add_child(_name_label(br[1]))
	v.add_child(_tag(br[3]))
	if not ready:
		_lock_cover(b, v, _lock_text(br[0], model), tried)
	b.pressed.connect(func():
		if ready:
			_try_breed = ""
			Outfit.choose_breed(br[0])
			_note.text = "%s · %s · đang chọn." % [br[1], br[2]]
		elif model:
			_try_breed = "" if tried else br[0]
			_buy_id = "" if tried else br[0]
			_note.text = ("Đã bỏ xem thử %s." % br[1]) if tried else ("Đang xem thử %s · %s. %s." % [br[1], br[2], Shop.check(br[0]).text])
		else:
			_note.text = "%s · %s · đang dựng trong Blender. %s." % [br[1], br[2], br[7]]
		_refresh())
	return b


func _acc_tile(a: Array) -> Button:
	var ready := Outfit.in_game(a[0])
	var model := OutfitView.has_model(a[0])
	var tried: bool = _try.get(a[3], "") == a[0]
	var on := Outfit.is_worn(a[0]) and not _try.has(a[3])
	var b := _tile_button(Vector2(104, 160), on)
	b.tooltip_text = "%s · ô %s" % [a[1], Outfit.slot_name(a[3])]
	var v := _tile_body(b)
	var ic := SlotIcon.new()
	ic.slot = a[3]
	ic.color = T.RED if a[0] == "khando" else T.TEAL
	ic.custom_minimum_size = Vector2(48, 38)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ic)
	v.add_child(_name_label(a[1]))
	v.add_child(_tag(a[2]))
	if on:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", T.box(T.AMBER, 8, 4, Color(0, 0, 0, 0), 0))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.anchor_right = 1.0
		p.offset_left = 8
		p.offset_right = -8
		p.offset_top = 8
		var badge := T.label("Đang đeo", 10, T.ON_CRUST, "bold")
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(badge)
		b.add_child(p)
	if not ready:
		_lock_cover(b, v, _lock_text(a[0], model), tried)
	b.pressed.connect(func():
		if ready:
			_try.erase(a[3])
			Outfit.toggle(a[0])
			_refresh()
			_note.text = "%s %s." % ["Đã đeo" if Outfit.is_worn(a[0]) else "Đã tháo", a[1].to_lower()]
		elif model:
			if tried:
				_try.erase(a[3])
			else:
				_try[a[3]] = a[0]
			_buy_id = "" if tried else a[0]
			_refresh()
			_note.text = ("Đã bỏ thử %s." % a[1].to_lower()) if tried else ("Đang mặc thử %s · %s." % [a[1].to_lower(), Shop.check(a[0]).text])
		else:
			_note.text = "%s (ô %s) đang được dựng trong Blender, sắp có." % [a[1], Outfit.slot_name(a[3])])
	return b


const TIEM_ICON := "res://assets/textures/tiem/%s.png"


## Ô món trang trí tiệm: ảnh món, tên, độ hiếm. Đã có thì bấm để bày/cất; chưa có thì bấm để xem thử.
func _tiem_tile(id: String) -> Button:
	var own := Tiem.owned(id)
	var on := Tiem.shown(id)
	var tried := _try_tiem == id
	var b := _tile_button(Vector2(150, 190), on)
	b.tooltip_text = "%s · %s" % [Tiem.NAMES[id], TIEM_DESC[id]]
	var v := _tile_body(b)
	var img := TextureRect.new()
	img.texture = load(TIEM_ICON % id)
	img.custom_minimum_size = Vector2(0, 104)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(img)
	v.add_child(_name_label(Tiem.NAMES[id]))
	v.add_child(_tag(Shop.rarity(id)))
	if own:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", T.box(T.AMBER if on else T.SAND, 8, 4, Color(0, 0, 0, 0), 0))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.anchor_right = 1.0
		p.offset_left = 8
		p.offset_right = -8
		p.offset_top = 8
		var badge := T.label("Đang bày" if on else "Đang cất · bấm để bày", 10, T.ON_CRUST if on else T.INK, "bold")
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(badge)
		b.add_child(p)
	else:
		_lock_cover(b, v, _lock_text(id, true), tried)
	b.pressed.connect(func():
		_tiem_pick = id
		if own:
			Tiem.set_shown(id, not on)
			_note.text = "%s %s." % ["Đã bày" if not on else "Đã cất", Tiem.NAMES[id].to_lower()]
		else:
			_try_tiem = "" if tried else id
			_buy_id = "" if tried else id
			_note.text = ("Đã bỏ xem thử %s." % Tiem.NAMES[id].to_lower()) if tried else ("Đang xem thử %s · %s." % [Tiem.NAMES[id].to_lower(), Shop.check(id).text])
		_refresh())
	return b


func _set_card(s: Array) -> Control:
	var items: Array = s[2]
	var ready := 0
	var worn := 0
	var models := 0
	var tried := 0
	for id in items:
		if Outfit.in_game(id):
			ready += 1
		if OutfitView.has_model(id):
			models += 1
		if _try.get(Outfit.acc(id)[3], "") == id:
			tried += 1
		if Outfit.is_worn(id):
			worn += 1
	var all_ready := ready == items.size()
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on := all_ready and worn == items.size()
	card.add_theme_stylebox_override("panel", T.box(Color("#FFF1D6") if on else T.PAPER, 18, 14, T.CRUST if on else T.INK, 4 if on else 3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_child(T.label(s[0], 20, T.INK, "display"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(T.label("%d món" % items.size(), 13, T.MUTED, "bold"))
	v.add_child(top)
	var d := T.label(s[1], 13, T.MUTED, "body")
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(d)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	for id in items:
		var a := Outfit.acc(id)
		var chip := PanelContainer.new()
		var have := Outfit.in_game(id)
		chip.add_theme_stylebox_override("panel", T.box(T.SAND if have else Color("#EDE6D6"), 999, 8, Color(0, 0, 0, 0), 0))
		chip.add_child(T.label(a[1], 11, T.INK if have else Color("#8A7B5C"), "bold"))
		chip.tooltip_text = a[1] + ("" if have else " · sắp có")
		flow.add_child(chip)
	v.add_child(flow)
	var b: Button
	if all_ready:
		b = T.button("Đang mặc cả bộ" if on else "Mặc cả bộ", "primary" if not on else "secondary", 44, 15)
		b.disabled = on
		b.pressed.connect(func():
			for id in items:
				Outfit.wear(id)
			_refresh()
			_note.text = "Đã mặc %s." % s[0].to_lower())
	elif models > 0:
		# Một ô chỉ đeo được một món: bộ có hai món cùng ô thì món sau thắng.
		var all_on := tried > 0 and tried == _set_try_count(items)
		b = T.button("Bỏ mặc thử bộ" if all_on else "Mặc thử cả bộ", "secondary" if all_on else "primary", 44, 15)
		b.tooltip_text = "Chỉ xem trên bục" + ("" if models == items.size() else " · %d món còn đang dựng" % (items.size() - models))
		b.pressed.connect(func():
			for id in items:
				var slot: String = Outfit.acc(id)[3]
				if all_on:
					if _try.get(slot, "") == id:
						_try.erase(slot)
				elif OutfitView.has_model(id) and not Outfit.in_game(id):
					_try[slot] = id
			_refresh()
			_note.text = ("Đã bỏ thử %s." % s[0].to_lower()) if all_on else ("Đang mặc thử %s trên bục." % s[0].to_lower()))
	else:
		b = T.button("Đang dựng · %d/%d món" % [models, items.size()], "secondary", 44, 15)
		b.disabled = true
		b.tooltip_text = "Các món trong bộ đang được dựng trong Blender"
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	return card


## Số món của bộ còn lại trên bục khi mặc thử cả bộ (mỗi ô một món, món sau thắng).
func _set_try_count(items: Array) -> int:
	var slots := {}
	for id in items:
		if OutfitView.has_model(id) and not Outfit.in_game(id):
			slots[Outfit.acc(id)[3]] = id
	return slots.size()


func open() -> void:
	visible = true


## Xong: bỏ hết đồ mặc thử, Bơ trên bục và trong màn chơi chỉ mặc đồ đã có.
func close() -> void:
	if _trying():
		_clear_try()
		_refresh()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Biểu tượng ô gắn vẽ bằng nét: mũ, kính, khăn, túi, nơ đuôi, tất.
class SlotIcon:
	extends Control
	var slot := "head"
	var color := Color.TEAL
	var plus := false

	func _draw() -> void:
		var s := minf(size.x / 40.0, size.y / 30.0)
		var o := (size - Vector2(40, 30) * s) / 2.0
		var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
		var w := 2.6 * s
		var ink := UiTheme.INK
		if plus:
			color = Color(color, 0.55)
		match slot:
			"head":
				var dome := PackedVector2Array()
				for i in 13:
					var a := PI + PI * i / 12.0
					dome.append(p.call(20 + cos(a) * 11, 21 + sin(a) * 12))
				draw_colored_polygon(dome, color)
				draw_polyline(dome, ink, w, true)
				draw_line(p.call(4, 22), p.call(36, 22), ink, w * 1.3, true)
			"face":
				for x in [12.0, 28.0]:
					draw_circle(p.call(x, 16), 6.5 * s, Color(color, 0.35))
					draw_arc(p.call(x, 16), 6.5 * s, 0, TAU, 20, ink, w, true)
				draw_line(p.call(18.5, 15), p.call(21.5, 15), ink, w, true)
			"neck":
				var band := PackedVector2Array([p.call(5, 8), p.call(20, 14), p.call(35, 8), p.call(35, 13), p.call(20, 19), p.call(5, 13)])
				draw_colored_polygon(band, color)
				var tail := PackedVector2Array([p.call(22, 15), p.call(29, 27), p.call(24, 28), p.call(18, 17)])
				draw_colored_polygon(tail, color.darkened(0.15))
				band.append(band[0])
				draw_polyline(band, ink, w * 0.8, true)
				tail.append(tail[0])
				draw_polyline(tail, ink, w * 0.8, true)
			"back":
				draw_arc(p.call(20, 12), 9 * s, PI, TAU, 12, ink, w, true)
				var bag := Rect2(p.call(9, 11), Vector2(22, 15) * s)
				draw_rect(bag, color)
				draw_rect(bag, ink, false, w)
				draw_line(p.call(9, 17), p.call(31, 17), ink, w * 0.7, true)
			"tail":
				var l := PackedVector2Array([p.call(20, 15), p.call(7, 7), p.call(7, 23)])
				var r := PackedVector2Array([p.call(20, 15), p.call(33, 7), p.call(33, 23)])
				for t in [l, r]:
					draw_colored_polygon(t, color)
					t.append(t[0])
					draw_polyline(t, ink, w * 0.8, true)
				draw_circle(p.call(20, 15), 3.2 * s, ink)
			"feet":
				var sock := PackedVector2Array([p.call(13, 3), p.call(23, 3), p.call(23, 18), p.call(33, 21), p.call(33, 27), p.call(13, 27)])
				draw_colored_polygon(sock, color)
				draw_line(p.call(13, 9), p.call(23, 9), Color.WHITE, w, true)
				sock.append(sock[0])
				draw_polyline(sock, ink, w * 0.8, true)
		if plus:
			var c: Vector2 = p.call(34, 6)
			draw_circle(c, 6 * s, UiTheme.PAPER)
			draw_arc(c, 6 * s, 0, TAU, 16, ink, 1.5 * s, true)
			draw_line(c + Vector2(-3, 0) * s, c + Vector2(3, 0) * s, ink, 1.8 * s)
			draw_line(c + Vector2(0, -3) * s, c + Vector2(0, 3) * s, ink, 1.8 * s)


class CatFace:
	extends Control
	var fur := Color.ORANGE
	var belly := Color.WHITE
	var eye := Color.YELLOW
	func _draw() -> void:
		var head := PackedVector2Array([Vector2(8, 54), Vector2(6, 30), Vector2(12, 4), Vector2(24, 16), Vector2(40, 16), Vector2(52, 4), Vector2(58, 30), Vector2(56, 54)])
		draw_colored_polygon(head, fur)
		draw_colored_polygon(PackedVector2Array([Vector2(22, 54), Vector2(32, 42), Vector2(42, 54)]), belly)
		head.append(head[0])
		draw_polyline(head, UiTheme.INK, 3.0, true)
		for x in [23, 41]:
			draw_circle(Vector2(x, 32), 4.5, eye)
			draw_arc(Vector2(x, 32), 4.5, 0, TAU, 16, UiTheme.INK, 1.5, true)
