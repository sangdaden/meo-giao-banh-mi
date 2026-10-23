extends Node3D
## V4 · Thau cá rô ở chợ Thứ Ba, đặt dưới đất cạnh sạp khô (sạp cá) phía bắc. Hai con cá rô bơi vòng trong thau
## nhôm dưới mặt nước. Bơ ghé sát hoặc bấm Q thì một con quẫy đuôi té nước; lần đầu ConVat.meet("ca").
## Model: thau_nhom, mat_nuoc, ca_ro (assets/models/con_vat/). Mặt nước ở y ≈ 0,14 so với đáy thau.

const AT := Vector3(-0.9, 0, -3.55)       ## giữa đáy thau, bên trái sạp khô x 0,6
const FISH := 2
const SWIM_R := 0.13
const FISH_Y := 0.035
const NEAR_R := 1.0
const COOL := 2.5
const VIEW_END := 18.0

var player: CharacterBody3D
var toast: Callable
var goi_r := 3.0
var fish: Array[Node3D] = []
var splashes := 0
var _t := 0.0
var _cool := 0.0
var _near := false


func _ready() -> void:
	name = "ThauCa"
	add_to_group("con_vat")
	position = AT
	MoHinhConVat.put(self, "thau_nhom", Vector3.ZERO, 0.0, VIEW_END)
	for i in FISH:
		var f := MoHinhConVat.put(self, "ca_ro", Vector3.ZERO, 0.0, VIEW_END)
		MoHinhConVat.play(f, "boi" if i == 0 else "nam_im")
		fish.append(f)
	MoHinhConVat.put(self, "mat_nuoc", Vector3.ZERO, 0.0, VIEW_END)


func on_called(_pos: Vector3) -> void:
	_splash()


func _process(delta: float) -> void:
	_t += delta
	_cool = maxf(_cool - delta, 0.0)
	for i in fish.size():
		var f := fish[i]
		var speed := 0.9 if i == 0 else 0.35
		var a := _t * speed + PI * i
		var r := SWIM_R * (1.0 if i == 0 else 0.6)
		f.position = Vector3(cos(a) * r, FISH_Y + 0.01 * i, sin(a) * r)
		f.rotation.y = -a  # bơi theo vòng ngược chiều kim đồng hồ: đầu (+Z) theo tiếp tuyến
		if not MoHinhConVat.busy(f):
			MoHinhConVat.play(f, "boi" if i == 0 else "nam_im")
	if player:
		var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
		var near := d < NEAR_R
		if near and not _near:
			_splash()
		_near = near


func _splash() -> void:
	if _cool > 0.0:
		return
	_cool = COOL
	splashes += 1
	var f := fish[splashes % fish.size()]
	MoHinhConVat.play(f, "quay_duoi", false, 0.1)
	MoHinhConVat.pop_text(self, "Lách tách!", 0.35, 1.0)
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.play_at("splash", global_position, 15.0, -6.0, 1.3)
	ConVat.meet("ca")
