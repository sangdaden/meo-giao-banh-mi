class_name BoTheoNgay
extends Node3D
## U2 · Bơ phản ứng theo ngày (trang "Phác thảo động tác Bơ theo ngày", Sang duyệt 24/10/2026,
## bàn giao /mnt/project-files/cai-thien-2/u2-dong-tac/BAN-GIAO.md). Bơ đứng yên một lúc ngoài phố thì tự làm
## một động tác của riêng ngày đó; bấm phím nào (hay đẩy cần) cũng ngắt ngay. Chỉ để nhìn: không mất sao,
## không giữ chân Bơ, không làm chậm đơn.
##   Thứ Hai  rua_mat       đứng yên 6 s ngoài phố
##   Thứ Ba   ngo_cho       đứng yên 6 s ở chợ sáng hoặc góc cờ
##   Thứ Tư   giu_nuoc      vừa dầm mưa xong, đứng yên chỗ khô (mái che hoặc tạnh mưa) thì giũ nước
##            giu_chan      đứng yên 3 s chỗ khô thì giũ chân
##   Thứ Năm  nam_bong_mat  (lặp) đứng yên 5 s dưới bóng râm (có vật che nắng trưa)
##   Thứ Sáu  hat_xi        đứng yên 3 s trong 2 m quanh bàn thờ Bà Sáu, một lần mỗi lần vào vùng; kèm tiếng, làn khói
##   Thứ Bảy  von_buom      đứng yên 6 s gần bướm (V1 ở bãi cỏ công viên); con bướm gần nhất bay lại đầu Bơ
##   Chủ Nhật chai_long     đứng yên 6 s ở sân Hội mèo (công viên khối 4)
## Số liệu động tác ở assets/models/bo_dong_tac.json (rút từ bo_u2.glb, xem tools/dong_tac_bo/xuat_json_u2.py).
## Nối vào game qua khóa "nodes" của scripts/ngay/thu_hai.gd (nạp mọi ngày), node tự gỡ khi ngày không có động tác.
## Giây chờ: DoKho "dung_yen_giay" (6 s); chỗ riêng ở Thứ Tư, Thứ Năm, Thứ Sáu chờ ngắn hơn theo CHO.

const CLIP := {
	"thu_hai": "rua_mat", "thu_ba": "ngo_cho", "thu_tu": "giu_chan", "thu_nam": "nam_bong_mat",
	"thu_sau": "hat_xi", "thu_bay": "von_buom", "chu_nhat": "chai_long",
}
const CHO := {"thu_tu": 3.0, "thu_nam": 5.0, "thu_sau": 3.0}  ## giây đứng yên ở chỗ riêng (còn lại dung_yen_giay)
const CHO_GIU_NUOC := 0.6     ## vừa dầm mưa: đứng yên chừng này dưới mái là giũ nước liền
const UOT_SAU := 1.0          ## dầm mưa bao lâu thì ướt
const DUNG_TOC := 0.15        ## m/s: chậm hơn chừng này là đứng yên
const BAN_THO_R := 2.0
const CHO_R := 2.5            ## nới vùng chợ ra ngoài dãy sạp
const CO_R := 3.5             ## quanh bàn cờ góc công viên
const BUOM_R := 4.0
const XI_LUC := 1.05          ## "hắt xì!" ở giây này của clip hat_xi
const BUOM_THAM := 3.4        ## bướm bay lại đầu Bơ trong chừng này giây

var main: Node
var player: CharacterBody3D
var day := ""
var dang := ""                ## động tác của node này đang chạy ("" là không)
var lan := 0                  ## số lần đã diễn (test đọc)
var _t := 0.0                 ## giây đã đứng yên ở chỗ hợp
var _clip_t := 0.0
var _uot := 0.0               ## Thứ Tư: giây dầm mưa liền
var _wet := false
var _xi_xong := false         ## Thứ Sáu: đã hắt xì trong lượt vào vùng này
var _xi_phat := false
var _sun: DirectionalLight3D
var _cho := Rect2()


func _ready() -> void:
	name = "BoTheoNgay"
	main = get_parent()
	_setup.call_deferred()


func _setup() -> void:
	day = str(main.day.get("id", "")) if main and "day" in main and main.day is Dictionary else ""
	player = main.get("player") if main else null
	if not CLIP.has(day) or player == null or not player.has_method("has_clip") or not player.has_clip(CLIP[day]):
		queue_free()
		return
	player.clip_finished.connect(_on_clip_finished)
	_sun = main.find_child("MatTroi", true, false) as DirectionalLight3D
	if day == "thu_ba":
		var p0: Vector3 = CityProps.MARKET_STALLS[0].pos
		_cho = Rect2(p0.x, p0.z, 0, 0)
		for s: Dictionary in CityProps.MARKET_STALLS:
			_cho = _cho.expand(Vector2(s.pos.x, s.pos.z))
		_cho = _cho.grow(CHO_R)


## Phím, nút tay cầm, chạm màn hình: ngắt động tác, đếm lại từ đầu (xoay chuột nhìn quanh thì không ngắt)
func _input(event: InputEvent) -> void:
	var bam := (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton \
		or event is InputEventScreenTouch) and event.is_pressed()
	if event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		bam = true
	if bam:
		_ngat()


func _ngat() -> void:
	_t = 0.0
	if dang != "" and is_instance_valid(player) and player.clip == dang:
		player.stop_clip()
	dang = ""


func _on_clip_finished(clip_name: String) -> void:
	if clip_name == dang:
		dang = ""
		_t = 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var pos := player.global_position
	if day == "thu_tu":
		_theo_mua(delta, pos)
	if day == "thu_sau" and _flat(pos, ThuSau.ALTAR_POS) > BAN_THO_R + 0.3:
		_xi_xong = false
	if dang != "":
		_dang_dien(delta, pos)
		return
	if not _dung_yen():
		_t = 0.0
		return
	var cho := _cho_giay(pos)
	if cho < 0.0:
		_t = 0.0
		return
	_t += delta
	if _t >= cho:
		_dien(pos)


## Đang diễn: có ai khác giành động tác, Bơ bị đẩy đi hay người chơi cầm cần thì thôi
func _dang_dien(delta: float, pos: Vector3) -> void:
	if player.clip != dang or not _dung_yen(true):
		_ngat()
		return
	_clip_t += delta
	if dang == "hat_xi" and not _xi_phat and _clip_t >= XI_LUC:
		_xi_phat = true
		_hat_xi(pos)


func _dung_yen(dang_dien := false) -> bool:
	if not player.can_move or player.preview or not player.is_on_floor() or player.climb != "":
		return false
	if player._stun > 0.0 or player._act != "" or player._tui3_on or player.stance in ["crouch", "sneak"]:
		return false
	if not dang_dien and player.clip != "":
		return false
	if "state" in main and not main.state in [main.State.PLAY, main.State.EVENT]:
		return false
	if Vector2(player.velocity.x, player.velocity.z).length() > DUNG_TOC:
		return false
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.1 or Input.is_action_pressed("jump"):
		return false
	return true


## Giây phải đứng yên ở chỗ này trước khi diễn; âm là chỗ này không diễn
func _cho_giay(pos: Vector3) -> float:
	var giay := float(DoKho.v("dung_yen_giay", 6.0))
	var k := giay / 6.0
	match day:
		"thu_ba":
			if not (_cho.has_point(Vector2(pos.x, pos.z)) or _flat(pos, CityProps.CHESS_CORNER) < CO_R):
				return -1.0
		"thu_tu":
			if not _kho(pos):
				return -1.0
			return CHO_GIU_NUOC if _wet else float(CHO.thu_tu) * k
		"thu_nam":
			return float(CHO.thu_nam) * k if _bong_ram(pos) else -1.0
		"thu_sau":
			if _xi_xong or _flat(pos, ThuSau.ALTAR_POS) > BAN_THO_R:
				return -1.0
			return float(CHO.thu_sau) * k
		"thu_bay":
			return giay if _buom_gan(pos) != null else -1.0
		"chu_nhat":
			var san: Rect2 = City.BLOCKS[City.PARK_INDEX]
			return giay if san.has_point(Vector2(pos.x, pos.z)) else -1.0
	return giay


func _dien(pos: Vector3) -> void:
	var c: String = CLIP[day]
	if day == "thu_tu" and _wet:
		c = "giu_nuoc"
		_wet = false
	if day == "thu_sau":
		_xi_xong = true
		_xi_phat = false
	if day == "thu_bay":
		_goi_buom(pos)
	player.play_clip(c)
	dang = c
	_clip_t = 0.0
	_t = 0.0
	lan += 1


# ---------------------------------------------------------------- chỗ riêng từng ngày

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _tia(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, Blocks.LAYER_WORLD | Blocks.LAYER_PROP)
	q.exclude = [player.get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Thứ Tư: có mái trên đầu (như ThuTu._covered) hoặc trời đang tạnh
func _kho(pos: Vector3) -> bool:
	return not ThoiTiet.dang_mua() or _tia(pos + Vector3(0, 0.8, 0), pos + Vector3(0, 14.0, 0))


func _theo_mua(delta: float, pos: Vector3) -> void:
	if player.clip == "giu_nuoc" and dang == "":
		_wet = false   # xe tạt nước (thu_tu.gd) đã cho Bơ giũ rồi
		_uot = 0.0
		return
	if _kho(pos):
		_uot = 0.0
		return
	_uot += delta
	if _uot >= UOT_SAU:
		_wet = true


## Thứ Năm: bắn tia từ lưng Bơ về phía mặt trời, vướng gì là đang ở trong bóng
func _bong_ram(pos: Vector3) -> bool:
	var toi_mat_troi := _sun.global_basis.z.normalized() if is_instance_valid(_sun) else Vector3.UP
	return _tia(pos + Vector3(0, 0.3, 0), pos + Vector3(0, 0.3, 0) + toi_mat_troi * 40.0)


func _ds_buom() -> Array:
	var n := main.find_child("BuomBay", true, false)
	if n == null or not "bugs" in n:
		return []
	return n.bugs.filter(func(b) -> bool: return b.kind == "buom")


func _buom_gan(pos: Vector3) -> Variant:
	var best: Variant = null
	var bd := BUOM_R
	for b in _ds_buom():
		var d := _flat(b.pos, pos)
		if d < bd:
			bd = d
			best = b
	return best


## Con bướm gần nhất bay lại lượn trên đầu Bơ lúc Bơ vờn (trạng thái "tham" của buom_bay.gd)
func _goi_buom(pos: Vector3) -> void:
	var b: Variant = _buom_gan(pos)
	if b == null or b.state == "tham":
		return
	b.state = "tham"
	b.t = BUOM_THAM
	MoHinhConVat.play(b.node, "bay")


## Thứ Sáu: tiếng "hắt xì" nhỏ (tiếng meo ngắn kéo cao) và một làn khói nhang tan trước mũi
func _hat_xi(pos: Vector3) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.play("meow_short", -6.0, 1.55)
	var fwd: Vector3 = -player.visual.global_basis.z if "visual" in player and player.visual else Vector3.FORWARD
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 14
	p.lifetime = 1.1
	p.explosiveness = 0.85
	p.direction = fwd + Vector3.UP * 0.4
	p.spread = 35.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, 0.15, 0)
	p.damping_min = 0.4
	p.damping_max = 0.8
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(0.92, 0.92, 0.9, 0.55))
	g.set_color(1, Color(0.92, 0.92, 0.9, 0.0))
	p.color_ramp = g
	var m := SphereMesh.new()
	m.radius = 0.035
	m.height = 0.07
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	p.mesh = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.top_level = true
	add_child(p)
	p.global_position = pos + Vector3(0, 0.36, 0) + fwd * 0.3
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)
