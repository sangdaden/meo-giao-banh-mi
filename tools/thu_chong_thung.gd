extends SceneTree
## Lái Bơ bằng phím thật (Input.action_press) chơi trò Nhảy chồng thùng (Chủ Nhật, chồng thùng G11 6 cột).
## Đứng cột trước, canh nhịp rồi nhảy sang cột đang lắc. In "CRATES DONE tầng N" hoặc "CRATES STUCK".
##   godot --headless --path . -s tools/thu_chong_thung.gd
var n := 0
var cn
var t := 0.0
var jump_t := -1.0
var log_tier := 0
var jump_k := 1


func _initialize():
	PlayMode.day = "chu_nhat"
	change_scene_to_file.call_deferred("res://scenes/main.tscn")


func _press(dir: Vector3, yaw: float, k := 1.0) -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)
	if dir.length() < 0.01:
		return
	var v := Vector3(dir.x, 0, dir.z).normalized().rotated(Vector3.UP, -yaw) * k
	if v.x > 0: Input.action_press("move_right", v.x)
	else: Input.action_press("move_left", -v.x)
	if v.z > 0: Input.action_press("move_back", v.z)
	else: Input.action_press("move_forward", -v.z)


func _physics_process(d: float) -> bool:
	n += 1
	if n == 60:
		cn = current_scene.get_node("ChuNhat")
		cn.begin_after_orders()
	if n == 60 + 360:
		cn._play(1)
	if n < 60 + 365:
		return false
	var tr = cn.contests[1]
	var p: CharacterBody3D = cn.player
	var yaw: float = p.camera_rig.yaw if p.camera_rig else 0.0
	t += d
	if not tr.running:
		print("CRATES DONE best=", tr.best, " t=", t)
		quit()
		return false
	if tr.tier != log_tier:
		log_tier = tr.tier
		print("tier ", tr.tier, " tries ", tr.tries_left, " t=", t)
	var here: Vector3 = p.global_position
	if t > 150:
		print("CRATES STUCK tier ", tr.tier, " pos ", here)
		quit()
		return false
	if n % 120 == 0:
		print("  t=%.1f pos=%s floor=%s tier=%d act=%s jt=%.2f" % [t, here, p.is_on_floor(), tr.tier, p.get("_act"), jump_t])
	if jump_t >= 0.0:
		jump_t += d
		var tg: Vector3 = tr.column(jump_k)
		var hd := Vector2(here.x - tg.x, here.z - tg.z).length()
		_press(tg - here if hd > 0.08 else Vector3.ZERO, yaw, clampf(hd / 0.5, 0.25, 1.0))
		if jump_t > 0.35:
			Input.action_release("jump")
		if p.is_on_floor() and jump_t > 0.25:
			jump_t = -1.0
			_press(Vector3.ZERO, yaw)
		return false
	# Đang đứng cột nào (0 = đất)
	var k := 0
	for c in range(1, 7):
		var cc: Vector3 = tr.column(c)
		if Vector2(here.x - cc.x, here.z - cc.z).length() < 0.33 and absf(here.y - 0.4 * c) < 0.12:
			k = c
	if not p.is_on_floor():
		return false
	if k == tr.tier:
		_press(Vector3.ZERO, yaw)
		return false
	var nxt: Vector3 = tr.column(k + 1)
	var dist := Vector2(here.x - nxt.x, here.z - nxt.z).length()
	# Bước sát mép cột đang đứng rồi mới nhảy (đứng giữa cột nhảy tại chỗ thì không với tới)
	if dist > (0.6 if k == 0 else 0.56):
		_press(nxt - here, yaw)
		Input.action_release("sprint")
		return false
	if k + 1 < tr.tier:
		Input.action_press("jump")  # cột thấp hơn cột đích: cứ nhảy
		jump_t = 0.0
		jump_k = k + 1
		_press(nxt - here, yaw)
		return false
	# Nhảy sang cột đích: canh nhịp để đáp đúng lúc yên
	_press(Vector3.ZERO, yaw)
	var phase := fposmod(tr._beat_t + 0.45, 0.9)
	if phase > 0.80 and phase < 0.86:
		Input.action_press("jump")
		jump_t = 0.0
		jump_k = k + 1
		_press(nxt - here, yaw)
	return false
