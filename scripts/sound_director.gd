extends Node
## Gắn âm thanh vào màn giao bánh mà không phải sửa rải rác các script khác:
## node này nằm dưới main.gd, tự nghe tín hiệu của mèo, chó, HUD và theo dõi trạng thái
## đơn hàng mỗi khung hình để phát đúng tiếng. Thêm tiếng mới thì sửa ở đây.

const STEP_SLOW := 0.36      ## khoảng cách hai bước chân khi đi chậm (giây)
const STEP_FAST := 0.21      ## khi chạy nhanh hết cỡ
const TICK_FROM := 5         ## còn bấy nhiêu giây thì đồng hồ bắt đầu kêu tích tắc
const URGENT_FROM := 3       ## từ đây kêu gấp hơn
const BARK_RANGE := 16.0     ## mèo trong tầm này thì Chó Mực sủa
const SNORE_RANGE := 14.0    ## mèo trong tầm này thì nghe Chó Mực ngáy

var main: Node
var _state := -1
var _carrying := false
var _results := 0
var _dog_awake := false
var _step := 0.0
var _last_tick := -1
var _bark := 0.0
var _snoring := false


func _ready() -> void:
	main = get_parent()
	main.player.jumped.connect(func(): Sound.play("jump", 0.0, randf_range(0.96, 1.06)))
	main.player.landed.connect(func(): Sound.play("land"))
	main.dog.bit_player.connect(_on_bite)
	main.dog.state_changed.connect(_on_dog_state)
	main.hud.start_pressed.connect(func(): Sound.play_ui("ui_start"))
	for b in main.hud.find_children("*", "Button", true, false):
		b.pressed.connect(func(): Sound.play_ui("ui_click"))


func _process(delta: float) -> void:
	_watch_state()
	if main.state == main.State.MENU:
		return
	_watch_orders()  # cả lúc vừa sang END, để đơn cuối vẫn có tiếng giao
	if main.state != main.State.PLAY:
		if _snoring:
			_snoring = false
			Sound.stop_loop("snore")
		return
	_footsteps(delta)
	_dog(delta)


func _watch_state() -> void:
	if main.state == _state:
		return
	_state = main.state
	match _state:
		main.State.MENU:
			Sound.music("menu")
			Sound.ambience("street")
		main.State.PLAY:
			Sound.music("delivery")
			Sound.ambience("street")
		main.State.END:
			var total := 0
			for s in main.results:
				total += s
			# 10/15 sao trở lên là ca làm tốt. Đợi tiếng giao đơn cuối xong rồi mới chơi nhạc kết.
			Sound.music("", 0.8)
			get_tree().create_timer(1.1).timeout.connect(Sound.music.bind("jingle_win" if total >= 10 else "jingle_lose", 0.1))


func _watch_orders() -> void:
	var p = main.player
	if p.carrying and not _carrying:
		Sound.play("pickup")
		Sound.play("meow_short", -2.0, randf_range(0.95, 1.08))
	if main.results.size() > _results:
		var stars: int = main.results[-1]
		if stars > 0:
			Sound.play("deliver")
			for i in stars:
				get_tree().create_timer(0.35 + i * 0.22).timeout.connect(Sound.play.bind("star_%d" % (i + 1)))
			if stars == 3:
				get_tree().create_timer(0.3).timeout.connect(Sound.play.bind("meow"))
		else:
			Sound.play("fail")
	_results = main.results.size()
	_carrying = p.carrying

	# Đồng hồ đếm ngược: tích tắc mỗi giây ở mấy giây cuối
	if p.carrying:
		var secs := ceili(main.time_left)
		if secs <= TICK_FROM and secs != _last_tick and secs > 0:
			Sound.play("tick_urgent" if secs <= URGENT_FROM else "tick")
		_last_tick = secs
	else:
		_last_tick = -1


func _footsteps(delta: float) -> void:
	var p = main.player
	var hspeed := Vector2(p.velocity.x, p.velocity.z).length()
	if not p.is_on_floor() or hspeed < 0.8:
		_step = 0.05  # bước đầu tiên ngay khi vừa chạy
		return
	_step -= delta
	if _step <= 0.0:
		var k := clampf((hspeed - 2.0) / (p.sprint_speed - 2.0), 0.0, 1.0)
		_step = lerpf(STEP_SLOW, STEP_FAST, k)
		Sound.play("step", lerpf(-3.0, 0.0, k))


func _dog(delta: float) -> void:
	var dog = main.dog
	var hunting: bool = dog.state in [dog.State.CHASE, dog.State.BITE, dog.State.BARK]
	if hunting != _dog_awake:
		_dog_awake = hunting
		Sound.music("chase" if hunting else "delivery", 0.6)
	var dist: float = dog.global_position.distance_to(main.player.global_position)
	# Ngáy khi ngủ gật trong ca canh hẻm, chỉ nghe khi mèo lại gần
	var snoring: bool = dog.awake and dog.state == dog.State.SLEEP and dist < SNORE_RANGE
	if snoring != _snoring:
		_snoring = snoring
		if snoring:
			Sound.loop("snore")
		else:
			Sound.stop_loop("snore")
	if not hunting:
		return
	_bark -= delta
	if _bark <= 0.0 and dist < BARK_RANGE:
		var chasing: bool = dog.state == dog.State.CHASE
		# Càng xa càng nhỏ, để nghe ra chó đang ở gần hay xa
		_dog_sound("bark" if chasing else "bark_single", dog.global_position, randf_range(0.95, 1.05))
		_bark = randf_range(1.4, 2.6) if chasing else randf_range(0.5, 0.8)


func _on_dog_state(s: int) -> void:
	var dog = main.dog
	match s:
		dog.State.SUSPICIOUS:
			_dog_sound("sniff", dog.global_position)
			_dog_sound("growl", dog.global_position, 1.0, -6.0)
		dog.State.CHASE:
			_dog_sound("tag_jingle", dog.global_position)
			_bark = 0.0
		dog.State.BARK:
			_bark = 0.0


## Tiếng của Chó Mực: nhỏ dần theo khoảng cách (play_at nếu bản Sound có, không thì tự giảm).
func _dog_sound(sound_name: String, pos: Vector3, pitch := 1.0, volume_db := 0.0) -> void:
	if Sound.has_method("play_at"):
		Sound.call("play_at", sound_name, pos, 30.0, volume_db, pitch)
	else:
		var dist: float = pos.distance_to(main.player.global_position)
		Sound.play(sound_name, volume_db - dist * 0.8, pitch)


func _on_bite() -> void:
	Sound.play("bite")
	Sound.play("meow", 0.0, 1.25)  # mèo kêu thất thanh
