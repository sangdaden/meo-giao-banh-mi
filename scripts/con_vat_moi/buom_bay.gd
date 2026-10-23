extends Node3D
## V1 · Bướm và chuồn chuồn ở bãi cỏ công viên khối 4 (Thứ Bảy dạo phố). Bướm bay chập chờn quanh chỗ của nó,
## thỉnh thoảng đáp xuống cỏ phơi cánh; chuồn chuồn bay lượn rồi đứng yên giữa không trung. Bơ chạy ào tới thì cả
## bọn vụt bay lên cao một lúc. Q: con gần nhất bay tới đậu trên đầu Bơ (chuồn chuồn đứng lượn trước mặt) vài giây,
## lần đầu ConVat.meet("buom"). Model: buom, chuon_chuon (assets/models/con_vat/), cánh texture hai mặt.

## [loại, chỗ] (bãi cỏ trống giữa công viên, cách góc cờ và chỗ mèo Sữa, Lạc nằm)
const SPOTS := [["buom", Vector3(-34.5, 0, 18.5)], ["buom", Vector3(-36.0, 0, 16.5)], ["buom", Vector3(-32.5, 0, 20.5)],
	["chuon_chuon", Vector3(-37.5, 0, 12.5)], ["chuon_chuon", Vector3(-31.0, 0, 14.5)]]
const SCARE_R := 1.4
const SCARE_SPEED := 2.6       ## Bơ chạy nhanh hơn chừng này (m/s) tới gần thì bay vụt lên
const SCARE_TIME := 2.2
const LAND_EVERY := Vector2(5.0, 9.0)
const LAND_TIME := Vector2(3.0, 6.0)
const VISIT_TIME := 6.0        ## đậu trên đầu Bơ bao lâu
const HEAD := Vector3(0, 0.44, 0)
const VIEW_END := 18.0

class Bug:
	var node: Node3D
	var kind := "buom"
	var home := Vector3.ZERO
	var pos := Vector3.ZERO
	var state := "bay"         ## bay | dap | dau | so | tham
	var t := 0.0               ## giây còn lại của trạng thái
	var ph := 0.0
	var land := Vector3.ZERO

var player: CharacterBody3D
var toast: Callable
var goi_r := 5.0
var bugs: Array[Bug] = []
var visits := 0
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "BuomBay"
	add_to_group("con_vat")
	_rng.seed = 4
	for s: Array in SPOTS:
		var b := Bug.new()
		b.kind = s[0]
		b.home = s[1]
		b.ph = _rng.randf() * TAU
		b.pos = _fly_point(b)
		b.t = _rng.randf_range(LAND_EVERY.x, LAND_EVERY.y)
		b.node = MoHinhConVat.put(self, b.kind, b.pos, 0.0, VIEW_END)
		MoHinhConVat.play(b.node, "bay")
		bugs.append(b)


func on_called(pos: Vector3) -> void:
	var best: Bug = null
	var bd := INF
	for b in bugs:
		var d := b.pos.distance_to(pos)
		if b.state != "tham" and d < bd:
			bd = d
			best = b
	if best == null or bd > goi_r:
		return
	best.state = "tham"
	best.t = VISIT_TIME
	MoHinhConVat.play(best.node, "bay")
	visits += 1
	ConVat.meet("buom")
	if visits == 1 and toast.is_valid():
		toast.call("Bướm bay tới đậu lên đầu Bơ!" if best.kind == "buom" else "Chuồn chuồn bay tới chào Bơ!", 2.6)


## Điểm bay lượn quanh chỗ của con bọ ở thời điểm hiện tại
func _fly_point(b: Bug) -> Vector3:
	var c := _clock + b.ph * 3.0
	if b.kind == "buom":
		return b.home + Vector3(sin(c * 0.7 + b.ph) * 1.1, 0.75 + sin(c * 1.9) * 0.3, cos(c * 0.5 + b.ph) * 0.9)
	return b.home + Vector3(sin(c * 0.45 + b.ph) * 1.6, 1.0 + sin(c * 0.8) * 0.15, cos(c * 0.6) * 1.2)


func _physics_process(delta: float) -> void:
	_clock += delta
	var pp := player.global_position if player else Vector3(INF, 0, INF)
	var fast: bool = player != null and Vector2(player.velocity.x, player.velocity.z).length() > SCARE_SPEED
	for b in bugs:
		b.t -= delta
		var goal := b.pos
		var rate := 2.0
		match b.state:
			"bay":
				goal = _fly_point(b)
				if b.t <= 0.0:
					b.state = "dap"
					b.t = 2.0
					var a := _rng.randf() * TAU
					b.land = b.home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.2, 0.9)
					b.land.y = 0.02 if b.kind == "buom" else 0.45  # chuồn chuồn đứng lượn trên ngọn cỏ
			"dap":
				goal = b.land
				rate = 3.0
				if b.pos.distance_to(b.land) < 0.03 or b.t <= 0.0:
					b.state = "dau"
					b.t = _rng.randf_range(LAND_TIME.x, LAND_TIME.y)
					MoHinhConVat.play(b.node, "phoi_canh" if b.kind == "buom" else "lo_lung")
			"dau":
				goal = b.land
				if b.t <= 0.0:
					_take_off(b)
			"so":
				goal = b.pos + Vector3(0, 1.4, 0) * delta * 2.0 + (b.pos - pp).normalized() * delta * 2.0
				rate = 20.0
				if b.t <= 0.0:
					_take_off(b)
			"tham":
				if player == null:
					_take_off(b)
					continue
				var fwd: Vector3 = -player.visual.global_basis.z if "visual" in player and player.visual else Vector3.FORWARD
				goal = pp + HEAD + (Vector3(0, 0.02, 0) if b.kind == "buom" else fwd * 0.3 + Vector3(0, 0.05, 0))
				rate = 5.0
				if b.pos.distance_to(goal) < 0.05 and not MoHinhConVat.anim(b.node).current_animation in ["dau", "lo_lung"]:
					MoHinhConVat.play(b.node, "dau" if b.kind == "buom" else "lo_lung")
				if b.t <= 0.0:
					_take_off(b)
		if b.state in ["bay", "dap", "dau"] and fast and Vector2(b.pos.x - pp.x, b.pos.z - pp.z).length() < SCARE_R:
			b.state = "so"
			b.t = SCARE_TIME
			MoHinhConVat.play(b.node, "luot" if b.kind == "buom" else "bay", true, 0.05)
		var prev := b.pos
		b.pos = b.pos.lerp(goal, 1.0 - exp(-rate * delta))
		b.node.position = b.pos
		var v := b.pos - prev
		if Vector2(v.x, v.z).length() > 0.0005:
			b.node.rotation.y = lerp_angle(b.node.rotation.y, atan2(v.x, v.z), 1.0 - exp(-8.0 * delta))
		elif b.state == "tham" and player:
			# bướm trên đầu nhìn cùng hướng Bơ, chuồn chuồn trước mặt thì quay lại nhìn Bơ (Bơ nhìn -Z, model nhìn +Z)
			var yaw: float = player.visual.global_rotation.y if "visual" in player and player.visual else 0.0
			b.node.rotation.y = lerp_angle(b.node.rotation.y, yaw + (PI if b.kind == "buom" else 0.0), 1.0 - exp(-8.0 * delta))


func _take_off(b: Bug) -> void:
	b.state = "bay"
	b.t = _rng.randf_range(LAND_EVERY.x, LAND_EVERY.y)
	MoHinhConVat.play(b.node, "bay")
