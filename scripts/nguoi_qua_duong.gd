class_name NguoiQuaDuong
extends Node3D
## Người qua đường thật (gói P3 "Người qua đường và xe ra vào", Sang duyệt 22/10), thay 10 người khối đi tới đi lui.
## Mỗi người đi một chuyến có đầu có cuối: bước ra từ cửa nhà, từ hẻm giữa khối, từ vỉa hè vành ngoài khung bản đồ
## hoặc bước xuống xe buýt; ghé một hai chỗ (lò bánh, sạp báo, tạp hóa, cà phê Mây, công viên, góc cờ, xe ôm,
## cổng mẫu giáo, trạm xe buýt) rồi vào cửa nhà, vào hẻm, lên xe buýt hoặc đi ra vành ngoài và khuất.
## Không ai hiện ra hay biến mất trước mắt: chỉ sinh/biến mất trong cửa, trong hẻm, trên xe buýt, hoặc khi đã khuất
## (ngoài khung hình hay xa hơn HIDE_RANGE m).
##
## Đi đường: lưới AStarGrid2D 0,5 m dựng từ hộp va chạm của phố (nhà, đồ phố), lòng đường đắt gấp ROAD_WEIGHT nên
## người đi vỉa hè, chỉ băng qua đường ở chỗ ngắn nhất, đứng chờ ở mép đường tới khi không có xe tới gần.
## Đang dưới lòng đường thì traffic.gd biết (traffic.peds) nên xe máy, xe buýt phanh nhường.
## Lịch theo buổi của ngày (AnhSang preset): ai ra phố, bao nhiêu người, ghé đâu (LICH).
## Người dựng bằng Nguoi.make (bản "nhe" ~1,4k tam giác, LOD tự sinh, ẩn ngoài 30 m); chỉ người gần camera đổ bóng.

const CELL := 0.5
const AREA := Rect2(-48.0, -31.0, 96.0, 62.0)
const ROAD_WEIGHT := 6.0
## Lòng đường có xe chạy: đường lớn, đường dọc x = −18 phía bắc (phía nam là hẻm 42, không xe), đường dọc x = 16
const ROADS := [Rect2(-48.0, -5.0, 96.0, 10.0), Rect2(-22.0, -31.0, 8.0, 26.0), Rect2(12.0, -31.0, 8.0, 62.0)]
## Lòng ngã tư: không ai băng chéo qua giữa ngã tư
const JUNCTIONS := [Rect2(-22.2, -5.2, 8.4, 10.4), Rect2(11.8, -5.2, 8.4, 10.4)]
const NEAR_MAX := 14
const HIDE_RANGE := 35.0
const SHADOW_RANGE := 10.0
const DRAW_RANGE := 26.0          ## người qua đường xa hơn thì thôi vẽ (người dân đứng yên vẫn 30 m)
const OUT_LEN := 14.0           ## đi tiếp ra vành ngoài chừng này mét rồi khuất
const CROSS_LOOK := 15.0        ## xe trong tầm này đang chạy tới thì đứng chờ ở mép đường
const CROSS_WAIT_MAX := 14.0
const SPAWN_EVERY := 2.2
const BOARD_MAX := 4            ## mỗi lần xe buýt đỗ: tối đa 4 người lên xuống

## Đầu đường ra vành ngoài: điểm vỉa hè sát mép vùng chơi và hướng đi ra
const EXITS := [
	[Vector3(46.5, 0, -6.2), Vector3(1, 0, 0)], [Vector3(46.5, 0, 6.2), Vector3(1, 0, 0)],
	[Vector3(-46.5, 0, -6.2), Vector3(-1, 0, 0)], [Vector3(-46.5, 0, 6.2), Vector3(-1, 0, 0)],
	[Vector3(-13.2, 0, -30.0), Vector3(0, 0, -1)], [Vector3(-22.8, 0, -30.0), Vector3(0, 0, -1)],
	[Vector3(11.2, 0, -30.0), Vector3(0, 0, -1)], [Vector3(20.8, 0, -30.0), Vector3(0, 0, -1)],
	[Vector3(11.2, 0, 30.0), Vector3(0, 0, 1)], [Vector3(20.8, 0, 30.0), Vector3(0, 0, 1)],
	[Vector3(-18.0, 0, 30.6), Vector3(0, 0, 1)],  # cổng hẻm 42 (z = 31,7), chỉ dùng nếu đi tới được
]
## Chỗ ghé: pos (đứng), face (hướng nhìn khi đứng), anims (động tác lúc ghé), secs, cap (tối đa bao nhiêu người cùng lúc).
## seats: chỗ ngồi (cao mặt ghế) thay cho pos, approach: điểm đứng trước ghế.
const GHE := {
	"lo_banh": {"pos": Vector3(-36.8, 0, -5.3), "face": Vector3(0, 0, -1), "anims": ["dung_cho", "vay"], "secs": [3.0, 6.0], "cap": 2},
	"sap_bao": {"pos": Vector3(0.3, 0, -5.25), "face": Vector3(0, 0, -1), "anims": ["dung_cho", "noi"], "secs": [3.0, 6.0], "cap": 2},
	"tap_hoa": {"pos": Vector3(7.3, 0, -5.3), "face": Vector3(0, 0, -1), "anims": ["dung_cho", "noi"], "secs": [3.0, 7.0], "cap": 2},
	"ca_phe": {"seats": [Vector3(-4.0, 0.02, 5.38), Vector3(1.0, 0.02, 5.38)], "approach": Vector3(0, 0, -0.75),
		"face": Vector3(0, 0, 1), "anims": ["ngoi_ghe"], "secs": [10.0, 18.0], "cap": 2},
	"cong_vien": {"pos": Vector3(-37.0, 0, 13.0), "face": Vector3(1, 0, 0), "anims": ["vuon_vai", "dung_yen"], "secs": [5.0, 9.0], "cap": 2},
	"goc_co": {"pos": Vector3(-29.0, 0, 10.4), "face": Vector3(0, 0, -1), "anims": ["dung_cho"], "secs": [5.0, 9.0], "cap": 1},
	"xe_om": {"pos": Vector3(-21.6, 0, 7.4), "face": Vector3(-1, 0, -0.6), "anims": ["noi"], "secs": [3.0, 5.0], "cap": 1},
	# Cổng mẫu giáo ở vành nam đối diện tiệm xe (P2: x 34,4–46,5, cổng z = 31,5 nhìn bắc): phụ huynh đứng chờ trước cổng
	"mau_giao": {"pos": Vector3(39.0, 0, 30.4), "face": Vector3(0, 0, 1), "anims": ["dung_cho", "vay_con"], "secs": [6.0, 12.0], "cap": 3},
	# Nhà đang xây khối 5 dãy nam (P2: x −12 → −6, mặt tiền z = 24 nhìn nam): thợ ngồi ăn trưa trước công trình
	"cong_trinh": {"pos": Vector3(-10.0, 0, 27.0), "face": Vector3(0, 0, -1), "anims": ["ngoi_an", "lau_mo_hoi"], "secs": [10.0, 18.0], "cap": 2},
}
## Kiểu người (theo người gốc): chỗ hay ghé, đi chậm hay nhanh, đồ cầm tay (assets/models/nguoi, Nguoi.hold), động tác riêng
const KIEU := {
	"qd_ongtd": {"ghe": ["cong_vien", "goc_co", "lo_banh", "sap_bao"], "walk": "di_cham", "speed": 0.75},
	"qd_vanphong": {"ghe": ["sap_bao", "ca_phe", "lo_banh", "tap_hoa"], "bus": 0.45, "do": "dien_thoai", "phone": true},
	"qd_hocsinh": {"ghe": ["lo_banh", "tap_hoa", "goc_co"], "bus": 0.2, "speed": 1.35},
	"qd_sinhvien": {"ghe": ["ca_phe", "tap_hoa", "sap_bao"], "bus": 0.35, "phone": true},
	"qd_veso": {"ghe": ["ca_phe", "goc_co", "sap_bao", "lo_banh"], "walk": "di_cham", "speed": 0.8, "do": "bang_ve_so", "hand": "hand.L", "act": "moi_ve"},
	"qd_giaohang": {"ghe": [], "door": true, "do": "goi_hang", "speed": 1.35},
	"qd_congnhan": {"ghe": ["cong_trinh", "tap_hoa", "xe_om", "lo_banh"], "act": "lau_mo_hoi"},
	"qd_mehoa": {"ghe": ["mau_giao", "tap_hoa", "lo_banh"], "bus": 0.15},
}
## Lịch theo buổi (AnhSang preset của ngày): số người cùng ra phố và ai ra phố
const LICH := {
	"pho_sang": {"n": 11, "ai": ["qd_ongtd", "qd_vanphong", "qd_hocsinh", "qd_hocsinh_b", "qd_sinhvien", "qd_veso",
		"qd_giaohang", "qd_congnhan", "qd_mehoa", "qd_vanphong_b", "qd_sinhvien_b", "qd_ongtd_b"]},
	"pho_cho": {"n": 7, "ai": ["qd_mehoa", "qd_mehoa_b", "qd_ongtd", "qd_veso", "qd_vanphong", "qd_hocsinh", "qd_giaohang_b", "qd_congnhan"]},
	"pho_mua": {"n": 7, "ai": ["qd_vanphong_mua", "qd_hocsinh_mua", "qd_congnhan_mua", "qd_giaohang_mua", "qd_mehoa_mua", "qd_sinhvien", "qd_hocsinh_b"],
		"run": ["qd_sinhvien", "qd_hocsinh_b"]},
	"pho_trua": {"n": 9, "ai": ["qd_congnhan", "qd_congnhan_b", "qd_vanphong", "qd_vanphong_b", "qd_giaohang", "qd_veso", "qd_sinhvien", "qd_ongtd_b", "qd_mehoa_b"]},
	"pho_chieu": {"n": 12, "ai": ["qd_mehoa", "qd_mehoa_b", "qd_hocsinh", "qd_hocsinh_b", "qd_vanphong", "qd_sinhvien", "qd_ongtd", "qd_veso_b",
		"qd_congnhan", "qd_giaohang_b", "qd_vanphong_b", "qd_sinhvien_b"]},
	"pho_toi": {"n": 8, "ai": ["qd_ongtd", "qd_sinhvien", "qd_sinhvien_b", "qd_vanphong_b", "qd_veso", "qd_mehoa", "qd_giaohang", "qd_congnhan_b"]},
}


class Khach:
	var n: Nguoi
	var id := ""
	var kind := ""                  ## người gốc (qd_vanphong...) để tra KIEU
	var path: PackedVector3Array = []
	var road: PackedByteArray = []  ## từng điểm của path có nằm dưới lòng đường không
	var i := 0
	var speed := 1.2
	var walk_anim := "di_bo"
	var state := "walk"             ## walk, cross_wait, act, wait_bus, board, in_door, out
	var goal := {}                  ## {"kind": ghe|door|alley|exit|bus, ...}
	var plan: Array = []            ## các goal kế tiếp
	var timer := 0.0
	var wait := 0.0
	var spot := ""                  ## chỗ ghé đang chiếm (GHE key + chỉ số chỗ ngồi)
	var yield_cd := 0.0
	var on_road := false


var traffic: Node
var player: Node3D
var preset := "pho_sang"
var ready_grid := false
var astar := AStarGrid2D.new()
var _w := 0
var _h := 0
var _road_cells := {}
var _doors: Array = []          ## [{out: Vector3, inside: Vector3}]
var _alleys: Array = []         ## [{mouth: Vector3, deep: Vector3}]
var _exits: Array = []          ## [{edge: Vector3, far: Vector3}]
var _people: Array[Khach] = []
var _taken := {}                ## chỗ ghé -> số người đang ở đó
var _spawn_cd := 0.0
var _shadow_cd := 0.0
var _rng := RandomNumberGenerator.new()
var _boarding := 0


func _ready() -> void:
	name = "NguoiQuaDuong"
	_rng.seed = 808
	preset = AnhSang.preset_for_day(PlayMode.day)
	if not LICH.has(preset):
		preset = "pho_sang"
	_build.call_deferred()


func _build() -> void:
	# Chờ các màn trong ngày (chợ, Thứ Năm, Thứ Sáu...) dựng xong đồ có va chạm rồi mới dựng lưới đi bộ
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_build_grid()
	_find_anchors()
	ready_grid = true
	if traffic and traffic.bus:
		traffic.bus.doors_opened.connect(_on_bus_doors)
	# Đầu ngày phố đã có người đang đi dở chuyến (không ai bật ra trước mắt sau đó)
	var n0 := int(ceil(_target() * 0.7))
	for k in n0:
		_spawn(true)


func _target() -> int:
	return mini(int(LICH[preset].n), NEAR_MAX)


# ---------------------------------------------------------------- lưới đi bộ

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int((p.x - AREA.position.x) / CELL), 0, _w - 1), clampi(int((p.z - AREA.position.y) / CELL), 0, _h - 1))


func _world(c: Vector2i) -> Vector3:
	return Vector3(AREA.position.x + (c.x + 0.5) * CELL, 0, AREA.position.y + (c.y + 0.5) * CELL)


func _in_area(p: Vector3) -> bool:
	return AREA.has_point(Vector2(p.x, p.z))


func _build_grid() -> void:
	_w = int(AREA.size.x / CELL)
	_h = int(AREA.size.y / CELL)
	astar.region = Rect2i(0, 0, _w, _h)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	var main := get_parent().get_parent() if traffic else get_parent()
	for shape: CollisionShape3D in main.find_children("*", "CollisionShape3D", true, false):
		var body := shape.get_parent()
		if not (body is StaticBody3D) or shape.disabled or not shape.is_inside_tree():
			continue
		if (body as CollisionObject3D).collision_layer & (Blocks.LAYER_WORLD | Blocks.LAYER_PROP) == 0:
			continue
		if _under_named(body, "MepMem"):
			continue  # tường mép mềm chỉ chặn Bơ
		var half := Vector3.ZERO
		if shape.shape is BoxShape3D:
			half = (shape.shape as BoxShape3D).size / 2.0
		elif shape.shape is CylinderShape3D:
			var cy := shape.shape as CylinderShape3D
			half = Vector3(cy.radius, cy.height / 2.0, cy.radius)
		else:
			continue
		var xf := shape.global_transform
		var b := xf.basis
		var ext := Vector3(
			absf(b.x.x) * half.x + absf(b.y.x) * half.y + absf(b.z.x) * half.z,
			absf(b.x.y) * half.x + absf(b.y.y) * half.y + absf(b.z.y) * half.z,
			absf(b.x.z) * half.x + absf(b.y.z) * half.y + absf(b.z.z) * half.z)
		var c := xf.origin
		if c.y - ext.y > 1.6 or c.y + ext.y < 0.12:
			continue  # mái hiên, dây điện trên đầu; vạch sơn, nắp cống dưới chân
		if ext.x > 30.0 or ext.z > 30.0:
			continue  # nền đất
		_mark(Rect2(c.x - ext.x - 0.2, c.z - ext.z - 0.2, ext.x * 2.0 + 0.4, ext.z * 2.0 + 0.4))
	for j: Rect2 in JUNCTIONS:
		_mark(j)
	for r: Rect2 in ROADS:
		var a := _cell(Vector3(r.position.x, 0, r.position.y))
		var e := _cell(Vector3(r.end.x - 0.01, 0, r.end.y - 0.01))
		for x in range(a.x, e.x + 1):
			for y in range(a.y, e.y + 1):
				var cc := Vector2i(x, y)
				_road_cells[cc] = true
				if not astar.is_point_solid(cc):
					astar.set_point_weight_scale(cc, ROAD_WEIGHT)


func _under_named(n: Node, what: String) -> bool:
	var p := n
	while p:
		if p.name == what:
			return true
		p = p.get_parent()
	return false


func _mark(r: Rect2) -> void:
	var a := _cell(Vector3(r.position.x, 0, r.position.y))
	var e := _cell(Vector3(r.end.x, 0, r.end.y))
	for x in range(a.x, e.x + 1):
		for y in range(a.y, e.y + 1):
			var w := _world(Vector2i(x, y))
			if r.has_point(Vector2(w.x, w.z)):
				astar.set_point_solid(Vector2i(x, y), true)


func _solid(p: Vector3) -> bool:
	return not _in_area(p) or astar.is_point_solid(_cell(p))


func _is_road(p: Vector3) -> bool:
	return _in_area(p) and _road_cells.has(_cell(p))


## Ô trống gần p nhất (trong bán kính r mét); không có thì trả lại Vector2i(-1, -1).
func _free_near(p: Vector3, r := 1.5, sidewalk := false) -> Vector2i:
	var c := _cell(p)
	var best := Vector2i(-1, -1)
	var best_d := INF
	var n := int(ceil(r / CELL))
	for dx in range(-n, n + 1):
		for dy in range(-n, n + 1):
			var q := c + Vector2i(dx, dy)
			if not astar.is_in_boundsv(q) or astar.is_point_solid(q):
				continue
			if sidewalk and _road_cells.has(q):
				continue
			var d := _world(q).distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = q
	return best


## Đường đi từ a tới b: điểm thế giới đã nắn thẳng, kèm cờ dưới lòng đường. Rỗng nếu không tới được.
func _route(a: Vector3, b: Vector3) -> Array:
	var ca := _free_near(a, 2.0)
	var cb := _free_near(b, 2.0)
	if ca.x < 0 or cb.x < 0:
		return []
	var ids := astar.get_id_path(ca, cb)
	if ids.is_empty():
		return []
	var pts: Array[Vector3] = []
	for c in ids:
		pts.append(_world(c))
	pts[-1] = b if not _solid(b) else pts[-1]
	# Nắn thẳng: nối tới điểm xa nhất còn nhìn thấy, không cắt qua ô đặc và không đổi vỉa hè/lòng đường giữa chừng
	var out := PackedVector3Array([a])
	var flags := PackedByteArray([1 if _is_road(a) else 0])
	var k := 0
	while k < pts.size() - 1:
		var far := k + 1
		var j := pts.size() - 1
		while j > k + 1:
			if _clear(pts[k], pts[j]):
				far = j
				break
			j -= 1
		out.append(pts[far])
		flags.append(1 if _road_cells.has(_cell(pts[far])) else 0)
		k = far
	return [out, flags]


func _clear(a: Vector3, b: Vector3) -> bool:
	var road := _road_cells.has(_cell(a))
	var steps := int(a.distance_to(b) / (CELL * 0.5)) + 1
	for s in range(1, steps + 1):
		var c := _cell(a.lerp(b, float(s) / steps))
		if astar.is_point_solid(c) or _road_cells.has(c) != road:
			return false
	return true


func _reachable(a: Vector3, b: Vector3) -> bool:
	var ca := _free_near(a, 2.0)
	var cb := _free_near(b, 2.0)
	return ca.x >= 0 and cb.x >= 0 and not astar.get_id_path(ca, cb).is_empty()


# ---------------------------------------------------------------- điểm đầu, điểm cuối

func _find_anchors() -> void:
	var hub: Vector3 = XeBuyt.stands()[2]
	# Cửa nhà: dò từ mép khối vào trong, gặp mặt tiền (ô đặc đầu tiên) thì cửa ở đó
	var avoid: Array[Vector3] = [City.BAKERY_POINT]
	for id: String in Days.DATA:
		for o: Dictionary in (Days.DATA[id] as Dictionary).get("orders", []):
			avoid.append(o.pos)
	for i in City.BLOCKS.size():
		if i == City.PARK_INDEX:
			continue
		var r: Rect2 = City.BLOCKS[i]
		var sides := [
			[Vector3(0, 0, r.position.y), Vector3(0, 0, 1), true], [Vector3(0, 0, r.end.y), Vector3(0, 0, -1), true],
			[Vector3(r.position.x, 0, 0), Vector3(1, 0, 0), false], [Vector3(r.end.x, 0, 0), Vector3(-1, 0, 0), false]]
		for sd in sides:
			var along_x: bool = sd[2]
			var lo := (r.position.x if along_x else r.position.y) + 3.0
			var hi := (r.end.x if along_x else r.end.y) - 3.0
			var t := lo + _rng.randf_range(0.0, 2.0)
			while t < hi:
				var edge: Vector3 = sd[0] + (Vector3(t, 0, 0) if along_x else Vector3(0, 0, t))
				var inward: Vector3 = sd[1]
				for d in range(2, 9):
					var p := edge + inward * (d * 0.5)
					if _solid(p):
						var out := p - inward * 0.75
						var ok := not _solid(out) and not _solid(out - inward * 0.5)
						for q in avoid:
							if Vector2(q.x - out.x, q.z - out.z).length() < 2.5:
								ok = false
						if ok and _reachable(out, hub):
							_doors.append({"out": out, "inside": p + inward * 0.5, "face": inward})
						break
				t += _rng.randf_range(3.5, 6.0)
	# Hẻm giữa khối (z ±15,5): vào sâu trong hẻm thì khuất
	for i in City.BLOCKS.size():
		if i == City.PARK_INDEX:
			continue
		var r: Rect2 = City.BLOCKS[i]
		var zc := -15.5 if r.end.y < 0.0 else 15.5
		for v in [[r.position.x, 1.0], [r.end.x, -1.0]]:
			var mouth := Vector3(v[0] + v[1] * 1.0, 0, zc)
			var deep := Vector3(v[0] + v[1] * 4.5, 0, zc)
			if not _solid(deep) and _reachable(mouth, hub):
				_alleys.append({"mouth": mouth, "deep": deep, "out": Vector3(-v[1], 0, 0)})
	for e in EXITS:
		if _reachable(e[0], hub):
			_exits.append({"edge": e[0], "far": e[0] + e[1] * OUT_LEN, "dir": e[1]})


# ---------------------------------------------------------------- sinh người, lên kế hoạch chuyến

func _cam() -> Camera3D:
	return get_viewport().get_camera_3d() if is_inside_tree() else null


func _hidden(p: Vector3) -> bool:
	var cam := _cam()
	if cam == null:
		return true
	if cam.global_position.distance_to(p) > HIDE_RANGE:
		return true
	return not cam.is_position_in_frustum(p + Vector3.UP)


func _base(id: String) -> String:
	var g := id
	for suf in ["_mua", "_xe", "_b"]:
		g = g.trim_suffix(suf)
	return g


func _pick_id() -> String:
	var used := {}
	for k in _people:
		used[k.id] = true
	var pool: Array = []
	for id: String in LICH[preset].ai:
		if not used.has(id) and not Nguoi.in_scene(get_tree(), id):
			pool.append(id)
	if pool.is_empty():
		return ""
	return pool[_rng.randi() % pool.size()]


## Sinh một người. mid_trip: đầu ngày, đặt sẵn ở giữa chuyến trên vỉa hè (lúc mở màn chưa ai nhìn thấy).
func _spawn(mid_trip := false, from_bus := Vector3.INF) -> Khach:
	var id := _pick_id()
	if id == "":
		return null
	var k := Khach.new()
	k.id = id
	k.kind = _base(id)
	var kieu: Dictionary = KIEU.get(k.kind, {})
	k.speed = float(kieu.get("speed", 1.2)) * _rng.randf_range(0.92, 1.08)
	k.walk_anim = kieu.get("walk", "di_bo")
	if preset == "pho_mua" and id in LICH[preset].get("run", []):
		k.walk_anim = "chay"
		k.speed = 2.4
	# Điểm xuất phát
	var start := Vector3.ZERO
	var first := {}
	if from_bus != Vector3.INF:
		start = from_bus
		first = {"kind": "step_off"}
	elif mid_trip:
		var tries := 0
		while tries < 30:
			tries += 1
			var c := Vector2i(_rng.randi_range(0, _w - 1), _rng.randi_range(0, _h - 1))
			var p := _world(c)
			if astar.is_point_solid(c) or _road_cells.has(c) or not _reachable(p, XeBuyt.stands()[2]):
				continue
			if player and p.distance_to(player.global_position) < 6.0:
				continue
			start = p
			break
		if tries >= 30:
			return null
	else:
		var opts: Array = []
		for d in _doors:
			opts.append({"kind": "door", "d": d, "w": 3.0})
		for a in _alleys:
			if _hidden(a.deep):
				opts.append({"kind": "alley", "d": a, "w": 2.0})
		for e in _exits:
			if _hidden(e.far):
				opts.append({"kind": "exit", "d": e, "w": 4.0})
		var o := _weighted(opts)
		if o.is_empty():
			return null
		match o.kind:
			"door":
				start = o.d.inside
				first = {"kind": "leave_door", "to": o.d.out}
			"alley":
				start = o.d.deep
			"exit":
				start = o.d.far
				first = {"kind": "enter_edge", "to": o.d.edge}
	k.n = Nguoi.make(id, "dung_yen")
	k.n.look_target = player
	k.n.look_range = 4.0
	add_child(k.n)
	k.n.position = start
	for mi: GeometryInstance3D in k.n.find_children("*", "GeometryInstance3D", true, false):
		mi.visibility_range_end = DRAW_RANGE
	var item: String = kieu.get("do", "")
	if item != "" and ResourceLoader.exists("res://assets/models/nguoi/%s.glb" % item):
		k.n.hold("res://assets/models/nguoi/%s.glb" % item, kieu.get("hand", "hand.R"), Vector3.ZERO)
	_people.append(k)
	_make_plan(k)
	if not first.is_empty():
		k.plan.push_front(first)
	_next_goal(k)
	return k


func _weighted(opts: Array) -> Dictionary:
	var total := 0.0
	for o in opts:
		total += o.w
	var r := _rng.randf() * total
	for o in opts:
		r -= o.w
		if r <= 0.0:
			return o
	return {} if opts.is_empty() else opts[-1]


## Kế hoạch chuyến: ghé một hai chỗ hợp kiểu người rồi về một đích (cửa nhà, hẻm, vành ngoài, xe buýt).
func _make_plan(k: Khach) -> void:
	var kieu: Dictionary = KIEU.get(k.kind, {})
	var ghe: Array = kieu.get("ghe", []).duplicate()
	ghe.shuffle()
	var stops := _rng.randi_range(1, 2)
	for g in ghe:
		if stops <= 0:
			break
		if g == "mau_giao" and preset != "pho_chieu" and preset != "pho_sang":
			continue  # cổng mẫu giáo: đưa con buổi sáng, đón con chiều tà
		if g == "cong_trinh" and preset != "pho_trua" and _rng.randf() < 0.6:
			continue  # thợ ngồi ăn ở công trình chủ yếu buổi trưa
		if g == "ca_phe" and preset == "pho_mua":
			continue
		k.plan.append({"kind": "ghe", "key": g})
		stops -= 1
	if kieu.get("door", false) and not _doors.is_empty():
		k.plan.append({"kind": "deliver", "d": _doors[_rng.randi() % _doors.size()]})
	var opts: Array = []
	for d in _doors:
		opts.append({"kind": "door", "d": d, "w": 3.0})
	for a in _alleys:
		opts.append({"kind": "alley", "d": a, "w": 2.0})
	for e in _exits:
		opts.append({"kind": "exit", "d": e, "w": 4.0})
	if traffic and traffic.bus:
		opts.append({"kind": "bus", "w": 30.0 * float(kieu.get("bus", 0.0))})
	var o := _weighted(opts)
	if not o.is_empty():
		k.plan.append(o)


func _next_goal(k: Khach) -> void:
	_release(k)
	if k.plan.is_empty():
		_remove(k)
		return
	k.goal = k.plan.pop_front()
	var to := Vector3.INF
	match k.goal.kind:
		"leave_door", "enter_edge":
			to = k.goal.to
		"step_off":
			k.state = "act"
			_face_dir(k, -XeBuyt.facing())  # bước xuống quay lưng về xe (xe đỗ trước mặt trạm)
			k.n.play_once("xuong_xe_buyt", "dung_yen")
			k.timer = 1.1
			return
		"ghe":
			var g: Dictionary = GHE[k.goal.key]
			var slot := _free_slot(k.goal.key)
			if slot < 0:
				_next_goal(k)  # chỗ đó đầy người: bỏ qua
				return
			k.spot = "%s:%d" % [k.goal.key, slot]
			_taken[k.spot] = true
			if g.has("seats"):
				to = g.seats[slot] + g.approach
				to.y = 0.0
			else:
				to = g.pos + Vector3(slot * 0.7, 0, 0)
		"deliver":
			to = k.goal.d.out
		"door":
			to = k.goal.d.out
		"alley":
			to = k.goal.d.mouth
		"exit":
			to = k.goal.d.edge
		"bus":
			var spots: Array = XeBuyt.seats() + XeBuyt.stands()
			var slot := -1
			for s in spots.size():
				if not _taken.has("tram:%d" % s):
					slot = s
					break
			if slot < 0:
				k.goal = {"kind": "exit", "d": _exits[_rng.randi() % _exits.size()]} if not _exits.is_empty() else {}
				if k.goal.is_empty():
					_remove(k)
					return
				to = k.goal.d.edge
			else:
				k.spot = "tram:%d" % slot
				_taken[k.spot] = true
				k.goal["slot"] = slot
				k.goal["seat"] = slot < XeBuyt.seats().size()
				to = spots[slot]
				to.y = 0.0
				if k.goal.seat:
					to += XeBuyt.facing() * 0.55
	if to == Vector3.INF:
		_next_goal(k)
		return
	_walk_to(k, to)


func _walk_to(k: Khach, to: Vector3) -> void:
	var from := k.n.position
	from.y = 0.0
	var direct: bool = k.goal.kind in ["leave_door", "enter_edge"] or not _in_area(from) or not _in_area(to)
	if direct:
		k.path = PackedVector3Array([from, to])
		k.road = PackedByteArray([0, 0])
	else:
		var r := _route(from, to)
		if r.is_empty():
			_next_goal(k)  # không tới được: sang việc kế
			return
		k.path = r[0]
		k.road = r[1]
	k.i = 1
	k.state = "walk"
	k.n.play(k.walk_anim)


func _free_slot(key: String) -> int:
	var g: Dictionary = GHE[key]
	var n: int = g.seats.size() if g.has("seats") else int(g.cap)
	for s in n:
		if not _taken.has("%s:%d" % [key, s]):
			return s
	return -1


func _release(k: Khach) -> void:
	if k.spot != "":
		_taken.erase(k.spot)
		k.spot = ""


func _remove(k: Khach) -> void:
	_release(k)
	_people.erase(k)
	if is_instance_valid(k.n):
		k.n.queue_free()


# ---------------------------------------------------------------- xe buýt

## Xe buýt mở cửa: người chờ ở trạm bước tới cửa lên xe, vài người bước xuống (tổng cộng ≤ BOARD_MAX).
func _on_bus_doors(doors: Array) -> void:
	var count := 0
	for k in _people:
		if count >= BOARD_MAX:
			break
		if k.state == "wait_bus":
			var d: Vector3 = doors[count % doors.size()]
			_release(k)
			k.goal = {"kind": "board", "door": d}
			k.path = PackedVector3Array([k.n.position * Vector3(1, 0, 1), d])
			k.road = PackedByteArray([0, 1])
			k.i = 1
			k.state = "walk"
			k.n.play(k.walk_anim)
			count += 1
	var off := mini(_rng.randi_range(0, 2), BOARD_MAX - count)
	for j in off:
		if _people.size() >= _target() + 2:
			break
		_spawn(false, doors[j % doors.size()])


# ---------------------------------------------------------------- vòng lặp

func _physics_process(delta: float) -> void:
	if not ready_grid:
		return
	var on_road := PackedVector3Array()
	for k in _people.duplicate():
		if not is_instance_valid(k.n):
			_people.erase(k)
			continue
		_step(k, delta)
		if k.on_road and k in _people:
			on_road.append(k.n.position)
	if traffic:
		traffic.peds = on_road
	_spawn_cd -= delta
	if _spawn_cd <= 0.0:
		_spawn_cd = SPAWN_EVERY * _rng.randf_range(0.6, 1.4)
		if _people.size() < _target():
			_spawn()
	_shadow_cd -= delta
	if _shadow_cd <= 0.0:
		_shadow_cd = 0.3
		_update_shadows()


func _step(k: Khach, delta: float) -> void:
	k.yield_cd = maxf(k.yield_cd - delta, 0.0)
	match k.state:
		"walk":
			_walk(k, delta)
		"cross_wait":
			k.wait += delta
			if _safe_to_cross(k) or k.wait > CROSS_WAIT_MAX:
				k.state = "walk"
				k.n.play(k.walk_anim)
		"act":
			k.timer -= delta
			if k.timer <= 0.0:
				if k.goal.get("seated", false):
					k.n.position.y = 0.0
					k.n.position = k.goal.get("stand_back", k.n.position)
				_next_goal(k)
		"wait_bus":
			k.timer -= delta
			if k.timer <= 0.0 or traffic == null or traffic.bus == null:
				# Đợi lâu quá thì thôi, đi bộ ra vành
				if k.goal.get("seat", false):
					k.n.position = Vector3(k.n.position.x, 0, k.n.position.z) + XeBuyt.facing() * 0.55
				k.plan = [{"kind": "exit", "d": _exits[_rng.randi() % _exits.size()]}] if not _exits.is_empty() else []
				_next_goal(k)
		"board":
			k.timer -= delta
			if k.timer <= 0.0:
				_remove(k)
		"in_door":
			k.timer -= delta
			k.n.position += k.goal.d.face * delta * k.speed
			if k.timer <= 0.0:
				_remove(k)
		"hide":
			# Tới chỗ khuất (vào sâu trong hẻm, ra vành ngoài): chỉ biến mất khi không ai nhìn thấy
			k.timer -= delta
			if _hidden(k.n.position) or k.timer <= 0.0:
				_remove(k)


func _walk(k: Khach, delta: float) -> void:
	if k.i >= k.path.size():
		_arrive(k)
		return
	var pos := k.n.position
	var target := k.path[k.i]
	target.y = 0.0
	k.on_road = _is_road(pos)
	# Nhường Bơ: Bơ ngay trước mặt thì đứng lại một chút
	var dir := (target - pos)
	dir.y = 0.0
	var dist := dir.length()
	if dist < 0.001:
		k.i += 1
		return
	dir /= dist
	if player:
		var rel := player.global_position - pos
		rel.y = 0.0
		if rel.length() < 1.2 and rel.dot(dir) > 0.3:
			if k.yield_cd <= 0.0:
				k.yield_cd = 4.0
				k.n.play_once("ne_bo", k.walk_anim)
			return
	var step := k.speed * delta
	if step >= dist:
		k.n.position = Vector3(target.x, pos.y, target.z)
		k.i += 1
		# Tới mép đường, đoạn kế băng qua lòng đường: nhìn xe trước đã
		if k.i < k.path.size() and k.road[k.i] == 1 and k.road[k.i - 1] == 0 and k.goal.kind != "board" and not _safe_to_cross(k):
			k.state = "cross_wait"
			k.wait = 0.0
			k.n.play("dung_cho")
			_face(k, k.path[k.i])
			return
	else:
		k.n.position = pos + dir * step
	k.n.rotation.y = lerp_angle(k.n.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 10.0))
	if k.n.current() != k.walk_anim and k.n.current() != "ne_bo":
		k.n.play(k.walk_anim)


func _face(k: Khach, at: Vector3) -> void:
	var d := at - k.n.position
	if Vector2(d.x, d.z).length() > 0.01:
		k.n.rotation.y = atan2(d.x, d.z)


func _face_dir(k: Khach, d: Vector3) -> void:
	k.n.rotation.y = atan2(d.x, d.z)


func _arrive(k: Khach) -> void:
	k.on_road = false
	var kieu: Dictionary = KIEU.get(k.kind, {})
	match k.goal.kind:
		"leave_door", "enter_edge":
			_next_goal(k)
		"ghe":
			var g: Dictionary = GHE[k.goal.key]
			k.state = "act"
			k.timer = _rng.randf_range(g.secs[0], g.secs[1])
			var anims: Array = g.anims
			var anim: String = anims[_rng.randi() % anims.size()]
			if kieu.has("act") and _rng.randf() < 0.5:
				anim = kieu.act
			if k.goal.key == "mau_giao" and k.kind != "qd_mehoa":
				anim = "dung_cho"
			if anim == "vay_con" and k.kind != "qd_mehoa":
				anim = "dung_cho"
			if g.has("seats"):
				var slot := int(k.spot.get_slice(":", 1))
				k.goal["seated"] = true
				k.goal["stand_back"] = k.n.position
				k.n.position = g.seats[slot]
			_face_dir(k, g.face)
			if kieu.get("phone", false) and anim == "dung_cho":
				anim = "nhin_dt"
			if anim in Nguoi.ONE_SHOT:
				k.n.play_once(anim, "dung_cho")
			else:
				k.n.play(anim)
		"deliver":
			k.state = "act"
			k.timer = _rng.randf_range(4.0, 6.0)
			_face_dir(k, k.goal.d.face)
			k.n.play("goi_dt")
		"door":
			k.state = "in_door"
			k.timer = 1.0
			_face_dir(k, k.goal.d.face)
			k.n.play(k.walk_anim)
		"alley":
			k.goal = {"kind": "hide_walk", "to": k.goal.d.deep}
			k.path = PackedVector3Array([k.n.position, k.goal.to])
			k.road = PackedByteArray([0, 0])
			k.i = 1
		"hide_walk":
			k.state = "hide"
			k.timer = 20.0
			k.n.play(["nhin_dt", "dung_yen"][_rng.randi() % 2] if kieu.get("phone", false) else "dung_yen")
		"exit":
			k.goal = {"kind": "hide_walk", "to": k.goal.d.far}
			k.path = PackedVector3Array([k.n.position, k.goal.to])
			k.road = PackedByteArray([0, 0])
			k.i = 1
		"bus":
			k.state = "wait_bus"
			k.timer = 150.0
			if k.goal.get("seat", false):
				k.n.position = XeBuyt.seats()[k.goal.slot] + Vector3(0, -0.26, 0)
				_face_dir(k, XeBuyt.facing())
				k.n.play("ngoi_ghe")
			else:
				_face_dir(k, Vector3(-1, 0, 0) + XeBuyt.facing() * 0.6)  # nhìn về phía xe tới
				k.n.play("nhin_dt" if kieu.get("phone", false) else "dung_cho")
		"board":
			k.state = "board"
			k.timer = 1.25
			_face_dir(k, XeBuyt.facing())
			k.n.play_once("len_xe_buyt", "dung_yen")
		_:
			_next_goal(k)


## Mép đường: không có xe nào (kể cả xe buýt) đang chạy tới trong tầm CROSS_LOOK.
func _safe_to_cross(k: Khach) -> bool:
	if traffic == null:
		return true
	var p := k.n.position
	for b in traffic._bikes:
		if not b.active or b.speed < 0.3:
			continue
		var rel: Vector3 = p - b.pos
		rel.y = 0.0
		if rel.length() < CROSS_LOOK and rel.dot(b.dir) > -2.0:
			return false
	return true


## Chỉ người gần camera đổ bóng (lượt bóng đổ của bản web rất đắt).
func _update_shadows() -> void:
	var cam := _cam()
	if cam == null:
		return
	var cp := cam.global_position
	for k in _people:
		if not is_instance_valid(k.n):
			continue
		var near := k.n.global_position.distance_to(cp) < SHADOW_RANGE
		if k.n.has_meta("bong") and k.n.get_meta("bong") == near:
			continue
		k.n.set_meta("bong", near)
		for mi: GeometryInstance3D in k.n.find_children("*", "GeometryInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if near else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Cho autotest và test: số người đang ra phố.
func count() -> int:
	return _people.size()
