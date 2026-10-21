extends Node
## Gắn âm thanh vào màn giao bánh mà không phải sửa rải rác các script khác:
## node này nằm dưới main.gd, tự nghe tín hiệu của mèo, chó, HUD và theo dõi trạng thái
## đơn hàng mỗi khung hình để phát đúng tiếng. Thêm tiếng mới thì sửa ở đây.

const STEP_SLOW := 0.36      ## khoảng cách hai bước chân khi đi chậm (giây)
const STEP_FAST := 0.21      ## khi chạy nhanh hết cỡ
const TICK_FROM := 5         ## còn bấy nhiêu giây thì đồng hồ bắt đầu kêu tích tắc
const URGENT_FROM := 3       ## từ đây kêu gấp hơn
const BARK_RANGE := 16.0     ## mèo trong tầm này thì Chó Mực sủa

var main: Node
var _state := -1
var _carrying := false
var _results := 0
var _dog_awake := false
var _step := 0.0
var _last_tick := -1
var _bark := 0.0


func _ready() -> void:
	main = get_parent()
	main.player.jumped.connect(func(): Sound.play("jump", 0.0, randf_range(0.96, 1.06)))
	main.player.landed.connect(func(): Sound.play("land"))
	main.dog.bit_player.connect(_on_bite)
	main.hud.start_pressed.connect(func(): Sound.play_ui("ui_start"))
	for b in main.hud.find_children("*", "Button", true, false):
		b.pressed.connect(func(): Sound.play_ui("ui_click"))


func _process(delta: float) -> void:
	_watch_state()
	if main.state == main.State.MENU:
		return
	_watch_orders()  # cả lúc vừa sang END, để đơn cuối vẫn có tiếng giao
	if main.state != main.State.PLAY:
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
	if dog.awake != _dog_awake:
		_dog_awake = dog.awake
		Sound.music("chase" if _dog_awake else "delivery", 0.6)
		if _dog_awake:
			Sound.play("growl", -6.0)
			_bark = 1.2
	if not _dog_awake:
		return
	var dist: float = dog.global_position.distance_to(main.player.global_position)
	_bark -= delta
	if _bark <= 0.0 and dist < BARK_RANGE:
		var chasing := Vector2(dog.velocity.x, dog.velocity.z).length() > 4.0
		# Càng xa càng nhỏ, để nghe ra chó đang ở gần hay xa
		Sound.play("bark" if chasing else "bark_single", -dist * 0.8, randf_range(0.95, 1.05))
		_bark = randf_range(1.4, 2.6) if chasing else randf_range(2.5, 4.0)


func _on_bite() -> void:
	Sound.play("bite")
	Sound.play("meow", 0.0, 1.25)  # mèo kêu thất thanh
