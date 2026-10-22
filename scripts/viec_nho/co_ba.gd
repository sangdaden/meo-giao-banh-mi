extends ViecNho
## Trang 1 · Cô Ba: chọn 3 nhân cho ổ "bánh mì Bơ" ở quầy (bảng chọn, không có thua).
## Ổ này vào thực đơn Tuần mới (GameState mục thu_bay, khóa banh_mi_bo). Bếp rút gọn thật làm sau.

const FILLINGS := ["Pate", "Chả lụa", "Trứng ốp la", "Xíu mại", "Thịt nguội", "Chả cá", "Đồ chua", "Ngò rí"]


func begin() -> void:
	line = "Cô Ba: chọn 3 nhân cho ổ \"bánh mì Bơ\""
	day.ui.choose("Bánh mì Bơ · chọn 3 nhân", FILLINGS, 3, _on_chosen)


func tick(_delta: float) -> void:
	pass


func bot_goal() -> Vector3:
	return Vector3.INF


func bot_act() -> void:
	if not is_done():
		day.ui.close_choice()
		_on_chosen(FILLINGS.slice(0, 3))


func _on_chosen(picked: Array) -> void:
	GameState.set_day("banh_mi_bo", picked, SoHangXom.DAY)
	day.toast("Cô Ba nếm thử: \"Ổ %s ngon quá Bơ ơi! Tuần sau cô bán luôn.\"" % ", ".join(picked).to_lower(), 3.5)
	finish()
