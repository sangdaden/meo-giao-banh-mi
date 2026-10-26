class_name TuDiPho
extends Node
## B3 "Tự đi theo mũi tên": bật ở Cài đặt > Hỗ trợ (mặc định tắt). Ngoài phố giữ F (tay cầm D-pad →)
## thì Bơ tự đi theo đường chấm của bản đồ nhỏ (BanDoNho.find_path) tới chỗ mũi tên đỏ chỉ; thả ra là đứng lại.
## Bị chắn (thùng, bậc) thì tự nhảy một cái. Tới gần đích thì dừng để người chơi tự giao, tự leo.
## main.gd thêm node này vào cảnh phố; giống Tab tự đi trong bếp (kitchen.gd _auto_walk_step).

const ACTION := "tu_di_pho"
const TOI_NOI := 2.2  # cách đích (theo mặt đất) chừng này mét thì dừng

var _main: Node
var _dang_di := false
var _path := PackedVector2Array()
var _goal := Vector3.INF
var _tim_lai := 0.0
var _ket := 0.0
var _vi_tri_cu := Vector3.ZERO
var _lan_ket := 0  # số lần kẹt liền nhau: lần lẻ thử nhảy, lần chẵn đổi phía lách
var _ne_huong := 1.0  # lách vật cản: 1 ưu tiên bên trái, -1 bên phải
var _lach_h := Vector3.ZERO
var _lach_t := 0.0


func _ready() -> void:
	_main = get_parent()
	process_physics_priority = -10  # chạy trước Bơ để Bơ thấy "vừa bấm nhảy" ngay khung này
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION, 0.2)  # DieuKhien (scripts/ban_phim.gd) gán phím theo bảng và phần người chơi đổi
		BanPhim.ap_dung()


func _physics_process(delta: float) -> void:
	var player: CharacterBody3D = _main.get("player")
	var hud: Node = _main.get("hud")
	var goal := _dich(hud)
	var muon: bool = DoKho.ho_tro("ho_tro_tu_di") and player != null and player.can_move \
		and goal != Vector3.INF and Input.is_action_pressed(ACTION) and not get_tree().paused
	if muon:
		var p := player.global_position
		muon = Vector2(goal.x - p.x, goal.z - p.z).length() > TOI_NOI
	if not muon:
		if _dang_di:
			_dung()
		return
	var p := player.global_position
	_tim_lai -= delta
	if not _dang_di or _tim_lai <= 0.0 or goal.distance_to(_goal) > 0.5 or _path.is_empty():
		_dang_di = true
		_goal = goal
		_tim_lai = 1.0
		_path = BanDoNho.find_path(Vector2(p.x, p.z), Vector2(goal.x, goal.z))
		while _path.size() > 1 and _path[0].distance_to(Vector2(p.x, p.z)) < 1.2:
			_path.remove_at(0)  # điểm đầu là ô Bơ đang đứng, điểm sát bên thì khỏi quay lại
		if _path.is_empty():
			_path = PackedVector2Array([Vector2(goal.x, goal.z)])
		_vi_tri_cu = p
		_ket = 0.0
	var next := _path[0]
	var d := next - Vector2(p.x, p.z)
	if d.length() < 0.6 and _path.size() > 1:
		_path.remove_at(0)
		return
	var huong := _lach(player, Vector3(d.x, 0, d.y).normalized(), delta)
	# Hướng trong thế giới → phím theo góc camera (player.gd xoay phím theo camera_rig.yaw)
	var yaw: float = player.camera_rig.yaw if player.camera_rig else 0.0
	var v := huong.rotated(Vector3.UP, -yaw)
	_truc("move_right", "move_left", v.x)
	_truc("move_back", "move_forward", v.z)
	# Đứng một chỗ quá lâu: thử nhảy qua vật chắn
	_ket += delta
	if _ket >= 0.8:
		if Vector2(p.x - _vi_tri_cu.x, p.z - _vi_tri_cu.z).length() < 0.3 and player.is_on_floor():
			_lan_ket += 1
			if _lan_ket % 2 == 1:
				Input.action_press("jump")
				_nha_nhay.call_deferred()
			else:
				_ne_huong = -_ne_huong  # lách mãi một phía không ra: lần sau thử phía kia
				_tim_lai = 0.0
		else:
			_lan_ket = 0
		_ket = 0.0
		_vi_tri_cu = p


## Đường chấm chỉ né dãy nhà. Phía trước có xe, quầy, thùng thì chọn hướng thoáng gần hướng muốn đi nhất
## và giữ hướng đó nửa giây cho khỏi lắc qua lắc lại.
func _lach(player: CharacterBody3D, muon: Vector3, delta: float) -> Vector3:
	_lach_t -= delta
	if _lach_t > 0.0 and _thoang(player, _lach_h, 0.8) >= 0.8:
		return _lach_h
	if _thoang(player, muon, 0.8) >= 0.8:
		return muon
	var tot := muon
	var diem := -INF
	for i in range(1, 9):
		for dau in [1.0, -1.0]:
			var g: float = i * 0.3 * dau * _ne_huong
			var h := muon.rotated(Vector3.UP, g)
			var xa := _thoang(player, h, 2.5)
			if xa < 0.8:
				continue
			var dd := xa - absf(g) * 1.2  # thoáng xa thì tốt, lệch nhiều khỏi hướng muốn đi thì kém
			if dd > diem:
				diem = dd
				tot = h
	_lach_h = tot
	_lach_t = 0.5
	return tot


## Đi theo hướng h được bao xa (tối đa `toi`) trước khi đụng vật chắn ngang thân Bơ.
func _thoang(player: CharacterBody3D, h: Vector3, toi: float) -> float:
	var sp := player.get_world_3d().direct_space_state
	var ngang := h.cross(Vector3.UP) * 0.16
	var xa := toi
	for lech in [Vector3.ZERO, ngang, -ngang]:
		var tu: Vector3 = player.global_position + Vector3(0, 0.25, 0) + lech
		var q := PhysicsRayQueryParameters3D.create(tu, tu + h * toi, player.collision_mask, [player.get_rid()])
		var hit := sp.intersect_ray(q)
		if hit:
			xa = minf(xa, tu.distance_to(hit.position))
	return xa


func _nha_nhay() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")


func _dich(hud: Node) -> Vector3:
	if hud == null or not hud.get("_playing") or not hud.get("_has_goal"):
		return Vector3.INF
	return hud.get("_goal")


func _truc(duong: String, am: String, v: float) -> void:
	if v > 0.05:
		Input.action_press(duong, v)
		Input.action_release(am)
	elif v < -0.05:
		Input.action_press(am, -v)
		Input.action_release(duong)
	else:
		Input.action_release(duong)
		Input.action_release(am)


func _dung() -> void:
	_dang_di = false
	_path = PackedVector2Array()
	for a in ["move_right", "move_left", "move_forward", "move_back"]:
		Input.action_release(a)
