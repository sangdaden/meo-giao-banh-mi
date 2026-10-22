extends TroThi
## Trò 1 · Đua mái nhà: 3 vòng qua 6 cờ trên đường sân thượng khối 1–2 (đường Thứ Tư, SanThuong lối "co_hai"),
## xuống cầu thang gấp khúc rồi chạy dưới phố về cờ 1. Đối thủ Mít (Xiêm) và Bột (Anh lông ngắn).
## Thong thả: đối thủ chậm 15% (race_rival_mult), rơi khỏi mái thì về cờ vừa qua (race_respawn_flag).
## Thử thách: đúng tốc độ, rơi thì xuống đất leo lại.

const LAPS := 3
const RIVAL_SPEED := 4.6      ## m/s trên đường đua (Bơ chạy nhanh 8 m/s, nhưng phải leo, giữ thăng bằng)
const TOUCH := 1.4            ## chạm cờ trong tầm này (ngang) và lệch cao dưới 1,2 m
const COLORS := [Color("#C8412F"), Color("#E8913A"), Color("#F2C14E"), Color("#7DB46C"), Color("#4F9BE0"), Color("#9B6AC8")]

var flags_pos: Array[Vector3] = []
## Chỗ thấp nhất của đường đua từ cờ trước tới mỗi cờ (đường có đoạn xuống thang giữa hai mái)
var _low_before: Array[float] = []
var path: Array = []          ## đường đi một vòng của đối thủ (qua đủ 6 cờ, về lại cờ 1)
var next_flag := 0
var lap := 1
var _flag_nodes: Array[Node3D] = []
var _rivals: Array[MeoNpc] = []
var _rival_lap := {}          ## mèo -> số vòng đã xong
var _rival_done: Array = []   ## thứ tự về đích của đối thủ
var _last_flag := Vector3.ZERO


func title() -> String:
	return "Đua mái nhà"


func rule() -> String:
	return "3 vòng qua 6 cờ trên sân thượng khối 1–2. Đua với Mít và Bột."


func build() -> void:
	var san: SanThuong = hoi.san
	var route: Array = san.routes.get("co_hai", []) if san else []
	if route.size() < 6:
		route = [Vector3(-26, 0, -3), Vector3(-20, 0, -3), Vector3(-10, 0, -3), Vector3(0, 0, -3), Vector3(8, 0, -3), Vector3(9, 0, -15)]
	var n := route.size()
	var prev := 0
	for k in 6:
		var idx := roundi(k * (n - 1) / 5.0)
		var p: Vector3 = route[idx]
		flags_pos.append(p)
		var low := p.y
		for j in range(prev, idx + 1):
			low = minf(low, route[j].y)
		_low_before.append(low)
		prev = idx
		_flag_nodes.append(TroThi.flag(self, p, COLORS[k], str(k + 1)))
	# Một vòng: theo đường sân thượng tới cờ 6, rồi ra đầu đông hẻm giữa khối 2, xuống đường lớn, về chân thùng
	path = route.duplicate()
	var end: Vector3 = route[n - 1]
	path.append_array([Vector3(13.2, 0, end.z), Vector3(13.2, 0, -2.6), Vector3(route[0].x - 1.6, 0, -2.6), Vector3(route[0].x - 1.6, 0, -5.0), route[0]])
	for f in _flag_nodes:
		f.visible = false


func begin() -> void:
	next_flag = 0
	lap = 1
	_rival_done.clear()
	for f in _flag_nodes:
		f.visible = true
	_highlight()
	var start: Vector3 = path[path.size() - 2]
	put_player(start + Vector3(0.6, 0, 0.8), flags_pos[0])
	_last_flag = start
	_rivals = [cat("mit"), cat("bot")]
	var mult := float(DoKho.v("race_rival_mult", 1.0))
	for i in _rivals.size():
		var m: MeoNpc = _rivals[i]
		m.snap_ground = false
		m.global_position = start + Vector3(-0.6 - i * 0.7, 0, 0.8)
		_rival_lap[m] = 0
		# Bột chắc chân nhưng chậm hơn Mít một chút
		var speed := RIVAL_SPEED * mult * (1.0 if i == 0 else 0.93)
		m.follow_path(path, speed)
		if not m.arrived.is_connected(_on_rival_lap.bind(m, speed)):
			m.arrived.connect(_on_rival_lap.bind(m, speed))
	toast("Đua mái nhà! Leo chồng thùng lên mái, chạm 6 cờ theo số, 3 vòng.", 4.0)


func _on_rival_lap(m: MeoNpc, speed: float) -> void:
	if not running:
		return
	_rival_lap[m] += 1
	if _rival_lap[m] >= LAPS:
		_rival_done.append(m)
		m.say("Về đích!", 2.0)
		m.set_pose("reo")
	else:
		m.follow_path(path, speed)


func tick(_delta: float) -> void:
	var p := player.global_position
	var f: Vector3 = flags_pos[next_flag]
	if TroThi.flat_dist(p, f) < TOUCH and absf(p.y - f.y) < 1.2:
		_last_flag = f
		next_flag += 1
		if next_flag >= flags_pos.size():
			next_flag = 0
			lap += 1
			if lap > LAPS:
				_end()
				return
			toast("Vòng %d/%d!" % [lap, LAPS], 1.5)
		_highlight()
	# Rơi khỏi mái: Thong thả về lại cờ vừa chạm. Chỉ tính là rơi khi thấp hơn chỗ thấp nhất của đường tới cờ kế
	# (giữa cờ 3 và cờ 4 đường xuống thang gần 5 m rồi mới leo lên lại)
	if bool(DoKho.v("race_respawn_flag", false)) and _last_flag.y > 2.0 and p.y < _low_before[next_flag] - 2.0 \
			and player.is_on_floor() and flags_pos[next_flag].y > 1.0:
		put_player(_last_flag, flags_pos[next_flag])
		toast("Trượt rồi! Về lại cờ vừa qua.", 1.5)


func _end() -> void:
	var rank := _rival_done.size() + 1
	for m in _rivals:
		m.stop()
		m.snap_ground = true
	for fl in _flag_nodes:
		fl.visible = false
	finish(rank, "về thứ %d" % rank)


func _highlight() -> void:
	for k in _flag_nodes.size():
		_flag_nodes[k].scale = Vector3.ONE * (1.4 if k == next_flag else 1.0)


func goal() -> Vector3:
	return flags_pos[next_flag] if running else Vector3.INF


func status() -> String:
	return "Vòng %d/%d · tới cờ %d" % [mini(lap, LAPS), LAPS, next_flag + 1]


func bot(_delta: float) -> void:
	if int(clock * 60.0) % 20 == 0:
		put_player(flags_pos[next_flag])
