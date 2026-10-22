extends SceneTree
## Lái Bơ bằng phím thật chơi trò Giao bánh tiếp sức (Chủ Nhật): chờ Sữa, bấm E ngậm túi, chạy về sân khấu.
## In "RELAY DONE hạng N" hoặc "RELAY STUCK".
##   godot --headless --path . -s tools/thu_tiep_suc.gd
var n := 0
var cn
var t := 0.0
var stuck := 0.0
var best := INF
var jump_cd := 0.0


func _initialize():
	PlayMode.day = "chu_nhat"
	change_scene_to_file.call_deferred("res://scenes/main.tscn")


func _press(dir: Vector3, yaw: float) -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)
	if Vector2(dir.x, dir.z).length() < 0.05:
		return
	var v := Vector3(dir.x, 0, dir.z).normalized().rotated(Vector3.UP, -yaw)
	if v.x > 0: Input.action_press("move_right", v.x)
	else: Input.action_press("move_left", -v.x)
	if v.z > 0: Input.action_press("move_back", v.z)
	else: Input.action_press("move_forward", -v.z)


func _physics_process(d: float) -> bool:
	n += 1
	if n == 60:
		cn = current_scene.get_node("ChuNhat")
		cn.begin_after_orders()
		cn.contests[3].finished.connect(func(rank, note): print("RELAY DONE rank=", rank, " ", note, " t=", t); quit())
	if n == 60 + 360:
		cn._play(3)
	if n < 60 + 365:
		return false
	var tr = cn.contests[3]
	var p: CharacterBody3D = cn.player
	var yaw: float = p.camera_rig.yaw if p.camera_rig else 0.0
	t += d
	jump_cd -= d
	if jump_cd < 0.3:
		Input.action_release("jump")
	if t > 150.0:
		print("RELAY STUCK timeout")
		quit()
		return false
	var goal: Vector3 = tr.goal()
	if tr._waiting:
		goal = tr._team[1].global_position
		if p.global_position.distance_to(goal) < 1.3:
			_press(Vector3.ZERO, yaw)
			# Bấm rồi nhả E xen kẽ từng khung (giữ luôn thì chỉ tính một lần bấm)
			if n % 2 == 0:
				Input.action_press("deliver")
			else:
				Input.action_release("deliver")
			return false
	Input.action_release("deliver")
	if not tr._waiting and not tr._has_bag and tr._dropped == Vector3.INF:
		_press(Vector3.ZERO, yaw)  # đứng chờ ở chỗ nhận
		return false
	if tr._has_bag and tr._hold < tr.HOLD:
		_press(Vector3.ZERO, yaw)  # giữ yên nửa giây cho chắc
		return false
	var to := goal - p.global_position
	var dist := Vector2(to.x, to.z).length()
	if dist < best - 0.05:
		best = dist
		stuck = 0.0
	else:
		stuck += d
	if stuck > 0.8 and jump_cd <= 0.0:
		Input.action_press("jump")
		jump_cd = 0.7
	if stuck > 8.0 or t > 150.0:
		print("RELAY STUCK pos=", p.global_position, " goal=", goal)
		quit()
	_press(to, yaw)
	Input.action_press("sprint")
	return false
