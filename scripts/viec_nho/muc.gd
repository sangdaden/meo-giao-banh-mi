extends ViecNho
## Chương Chó Mực (trang 11): Mực nằm buồn cuối hẻm 42, thẻ tên đồng rơi mất. Lần theo tiếng leng keng:
## thẻ kẹt dưới gầm ba gác (chui) → con nít đá vào công viên (tìm trong cỏ) → nằm trong máng xối mái hiên khối 5
## (lên bằng chồng thùng cạnh quán cà phê). Đem thẻ về, ngồi gọi Q cạnh Mực.
## Thẻ dùng model rời the_ten_muc.glb (G3).

const SPOTS := [Vector3(-17.72, 0, 12.5), Vector3(-27.5, 0, 16.5), Vector3(-6.0, 0, 6.55)]

const TAG := preload("res://assets/models/cho_muc/the_ten_muc.glb")

var _giving := false


func begin() -> void:
	line = "Chương Mực: lần theo tiếng leng keng tìm thẻ tên của Mực · 0/3"
	ordered = true
	hint_text = "leng keng"
	hint_radius = 7.0
	for i in SPOTS.size():
		var s: Vector3 = SPOTS[i]
		var p := surface(get_world_3d(), s.x, s.z) if i == 2 else s
		var tag := _tag()
		add_child(tag)
		add_target(p, tag, 0.6 if i == 0 else 0.8, 0.6, i == 0)
	var bush := prop("bui_co", false)  # thẻ nằm lẫn trong bụi cỏ công viên
	add_child(bush)
	bush.global_position = SPOTS[1] + Vector3(0.25, 0, 0.1)
	carry_with(_tag)
	player.called.connect(_on_called)


func _tag() -> Node3D:
	var n := Node3D.new()
	var m: Node3D = TAG.instantiate()
	if m:
		m.scale = Vector3.ONE * 2.0  # thẻ thật 5,2 cm: phóng to chút cho dễ thấy
		n.add_child(m)
	n.add_child(trinket(Vector3(0.06, 0.02, 0.06), Color("#C9A040"), "cyl"))
	return n


func tick(delta: float) -> void:
	if _giving:
		return
	super.tick(delta)


func on_got(i: int) -> void:
	_sfx("tag_jingle")
	match i:
		0:
			day.toast("Leng keng! Thẻ bị con nít đá văng vào công viên rồi...", 2.5)
		1:
			day.toast("Thẻ lại bị đá lên mái hiên khối 5! Leo chồng thùng cạnh quán cà phê.", 2.8)
		2:
			day.toast("Có thẻ tên rồi! Mang về cuối hẻm 42, ngồi gọi Q cạnh Mực.", 3.0)
	line = "Chương Mực: lần theo tiếng leng keng · %d/3" % (i + 1) if i < 2 else "Chương Mực: mang thẻ về, ngồi gọi Q cạnh Mực"
	day.task_line(line)
	if i == 2:
		_giving = true
		_pick_carry()


func bot_goal() -> Vector3:
	return day.dog.global_position + Vector3(0.9, 0, 0) if _giving else super.bot_goal()


func bot_act() -> void:
	if _giving:
		_on_called(player.global_position)


func _on_called(pos: Vector3) -> void:
	if _giving and not is_done() and pos.distance_to(day.dog.global_position) < 2.6:
		finish()
