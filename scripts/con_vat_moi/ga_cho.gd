extends Node3D
## V3 · Gà sổ bu ở chợ Thứ Ba: bu gà bị xô nghiêng, 5 gà con chạy lạc giữa khe sạp phía nam, gà mẹ đứng cạnh gọi con.
## Bơ đi sát một con (FOLLOW_R) hoặc bấm Q gần đàn thì gà con chạy theo Bơ thành hàng; dẫn tới gần bu (HOME_R)
## là nó nhảy vào. Đủ 5 con thì bu dựng lại, gà mẹ cục tác, lần đầu được tiền boa nhỏ. Không đồng hồ, không thua.
## Model: ga_mai, ga_con, ga_con_van, bu_ga (assets/models/con_vat/).

const BU := Vector3(0.6, 0, 4.25)          ## giữa đáy bu, khe giữa sạp -2,8 và 3,6 phía nam
const HEN_AT := Vector3(-0.2, 0, 4.05)
const SCATTER := [Vector3(-1.3, 0, 3.0), Vector3(2.4, 0, 3.4), Vector3(0.1, 0, 2.3), Vector3(1.6, 0, 2.6),
	Vector3(-0.8, 0, 3.9)]
const FOLLOW_R := 1.1      ## Bơ tới sát chừng này thì gà con chạy theo
const HOME_R := 1.0        ## gà con theo Bơ tới gần bu chừng này thì nhảy vào
const GAP := 0.32          ## khoảng cách giữa các con trong hàng
const WANDER_R := 0.6      ## gà lạc đi loanh quanh chỗ của nó
const HOP_TIME := 0.5
const TILT := 20.0         ## bu bị xô nghiêng (độ)
const REWARD := 3000
const SAVE_KEY := "ga_ve_bu"
const DAY := "thu_ba"
const VIEW_END := 22.0

class Chick:
	var node: Node3D
	var pos := Vector3.ZERO
	var spot := Vector3.ZERO
	var goal := Vector3.ZERO
	var yaw := 0.0
	var state := "lac"         ## lac | theo | ve | o_bu
	var t := 0.0

var player: CharacterBody3D
var toast: Callable
## Bán kính nghe Q của ConVat
var goi_r := 4.5
var chicks: Array[Chick] = []
var home_count := 0
var hen: Node3D
var _pivot: Node3D
var _rng := RandomNumberGenerator.new()
var _hen_busy := 0.0
var _hinted := false


func _ready() -> void:
	name = "GaCho"
	add_to_group("con_vat")
	_rng.seed = 727
	_pivot = Node3D.new()
	_pivot.name = "BuNghieng"
	add_child(_pivot)
	_pivot.position = BU + Vector3(0, 0, 0.365)  # bản lề ở mép bu phía vỉa hè, nghiêng thì mép kia nhấc lên
	MoHinhConVat.put(_pivot, "bu_ga", Vector3(0, 0, -0.365), 0.0, VIEW_END)
	_pivot.rotation.x = deg_to_rad(TILT)
	hen = MoHinhConVat.put(self, "ga_mai", HEN_AT, 0.0, VIEW_END)
	_face(hen, BU + Vector3(0, 0, -2.0))
	MoHinhConVat.play(hen, "goi_con")
	for i in SCATTER.size():
		var c := Chick.new()
		c.node = MoHinhConVat.put(self, "ga_con_van" if i % 2 else "ga_con", SCATTER[i], 0.0, VIEW_END)
		c.spot = SCATTER[i]
		c.pos = SCATTER[i]
		c.goal = c.pos
		c.yaw = _rng.randf() * TAU
		c.t = _rng.randf_range(0.0, 2.0)
		MoHinhConVat.play(c.node, "mo")
		chicks.append(c)


## Q (ConVat): gà con lạc trong tầm chạy theo Bơ.
func on_called(pos: Vector3) -> void:
	var n := 0
	for c in chicks:
		if c.state == "lac" and c.pos.distance_to(pos) <= goi_r:
			_follow(c)
			n += 1
	if n == 0 and home_count == chicks.size():
		MoHinhConVat.play(hen, "cuc_tac", false)
		MoHinhConVat.pop_text(hen, "Cục tác!", 0.5)
		ConVat.meet("ga")


func _follow(c: Chick) -> void:
	c.state = "theo"
	MoHinhConVat.play(c.node, "chiep", false)
	MoHinhConVat.pop_text(c.node, "Chiếp chiếp!", 0.2, 1.0)
	ConVat.meet("ga")
	if not _hinted:
		_hinted = true
		_say("Gà con sổ bu! Dẫn tụi nó về cái bu cạnh gà mẹ nha.", 3.2)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_hen_busy = maxf(_hen_busy - delta, 0.0)
	var pp := player.global_position
	var lead := pp
	var running: bool = player.velocity.length() > 0.3
	for c in chicks:
		match c.state:
			"lac":
				_wander(c, delta)
				if Vector2(c.pos.x - pp.x, c.pos.z - pp.z).length() < FOLLOW_R and absf(pp.y - c.pos.y) < 0.6:
					_follow(c)
			"theo":
				var to := lead - c.pos
				to.y = 0.0
				var d := to.length()
				if d > GAP:
					var speed := clampf((d - GAP) * 5.0, 0.0, 7.5)
					c.pos += to / d * minf(speed * delta, d - GAP)
					c.yaw = atan2(to.x, to.z)
				var moving := d > GAP + 0.05 and running
				if not MoHinhConVat.busy(c.node):
					MoHinhConVat.play(c.node, "chay" if moving else "dung")
				lead = c.pos
				if Vector2(c.pos.x - BU.x, c.pos.z - BU.z).length() < HOME_R:
					_hop_home(c)
			"ve":
				c.t += delta
				var k := clampf(c.t / HOP_TIME, 0.0, 1.0)
				c.pos = c.goal.lerp(BU, k) + Vector3.UP * sin(k * PI) * 0.25
				if k >= 1.0:
					c.state = "o_bu"
					c.node.visible = false
					_arrived()
		if c.state != "o_bu":
			if c.state != "ve":
				c.pos.y = _ground(c.pos)
			c.node.position = c.pos
			c.node.rotation.y = lerp_angle(c.node.rotation.y, c.yaw, 1.0 - exp(-10.0 * delta))
	if _hen_busy <= 0.0 and not MoHinhConVat.busy(hen):
		MoHinhConVat.play(hen, "goi_con" if home_count < chicks.size() else "dung")


## Gà con lạc mổ loanh quanh chỗ của nó, thỉnh thoảng chạy vài bước.
func _wander(c: Chick, delta: float) -> void:
	c.t -= delta
	if c.t <= 0.0:
		c.t = _rng.randf_range(1.5, 3.5)
		if _rng.randf() < 0.5:
			var a := _rng.randf() * TAU
			c.goal = c.spot + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.1, WANDER_R)
		else:
			c.goal = c.pos
			MoHinhConVat.play(c.node, "mo" if _rng.randf() < 0.7 else "chiep", true)
	var to := c.goal - c.pos
	to.y = 0.0
	if to.length() > 0.05:
		c.pos += to.normalized() * minf(1.2 * delta, to.length())
		c.yaw = atan2(to.x, to.z)
		MoHinhConVat.play(c.node, "chay")
	elif MoHinhConVat.anim(c.node).current_animation == "chay":
		MoHinhConVat.play(c.node, "mo")


func _hop_home(c: Chick) -> void:
	c.state = "ve"
	c.t = 0.0
	c.goal = c.pos
	MoHinhConVat.play(c.node, "nhay", false)


func _arrived() -> void:
	home_count += 1
	_hen_busy = 1.6
	MoHinhConVat.play(hen, "cuc_tac", false)
	MoHinhConVat.pop_text(hen, "Cục tác!", 0.5)
	if home_count < chicks.size():
		_say("Gà con về bu: %d/%d" % [home_count, chicks.size()], 1.8)
		return
	var tw := create_tween()
	tw.tween_property(_pivot, "rotation:x", 0.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not bool(GameState.get_day(SAVE_KEY, false, DAY)):
		GameState.set_day(SAVE_KEY, true, DAY)
		GameState.set_global("vi_tien_boa", Shop.wallet() + REWARD)
		GameState.write_save()
		_say("Đủ 5 gà con về bu rồi! Tiền boa +%s" % Shop.money(REWARD), 3.5)
	else:
		_say("Đủ 5 gà con về bu rồi!", 2.5)


## Mặt đất dưới chân (dò ngắn từ trên đầu gà xuống, không leo lên mặt sạp)
func _ground(p: Vector3) -> float:
	if not is_inside_tree():
		return p.y
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.4, p + Vector3.DOWN * 1.5, Blocks.LAYER_WORLD | Blocks.LAYER_PROP)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else 0.0


func _face(n: Node3D, at: Vector3) -> void:
	n.rotation.y = atan2(at.x - n.position.x, at.z - n.position.z)


func _say(text: String, secs: float) -> void:
	if toast.is_valid():
		toast.call(text, secs)
