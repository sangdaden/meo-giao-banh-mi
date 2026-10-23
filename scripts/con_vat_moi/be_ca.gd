extends Node3D
## V4 · Bể cá vàng trên quầy Cà phê Mây (đầu phải quầy, xoay dọc để chừa chỗ đặt bánh). Hai con cá vàng bơi qua lại
## trong bể. Bơ lại gần thì cá bơi ra sát kính phía Bơ, đứng bơi rồi đớp mồi; bấm Q thì đớp mồi, lần đầu
## ConVat.meet("ca"). Model: be_kinh, nuoc_be, ca_vang (assets/models/con_vat/).

const AT := Vector3(5.96, 0.9, 6.3)       ## giữa đáy bể trên mặt quầy (CityProps.CAFE_COUNTER, quầy x 4,7…6,1)
const YAW := PI / 2.0                     ## bể dài 0,52 m nằm dọc trục z của phố
const HALF := 0.17                        ## cá bơi trong khoảng ±0,17 m dọc bể
const SIDE := 0.06
const NEAR_R := 1.4
const VIEW_END := 16.0

var player: CharacterBody3D
var toast: Callable
var goi_r := 3.0
var fish: Array[Node3D] = []
var _x := [0.0, 0.1]
var _dir := [1.0, -1.0]
var _y := [0.11, 0.18]
var _near := false
var _feed := 0.0


func _ready() -> void:
	name = "BeCa"
	add_to_group("con_vat")
	position = AT
	rotation.y = YAW
	MoHinhConVat.put(self, "be_kinh", Vector3.ZERO, 0.0, VIEW_END)
	for i in 2:
		var f := MoHinhConVat.put(self, "ca_vang", Vector3.ZERO, 0.0, VIEW_END)
		MoHinhConVat.play(f, "boi")
		fish.append(f)
	MoHinhConVat.put(self, "nuoc_be", Vector3.ZERO, 0.0, VIEW_END)


func on_called(_pos: Vector3) -> void:
	_feed = 2.5
	for f in fish:
		MoHinhConVat.play(f, "dop_moi", false, 0.1)
	MoHinhConVat.pop_text(self, "Bóp bép!", 0.45, 1.0)
	ConVat.meet("ca")


func _process(delta: float) -> void:
	_feed = maxf(_feed - delta, 0.0)
	var near := false
	var side := 0.0  # phía kính gần Bơ (trục x riêng của bể)
	if player:
		var lp := to_local(player.global_position)
		near = Vector2(lp.x, lp.z).length() < NEAR_R
		side = clampf(lp.x, -HALF, HALF)
	for i in fish.size():
		var f := fish[i]
		var goal: float = _x[i]
		if near or _feed > 0.0:
			goal = side + (0.05 if i else -0.05)
			_x[i] = move_toward(_x[i], goal, 0.25 * delta)
			_dir[i] = 1.0 if side >= 0.0 else -1.0
			if not MoHinhConVat.busy(f):
				MoHinhConVat.play(f, "dung_boi")
		else:
			_x[i] += _dir[i] * 0.07 * delta
			if absf(_x[i]) > HALF:
				_x[i] = clampf(_x[i], -HALF, HALF)
				_dir[i] = -_dir[i]
				MoHinhConVat.play(f, "quay", false, 0.1)
			elif not MoHinhConVat.busy(f):
				MoHinhConVat.play(f, "boi")
		f.position = Vector3(_x[i], _y[i], SIDE * (1.0 if i else -1.0))
		var yaw := PI / 2.0 if _dir[i] > 0.0 else -PI / 2.0  # đầu cá (+Z) nhìn theo hướng bơi trên trục x
		f.rotation.y = lerp_angle(f.rotation.y, yaw, 1.0 - exp(-6.0 * delta))
	if near and not _near and player:
		for f in fish:
			MoHinhConVat.play(f, "dop_moi", false, 0.1)
	_near = near
