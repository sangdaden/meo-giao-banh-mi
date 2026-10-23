class_name HudHinh
extends RefCounted
## Hình vẽ nhỏ của HUD phố (ổ bánh tiến độ, túi, mũi tên mép màn hình, huy hiệu, tem, trứng). Tách từ hud.gd.

## Ổ bánh mì trong hàng tiến độ: done (cam), late (đỏ), current (viền vàng nét đứt), todo (viền mờ).
class LoafIcon:
	extends Control
	var state := "todo"

	func _draw() -> void:
		var pts := PackedVector2Array()
		var w := size.x
		var h := size.y
		for i in 25:
			var a := PI + PI * i / 24.0
			pts.append(Vector2(w / 2 + cos(a) * (w / 2 - 2), h * 0.6 + sin(a) * (h * 0.5)))
		for i in 25:
			var a := PI * i / 24.0
			pts.append(Vector2(w / 2 + cos(a) * (w / 2 - 3), h * 0.62 + sin(a) * (h * 0.3)))
		var outline := pts.duplicate()
		outline.append(pts[0])
		match state:
			"done", "late":
				draw_colored_polygon(pts, UiTheme.CRUST if state == "done" else UiTheme.RED)
				draw_polyline(outline, UiTheme.PAPER, 2.0, true)
				if state == "done":
					for x in [0.32, 0.5, 0.68]:
						draw_line(Vector2(w * x - 2, h * 0.35), Vector2(w * x + 2, h * 0.62), UiTheme.CRUST_DARK, 2.0, true)
				else:
					draw_line(Vector2(w * 0.38, h * 0.3), Vector2(w * 0.62, h * 0.75), UiTheme.PAPER, 2.5, true)
					draw_line(Vector2(w * 0.62, h * 0.3), Vector2(w * 0.38, h * 0.75), UiTheme.PAPER, 2.5, true)
			"current":
				for i in range(0, outline.size() - 1, 2):
					draw_line(outline[i], outline[i + 1], UiTheme.AMBER, 2.5, true)
			_:
				draw_polyline(outline, Color(UiTheme.PAPER, 0.6), 2.0, true)


class BagIcon:
	extends Control
	func _draw() -> void:
		draw_style_box(UiTheme.box(UiTheme.TEAL, 6, 0, UiTheme.INK, 2), Rect2(3, 8, 34, 24))
		draw_arc(Vector2(20, 8), 7, PI, TAU, 12, UiTheme.INK, 2.5, true)
		draw_line(Vector2(10, 15), Vector2(31, 14), UiTheme.CRUST, 5.0, true)


## Mũi tên đỏ ở mép màn hình chỉ về phía điểm đến khi nó nằm ngoài khung hình.
class EdgeArrow:
	extends Control
	var _pos := Vector2.ZERO
	var _dir := Vector2.RIGHT
	var _show := false

	func update_goal(cam: Camera3D, goal: Vector3) -> void:
		_show = false
		if cam == null:
			queue_redraw()
			return
		var vp := size
		var margin := 70.0
		var behind := cam.is_position_behind(goal)
		var p := cam.unproject_position(goal)
		if behind:
			p = vp - p  # đằng sau: lật lại để mũi tên chỉ đúng phía
		var inside := not behind and p.x > margin and p.x < vp.x - margin and p.y > margin and p.y < vp.y - margin
		if not inside:
			var c := vp / 2.0
			var d := (p - c)
			if d.length() < 1.0:
				d = Vector2.DOWN
			if behind and absf(d.y) < absf(d.x) * 0.2:
				d.y = absf(d.x) * 0.2
			_dir = d.normalized()
			var half := c - Vector2(margin, margin)
			var t := minf(half.x / maxf(absf(_dir.x), 0.001), half.y / maxf(absf(_dir.y), 0.001))
			_pos = c + _dir * t
			_show = true
		queue_redraw()

	func _draw() -> void:
		if not _show:
			return
		var a := _dir.angle()
		var pts := PackedVector2Array([Vector2(26, 0), Vector2(-16, -22), Vector2(-8, 0), Vector2(-16, 22)])
		for i in pts.size():
			pts[i] = _pos + pts[i].rotated(a)
		draw_colored_polygon(pts, UiTheme.RED)
		pts.append(pts[0])
		draw_polyline(pts, UiTheme.PAPER, 4.0, true)


## Huy hiệu nhiệm vụ phụ: khiên tròn, đạt thì vàng có dấu tích, chưa đạt thì xám rỗng.
class BadgeIcon:
	extends Control
	var earned := false
	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var ribbon := PackedVector2Array([c + Vector2(-r * 0.6, r * 0.2), c + Vector2(-r * 0.75, r + 2), c + Vector2(-r * 0.2, r * 0.75),
			c + Vector2(r * 0.2, r * 0.75), c + Vector2(r * 0.75, r + 2), c + Vector2(r * 0.6, r * 0.2)])
		draw_colored_polygon(ribbon, UiTheme.RED if earned else Color("#C9BFA8"))
		draw_circle(c + Vector2(0, -1), r * 0.82, UiTheme.AMBER if earned else UiTheme.SAND)
		draw_arc(c + Vector2(0, -1), r * 0.82, 0, TAU, 24, UiTheme.INK, 2.0, true)
		if earned:
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.35, -1), c + Vector2(-r * 0.08, r * 0.28 - 1), c + Vector2(r * 0.4, -r * 0.32 - 1)]), UiTheme.INK, 2.5, true)


## Tem Cô Ba: ổ bánh có nơ đỏ trên con tem răng cưa. Chưa nhặt thì chỉ còn viền mờ.
class StampIcon:
	extends Control
	var found := false
	func _draw() -> void:
		var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var col := UiTheme.PAPER if found else Color(1, 1, 1, 0.0)
		draw_rect(rect, col)
		var edge := UiTheme.INK if found else Color("#B5A88A")
		draw_rect(rect, edge, false, 1.5)
		for x in range(4, int(size.x) - 3, 5):
			draw_circle(Vector2(x, 2), 1.3, Color("#F6EDDA"))
			draw_circle(Vector2(x, size.y - 2), 1.3, Color("#F6EDDA"))
		var c := size / 2.0 + Vector2(0, 1)
		var loaf := PackedVector2Array()
		for k in 16:
			var a := TAU * k / 16.0
			loaf.append(c + Vector2(cos(a) * size.x * 0.3, sin(a) * size.y * 0.2))
		draw_colored_polygon(loaf, UiTheme.CRUST if found else Color("#D9CFB8"))
		if found:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2), c + Vector2(-5, -6), c + Vector2(-5, 2)]), UiTheme.RED)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2), c + Vector2(5, -6), c + Vector2(5, 2)]), UiTheme.RED)


## Quả trứng nhỏ cho chỉ báo số trứng: trứng nguyên màu kem, trứng vỡ nứt đôi, lòng đỏ chảy ra.
class EggIcon:
	extends Control
	var broken := false

	func _draw() -> void:
		var c := size / 2.0
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			var r := Vector2(size.x * 0.42, size.y * 0.46)
			var squash := 1.0 - 0.18 * maxf(0.0, sin(a))  # đầu dưới tròn hơn, đầu trên thon
			pts.append(c + Vector2(cos(a) * r.x * squash, sin(a) * r.y))
		var ink := UiTheme.INK
		if broken:
			draw_circle(c + Vector2(0, size.y * 0.22), size.x * 0.32, Color(UiTheme.AMBER, 0.75))
			draw_colored_polygon(pts, Color("#CFC6B4"))
			var crack := PackedVector2Array([c + Vector2(-size.x * 0.4, -2), c + Vector2(-size.x * 0.15, 3),
				c + Vector2(0, -3), c + Vector2(size.x * 0.17, 3), c + Vector2(size.x * 0.4, -2)])
			draw_polyline(crack, ink, 1.8, true)
		else:
			draw_colored_polygon(pts, Color("#FFF4DC"))
			draw_circle(c + Vector2(-size.x * 0.12, -size.y * 0.16), size.x * 0.08, Color(1, 1, 1, 0.9))
		pts.append(pts[0])
		draw_polyline(pts, ink, 2.0, true)
