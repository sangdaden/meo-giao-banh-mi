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
## Khách nói cảm ơn khi nhận bánh (giọng theo từng người, tên lấy từ ORDERS trong main.gd)
const THANKS := {"Chú Tư": "thanks_chu_tu", "Bé Na": "thanks_be_na", "Chị Mây": "thanks_chi_may",
	"Anh Hùng": "thanks_anh_hung", "Bà Sáu": "thanks_ba_sau"}

var main: Node
var _state := -1
var _carrying := false
var _results := 0
var _dog_awake := false
var _step := 0.0
var _last_tick := -1
var _bark := 0.0
var _snoring := false
var _late := false
var _intact := true
var _bites := 0
var _hello_at := -10.0


func _ready() -> void:
	main = get_parent()
	main.player.jumped.connect(func(): Sound.play("jump", 0.0, randf_range(0.96, 1.06)))
	main.player.landed.connect(func(): Sound.play("land"))
	main.dog.bit_player.connect(_on_bite)
	main.dog.state_changed.connect(_on_dog_state)
	main.player.startled.connect(func(): Sound.play("meow_startle", 0.0, randf_range(0.95, 1.08)))
	main.stamps.collected.connect(func(_i, _n): Sound.play("stamp"))
	for c in main.get_children():
		if c.has_signal("bike_hit_player"):
			c.bike_hit_player.connect(func(_pos): Sound.play("bike_hit"))
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
			Sound.ambience("morning")  # Thứ Hai là ca sáng: chim sẻ, chổi tre, rao bánh mì
			_hello_at = _now()
			get_tree().create_timer(0.5).timeout.connect(Sound.play.bind("coba_hello"))
		main.State.END:
			var total := 0
			for s in main.results:
				total += s
			# 10/15 sao trở lên là ca làm tốt. Đợi tiếng giao đơn cuối xong rồi mới chơi nhạc kết.
			Sound.music("", 0.8)
			var good := total >= 10
			get_tree().create_timer(1.1).timeout.connect(Sound.music.bind("jingle_win" if good else "jingle_lose", 0.1))
			# Cô Ba tổng kết sau nhạc kết
			get_tree().create_timer(3.0).timeout.connect(Sound.play.bind("coba_good" if good else "coba_ok"))


func _watch_orders() -> void:
	var p = main.player
	if p.carrying and not _carrying:
		Sound.play("pickup")
		Sound.play("paper_slip", 0.0, randf_range(0.95, 1.05))
		Sound.play("meow_short", -2.0, randf_range(0.95, 1.08))
		if _now() - _hello_at > 3.0:  # đơn đầu thì Cô Ba vừa chào xong, khỏi nói chồng
			get_tree().create_timer(0.25).timeout.connect(Sound.play.bind("coba_order"))
		_late = false
		_intact = true
		_bites = main.bites
	if main.results.size() > _results:
		_on_delivered()
	_results = main.results.size()
	_carrying = p.carrying
	# Hết giờ đơn: báo một tiếng, Bơ vẫn chạy tới giao trễ
	if p.carrying and main.late and not _late:
		Sound.play("fail")
	_late = main.late
	# Bánh dập vì rơi cao (bị đớp thì đã có tiếng đớp)
	if p.carrying and _intact and not main.intact and main.bites == _bites:
		Sound.play("squish")
	_intact = main.intact
	_bites = main.bites

	# Đồng hồ đếm ngược: tích tắc mỗi giây ở mấy giây cuối
	if p.carrying:
		var secs := ceili(main.time_left)
		if secs <= TICK_FROM and secs != _last_tick and secs > 0:
			Sound.play("tick_urgent" if secs <= URGENT_FROM else "tick")
		_last_tick = secs
	else:
		_last_tick = -1


func _on_delivered() -> void:
	var stars: int = main.results[-1]
	var row: Dictionary = main.score_rows[-1] if main.score_rows.size() == main.results.size() else {}
	Sound.play("deliver", -4.0 if row.get("late", false) else 0.0)
	for i in stars:
		get_tree().create_timer(0.35 + i * 0.22).timeout.connect(Sound.play.bind("star_%d" % (i + 1)))
	var after := 0.35 + stars * 0.22
	if int(row.get("tip", 0)) > 0:
		get_tree().create_timer(after + 0.05).timeout.connect(Sound.play.bind("coin"))
	if row.get("new_best", false) and float(row.get("best_time", -1.0)) >= 0.0:
		get_tree().create_timer(after + 0.35).timeout.connect(Sound.play.bind("record"))
	if stars == 3:
		get_tree().create_timer(0.3).timeout.connect(Sound.play.bind("meow"))
	var i: int = row.get("index", main.order_index - 1)
	if i >= 0 and i < main.ORDERS.size() and THANKS.has(main.ORDERS[i].who):
		get_tree().create_timer(0.55).timeout.connect(Sound.play.bind(THANKS[main.ORDERS[i].who]))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


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
		if p.stance == "sneak":
			return  # player.gd tự phát tiếng rón rén theo nhịp bước
		if p.stance == "crouch":
			Sound.play("sneak", 2.0)
			return
		Sound.play(_surface(p), lerpf(-3.0, 0.0, k))


## Mặt đất dưới chân Bơ: mái tôn, đồ gỗ (thùng, ghế, ổ chó...), cỏ công viên hay mặt đường.
func _surface(p: CharacterBody3D) -> String:
	var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 0.2, p.global_position + Vector3.DOWN * 0.3)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	var body = hit.get("collider")
	if body is Node:
		if body.is_in_group("mai_hien"):
			return "step_metal"
		if body is CollisionObject3D and body.collision_layer & Blocks.LAYER_PROP:
			return "step_wood"
	var pos := p.global_position
	var park: Rect2 = City.BLOCKS[City.PARK_INDEX]
	if pos.y < 0.2 and park.has_point(Vector2(pos.x, pos.z)) and not _on_park_path(park, pos):
		return "step_grass"
	return "step"


## Lối đi lát gạch chạy chéo công viên (rộng 2 m, xem City._park)
func _on_park_path(park: Rect2, pos: Vector3) -> bool:
	var c := park.get_center()
	var d := Vector2(park.size.x, park.size.y).normalized()
	var rel := Vector2(pos.x - c.x, pos.z - c.y)
	return absf(rel.x * d.y - rel.y * d.x) < 1.0


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


## Tiếng của Chó Mực: nhỏ dần theo khoảng cách tới camera.
func _dog_sound(sound_name: String, pos: Vector3, pitch := 1.0, volume_db := 0.0) -> void:
	Sound.play_at(sound_name, pos, 30.0, volume_db, pitch)


func _on_bite() -> void:
	Sound.play("bite")  # tiếng mèo kêu thất thanh đi theo tín hiệu startled của Bơ
