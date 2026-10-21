extends SceneTree
## Thử riêng góc cờ tướng (scripts/chess_corner.gd) và cách giao "beside_tea", không cần mở cả khu phố.
## Chạy: godot --headless --path . --script res://tools/chess_test.gd
## In "CHESS TEST OK" và thoát mã 0 nếu mọi tình huống đúng.

const DeliveriesScript := preload("res://scripts/deliveries.gd")

## Mèo giả: thân va chạm, trọng lực, tín hiệu tiếng động và biến _stun như player.gd.
const FAKE_CAT := """
extends CharacterBody3D
signal noise_made(pos: Vector3, radius: float)
var _stun := 0.0
var stance := "walk"
var walk_speed := 5.0
func _ready() -> void:
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.3, 0.3, 0.5)
	s.shape = b
	s.position.y = 0.15
	add_child(s)
func _physics_process(delta: float) -> void:
	_stun = maxf(_stun - delta, 0.0)
	velocity.y -= 28.0 * delta
	move_and_slide()
"""

var world: Node3D
var chess: ChessCorner
var cat: CharacterBody3D
var events: Array[String] = []
var fails := 0
var C := CityProps.CHESS_CORNER


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _case_sneak_quiet()
	await _case_walk_shush()
	await _case_far_walk()
	await _case_sprint_scold()
	await _case_bump_table()
	await _case_checkmate_window()
	await _case_cycle()
	await _case_inactive()
	await _case_deliveries()
	print("CHESS TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _setup() -> void:
	if world:
		world.free()
	events.clear()
	world = Node3D.new()
	root.add_child(world)
	Blocks.solid_box(world, Vector3(40, 1, 40), C + Vector3(0, -0.5, 0), Color.GRAY)
	ChessCorner.build_static(world)
	chess = ChessCorner.new()
	world.add_child(chess)
	_spawn_cat(C + Vector3(0, 0.1, -4))
	chess.setup(cat)
	chess.chess_event.connect(func(k): events.append(k))
	chess.begin_order()
	await _wait(0.1)


func _spawn_cat(at: Vector3) -> void:
	var cat_script := GDScript.new()
	cat_script.source_code = FAKE_CAT
	cat_script.reload()
	cat = CharacterBody3D.new()
	cat.set_script(cat_script)
	cat.collision_layer = 2
	cat.collision_mask = Blocks.LAYER_WORLD | Blocks.LAYER_PROP
	cat.position = at
	world.add_child(cat)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _expect(what: String, ok: bool) -> void:
	print("  ", "ok  " if ok else "SAI ", what)
	if not ok:
		fails += 1


func _noise(offset: Vector3, radius: float) -> void:
	cat.noise_made.emit(C + offset, radius)


func _case_sneak_quiet() -> void:
	print("rón rén sát bàn:")
	await _setup()
	_noise(Vector3(0, 0, -1.3), 2.5)
	await _wait(0.1)
	_expect("không ai suỵt, không mắng", events.is_empty() and not chess.scolded)


func _case_walk_shush() -> void:
	print("đi thường trong 3 m:")
	await _setup()
	_noise(Vector3(0.5, 0, -2.2), 6.0)
	await _wait(0.1)
	_expect("một ông suỵt", events == ["suyt"] and chess.shushes == 1)
	_expect("Bơ khựng lại", cat._stun > 0.5)
	_noise(Vector3(0.5, 0, -2.0), 6.0)
	await _wait(0.1)
	_expect("không suỵt liên tục (chờ 2 s)", chess.shushes == 1)
	await _wait(2.1)
	_noise(Vector3(0.5, 0, -2.0), 6.0)
	await _wait(0.1)
	_expect("đi tiếp thì suỵt lần nữa", chess.shushes == 2)
	_expect("suỵt không làm mất sao", not chess.scolded)


func _case_far_walk() -> void:
	print("đi thường ngoài 3 m:")
	await _setup()
	_noise(Vector3(0, 0, -4.0), 6.0)
	await _wait(0.1)
	_expect("không ai để ý", events.is_empty())


func _case_sprint_scold() -> void:
	print("chạy nhanh trong 3 m:")
	await _setup()
	_noise(Vector3(-1.0, 0, -2.5), 10.0)
	await _wait(0.2)
	_expect("hai ông mắng, mất sao", events == ["mang"] and chess.scolded)
	var fallen := chess._pieces.filter(func(pc): return pc.fallen).size()
	_expect("có quân cờ rơi (tối đa 2)", fallen <= 2)
	_expect("hai ông đứng dậy mắng", chess._men.all(func(m): return m.state == "mang"))


func _case_bump_table() -> void:
	print("đụng bàn (tiếng đụng thùng 8 m sát bàn):")
	await _setup()
	_noise(Vector3(0.3, 0.2, -0.3), 8.0)
	await _wait(0.1)
	_expect("đụng bàn là bị mắng", chess.scolded)
	print("đáp đất 8 m nhưng xa bàn 2 m:")
	await _setup()
	_noise(Vector3(0, 0, -2.0), 8.0)
	await _wait(0.1)
	_expect("chỉ bị suỵt", events == ["suyt"] and not chess.scolded)


func _case_checkmate_window() -> void:
	print("chiếu tướng:")
	await _setup()
	chess.checkmate_now()
	_expect("phát chieu_tuong", events == ["chieu_tuong"] and chess.distracted)
	_noise(Vector3(0, 0, -1.5), 10.0)
	await _wait(0.5)
	_expect("trong 2 s chạy nhanh cũng không ai để ý", not chess.scolded and chess.shushes == 0)
	await _wait(1.7)
	_expect("hết 2 s thì lại để ý", not chess.distracted)
	_noise(Vector3(0, 0, -1.5), 6.0)
	await _wait(0.1)
	_expect("đi thường lại bị suỵt", chess.shushes == 1)


func _case_cycle() -> void:
	print("chu kỳ chiếu tướng 10 đến 14 s:")
	await _setup()
	var t0 := chess.checks
	await _wait(14.2)
	var n1 := chess.checks - t0
	await _wait(14.0)
	var n2 := chess.checks - t0
	_expect("trong 14 s có đúng 1 lần, 28 s có 2 lần", n1 == 1 and n2 == 2)


func _case_inactive() -> void:
	print("chưa nhận đơn góc cờ:")
	await _setup()
	chess.end_order()
	_noise(Vector3(0, 0, -1.0), 10.0)
	await _wait(0.1)
	_expect("đi ngang không bị mắng", not chess.scolded and chess.shushes == 0)


## Cách giao beside_tea trong deliveries.gd: đặt túi lúc thường và lúc chiếu tướng, bị mắng thì mất sao.
func _case_deliveries() -> void:
	print("deliveries beside_tea:")
	if world:
		world.free()
	world = Node3D.new()
	root.add_child(world)
	Blocks.solid_box(world, Vector3(40, 1, 40), C + Vector3(0, -0.5, 0), Color.GRAY)
	var d: Node3D = DeliveriesScript.new()
	d.build_static(world, [ChessCorner.ORDER])
	world.add_child(d)
	_spawn_cat(ChessCorner.DROP + Vector3(0, 0.1, 0))
	d.setup(cat, null, null, true)
	_expect("deliveries dựng góc cờ", d.chess != null and d.chess.is_inside_tree())
	d.on_pick_up(0)
	_expect("nhận bánh thì hai ông bắt đầu để ý", d.chess.active)
	await _wait(0.2)
	_expect("autotest đợi chiếu tướng mới đặt", not d.step(0, true, 0.016) or d.chess.distracted)
	d.chess.checkmate_now()
	_expect("đặt túi lúc chiếu tướng", d.step(0, true, 0.016))
	_expect("nhiệm vụ phụ đạt", d.side_ok[0] and d.chess.delivered and not d.star_lost(0))
	d.on_pick_up(0)
	await _wait(2.2)
	cat.noise_made.emit(C + Vector3(0.2, 0, -0.4), 8.0)
	await _wait(0.1)
	_expect("đụng bàn thì đơn mất 1 sao", d.star_lost(0))
	d.chess.checkmate_now()
	_expect("vẫn giao được", d.step(0, true, 0.016))
