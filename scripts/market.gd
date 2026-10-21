class_name Market
extends Node3D
## Chợ sáng Thứ Ba (gói T3-4): chợ tạm trên đường lớn giữa khối 2 và khối 5.
## Đơn 1–3 chợ họp: 18 sạp có bạt (gầm 0,5 m, Bơ chui được), thúng hàng đổ được, người đi chợ chen nhau,
## Cô Bảy gánh hàng đi giữa chợ. Đơn 4–5 chợ tan: sạp dọn đi từng cái, để lại chồng thúng và rổ rau,
## ba gác chở hàng về nằm giữa đường, người đi chợ thưa dần.
## Xe bắp nướng của Chú Sáu chặn hẻm giữa khối 3 theo lịch (traffic.gd, ALLEY_BLOCKS).
## Va người đi chợ: Bơ khựng 0,4 s, phát player.bumped("person"). Xe máy chạy chậm qua vùng chợ.
## main.gd chỉ cần: add_child(preload("res://scripts/market.gd").new()) sau giao thông; ngày khác chợ tự gỡ.
## Sạp, thúng, rổ, cân, gánh, xe đẩy là model đã duyệt (trang "Phác thảo Thứ Ba"), vẽ bằng MultiMesh.
## Người bán và người đi chợ còn là khối tạm cho tới khi "Người dân vào game" rig xong 7 người chợ.

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

const MODEL_DIR := "res://assets/models/cho/"
const PILE_STACK := 3         ## sạp dọn xong để lại mấy thúng chồng lên nhau
const CROWD_VIEW_RANGE := 20.0  ## đám đông xa hơn chừng này (cao chưa tới 50 điểm ảnh) thì thôi vẽ: giữ tam giác và lệnh vẽ web
const GANH_REACH := 0.8       ## hai đầu gánh cách vai Cô Bảy bao xa (va vào thúng gánh cũng là va người)
const SHIRTS := [Color("#E39C7A"), Color("#5E8FB8"), Color("#F2E3B8"), Color("#8DB36F"), Color("#D7A9C4"), Color("#C9C3B3"), Color("#B85C7A")]
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
	var seller := false           ## người bán ngồi sau sạp: dọn sạp xong thì về
	var ganh := false             ## Cô Bảy gánh hàng: gánh dài dọc hướng đi
	var leaving := false
	var gone := false
	var box := -1                 ## chỗ trong MultiMesh khối tạm (-1 = đã có người có xương)
	var person: Nguoi             ## người có xương (đã duyệt ở trang phác thảo Thứ Ba); null = khối tạm
	var stand_anim := "dung_chon"
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
var _stalls: Array = []           ## [{pos, xf, kind, slab, poles, pile, folded, anim, seller}]
var _fold_queue: Array[int] = []
var _fold_timer := 0.0
var _baskets: Array = []          ## [{pos, body, shape, spilled}]
var _shoppers: Array[Shopper] = []
var _open_mm := {}                ## loại sạp -> MultiMesh sạp đang bán
var _pile_mm: MultiMesh           ## thúng chồng khi sạp đã dọn (PILE_STACK cái mỗi sạp)
var _pile_ro_mm: MultiMesh
var _scale_mm: MultiMesh          ## cân đĩa trên sạp đồ khô
var _basket_mm: MultiMesh
var _spill_mm: MultiMesh
var _shade_mm: MultiMesh          ## bóng giả dưới bạt sạp (sạp không đổ bóng thật)
var _slots := {}                  ## MultiMesh model chợ -> {of: key -> chỗ, keys: chỗ -> key}
var _ganh_mi: MeshInstance3D
var _stool_mm: MultiMesh           ## thúng úp làm ghế cho người ngồi bán
var _ganh_shopper: Shopper
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

static var _meshes := {}          ## model chợ đã nạp, dùng chung giữa các lần vào màn


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


# ---------------------------------------------------------------- model chợ

## Model chợ dựng trong Blender theo trang "Phác thảo Thứ Ba" (Sang duyệt 21/10), thư mục assets/models/cho/:
## mét thật, gốc ở giữa đáy, một vật liệu màu đỉnh. Dùng chung vật liệu PhoModels.material().
## Bản web (Compatibility) không đổi màu đỉnh linear sang sRGB như Forward+ nên đổi sẵn ở đây.
static func cho_mesh(model: String) -> ArrayMesh:
	if _meshes.has(model):
		return _meshes[model]
	var root: Node = load(MODEL_DIR + model + ".glb").instantiate()
	var src: Mesh = (root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	var to_srgb := RenderingServer.get_rendering_device() == null
	var dst := ArrayMesh.new()
	for i in src.get_surface_count():
		var arrays := src.surface_get_arrays(i)
		if to_srgb and arrays[Mesh.ARRAY_COLOR] != null:
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for k in cols.size():
				cols[k] = cols[k].linear_to_srgb()
			arrays[Mesh.ARRAY_COLOR] = cols
		dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	root.free()
	_meshes[model] = dst
	return dst


## Đặt một model chợ làm con của parent (để nhìn; va chạm đặt riêng).
static func put(parent: Node, model: String, pos: Vector3, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = cho_mesh(model)
	mi.material_override = PhoModels.material()
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- sạp chợ

func _build_stalls() -> void:
	var by_kind := {}
	for def in CityProps.MARKET_STALLS:
		by_kind[def.kind] = by_kind.get(def.kind, 0) + 1
	for kind in by_kind:
		_open_mm[kind] = _model_mm("sap_" + kind, by_kind[kind])
	var n: int = CityProps.MARKET_STALLS.size()
	_pile_mm = _model_mm("thung", n * PILE_STACK)
	_pile_ro_mm = _model_mm("ro_rau", n)
	_scale_mm = _model_mm("can_dia", by_kind.get("kho", 0))
	_shade_mm = _shade(n)
	for i in n:
		var def: Dictionary = CityProps.MARKET_STALLS[i]
		var yaw := 0.0 if def.side < 0 else PI  # mặt trước sạp (bạt rủ) quay ra lòng đường
		var xf := Transform3D(Basis(Vector3.UP, yaw), def.pos)
		var body := StaticBody3D.new()
		body.collision_layer = Blocks.LAYER_PROP
		body.transform = xf
		body.add_to_group("sap_cho")
		body.set_meta("bump_kind", "stall")  # player.gd: chạy húc sạp thì phát bumped("stall")
		add_child(body)
		# Mặt sạp: bạt rủ tới 0,5 m, mặt bàn 0,72 m. Bốn cột tre dù ở góc (±0,78; ±0,45).
		var slab := _shape(body, Vector3(1.6, 0.22, 0.86), Vector3(0, 0.61, 0))
		var poles: Array[CollisionShape3D] = []
		for c in [Vector2(-0.78, -0.45), Vector2(0.78, -0.45), Vector2(-0.78, 0.45), Vector2(0.78, 0.45)]:
			poles.append(_shape(body, Vector3(0.06, 2.1, 0.06), Vector3(c.x, 1.05, c.y)))
		# Dọn xong: chồng thúng và rổ rau phía vỉa hè, cao 0,6 m (nhảy lên được)
		var pile := _shape(body, Vector3(0.62, 0.6, 0.62), Vector3(0, 0.3, -0.2))
		pile.disabled = true
		_mm_show(_open_mm[def.kind], i, xf)
		_mm_show(_shade_mm, i, xf)
		if def.kind == "kho":
			_mm_show(_scale_mm, i, xf * Transform3D(Basis(), Vector3(0.55, 0.72, 0.2)))
		_stalls.append({"pos": def.pos, "xf": xf, "kind": def.kind, "slab": slab, "poles": poles, "pile": pile,
			"folded": false, "anim": -1.0})


func _shape(body: StaticBody3D, size: Vector3, pos: Vector3) -> CollisionShape3D:
	var s := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	s.shape = bs
	s.position = pos
	body.add_child(s)
	return s


## Hiện chồng thúng của sạp i, cao theo h (0..1) để đống hàng nhô lên dần.
func _show_pile(i: int, h: float) -> void:
	var xf: Transform3D = _stalls[i].xf
	var s := maxf(h, 0.02)
	for k in PILE_STACK:
		var local := Transform3D(Basis().scaled(Vector3(1.0, s, 1.0)).rotated(Vector3.UP, k * 0.7), Vector3(0, k * 0.19 * s, -0.2))
		_mm_show(_pile_mm, i * PILE_STACK + k, xf * local)
	_mm_show(_pile_ro_mm, i, xf * Transform3D(Basis().scaled(Vector3(1.0, s, 1.0)), Vector3(0.05, PILE_STACK * 0.19 * s, -0.2)))


# ---------------------------------------------------------------- thúng hàng

## Thúng đặt trước khe giữa hai sạp liền nhau, phía lòng đường.
func _build_baskets(_rng: RandomNumberGenerator) -> void:
	var spots: Array[Vector3] = []
	for i in range(1, CityProps.MARKET_STALLS.size()):
		var p0: Vector3 = CityProps.MARKET_STALLS[i - 1].pos
		var p1: Vector3 = CityProps.MARKET_STALLS[i].pos
		if p0.z == p1.z and absf(p1.x - p0.x) < 2.5:
			spots.append(Vector3((p0.x + p1.x) / 2.0, 0, signf(p0.z) * BASKET_Z))
	_basket_mm = _model_mm("thung", spots.size())
	_spill_mm = _model_mm("thung_do", spots.size())
	for i in spots.size():
		var body := StaticBody3D.new()
		body.collision_layer = Blocks.LAYER_PROP
		body.position = spots[i]
		body.add_to_group("thung_cho")
		add_child(body)
		var s := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 0.28
		cs.height = 0.2
		s.shape = cs
		s.position.y = 0.1
		body.add_child(s)
		_mm_show(_basket_mm, i, Transform3D(Basis(Vector3.UP, i * 1.3), spots[i]))
		_baskets.append({"pos": spots[i], "shape": s, "spilled": false})


func _spill(i: int) -> void:
	var bk: Dictionary = _baskets[i]
	bk.spilled = true
	bk.shape.set_deferred("disabled", true)
	var away := Vector3(bk.pos.x - player.global_position.x, 0, bk.pos.z - player.global_position.z).normalized()
	if away == Vector3.ZERO:
		away = Vector3.RIGHT
	# Thúng lật nghiêng theo hướng Bơ húc, hàng văng ra đất (model thung_do: hàng đổ về phía -z của model)
	_mm_hide(_basket_mm, i)
	_mm_show(_spill_mm, i, Transform3D(Basis.looking_at(-away), bk.pos))
	spills_this_order += 1
	spills_total += 1
	basket_spilled.emit(bk.pos)
	_sound_at("basket_topple", bk.pos)
	if player.has_method("bump"):
		player.bump("stall", bk.pos, 0.2)
	if hud and hud.has_method("show_toast"):
		hud.show_toast("Đổ thúng hàng rồi! Qua chợ thì rón rén thôi.", 1.8)


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
	# Người bán ngồi sau mỗi sạp, nhìn ra đường; dọn sạp xong thì về
	for i in CityProps.MARKET_STALLS.size():
		var def: Dictionary = CityProps.MARKET_STALLS[i]
		var side := signf(def.pos.z)
		var s := Shopper.new()
		s.browse = true
		s.seller = true
		s.stall = i
		s.a = Vector3(def.pos.x + rng.randf_range(-0.3, 0.3), 0, side * 4.8)
		s.b = s.a
		s.face = Vector3(0, 0, -side)
		s.phase = rng.randf() * TAU
		_shoppers.append(s)
	# Cô Bảy gánh hàng rong đi dọc chợ: hai thúng gánh trước sau cũng va được
	var g := Shopper.new()
	g.ganh = true
	g.a = Vector3(zone.position.x + 1.0, 0, -1.2)
	g.b = Vector3(zone.end.x - 1.0, 0, -1.2)
	g.t = 0.3
	g.speed = 0.9
	_shoppers.append(g)
	_ganh_shopper = g
	_ganh_mi = put(self, "ganh", Vector3.ZERO)
	_cast_people()
	# Khối tạm chỉ cho người chưa có model: chỗ trong MultiMesh đánh số riêng
	var boxes := 0
	for sh in _shoppers:
		sh.box = boxes if sh.person == null else -1
		boxes += 1 if sh.person == null else 0
	var torso := BoxMesh.new()
	torso.size = Vector3(0.4, 0.6, 0.24)
	_shirt_mm = _multimesh(_offset(torso, Vector3(0, 1.15, 0)), boxes, true)
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
	_body_mm = _multimesh(st.commit(), boxes, false)
	var hat := BoxMesh.new()
	hat.size = Vector3(0.5, 0.06, 0.5)
	_hat_mm = _multimesh(_offset(hat, Vector3(0, 1.8, 0)), boxes, false, Color("#E8D9A8"))
	for i in boxes:
		_shirt_mm.set_instance_color(i, SHIRTS[rng.randi() % SHIRTS.size()])
		_hat_mm.set_instance_transform(i, _hidden)
	for sh in _shoppers:
		_step_shopper(sh, 0.0)
		sh.prev_xf = sh.xf


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
		var near := Vector2(p.x - s.pos.x, p.z - s.pos.z).length() < BUMP_DIST
		if s.ganh and not near:
			# Hai thúng gánh trước và sau vai
			var fwd := -s.xf.basis.z
			for e in [-GANH_REACH, GANH_REACH]:
				var q: Vector3 = s.pos + fwd * e
				near = near or Vector2(p.x - q.x, p.z - q.z).length() < BUMP_DIST
		if near:
			_bump_cd = BUMP_COOLDOWN
			s.pause = 0.8
			if s.person:
				s.person.play_once("va")
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
	var allowed := int(round(keep * _shoppers.filter(func(x: Shopper) -> bool: return not x.seller).size()))
	var kept := 0
	for s in _shoppers:
		if s.seller:
			continue  # người bán về khi sạp của mình dọn xong (_fold)
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
	for pole: CollisionShape3D in st.poles:
		pole.disabled = true
	st.pile.disabled = false
	if st.kind == "kho":
		_mm_hide(_scale_mm, i)
	_mm_hide(_shade_mm, i)
	for s in _shoppers:
		if s.seller and s.stall == i and not s.gone:
			s.seller = false
			s.gone = instant
			s.leaving = not instant
			_mm_hide(_stool_mm, i)  # người ngồi đứng dậy xách thúng ghế về luôn
	if instant:
		_mm_hide(_open_mm[st.kind], i)
		_show_pile(i, 1.0)
	else:
		st.anim = 0.0


## Dọn sạp: sạp xẹp xuống rồi chồng thúng nhô lên. Không gập sạp Bơ đang chui bên dưới hoặc đứng cạnh.
func _update_folding(delta: float) -> void:
	for i in _stalls.size():
		var st: Dictionary = _stalls[i]
		if st.anim < 0.0:
			continue
		st.anim += delta / FOLD_TIME
		var a: float = minf(st.anim, 2.0)
		var xf: Transform3D = st.xf
		if a < 1.0:
			_mm_show(_open_mm[st.kind], i, Transform3D(xf.basis.scaled(Vector3(1.0, maxf(1.0 - a, 0.02), 1.0)), xf.origin))
		else:
			_mm_hide(_open_mm[st.kind], i)
			_show_pile(i, a - 1.0)
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


## Xe ba gác chở hàng về: nằm dọc giữa đường, gầm 0,4 m chui được. Trên sàn (cao 0,47 m) chất hai chồng thúng,
## rổ rau và cân đĩa; hàng chất cao tới khoảng 1,1 m.
func _place_ba_gac() -> void:
	if _ba_gac:
		return
	_ba_gac = Node3D.new()
	_ba_gac.name = "BaGacChoTan"
	add_child(_ba_gac)
	var b := CityProps._ba_gac(_ba_gac, CityProps.MARKET_BA_GAC, 0.0)
	for x in [-0.95, -0.3]:
		for k in 3:
			put(b, "thung", Vector3(x, 0.47 + k * 0.19, 0.0), k * 0.8)
		Blocks.collider(b, Vector3(0.6, 0.57, 0.6), Vector3(x, 0.47 + 0.285, 0.0), Blocks.LAYER_PROP)
	put(b, "ro_rau", Vector3(-0.95, 1.04, 0.0))
	put(b, "ro_rau", Vector3(0.3, 0.47, 0.3))
	put(b, "can_dia", Vector3(0.3, 0.47, -0.3))
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
		if s.person:
			_draw_person(s, xf)
		else:
			# Chỉ một nửa số người đội nón lá
			_shirt_mm.set_instance_transform(s.box, xf)
			_body_mm.set_instance_transform(s.box, xf)
			_hat_mm.set_instance_transform(s.box, xf if i % 2 == 0 and not s.gone else _hidden)
		if s.ganh:
			# Gánh model dài theo trục X, đòn gánh trên vai cao ~1,3 m: xoay cho dọc hướng đi, nâng 0,3 m
			_ganh_mi.visible = not s.gone
			var gx := s.prev_xf.interpolate_with(s.xf, f)
			_ganh_mi.transform = gx * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, 0.3, 0))


## Người có xương theo vị trí của Shopper; chọn động tác theo việc đang làm.
func _draw_person(s: Shopper, xf: Transform3D) -> void:
	var p := s.person
	p.visible = not s.gone
	if s.gone:
		return
	# Model người nhìn về +Z. Người đi (looking_at hướng đi, -Z) phải xoay nửa vòng; người đứng lựa hàng thì không.
	if s.browse and not s.leaving:
		# Đứng lựa hàng hay ngồi bán: đứng yên đúng chỗ, động tác do animation lo
		p.transform = Transform3D(Basis.looking_at(-s.face), s.a)
	else:
		p.transform = Transform3D(xf.basis * Basis(Vector3.UP, PI), Vector3(xf.origin.x, 0, xf.origin.z))
	if p.busy():
		return
	if s.leaving or (not s.browse and s.pause <= 0.0):
		p.play("ganh_di" if s.ganh else "di_bo")
	else:
		p.play(s.stand_anim)


## Người chợ đã duyệt ở trang phác thảo Thứ Ba. Người có tên ở gần (Cô Tư bán rau, Cô Bảy gánh hàng,
## Bà Tư và Chị Hồng lựa hàng, Anh Tâm dạo chợ) dùng bản nhẹ; đám đông còn lại lặp năm người chợ chung
## (Cô Năm đứng bán, Chú Tám ngồi bán, Bé Thư, Ông Út, Chị Mai) ở bản "dong" ~600 tam giác cho vừa ngân sách web.
## (Chú Sáu đẩy xe bắp nướng nằm ở traffic.gd)
func _cast_people() -> void:
	var browsers: Array = []
	var walkers: Array = []
	var sellers: Array = []
	var cotu: Shopper
	var best := INF
	for s in _shoppers:
		if s.ganh:
			_give_person(s, "ganhhang", "ganh_di", "nhe")
		elif s.seller:
			sellers.append(s)
			# Sạp rau gần giữa chợ dọn sau cùng: Cô Tư ngồi bán tới hết ngày
			var st: Dictionary = _stalls[s.stall]
			if st.kind == "rau" and absf(st.pos.x + 1.0) < best:
				best = absf(st.pos.x + 1.0)
				cotu = s
		elif s.browse:
			browsers.append(s)
		else:
			walkers.append(s)
	_stool_mm = _model_mm("thung", sellers.size())
	for k in sellers.size():
		var s: Shopper = sellers[k]
		if s == cotu:
			_give_person(s, "bancho", "ngoi_rao", "nhe")
		elif k % 2 == 0:
			_give_person(s, "cho4", "mac_ca", "dong")
		else:
			_give_person(s, "cho8", "mac_ca", "dong")
		var seat: float = Nguoi.SEAT.get(s.person.id, 0.0)
		if seat > 0.0:
			# Thúng úp làm ghế, kéo cao cho mặt thúng đúng mặt ghế của người ngồi (thúng thật cao 0,19 m)
			var h := seat + 0.01
			_mm_show(_stool_mm, s.stall, Transform3D(Basis(Vector3.RIGHT, PI).scaled(Vector3(1, h / 0.19, 1)), s.a + Vector3(0, h, 0)))
	const BROWSE := [["cho5", "dung_chon"], ["cho7", "mac_ca"], ["cho6", "xem"]]
	const WALK := ["cho6", "cho7", "cho5"]
	for k in browsers.size():
		if k == 0:
			_give_person(browsers[k], "dicho1", "dung_chon", "nhe")
		elif k == 1:
			_give_person(browsers[k], "dicho3", "xem", "nhe")
		else:
			var b: Array = BROWSE[k % BROWSE.size()]
			_give_person(browsers[k], b[0], b[1], "dong")
	for k in walkers.size():
		if k == 0:
			_give_person(walkers[k], "dicho2", "dung_chon", "nhe")
		else:
			_give_person(walkers[k], WALK[k % WALK.size()], "dung_chon", "dong")


func _give_person(s: Shopper, id: String, stand: String, ban: String) -> void:
	var p := Nguoi.make(id, stand)
	p.ban = ban
	p.look_target = player
	s.person = p
	s.stand_anim = stand
	add_child(p)
	if ban == "dong":
		# Đám đông không đổ bóng thật: chợ ngày Thứ Ba sát ngân sách web (tam giác và lệnh vẽ)
		for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = CROWD_VIEW_RANGE


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


## MultiMesh một lệnh vẽ cho một model chợ.
func _model_mm(model: String, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cho_mesh(model)
	mm.instance_count = count
	mm.visible_instance_count = 0
	_slots[mm] = {"of": {}, "keys": []}
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = PhoModels.material()
	# Không đổ bóng thật cho đồ chợ (web chỉ còn chừng 7k tam giác dư ở góc ngã tư): đồ nhỏ sát đất
	# không cần bóng, còn sạp có tấm bóng giả dưới bạt (_shade_mm)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


## Tấm bóng giả dưới bạt: mặt phẳng tối mờ sát đất, 2 tam giác mỗi sạp thay cho bóng thật của sạp.
func _shade(count: int) -> MultiMesh:
	var quad := PlaneMesh.new()
	quad.size = Vector2(2.0, 1.3)
	quad.center_offset = Vector3(0, 0.012, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.08, 0.06, 0.05, 0.38)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = count
	mm.visible_instance_count = 0
	_slots[mm] = {"of": {}, "keys": []}
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


## Hiện bản `key` của MultiMesh model chợ (cấp chỗ mới nếu chưa có). Chỉ vẽ visible_instance_count bản
## đầu, nên bản ẩn không tốn tam giác như cách thu nhỏ về 0.
func _mm_show(mm: MultiMesh, key: int, xf: Transform3D) -> void:
	var p: Dictionary = _slots[mm]
	if not p.of.has(key):
		p.of[key] = p.keys.size()
		p.keys.append(key)
		mm.visible_instance_count = p.keys.size()
	mm.set_instance_transform(p.of[key], xf)


## Ẩn bản `key`: dời bản cuối vào chỗ trống rồi bớt một bản đang vẽ.
func _mm_hide(mm: MultiMesh, key: int) -> void:
	var p: Dictionary = _slots[mm]
	if not p.of.has(key):
		return
	var slot: int = p.of[key]
	var last: int = p.keys.size() - 1
	if slot != last:
		var moved: int = p.keys[last]
		p.keys[slot] = moved
		p.of[moved] = slot
		mm.set_instance_transform(slot, mm.get_instance_transform(last))
	p.keys.pop_back()
	p.of.erase(key)
	mm.visible_instance_count = p.keys.size()


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
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # người khối tạm: bỏ bóng cho nhẹ web
	add_child(mmi)
	return mm
