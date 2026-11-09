class_name ChoNam
extends Node3D
## U1 (cải thiện vòng 2): chỗ nằm ưa thích của Bơ, 1–2 chỗ mỗi ngày. Mỗi chỗ là một vệt nắng ấm trên vỉa hè
## (Thứ Tư mưa: chỗ khô dưới mái hiên; Chủ Nhật tối: quầng đèn lồng). Bơ đứng yên trong vệt một lúc thì cuộn tròn
## nằm (động tác có sẵn "ngu_cuon"), nằm đủ lâu lần đầu thì chỗ đó được ghi vào Sổ hàng xóm (trang "Chỗ nằm ưa thích").
## Chỉ là thưởng: không tính vào đơn, không mất sao, đồng hồ đơn vẫn chạy như thường.
## Vệt sáng là một mặt phẳng 2 tam giác, không bóng, tắt khi xa (không thêm model mới).
## Lưu: khóa chung "cho_nam" (Array id đã tìm) trong GameState.
##
## main.gd chỉ cần ChoNam.setup(player, self).

const SAVE_KEY := "cho_nam"
## Mọi chỗ trong tuần, theo thứ tự ngày. x, z là chỗ trên mặt đất (đã dò: trong khối nhà, không trên lòng đường,
## không vướng đồ, "nang" thì trên đầu là trời, "kho" thì có mái che). san = true: ngày đó tự lo (Thứ Bảy mái tôn).
const LIST := [
	{"id": "t2_ca_phe", "day": "thu_hai", "name": "Bậc thềm Cà phê Mây", "x": 8.0, "z": 5.6, "kind": "nang"},
	{"id": "t2_sap_bao", "day": "thu_hai", "name": "Vệt nắng cạnh sạp báo Chú Tư", "x": -4.0, "z": -5.6, "kind": "nang"},
	{"id": "t3_co_cong_vien", "day": "thu_ba", "name": "Bãi cỏ cạnh góc cờ", "x": -27.0, "z": 11.0, "kind": "nang"},
	{"id": "t3_he_lo_banh", "day": "thu_ba", "name": "Vỉa hè trước lò bánh", "x": -28.0, "z": -5.6, "kind": "nang"},
	{"id": "t4_mai_hien", "day": "thu_tu", "name": "Chỗ khô dưới mái hiên", "x": 3.0, "z": 6.2, "kind": "kho"},
	{"id": "t4_hien_khoi_5", "day": "thu_tu", "name": "Hiên nhà khối 5", "x": -10.4, "z": 6.2, "kind": "kho"},
	{"id": "t5_co_cong_vien", "day": "thu_nam", "name": "Bãi cỏ trưa hè", "x": -36.0, "z": 12.0, "kind": "nang"},
	{"id": "t5_he_chung_cu", "day": "thu_nam", "name": "Vỉa hè trước chung cư", "x": 23.0, "z": -5.6, "kind": "nang"},
	{"id": "t6_he_tiem_xe", "day": "thu_sau", "name": "Vỉa hè trước tiệm xe", "x": 27.0, "z": 25.4, "kind": "nang"},
	{"id": "t6_bia_cong_vien", "day": "thu_sau", "name": "Mép công viên", "x": -24.0, "z": 20.0, "kind": "nang"},
	{"id": "t7_mai_ton", "day": "thu_bay", "name": "Mái tôn ấm", "san": true},
	{"id": "t7_co_cong_vien", "day": "thu_bay", "name": "Bãi cỏ công viên", "x": -31.0, "z": 14.0, "kind": "nang"},
	{"id": "cn_den_long", "day": "chu_nhat", "name": "Dưới đèn lồng Hội mèo", "x": -25.0, "z": 18.0, "kind": "den"},
]
const RADIUS := 0.9       ## đứng trong bán kính này (m) là đang ở chỗ nằm
const STILL := 1.2        ## đứng yên chừng này giây thì cuộn tròn nằm
const COLORS := {"nang": Color(1.0, 0.7, 0.2, 0.75), "kho": Color(1.0, 0.88, 0.62, 0.55), "den": Color(1.0, 0.55, 0.2, 0.7)}

var player: CharacterBody3D
var main: Node
var day := ""
var spots: Array = []     ## [{data, pos, disc}] của ngày đang chơi

var _here := -1
var _still := 0.0
var _nap := 0.0
var _sleeping := false
var _t := 0.0


static func setup(p: CharacterBody3D, m: Node) -> ChoNam:
	var d = m.get("day")
	var day := str(d.get("id", "")) if d is Dictionary else str(GameState.day)
	if day_spots(day).filter(func(s): return not s.get("san", false)).is_empty():
		return null
	var n := ChoNam.new()
	n.name = "ChoNam"
	n.day = day
	n.player = p
	n.main = m
	m.add_child(n)
	return n


static func day_spots(day: String) -> Array:
	return LIST.filter(func(s): return s.day == day)


static func found_ids() -> Array:
	return GameState.get_global(SAVE_KEY, [])


static func found(id: String) -> bool:
	return id in found_ids()


static func count() -> int:
	var ids := found_ids()
	return LIST.filter(func(s): return s.id in ids).size()


static func data(id: String) -> Dictionary:
	for s in LIST:
		if s.id == id:
			return s
	return {}


## Ghi một chỗ vào sổ (lần đầu). Trả về true nếu là chỗ mới. Thứ Bảy gọi cho mái tôn của mình.
static func ghi(id: String) -> bool:
	if data(id).is_empty() or found(id):
		return false
	var list := found_ids().duplicate()
	list.append(id)
	GameState.set_global(SAVE_KEY, list)
	GameState.write_save()
	return true


## Câu báo khi tìm được chỗ mới (Label tự dịch theo mẫu).
static func found_text(id: String) -> String:
	return "Chỗ nằm ưa thích mới: %s (%d/%d)" % [str(data(id).get("name", "")), count(), LIST.size()] + "\n" + "Đã ghi vào Sổ hàng xóm"


func _ready() -> void:
	# Chờ va chạm của phố vào thế giới rồi mới dò mặt đất (gọi ngay thì tia dò rơi xuống mặt đường).
	await get_tree().physics_frame
	await get_tree().physics_frame
	for s in day_spots(day):
		if s.get("san", false):
			continue
		var pos := _surface(float(s.x), float(s.z))
		spots.append({"data": s, "pos": pos, "disc": _disc(pos, str(s.kind))})


func _surface(x: float, z: float) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 1.2, z), Vector3(x, -1.0, z), Blocks.LAYER_WORLD | Blocks.LAYER_PROP)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else Vector3(x, 0.0, z)


## Vệt sáng tròn mờ dần ra mép (ảnh gradient tròn), không đổ bóng, tắt khi xa hơn 40 m.
func _disc(pos: Vector3, kind: String) -> MeshInstance3D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.albedo_color = COLORS.get(kind, COLORS.nang)
	mat.disable_receive_shadows = true
	var plane := PlaneMesh.new()
	plane.size = Vector2(RADIUS * 2.2, RADIUS * 2.2)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 40.0
	add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.08  # trên mặt vỉa hè (vỉa hè cao 4 cm, va chạm ở mặt đất)
	return mi


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or spots.is_empty():
		return
	_t += delta
	for s in spots:  # vệt sáng thở nhẹ
		var mat: StandardMaterial3D = s.disc.material_override
		var base: Color = COLORS.get(str(s.data.kind), COLORS.nang)
		mat.albedo_color.a = base.a * (0.8 + 0.2 * sin(_t * 1.6))
	var here := _spot_here()
	var still := Vector2(player.velocity.x, player.velocity.z).length() < 0.2 and player.is_on_floor() \
		and bool(player.get("can_move")) and not ChupAnh.dang_chup
	if here < 0 or not still:
		_wake()
		_here = here
		return
	if here != _here:
		_wake()
		_here = here
	_still += delta
	if _still < STILL:
		return
	if not _sleeping:
		_sleeping = true
		_nap = 0.0
		player.play_clip("ngu_cuon")
		_toast(_sleep_text(str(spots[here].data.kind)), 2.5)
	_nap += delta
	var id := str(spots[here].data.id)
	if _nap >= float(DoKho.v("cho_nam_giay", 6.0)) and ghi(id):
		_sfx("record")
		_toast(found_text(id), 3.5)


func _spot_here() -> int:
	var pp := player.global_position
	for i in spots.size():
		var p: Vector3 = spots[i].pos
		if Vector2(pp.x - p.x, pp.z - p.z).length() < RADIUS and absf(pp.y - p.y) < 0.5:
			return i
	return -1


func _wake() -> void:
	if _sleeping:
		_sleeping = false
		if player.get("clip") == "ngu_cuon":
			player.stop_clip()
	_still = 0.0
	_nap = 0.0


static func _sleep_text(kind: String) -> String:
	match kind:
		"kho":
			return "Chỗ này khô ráo... Bơ cuộn tròn nghe mưa rơi."
		"den":
			return "Đèn lồng ấm quá... Bơ cuộn tròn nằm một chút."
	return "Nắng ấm quá... Bơ cuộn tròn nằm sưởi."


func _toast(text: String, seconds: float) -> void:
	var hud = main.get("hud") if main else null
	if hud and hud.has_method("show_toast"):
		hud.show_toast(text, seconds)


## Tiếng động qua autoload Sound (không gọi thẳng tên autoload: chạy được cả khi chụp ảnh bằng -s).
func _sfx(sound_name: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.play(sound_name)
