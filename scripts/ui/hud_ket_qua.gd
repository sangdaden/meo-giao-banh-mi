class_name HudKetQua
extends RefCounted
## Bảng kết quả cuối ca của HUD phố (hud.show_results gọi build). Tách từ hud.gd để sửa bảng kết quả không đụng HUD chính.

const T = preload("res://scripts/ui/ui_theme.gd")
const PAPER := Color("#FFF8EA")
const INK := Color("#1F3A3D")
const CRUST := Color("#D98E2B")
const RED := Color("#C8412F")


const RANKS := {
	"thuong": ["Bánh mì thường", "#E7DCC4", 1],
	"gion": ["Bánh mì giòn", "#D98E2B", 2],
	"vang": ["Bánh mì vàng", "#F7D35E", 3],
}


## 85000 -> "85.000đ"
static func money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out + "đ"


static func build(hud: Node, rows: Array, summary := {}) -> Control:
	var scr := Control.new()
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = T.TEAL
	scr.add_child(T.full_rect(bg))

	var total := 0
	var on_time := 0
	var has_tip := summary.has("tip")
	for r in rows:
		total += int(r.stars)
		on_time += 1 if r.stars > 0 and not r.get("late", false) else 0
		has_tip = has_tip or r.has("tip")
	total = int(summary.get("stars", total))
	var stars_max := int(summary.get("stars_max", 15))
	# Hạng ngày: luồng chấm điểm gửi sẵn; thiếu thì tự tính theo cùng ngưỡng (<8, 8–12, ≥13)
	var rank: String = summary.get("rank", "vang" if total >= 13 else ("gion" if total >= 8 else "thuong"))
	var rk: Array = RANKS.get(rank, RANKS.thuong)

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 8)
	T.place(left, 0.5, 0.5, Rect2(-600, -330, 436, 660))
	scr.add_child(left)
	var day: String = summary.get("day", "")
	var title := T.label("Hết ca %s!" % day if day != "" else "Hết ca giao bánh!", 46, PAPER, "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(title)
	var big := T.StarRow.new()
	big.filled = rk[2]
	big.empty_color = Color("#256569")
	big.custom_minimum_size = Vector2(3 * 72 + 8, 68)
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(big)
	# Huy chương hạng ngày
	var medal := PanelContainer.new()
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	medal.add_theme_stylebox_override("panel", T.box(Color(rk[1]), 999, 22, INK, 3, 5))
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 12)
	medal.add_child(mh)
	var loaf := HudHinh.LoafIcon.new()
	loaf.state = "done"
	loaf.custom_minimum_size = Vector2(44, 28)
	loaf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mh.add_child(loaf)
	mh.add_child(T.label(rk[0], 24, T.ON_CRUST if rank != "thuong" else INK, "display"))
	left.add_child(medal)
	var tl := T.label("%d / %d sao" % [total, stars_max], 30, T.AMBER, "display")
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(tl)
	if summary.get("new_record", false):
		var rec := PanelContainer.new()
		rec.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rec.add_theme_stylebox_override("panel", T.box(RED, 999, 14, PAPER, 2))
		rec.add_child(T.label("Kỷ lục mới!", 15, PAPER, "bold"))
		left.add_child(rec)

	# Thẻ tiền boa
	if has_tip:
		var tip_total := int(summary.get("tip", 0))
		if not summary.has("tip"):
			for r in rows:
				tip_total += int(r.get("tip", 0))
		var tc := PanelContainer.new()
		tc.add_theme_stylebox_override("panel", T.box(PAPER, 20, 16, INK, 3, 6))
		tc.custom_minimum_size.x = 340
		tc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 2)
		tc.add_child(tv)
		var th := HBoxContainer.new()
		th.add_child(T.label("Tiền boa hôm nay", 16, T.MUTED, "bold"))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		th.add_child(sp)
		th.add_child(T.label(money(tip_total), 30, T.LEAF, "display"))
		tv.add_child(th)
		var bonus := int(summary.get("bonus", 0))
		if bonus > 0:
			tv.add_child(T.label("Gồm %s Cô Ba thưởng vì đủ %d sao" % [money(bonus), stars_max], 13, CRUST, "bold"))
		elif summary.has("bonus"):
			tv.add_child(T.label("Đủ %d sao thì Cô Ba thưởng thêm %s" % [stars_max, money(20000)], 13, T.MUTED, "bold"))
		if summary.has("wallet"):
			tv.add_child(T.label("Trong ví: %s · dùng mở đồ trong tủ" % money(int(summary.wallet)), 13, T.MUTED, "body"))
		left.add_child(tc)
	else:
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", T.box(Color("#8DBDB3"), 24, 0, INK, 4))
		frame.custom_minimum_size = Vector2(300, 200)
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		var pic := TextureRect.new()
		pic.texture = load("res://assets/ui/bo_menu.jpg")
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame.add_child(pic)
		left.add_child(frame)
	var praise := "Khách khen bánh còn nóng giòn!" if on_time == rows.size() else ("Ca này ổn, còn vài đơn trễ." if on_time >= 3 else "Ca vất vả quá, thử lại nhé!")
	var pl := T.label(praise, 16, T.CREAM, "bold")
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(pl)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", T.box(PAPER, 26, 24, INK, 4, 8))
	T.place(panel, 0.5, 0.5, Rect2(-128, -330, 728, 660))
	scr.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(T.label(summary.get("rows_title", "Năm đơn sáng nay"), 28, INK, "display"))
	for i in rows.size():
		v.add_child(_result_row(rows[i], i, has_tip))

	# Huy hiệu nhiệm vụ phụ và tem Cô Ba
	var quests := 0
	var quests_ok := 0
	for r in rows:
		if str(r.get("side_quest", "")) != "":
			quests += 1
			quests_ok += 1 if r.get("side_ok", false) else 0
	if quests > 0 or summary.has("stamps"):
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 10)
		if quests > 0:
			strip.add_child(_mini_panel("Huy hiệu", "%d/%d" % [quests_ok, quests], _badge_row(rows)))
		if summary.has("stamps"):
			var n := int(summary.stamps)
			var of := int(summary.get("stamps_total", 5))
			var stamps := HBoxContainer.new()
			stamps.add_theme_constant_override("separation", 4)
			for k in of:
				var st := HudHinh.StampIcon.new()
				st.found = k < n
				st.custom_minimum_size = Vector2(30, 24)
				stamps.add_child(st)
			var sub := "%d/%d" % [n, of]
			if summary.has("stamps_all"):
				sub += " · tổng %d/35" % int(summary.stamps_all)
			strip.add_child(_mini_panel("Tem Cô Ba", sub, stamps))
		v.add_child(strip)

	var unlock := PanelContainer.new()
	var us := T.box(Color(0, 0, 0, 0), 14, 10, CRUST, 3)
	unlock.add_theme_stylebox_override("panel", us)
	var uh := HBoxContainer.new()
	uh.add_theme_constant_override("separation", 14)
	unlock.add_child(uh)
	var uv := VBoxContainer.new()
	uv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var need := rows.size() - on_time
	uv.add_child(T.label("Đã mở skin Vỏ Bánh Giòn!" if need == 0 else "Còn %d đơn kịp giờ nữa là mở skin Vỏ Bánh Giòn" % need, 15, INK, "bold"))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = maxi(rows.size(), 1)
	bar.value = on_time
	bar.add_theme_stylebox_override("background", T.box(T.SAND, 999, 0, INK, 2))
	bar.add_theme_stylebox_override("fill", T.box(CRUST, 999, 0, INK, 2))
	uv.add_child(bar)
	uh.add_child(uv)
	uh.add_child(T.label("%d/%d" % [on_time, rows.size()], 20, INK, "display"))
	v.add_child(unlock)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)
	# Chơi liền các ngày: Enter sang ngày kế, Chơi lại ca thành nút phụ, Về menu về thẳng trang chủ.
	var first: Button
	if PlayMode.continuous:
		var next := T.button("  " + PlayMode.next_label(), "primary", 58, 20)
		next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next.pressed.connect(func(): PlayMode.go_next_day(hud.get_tree()))
		hud._add_key_hint(next, "Enter", T.ON_CRUST)
		foot.add_child(next)
		first = next
	var again := T.button("  Chơi lại ca", "secondary" if PlayMode.continuous else "primary", 58, 20)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func(): hud.restart_pressed.emit())
	if not PlayMode.continuous:
		hud._add_key_hint(again, "Enter", T.ON_CRUST)
		first = again
	foot.add_child(again)
	var home := T.button("Về menu", "secondary", 58, 20)
	if PlayMode.continuous:
		home.pressed.connect(func(): PlayMode.go_home(hud.get_tree()))
	else:
		home.pressed.connect(func(): hud.menu_pressed.emit())
	foot.add_child(home)
	first.grab_focus.call_deferred()
	return scr


static func _mini_panel(title: String, count: String, content: Control) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", T.box(Color("#F6EDDA"), 14, 10, Color(0, 0, 0, 0), 0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.add_child(T.label(title, 13, T.MUTED, "bold"))
	col.add_child(T.label(count, 17, INK, "display"))
	h.add_child(col)
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(content)
	return p


static func _badge_row(rows: Array) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for r in rows:
		var q := str(r.get("side_quest", ""))
		if q == "":
			continue
		var b := HudHinh.BadgeIcon.new()
		b.earned = r.get("side_ok", false)
		b.custom_minimum_size = Vector2(26, 26)
		b.tooltip_text = q
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(b)
	return h


static func _result_row(r: Dictionary, i: int, show_tip := false) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.box(Color("#F6EDDA") if i % 2 == 0 else Color(0, 0, 0, 0), 14, 10, Color(0, 0, 0, 0), 0))
	p.custom_minimum_size.y = 56
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var av := Panel.new()
	av.custom_minimum_size = Vector2(42, 42)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av.add_theme_stylebox_override("panel", T.box(r.get("color", CRUST), 999, 0, INK, 3))
	var who: String = r.get("who", "")
	var parts := who.split(" ")
	var ini := T.label(parts[parts.size() - 1].left(1).to_upper() if parts.size() > 0 else "?", 20, INK, "display")
	ini.set_anchors_preset(Control.PRESET_FULL_RECT)
	ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_child(ini)
	h.add_child(av)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_l := T.label("%s · %s" % [who, r.get("place", "")], 16, INK, "bold")
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_l)
	var line2 := HBoxContainer.new()
	line2.add_theme_constant_override("separation", 5)
	var sub := T.label(str(r.get("item", "")), 13, Color("#2C4F52"))
	line2.add_child(sub)
	if r.has("kitchen_stars"):
		line2.add_child(T.label("· bếp", 13, Color("#2C4F52")))
		var ks := T.StarRow.new()
		ks.filled = int(r.kitchen_stars)
		ks.empty_color = T.SAND
		ks.custom_minimum_size = Vector2(3 * 18 + 8, 16)
		ks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line2.add_child(ks)
	var note := str(r.get("note", ""))
	if note != "":
		var nl := T.label("· " + note, 13, Color("#2C4F52"))
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		line2.add_child(nl)
	col.add_child(line2)
	h.add_child(col)
	var q := str(r.get("side_quest", ""))
	if q != "":
		var b := HudHinh.BadgeIcon.new()
		b.earned = r.get("side_ok", false)
		b.custom_minimum_size = Vector2(30, 30)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.tooltip_text = ("Đạt: " if b.earned else "Chưa đạt: ") + q
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(b)
	var stars: int = r.get("stars", 0)
	var late: bool = r.get("late", stars == 0)
	var tag := PanelContainer.new()
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_theme_stylebox_override("panel", T.box(RED if late else T.LEAF, 999, 10, Color(0, 0, 0, 0), 0))
	tag.add_child(T.label("Trễ" if late else "Kịp giờ", 12, PAPER, "bold"))
	h.add_child(tag)
	var sr := T.StarRow.new()
	sr.filled = stars
	sr.empty_color = T.SAND
	sr.custom_minimum_size = Vector2(3 * 26 + 8, 24)
	sr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sr)
	if show_tip:
		var tip := int(r.get("tip", 0))
		var tl := T.label(("+" + money(tip)) if tip > 0 else "0đ", 15, T.LEAF if tip > 0 else Color("#A89C80"), "display")
		tl.custom_minimum_size.x = 76
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(tl)
	return p
