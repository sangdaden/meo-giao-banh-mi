class_name BoCauNon
extends Node3D
## K2 · Bồ câu non lạc đàn (Thứ Bảy, việc nhỏ không nằm trong Sổ hàng xóm): một chú bồ câu non rớt khỏi chuồng
## trên mái khối 2, lạc qua vỉa hè khối 5 kêu "chíp chíp". Bơ tới sát thì nó lẽo đẽo theo (vừa nhảy vừa vỗ cánh
## bay thấp, không bao giờ bị bỏ lại); dẫn nó về dưới mái khối 2 thì nó bay lên chuồng, bồ câu mẹ ra đón.
## Không đồng hồ, không thua; xong một lần thì được tiền boa nhỏ và ConVat.meet("bo_cau"), lần sau nó đậu sẵn ở chuồng.
## Model: bo_cau_nhe (G5 đã duyệt) thu nhỏ; chuồng chuong_bo_cau_game (G5) trên cùng mái nhà với chuồng Thứ Tư
## (SanThuong.coop_in), dời ra sát mép mái phía đường cho thấy được từ dưới.
##   var non := BoCauNon.new(); non.player = player; non.city_root = main; non.toast = toast; add_child(non)

signal home_reached

const DAY := "thu_bay"
const SAVE_KEY := "bo_cau_non"
const LOST_AT := Vector3(-9.5, 0, 6.2)      ## vỉa hè khối 5, ngay bên kia đường lớn so với chuồng
const COOP_Z := -7.9                       ## chuồng sát mép mái phía đường, nhìn thấy từ vỉa hè
const BELOW_Z := -6.0                       ## vỉa hè trước dãy nhà khối 2, ngay dưới chuồng
const HOME_R := 3.0                         ## dẫn tới gần chỗ dưới chuồng chừng này là nó tự bay lên
const MEET_R := 1.3                         ## Bơ tới sát chừng này thì nó đi theo
const HINT_R := 8.0                         ## nghe "chíp chíp" từ chừng này
const SCALE := 0.68                         ## bồ câu non nhỏ hơn bồ câu lớn
const FLY_UP := 2.4                         ## bay từ vỉa hè lên chuồng mất chừng này giây
const REWARD := 5000

var player: CharacterBody3D
## Nút chứa nhà phố (main, nơi City.build dựng) để đo mái khối 2; null = nút cha
var city_root: Node3D
## Hiện chữ (ThuBay.toast); không gán thì im
var toast: Callable
var state := "lost"                         ## lost | follow | fly_home | home
var coop := Vector3.INF                     ## chỗ chuồng trên mái (gốc giữa đáy)
var ledge := Vector3.INF                    ## gờ tường mặt tiền trước chuồng: mẹ đứng chờ, con về đậu cạnh

var _bird: Node3D
var _anim: AnimationPlayer
var _mom: Node3D
var _mom_anim: AnimationPlayer
var _hint: Label3D
var _coo: Label3D                           ## "gù gù" trên đầu bồ câu mẹ lúc đang dẫn con về: chỉ chỗ cần tới
var _pos := Vector3.ZERO
var _yaw := 0.0
var _t := 0.0
var _from := Vector3.ZERO
var _told_hint := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "BoCauNon"
	_rng.seed = 2611
	var spots := SanThuong.coop_in(city_root if city_root else get_parent(), COOP_Z)
	coop = spots[0] if spots.size() == 2 else Vector3(-4.4, 9.75, COOP_Z)
	ledge = spots[1] if spots.size() == 2 else coop + Vector3(0, 0, 0.8)
	var hut := ThuTuModels.put(self, "chuong_bo_cau_game", coop)
	_mom = ThuTuModels.put(self, "bo_cau_nhe", _perch(0.3))  # nhìn ra đường (+Z)
	_mom_anim = _anim_of(_mom)
	_bird = ThuTuModels.put(self, "bo_cau_nhe", LOST_AT, 0.0, Vector3.ONE * SCALE)
	_anim = _anim_of(_bird)
	for clip in ["dau", "di", "bay"]:
		for a in [_anim, _mom_anim]:
			a.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for n: Node3D in [_mom, _bird, hut]:  # đồ nhỏ trên mái: tắt bóng, xa quá thì thôi vẽ (chuồng 2328 + 2 × 812 tam giác)
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 45.0 if n != hut else 70.0
	_hint = Blocks.label(self, "chíp chíp", LOST_AT + Vector3(0, 0.6, 0), 44, Color("#FFF8EA"))
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.outline_size = 10
	_hint.outline_modulate = Color("#3D2A1E")
	_hint.visible = false
	_coo = Blocks.label(self, "gù gù", _perch(0.3) + Vector3(0, 0.55, 0), 44, Color("#FFF8EA"))
	_coo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_coo.outline_size = 10
	_coo.outline_modulate = Color("#3D2A1E")
	_coo.visible = false
	_pos = LOST_AT
	_yaw = PI * 0.5
	if bool(GameState.get_day(SAVE_KEY, false, DAY)):
		_settle()


func _anim_of(n: Node3D) -> AnimationPlayer:
	return n.find_children("*", "AnimationPlayer", true, false)[0]


## Chỗ đậu trên gờ tường trước chuồng (lệch sang x một chút).
func _perch(dx: float) -> Vector3:
	return ledge + Vector3(dx, 0.0, 0.0)


func below_coop() -> Vector3:
	return Vector3(coop.x, 0.0, BELOW_Z)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	var pp := player.global_position
	match state:
		"lost":
			var flat := Vector2(pp.x - _pos.x, pp.z - _pos.z).length()
			_hint.visible = flat < HINT_R
			if _hint.visible:
				_hint.global_position = _pos + Vector3(0, 0.55 + sin(_t * 4.0) * 0.04, 0)
				if not _told_hint:
					_told_hint = true
					_say("Nghe tiếng chíp chíp đâu đây... hình như có con chim nhỏ lạc mẹ.", 3.0)
			if flat < MEET_R and absf(pp.y - _pos.y) < 1.0:
				state = "follow"
				_hint.visible = false
				_say("Bồ câu non lạc đàn! Dẫn nó qua đường, tới dưới chỗ bồ câu mẹ gù gù trên mái khối 2.", 3.5)
		"follow":
			_follow(delta, pp)
			_coo.visible = true
			if Vector2(pp.x - coop.x, pp.z - BELOW_Z).length() < HOME_R and _pos.distance_to(pp) < 2.5:
				_fly_home()
		"fly_home":
			var k := clampf(_t / FLY_UP, 0.0, 1.0)
			var goal := _perch(-0.3)
			_pos = _from.lerp(goal, k) + Vector3.UP * sin(k * PI) * 1.2
			_yaw = atan2(-(goal.x - _from.x), -(goal.z - _from.z))
			if k >= 1.0:
				_arrive()


## Theo sau lưng Bơ: gần thì nhảy lò cò, xa hay lệch độ cao thì vỗ cánh bay thấp; càng xa càng nhanh.
func _follow(delta: float, pp: Vector3) -> void:
	var back := Vector3(0, 0, 0.8)
	if player.visual:
		back = player.visual.global_transform.basis.z.normalized() * 0.8
	var goal := pp + Vector3(back.x, 0.0, back.z)
	var d := goal - _pos
	var dist := d.length()
	if dist > 0.15:
		var speed := clampf(dist * 2.6, 1.5, 12.0)
		_pos += d / dist * minf(speed * delta, dist)
		_yaw = atan2(-d.x, -d.z)
	if dist > 25.0:
		_pos = goal  # bị bỏ xa quá (dịch chuyển, cứu kẹt): bay vụt tới
	var flying := dist > 2.2 or absf(d.y) > 0.3
	_play(_anim, "bay" if flying else ("di" if dist > 0.3 else "dau"))


func _fly_home() -> void:
	state = "fly_home"
	_coo.visible = false
	_t = 0.0
	_from = _pos
	_play(_anim, "bay")
	_say("Bồ câu non vỗ cánh bay lên chuồng. Bồ câu mẹ ra đón kìa!", 3.0)


func _arrive() -> void:
	var first := not bool(GameState.get_day(SAVE_KEY, false, DAY))
	_settle()
	_play(_mom_anim, "cat_canh")
	_sfx("jingle_win")
	if first:
		GameState.set_day(SAVE_KEY, true, DAY)
		GameState.set_global("vi_tien_boa", Shop.wallet() + REWARD)
		GameState.write_save()
		_meet()
		_say("Bồ câu non về với mẹ rồi! Tiền boa +%s" % Shop.money(REWARD), 3.5)
	home_reached.emit()


## Đậu yên trước cửa chuồng cạnh mẹ.
func _settle() -> void:
	state = "home"
	_pos = _perch(-0.3)
	_yaw = PI  # nhìn ra đường như mẹ
	_hint.visible = false
	_coo.visible = false


func _process(delta: float) -> void:
	_bird.position = _pos
	_bird.rotation.y = _yaw + PI  # model nhìn +Z, yaw tính theo -Z
	if state == "lost":
		# Lạc mẹ: đứng kêu, thỉnh thoảng vỗ cánh tại chỗ
		if not _anim.is_playing() or _anim.current_animation == "dau" and _rng.randf() < delta * 0.4:
			_play(_anim, "cat_canh" if _rng.randf() < 0.5 else "dau")
	elif state == "home":
		if not _anim.is_playing() or _anim.current_animation == "bay":
			_play(_anim, "mo" if _rng.randf() < 0.5 else "dau")
	if not _mom_anim.is_playing():
		_play(_mom_anim, "mo" if _rng.randf() < 0.4 else "dau")


func _play(a: AnimationPlayer, clip: String) -> void:
	if a.current_animation == clip and a.is_playing():
		return
	a.play(clip, 0.15)


## Autotest: đứng ở đâu cho việc chạy tiếp (đón chim, rồi tới dưới chuồng).
func bot_goal() -> Vector3:
	match state:
		"lost":
			return _pos
		"follow":
			return below_coop()
	return Vector3.INF


func is_home() -> bool:
	return state == "home"


func _meet() -> void:
	if ResourceLoader.exists(BoCau.CON_VAT):
		var cv: Script = load(BoCau.CON_VAT)
		for m in cv.get_script_method_list():
			if m.name == "meet":
				cv.call("meet", "bo_cau")
				return


func _say(text: String, seconds: float) -> void:
	if toast.is_valid():
		toast.call(text, seconds)


func _sfx(sound_name: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.play(sound_name)
