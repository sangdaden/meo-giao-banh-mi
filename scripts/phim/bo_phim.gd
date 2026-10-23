extends "res://scripts/player.gd"
## Bơ diễn trong phim (scripts/phim/): chính model, bộ xương, đồ đang mặc và động tác Blender của Bơ trong game,
## nhưng không có vật lý, không nghe phím. Đi, chạy, nhảy theo lệnh của kịch bản; giữ dáng bằng play_clip (động tác lặp).
## Dáng đi tính bằng code như lúc chơi (đặt velocity cho _animate), nên đi trong phim y như đi trong game.

signal arrived

var _goal := Vector3.INF
var _speed := 1.4
var _jump_from := Vector3.ZERO
var _jump_to := Vector3.ZERO
var _jump_t := -1.0
var _jump_len := 0.5
var _jump_h := 0.5


func _init() -> void:
	preview = true


func _ready() -> void:
	super()
	set_physics_process(false)
	play_idle_action("", 1e9)  # không tự ngồi, liếm chân như ở tủ kính trang chủ
	_sync()


## Mặc đồ cho cảnh: {ô: id}. Ô không ghi thì bỏ trống (phim mở đầu: chưa có khăn, chưa có túi).
func dress(worn: Dictionary) -> void:
	var all := {}
	for s in Outfit.SLOTS:
		all[s[0]] = worn.get(s[0], "")
	apply_outfit(all)


## Đặt chỗ đứng và hướng mặt (rad, cùng quy ước rotation.y: 0 là nhìn về -Z).
func place(pos: Vector3, yaw: float) -> void:
	global_position = pos
	visual.rotation.y = yaw
	_goal = Vector3.INF
	velocity = Vector3.ZERO
	_sync()


func face_point(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		visual.rotation.y = atan2(-d.x, -d.z)


## Đi (hoặc chạy nếu speed > 3) thẳng tới pos trên mặt phẳng; tới nơi phát arrived.
func go(pos: Vector3, speed := 1.4) -> void:
	stop_clip()
	_goal = pos
	_speed = speed
	stance = "sprint" if speed > 3.0 else "walk"


## Nhảy vòng cung lên chỗ pos (mặt thùng, bậc thềm) trong secs giây.
func hop(pos: Vector3, secs := 0.5, height := 0.45) -> void:
	stop_clip()
	_goal = Vector3.INF
	_jump_from = global_position
	_jump_to = pos
	_jump_t = 0.0
	_jump_len = secs
	_jump_h = height
	preview = false  # để _animate dùng dáng trên không theo velocity.y
	face_point(pos)


## Giữ một dáng Blender lặp ("ngoi_yen", "ngui_mui"...); "" về dáng đứng tính bằng code.
func pose(clip_name: String) -> void:
	if clip_name == "":
		stop_clip()
	elif clip != clip_name:
		play_clip(clip_name)


func _process(delta: float) -> void:
	if _jump_t >= 0.0:
		_jump_t += delta
		var u := clampf(_jump_t / _jump_len, 0.0, 1.0)
		var p := _jump_from.lerp(_jump_to, u)
		p.y += sin(u * PI) * _jump_h
		velocity = (p - global_position) / maxf(delta, 0.001)
		global_position = p
		if u >= 1.0:
			_jump_t = -1.0
			preview = true
			velocity = Vector3.ZERO
			arrived.emit()
	elif _goal != Vector3.INF:
		var to := _goal - global_position
		to.y = 0.0
		var step := _speed * delta
		if to.length() <= step:
			global_position = Vector3(_goal.x, global_position.y, _goal.z)
			_goal = Vector3.INF
			velocity = Vector3.ZERO
			arrived.emit()
		else:
			var dir := to.normalized()
			global_position += dir * step
			velocity = dir * _speed
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-10.0 * delta))
	_sync()
	super(delta)


## Không có nhịp vật lý: vị trí vẽ (smooth_position) lấy thẳng vị trí hiện tại.
func _sync() -> void:
	_prev_pos = global_position
	_curr_pos = global_position
