class_name MucTuan
extends Node3D
## Chó Mực xuyên tuần (luồng "Mực xuyên tuần", M1–M5 ở tuong-tac-con-vat/KE-HOACH.md, Sang chọn 23/10).
## main.gd thêm node này mọi ngày (khóa "nodes" của file ngày), ngày không có trong DAYS thì tự gỡ.
## Không sửa dog.gd: điều khiển Mực bằng home, awake, walk_speed, play_clip() như MucBan.
## - M1 khoảnh khắc mỗi ngày (MOMENTS): Thứ Ba ngửi sạp khô cá ở chợ, Thứ Tư trú mưa dưới mái hiên rồi giũ nước
##   văng vào Bơ, Thứ Năm nằm thở dưới cây dầu, Bơ đẩy chén nước tới. Không bắt buộc: một câu chữ và TIP đồng boa
##   lần đầu mỗi ngày. Ngày đã gặp ghi vào "muc_quen" (GameState toàn cục).
## - M2 chả cá (CHA_CA_DAYS): nhận đơn có Mực canh thì Cô Ba gói thêm miếng chả cá. Tới đầu hẻm 42 bấm E thả,
##   Mực tới ăn (an_banh) rồi ngủ say DoKho "cha_ca_ngu" giây. Mỗi đơn một miếng, đang bị đuổi thả cũng được.
## - M3 quen dần (Thứ Sáu): đuổi tối đa DoKho "muc_duoi_t6" giây, bớt QUEN_STEP giây mỗi khoảnh khắc đã gặp
##   trong tuần, rồi đứng sủa, vẫy đuôi.
## - M4 phím Q: node ở nhóm "con_vat", ConVat (luồng "Cơ chế chung con vật") gọi on_called(pos). Đã làm bạn
##   (SoHangXom.muc_friend()) thì Mực chạy tới ngồi vẫy đuôi rồi đi theo FOLLOW_TIME giây; Q lần nữa khi Mực đang
##   theo và Bơ không mang bánh thì Mực đánh hơi dẫn tới tem Cô Ba gần nhất. Chưa làm bạn: đang canh hẻm thì tiếng
##   meo làm Mực nghi ngờ (hear), không canh thì hé mắt rồi ngủ tiếp.
## - M5 ngủ trưa: Mực đang nằm yên, Bơ không mang bánh đứng yên cạnh NAP_AFTER giây thì cuộn tròn ngủ cạnh,
##   camera lùi ra, nhạc nhẹ; phím bất kỳ là dậy. Ảnh tự vào Sổ hàng xóm (SoHangXom.keep_photo(NAP_PHOTO)).
## Clip mới của Mực (giũ nước, uống nước, đánh hơi) chờ luồng "Phác thảo động tác và phụ kiện thưởng": chưa có
## thì dùng clip gần nhất (FALLBACK). Miếng chả cá và chén nước là khối tạm, chờ phác thảo.

const DAYS := ["thu_hai", "thu_ba", "thu_tu", "thu_nam", "thu_sau", "thu_bay"]
const CHA_CA_DAYS := ["thu_hai", "thu_sau"]
const CON_VAT := "res://scripts/con_vat.gd"
const TIP := 2000
const CHA_CA_SPOT := Vector3(-18.6, 0, 10.25)  ## đầu hẻm 42, ngay sau cổng (z 9), giữa thùng gỗ và xe ba gác
## Lối dọc bờ rào hẻm 42, né xe ba gác đậu sát tường (CityProps: x -17,72, z 11,45..13,55)
const HEM_LANE := [Vector3(-18.95, 0, 14.0), Vector3(-18.95, 0, 11.4)]
const CHA_CA_REACH := 1.6
const SNACK_EAT := 2.4
const QUEN_STEP := 0.8
const FOLLOW_TIME := 30.0
const SNIFF_STEP := 3.0      ## Mực đi trước Bơ chừng này khi đánh hơi
const SNIFF_TIME := 45.0
const NAP_AFTER := 5.0
const NAP_NEAR := 2.0
const NAP_CAM := 5.6         ## camera lùi ra lúc ngủ (thường 3,2 m)
const NAP_PHOTO := "ngu_trua_muc"
## Clip chờ luồng phác thảo động tác -> clip có sẵn dùng tạm
const FALLBACK := {"giu_nuoc": "dung_day", "uong_nuoc": "an_banh", "danh_hoi": "di"}
## Khoảnh khắc mỗi ngày. spot: chỗ Mực; face: Mực nhìn về đây lúc chờ; near: Bơ tới gần ngần này thì Mực đáp
## (không có near thì bấm E ở "bowl"); awning: tìm mái hiên gần điểm này, Mực đứng dưới đó (thay spot).
const MOMENTS := {
	"thu_ba": {"spot": Vector3(-13.25, 0, 3.05), "face": Vector3(-12.4, 0, 3.7), "idle": "ngui", "near": 2.2,
		"line": "Mực đang ngửi sạp khô cá. Thấy Bơ, nó ngửi ngửi rồi vẫy đuôi. (+2.000đ)"},
	"thu_tu": {"awning": Vector3(-25.0, 0, -4.6), "spot": Vector3(-25.0, 0, -4.6), "idle": "ngoi", "near": 1.7,
		"line": "Mực giũ nước văng ướt hết Bơ! Bơ cũng giũ lông theo. (+2.000đ)"},
	"thu_nam": {"spot": Vector3(-41.6, 0, 5.9), "face": Vector3(-41.6, 0, 4.0), "idle": "nam_xuong", "bowl": Vector3(1.4, 0, 0.2),
		"line": "Mực uống ừng ực rồi vẫy đuôi cảm ơn Bơ. (+2.000đ)"},
}

var goi_r := 12.0            ## ConVat: tiếng meo Mực nghe xa chừng này

var _main: Node
var player: CharacterBody3D
var dog: CharacterBody3D
var hud: Node
var day_id := ""
var autotest := false

var _ctl := ""               ## "" = AI canh hẻm; còn lại: kịch bản đang giữ Mực (xem _physics_process)
var _t := 0.0
var _saved := {}             ## home, walk_speed trước khi giữ Mực
var _moment := {}
var _moment_done := false
var _bowl: Node3D
var _path: Array = []        ## các điểm Mực còn phải đi qua (snack_go, back)
var _piece: Node3D
var _piece_ready := false    ## đang mang miếng chả cá của đơn này
var _prompt: Label3D
var _chase_t := 0.0
var _quen_told := false
var _follow: Node            ## MucBan do node này gắn (Q gọi Mực)
var _follow_t := 0.0
var _sniff_target: Node3D
var _sniff_stuck := 0.0
var _sniff_last := 0.0
var _sniff_found := -1.0     ## lúc Mực tìm ra tem (theo _t), -1 = chưa
var _still := 0.0
var _nap_hint: Label3D
var _napping := false
var _nap_t := 0.0
var _nap_prev_ctl := ""
var _nap_prev_clip := ""
var _cam_dist := 0.0
var _cam_tw: Tween


func _ready() -> void:
	_main = get_parent()
	if _main == null or not "day" in _main or not _main.day.get("id", "") in DAYS or not "dog" in _main:
		queue_free()
		return
	name = "MucTuan"
	day_id = _main.day.id
	add_to_group("con_vat")
	add_to_group("ban_do_nho")
	autotest = "--autotest" in OS.get_cmdline_user_args()
	_prompt = Blocks.label(self, "", Vector3.ZERO, 28, Color("#F2C14E"))
	_prompt.top_level = true
	_prompt.no_depth_test = true
	_prompt.visible = false
	_setup.call_deferred()


## Sau khi main dựng xong HUD, deliveries (Thứ Ba, Thứ Tư deliveries dời Mực ra miệng hẻm cạnh xe ôm).
func _setup() -> void:
	player = _main.player
	dog = _main.dog
	hud = _main.hud
	if dog == null or player == null:
		queue_free()
		return
	_nap_hint = Blocks.label(self, "z", Vector3.ZERO, 40, Color("#9FD3D6"))
	_nap_hint.top_level = true
	_nap_hint.visible = false
	if _main.has_signal("order_picked_up"):
		_main.order_picked_up.connect(_on_pick_up)
	if _main.has_signal("order_delivered"):
		_main.order_delivered.connect(func(_i, _o): _piece_ready = false)
	dog.state_changed.connect(_on_dog_state)
	if not ResourceLoader.exists(CON_VAT) and player.has_signal("called"):
		player.called.connect(_on_meow)  # chưa có ConVat: tự nghe tiếng meo (Thứ Năm, Thứ Sáu, Thứ Bảy có phím Q)
	if MOMENTS.has(day_id) and not autotest:
		_start_moment(MOMENTS[day_id])


# ---------------------------------------------------------------- giữ / thả Mực

## Giữ Mực cho kịch bản: tắt canh hẻm, nhớ home và tốc độ đi để trả lại.
func _take(mode: String) -> void:
	if _saved.is_empty():
		_saved = {"home": dog.home, "walk": dog.walk_speed}
	_ctl = mode
	_t = 0.0
	if dog.awake:
		dog.awake = false


## Trả Mực cho AI: về chỗ cũ, canh hẻm lại nếu đơn đang mang có Mực canh.
func _release() -> void:
	_ctl = ""
	_t = 0.0
	dog.play_clip("")
	if not _saved.is_empty():
		dog.home = _saved.home
		dog.walk_speed = _saved.walk
		_saved = {}
	dog.awake = _guard_now()


func _guard_now() -> bool:
	var i: int = _main.order_index
	return _main.state == _main.State.PLAY and player.carrying and i < _main.orders.size() \
		and bool(_main.orders[i].get("boss", false))


## Đặt Mực ngay tại p (không đi bộ tới).
func _place(p: Vector3) -> void:
	dog.global_position = p
	dog.home = p
	dog.set("_prev_pos", p)
	dog.set("_curr_pos", p)
	dog.velocity = Vector3.ZERO


func _clip(c: String) -> void:
	var anim: AnimationPlayer = dog.get("_anim")
	if anim and not anim.has_animation(c) and FALLBACK.has(c):
		c = FALLBACK[c]
	dog.play_clip(c)


func _face(target: Vector3, delta := 1.0, rate := 6.0) -> void:
	var v: Node3D = dog.get("_visual")
	var d := target - dog.global_position
	d.y = 0.0
	if v and d.length() > 0.05:
		v.rotation.y = lerp_angle(v.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-rate * delta))


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _set_zzz(on: bool) -> void:
	var z: Label3D = dog.get("_zzz")
	if z:
		z.visible = on


# ---------------------------------------------------------------- M1 khoảnh khắc mỗi ngày

func _start_moment(m: Dictionary) -> void:
	_moment = m.duplicate()
	if _moment.has("awning"):
		_moment.spot = _under_awning(_moment.awning, _moment.spot)
		_moment.face = _moment.spot + Vector3(0, 0, 2.0 if _moment.spot.z < 0.0 else -2.0)  # nhìn ra đường lớn (z = 0)
	_moment_done = day_id in _met_days()
	_take("moment_idle")
	_place(_moment.spot)
	_clip(_moment.idle)
	_face(_moment.get("face", _moment.spot + Vector3.FORWARD))
	if _moment.has("bowl"):
		_bowl = ViecNho.trinket(Vector3(0.24, 0.07, 0.24), Color("#C9C3B3"), "cyl")  # khối tạm chờ phác thảo
		var water := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.1
		disc.bottom_radius = 0.1
		disc.height = 0.01
		water.mesh = disc
		water.position.y = 0.07
		water.material_override = Blocks.mat(Color("#7FB7D6"))
		_bowl.add_child(water)
		add_child(_bowl)
		_bowl.top_level = true
		_bowl.global_position = _moment.spot + (_moment.bowl as Vector3)


## Mái hiên (nhóm "mai_hien", cao 2,9 m) gần điểm `near` nhất; Mực đứng dưới, trên mặt đất.
func _under_awning(near: Vector3, fallback: Vector3) -> Vector3:
	var best := fallback
	var best_d := INF
	for n in get_tree().get_nodes_in_group("mai_hien"):
		if not n is Node3D:
			continue
		var p: Vector3 = n.global_position
		var d := _flat(p, near)
		if d < best_d:
			best_d = d
			best = p
	best.y = 0.0
	return best


func _met_days() -> Array:
	return GameState.get_global("muc_quen", [])


func _moment_step(delta: float) -> void:
	if _napping:
		return
	var p := player.global_position
	match _ctl:
		"moment_idle":
			_clip(_moment.idle)
			if _moment_done:
				# Xong rồi: Bơ đi xa thì Mực về chỗ cũ cho khỏi đứng mãi một chỗ
				if _flat(p, dog.global_position) > 25.0 and not _saved.is_empty():
					_place(_saved.home)
					_release()
				return
			if _moment.has("near") and _flat(p, dog.global_position) < float(_moment.near):
				_ctl = "moment_react"
				_t = 0.0
		"moment_react":
			_face(_bowl.global_position if _bowl else p, delta)
			match day_id:
				"thu_ba":
					_clip("ngui" if _t < 1.4 else "vay_duoi")
					if _t >= 3.0:
						_moment_finish()
				"thu_tu":
					_clip("giu_nuoc" if _t < 1.2 else "vay_duoi")
					if _t >= 0.35 and _t - delta < 0.35:
						_splash()
						if player.has_method("play_clip"):
							player.play_clip("giu_nuoc")
					if _t >= 2.6:
						_moment_finish()
				"thu_nam":
					_clip("dung_day" if _t < 0.0 else ("uong_nuoc" if _t < 3.0 else "vay_duoi"))
					if _t >= 4.4:
						_moment_finish()


func _bowl_step() -> void:
	if _bowl == null or _ctl != "moment_idle" or _moment_done:
		return
	var near := _flat(player.global_position, _bowl.global_position) < 0.9
	if near:
		_show_prompt("E · Đẩy chén nước cho Mực", _bowl.global_position)
	if near and (Input.is_action_just_pressed("deliver") if InputMap.has_action("deliver") else false):
		push_bowl()


## Bơ dụi đầu đẩy chén nước tới trước mũi Mực (Thứ Năm).
func push_bowl() -> void:
	if _bowl == null or _moment_done:
		return
	if player.has_method("play_clip"):
		player.play_clip("dui_dau")
	var to: Vector3 = _moment.spot + (_moment.get("face", _moment.spot) - _moment.spot).normalized() * 0.5
	create_tween().tween_property(_bowl, "global_position", to, 0.8).set_delay(0.4)
	_ctl = "moment_react"
	_t = -1.2  # đợi chén tới rồi mới uống
	_clip("dung_day")


func _moment_finish() -> void:
	_ctl = "moment_idle"
	_moment_done = true
	_clip(_moment.idle)
	if day_id in _met_days():
		_toast(str(_moment.line).replace(" (+2.000đ)", ""), 3.0)
		return
	var met := _met_days().duplicate()
	met.append(day_id)
	GameState.set_global("muc_quen", met)
	GameState.set_global("vi_tien_boa", int(GameState.get_global("vi_tien_boa", 0)) + TIP)
	GameState.write_save()
	_meet()
	_toast(_moment.line, 3.2)


## Nước văng từ lông Mực (Thứ Tư).
func _splash() -> void:
	var fx := CPUParticles3D.new()
	fx.one_shot = true
	fx.amount = 40
	fx.lifetime = 0.7
	fx.explosiveness = 0.9
	fx.direction = Vector3.UP
	fx.spread = 80.0
	fx.initial_velocity_min = 1.5
	fx.initial_velocity_max = 3.0
	fx.gravity = Vector3(0, -9.0, 0)
	fx.scale_amount_min = 0.5
	var drop := SphereMesh.new()
	drop.radius = 0.02
	drop.height = 0.04
	drop.radial_segments = 4
	drop.rings = 2
	drop.material = Blocks.mat(Color("#BFE3F2"), true)
	fx.mesh = drop
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fx)
	fx.top_level = true
	fx.global_position = dog.global_position + Vector3(0, 0.45, 0)
	fx.emitting = true
	get_tree().create_timer(1.5).timeout.connect(fx.queue_free)
	_sfx_at("splash", dog.global_position)


# ---------------------------------------------------------------- M2 chả cá

func _on_pick_up(_index: int, order: Dictionary) -> void:
	_piece_ready = day_id in CHA_CA_DAYS and bool(order.get("boss", false)) and _piece == null
	if not _piece_ready:
		return
	var lines := ["Cô Ba gói thêm miếng chả cá: thả ở đầu hẻm 42 (E), thằng Mực ăn xong là ngủ khò."]
	if day_id == "thu_sau" and not _quen_told:
		_quen_told = true
		lines.append("Cô Ba: \"Mà thằng Mực bữa nay coi bộ ưa con rồi đó.\"")
	# Đợi câu "Nhận bánh..." của main.gd hiện xong
	var delay := 2.6
	for l: String in lines:
		get_tree().create_timer(delay).timeout.connect(_toast.bind(l, 3.2))
		delay += 3.4


func _cha_ca_step() -> void:
	if not _piece_ready or not player.carrying:
		return
	if _ctl.begins_with("snack") or _napping:
		return
	if _flat(player.global_position, CHA_CA_SPOT) > CHA_CA_REACH:
		return
	_show_prompt("E · Thả miếng chả cá cho Mực", CHA_CA_SPOT)
	if InputMap.has_action("deliver") and Input.is_action_just_pressed("deliver"):
		drop_cha_ca()


## Thả miếng chả cá ở đầu hẻm: Mực tới ăn rồi ngủ say.
func drop_cha_ca() -> void:
	_piece_ready = false
	if player.has_method("play_clip"):
		player.play_clip("dap_tay")
	_piece = ViecNho.trinket(Vector3(0.16, 0.035, 0.11), Color("#E8C9A0"))  # khối tạm chờ phác thảo
	add_child(_piece)
	_piece.top_level = true
	_piece.global_position = CHA_CA_SPOT
	if _follow:
		_unfollow()
	if dog.state == dog.State.CHASE or dog.state == dog.State.BARK:
		dog.call("_set_state", dog.State.TIRED)  # đang đuổi mà ngửi thấy chả cá thì bỏ Bơ, quay lại ăn
	_take("snack_go")
	_go(CHA_CA_SPOT + Vector3(0, 0, 0.45))
	dog.walk_speed = 3.5
	_toast("Mực ngửi thấy mùi chả cá…", 2.0)


func _snack_step(delta: float) -> void:
	if _napping:
		_t -= delta  # ngủ trưa cạnh Mực: giấc ngủ say không trôi
		return
	match _ctl:
		"snack_go":
			_clip("di")
			var arrived := _path_step()
			if arrived or _t > 8.0:
				if not arrived:
					_place(_path.back())  # kẹt đường thì tới luôn
				_ctl = "snack_eat"
				_t = 0.0
				_face(CHA_CA_SPOT)
				_sfx_at("sniff", dog.global_position)
				_toast("Mực ăn miếng chả cá ngon lành… rồi lăn ra ngủ khò!", 3.0)
		"snack_eat":
			_face(CHA_CA_SPOT, delta)
			_clip("an_banh")
			if _t >= SNACK_EAT:
				if _piece:
					_piece.queue_free()
					_piece = null
				_ctl = "snack_sleep"
				_t = 0.0
				_meet()
		"snack_sleep":
			_clip("ngu_gat")
			_set_zzz(true)
			if _t >= float(DoKho.v("cha_ca_ngu", 10.0)):
				_ctl = "back"
				_t = 0.0
				_go(_saved.get("home", dog.home))
				dog.walk_speed = 2.0
		"back":
			_clip("di")
			if _path_step() or _t > 10.0:
				_release()


## Cho Mực đi tới goal; trong hẻm 42 mà phải qua xe ba gác thì đi vòng theo HEM_LANE.
func _go(goal: Vector3) -> void:
	var a := dog.global_position
	_path = []
	if _in_hem(a) and _in_hem(goal) and minf(a.z, goal.z) < 11.4 and maxf(a.z, goal.z) > 13.6:
		_path = HEM_LANE.duplicate() if a.z > goal.z else [HEM_LANE[1], HEM_LANE[0]]
	_path.append(goal)
	dog.home = _path[0]


func _in_hem(p: Vector3) -> bool:
	return p.x > -20.2 and p.x < -16.8 and p.z > 8.5 and p.z < 22.0


## Đi tiếp theo _path; true khi đã tới điểm cuối.
func _path_step() -> bool:
	if _path.is_empty():
		return true
	if _flat(dog.global_position, _path[0]) < 0.35:
		_path.pop_front()
		if _path.is_empty():
			return true
		dog.home = _path[0]
	return false


# ---------------------------------------------------------------- M3 Thứ Sáu quen dần

func _on_dog_state(s: int) -> void:
	if s == dog.State.CHASE:
		_chase_t = 0.0


## Giây Mực còn đuổi Thứ Sáu: số DoKho bớt dần theo số khoảnh khắc đã gặp trong tuần.
func chase_limit() -> float:
	return maxf(float(DoKho.v("muc_duoi_t6", 8.0)) - QUEN_STEP * _met_days().size(), 1.5)


func _quen_step(delta: float) -> void:
	if day_id != "thu_sau":
		return
	if _ctl == "" and dog.state == dog.State.CHASE:
		_chase_t += delta
		if _chase_t >= chase_limit():
			dog.call("_set_state", dog.State.BARK)
			_ctl = "wag"
			_t = 0.0
			_toast("Mực đuổi một đoạn rồi đứng lại sủa, đuôi vẫy vẫy. Coi bộ nó quen Bơ rồi!", 3.0)
	elif _ctl == "wag":
		_face(player.global_position, delta)
		_clip("sua" if _t < 1.0 else "vay_duoi")
		if _t >= 2.4 or dog.state != dog.State.BARK:
			_ctl = ""
			dog.play_clip("")


# ---------------------------------------------------------------- M4 phím Q

## ConVat gọi khi Bơ ngồi kêu meo (Q) trong tầm goi_r.
func on_called(pos: Vector3) -> void:
	if dog == null or _napping:
		return
	if SoHangXom.muc_friend():
		_called_friend()
		return
	if dog.awake and _ctl == "":
		dog.hear(pos, goi_r)  # đang canh hẻm mà kêu meo thì Mực nghe thấy
		return
	if _ctl == "" or _ctl == "moment_idle":
		var prev := _ctl
		_ctl = "peek"
		_t = 0.0
		_clip("he_mat")
		get_tree().create_timer(1.4).timeout.connect(func():
			if _ctl == "peek":
				_ctl = prev
				if prev == "":
					dog.play_clip("")
				else:
					_clip(_moment.get("idle", "")))


func _on_meow(pos: Vector3) -> void:
	if _flat(pos, dog.global_position) <= goi_r:
		on_called(pos)


func _called_friend() -> void:
	var mb := dog.get_node_or_null("MucBan")
	if mb == null:
		# Mực chạy tới, ngồi vẫy đuôi, đi theo một lúc
		if _ctl.begins_with("snack") or _ctl == "moment_react":
			return
		if _ctl == "":
			_take("follow")
		else:
			_ctl = "follow"
		dog.play_clip("")
		_follow = MucBan.attach(dog, player)
		_follow_t = 0.0
		_meet()
		_toast("Bơ kêu meo, Mực chạy tới liền!", 2.0)
		return
	_follow_t = 0.0
	if not player.carrying and _ctl != "sniff":
		_start_sniff(mb)
	else:
		_wag(mb)


## Mực đang đi theo: ngừng theo một nhịp để vẫy đuôi.
func _wag(mb: Node) -> void:
	mb.set_physics_process(false)
	dog.home = dog.global_position
	dog.play_clip("vay_duoi")
	get_tree().create_timer(1.6).timeout.connect(func():
		if is_instance_valid(mb) and not _napping and _ctl != "sniff":
			mb.set_physics_process(true))


func _unfollow() -> void:
	if _follow and is_instance_valid(_follow):
		_follow.queue_free()
	_follow = null


func _follow_step(delta: float) -> void:
	if _ctl != "follow" or _napping:
		return
	_follow_t += delta
	if _follow_t >= FOLLOW_TIME:
		_unfollow()
		_ctl = "back"
		_t = 0.0
		_go(_saved.get("home", dog.home))
		dog.walk_speed = 2.5


## Tem Cô Ba gần nhất còn nằm đó (đồ lạc cho Mực đánh hơi).
func _nearest_stamp() -> Node3D:
	var st: Node = _main.get("stamps")
	if st == null:
		return null
	var best: Node3D = null
	var best_d := INF
	for s in st.get("_items"):
		if not is_instance_valid(s) or not s.visible:
			continue
		var d := _flat(s.global_position, player.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


func _start_sniff(mb: Node) -> void:
	_sniff_target = _nearest_stamp()
	if _sniff_target == null:
		_wag(mb)
		_toast("Mực ngửi quanh một vòng rồi ngồi xuống: quanh đây hết đồ lạc rồi.", 2.6)
		return
	mb.set_physics_process(false)
	if _ctl == "":
		_take("sniff")
	_ctl = "sniff"
	_t = 0.0
	_sniff_stuck = 0.0
	_sniff_last = INF
	_sniff_found = -1.0
	dog.walk_speed = 3.0
	_toast("Mực dí mũi xuống đất đánh hơi… đi theo nó!", 2.6)


func _sniff_step(delta: float) -> void:
	if _ctl != "sniff":
		return
	var mb := dog.get_node_or_null("MucBan")
	if _sniff_target == null or not is_instance_valid(_sniff_target) or not _sniff_target.visible or _t > SNIFF_TIME or player.carrying:
		_end_sniff(mb)
		return
	var goal := _sniff_target.global_position
	var dp := dog.global_position
	var to_goal := _flat(dp, goal)
	if to_goal < 0.7 or _sniff_found >= 0.0:
		dog.home = dp
		_face(goal, delta)
		_clip("sua")
		if _sniff_found < 0.0:
			_sniff_found = _t
			_sfx_at("bark", dp)
			_toast("Gâu! Mực tìm ra tem Cô Ba rồi nè!", 2.4)
		elif _t - _sniff_found > 2.5 and _flat(player.global_position, dp) < 2.5:
			_end_sniff(mb)
		return
	# Đi trước Bơ SNIFF_STEP mét về phía tem; Bơ tụt lại thì đứng ngửi chờ
	var pp := player.global_position
	var dir := Vector3(goal.x - pp.x, 0, goal.z - pp.z)
	var lead := pp + dir.normalized() * minf(SNIFF_STEP, dir.length()) if dir.length() > 0.01 else goal
	if _flat(dp, pp) > SNIFF_STEP + 2.5:
		dog.home = dp
		_clip("ngui")
		_face(pp, delta)
		_sniff_stuck = 0.0
		return
	dog.home = Vector3(lead.x, dp.y, lead.z)
	_clip("danh_hoi")
	# Kẹt (tường, rào) thì nhảy tới chỗ đất trước mặt như MucBan
	if to_goal < _sniff_last - 0.05:
		_sniff_last = to_goal
		_sniff_stuck = 0.0
	elif _flat(dp, dog.home) > 0.4:
		_sniff_stuck += delta
	if _sniff_stuck > 1.5:
		_sniff_stuck = 0.0
		var p := ViecNho.surface(dog.get_world_3d(), dog.home.x, dog.home.z, 0.6)
		_place(Vector3(p.x, maxf(p.y, 0.0), p.z))


func _end_sniff(mb: Node) -> void:
	_sniff_target = null
	_ctl = "follow" if mb else ""
	_follow_t = 0.0
	dog.play_clip("")
	if mb:
		mb.set_physics_process(true)
	elif _ctl == "":
		_release()


# ---------------------------------------------------------------- M5 ngủ trưa

## Mực đang nằm yên (ngủ ở ổ, ngủ say sau chả cá, nằm bóng mát, ngồi cạnh Bơ lúc đi theo).
func _dog_calm() -> bool:
	if _ctl in ["snack_sleep", "moment_idle"]:
		return true
	if _ctl == "" and not dog.awake and dog.state == dog.State.SLEEP and dog.velocity.length() < 0.2:
		return true
	return (_ctl == "follow" or day_id == "thu_bay") and dog.get_node_or_null("MucBan") != null and dog.velocity.length() < 0.2


func _nap_step(delta: float) -> void:
	if _napping:
		_nap_t += delta
		_nap_hint.visible = false
		player.can_move = false
		if _nap_t >= 2.5 and _nap_t - delta < 2.5:
			_snap.call_deferred()
		return
	var ok: bool = not autotest and _main.state == _main.State.PLAY and not player.carrying and player.is_on_floor() \
		and str(player.get("climb")) == "" and Vector2(player.velocity.x, player.velocity.z).length() < 0.15 \
		and _flat(player.global_position, dog.global_position) < NAP_NEAR and _dog_calm()
	_still = _still + delta if ok else 0.0
	_nap_hint.visible = _still > 1.5
	if _nap_hint.visible:
		_nap_hint.global_position = player.global_position + Vector3(0, 0.9 + 0.1 * _still, 0)
		_nap_hint.text = "z" if _still < 3.0 else ("z z" if _still < 4.2 else "z z z")
	if _still >= NAP_AFTER:
		start_nap()


func start_nap() -> void:
	_napping = true
	_nap_t = 0.0
	_still = 0.0
	_nap_prev_ctl = _ctl
	_nap_prev_clip = str(dog.get("_override"))
	var mb := dog.get_node_or_null("MucBan")
	if mb:
		mb.set_physics_process(false)
	if _ctl == "":
		_take("nap")
	dog.home = dog.global_position
	_clip("ngu_gat")
	player.can_move = false
	player.velocity = Vector3.ZERO
	var v: Node3D = player.get("visual")
	if v:
		var d := dog.global_position - player.global_position
		if Vector2(d.x, d.z).length() > 0.05:
			v.rotation.y = atan2(-d.x, -d.z) + PI * 0.5  # nằm ngang, lưng tựa Mực
	if player.has_method("play_clip"):
		player.play_clip("ngu_cuon")
	var rig: Node = player.get("camera_rig")
	if rig and "distance" in rig:
		_cam_dist = rig.distance
		_tween_cam(rig, NAP_CAM, 1.6)
	_music("menu", 1.5)
	_toast("Bơ cuộn tròn ngủ trưa cạnh Mực… (bấm phím bất kỳ để dậy)", 3.0)


func _input(event: InputEvent) -> void:
	if not _napping or _nap_t < 1.0:
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed()
	if pressed:
		get_viewport().set_input_as_handled()
		wake_up()


func wake_up() -> void:
	if not _napping:
		return
	_napping = false
	if player.has_method("play_clip"):
		player.play_clip("vuon_vai")
	if _main.state == _main.State.PLAY:
		player.can_move = true
	var rig: Node = player.get("camera_rig")
	if rig and "distance" in rig and _cam_dist > 0.0:
		_tween_cam(rig, _cam_dist, 0.8)
	_music("delivery", 1.0)
	var mb := dog.get_node_or_null("MucBan")
	if mb and _ctl != "sniff":
		mb.set_physics_process(true)
	if _ctl == "nap":
		_release()
	elif _nap_prev_clip != "":
		dog.play_clip(_nap_prev_clip)
	var n := int(GameState.get_global("ngu_trua_muc", 0)) + 1
	GameState.set_global("ngu_trua_muc", n)
	GameState.write_save()
	_meet()
	if n == 1:
		_toast("Bơ ngủ một giấc ngon lành cạnh Mực. Ảnh đã dán vào Sổ hàng xóm.", 3.2)


func _tween_cam(rig: Node, to: float, secs: float) -> void:
	if _cam_tw:
		_cam_tw.kill()
	_cam_tw = create_tween()
	_cam_tw.tween_property(rig, "distance", to, secs).set_trans(Tween.TRANS_SINE)


## Ảnh ngủ trưa: ẩn HUD một khung rồi chụp màn hình (bản không màn hình thì bỏ qua).
func _snap() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var was: bool = hud.visible if hud and "visible" in hud else false
	if hud and "visible" in hud:
		hud.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	SoHangXom.keep_photo(NAP_PHOTO, img)
	GameState.write_save()
	if hud and "visible" in hud:
		hud.visible = was


# ---------------------------------------------------------------- mỗi khung

func _physics_process(delta: float) -> void:
	if dog == null or not is_instance_valid(dog):
		return
	global_position = dog.global_position  # ConVat đo tầm tiếng meo tới node này
	_t += delta
	_prompt.visible = false
	var holding := _ctl != "" and not _ctl in ["wag", "peek"]
	if holding and dog.awake:
		dog.awake = false  # main.gd bật canh hẻm lúc nhận đơn: kịch bản đang giữ Mực thì tắt lại
	if holding and _ctl != "snack_sleep" and _ctl != "nap":
		_set_zzz(false)
	_moment_step(delta)
	_bowl_step()
	_cha_ca_step()
	_snack_step(delta)
	_quen_step(delta)
	_follow_step(delta)
	_sniff_step(delta)
	_nap_step(delta)
	if _ctl == "back" and _saved.is_empty():
		_ctl = ""


func _show_prompt(text: String, at: Vector3) -> void:
	_prompt.text = text
	_prompt.global_position = at + Vector3(0, 1.1, 0)
	_prompt.visible = true


## Ghim trên bản đồ nhỏ: chỗ khoảnh khắc chưa gặp hôm nay, chỗ thả chả cá khi đang mang.
func ban_do_pins() -> Array:
	var pins := []
	if dog == null:
		return pins
	if not _moment.is_empty() and not _moment_done:
		pins.append({"pos": _moment.spot, "kind": "place", "text": "M", "color": Color("#3B3A36"), "state": "next", "name": "Chó Mực"})
	if _piece_ready and player.carrying:
		pins.append({"pos": CHA_CA_SPOT, "kind": "place", "text": "M", "color": Color("#E8C9A0"), "state": "next", "name": "Thả chả cá cho Mực"})
	return pins


func _meet() -> void:
	if not ResourceLoader.exists(CON_VAT):
		return
	var cv: Script = load(CON_VAT)
	for m in cv.get_script_method_list():
		if m.name == "meet":
			cv.call("meet", "muc")
			return


func _toast(text: String, seconds := 2.0) -> void:
	if hud and hud.has_method("show_toast"):
		hud.show_toast(text, seconds)


func _music(track: String, fade: float) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.music(track, fade)


func _sfx_at(sound_name: String, pos: Vector3) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.play_at(sound_name, pos)
