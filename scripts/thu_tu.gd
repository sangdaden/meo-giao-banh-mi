class_name ThuTu
extends Node3D
## Thứ Tư · Mưa chiều (gói việc thiet-ke-man/goi-viec-thu-tu.md). Khối tạm tới khi có model G5.
## main.gd chỉ cần add_child(preload("res://scripts/thu_tu.gd").new()) sau giao thông; ngày khác tự gỡ.
## - Đường sân thượng (SanThuong) + đi thăng bằng trên ván (ThangBang).
## - Ngập theo đơn: khóa "flood" của đơn trong days.gd = Vector2(mức nước m, giây) → ThoiTiet.ngap. Ngập cả hai
##   đường dọc phía bắc (mặt nước riêng, cùng mức với ThoiTiet). Lội nước thì chậm (DoKho "flood_slow").
## - Vũng nước trơn: chạy nhanh qua thì trượt ngắn. Xe máy chạy qua chỗ ngập tạt nước: khựng.
## - Bồ câu (BoCau): khóa "pigeons" của đơn = "roof" (đậu cạnh chuồng trên mái khối 2) | "street" (xuống đường mổ).
## - Khóa "clear": true: tạnh mưa (đơn 5), Chú Tư dọn bạt sạp báo.
## - 5 nhiệm vụ phụ chấm qua deliveries.extra_quests.

const DAY := "thu_tu"
## Hai đường dọc phía bắc đường lớn (x_min, z_min, rộng, sâu) cũng ngập; đoạn phía nam x = -18 là hẻm 42
const SIDE_ROADS := [Rect2(-22.0, -26.0, 8.0, 21.0), Rect2(12.0, -26.0, 8.0, 21.0), Rect2(12.0, 5.0, 8.0, 21.0)]
const MAIN_ROAD_HALF := 4.9
## Vũng mới trên vỉa hè (x, z, bán kính x, bán kính z): trước quán cà phê Mây, dọc vỉa hè khối 1–2
const PUDDLES := [Vector4(2.6, 5.7, 0.8, 0.45), Vector4(7.6, 5.5, 0.9, 0.4), Vector4(-27.5, -5.6, 0.9, 0.4), Vector4(-8.0, -5.7, 1.0, 0.45)]
const SPLASH_REACH := 2.2          ## xe chạy cách Bơ chừng này (ngang) thì tạt trúng
const SPLASH_MIN_SPEED := 3.0
const BIKE_HIT_SIDE := 0.45        ## gần hơn nữa là xe tông (traffic.gd lo)

var main: Node3D
var player: CharacterBody3D
var hud: Node
var deliveries: Node
var traffic: Node
var thoi_tiet: Node
var san: SanThuong
var balance: ThangBang
var pigeons: BoCau

## Đếm trong đơn đang mang bánh (nhiệm vụ phụ)
var wet_time := 0.0
var wobbles := 0
var crossed_plank := false
var scatters := 0
var splashes := 0
var slips := 0

var _order := -1
var _carrying := false
var _side_floods: Array[MeshInstance3D] = []
var _slip_left := 0.0
var _in_puddle := false
var _bike_cd := {}
var _told := {}
var _tarp_bao: Node3D
var _blind: Control
var _autotest := false


func _ready() -> void:
	name = "ThuTu"
	main = get_parent()
	var day: Dictionary = main.get("day") if main.get("day") != null else {}
	if day.get("id", "") != DAY:
		queue_free()
		return
	player = main.get("player")
	hud = main.get("hud")
	deliveries = main.get("deliveries")
	traffic = main.get_node_or_null("GiaoThong")
	thoi_tiet = main.find_child("ThoiTiet", true, false)
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	san = SanThuong.new()
	add_child(san)
	san.build(main)
	balance = ThangBang.attach(player, san.planks)
	balance.wobbled.connect(func():
		wobbles += 1
		_tell("chao", "Chao rồi! Trên ván nhả Shift, đi chậm thôi." if not DoKho.hard() else "Trượt chân rơi khỏi ván!"))
	balance.balance_changed.connect(func(on: bool):
		if on:
			crossed_plank = true
			_tell("van", "Đi thăng bằng: Bơ tự đi chậm trên ván. Đừng chạy nhanh!"))
	pigeons = BoCau.new()
	pigeons.player = player
	add_child(pigeons)
	pigeons.visible = false
	pigeons.scattered.connect(func(_p): scatters += 1)
	pigeons.blinded.connect(_on_blinded)
	_build_props()
	_build_side_floods()
	_build_puddles()
	_build_blind()
	main.order_picked_up.connect(_on_pick_up)
	main.order_delivered.connect(func(_i, _o): _carrying = false)
	if deliveries and "extra_quests" in deliveries:
		deliveries.extra_quests["duoi_mai_hien"] = func(): return wet_time <= float(DoKho.v("rain_grace", 3.0))
		deliveries.extra_quests["van_vung"] = func(): return crossed_plank and wobbles == 0
		deliveries.extra_quests["bo_cau_yen"] = func(): return scatters == 0
		deliveries.extra_quests["khong_bi_tat"] = func(): return splashes == 0
		deliveries.extra_quests["khong_truot"] = func(): return slips == 0
	# Vào thẳng một đơn (màn Chọn màn): dựng thời tiết như lúc đơn trước vừa xong
	var orders: Array = main.get("orders")
	var first := PlayMode.first_order()
	for k in mini(first, orders.size()):
		_apply_order(orders[k], true)


func _on_pick_up(index: int, order: Dictionary) -> void:
	_order = index
	_carrying = true
	wet_time = 0.0
	wobbles = 0
	crossed_plank = false
	scatters = 0
	splashes = 0
	slips = 0
	_apply_order(order, false)
	if order.get("rooftop_hint", false):
		get_tree().create_timer(2.4).timeout.connect(func():
			_toast("Đường lớn sắp ngập! Theo mũi tên vàng: chồng thùng cạnh lò → mái hiên → cầu thang sắt lên sân thượng.", 4.0))


## Thời tiết, nước ngập, bồ câu theo đơn. instant: đặt ngay (vào thẳng một đơn giữa ngày).
func _apply_order(order: Dictionary, instant: bool) -> void:
	if order.has("flood") and thoi_tiet and thoi_tiet.has_method("ngap"):
		var f: Vector2 = order.flood
		thoi_tiet.ngap(f.x, 0.0 if instant else f.y)
	match order.get("pigeons", ""):
		"roof":
			pigeons.perch_at(san.coop + Vector3(0, 0, 1.2), 1.2)
		"street":
			pigeons.perch_at(Vector3(4.0, 0.04, -5.9), 1.0)
	if order.get("clear", false):
		_clear_sky(instant)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var level := flood_level()
	for m in _side_floods:
		m.position.y = level
		m.visible = level > 0.005
	var pos := player.global_position
	var on_floor := player.is_on_floor()
	# Lội nước: chậm lại
	var wading := on_floor and level > 0.05 and pos.y < level and _in_flood(pos)
	player.speed_scale = float(DoKho.v("flood_slow", 0.4)) if wading else 1.0
	if wading:
		_tell("ngap", "Nước ngập, lội chậm lắm! Lên mái hiên, sân thượng mà đi.")
	_update_puddles(delta, pos, on_floor)
	_update_splash(pos, level)
	if _carrying and _order >= 0 and not _covered(pos):
		wet_time += delta


func flood_level() -> float:
	var f: Variant = thoi_tiet.get("flood") if thoi_tiet else null
	return f.position.y if f is Node3D and is_instance_valid(f) and f.visible else 0.0


func _in_flood(p: Vector3) -> bool:
	if absf(p.z) < MAIN_ROAD_HALF:
		return true
	for r: Rect2 in SIDE_ROADS:
		if r.has_point(Vector2(p.x, p.z)):
			return true
	return false


## Có mái che trên đầu (mái hiên, giàn, ván, nhà): bắn tia lên trên.
func _covered(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.8, 0), p + Vector3(0, 14.0, 0), Blocks.LAYER_WORLD | Blocks.LAYER_PROP)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ---------------------------------------------------------------- vũng nước, xe tạt

func _update_puddles(delta: float, pos: Vector3, on_floor: bool) -> void:
	if _slip_left > 0.0:
		_slip_left -= delta
		if _slip_left <= 0.0:
			player.exit_oil()
	var inside := on_floor and _in_puddle_at(pos)
	var hs := Vector2(player.velocity.x, player.velocity.z).length()
	if inside and not _in_puddle and _slip_left <= 0.0 and hs > float(DoKho.v("puddle_slip_speed", 5.5)):
		_slip_left = float(DoKho.v("puddle_slip_time", 0.6))
		player.enter_oil()
		if _carrying:
			slips += 1
		_tell("vung", "Vũng nước trơn! Chạy nhanh qua là trượt, đi thường thì không sao.")
	_in_puddle = inside


func _in_puddle_at(p: Vector3) -> bool:
	if p.y > 0.3:
		return false
	for pd: Vector4 in ThoiTiet.PUDDLES + PUDDLES:
		var dx := (p.x - pd.x) / pd.z
		var dz := (p.z - pd.y) / pd.w
		if dx * dx + dz * dz < 1.0:
			return true
	return false


func _update_splash(pos: Vector3, level: float) -> void:
	if level < 0.05 or traffic == null or not "_bikes" in traffic:
		return
	var now := Time.get_ticks_msec() * 0.001
	for b in traffic._bikes:
		if not b.active or b.speed < SPLASH_MIN_SPEED or not _in_flood(b.pos):
			continue
		var rel: Vector3 = pos - b.pos
		if rel.y > 1.0:
			continue
		var right: Vector3 = b.dir.cross(Vector3.UP)
		var along := rel.dot(b.dir)
		var side := absf(rel.dot(right))
		if absf(along) > 1.2 or side < BIKE_HIT_SIDE or side > SPLASH_REACH:
			continue
		var key: int = b.get_instance_id()
		if now < float(_bike_cd.get(key, 0.0)):
			continue
		_bike_cd[key] = now + 2.0
		_splash(pos)


func _splash(at: Vector3) -> void:
	if _carrying:
		splashes += 1
	player.hold(float(DoKho.v("splash_stun", 0.6)))
	player.play_clip("giu_nuoc")
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 40
	p.lifetime = 0.7
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.5
	var drop := SphereMesh.new()
	drop.radius = 0.03
	drop.height = 0.06
	drop.radial_segments = 6
	drop.rings = 3
	p.mesh = drop
	p.material_override = Blocks.mat(Color("#DCEBF2", 0.8), true)
	add_child(p)
	p.global_position = at + Vector3(0, 0.2, 0)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	_tell("tat", "Xe máy tạt nước! Đi sát mép hoặc lên cao cho khỏi ướt.")


# ---------------------------------------------------------------- bồ câu che mắt

func _on_blinded(seconds: float) -> void:
	_tell("bo_cau", "Bồ câu bay tán loạn! Lần sau rón rén (Alt) đi ngang cho chim khỏi giật mình.")
	if _blind == null or _autotest:
		return
	_blind.visible = true
	var tw := create_tween()
	tw.tween_property(_blind, "modulate:a", 1.0, 0.15).from(0.0)
	tw.tween_interval(seconds)
	tw.tween_property(_blind, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _blind.visible = false)
	for f: Control in _blind.get_children():
		var t2 := create_tween()
		var start := f.position
		t2.tween_property(f, "position", start + Vector2(randf_range(-160, 160), randf_range(80, 260)), seconds + 0.6)
		t2.tween_callback(func(): f.position = start)


func _build_blind() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_blind = Control.new()
	_blind.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blind.visible = false
	layer.add_child(_blind)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var size := get_viewport().get_visible_rect().size
	for k in 16:
		var f := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#8E949A") if k % 3 else Color("#E8E6E0")
		sb.set_corner_radius_all(60)
		f.add_theme_stylebox_override("panel", sb)
		f.size = Vector2(rng.randf_range(140, 300), rng.randf_range(70, 150))
		f.position = Vector2(rng.randf_range(-60, size.x - 120), rng.randf_range(-80, size.y * 0.7))
		f.rotation = rng.randf_range(-0.6, 0.6)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_blind.add_child(f)


# ---------------------------------------------------------------- dựng cảnh mưa

func _build_props() -> void:
	# Bàn ghế nhựa quán cà phê xếp chồng thành bậc lên mái hiên quán (cạnh đông quán, 0,9 m rồi 1,8 m)
	Blocks.solid_box(self, Vector3(0.5, 0.9, 0.5), Vector3(10.5, 0.45, 5.65), Color("#C8412F"), Blocks.LAYER_PROP)
	Blocks.solid_box(self, Vector3(0.5, 1.8, 0.5), Vector3(10.5, 0.9, 6.35), Color("#3D7FC1"), Blocks.LAYER_PROP)
	# Bạt che sạp báo Chú Tư (đơn 5 tạnh mưa thì dọn), bạt che xe ôm Chú Năm, bạt che ổ Chó Mực
	_tarp_bao = Blocks.box(self, Vector3(1.9, 0.04, 0.9), Vector3(0.4, 1.02, -6.6), Color("#3F6FA8"))
	_tarp(Vector3(-17.5, 2.25, 10.2), Vector2(2.4, 2.0), Color("#3F6FA8"))
	_tarp(Vector3(-18.6, 1.45, 15.0), Vector2(1.6, 1.4), Color("#5E8A5A"))


func _tarp(top: Vector3, size: Vector2, color: Color) -> void:
	Blocks.box(self, Vector3(size.x, 0.04, size.y), top, color)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Blocks.box(self, Vector3(0.04, top.y, 0.04), Vector3(top.x + sx * (size.x / 2.0 - 0.05), top.y / 2.0, top.z + sz * (size.y / 2.0 - 0.05)), Color("#6E6A62"))


## Mặt nước ngập hai đường dọc phía bắc, đi theo mức nước của ThoiTiet.
func _build_side_floods() -> void:
	for r: Rect2 in SIDE_ROADS:
		var pm := PlaneMesh.new()
		pm.size = r.size
		pm.subdivide_width = 6
		pm.subdivide_depth = 12
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = ThoiTiet.water_material(Color("#4E5E58"), ThoiTiet.SKY_TINT, true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(r.get_center().x, 0, r.get_center().y)
		mi.visible = false
		add_child(mi)
		_side_floods.append(mi)


func _build_puddles() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for pd: Vector4 in PUDDLES:
		var c := Vector3(pd.x, 0.05, pd.y)
		for k in 16:
			var a0 := TAU * k / 16.0
			var a1 := TAU * (k + 1) / 16.0
			st.add_vertex(c)
			st.add_vertex(c + Vector3(cos(a1) * pd.z, 0, sin(a1) * pd.w))
			st.add_vertex(c + Vector3(cos(a0) * pd.z, 0, sin(a0) * pd.w))
	var mi := MeshInstance3D.new()
	mi.name = "VungNuocThuTu"
	mi.mesh = st.commit()
	mi.material_override = ThoiTiet.water_material(ThoiTiet.WATER, ThoiTiet.SKY_TINT)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Tạnh mưa: tắt hạt mưa, Chú Tư dọn bạt.
func _clear_sky(instant: bool) -> void:
	if thoi_tiet:
		for n in ["rain", "splash"]:
			var p: GPUParticles3D = thoi_tiet.get(n)
			if p:
				p.emitting = false
	if _tarp_bao:
		if instant:
			_tarp_bao.visible = false
		else:
			var tw := create_tween()
			tw.tween_property(_tarp_bao, "scale", Vector3(0.05, 1, 1), 1.2).set_delay(1.0)
			tw.tween_callback(func(): _tarp_bao.visible = false)
	if not instant:
		_toast("Tạnh mưa rồi! Nước rút dần, bồ câu xuống đường kiếm ăn.", 3.0)


# ---------------------------------------------------------------- tiện ích

func _toast(text: String, seconds := 2.5) -> void:
	if hud and hud.has_method("show_toast"):
		hud.show_toast(text, seconds)


## Mẹo chỉ hiện lần đầu trong ngày.
func _tell(key: String, text: String) -> void:
	if _told.has(key):
		return
	_told[key] = true
	_toast(text, 3.0)
