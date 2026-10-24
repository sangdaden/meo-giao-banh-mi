extends SceneTree
## Đi bộ thật (phím ảo, vật lý thật) trên đường sân thượng Thứ Tư: từ mái hiên khối 1 theo từng điểm của
## SanThuong.routes tới chỗ Cô Hai (đơn 2), Bé Na (đơn 3), Chú Năm (đơn 4). Kiểm tra không kẹt, không rơi
## quá cao (bánh không dập), có đi thăng bằng trên ván, chạy nhanh trên ván thì chao (Thong thả) / rơi (Thử thách).
## Chạy: godot --headless --path . -s tests/test_thu_tu.gd

const PlayerScript := preload("res://scripts/player.gd")
const STUCK_TIME := 4.0
const MAX_DROP := 2.5

var world: Node3D
var san: SanThuong
var bo: CharacterBody3D
var balance: ThangBang
var fails := 0
var falls := 0


func _init() -> void:
	DoKho.force = -1
	_run.call_deferred()


func _run() -> void:
	# main.gd dùng autoload (Sound): nạp lúc chạy, không preload, kẻo ở chế độ -s báo lỗi biên dịch
	load("res://scripts/main.gd")._setup_input()
	world = Node3D.new()
	root.add_child(world)
	City.build(world)
	san = SanThuong.new()
	world.add_child(san)
	san.build(world)
	_check(san.planks.size() == 4, "4 tấm ván (2 lần qua đường dọc), có %d" % san.planks.size())
	for key in ["co_hai", "be_na", "chu_nam"]:
		_check(san.routes.has(key), "có lối " + key)
	bo = PlayerScript.new()
	world.add_child(bo)
	balance = ThangBang.attach(bo, san.planks)
	balance.fell.connect(func(): falls += 1)
	await physics_frame
	for key in ["co_hai", "be_na", "chu_nam"]:
		await _walk(key)
	await _sprint_on_plank(false)
	DoKho.force = 1
	await _sprint_on_plank(true)
	print("THU TU TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _walk(key: String) -> void:
	var pts: Array = san.routes[key]
	bo.global_position = pts[1] + Vector3(0, 0.15, 0)
	bo.velocity = Vector3.ZERO
	bo.can_move = true
	for i in 10:
		await physics_frame
	var balanced := false
	var worst_drop := 0.0
	var air_top := bo.global_position.y
	for k in range(2, pts.size()):
		var goal: Vector3 = pts[k]
		var best := INF
		var still := 0.0
		while true:
			var p := bo.global_position
			var d := Vector2(goal.x - p.x, goal.z - p.z)
			if d.length() < 0.3 and absf(goal.y - p.y) < 0.7:
				break
			if d.length() < best - 0.05:
				best = d.length()
				still = 0.0
			still += 1.0 / 60.0
			if still > STUCK_TIME:
				_check(false, "%s: kẹt ở %s, đang tới điểm %d %s" % [key, p, k, goal])
				_release()
				return
			_steer(d.normalized() if d.length() > 0.05 else Vector2.ZERO)
			await physics_frame
			balanced = balanced or balance.balancing
			if bo.is_on_floor():
				worst_drop = maxf(worst_drop, air_top - bo.global_position.y)
				air_top = bo.global_position.y
			else:
				air_top = maxf(air_top, bo.global_position.y)
	_release()
	_check(worst_drop < MAX_DROP, "%s: rơi cao nhất %.2f m (< %.1f)" % [key, worst_drop, MAX_DROP])
	if key != "chu_nam":
		_check(balanced, "%s: có đi thăng bằng trên ván" % key)
	var end: Vector3 = pts[pts.size() - 1]
	print("[%s] tới %s (đích %s), %d điểm" % [key, bo.global_position, end, pts.size()])


## Đứng giữa ván đầu tiên, giữ Shift chạy dọc ván 1 giây.
func _sprint_on_plank(hard: bool) -> void:
	var pl: Dictionary = san.planks[0]
	var c: Vector3 = (pl.xf as Transform3D).origin
	bo.global_position = c + Vector3(-0.6, 0.1, 0)
	bo.velocity = Vector3.ZERO
	balance.wobbles = 0
	for i in 10:
		await physics_frame
	Input.action_press("sprint")
	for i in 60:
		_steer(Vector2(1, 0))
		await physics_frame
	_release()
	for i in 90:
		await physics_frame
	if hard:
		_check(falls >= 1, "Thử thách: chạy nhanh trên ván thì trượt rơi (%d lần)" % falls)
	else:
		_check(balance.wobbles >= 1 and falls == 0 and absf(bo.global_position.y - c.y) < 0.3, "Thong thả: chạy nhanh trên ván thì chao rồi đứng lại (chao %d lần, y %.2f)" % [balance.wobbles, bo.global_position.y])


func _steer(v: Vector2) -> void:
	_set_axis("move_right", "move_left", v.x)
	_set_axis("move_back", "move_forward", v.y)


func _set_axis(pos: String, neg: String, value: float) -> void:
	if value > 0.0:
		Input.action_press(pos, value)
		Input.action_release(neg)
	elif value < 0.0:
		Input.action_press(neg, -value)
		Input.action_release(pos)
	else:
		Input.action_release(pos)
		Input.action_release(neg)


func _release() -> void:
	for a in ["move_right", "move_left", "move_back", "move_forward", "sprint"]:
		Input.action_release(a)


func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  SAI ") + what)
	if not ok:
		fails += 1
