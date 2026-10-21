class_name Market
extends Node3D
## Chợ sáng Thứ Ba (gói T3-4): chợ tạm trên đường lớn giữa khối 2 và khối 5.
## Đơn 1–3 chợ họp: 18 sạp có bạt (gầm 0,5 m, Bơ chui được), thúng hàng đổ được, người đi chợ chen nhau.
## Đơn 4–5 chợ tan: sạp gập lại từng cái thành đống bạt và thúng, ba gác chở hàng về chắn giữa đường,
## người đi chợ thưa dần. Xe chè chặn hẻm giữa khối 3 theo lịch (traffic.gd, ALLEY_BLOCKS).
## Va người đi chợ: Bơ khựng 0,4 s, phát player.bumped("person"). Xe máy chạy chậm qua vùng chợ.
## main.gd chỉ cần: add_child(preload("res://scripts/market.gd").new()) sau giao thông; ngày khác chợ tự gỡ.
## Bản khối tạm: sạp, thúng, người đi chợ vẽ bằng MultiMesh. Model thật chờ trang "Phác thảo Thứ Ba" được duyệt.

signal person_bumped(pos: Vector3)   ## âm thanh: tiếng "ối", luồng giao bánh: nhiệm vụ phụ đơn 4
signal basket_spilled(pos: Vector3)  ## âm thanh: rau quả lăn, luồng giao bánh: nhiệm vụ phụ đơn 5
signal packing_started               ## chợ bắt đầu dọn (đầu đơn 4)

const DAYS := ["thu_ba", "t3"]
## Chợ họp trong 3 đơn đầu (Sang chốt 21/10), sau đó dọn dần
const OPEN_ORDERS := 3
## Phần sạp đã gập và phần người đi chợ còn lại theo từng đơn (chỉ số 0–4)
const FOLDED := [0.0, 0.0, 0.0, 0.5, 0.85]
const CROWD := [1.0, 1.0, 1.0, 0.35, 0.15]
const FOLD_STEP := 1.4        ## mỗi bao nhiêu giây một sạp gập lại
const FOLD_TIME := 0.5        ## một sạp gập (hoặc đống hàng hiện ra) trong bao lâu
const BIKE_SPEED := 3.0       ## xe máy qua chợ: vẫn đủ nhanh để tông Bơ
const BROWSERS := 10          ## người đứng lựa hàng trước sạp
const WALKERS := 18           ## người đi qua lại giữa hai dãy sạp
const WALK_LINES := [-1.2, 0.0, 1.2]
const BUMP_DIST := 0.48       ## nửa bề ngang người + bán kính Bơ
const BUMP_STUN := 0.4
const BUMP_COOLDOWN := 1.0
const SPILL_DIST := 0.6
const SPILL_SPEED := 3.0      ## Bơ chạy nhanh hơn mức này (không rón rén, không chui) mà đụng thúng là đổ
const BASKET_Z := 3.15        ## thúng đặt trước khe giữa hai sạp, phía lòng đường

const WOOD := Color("#9B6A3A")
const TARPS := {"rau": Color("#3D7FB8"), "trai_cay": Color("#C8412F"), "ca": Color("#2E7C80"), "hoa": Color("#D7A9C4"), "kho": Color("#E8C98A")}
const SHIRTS := [Color("#E39C7A"), Color("#5E8FB8"), Color("#F2E3B8"), Color("#8DB36F"), Color("#D7A9C4"), Color("#C9C3B3"), Color("#B85C7A")]
const PRODUCE := [Color("#5FA35A"), Color("#F2A33A"), Color("#D94F3D"), Color("#E8D06A"), Color("#8C5A9E")]
var _hidden := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -50, 0))  ## giấu bản MultiMesh


class Shopper:
	var a: Vector3
	var b: Vector3
	var t := 0.0
	var forward := true
	var speed := 1.0
	var pause := 0.0
	var phase := 0.0
	var browse := false           ## đứng lựa hàng: không đi, chỉ lắc lư
	var face := Vector3.FORWARD
	var stall := -1               ## sạp đang đứng trước (người lựa hàng)
	var keep := true              ## còn ở lại khi chợ tan
	var leaving := false
	var gone := false
	var pos := Vector3.ZERO
	var prev_xf := Transform3D()
	var xf := Transform3D()


var main: Node
var player: CharacterBody3D
var traffic: Node
var hud: Node

## Đếm cho nhiệm vụ phụ, tính từ lúc nhận bánh tới khi giao (luồng giao bánh đọc)
var bumps_this_order := 0
var spills_this_order := 0
var bumps_total := 0
var spills_total := 0
var packing := false

var _order := -1
var _carrying := false
var _stalls: Array = []           ## [{pos, side, kind, body, slab, pile, folded, anim, open_mm, open_i}]
var _fold_queue: Array[int] = []
var _fold_timer := 0.0
var _baskets: Array = []          ## [{pos, body, shape, spilled}]
var _shoppers: Array[Shopper] = []
var _open_mm := {}                ## loại sạp -> MultiMesh sạp đang bán
var _pile_mm: MultiMesh
var _basket_mm: MultiMesh
var _goods_mm: MultiMesh
var _shirt_mm: MultiMesh
var _body_mm: MultiMesh
var _hat_mm: MultiMesh
var _ba_gac: Node3D
var _bump_cd := 0.0
var _oi: Label3D
var _oi_time := 0.0
var _autotest := false
var _in_market := false           ## Bơ đang trong vùng chợ (đổi tiếng nền)
var _rattle_on := false
var _cart_last := {}              ## xe chặn hẻm -> vị trí khung trước, để biết xe đang lăn


## Hôm nay có chợ không: ngày Thứ Ba, hoặc thử bằng -- --ngay=thu_ba / -- --cho
static func is_market_day() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--cho" or arg == "--ngay=thu_ba":
			return true
	return GameState.day in DAYS


func _ready() -> void:
	name = "ChoSang"
	add_to_group("cho_sang")
	if not is_market_day():
		queue_free()
		return
	main = get_parent()
	player = main.get("player")
	hud = main.get("hud")
	traffic = main.get_node_or_null("GiaoThong")
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	var rng := RandomNumberGenerator.new()
	rng.seed = 315  # cố định để chợ lần nào cũng giống nhau
	_build_stalls()
	_build_baskets(rng)
	_build_shoppers(rng)
	_oi = Blocks.label(self, "Ối!", Vector3.ZERO, 40, Color("#FFF2B8"))
	_oi.visible = false
	if traffic:
		traffic.slow_zones.append({"rect": CityProps.MARKET_ZONE, "speed": BIKE_SPEED})
		traffic.enable_alley_blocks()
	_sync_order(true)
	_draw(1.0)


# ---------------------------------------------------------------- sạp chợ

func _build_stalls() -> void:
	var by_kind := {}
	for i in CityProps.MARKET_STALLS.size():
		var def: Dictionary = CityProps.MARKET_STALLS[i]
		by_kind[def.kind] = by_kind.get(def.kind, 0) + 1
	for kind in by_kind:
		_open_mm[kind] = _multimesh(_stall_mesh(kind), by_kind[kind], false)
	_pile_mm = _multimesh(_pile_mesh(), CityProps.MARKET_STALLS.size(), false)
	var used := {}
	for i in CityProps.MARKET_STALLS.size():
		var def: Dictionary = CityProps.MARKET_STALLS[i]
		var yaw := 0.0 if def.side < 0 else PI  # mặt trước sạp quay ra lòng đường
		var xf := Transform3D(Basis(Vector3.UP, yaw), def.pos)
		var body := StaticBody3D.new()
		body.collision_layer = Blocks.LAYER_PROP
		body.transform = xf
		body.add_to_group("sap_cho")
		add_child(body)
		# Mặt sạp: đáy 0,5 m, đỉnh 0,62 m
		var slab := _shape(body, Vector3(1.8, 0.12, 1.4), Vector3(0, 0.56, 0))
		# Người bán ngồi (rồi đứng dọn hàng) phía vỉa hè
		_shape(body, Vector3(0.45, 1.2, 0.35), Vector3(0, 0.6, -0.95))
		var pile := _shape(body, Vector3(1.8, 0.62, 0.9), Vector3(0, 0.31, -0.25))
		pile.disabled = true
		var oi: int = used.get(def.kind, 0)
		used[def.kind] = oi + 1
		_open_mm[def.kind].set_instance_transform(oi, xf)
		_pile_mm.set_instance_transform(i, _hidden)
		_stalls.append({"pos": def.pos, "xf": xf, "kind": def.kind, "slab": slab, "pile": pile,
			"folded": false, "anim": -1.0, "open_i": oi})


func _shape(body: StaticBody3D, size: Vector3, pos: Vector3) -> CollisionShape3D:
	var s := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	s.shape = bs
	s.position = pos
	body.add_child(s)
	return s


## Sạp đang bán (gốc ở tâm sạp trên mặt đất, mặt trước quay về +Z): chân gỗ, mặt sạp, bạt phủ rủ xuống
## còn cách đất 0,5 m, hàng trên sạp theo loại, dù che nắng, người bán ngồi ghế đẩu phía sau.
func _stall_mesh(kind: String) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tarp: Color = TARPS[kind]
	for c in [Vector2(-0.82, -0.62), Vector2(0.82, -0.62), Vector2(-0.82, 0.62), Vector2(0.82, 0.62)]:
		_box(st, Vector3(0.06, 0.5, 0.06), Vector3(c.x, 0.25, c.y), WOOD.darkened(0.3))
	_box(st, Vector3(1.8, 0.12, 1.4), Vector3(0, 0.56, 0), WOOD)
	_box(st, Vector3(1.9, 0.03, 1.5), Vector3(0, 0.635, 0), tarp)
	_box(st, Vector3(1.9, 0.14, 0.02), Vector3(0, 0.57, 0.75), tarp.darkened(0.15))   # bạt rủ phía trước
	_box(st, Vector3(0.02, 0.14, 1.5), Vector3(-0.95, 0.57, 0), tarp.darkened(0.15))
	_box(st, Vector3(0.02, 0.14, 1.5), Vector3(0.95, 0.57, 0), tarp.darkened(0.15))
	var top := 0.65
	match kind:
		"rau":
			for ix in 4:
				for iz in 2:
					var g := Color("#5FA35A") if (ix + iz) % 2 == 0 else Color("#8DB36F")
					_box(st, Vector3(0.36, 0.12, 0.42), Vector3(-0.6 + ix * 0.4, top + 0.06, -0.2 + iz * 0.5), g)
		"trai_cay":
			for ix in 3:
				_box(st, Vector3(0.5, 0.06, 0.5), Vector3(-0.58 + ix * 0.58, top + 0.03, 0.1), Color("#C79A5B"))  # rổ
				var fruit: Color = [Color("#F2A33A"), Color("#E8D06A"), Color("#D94F3D")][ix]
				for k in 4:
					_box(st, Vector3(0.14, 0.14, 0.14), Vector3(-0.66 + ix * 0.58 + (k % 2) * 0.16, top + 0.13, 0.02 + (k / 2) * 0.16), fruit)
			_box(st, Vector3(0.24, 0.1, 0.24), Vector3(0.0, top + 0.05, -0.45), Color("#C8412F"))   # cân đĩa
			_box(st, Vector3(0.3, 0.02, 0.3), Vector3(0.0, top + 0.12, -0.45), Color("#C9C3B3"))
		"ca":
			for ix in 2:
				_box(st, Vector3(0.7, 0.14, 0.55), Vector3(-0.42 + ix * 0.84, top + 0.07, 0.1), Color("#5E8FB8"))  # thau
				for k in 3:
					_box(st, Vector3(0.32, 0.04, 0.09), Vector3(-0.42 + ix * 0.84, top + 0.16, -0.05 + k * 0.14), Color("#C9D3D8"))
		"hoa":
			_box(st, Vector3(1.4, 0.2, 0.3), Vector3(0, top + 0.1, -0.2), Color("#3D4A4A"))  # xô cắm hoa
			for k in 7:
				var f: Color = [Color("#D94F3D"), Color("#F2E3B8"), Color("#E8D06A"), Color("#C8407E")][k % 4]
				_box(st, Vector3(0.14, 0.4, 0.14), Vector3(-0.6 + k * 0.2, top + 0.4, -0.2), f)
			_box(st, Vector3(1.2, 0.08, 0.4), Vector3(0, top + 0.04, 0.35), Color("#5FA35A"))  # lá
		"kho":
			for k in 3:
				_box(st, Vector3(0.38, 0.32, 0.38), Vector3(-0.55 + k * 0.55, top + 0.16, 0.0), Color("#E7D8B8"))  # bao gạo, đậu
				_box(st, Vector3(0.3, 0.04, 0.3), Vector3(-0.55 + k * 0.55, top + 0.34, 0.0), [Color("#F4F1EA"), Color("#C9A06A"), Color("#5FA35A")][k])
			_box(st, Vector3(0.24, 0.1, 0.24), Vector3(0.0, top + 0.05, 0.45), Color("#C8412F"))  # cân đĩa
	# Dù che nắng
	_box(st, Vector3(0.05, 1.75, 0.05), Vector3(0, 1.5, -0.6), Color("#5E6F6C"))
	_box(st, Vector3(1.0, 0.06, 1.8), Vector3(-0.5, 2.38, -0.05), tarp.lightened(0.25))
	_box(st, Vector3(1.0, 0.06, 1.8), Vector3(0.5, 2.38, -0.05), Color("#F4F1EA"))
	# Người bán ngồi ghế đẩu
	_box(st, Vector3(0.3, 0.25, 0.3), Vector3(0, 0.125, -0.95), Color("#D94F3D"))
	_box(st, Vector3(0.4, 0.5, 0.26), Vector3(0, 0.5, -0.95), Color("#A9C7E8"))
	_box(st, Vector3(0.24, 0.26, 0.24), Vector3(0, 0.88, -0.95), Color("#D9A57E"))
	_box(st, Vector3(0.52, 0.06, 0.52), Vector3(0, 1.04, -0.95), Color("#E8D9A8"))  # nón lá
	_box(st, Vector3(0.32, 0.12, 0.32), Vector3(0, 0.3, -0.72), Color("#3B4252"))   # đùi
	return st.commit()


## Sạp đã dọn: ván gập, cuộn bạt, thúng chồng (cao 0,62 m, nhảy lên được), người bán đứng buộc hàng.
func _pile_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(1.8, 0.2, 0.9), Vector3(0, 0.1, -0.25), WOOD)
	_box(st, Vector3(1.7, 0.08, 0.85), Vector3(0, 0.24, -0.25), WOOD.darkened(0.2))
	_box(st, Vector3(1.5, 0.2, 0.24), Vector3(-0.1, 0.38, -0.4), Color("#3D7FB8"))   # cuộn bạt
	_box(st, Vector3(0.5, 0.3, 0.5), Vector3(0.55, 0.43, -0.15), Color("#B58A4C"))   # thúng chồng
	_box(st, Vector3(0.44, 0.06, 0.44), Vector3(0.55, 0.6, -0.15), Color("#C79A5B"))
	_box(st, Vector3(0.05, 0.05, 1.7), Vector3(-0.5, 0.52, -0.3), Color("#5E6F6C"))  # cán dù gập
	_box(st, Vector3(0.4, 0.6, 0.24), Vector3(0, 1.15, -0.95), Color("#A9C7E8"))
	_box(st, Vector3(0.24, 0.26, 0.24), Vector3(0, 1.62, -0.95), Color("#D9A57E"))
	_box(st, Vector3(0.52, 0.06, 0.52), Vector3(0, 1.78, -0.95), Color("#E8D9A8"))
	_box(st, Vector3(0.3, 0.85, 0.16), Vector3(0, 0.42, -0.95), Color("#3B4252"))
	return st.commit()


# ---------------------------------------------------------------- thúng hàng

## Thúng đặt trước khe giữa hai sạp liền nhau, phía lòng đường.
func _build_baskets(rng: RandomNumberGenerator) -> void:
	var spots: Array[Vector3] = []
	for i in range(1, CityProps.MARKET_STALLS.size()):
		var p0: Vector3 = CityProps.MARKET_STALLS[i - 1].pos
		var p1: Vector3 = CityProps.MARKET_STALLS[i].pos
		if p0.z == p1.z and absf(p1.x - p0.x) < 2.5:
			spots.append(Vector3((p0.x + p1.x) / 2.0, 0, signf(p0.z) * BASKET_Z))
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.26
	cyl.bottom_radius = 0.2
	cyl.height = 0.28
	cyl.radial_segments = 10
	cyl.rings = 1
	_basket_mm = _multimesh(_offset(cyl, Vector3(0, 0.14, 0)), spots.size(), false, Color("#B58A4C"))
	var dome := SphereMesh.new()
	dome.radius = 0.22
	dome.height = 0.2
	dome.radial_segments = 8
	dome.rings = 3
	_goods_mm = _multimesh(_offset(dome, Vector3(0, 0.28, 0)), spots.size(), true)
	for i in spots.size():
		var body := StaticBody3D.new()
		body.collision_layer = Blocks.LAYER_PROP
		body.position = spots[i]
		body.add_to_group("thung_cho")
		add_child(body)
		var s := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 0.24
		cs.height = 0.3
		s.shape = cs
		s.position.y = 0.15
		body.add_child(s)
		_basket_mm.set_instance_transform(i, Transform3D(Basis(), spots[i]))
		_goods_mm.set_instance_transform(i, Transform3D(Basis(), spots[i]))
		_goods_mm.set_instance_color(i, PRODUCE[rng.randi() % PRODUCE.size()])
		_baskets.append({"pos": spots[i], "shape": s, "spilled": false})


func _spill(i: int) -> void:
	var bk: Dictionary = _baskets[i]
	bk.spilled = true
	bk.shape.set_deferred("disabled", true)
	var away := Vector3(bk.pos.x - player.global_position.x, 0, bk.pos.z - player.global_position.z).normalized()
	if away == Vector3.ZERO:
		away = Vector3.RIGHT
	# Thúng ngã nghiêng theo hướng Bơ húc, rau quả văng thành vệt trên đất
	var axis := away.cross(Vector3.UP).normalized()
	_basket_mm.set_instance_transform(i, Transform3D(Basis(axis, -1.75), bk.pos + away * 0.25 + Vector3.UP * 0.25))
	var spread := Basis.looking_at(away).scaled(Vector3(2.2, 0.2, 3.2))
	_goods_mm.set_instance_transform(i, Transform3D(spread, bk.pos + away * 0.75 - Vector3.UP * 0.27))
	spills_this_order += 1
	spills_total += 1
	basket_spilled.emit(bk.pos)
	_sound_at("basket_topple", bk.pos)
	if player.has_method("bump"):
		player.bump("stall", bk.pos, 0.2)
	if hud and hud.has_method("show_toast"):
		hud.show_toast("Đổ thúng rau rồi! Qua chợ thì rón rén thôi.", 1.8)


func _check_baskets() -> void:
	var hv := Vector2(player.velocity.x, player.velocity.z).length()
	var stance: String = player.get("stance") if player.get("stance") != null else "walk"
	if hv < float(DoKho.v("spill_speed", SPILL_SPEED)) or stance in ["sneak", "crouch"] or player.global_position.y > 0.5:
		return
	var p := player.global_position
	for i in _baskets.size():
		var bk: Dictionary = _baskets[i]
		if not bk.spilled and Vector2(p.x - bk.pos.x, p.z - bk.pos.z).length() < SPILL_DIST:
			_spill(i)
			return


# ---------------------------------------------------------------- người đi chợ

func _build_shoppers(rng: RandomNumberGenerator) -> void:
	var zone := CityProps.MARKET_ZONE
	var stall_order := range(CityProps.MARKET_STALLS.size())
	for k in BROWSERS:
		var s := Shopper.new()
		s.browse = true
		s.stall = stall_order[(k * 7 + 3) % stall_order.size()]
		var def: Dictionary = CityProps.MARKET_STALLS[s.stall]
		var side := signf(def.pos.z)
		s.a = Vector3(def.pos.x + rng.randf_range(-0.5, 0.5), 0, side * 2.95)
		s.b = s.a
		s.face = Vector3(0, 0, side)
		s.phase = rng.randf() * TAU
		s.keep = false
		_shoppers.append(s)
	for k in int(DoKho.v("market_walkers", WALKERS)):
		var s := Shopper.new()
		var z: float = WALK_LINES[k % WALK_LINES.size()]
		var x0 := rng.randf_range(zone.position.x + 0.8, zone.end.x - 6.0)
		s.a = Vector3(x0, 0, z + rng.randf_range(-0.2, 0.2))
		s.b = Vector3(minf(x0 + rng.randf_range(4.0, 9.0), zone.end.x - 0.8), 0, s.a.z)
		s.t = rng.randf()
		s.forward = rng.randf() < 0.5
		s.speed = rng.randf_range(0.8, 1.2)  # đi chợ thong thả
		s.phase = rng.randf() * TAU
		s.keep = z != 0.0  # chợ tan: người giữa đường (chỗ ba gác) về trước
		_shoppers.append(s)
	var torso := BoxMesh.new()
	torso.size = Vector3(0.4, 0.6, 0.24)
	_shirt_mm = _multimesh(_offset(torso, Vector3(0, 1.15, 0)), _shoppers.size(), true)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var skin := Color("#D9A57E")
	_box(st, Vector3(0.24, 0.26, 0.24), Vector3(0, 1.62, 0), skin)
	_box(st, Vector3(0.26, 0.08, 0.26), Vector3(0, 1.76, 0), Color("#2B2622"))
	_box(st, Vector3(0.14, 0.85, 0.16), Vector3(-0.1, 0.42, 0), Color("#3B4252"))
	_box(st, Vector3(0.14, 0.85, 0.16), Vector3(0.1, 0.42, 0), Color("#3B4252"))
	_box(st, Vector3(0.1, 0.55, 0.12), Vector3(-0.26, 1.12, 0), skin)
	_box(st, Vector3(0.1, 0.55, 0.12), Vector3(0.26, 1.12, 0), skin)
	_box(st, Vector3(0.3, 0.2, 0.22), Vector3(0.36, 0.78, 0.02), Color("#C79A5B"))  # giỏ đi chợ
	_box(st, Vector3(0.02, 0.2, 0.02), Vector3(0.3, 0.95, 0.02), Color("#8C5A3A"))
	_body_mm = _multimesh(st.commit(), _shoppers.size(), false)
	var hat := BoxMesh.new()
	hat.size = Vector3(0.5, 0.06, 0.5)
	_hat_mm = _multimesh(_offset(hat, Vector3(0, 1.8, 0)), _shoppers.size(), false, Color("#E8D9A8"))
	for i in _shoppers.size():
		_shirt_mm.set_instance_color(i, SHIRTS[rng.randi() % SHIRTS.size()])
		_step_shopper(_shoppers[i], 0.0)
		_shoppers[i].prev_xf = _shoppers[i].xf
	# Chỉ một nửa số người đội nón lá: người còn lại ẩn nón
	for i in _shoppers.size():
		_hat_mm.set_instance_transform(i, _hidden)


func _step_shopper(s: Shopper, delta: float) -> void:
	if s.gone:
		return
	var zone := CityProps.MARKET_ZONE
	if s.leaving:
		# Chợ tan: xách giỏ đi về phía mép chợ gần nhất rồi khuất
		var exit_x := zone.position.x - 0.5 if s.pos.x < zone.get_center().x else zone.end.x + 0.5
		var dir := Vector3(signf(exit_x - s.pos.x), 0, 0)
		s.pos += dir * 1.4 * delta
		s.phase += delta * 8.0
		s.xf = Transform3D(Basis.looking_at(dir), s.pos + Vector3.UP * absf(sin(s.phase)) * 0.04)
		if not zone.has_point(Vector2(s.pos.x, s.pos.z)):
			s.gone = true
		return
	if s.browse:
		s.phase += delta * 1.3
		s.pos = s.a + Vector3(sin(s.phase) * 0.05, 0, 0)
		s.xf = Transform3D(Basis.looking_at(-s.face).rotated(Vector3.UP, sin(s.phase * 0.7) * 0.25), s.pos)
		return
	var line_len := s.a.distance_to(s.b)
	var moving := s.pause <= 0.0
	if moving and line_len > 0.1:
		s.t += (1.0 if s.forward else -1.0) * s.speed * delta / line_len
		if s.t >= 1.0 or s.t <= 0.0:
			s.t = clampf(s.t, 0.0, 1.0)
			s.forward = not s.forward
			s.pause = 1.5  # dừng lại ngó hàng rồi quay lại
		s.phase += delta * s.speed * 6.0
	s.pause = maxf(s.pause - delta, 0.0)
	s.pos = s.a.lerp(s.b, s.t)
	var fwd := (s.b - s.a).normalized() * (1.0 if s.forward else -1.0)
	if fwd == Vector3.ZERO:
		fwd = Vector3.FORWARD
	s.xf = Transform3D(Basis.looking_at(fwd), s.pos + Vector3.UP * (absf(sin(s.phase)) * 0.04 if moving else 0.0))


## Bơ chen vào người đi chợ: khựng lại, người kia kêu "Ối!".
func _check_bumps() -> void:
	if _bump_cd > 0.0 or player.global_position.y > 1.0:
		return
	var p := player.global_position
	for s in _shoppers:
		if s.gone:
			continue
		if Vector2(p.x - s.pos.x, p.z - s.pos.z).length() < BUMP_DIST:
			_bump_cd = BUMP_COOLDOWN
			s.pause = 0.8
			if player.has_method("bump"):
				player.bump("person", s.pos, float(DoKho.v("market_bump_stun", BUMP_STUN)))
			else:
				player.knockback(s.pos, 2.5, float(DoKho.v("market_bump_stun", BUMP_STUN)))
			bumps_this_order += 1
			bumps_total += 1
			person_bumped.emit(s.pos)
			_sound_at("oops", s.pos)
			_oi.position = s.pos + Vector3.UP * 2.2
			_oi.visible = true
			_oi_time = 0.8
			return


# ---------------------------------------------------------------- chợ tan

## Theo dõi đơn hiện tại: sang đơn 4 thì bắt đầu dọn; vào thẳng đơn 4, 5 (chọn một đơn) thì dọn sẵn.
func _sync_order(initial := false) -> void:
	var idx: int = main.get("order_index") if main.get("order_index") != null else 0
	var carrying: bool = player.get("carrying") == true
	if carrying and not _carrying:
		bumps_this_order = 0
		spills_this_order = 0
	_carrying = carrying
	if idx == _order:
		return
	_order = idx
	if idx < OPEN_ORDERS:
		return
	var k := mini(idx, FOLDED.size() - 1)
	var want := int(round(FOLDED[k] * _stalls.size()))
	var have := 0
	for st in _stalls:
		if st.folded:
			have += 1
	var order: Array[int] = []
	for i in _stalls.size():
		order.append(i)
	# Thứ tự dọn cố định, xen kẽ hai dãy: sạp ở xa giữa chợ dọn trước
	order.sort_custom(func(a: int, b: int) -> bool: return absf(_stalls[a].pos.x + 1.0) > absf(_stalls[b].pos.x + 1.0))
	_fold_queue.clear()
	for i in order:
		if not _stalls[i].folded and _fold_queue.size() < want - have:
			_fold_queue.append(i)
	_thin_crowd(CROWD[k], initial)
	if initial:
		for i in _fold_queue:
			_fold(i, true)
		_fold_queue.clear()
		_place_ba_gac()
	elif not packing:
		if hud and hud.has_method("show_toast"):
			hud.show_toast("Chợ tan rồi, các cô đang dọn hàng!", 2.2)
		_fold_timer = 0.5
	if not packing:
		packing = true
		packing_started.emit()


func _thin_crowd(keep: float, instant: bool) -> void:
	var walkers := 0
	for s in _shoppers:
		if not s.browse:
			walkers += 1
	var allowed := int(round(keep * _shoppers.size()))
	var kept := 0
	for s in _shoppers:
		var stay := s.keep and kept < allowed
		if stay:
			kept += 1
		elif not s.gone and not s.leaving:
			s.browse = false
			if instant:
				s.gone = true
			else:
				s.leaving = true


func _fold(i: int, instant := false) -> void:
	var st: Dictionary = _stalls[i]
	st.folded = true
	st.slab.disabled = true
	st.pile.disabled = false
	if instant:
		_open_mm[st.kind].set_instance_transform(st.open_i, _hidden)
		_pile_mm.set_instance_transform(i, st.xf)
	else:
		st.anim = 0.0


## Gập sạp: sạp xẹp xuống rồi đống hàng nhô lên. Không gập sạp Bơ đang chui bên dưới hoặc đứng cạnh.
func _update_folding(delta: float) -> void:
	for i in _stalls.size():
		var st: Dictionary = _stalls[i]
		if st.anim < 0.0:
			continue
		st.anim += delta / FOLD_TIME
		var a: float = minf(st.anim, 2.0)
		var xf: Transform3D = st.xf
		if a < 1.0:
			_open_mm[st.kind].set_instance_transform(st.open_i, Transform3D(xf.basis.scaled(Vector3(1.0, maxf(1.0 - a, 0.02), 1.0)), xf.origin))
		else:
			_open_mm[st.kind].set_instance_transform(st.open_i, _hidden)
			_pile_mm.set_instance_transform(i, Transform3D(xf.basis.scaled(Vector3(1.0, maxf(a - 1.0, 0.02), 1.0)), xf.origin))
		if a >= 2.0:
			st.anim = -1.0
	if _fold_queue.is_empty():
		if packing and _ba_gac == null and _far_from(CityProps.MARKET_BA_GAC, 3.0):
			_place_ba_gac()
		return
	_fold_timer -= delta
	if _fold_timer > 0.0:
		return
	for q in _fold_queue.size():
		var i := _fold_queue[q]
		if _far_from(_stalls[i].pos, 1.8):
			_fold_queue.remove_at(q)
			_fold(i)
			_fold_timer = FOLD_STEP
			return


func _far_from(p: Vector3, dist: float) -> bool:
	return player == null or Vector2(player.global_position.x - p.x, player.global_position.z - p.z).length() > dist


## Xe ba gác chất bạt, thúng chở hàng về: nằm giữa đường, gầm 0,4 m chui được, hàng chất cao 1,4 m.
func _place_ba_gac() -> void:
	if _ba_gac:
		return
	_ba_gac = Node3D.new()
	_ba_gac.name = "BaGacChoTan"
	add_child(_ba_gac)
	var b := CityProps._ba_gac(_ba_gac, CityProps.MARKET_BA_GAC, PI / 2.0)
	Blocks.solid_box(b, Vector3(0.8, 0.35, 0.8), Vector3(0, 0.25, -0.4), Color("#B58A4C"), Blocks.LAYER_PROP)  # thúng chồng
	Blocks.solid_box(b, Vector3(0.7, 0.3, 0.7), Vector3(0, 0.57, -0.4), Color("#C79A5B"), Blocks.LAYER_PROP)
	Blocks.solid_box(b, Vector3(0.85, 0.25, 0.8), Vector3(0, 0.2, 0.45), Color("#3D7FB8"), Blocks.LAYER_PROP)  # bạt gấp
	Blocks.box(b, Vector3(0.12, 0.4, 0.12), Vector3(0.3, 0.55, 0.45), Color("#5FA35A"))  # bó rau thừa
	Blocks.merge_static(_ba_gac)


# ---------------------------------------------------------------- vòng lặp

func _physics_process(delta: float) -> void:
	if player == null:
		return
	_sync_order()
	_bump_cd = maxf(_bump_cd - delta, 0.0)
	for s in _shoppers:
		s.prev_xf = s.xf
		_step_shopper(s, delta)
	_update_folding(delta)
	_check_bumps()
	_check_baskets()
	_update_sound()
	if _oi_time > 0.0:
		_oi_time -= delta
		_oi.visible = _oi_time > 0.0


func _process(_delta: float) -> void:
	_draw(Engine.get_physics_interpolation_fraction())


func _draw(f: float) -> void:
	for i in _shoppers.size():
		var s := _shoppers[i]
		var xf := _hidden if s.gone else s.prev_xf.interpolate_with(s.xf, f)
		_shirt_mm.set_instance_transform(i, xf)
		_body_mm.set_instance_transform(i, xf)
		_hat_mm.set_instance_transform(i, xf if i % 2 == 0 and not s.gone else _hidden)


# ---------------------------------------------------------------- âm thanh

## Tiếng chợ do luồng âm thanh làm (PR âm thanh chợ); chưa có hàm nào thì im lặng.
func _sound_at(sound_name: String, pos: Vector3) -> void:
	if Sound.has_method("play_at"):
		Sound.call("play_at", sound_name, pos)


## Vào chợ thì nghe tiếng rao, ra khỏi chợ thì về tiếng buổi sáng; xe chè lăn gần thì nghe lạch cạch.
func _update_sound() -> void:
	var p := player.global_position
	var inside := CityProps.MARKET_ZONE.grow(1.0).has_point(Vector2(p.x, p.z))
	if inside != _in_market and Sound.has_method("ambience"):
		Sound.call("ambience", "market" if inside else "morning")
	_in_market = inside
	var rattle := false
	if traffic:
		for c in traffic.get("_alley_carts"):
			var pos: Vector3 = c.body.global_position
			var last: Vector3 = _cart_last.get(c.body, pos)
			_cart_last[c.body] = pos
			if pos.distance_to(last) > 0.001 and pos.distance_to(p) < 9.0:
				rattle = true
	if rattle != _rattle_on and Sound.has_method("loop"):
		if rattle:
			Sound.call("loop", "cart_rattle")
		else:
			Sound.call("stop_loop", "cart_rattle")
	_rattle_on = rattle


func _exit_tree() -> void:
	if _rattle_on and Sound.has_method("stop_loop"):
		Sound.call("stop_loop", "cart_rattle")
	if _autotest and player:
		print("[autotest] chợ sáng: %d lần va người, %d thúng đổ, %d/%d sạp đã dọn" % [bumps_total, spills_total,
			_stalls.filter(func(s: Dictionary) -> bool: return s.folded).size(), _stalls.size()])


# ---------------------------------------------------------------- tiện ích vẽ

func _box(st: SurfaceTool, size: Vector3, pos: Vector3, col: Color) -> void:
	var m := BoxMesh.new()
	m.size = size
	var arrays := m.get_mesh_arrays()
	var cols := PackedColorArray()
	cols.resize(arrays[Mesh.ARRAY_VERTEX].size())
	cols.fill(col)
	arrays[Mesh.ARRAY_COLOR] = cols
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st.append_from(tmp, 0, Transform3D(Basis(), pos))


func _offset(m: PrimitiveMesh, pos: Vector3) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(m, 0, Transform3D(Basis(), pos))
	return st.commit()


## MultiMesh một lệnh vẽ. Có màu từng bản (instance_colors) hoặc một màu chung (color),
## không thì lấy màu theo đỉnh của mesh.
func _multimesh(m: Mesh, count: int, instance_colors: bool, color := Color.WHITE) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = instance_colors
	mm.mesh = m
	mm.instance_count = count
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.85
	if color != Color.WHITE:
		mat.albedo_color = color
	else:
		mat.vertex_color_use_as_albedo = true
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mm
