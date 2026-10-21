class_name ShopTapHoa
extends Node3D
## Tạp hóa Cô Hai và đơn ngược Thứ Ba (gói T3-3, trang thiết kế màn mục 06 và 13).
## Đơn 2 Thứ Ba: Cô Ba hết trứng, sai Bơ qua tạp hóa khối 2 mua một túi 6 trứng rồi mang về lò.
## Đồng hồ chạy từ lúc nhận việc ở lò tới lúc đặt túi trứng ở lò. Trên đường về, đáp đất từ cao
## hơn 1 m hoặc va người, xe đẩy, sạp chợ, xe máy là vỡ một quả (player.carry_fragile, gói này thêm).
## Số trứng còn lại ghi vào GameState.eggs_brought để màn bếp ráp nhanh ổ trứng cho đơn 3 (gói T3-5).
##
## Hai phần:
## - build(): vỏ tiệm và nội thất đứng yên (City dựng qua ô "tap_hoa" trong CityProps.SLOTS).
##   Khối 2 dãy bắc, x 5,6 → 10, mặt tiền mở ra đường phía bắc (z = -24), lòng tiệm sâu 7,3 m.
##   Có model res://assets/models/pho/tap_hoa.glb (luồng Nhà và đồ phố) thì nạp model làm vỏ,
##   va chạm vẫn là các khối ở đây (ẩn hình).
## - Một node ShopTapHoa (deliveries.gd tạo khi trong ngày có đơn "errand"): Cô Hai đưa túi trứng,
##   vết trứng vỡ, chỉ báo số trứng trên HUD, ghi số trứng cho màn bếp (GameState.eggs_brought).
##   Đường đi và đồng hồ do main.gd lo (đơn errand: lấy đồ ở vùng quanh COUNTER_POINT, mang về lò).
## Toàn bộ là khối tạm. Nội thất, túi trứng, tư thế Bơ ngậm túi và animation Cô Hai chờ Sang duyệt
## trang "Phác thảo Thứ Ba".

const MODEL := "res://assets/models/pho/tap_hoa.glb"
const X0 := 5.6
const X1 := 10.0
const FRONT_Z := -24.0
const DEPTH := 7.3
const GROUND_H := 3.2
## Chỗ Bơ đứng trước quầy để nhận túi trứng ("pos" của đơn 2 Thứ Ba trong days.gd)
const COUNTER_POINT := Vector3(7.8, 0, -18.9)
const COUNTER_TOP := Vector3(7.8, 0.95, -18.1)
const CO_HAI := Vector3(7.8, 0, -17.45)
const EGGS := 6
## Vỡ nhiều hơn số này thì ổ trứng đơn 3 tối đa 1 sao bếp, và đơn mua trứng mất sao nguyên vẹn
const EGGS_OK := 3

const WALL := Color("#E39C7A")
const SHELF := Color("#8A9A98")
const RICE := Color("#EDE3C8")
const FREEZER := Color("#D8E4E6")
const GLASS := Color(0.75, 0.9, 0.95, 0.45)
const COUNTER := Color("#9B6A3A")
const SHIRT := Color("#E8C15A")
const GOODS := [Color("#C8412F"), Color("#E8C15A"), Color("#3D7FB8"), Color("#4E8F4A"), Color("#F4F1EA"), Color("#D7A9C4")]

var player: CharacterBody3D
var hud: CanvasLayer
var autotest := false
## "" (chưa tới quầy) | "carry" (đang ngậm túi trứng) | "done" (đã đưa Cô Ba)
var state := ""
var _main: Node
var _order := -1
var _co_hai: Nguoi
var _bag_on_counter: Node3D
var _delivered := 0               ## số trứng còn lại lúc về tới lò
var _rustle_t := 0.0


# ---------------------------------------------------------------- dựng tiệm

## Vỏ tiệm và đồ trong tiệm. z0 là mặt tiền (dãy bắc nhìn ra phía bắc), lòng tiệm lùi về +z.
static func build(parent: Node3D, x0: float, x1: float, z0: float, depth: float) -> void:
	var has_model := ResourceLoader.exists(MODEL)
	var w := x1 - x0
	var cx := (x0 + x1) / 2.0
	var zb := z0 + depth          # tường sau
	var zc := z0 + depth / 2.0
	var h := 9.0
	# Vách hông, tường sau, các tầng trên
	for sx in [x0 + 0.1, x1 - 0.1]:
		_solid(parent, Vector3(0.2, GROUND_H, depth), Vector3(sx, GROUND_H / 2.0, zc), WALL, has_model)
	_solid(parent, Vector3(w, 0.2, depth), Vector3(cx, GROUND_H + 0.1, zc), WALL, has_model)  # trần
	_solid(parent, Vector3(w - 0.15, h - GROUND_H - 0.2, depth), Vector3(cx, (h + GROUND_H + 0.2) / 2.0, zc), WALL, has_model)
	# Tường sau có cửa sau nhỏ ở góc phải, mở ra hẻm giữa khối 2: lối tắt từ phía lò bánh
	var door := Vector2(x1 - 0.95, x1 - 0.2)
	var left_w := door.x - (x0 + 0.2)
	_solid(parent, Vector3(left_w, GROUND_H, 0.2), Vector3(x0 + 0.2 + left_w / 2.0, GROUND_H / 2.0, zb - 0.1), WALL.darkened(0.1), has_model)
	_solid(parent, Vector3(door.y - door.x, GROUND_H - 1.4, 0.2), Vector3((door.x + door.y) / 2.0, 1.4 + (GROUND_H - 1.4) / 2.0, zb - 0.1), WALL.darkened(0.1), has_model)
	if not has_model:
		Blocks.box(parent, Vector3(w - 0.4, 0.02, depth - 0.2), Vector3(cx, 0.03, zc), Color("#CFC6B2"))  # nền gạch bông
		Blocks.label(parent, "TẠP HÓA CÔ HAI", Vector3(cx, 3.6, z0 - 0.2), 52, Color("#C8412F"))
	CityProps.awning(parent, w, Vector3(cx, 2.9, z0 - 0.5), "mai_hien_xanh", -1.0)
	# Kệ hàng cao gần sát trần dọc vách trái (leo được: các tầng kệ cách nhau 0,6 m)
	_shelf(parent, Vector3(x0 + 0.45, 0, z0 + 0.6), Vector2(0.45, 4.6), 2.8)
	# Kệ thấp hơn dọc vách phải, phía trong
	_shelf(parent, Vector3(x1 - 0.45, 0, z0 + 3.4), Vector2(0.45, 2.2), 2.2)
	# Bao gạo xếp bậc ở góc phải mặt tiền: 0,4 → 0,8 → 1,2 m, leo lên nóc tủ kem rồi lên kệ
	for k in 3:
		var sz := Vector3(1.0, 0.4 * (k + 1), 0.5)
		var b := Blocks.solid_box(parent, sz, Vector3(x1 - 0.75, sz.y / 2.0, z0 + 0.45 + k * 0.5), RICE, Blocks.LAYER_PROP)
		b.add_to_group("bao_gao")
	# Tủ kem nắp kính: trơn như vũng dầu, đứng lên là trượt
	var fz := z0 + 2.4
	_solid(parent, Vector3(1.0, 0.85, 1.0), Vector3(x1 - 0.75, 0.425, fz), FREEZER, false, Blocks.LAYER_PROP)
	Blocks.box(parent, Vector3(0.96, 0.03, 0.96), Vector3(x1 - 0.75, 0.865, fz), GLASS)
	var lid := Area3D.new()
	lid.name = "NapTuKem"
	lid.collision_layer = 0
	lid.collision_mask = 2
	lid.position = Vector3(x1 - 0.75, 0.95, fz)
	var ls := CollisionShape3D.new()
	var lb := BoxShape3D.new()
	lb.size = Vector3(1.0, 0.2, 1.0)
	ls.shape = lb
	lid.add_child(ls)
	lid.body_entered.connect(func(b: Node3D): if b.has_method("enter_oil"): b.enter_oil())
	lid.body_exited.connect(func(b: Node3D): if b.has_method("exit_oil"): b.exit_oil())
	parent.add_child(lid)
	# Quầy và cái cân, Cô Hai đứng sau quầy
	_solid(parent, Vector3(2.2, 0.95, 0.6), Vector3(COUNTER_TOP.x, 0.475, COUNTER_TOP.z), COUNTER, false, Blocks.LAYER_PROP)
	Blocks.box(parent, Vector3(0.3, 0.06, 0.25), COUNTER_TOP + Vector3(-0.7, 0.03, 0), Color("#C9CFCD"))   # đế cân
	Blocks.box(parent, Vector3(0.22, 0.16, 0.06), COUNTER_TOP + Vector3(-0.7, 0.14, 0.08), Color("#E8E2D0"))  # mặt số
	Blocks.box(parent, Vector3(0.34, 0.02, 0.3), COUNTER_TOP + Vector3(-0.7, 0.24, 0), Color("#C9CFCD"))  # đĩa cân
	_shelf(parent, Vector3(cx - 1.3, 0, zb - 0.45), Vector2(2.6, 0.35), 2.6, true)  # kệ sau lưng Cô Hai
	var co_hai := StaticBody3D.new()
	co_hai.collision_layer = Blocks.LAYER_PROP
	co_hai.position = CO_HAI
	co_hai.set_meta("bump_kind", "person")
	parent.add_child(co_hai)
	# Thân Cô Hai (người có xương, scripts/nguoi.gd) dựng ở _ready, sau khi Blocks.merge_static gộp khối
	var cs := CollisionShape3D.new()
	var cb := BoxShape3D.new()
	cb.size = Vector3(0.5, 1.6, 0.35)
	cs.shape = cb
	cs.position.y = 0.8
	co_hai.add_child(cs)
	Blocks.label(co_hai, "Cô Hai", Vector3(0, 2.1, 0), 40)
	if has_model:
		# Model nạp sau khi Blocks.merge_static gộp khối (glb không dùng material_override)
		var model: Node3D = load(MODEL).instantiate()
		model.position = Vector3(x1, 0, z0)
		model.rotation.y = PI
		parent.add_child.call_deferred(model)


## Khối đặc; hidden = chỉ có va chạm (khi đã có model vỏ tiệm)
static func _solid(parent: Node3D, size: Vector3, pos: Vector3, color: Color, hidden := false, layer := Blocks.LAYER_WORLD) -> StaticBody3D:
	if not hidden:
		return Blocks.solid_box(parent, size, pos, color, layer)
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = pos
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)
	return body


## Kệ hàng: corner là góc gần mặt tiền (x tâm, z đầu kệ), size = (sâu x, dài z); along_x = kệ nằm ngang
static func _shelf(parent: Node3D, corner: Vector3, size: Vector2, height: float, along_x := false) -> void:
	var sx := size.y if along_x else size.x
	var sz := size.y if not along_x else size.x
	var center := corner + (Vector3(sx / 2.0, 0, 0) if along_x else Vector3(0, 0, sz / 2.0))
	# Cột hai đầu và các tầng kệ (va chạm từng tầng để Bơ nhảy lên được)
	for end in [-1.0, 1.0]:
		var off := Vector3(end * (sx / 2.0 - 0.03), height / 2.0, 0) if along_x else Vector3(0, height / 2.0, end * (sz / 2.0 - 0.03))
		Blocks.solid_box(parent, Vector3(0.06 if along_x else sx, height, sz if along_x else 0.06), center + off, SHELF, Blocks.LAYER_PROP)
	var y := 0.6
	var n := 0
	while y < height:
		Blocks.solid_box(parent, Vector3(sx, 0.04, sz), center + Vector3(0, y, 0), SHELF, Blocks.LAYER_PROP)
		# Hàng hóa: mấy khối màu đứng trên tầng kệ (chỉ để nhìn)
		var count := int((sz if not along_x else sx) / 0.35)
		for k in count:
			var t := -0.5 + (k + 0.5) / count
			var gpos := center + (Vector3(t * sx, y + 0.13, 0) if along_x else Vector3(0, y + 0.13, t * sz))
			Blocks.box(parent, Vector3(0.22, 0.22, 0.22) * (0.8 + 0.1 * ((k + n) % 3)), gpos, GOODS[(k * 2 + n) % GOODS.size()])
		y += 0.6
		n += 1


# ---------------------------------------------------------------- đơn ngược

## p: Bơ, h: HUD. Node này nằm trong Deliveries, cha của Deliveries là màn giao (main.gd):
## nghe order_delivered để ghi số trứng, và đặt main.intact = false khi vỡ quá 3 quả.
func setup(p: CharacterBody3D, h: CanvasLayer, is_autotest := false) -> void:
	player = p
	hud = h
	autotest = is_autotest
	if _co_hai:
		_co_hai.look_target = p
	if player.has_signal("fragile_damaged"):
		player.fragile_damaged.connect(_on_egg_broken)
	var deliveries := get_parent()
	_main = deliveries.get_parent() if deliveries else null
	if _main and _main.has_signal("order_delivered"):
		_main.order_delivered.connect(_on_delivered)


func _ready() -> void:
	name = "TapHoaCoHai"
	# Cô Hai sau quầy, nhìn ra cửa tiệm (-Z); model Nguoi nhìn +Z nên quay nửa vòng
	_co_hai = Nguoi.make("cohai", "viec_rieng")
	_co_hai.position = CO_HAI
	_co_hai.rotation.y = PI
	add_child(_co_hai)
	_bag_on_counter = Node3D.new()
	add_child(_bag_on_counter)
	_bag_on_counter.position = COUNTER_TOP + Vector3(0.3, 0.05, 0)
	Blocks.box(_bag_on_counter, Vector3(0.11, 0.07, 0.075), Vector3.ZERO, Color(0.96, 0.95, 0.92, 0.6))


## Bơ tới quầy (main.gd nhận đơn errand ở vùng quanh COUNTER_POINT): Cô Hai cân trứng, chìa túi qua quầy,
## Bơ ngậm túi 6 trứng. Đồng hồ đơn chạy từ lúc này tới lúc về lò.
func begin(order_index: int) -> void:
	_order = order_index
	state = "carry"
	_delivered = 0
	_bag_on_counter.visible = false
	player.carry_fragile("trung6", EGGS)
	if player.bread:
		player.bread.visible = false  # đơn này không mang bánh, túi bánh bên hông để trống
	_set_hud_eggs(EGGS)
	_sfx("scale_clank", COUNTER_TOP)
	_sfx("paper_slip", COUNTER_TOP)
	# Chìa túi trứng qua quầy (dua_tui, trang phác thảo Thứ Ba) rồi dặn dò
	_co_hai.play_once("dua_tui", "noi", 2.5)
	_toast("Cô Hai: \"Trứng gà ta đó, cầm nhẹ tay nghen!\" Đừng nhảy từ trên cao, đừng va người.", 3.0, 1.8)


func eggs() -> int:
	if state == "done":
		return _delivered
	return player.fragile_count if player and state == "carry" else 0


func _physics_process(delta: float) -> void:
	if state != "carry" or player == null:
		return
	# Túi nilon sột soạt theo bước chân
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	_rustle_t -= delta * clampf(hspeed / 5.0, 0.0, 1.6)
	if hspeed > 1.0 and _rustle_t <= 0.0:
		_rustle_t = 0.35
		_sfx("nylon", player.global_position)


## Về tới lò (main phát order_delivered sau khi chấm điểm)
func _on_delivered(index: int, _order_data: Dictionary) -> void:
	if index != _order or state != "carry":
		return
	_delivered = player.fragile_count
	state = "done"
	player.carry_fragile("", 0)
	_set_hud_eggs(-1)
	_bag_on_counter.visible = true  # Cô Hai xếp túi khác lên quầy cho lần chơi sau
	# Màn bếp (PR bếp Thứ Ba) khai GameState.eggs_brought; ghi qua set() để file này chạy được cả khi chưa có
	var gs: Script = GameState
	if "eggs_brought" in gs:
		gs.set("eggs_brought", _delivered)
	if _main and _main.get("result_notes") is Array and not (_main.result_notes as Array).is_empty():
		_main.result_notes[-1] += ", về lò còn %d/%d trứng" % [_delivered, EGGS]
	var tail := "Vào bếp ráp ổ trứng nha!" if _delivered > 0 else "Bể hết rồi, ổ trứng phải làm không trứng..."
	_toast("Cô Ba nhận túi: còn %d/%d quả. %s" % [_delivered, EGGS, tail], 3.0, 2.2)


func _on_egg_broken(remaining: int) -> void:
	if state != "carry":
		return
	var deliveries := get_parent()
	if deliveries and "side_ok" in deliveries:
		deliveries.side_ok[_order] = false
	if remaining <= int(DoKho.v("eggs_lose_at", EGGS_OK)) and _main and "intact" in _main:
		_main.intact = false
	_set_hud_eggs(remaining)
	# Vệt trứng vỡ trên đất (decal tạm: lòng trắng, lòng đỏ)
	# Quả trứng rơi khỏi túi ngay trước mũi Bơ, lệch ngẫu nhiên một chút
	var ahead: Vector3 = -player.visual.global_transform.basis.z if "visual" in player and player.visual else Vector3.FORWARD
	var at := player.global_position + ahead * 0.35 + Vector3(randf_range(-0.12, 0.12), 0, randf_range(-0.12, 0.12))
	var splat := Node3D.new()
	add_child(splat)
	splat.global_position = Vector3(at.x, at.y + 0.02, at.z)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.09
	disc.bottom_radius = 0.09
	disc.height = 0.005
	disc.radial_segments = 12
	disc.rings = 1
	Blocks.mesh(splat, disc, Vector3.ZERO, Color(0.97, 0.95, 0.88, 0.85))
	var yolk := disc.duplicate() as CylinderMesh
	yolk.top_radius = 0.035
	yolk.bottom_radius = 0.035
	Blocks.mesh(splat, yolk, Vector3(0.01, 0.004, 0), Color("#F2B233"))
	get_tree().create_timer(12.0).timeout.connect(splat.queue_free)
	if remaining == 0:
		_toast("Bể hết trứng rồi! Vẫn mang túi về cho Cô Ba nhé.", 2.5)
	elif remaining == int(DoKho.v("eggs_lose_at", EGGS_OK)):
		_toast("Bể một quả! Còn %d/%d. Ổ trứng sẽ mất sao bếp." % [remaining, EGGS], 2.5)
	else:
		_toast("Bể một quả! Còn %d/%d." % [remaining, EGGS], 2.0)


func _set_hud_eggs(n: int) -> void:
	if hud and hud.has_method("set_eggs"):
		hud.set_eggs(n, EGGS)


func _sfx(sound_name: String, at: Vector3) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.play_at(sound_name, at)


func _toast(text: String, seconds := 2.0, delay := 0.0) -> void:
	if hud == null or not hud.has_method("show_toast"):
		return
	if delay <= 0.0:
		hud.show_toast(text, seconds)
	else:
		get_tree().create_timer(delay).timeout.connect(func(): hud.show_toast(text, seconds))
