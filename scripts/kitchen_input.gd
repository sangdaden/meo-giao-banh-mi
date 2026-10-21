class_name KitchenInput
extends RefCounted
## 9 kiểu thao tác trong cận cảnh bếp (theo trang phác thảo game, bản đầu):
##   tap          bấm E n lần (chặt, mở cửa, xịt)
##   hold         giữ E tới khi đầy (đẩy khay, bóc lá)
##   hold_release giữ E cho kim lên rồi thả đúng vùng xanh (rót nước, xẻ bánh)
##   alt          bấm xen kẽ A/D (←/→) n lần (nhào, lăn, chà rửa)
##   dip          bấm xen kẽ S/W (↓/↑) n lần (nhúng lắc rau)
##   timing       kim chạy qua lại, bấm E khi kim trong vùng xanh, cần n lần trúng (rạch, thái)
##   swipe        vuốt: giữ D (→) hoặc kéo chuột sang phải cho đầy một nhát, n nhát (gọt, bào)
##   rotate       xoay: W→D→S→A (cần analog hay chuột vẽ vòng) cho đủ một vòng, n vòng (khuấy)
##   pick         chọn đúng thứ tự trong các ô (phím số, ←/→ rồi E, hoặc bấm chuột) (lặt rau, xếp nhân)
## Màn bếp gọi update(delta) mỗi nhịp vật lý và handle(event) cho phím. Mỗi nhịp xong phát hit(i, last);
## màn bếp khoá (locked = true) trong lúc chân Bơ diễn nhịp đó rồi mở lại.

signal hit(index: int, last: bool)
signal progress(value: float)
signal miss(text: String)
signal picked_changed
signal wrong_pick(option: String)   ## pick: chọn ô không có trong thứ tự (vd. Ớt khi phiếu ghi "không ớt")

const TIMING_SPEED := 0.45   ## kim chạy bao nhiêu chiều dài thước mỗi giây cho mỗi 1 đơn vị speed
const SWIPE_RATE := 2.2      ## giữ phím vuốt: một nhát đầy sau chừng 0,45 giây
const SWIPE_PIXELS := 220.0  ## hoặc kéo chuột chừng này điểm ảnh
const MISS_LOCK := 0.35

var step := {}
var kind := ""
var n := 1
var count := 0
var value := 0.0             ## độ đầy (hold, hold_release, swipe, rotate) hoặc vị trí kim (timing)
var zone := Vector2(-1, -1)
var locked := false
var options: Array = []      ## pick: các ô theo thứ tự hiện trên màn hình
var order: Array = []        ## pick: thứ tự đúng
var cursor := 0
var bot := false
var screen_center := Vector2(640, 360)  ## tâm màn hình, để vẽ vòng bằng chuột

var _dir := 0                ## alt/dip: hướng vừa bấm (-1, 1), 0 = chưa bấm
var _need_release := false
var _lock_t := 0.0
var _t := 0.0
var _last_angle := INF
var _mouse_drag := false
var _bot_t := 0.0
var _bot_hold := false


func start(s: Dictionary) -> void:
	step = s
	kind = s.get("type", "tap")
	n = int(s.get("n", 1))
	count = 0
	value = 0.0
	var z: Array = s.get("zone", [])
	zone = Vector2(z[0], z[1]) if z.size() == 2 else Vector2(-1, -1)
	locked = false
	order = s.get("order", [])
	options = order.duplicate()
	options.append_array(s.get("wrong", []))
	options.shuffle()
	cursor = 0
	_dir = 0
	_need_release = false
	_lock_t = 0.0
	_t = randf() * 2.0
	_last_angle = INF
	_mouse_drag = false
	_bot_t = 0.35
	_bot_hold = false
	if kind == "pick":
		n = order.size()
	picked_changed.emit()


func is_continuous() -> bool:
	return kind in ["hold", "hold_release", "swipe", "rotate"]


## Ô pick đã chọn đúng chưa.
func is_picked(i: int) -> bool:
	return order.find(options[i]) < count and order.find(options[i]) >= 0


# ---------------------------------------------------------------- phím bấm

func handle(event: InputEvent) -> void:
	if locked or _lock_t > 0.0 or bot:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		_mouse_drag = mb.pressed
		if not mb.pressed:
			_last_angle = INF
	match kind:
		"tap":
			if event.is_action_pressed("interact"):
				_hit()
		"timing":
			if event.is_action_pressed("interact"):
				_try_timing()
		"alt":
			_alternate(event, "move_left", "move_right")
		"dip":
			_alternate(event, "move_back", "move_forward")
		"pick":
			var key := event as InputEventKey
			if key and key.pressed and not key.echo and key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_9:
				choose(key.physical_keycode - KEY_1)
			elif event.is_action_pressed("move_left"):
				cursor = posmod(cursor - 1, options.size())
				picked_changed.emit()
			elif event.is_action_pressed("move_right"):
				cursor = posmod(cursor + 1, options.size())
				picked_changed.emit()
			elif event.is_action_pressed("interact") and not (event is InputEventMouseButton):
				choose(cursor)
	var mm := event as InputEventMouseMotion
	if mm and _mouse_drag:
		match kind:
			"swipe":
				if not _need_release and mm.relative.x > 0.0:
					_fill(mm.relative.x / SWIPE_PIXELS)
			"rotate":
				_turn_to(mm.position - screen_center)


func _alternate(event: InputEvent, a: String, b: String) -> void:
	var d := 0
	if event.is_action_pressed(a):
		d = -1
	elif event.is_action_pressed(b):
		d = 1
	if d == 0:
		return
	if d == _dir:
		miss.emit("Xen kẽ hai phím nhé!")
		return
	_dir = d
	_hit()


## pick: chọn ô thứ i.
func choose(i: int) -> void:
	if locked or i < 0 or i >= options.size() or count >= n:
		return
	cursor = i
	if is_picked(i):
		return
	if options[i] == order[count]:
		_hit()
	else:
		var why := "Không cần %s" % options[i].to_lower() if not options[i] in order else "Chưa tới lượt %s" % options[i].to_lower()
		_miss(why)
		if not options[i] in order:
			wrong_pick.emit(options[i])
	picked_changed.emit()


# ---------------------------------------------------------------- mỗi nhịp vật lý

func update(delta: float) -> void:
	_lock_t = maxf(_lock_t - delta, 0.0)
	if kind == "timing":
		_t += delta * float(step.get("speed", 2.0)) * TIMING_SPEED
		value = pingpong(_t, 1.0)
	if bot:
		_bot(delta)
	if locked or count >= n:
		return
	match kind:
		"hold":
			if _held():
				_fill(delta / float(step.get("dur", 1.0)))
		"hold_release":
			if _held():
				value += delta / float(step.get("dur", 1.5))
				progress.emit(minf(value, 1.0))
				if value >= 1.08:
					_release()
			elif value > 0.0:
				_release()
		"swipe":
			if _need_release:
				if not Input.is_action_pressed("move_right") and not _mouse_drag and not _bot_hold:
					_need_release = false
			elif Input.is_action_pressed("move_right") or _bot_hold:
				_fill(delta * SWIPE_RATE)
		"rotate":
			if bot:
				_fill(delta * 1.6)
			elif not _mouse_drag:
				var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
				if v.length() > 0.5:
					_turn_to(v)
				else:
					_last_angle = INF


func _held() -> bool:
	return _bot_hold if bot else Input.is_action_pressed("interact")


## Hướng v (toạ độ màn hình, y xuống) đổi góc bao nhiêu thì cộng bấy nhiêu vào vòng xoay.
func _turn_to(v: Vector2) -> void:
	if v.length() < 4.0 and v.length() > 1.5:  # chuột sát tâm màn hình: góc nhảy lung tung
		return
	var a := v.angle()
	if _last_angle != INF:
		var d := wrapf(a - _last_angle, -PI, PI)
		if absf(d) < PI * 0.75:
			_fill(absf(d) / TAU)
	_last_angle = a


func _fill(amount: float) -> void:
	value = minf(value + amount, 1.0)
	progress.emit(value)
	if value >= 1.0:
		value = 0.0
		if kind == "swipe":
			_need_release = true
		_hit()


func _release() -> void:
	if zone.x <= value and value <= zone.y:
		value = clampf(value, 0.0, 1.0)
		_hit()
	else:
		_miss("Chưa đủ, giữ lâu hơn!" if value < zone.x else "Quá tay rồi, làm lại!")
		value = 0.0
		progress.emit(0.0)


func _try_timing() -> void:
	if zone.x <= value and value <= zone.y:
		_hit()
	else:
		_miss("Trượt rồi, canh lúc kim vào vùng xanh!")


func _hit() -> void:
	count += 1
	hit.emit(count - 1, count >= n)


func _miss(text: String) -> void:
	_lock_t = MISS_LOCK
	miss.emit(text)


# ---------------------------------------------------------------- tự chơi (--autotest-bep, --demo-bep)

func _bot(delta: float) -> void:
	if locked or count >= n:
		_bot_hold = false
		return
	_bot_t -= delta
	match kind:
		"hold", "swipe":
			_bot_hold = _bot_t <= 0.0 and not _need_release
		"hold_release":
			_bot_hold = _bot_t <= 0.0 and value < (zone.x + zone.y) * 0.5
		"tap", "alt", "dip", "pick":
			if _bot_t <= 0.0:
				_bot_t = 0.16 if kind in ["alt", "dip"] else 0.3
				match kind:
					"pick":
						choose(options.find(order[count]))
					"alt", "dip":
						_dir = -_dir if _dir != 0 else 1
						_hit()
					_:
						_hit()
		"timing":
			var mid := (zone.x + zone.y) * 0.5
			if _bot_t <= 0.0 and absf(value - mid) < (zone.y - zone.x) * 0.3:
				_bot_t = 0.2
				_try_timing()


# ---------------------------------------------------------------- lời nhắc phím cho HUD

func hint() -> String:
	var left := n - count
	match kind:
		"tap":
			return "Bấm E" if left <= 1 else "Bấm E × %d" % left
		"hold":
			return "Giữ E"
		"hold_release":
			return "Giữ E rồi thả khi kim vào vùng xanh"
		"alt":
			return "Bấm xen kẽ A  D  (← →) · còn %d" % left
		"dip":
			return "Nhúng lên xuống: S  W  (↓ ↑) · còn %d" % left
		"timing":
			return "Bấm E khi kim vào vùng xanh · còn %d" % left
		"swipe":
			return "Vuốt: giữ D (→) hoặc kéo chuột sang phải · còn %d nhát" % left
		"rotate":
			return "Xoay: W → D → S → A, hoặc vẽ vòng bằng chuột · còn %d vòng" % left
		"pick":
			return "Chọn đúng thứ tự: phím số, ← → rồi E, hoặc bấm chuột"
	return ""
