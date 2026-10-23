class_name ChuotTi
extends Node3D
## V6 · Chuột Tí trong bếp Cô Ba: ngồi ôm vụn bánh gặm (gam_banh) ở góc tường trái, giữa bao bột và bàn đồ chua.
## Bơ đi lại gần thì Tí đứng hai chân vẫy tay chào (chao), lần đầu ConVat.meet("chuot_ti"). Bơ chạy ào tới thì Tí
## chạy trốn sau bao bột (tron) một lúc rồi ra lại. Không cản bước nào của bếp, không tính điểm.
## Gắn vào bếp: ChuotTi.attach(self) (một dòng trong kitchen.gd). Model chuot_ti (assets/models/con_vat/).

const HOME := Vector3(-2.47, 0, -0.62)
const HIDE := Vector3(-2.52, 0, -1.6)       ## sau bao bột (BAO -2,2; -1,45)
const NEAR := 0.85
const RUN := 1.6                             ## Bơ chạy nhanh hơn chừng này tới gần thì Tí trốn
const HIDE_TIME := 3.0
const WAVE_COOL := 9.0
const SPEED := 1.8

var player: CharacterBody3D
var kitchen: Node
var model: Node3D
var waves := 0
var state := "gam"                            ## gam | chao | chay_tron | tron | ve
var _t := 0.0
var _cool := 0.0
var _rng := RandomNumberGenerator.new()


static func attach(k: Node) -> ChuotTi:
	var c := ChuotTi.new()
	c.kitchen = k
	c.player = k.get("player")
	k.add_child(c)
	return c


func _ready() -> void:
	name = "ChuotTi"
	add_to_group("con_vat")
	_rng.seed = 9
	model = MoHinhConVat.put(self, "chuot_ti", HOME, 0.0, 0.0)
	_face(Vector3(0, 0, 1.0))
	MoHinhConVat.play(model, "gam_banh")


## Q (khi bếp có ConVat): Tí đứng lên chào
func on_called(_pos: Vector3) -> void:
	if state == "gam":
		_wave()


func _physics_process(delta: float) -> void:
	_t -= delta
	_cool = maxf(_cool - delta, 0.0)
	if player == null:
		return
	var pp := player.global_position
	var d := Vector2(pp.x - model.position.x, pp.z - model.position.z).length()
	var fast := Vector2(player.velocity.x, player.velocity.z).length() > RUN
	match state:
		"gam":
			if d < NEAR and fast:
				state = "chay_tron"
				MoHinhConVat.play(model, "tron", true, 0.05)
			elif d < NEAR and _cool <= 0.0:
				_wave()
			elif _t <= 0.0:
				_t = _rng.randf_range(3.0, 6.0)
				MoHinhConVat.play(model, "ngui" if _rng.randf() < 0.3 else "gam_banh")
		"chao":
			_face(pp)
			if _t <= 0.0:
				state = "gam"
				_t = 2.0
				MoHinhConVat.play(model, "gam_banh")
		"chay_tron":
			if _run_to(HIDE, delta):
				state = "tron"
				_t = HIDE_TIME
				model.visible = false
		"tron":
			if _t <= 0.0 and d > NEAR * 1.5:
				state = "ve"
				model.visible = true
				MoHinhConVat.play(model, "chay")
		"ve":
			if _run_to(HOME, delta):
				state = "gam"
				_t = 2.0
				_face(Vector3(model.position.x, 0, 1.0))
				MoHinhConVat.play(model, "gam_banh")


func _wave() -> void:
	state = "chao"
	_t = 2.4
	_cool = WAVE_COOL
	waves += 1
	MoHinhConVat.play(model, "chao", false, 0.15)
	MoHinhConVat.pop_text(model, "Chít chít!", 0.18, 1.2)
	if ConVat.meet("chuot_ti") and kitchen and kitchen.get("hud") and kitchen.hud.has_method("say"):
		kitchen.hud.say("Chuột Tí ở góc bếp vẫy chào Bơ. Cô Ba: \"Tí ngoan, chỉ gặm vụn thôi!\"", 3.0)


func _run_to(goal: Vector3, delta: float) -> bool:
	var to := goal - model.position
	to.y = 0.0
	if to.length() < 0.03:
		return true
	model.position += to.normalized() * minf(SPEED * delta, to.length())
	_face(goal)
	return false


func _face(at: Vector3) -> void:
	var to := at - model.position
	if Vector2(to.x, to.z).length() > 0.01:
		model.rotation.y = atan2(to.x, to.z)
