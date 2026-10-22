extends SceneTree
## Lái Bơ bằng phím thật (Input.action_press) theo lối co_hai, chơi trọn 3 vòng Đua mái nhà (Chủ Nhật).
## In "RACE FINISHED" nếu về đích; kẹt quá 6 s thì in "STUCK" và chụp user://dua_mai_ket*.png (khi chạy có hình).
##   godot --headless --path . -s tools/thu_dua_mai.gd
var n := 0
var cn
var route: Array
var i := 0
var t := 0.0
var stuck_t := 0.0
var best := INF
var jump_cd := 0.0
var _q := false
var _cam: Camera3D
var _k := 0
func _initialize():
	PlayMode.day = "chu_nhat"
	change_scene_to_file.call_deferred("res://scenes/main.tscn")
func _physics_process(d: float) -> bool:
	if _q:
		return false
	n += 1
	if n == 60:
		cn = current_scene.get_node("ChuNhat")
		cn.begin_after_orders()
	if n == 60 + 60 * 6:
		cn._play(0)
		route = [Vector3(-27.0, 0, -5.6)] + cn.san.routes["co_hai"]
		print("START ", cn.player.global_position)
	if n < 60 + 60 * 6 + 5:
		return false
	var p: CharacterBody3D = cn.player
	var tr: TroThi = cn.contests[0]
	t += d
	jump_cd -= d
	var tgt: Vector3 = route[i]
	var to := tgt - p.global_position
	var flat := Vector2(to.x, to.z)
	if flat.length() < 0.6 and absf(to.y) < 1.0:
		i += 1
		best = INF
		stuck_t = 0
		if i >= route.size():
			print("DONE lap at t=", t, " next_flag=", tr.next_flag, " lap=", tr.lap)
			i = 0
		return false
	if flat.length() < best - 0.05:
		best = flat.length(); stuck_t = 0
	else:
		stuck_t += d
	var yaw: float = p.camera_rig.yaw if p.camera_rig else 0.0
	var v := Vector3(flat.x, 0, flat.y).normalized().rotated(Vector3.UP, -yaw)
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)
	if v.x > 0: Input.action_press("move_right", v.x)
	else: Input.action_press("move_left", -v.x)
	if v.z > 0: Input.action_press("move_back", v.z)
	else: Input.action_press("move_forward", -v.z)
	Input.action_press("sprint")
	if jump_cd <= 0 and ((to.y > 0.35 and flat.length() < 2.5) or stuck_t > 0.6):
		Input.action_press("jump"); jump_cd = 0.7
	elif jump_cd < 0.15:
		Input.action_release("jump")
	if stuck_t > 6.0 and not _q:
		_q = true
		print("STUCK at wp ", i, " tgt=", tgt, " pos=", p.global_position, " next_flag=", tr.next_flag, " t=", t)
		var cam := Camera3D.new()
		current_scene.add_child(cam)
		cam.global_position = p.global_position + Vector3(4, 4, 5)
		cam.look_at(p.global_position)
		cam.make_current()
		_cam = cam

	if t > 200:
		print("TIMEOUT"); quit()
	if not tr.running:
		print("RACE FINISHED t=", t); quit()
	return false


func _process(_d: float) -> bool:
	if not _cam:
		return false
	_k += 1
	if _k == 5:
		root.get_viewport().get_texture().get_image().save_png("user://dua_mai_ket.png")
		var p: Vector3 = cn.player.global_position
		_cam.global_position = p + Vector3(-3, 5, 2)
		_cam.look_at(Vector3(3.35, 9.5, -11))
	if _k == 10:
		root.get_viewport().get_texture().get_image().save_png("user://dua_mai_ket2.png")
		quit()
	return false
