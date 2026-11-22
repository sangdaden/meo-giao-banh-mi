extends SceneTree
## PD-4: mở trang chủ rồi lần lượt mở Chọn màn (từng ngày), Cài đặt, Đổi phím, hộp "Chơi mới" và Tủ đồ
## (từng tab, bấm thử từng ô), để ghi_file_mo.sh biết trang chủ có thể mở những file nào. Mọi file ở đây
## nằm lại trong index.pck: trang chủ hiện lên khi gói "pho" (đồ chơi Thứ Hai) còn đang tải ngầm.
## Chạy (thường qua ghi_file_mo.sh): godot --headless --path . -s tools/goi_web/mo_trang_chu.gd

func _initialize() -> void:
	_run.call_deferred()


func _wait(frames := 10) -> void:
	for i in frames:
		await process_frame


## Bấm thử từng nút trong `panel` (danh sách lấy lại sau mỗi lần bấm vì bảng tự dựng lại).
func _press_all(panel: Node, skip: Array[String]) -> void:
	var n := _buttons(panel).size()
	for i in n:
		var list := _buttons(panel)
		if i >= list.size():
			break
		var b: Button = list[i]
		if b.text.strip_edges() in skip or b.disabled or not b.is_visible_in_tree():
			continue
		b.pressed.emit()
		await _wait(2)


func _buttons(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "Button", true, false):
		out.append(c)
	return out


func _run() -> void:
	GameState.use_test_save("user://luu_game_mo_trang_chu.cfg")  # file lưu riêng, không đụng file thật
	GameState.set_global("vi_tien_boa", 999999)  # đủ tiền để ô tủ đồ nào cũng bấm được
	change_scene_to_file("res://scenes/menu.tscn")
	await _wait(30)
	var menu := current_scene
	menu.level_select.open()
	for d in Days.ORDER:
		menu.level_select._select(d)
		await _wait(4)
	menu.level_select.close()
	menu.settings.open()
	await _wait(6)
	for p in menu.settings.find_children("*", "DoiPhimPanel", true, false):
		p.open()
		await _wait(6)
		p.close()
	menu.settings.close()
	menu._ask_new_game()
	await _wait(6)
	menu.confirm_new.visible = false
	menu.wardrobe.open()
	for tab in 3:
		menu.wardrobe.show_tab(tab)
		await _wait(6)
		await _press_all(menu.wardrobe, ["Xong", "Mua", "Chơi mới"])
	menu.wardrobe.close()
	await _wait(10)
	DirAccess.remove_absolute(GameState.save_path)
	print("MO TRANG CHU OK")
	quit()
