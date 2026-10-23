class_name BanDoNho
extends Control
## Bản đồ nhỏ góc trên bên phải và bản đồ lớn (phím B). Sang 22/10: cần một bản đồ nhỏ hiện nhiệm vụ và chỉ đường.
##
## Bản đồ nhỏ xoay theo camera: phía trên bản đồ là hướng camera đang nhìn, nên "đường chấm đi lên" là "chạy thẳng tới".
## Bản đồ lớn luôn để bắc ở trên, hiện cả khu phố, mọi ghim và tên chỗ.
## Đường chấm từ Bơ tới đích tìm bằng AStarGrid2D trên lưới 0,5 m, chỉ né dãy nhà (mèo nhảy qua được thùng, ghế, rào).
## Chế độ thử thách tắt đường chấm, chỉ còn ghim (DoKho "map_path").
##
## Ghim lấy từ các node trong nhóm "ban_do_nho" có hàm ban_do_pins() -> Array[Dictionary]:
##   pos: Vector3 · kind: "bakery" | "order" | "favour" | "place" · text: chữ trong ghim (số đơn, ★, B)
##   color: màu ghim · state: "now" (đang tới) | "next" (sắp tới) | "done" (xong) · name: tên hiện ở bản đồ lớn
## Đích đang tới là hud.set_goal (cùng chỗ mũi tên đỏ ở mép màn hình), không cần ghim "now" cũng có ghim đỏ.

const T = preload("res://scripts/ui/ui_theme.gd")

const ROAD := Color("#B9B2A2")
const SIDEWALK := Color("#E7DCC4")
const HOUSE := Color("#F6E7C9")
const HOUSE_EDGE := Color("#8F7F60")
const GRASS := Color("#A9CF8E")
const ALLEY := Color("#CFC8B8")
const PATH := Color("#C8412F")

## Ô nhà đặc biệt: màu mái trên bản đồ và tên hiện ở bản đồ lớn
const SPECIAL := {
	"lo_banh": [Color("#E8B36A"), "Lò Cô Ba"],
	"chung_cu": [Color("#BFD8D2"), "Chung cư"],
	"cafe_may": [Color("#CFE3D6"), "Cà phê Mây"],
	"tiem_xe": [Color("#C9CFCB"), "Sửa xe"],
	"tap_hoa": [Color("#F2C9AE"), "Tạp hóa"],
}
const PLACE_NAMES := [
	["Công viên", Vector2(-33, 15)], ["Hẻm 42", Vector2(-18.5, 19)], ["Ngã tư", Vector2(-18, 0)], ["Ngã tư", Vector2(16, 0)],
]

const CELL := 0.5
const AREA := Rect2(-48, -30, 96, 60)

## Bản đồ nhỏ: số điểm ảnh mỗi mét
@export var px_per_m := 3.0
var full := false  ## true: bản đồ lớn, bắc ở trên, thấy cả khu phố

var _player: Node3D
var _goal := Vector3.ZERO
var _has_goal := false
var _pins: Array = []
var _path := PackedVector2Array()
var _path_from := Vector2i(-999, -999)
var _path_goal := Vector2i(-999, -999)
var _path_t := 0.0
var _pin_t := 0.0
var _pulse := 0.0
var _theta := 0.0  # góc xoay bản đồ
var _center_w := Vector2.ZERO  # điểm thế giới (x, z) nằm giữa bản đồ
var _scale := 3.0

static var _houses: Array = []  # [Rect2, Color]
static var _grid: AStarGrid2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build_static()


func set_goal(world_pos: Vector3, on: bool) -> void:
	_goal = world_pos
	_has_goal = on


func path_on() -> bool:
	return bool(DoKho.v("map_path", false))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_pulse += delta
	_pin_t -= delta
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
	if _pin_t <= 0.0:
		_pin_t = 0.25
		_pins = _collect_pins()
	_path_t -= delta
	if _path_t <= 0.0:
		_path_t = 0.3
		_update_path()
	queue_redraw()


func _find_player() -> Node3D:
	var s := get_tree().current_scene
	if s and "player" in s and s.player is Node3D:
		return s.player
	return null


func _collect_pins() -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group("ban_do_nho"):
		if n.has_method("ban_do_pins"):
			out.append_array(n.ban_do_pins())
	return out


# ---------------------------------------------------------------- dữ liệu tĩnh

## Dãy nhà theo đúng cách City._block xếp: mỗi khối hai dãy, cách mép 2 m, giữa có hẻm 2,4 m.
static func _build_static() -> void:
	if _grid != null:
		return
	_houses.clear()
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, int(AREA.size.x / CELL), int(AREA.size.y / CELL))
	_grid.cell_size = Vector2(CELL, CELL)
	_grid.offset = AREA.position + Vector2(CELL, CELL) * 0.5
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	for i in City.BLOCKS.size():
		if i == City.PARK_INDEX:
			continue
		var r: Rect2 = City.BLOCKS[i]
		var inset := 2.0
		var depth := (r.size.y - inset * 2 - 2.4) / 2.0
		for row in 2:
			var z0 := r.position.y + inset + row * (depth + 2.4)
			var x := r.position.x + inset
			var x_end := r.end.x - inset
			# Chia dãy theo ô đặc biệt để tô màu riêng và chừa khe hông tiệm xe
			var slots := CityProps.SLOTS.filter(func(s): return s.block == i and s.row == row)
			slots.sort_custom(func(a, b): return a.x0 < b.x0)
			for s in slots:
				if s.x0 > x:
					_add_house(Rect2(x, z0, s.x0 - x, depth), HOUSE)
				if s.kind != "khe_hong":
					_add_house(Rect2(s.x0, z0, s.x1 - s.x0, depth), SPECIAL.get(s.kind, [HOUSE])[0], s.kind)
				x = s.x1
			if x < x_end:
				_add_house(Rect2(x, z0, x_end - x, depth), HOUSE)


static func _add_house(r: Rect2, col: Color, kind := "") -> void:
	_houses.append([r, col, kind])
	var a := _cell(r.position + Vector2(0.15, 0.15))
	var b := _cell(r.end - Vector2(0.15, 0.15))
	for cx in range(a.x, b.x + 1):
		for cy in range(a.y, b.y + 1):
			if _grid.is_in_boundsv(Vector2i(cx, cy)):
				_grid.set_point_solid(Vector2i(cx, cy), true)


static func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - AREA.position.x) / CELL), floori((p.y - AREA.position.y) / CELL))


## Ô trống gần nhất (đích nằm sát tường hay trên ban công thì tìm ô đứng được bên dưới).
static func _free_cell(c: Vector2i) -> Vector2i:
	c = c.clamp(Vector2i.ZERO, _grid.region.size - Vector2i.ONE)
	if not _grid.is_point_solid(c):
		return c
	for r in range(1, 16):
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				for q in [Vector2i(dx, dy), Vector2i(dy, dx)]:
					var n: Vector2i = c + q
					if _grid.is_in_boundsv(n) and not _grid.is_point_solid(n):
						return n
	return c


## Đường đi (x, z) từ a tới b, rỗng nếu không tìm được.
static func find_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	_build_static()
	var ca := _free_cell(_cell(a))
	var cb := _free_cell(_cell(b))
	var pts := _grid.get_point_path(ca, cb)
	return _simplify(pts)


## Bỏ điểm thẳng hàng cho đường chấm đều, đỡ tốn lệnh vẽ.
static func _simplify(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var d1 := (pts[i] - pts[i - 1]).normalized()
		var d2 := (pts[i + 1] - pts[i]).normalized()
		if d1.dot(d2) < 0.999:
			out.append(pts[i])
	out.append(pts[pts.size() - 1])
	return out


func _update_path() -> void:
	if not _has_goal or _player == null or not path_on():
		_path = PackedVector2Array()
		return
	var p := Vector2(_player.global_position.x, _player.global_position.z)
	var g := Vector2(_goal.x, _goal.z)
	if not AREA.grow(2.0).has_point(p):
		_path = PackedVector2Array()
		return
	var cp := _cell(p)
	var cg := _cell(g)
	if cp == _path_from and cg == _path_goal:
		return
	_path_from = cp
	_path_goal = cg
	_path = find_path(p, g)
	if _path.size() > 0:
		_path[0] = p
		if g.distance_to(_path[_path.size() - 1]) < 3.0:
			_path.append(g)


# ---------------------------------------------------------------- vẽ

func _view() -> void:
	if full:
		_theta = 0.0
		_center_w = AREA.get_center()
		_scale = minf((size.x - 40.0) / AREA.size.x, (size.y - 40.0) / AREA.size.y)
		return
	_scale = px_per_m
	if _player:
		_center_w = Vector2(_player.global_position.x, _player.global_position.z)
	var cam := get_viewport().get_camera_3d()
	if cam:
		var f := -cam.global_basis.z
		var f2 := Vector2(f.x, f.z)
		if f2.length() > 0.05:
			_theta = f2.angle_to(Vector2(0, -1))


## Điểm thế giới (x, z) ra điểm trên bản đồ.
func to_map(w: Vector2) -> Vector2:
	return size / 2.0 + ((w - _center_w) * _scale).rotated(_theta)


func _draw() -> void:
	_view()
	var c := size / 2.0
	draw_rect(Rect2(Vector2.ZERO, size), ROAD)
	draw_set_transform(c - (_center_w * _scale).rotated(_theta), _theta, Vector2(_scale, _scale))
	for i in City.BLOCKS.size():
		var r: Rect2 = City.BLOCKS[i]
		draw_rect(r, GRASS if i == City.PARK_INDEX else SIDEWALK)
	# Cỏ công viên lấn ra tới bờ rào hẻm 42, lòng hẻm láng xi măng (CityProps.hem_42)
	draw_rect(Rect2(-22.0, CityProps.HEM42_Z.x, 22.0 + CityProps.HEM42_X.x - 0.3, CityProps.HEM42_Z.y - CityProps.HEM42_Z.x), GRASS)
	draw_rect(Rect2(CityProps.HEM42_X.x, CityProps.HEM42_Z.x, CityProps.HEM42_X.y - CityProps.HEM42_X.x, CityProps.HEM42_Z.y - CityProps.HEM42_Z.x), ALLEY)
	var edge_w := 1.6 / _scale
	for h in _houses:
		draw_rect(h[0], h[1])
		draw_rect(h[0], HOUSE_EDGE, false, edge_w)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_path()
	if full:
		_draw_names()
	_draw_pins()
	_draw_player()
	if not full:
		_draw_north()


func _draw_path() -> void:
	if _path.size() < 2:
		return
	# Đường chấm tròn đều nhau, trôi nhẹ về phía đích
	var step := 9.0 if not full else 11.0
	var phase := fmod(_pulse * 14.0, step)
	var carry := step - phase
	for i in range(_path.size() - 1):
		var a := to_map(_path[i])
		var b := to_map(_path[i + 1])
		var seg := a.distance_to(b)
		var t := carry
		while t <= seg:
			var p := a.lerp(b, t / seg)
			draw_circle(p, 3.2, T.PAPER)
			draw_circle(p, 2.2, PATH)
			t += step
		carry = t - seg


func _draw_names() -> void:
	var f := T.font("bold")
	for h in _houses:
		if h[2] != "" and SPECIAL.has(h[2]):
			var r: Rect2 = h[0]
			_text(f, to_map(r.get_center()), SPECIAL[h[2]][1], 13, T.INK, T.PAPER)
	for pn in PLACE_NAMES:
		_text(f, to_map(pn[1]), pn[0], 12, T.MUTED, Color(T.PAPER, 0.8))


func _text(f: Font, at: Vector2, s: String, fs: int, col: Color, outline: Color) -> void:
	s = tr(s)  # draw_string không tự dịch như Label (bản tiếng Anh, scripts/ngon_ngu.gd)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := at + Vector2(-w / 2.0, fs * 0.35)
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, outline)
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_pins() -> void:
	var f := T.font("display")
	var goal_drawn := false
	# Ghim xong vẽ trước, ghim đang tới vẽ sau cùng cho nổi lên trên
	var order := {"done": 0, "next": 1, "now": 2}
	var pins := _pins.duplicate()
	pins.sort_custom(func(a, b): return order.get(a.get("state", "next"), 1) < order.get(b.get("state", "next"), 1))
	for pin in pins:
		var now: bool = pin.get("state", "next") == "now" or (_has_goal and Vector2(pin.pos.x, pin.pos.z).distance_to(Vector2(_goal.x, _goal.z)) < 1.5)
		if now:
			if goal_drawn:
				continue
			goal_drawn = true
		_pin(f, pin, now)
	if _has_goal and not goal_drawn:
		_pin(f, {"pos": _goal, "kind": "goal", "text": "", "color": T.RED, "state": "now"}, true)


func _pin(f: Font, pin: Dictionary, now: bool) -> void:
	var w := Vector2(pin.pos.x, pin.pos.z)
	var p := to_map(w)
	var state: String = pin.get("state", "next")
	var col: Color = pin.get("color", T.CRUST)
	var r := 11.0 if now else (8.0 if state == "next" else 6.5)
	if full:
		r *= 1.15
	var margin := r + 4.0
	var box := Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2.0)
	var off := not box.has_point(p)
	if off:
		if not now:
			return  # ghim phụ ra khỏi bản đồ nhỏ thì thôi, chỉ đích đang tới bám mép
		var c := size / 2.0
		var d := (p - c)
		var t := minf(box.size.x / 2.0 / maxf(absf(d.x), 0.001), box.size.y / 2.0 / maxf(absf(d.y), 0.001))
		p = c + d * t
		var a := d.angle()
		var tip := PackedVector2Array([p + Vector2(r + 9, 0).rotated(a), p + Vector2(r - 1, -7).rotated(a), p + Vector2(r - 1, 7).rotated(a)])
		draw_colored_polygon(tip, T.RED)
	if now:
		var k := fmod(_pulse, 1.2) / 1.2
		draw_arc(p, r + 3.0 + k * 10.0, 0, TAU, 32, Color(T.RED, 0.7 * (1.0 - k)), 3.0, true)
		col = T.RED if pin.get("kind", "") in ["goal", "order", "favour"] else col
	if state == "done" and not now:
		draw_circle(p, r, Color(T.PAPER, 0.85))
		draw_arc(p, r, 0, TAU, 20, Color(T.INK, 0.45), 1.5, true)
		draw_polyline(PackedVector2Array([p + Vector2(-r * 0.45, 0), p + Vector2(-r * 0.1, r * 0.38), p + Vector2(r * 0.5, -r * 0.4)]), T.LEAF, 2.2, true)
		return
	draw_circle(p + Vector2(0, 2), r, Color(T.INK, 0.35))
	draw_circle(p, r, col if state != "next" or now else col.lerp(T.PAPER, 0.15))
	draw_arc(p, r, 0, TAU, 24, T.PAPER if now else T.INK, 2.5 if now else 2.0, true)
	var s: String = str(pin.get("text", ""))
	if pin.get("kind", "") == "favour" and s == "":
		s = "♥"
	if s != "" and r >= 7.0:
		var fs := int(r * (1.25 if s.length() < 2 else 0.95))
		var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, p + Vector2(-sw / 2.0, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, T.PAPER if now or col.get_luminance() < 0.55 else T.INK)
	if full and str(pin.get("name", "")) != "":
		_text(T.font("bold"), p + Vector2(0, r + 12), pin.name, 13, T.INK, T.PAPER)


## Bơ: chấm cam viền mực, có quạt sáng chỉ hướng camera đang nhìn.
func _draw_player() -> void:
	if _player == null:
		return
	var p := to_map(Vector2(_player.global_position.x, _player.global_position.z))
	var up := Vector2(0, -1)
	if full:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var f := -cam.global_basis.z
			if Vector2(f.x, f.z).length() > 0.05:
				up = Vector2(f.x, f.z).normalized()
	var a := up.angle()
	var fan := PackedVector2Array([p])
	for k in 9:
		fan.append(p + Vector2(30, 0).rotated(a - 0.5 + k / 8.0))
	draw_colored_polygon(fan, Color(T.PAPER, 0.45))
	draw_circle(p + Vector2(0, 1.5), 8.0, Color(T.INK, 0.35))
	draw_circle(p, 8.0, T.FUR)
	draw_arc(p, 8.0, 0, TAU, 24, T.INK, 2.5, true)
	var tri := PackedVector2Array([p + Vector2(7, 0).rotated(a), p + Vector2(-3, -4.5).rotated(a), p + Vector2(-3, 4.5).rotated(a)])
	draw_colored_polygon(tri, T.INK)


## Chữ B (bắc) chạy quanh mép bản đồ nhỏ khi bản đồ xoay.
func _draw_north() -> void:
	var c := size / 2.0
	var d := Vector2(0, -1).rotated(_theta)
	var half := c - Vector2(14, 14)
	var t := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
	var p := c + d * t
	draw_circle(p, 10.0, T.INK)
	var f := T.font("display")
	var sw := f.get_string_size("B", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(f, p + Vector2(-sw / 2.0, 5), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, T.PAPER)
