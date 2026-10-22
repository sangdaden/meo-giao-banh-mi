extends TroThi
## Trò 3 · Trốn tìm ở hẻm 42 và hẻm giữa khối 5: tìm 5 mèo đang nằm rạp. Đi rón rén (Alt/Z) thì nghe
## tiếng chuông cổ, tiếng ngáp của con gần nhất; chạy nhanh sát bên thì nó chuồn sang chỗ khác.
## Thong thả: không giờ (hide_time 0), sau 30 s chưa thấy con nào thì chuông kêu to hơn và mũi tên chỉ tới
## (hide_hint_after). Thử thách: 3 phút, không nhắc, chạy là chúng chuyển chỗ ngay.

const HIDERS := ["mun", "mit", "bot", "lac", "sua"]
const SPOTS := [
	Vector3(-18.3, 0, 12.4), Vector3(-19.2, 0, 20.6),                           # hẻm 42
	Vector3(-10.5, 0, 15.6), Vector3(-2.5, 0, 15.2), Vector3(6.0, 0, 15.8),      # hẻm giữa khối 5
]
const SPARE := [Vector3(-18.6, 0, 17.8), Vector3(-6.5, 0, 15.9), Vector3(2.0, 0, 15.4), Vector3(9.0, 0, 15.5)]
const START := Vector3(-21.0, 0, 7.0)
const FIND := 1.4
const HEAR := 7.0
const SPOOK := 4.0
const SOUNDS := ["leng keng...", "ngáp~", "khịt khịt", "leng keng!"]

var found: Array[String] = []
var _where := {}          ## id -> chỗ đang trốn
var _since_find := 0.0
var _hint_cd := 0.0
var _limit := 0.0


func title() -> String:
	return "Trốn tìm"


func rule() -> String:
	return "Tìm 5 mèo trốn ở hẻm 42 và hẻm giữa khối 5. Rón rén để nghe tiếng chuông."


func begin() -> void:
	found.clear()
	_since_find = 0.0
	_limit = float(DoKho.v("hide_time", 180.0))
	for i in HIDERS.size():
		var m := cat(HIDERS[i])
		m.stop()
		m.snap_ground = true
		m.show_name(false)
		_place(HIDERS[i], SPOTS[i])
	put_player(START, SPOTS[0])
	toast("Trốn tìm! Năm bạn đã trốn trong hẻm 42 và hẻm giữa khối 5. Rón rén (Alt) để nghe tiếng chuông, tới sát rồi bấm E.", 5.0)


func _place(id: String, pos: Vector3) -> void:
	var m := cat(id)
	_where[id] = pos
	m.global_position = pos
	m.global_position.y = m._ground_y(pos) if m.is_inside_tree() else 0.0
	m.rotation.y = randf() * TAU
	m.set_pose("tron")


func tick(delta: float) -> void:
	_since_find += delta
	_hint_cd = maxf(_hint_cd - delta, 0.0)
	var p := player.global_position
	var sneaking: bool = "stance" in player and player.stance == "sneak"
	var sprint := Input.is_action_pressed("sprint") and Vector2(player.velocity.x, player.velocity.z).length() > 5.5
	var near := ""
	var near_d := INF
	for id in HIDERS:
		if id in found:
			continue
		var d := TroThi.flat_dist(p, _where[id])
		if d < near_d:
			near_d = d
			near = id
		if d < FIND and (Input.is_action_just_pressed("deliver") or d < 0.8 or autotest):
			_found(id)
			return
		if sprint and d < SPOOK and DoKho.hard():
			_spook(id)
	if near == "":
		return
	var loud := _hint_after() > 0.0 and _since_find > _hint_after()
	if _hint_cd <= 0.0 and ((sneaking and near_d < HEAR) or loud):
		_hint_cd = 2.0 if not loud else 3.0
		cat(near).say(SOUNDS[randi() % SOUNDS.size()], 1.2)
	if _limit > 0.0 and clock >= _limit:
		_end()


func _hint_after() -> float:
	return float(DoKho.v("hide_hint_after", 0.0))


func _found(id: String) -> void:
	found.append(id)
	_since_find = 0.0
	var m := cat(id)
	m.set_pose("dung")
	m.play("lo_dau")
	m.show_name()
	m.say("Bị tìm ra rồi!", 2.0)
	m.face(player.global_position)
	toast("Tìm ra %s! (%d/5)" % [MeoNpc.CAST[id].ten, found.size()], 2.0)
	if found.size() >= HIDERS.size():
		_end()


## Chạy ầm sát bên: mèo chuồn sang chỗ trống khác (Thử thách).
func _spook(id: String) -> void:
	var used := _where.values()
	for s in SPARE + SPOTS:
		if not s in used:
			cat(id).say("Ối!", 0.8)
			_place(id, s)
			toast("%s nghe tiếng chạy nên chuồn mất rồi!" % MeoNpc.CAST[id].ten, 2.0)
			return


func _end() -> void:
	var n := found.size()
	for id in HIDERS:
		cat(id).set_pose("dung")
		cat(id).show_name()
	finish(1 if n >= 5 else (2 if n == 4 else (3 if n == 3 else 4)), "tìm được %d/5" % n)


func goal() -> Vector3:
	if not running:
		return Vector3.INF
	if _hint_after() > 0.0 and _since_find > _hint_after():
		var best := Vector3.INF
		for id in HIDERS:
			if not id in found and (best == Vector3.INF or TroThi.flat_dist(player.global_position, _where[id]) < TroThi.flat_dist(player.global_position, best)):
				best = _where[id]
		return best
	return Vector3(-8.0, 0, 15.5) if player.global_position.x < -16.0 else Vector3.INF


func status() -> String:
	var s := "Đã tìm %d/5" % found.size()
	if _limit > 0.0:
		s += " · còn %d giây" % maxi(0, ceili(_limit - clock))
	return s


func bot(_delta: float) -> void:
	if int(clock * 60.0) % 20 != 0:
		return
	for id in HIDERS:
		if not id in found:
			put_player(_where[id] + Vector3(0.5, 0, 0))
			return
