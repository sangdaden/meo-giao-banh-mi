class_name ChaoMao
extends Node3D
## Chim chào mào trong lồng tre (luồng "Bồ câu và chim", K3 + K4). Model đã duyệt 23/10 (trang phác thảo con vật mới,
## assets/models/chim/): chao_mao (908 tam giác, clip dau, hot, nhay, ria_long, vo_canh, nghieng_dau), bản nhẹ
## chao_mao_nhe (476); long_tre (1 558) / long_tre_nhe (694), cua_long. Mặt trước +Z, gốc lồng ở giữa đáy.
## - K3: lồng của Ông Bảy treo dưới tán cây lớn ở góc cờ (ChessCorner gọi ChaoMao.for_chess(self)). Bơ bấm Q gần
##   lồng thì chim hót đáp lại (clip hot, tiếng "líu lo"); hót đối 3 lần thì Ông Bảy khen.
## - K4: chim thật trong vài lồng ban công (long_chim P4 do NhaRap gắn tường, ghi chỗ ở NhaRap.bird_cages):
##   ChaoMao.balconies(main) đặt chim nhẹ vào DoKho "chim_ban_cong" lồng gần đường lớn nhất.
## Chỉ là thưởng: không tính vào đơn. Lần đầu hót đáp thì ConVat.meet("chao_mao").

const DIR := "res://assets/models/chim/"
const HOOK_Y := 0.567                  ## móc treo cao chừng này trên gốc lồng (bàn giao luồng phác thảo)
const PERCH := Vector3(0, 0.13, 0.02)  ## cầu đậu dưới, so với gốc lồng long_tre
const DOOR := Vector3(0, 0.034, 0.195)
const BALCONY_PERCH := Vector3(0, 0.16, 0.0)  ## cầu đậu trong lồng long_chim P4 (gốc giữa đáy)
const IDLE := ["dau", "dau", "nghieng_dau", "ria_long", "nhay", "vo_canh"]
const SING_TIME := 1.6
const PRAISE_AFTER := 3                ## hót đối chừng này lần thì Ông Bảy khen

## Bán kính nghe Q của ConVat (DoKho "chao_mao_r")
var goi_r := 3.0
var sings := 0
var nhe := false
var bird: Node3D
var anim: AnimationPlayer
## Chủ lồng khen khi hót đối đủ PRAISE_AFTER lần (góc cờ: Ông Bảy reo và nói); không gán = không ai khen
var praise: Callable

var _label: Label3D
var _idle_t := 0.0
var _sing_t := 0.0
var _rng := RandomNumberGenerator.new()


## Lồng tre treo ở `hook` (điểm móc), có chim bên trong. yaw: xoay mặt trước lồng.
static func hang(parent: Node3D, hook: Vector3, light := false, yaw := 0.0) -> ChaoMao:
	var c := ChaoMao.new()
	c.nhe = light
	c.position = hook
	c.rotation.y = yaw
	var cage := _put(c, "long_tre_nhe" if light else "long_tre", Vector3(0, -HOOK_Y, 0))
	_put(cage, "cua_long", DOOR)
	c._add_bird(Vector3(0, -HOOK_Y, 0) + PERCH)
	parent.add_child(c)  # sau cùng: _ready cần chim đã có
	return c


## Chim đậu trong lồng có sẵn (đồ gắn tường đã gộp): xf là chỗ gốc lồng trong thế giới.
static func in_cage(parent: Node3D, xf: Transform3D) -> ChaoMao:
	var c := ChaoMao.new()
	c.nhe = true
	c.transform = xf
	c._add_bird(BALCONY_PERCH)
	c.bird.rotation.y = 0.5  # nhìn ra phố, hơi xéo
	parent.add_child(c)
	return c


## K3: lồng chào mào của Ông Bảy dưới tán cây lớn góc cờ (cây ở CENTER + (-1,7; 1,7), tán từ ~2,9 m).
static func for_chess(chess: Node3D, praise := Callable()) -> ChaoMao:
	var hook := ChessCorner.CENTER + Vector3(-1.45, 2.45, 0.35)
	var c := hang(chess, hook, false, PI / 2.0)  # mặt lồng nhìn về phía bàn cờ (+X)
	var cord := CylinderMesh.new()  # dây treo lên cành
	cord.top_radius = 0.006
	cord.bottom_radius = 0.006
	cord.height = 0.55
	cord.radial_segments = 4
	cord.rings = 1
	var cm := Blocks.mesh(c, cord, Vector3(0, 0.27, 0), Color("#4A3A2A"))
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.praise = praise
	return c


## K4: chim thật trong `count` lồng ban công gần đường lớn nhất (mỗi lồng cách nhau ít nhất 10 m).
static func balconies(main: Node3D, count := -1) -> Array:
	if count < 0:
		count = int(DoKho.v("chim_ban_cong", 3))
	var cages: Array = NhaRap.bird_cages.duplicate()
	cages.sort_custom(func(a: Transform3D, b: Transform3D): return absf(a.origin.z) < absf(b.origin.z))
	var out := []
	for xf: Transform3D in cages:
		if out.size() >= count:
			break
		var far := true
		for c: ChaoMao in out:
			far = far and c.global_position.distance_to(xf.origin) > 10.0
		if far:
			out.append(in_cage(main, xf))
	return out


static func _put(parent: Node3D, model: String, pos: Vector3) -> Node3D:
	var n: Node3D = load(DIR + model + ".glb").instantiate()
	n.position = pos
	parent.add_child(n)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # đồ nhỏ treo cao: tắt bóng
		mi.visibility_range_end = 30.0
	return n


func _add_bird(at: Vector3) -> void:
	bird = _put(self, "chao_mao_nhe" if nhe else "chao_mao", at)
	if nhe:
		for mi: MeshInstance3D in bird.find_children("*", "MeshInstance3D", true, false):
			mi.visibility_range_end = 18.0
	anim = bird.find_children("*", "AnimationPlayer", true, false)[0]
	anim.get_animation("dau").loop_mode = Animation.LOOP_LINEAR
	_label = Blocks.label(self, "líu lo", at + Vector3(0, 0.32, 0), 40, Color("#FFF8EA"))
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 10
	_label.outline_modulate = Color("#3D2A1E")
	_label.visible = false


func _ready() -> void:
	name = "ChaoMao"
	add_to_group("con_vat")
	goi_r = float(DoKho.v("chao_mao_r", 2.5)) + maxf(global_position.y, 0.0)  # lồng treo cao: tính cả độ cao
	_rng.seed = int(absf(global_position.x * 13.0 + global_position.z * 7.0))
	anim.play("dau")
	anim.seek(_rng.randf() * anim.current_animation_length, true)
	_idle_t = _rng.randf_range(1.0, 4.0)


func _process(delta: float) -> void:
	if _sing_t > 0.0:
		_sing_t -= delta
		_label.visible = true
		_label.position.y = bird.position.y + 0.32 + (SING_TIME - _sing_t) * 0.08
		if _sing_t <= 0.0:
			_label.visible = false
			anim.play("dau", 0.2)
		return
	_idle_t -= delta
	if _idle_t <= 0.0 or (anim.current_animation != "dau" and not anim.is_playing()):
		var clip: String = IDLE[_rng.randi() % IDLE.size()]
		anim.play(clip, 0.2)
		_idle_t = _rng.randf_range(2.0, 5.0)
		if clip == "nhay" and not nhe:
			_sfx("chao_mao_chiep")


## ConVat: Bơ ngồi kêu meo gần lồng thì chim hót đáp lại.
func on_called(_pos: Vector3) -> void:
	sing()


func sing() -> void:
	if _sing_t > 0.0:
		return
	sings += 1
	_sing_t = SING_TIME
	anim.play("hot", 0.1)
	_sfx("chao_mao_hot")
	if ConVat.meet("chao_mao"):
		return  # bạn mới: ConVat tự báo một dòng
	if sings == 1:
		_toast("Chào mào hót đáp lại Bơ: líu lo!", 2.2)
	elif sings == PRAISE_AFTER and praise.is_valid():
		praise.call()


func _toast(text: String, seconds: float) -> void:
	var scene := get_tree().current_scene
	var hud: Node = scene.get("hud") if scene else null
	if hud and hud.has_method("show_toast"):
		hud.show_toast(text, seconds)


func _sfx(sound_name: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.play(sound_name)
