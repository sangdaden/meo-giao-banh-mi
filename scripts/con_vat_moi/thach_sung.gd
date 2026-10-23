class_name ThachSung
extends Node3D
## V2 · Thạch sùng chỉ chỗ bám ở tường hông tây chung cư (cảnh chung_cu.gd, Thứ Năm). Nó bám trên mặt tường x = 0.
## Bơ đứng ngập ngừng ở đường leo ngoài tường (mái nhà bên, cục nóng, chuồng cọp) quá HESITATE giây, hoặc bấm Q, thì
## thạch sùng bò tới ngay trên chỗ đứng kế tiếp, quay đầu chỉ (chi_duong) và kêu "tặc tặc". Lần đầu ConVat.meet.
## Chỉ là gợi ý: không tính giờ, không thua. Gắn vào cảnh: ThachSung.attach(self) (một dòng trong chung_cu.gd).
## Model thach_sung (assets/models/con_vat/): nằm phẳng, bụng xuống (-Y), đầu nhìn +Z, gốc giữa bụng.

const HESITATE := 2.5          ## đứng yên chừng này giây trên đường leo thì nó chỉ
const CRAWL := 1.4             ## m/giây bò trên tường
const DART := 4.0              ## xa quá thì chạy vụt
const ABOVE := 0.3             ## bám cao hơn mặt chỗ đứng kế tiếp chừng này
const WALL_X := -0.004
const VIEW_END := 22.0
## Chỗ chờ khi Bơ còn dưới khe (gợi ý bật tường lên mái nhà bên)
const GAP_SPOT := Vector2(2.6, -1.0)       ## (y, z)

var scene: Node
var player: CharacterBody3D
var goi_r := 6.0
var hints := 0
var model: Node3D
## Chỗ đứng trên đường leo: [(y mặt trên, z giữa)], 0 = mái nhà bên rồi tới bậc A…F
var stops: Array[Vector2] = []
var _wall: Vector2              ## (y, z) đang bám trên tường
var _goal: Vector2
var _idle := 0.0
var _shown := -2                ## đã chỉ chỗ đứng số mấy (khỏi chỉ lại khi Bơ còn đứng đó)
var _pointing := 0.0


static func attach(s: Node) -> ThachSung:
	var t := ThachSung.new()
	t.scene = s
	t.player = s.get("player")
	s.add_child(t)
	if s.get_node_or_null("ConVat") == null and t.player:
		ConVat.setup(t.player, s)  # phím Q trong cảnh chung cư (cảnh phố thì main.gd đã gắn)
	return t


func _ready() -> void:
	name = "ThachSung"
	add_to_group("con_vat")
	var consts: Dictionary = scene.get_script().get_script_constant_map() if scene and scene.get_script() else {}
	stops.append(Vector2(consts.get("NEIGHBOR_ROOF", 3.9), -2.6))
	for st: Array in consts.get("WALL_STEPS", []):
		stops.append(Vector2(st[3], (st[1] + st[2]) / 2.0))
	model = MoHinhConVat.put(self, "thach_sung", Vector3.ZERO, 0.0, VIEW_END)
	_wall = GAP_SPOT
	_goal = _wall
	MoHinhConVat.play(model, "bam")
	_place(Vector2(1, 0))  # đầu ngóc lên


## Bậc Bơ đang đứng trên đường leo ngoài tường: -1 dưới đất trong khe, 0 mái nhà bên, 1..6 bậc A…F, -2 nơi khác.
func level() -> int:
	if player == null:
		return -2
	var p := player.global_position
	if p.x > 0.2 or p.x < -5.6 or p.z < -8.2 or p.z > 1.5:
		return -2
	if p.y < 1.5:
		return -1 if p.x > -1.3 else -2
	var best := -2
	for i in stops.size():
		if absf(p.y - stops[i].x) < 0.25:
			best = i
	return best


func on_called(_pos: Vector3) -> void:
	_show(level(), true)


func _physics_process(delta: float) -> void:
	_pointing = maxf(_pointing - delta, 0.0)
	var lv := level()
	var still: bool = player != null and player.is_on_floor() and player.velocity.length() < 0.3
	_idle = _idle + delta if still and lv != -2 else 0.0
	if _idle > HESITATE and lv != _shown:
		_show(lv, false)
	# bò về đích
	var to := _goal - _wall
	var d := to.length()
	if d > 0.01:
		var speed := DART if d > 2.5 else CRAWL
		_wall += to / d * minf(speed * delta, d)
		MoHinhConVat.play(model, "chay_vut" if speed == DART else "bo")
		_place(to / d)
	elif not MoHinhConVat.busy(model) and _pointing <= 0.0:
		MoHinhConVat.play(model, "bam")
		_place(Vector2(1, 0))  # đầu ngóc lên


## Bò tới ngay trên chỗ đứng kế tiếp của bậc `lv`, quay đầu chỉ và kêu "tặc tặc".
func _show(lv: int, called: bool) -> void:
	if lv == -2:
		if called:
			MoHinhConVat.play(model, "tac_tac", false)
			MoHinhConVat.pop_text(model, "Tặc tặc", 0.12)
		return
	_shown = lv
	var next := lv + 1
	if next >= stops.size():
		MoHinhConVat.play(model, "tac_tac", false)
		MoHinhConVat.pop_text(model, "Tặc tặc", 0.12)
		return
	_goal = Vector2(stops[next].x + ABOVE, stops[next].y)
	if next == 0:
		_goal = Vector2(stops[0].x + ABOVE, -1.4)  # mép mái nhà bên phía khe
	hints += 1
	ConVat.meet("thach_sung")
	await get_tree().create_timer(maxf((_goal - _wall).length() / CRAWL, 0.2)).timeout
	if not is_inside_tree():
		return
	_pointing = 2.0
	MoHinhConVat.play(model, "chi_duong", false, 0.1)
	MoHinhConVat.pop_text(model, "Tặc tặc", 0.12)
	if hints == 1 and scene.get("hud") and scene.hud.has_method("show_toast"):
		scene.hud.show_toast("Thạch sùng chỉ chỗ bám kế tiếp: nhảy lên chỗ nó đang bám!", 3.2)


## Đặt thạch sùng ở (y, z) trên tường, bụng áp tường (+X), lưng ra ngoài (-X), đầu nhìn theo `head` (y, z).
func _place(head: Vector2) -> void:
	var fwd := Vector3(0, head.x, head.y).normalized()
	var up := Vector3(-1, 0, 0)
	model.global_transform = Transform3D(Basis(up.cross(fwd), up, fwd), Vector3(WALL_X, _wall.x, _wall.y))
