extends ViecNho
## Trang 4 · Chị Mây: làm "mèo mẫu" cho thực đơn. Bảng trước quán vẽ 3 dáng; đứng trước quầy, bấm 1/2/3 tạo
## đúng dáng trên bảng. Sai thì chọn lại, không canh giờ. Dáng là clip G2 của Bơ.

const POSES := [["chup_dung", "Đứng ngắm"], ["chup_vay", "Vẫy tay"], ["chup_nam", "Nằm nghiêng"]]
const ASK := [0, 2, 1]                 ## thứ tự dáng trên bảng
const SPOT := Vector3(4.2, 0, 5.6)     ## đứng trước quầy Cà phê Mây

var _step := 0
var _board: Label3D
var _keys := [false, false, false]


func begin() -> void:
	_board = Blocks.label(self, "", Vector3(6.6, 1.7, 5.4), 40, Color("#FFF8EA"))
	_board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_board.outline_size = 10
	_board.outline_modulate = Color("#3D2A1E")
	var mark := trinket(Vector3(1.2, 0.02, 1.2), Color("#F2C14E"), "cyl")
	add_child(mark)
	mark.global_position = SPOT
	_show()


func _show() -> void:
	var want: Array = POSES[ASK[_step]]
	_board.text = "Bảng dáng %d/3\n%s" % [_step + 1, want[1]]
	line = "Chị Mây: đứng ở vòng vàng trước quầy, bấm 1 Đứng · 2 Vẫy · 3 Nằm theo bảng (%d/3)" % (_step + 1)
	day.task_line(line)


func tick(_delta: float) -> void:
	if is_done() or not _near(SPOT, 1.6, 1.0):
		_keys = [Input.is_physical_key_pressed(KEY_1), Input.is_physical_key_pressed(KEY_2), Input.is_physical_key_pressed(KEY_3)]
		return
	for k in 3:
		var down := Input.is_physical_key_pressed([KEY_1, KEY_2, KEY_3][k])
		if down and not _keys[k]:
			_pose(k)
		_keys[k] = down


func bot_goal() -> Vector3:
	return SPOT


func bot_act() -> void:
	if not is_done() and _step < ASK.size() and _near(SPOT, 1.6, 1.0):
		_pose(ASK[_step])


func _pose(k: int) -> void:
	if _step >= ASK.size():
		return
	player.play_clip(POSES[k][0])
	if k != ASK[_step]:
		day.toast("Chị Mây: \"Dáng này dễ thương mà chưa giống bảng, thử lại nha!\"", 2.0)
		return
	_sfx("stamp")
	_step += 1
	if _step >= POSES.size():
		day.toast("Chị Mây: \"Đẹp quá! Thực đơn mới có mèo mẫu rồi.\"", 2.5)
		get_tree().create_timer(1.2).timeout.connect(func():
			player.stop_clip()
			finish())
	else:
		day.toast("Đúng dáng! Dáng tiếp theo trên bảng.", 1.5)
		_show()
