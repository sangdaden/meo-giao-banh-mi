extends SceneTree
## Thử riêng AI Chó Mực, không cần mở cả khu phố.
## Chạy: godot --headless --path . --script res://tools/dog_test.gd
## In "DOG TEST OK" và thoát mã 0 nếu mọi tình huống đúng.

const DogScript := preload("res://scripts/dog.gd")

## Mèo giả: chỉ có thân va chạm, trọng lực và tín hiệu tiếng động như hợp đồng của player.gd.
const FAKE_CAT := """
extends CharacterBody3D
signal noise_made(pos: Vector3, radius: float)
func _ready() -> void:
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.3, 0.3, 0.5)
	s.shape = b
	s.position.y = 0.15
	add_child(s)
func _physics_process(delta: float) -> void:
	velocity.y -= 28.0 * delta
	move_and_slide()
"""

var world: Node3D
var dog: CharacterBody3D
var cat: CharacterBody3D
var fails := 0
const HOME := Vector3(0, 0, 0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _case_sneak_not_heard()
	await _case_suspicious_then_calm()
	await _case_chase_bite_tired_sleep()
	await _case_peek_sees()
	await _case_high_ground_bark()
	await _case_leash_bark()
	await _case_stuck_bark()
	await _case_off_duty()
	print("DOG TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _setup(cat_pos: Vector3) -> void:
	if world:
		world.free()
	world = Node3D.new()
	root.add_child(world)
	Blocks.solid_box(world, Vector3(80, 1, 80), Vector3(0, -0.5, 0), Color.GRAY)
	var cat_script := GDScript.new()
	cat_script.source_code = FAKE_CAT
	cat_script.reload()
	cat = CharacterBody3D.new()
	cat.set_script(cat_script)
	cat.collision_mask = Blocks.LAYER_WORLD | Blocks.LAYER_PROP
	cat.position = cat_pos
	world.add_child(cat)
	dog = DogScript.new()
	dog.position = HOME
	dog.player = cat
	world.add_child(dog)
	dog.awake = true
	await _wait(0.2)


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _expect(what: String, got: int, want: int) -> void:
	var ok := got == want
	print("  ", "ok  " if ok else "SAI ", what, ": ", DogScript.STATE_NAMES[got], " (cần ", DogScript.STATE_NAMES[want], ")")
	if not ok:
		fails += 1


func _noise(radius: float) -> void:
	cat.noise_made.emit(cat.global_position, radius)


func _case_sneak_not_heard() -> void:
	print("Rón rén cách 4 m: không nghe")
	await _setup(Vector3(4, 0, 0))
	for i in 8:
		_noise(2.5)
		await _wait(0.25)
	_expect("sau 2 s rón rén", dog.state, DogScript.State.SLEEP)


func _case_suspicious_then_calm() -> void:
	print("Đi thường cách 4 m một bước rồi đứng im: nghi ngờ rồi ngủ lại")
	await _setup(Vector3(4, 0, 0))
	_noise(6.0)
	await _wait(0.1)
	_expect("nghe một tiếng", dog.state, DogScript.State.SUSPICIOUS)
	await _wait(3.2)
	_expect("im 3 s", dog.state, DogScript.State.SLEEP)
	_expect_bool("woke_up_this_order", dog.woke_up_this_order, true)


func _case_chase_bite_tired_sleep() -> void:
	print("Chạy nhanh sát ổ: nghi ngờ, đuổi, đớp, mệt về ổ, ngủ lại")
	await _setup(Vector3(3, 0, 0))
	var bites := [0]
	dog.bit_player.connect(func(): bites[0] += 1)
	_noise(10.0)
	await _wait(1.6)
	_noise(10.0)
	await _wait(0.05)
	_expect("còn tiếng sau 1,5 s", dog.state, DogScript.State.CHASE)
	await _wait(1.0)
	_expect_bool("đã đớp một lần", bites[0] == 1, true)
	await _wait(0.6)
	_expect("sau khi đớp", dog.state, DogScript.State.TIRED)
	cat.global_position = Vector3(30, 0.2, 30)  # mèo đi xa, chó về ổ nằm thở
	await _wait(1.0)
	_noise(10.0)
	_expect("mệt thì không nghe", dog.state, DogScript.State.TIRED)
	await _wait(6.5)
	_expect("về ổ nằm 5 s", dog.state, DogScript.State.SLEEP)
	_expect_bool("đớp đúng một lần", bites[0] == 1, true)


func _case_peek_sees() -> void:
	print("Hé mắt thấy Bơ trong 8 m: đuổi")
	await _setup(Vector3(6, 0, 0))
	await _wait(5.6)
	_expect("trước 6 s vẫn ngủ", dog.state, DogScript.State.SLEEP)
	await _wait(0.4)
	_expect("hé mắt", dog.state, DogScript.State.CHASE)


func _case_high_ground_bark() -> void:
	print("Bơ đứng trên bờ rào 0,7 m: chó đứng dưới sủa")
	await _setup(Vector3(2.5, 1.0, 0))
	Blocks.solid_box(world, Vector3(1.0, 0.7, 4.0), Vector3(2.5, 0.35, 0), Color.BROWN, Blocks.LAYER_PROP)
	await _wait(0.3)
	dog._set_state(DogScript.State.CHASE)
	await _wait(1.5)
	_expect("với không tới", dog.state, DogScript.State.BARK)
	await _wait(2.7)
	_expect("sủa xong", dog.state, DogScript.State.TIRED)


func _case_leash_bark() -> void:
	print("Bơ chạy ra khỏi 13 m: chó sủa rồi về")
	await _setup(Vector3(5, 0, 0))
	dog._set_state(DogScript.State.CHASE)
	cat.global_position = Vector3(14, 0.2, 0)
	await _wait(0.2)
	_expect("ra khỏi 13 m", dog.state, DogScript.State.BARK)


func _case_stuck_bark() -> void:
	print("Bơ nằm dưới gầm ba gác 0,4 m: chó không chui được, kẹt thì sủa")
	await _setup(Vector3(4, 0, 0))
	Blocks.solid_box(world, Vector3(1.8, 0.15, 3.0), Vector3(4, 0.475, 0), Color.BLUE, Blocks.LAYER_PROP)  # sàn ba gác: gầm 0,4 m, mặt 0,55 m
	dog._set_state(DogScript.State.CHASE)
	await _wait(2.0)
	_expect("kẹt", dog.state, DogScript.State.BARK)


func _case_off_duty() -> void:
	print("Không phải đơn đi qua hẻm: ngủ say")
	await _setup(Vector3(2, 0, 0))
	dog.awake = false
	_noise(10.0)
	await _wait(7.0)
	_expect("ngủ say", dog.state, DogScript.State.SLEEP)


func _expect_bool(what: String, got: bool, want: bool) -> void:
	var ok := got == want
	print("  ", "ok  " if ok else "SAI ", what)
	if not ok:
		fails += 1
