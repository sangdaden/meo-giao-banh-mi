extends TroThi
## Trò 4 · Giao bánh tiếp sức vòng quanh công viên khối 4. Đội Bơ: Gừng chặng 1, Sữa chặng 2, Bơ chạy chặng
## cuối tự chọn đường về sân khấu. Đội bạn: Mít, Bột, Mun. Chuyền túi bằng miệng: mèo sau ngậm quai
## (nhan_tui) rồi mèo trước mới nhả (dua_tui). Bơ đứng ở chỗ nhận, Sữa tới thì bấm E ngậm túi.
## Thong thả: đội bạn chậm (relay_rival_mult 0,8), Gừng và Sữa tự chạy. Thử thách: đội bạn đúng tốc độ,
## ngậm xong mà chạy đi ngay (chưa giữ yên nửa giây) là đứt chuyền, túi rơi phải quay lại nhặt (relay_drop).

const C := Vector3(-43.0, 0, 25.0)
const B := Vector3(-43.0, 0, 6.0)
const A := Vector3(-23.0, 0, 6.0)
const FINISH := Vector3(-34.0, 0, 21.8)
const LANE := Vector3(1.4, 0, 1.4)            ## đội bạn chạy làn trong
const SPEED := 4.0
const HOLD := 0.5

var _team: Array[MeoNpc] = []
var _rivals: Array[MeoNpc] = []
var _bag: Node3D
var _rival_bag: Node3D
var _waiting := false     ## Sữa đã tới, đợi Bơ ngậm túi
var _has_bag := false
var _hold := 0.0
var _dropped := Vector3.INF
var _rival_finished := false
var _finish_ring: MeshInstance3D


func title() -> String:
	return "Giao bánh tiếp sức"


func rule() -> String:
	return "Gừng, Sữa chạy trước. Bơ ngậm túi ở góc đông bắc rồi chạy về sân khấu."


func begin() -> void:
	_team = [cat("gung"), cat("sua")]
	_rivals = [cat("mit"), cat("bot"), cat("mun")]
	_waiting = false
	_has_bag = false
	_dropped = Vector3.INF
	_rival_finished = false
	put_player(A + Vector3(0.6, 0, -0.4), B)
	_finish_ring = TroThi.ring(self, FINISH, Color("#F2C14E"), 1.2)
	_team[0].global_position = C
	_team[1].global_position = B
	_rivals[0].global_position = C + LANE * Vector3(1, 0, -1)
	_rivals[1].global_position = B + LANE
	_rivals[2].global_position = A + LANE * Vector3(-1, 0, 1)
	for m in _team + _rivals:
		m.stop()
		m.snap_ground = true
		m.set_pose("dung")
	_bag = _make_bag(_team[0], Color("#3FA39A"))
	_rival_bag = _make_bag(_rivals[0], Color("#C8412F"))
	toast("Tiếp sức! Gừng chạy chặng 1, Sữa chặng 2. Bơ đứng ở vòng vàng chờ Sữa tới rồi bấm E ngậm túi.", 4.0)
	_run_leg(_team[0], [B], SPEED, func(): _hand(_team[0], _team[1], _bag, func(): _run_leg(_team[1], [A], SPEED * 0.85, _sua_arrived)))
	_run_leg(_rivals[0], [B + LANE], SPEED * _rm(), _rival_leg2)


func _rm() -> float:
	return float(DoKho.v("relay_rival_mult", 1.0))


func _rival_leg2() -> void:
	_hand(_rivals[0], _rivals[1], _rival_bag, func(): _run_leg(_rivals[1], [A + LANE * Vector3(-1, 0, 1)], SPEED * 0.95 * _rm(), _rival_leg3))


func _rival_leg3() -> void:
	var ra := A + LANE * Vector3(-1, 0, 1)
	_hand(_rivals[1], _rivals[2], _rival_bag, func(): _run_leg(_rivals[2], [ra + Vector3(0, 0, 13.0), FINISH + Vector3(1.5, 0, 0)], SPEED * _rm(), _rival_done))


func _make_bag(m: MeoNpc, color: Color) -> Node3D:
	var b := Node3D.new()
	m.add_child(b)
	b.position = Vector3(0, 0.3, -0.32)
	Blocks.box(b, Vector3(0.2, 0.14, 0.1), Vector3.ZERO, color)
	Blocks.box(b, Vector3(0.12, 0.04, 0.02), Vector3(0, 0.09, 0), Color("#3A2418"))
	return b


func _run_leg(m: MeoNpc, pts: Array, speed: float, then: Callable) -> void:
	m.follow_path(pts, speed)
	m.arrived.connect(_leg_done.bind(then), CONNECT_ONE_SHOT)


func _leg_done(then: Callable) -> void:
	if running:
		then.call()


## Chuyền túi: người nhận ngậm quai trước rồi người đưa mới nhả.
func _hand(from: MeoNpc, to: MeoNpc, bag: Node3D, then: Callable) -> void:
	to.face(from.global_position)
	from.face(to.global_position)
	to.play("nhan_tui")
	from.play("dua_tui")
	get_tree().create_timer(0.5).timeout.connect(_pass_bag.bind(to, bag, then))


func _pass_bag(to: Variant, bag: Variant, then: Callable) -> void:
	if not running or not is_instance_valid(bag) or not is_instance_valid(to):
		return
	bag.reparent(to, false)
	bag.position = Vector3(0, 0.3, -0.32)
	then.call()


func _sua_arrived() -> void:
	_waiting = true
	_team[1].face(player.global_position)
	_team[1].say("Bơ ơi, ngậm quai đi!", 2.5)


func _rival_done() -> void:
	_rival_finished = true
	_rivals[2].say("Về đích!", 2.0)
	_rivals[2].set_pose("reo")
	if not _has_bag:
		toast("Đội bạn về đích rồi! Mình vẫn chạy nốt cho trọn nha.", 2.5)


func tick(delta: float) -> void:
	var p := player.global_position
	if _waiting and TroThi.flat_dist(p, _team[1].global_position) < 1.6 and (Input.is_action_just_pressed("deliver") or autotest):
		_waiting = false
		_has_bag = true
		_hold = 0.0
		_team[1].play("dua_tui")
		player.play_clip("nhan_tui")
		player.carry_tui3(true)
		_bag.visible = false
		toast("Ngậm túi rồi! Chạy về sân khấu, đường nào cũng được.", 2.5)
	if _has_bag and _hold < HOLD:
		_hold += delta
		if bool(DoKho.v("relay_drop", true)) and Vector2(player.velocity.x, player.velocity.z).length() > 2.0:
			_drop(p)
	if _dropped != Vector3.INF and TroThi.flat_dist(p, _dropped) < 1.0:
		_dropped = Vector3.INF
		_has_bag = true
		_hold = HOLD
		player.carry_tui3(true)
		_bag.visible = false
		toast("Nhặt lại túi rồi!", 1.5)
	if _has_bag and _dropped == Vector3.INF and TroThi.flat_dist(p, FINISH) < 1.4:
		player.carry_tui3(false)
		player.play_clip("dua_tui")
		_end()


func _drop(p: Vector3) -> void:
	_has_bag = false
	_dropped = p + Vector3(0, 0, 0.4)
	player.carry_tui3(false)
	_bag.reparent(self, false)
	_bag.visible = true
	_bag.global_position = _dropped + Vector3(0, 0.07, 0)
	toast("Chạy sớm quá, đứt chuyền! Túi rơi rồi, quay lại nhặt.", 2.5)


func _end() -> void:
	for m in _team + _rivals:
		m.stop()
	_team[0].set_pose("reo")
	_team[1].set_pose("reo")
	for b in [_bag, _rival_bag]:
		if is_instance_valid(b):
			b.queue_free()
	if _finish_ring:
		_finish_ring.queue_free()
	finish(2 if _rival_finished else 1, "đội Bơ về %s" % ("nhì" if _rival_finished else "nhất"))


func goal() -> Vector3:
	if not running:
		return Vector3.INF
	if _dropped != Vector3.INF:
		return _dropped
	return FINISH if _has_bag else A


func status() -> String:
	if _has_bag:
		return "Chặng cuối · chạy về sân khấu"
	if _waiting:
		return "Sữa tới rồi · bấm E ngậm túi"
	return "Gừng và Sữa đang chạy · Bơ chờ ở góc đông bắc"


func bot(_delta: float) -> void:
	if int(clock * 60.0) % 20 != 0:
		return
	if _waiting:
		put_player(_team[1].global_position + Vector3(0.5, 0, 0))
	elif _has_bag and _hold >= HOLD:
		put_player(FINISH)
