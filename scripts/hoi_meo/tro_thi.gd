class_name TroThi
extends Node3D
## Một trò thi trong Hội mèo Chủ Nhật (scripts/chu_nhat.gd dựng và gọi). Không có thua:
## xong trò thì phát finished(hạng) với hạng 1–3, hoặc 4 = "tham gia". Ai cũng có huy chương.
## Trò con ghi đè: title, build(), begin(), tick(delta), bot(delta) (autotest), goal() (mũi tên chỉ đường).

signal finished(rank: int, note: String)

const RANK_NAMES := ["", "Hạng nhất", "Hạng nhì", "Hạng ba", "Tham gia"]

var hoi: Node          ## ChuNhat
var main: Node3D
var player: CharacterBody3D
var hud: Node
var cats := {}         ## id CAST -> MeoNpc (ChuNhat dựng sẵn)
var running := false
var autotest := false
var clock := 0.0       ## giây đã chơi
var score := -1.0      ## số ghi bảng kỷ lục (giây, tầng, điểm); -1 = không ghi
var _done := false


func title() -> String:
	return ""


## Một dòng luật hiện trên bảng chọn trò.
func rule() -> String:
	return ""


## Dựng đồ của trò (gọi một lần khi ChuNhat bày sân hội).
func build() -> void:
	pass


## Bắt đầu chơi: đặt Bơ, mèo vào chỗ.
func begin() -> void:
	pass


func tick(_delta: float) -> void:
	pass


## Autotest: bot chơi thay (dịch chuyển Bơ). Mặc định không làm gì.
func bot(_delta: float) -> void:
	pass


## Đích hiện tại cho mũi tên trên đầu Bơ (Vector3.INF = không chỉ).
func goal() -> Vector3:
	return Vector3.INF


## Dòng phụ trên thẻ HUD.
func status() -> String:
	return ""


func start() -> void:
	running = true
	_done = false
	clock = 0.0
	score = -1.0
	begin()


func _physics_process(delta: float) -> void:
	if not running:
		return
	clock += delta
	tick(delta)
	if autotest and running:
		bot(delta)


## Kết thúc trò với hạng rank (1–4).
func finish(rank: int, note := "") -> void:
	if _done:
		return
	_done = true
	running = false
	finished.emit(clampi(rank, 1, 4), note)


func toast(text: String, seconds := 2.5) -> void:
	if hud:
		hud.show_toast(text, seconds)


func cat(id: String) -> MeoNpc:
	return cats.get(id)


## Đặt Bơ tại pos, đứng yên, nhìn về phía look.
func put_player(pos: Vector3, look := Vector3.INF) -> void:
	player.global_position = pos + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	if look != Vector3.INF and "visual" in player and player.visual:
		var d := look - pos
		player.visual.rotation.y = atan2(-d.x, -d.z)


static func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Vòng sáng trên đất đánh dấu chỗ đứng.
static func ring(parent: Node3D, pos: Vector3, color: Color, radius := 0.8) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = radius * 0.86
	t.outer_radius = radius
	t.rings = 24
	t.ring_segments = 4
	var m := Blocks.mesh(parent, t, Vector3.ZERO, color, true)
	m.global_position = pos + Vector3(0, 0.05, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m
