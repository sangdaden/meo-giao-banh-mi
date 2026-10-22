extends ViecNho
## Trang 3 · Bé Na: trốn tìm 3 lần, không giờ. Tới gần thì nghe tiếng cười khúc khích (chữ "hi hi" to dần).
## Bản này trốn quanh chung cư ngoài phố (hẻm giữa khối 3, mái hiên, mặt bắc); cảnh trong chung cư làm sau
## (luồng "Màn leo chung cư").

const SPOTS := [Vector3(37.0, 0, -15.5), Vector3(30.0, 0, -6.55), Vector3(24.0, 0, -24.9)]

var _na: Nguoi
var _home := Vector3.ZERO
var _home_yaw := 0.0


func begin() -> void:
	line = "Bé Na: trốn tìm! Nghe tiếng cười mà tìm (3 lần)"
	ordered = true
	hint_text = "hi hi"
	hint_radius = 8.0
	_na = day.people.get("bena")
	for s in SPOTS:
		var p: Vector3 = surface(get_world_3d(), s.x, s.z) if s.z > -7.0 and s.z < -6.0 else s
		add_target(p, null, 1.3, 1.0)
	if _na:
		_home = _na.global_position
		_home_yaw = _na.rotation.y
		_na.play_once("vui")
	get_tree().create_timer(0.8).timeout.connect(_hide.bind(0))


func on_got(i: int) -> void:
	_sfx("jingle_win")
	if _na:
		_na.play_for("vui", 1.5)
	if i + 1 < targets.size():
		day.toast("Tìm thấy Bé Na rồi! Bé chạy trốn chỗ khác (%d/3)" % (i + 1), 2.2)
		get_tree().create_timer(1.2).timeout.connect(_hide.bind(i + 1))
	else:
		day.toast("Bé Na: \"Bơ giỏi quá, tìm được hết!\"", 2.5)
		if _na:
			_na.global_position = _home
			_na.rotation.y = _home_yaw


func _hide(i: int) -> void:
	if _na and is_instance_valid(_na) and i < targets.size():
		_na.global_position = targets[i].pos + Vector3(0.4, 0, 0.0)
