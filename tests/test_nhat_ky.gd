extends SceneTree
## Nhật ký chơi thử (P3, P4): file nhật ký trong user://logs, chỗ lúng túng (đứng yên / đi vòng > 8 giây) vào ket_*.csv,
## chép lỗi godot.log lúc tắt, heatmap gộp được, và đứng yên thật ngoài phố cũng bị ghi.
## Chạy: godot --headless --path . -s tests/test_nhat_ky.gd

const Heatmap := preload("res://tools/heatmap_ket.gd")

var nk: Node
var fails := 0


func _init() -> void:
	PlayMode.day = "thu_hai"
	PlayMode.mode = PlayMode.Mode.DELIVERY
	GameState.use_test_save("user://luu_game_test_nhat_ky.cfg")
	_run.call_deferred()


func _run() -> void:
	nk = root.get_node_or_null("NhatKy")
	_check(nk != null, "có autoload NhatKy")
	if nk == null:
		quit(1)
		return
	_check(not nk.bat, "chạy test thì nhật ký tự tắt")
	nk.bat_dau()
	_check(FileAccess.file_exists(nk.duong_txt) and FileAccess.file_exists(nk.duong_csv), "mở file nhật ký + csv trong user://logs")

	# Mẫu giả mỗi 0,25 giây, không cần chờ thật
	var t := 0.0
	# 1. đứng yên 10 giây rồi chạy đi
	for i in 40:
		t += 0.25
		nk.lay_mau(t, Vector3(5.0 + sin(i) * 0.1, 0.1, 5.0))
	for i in 12:
		t += 0.25
		nk.lay_mau(t, Vector3(5.0 + i * 1.0, 0.1, 5.0))
	_check(nk.so_ket == 1, "đứng yên 10 giây ghi 1 chỗ (%d)" % nk.so_ket)
	# 2. đi vòng tròn bán kính 2 m trong 12 giây
	for i in 48:
		t += 0.25
		var g := i * 0.25 * 1.0
		nk.lay_mau(t, Vector3(-10.0 + cos(g) * 2.0, 0.1, 8.0 + sin(g) * 2.0))
	for i in 12:
		t += 0.25
		nk.lay_mau(t, Vector3(-10.0, 0.1, 8.0 + i * 1.0))
	_check(nk.so_ket == 2, "đi vòng 12 giây ghi thêm 1 chỗ (%d)" % nk.so_ket)
	# 3. chạy thẳng 20 giây, leo ống 3 m trong 10 giây: không phải lúng túng
	for i in 80:
		t += 0.25
		nk.lay_mau(t, Vector3(-30.0 + i * 0.6, 0.1, -3.0))
	for i in 40:
		t += 0.25
		nk.lay_mau(t, Vector3(20.0, 0.1 + i * 0.08, -3.0))
	nk._mau.clear()
	_check(nk.so_ket == 2, "chạy thẳng / leo ống không bị ghi (%d)" % nk.so_ket)

	var csv := FileAccess.get_file_as_string(nk.duong_csv)
	_check(csv.contains(",dung_yen,") and csv.contains(",di_vong,"), "csv có dòng dung_yen và di_vong")
	var dong := csv.strip_edges().split("\n")
	if dong.size() >= 2:
		var c := dong[1].split(",")
		_check(c.size() == nk.CSV_DAU.split(",").size() and absf(float(c[6]) - 5.0) < 0.5 and float(c[9]) >= 8.0,
			"dòng đứng yên đúng chỗ và >= 8 giây: " + dong[1])

	# 4. heatmap gộp được csv này (đổi màn thành pho để lên bản đồ)
	var anh_csv := "user://test_heatmap_ket.csv"
	var f := FileAccess.open(anh_csv, FileAccess.WRITE)
	f.store_string(csv.replace(",,thu_hai,", ",pho,thu_hai,"))
	f.close()
	var tool = Heatmap.new()
	tool._doc(anh_csv)
	_check(tool.su_kien.size() == 2, "heatmap đọc được 2 chỗ ngoài phố (%d)" % tool.su_kien.size())
	var img: Image = Heatmap.ve(tool.su_kien)
	_check(img.get_width() == 960 and img.get_height() == 600, "ảnh heatmap 960 × 600")
	var cham := img.get_pixelv(Vector2i(Heatmap._p(5.0, 5.0).round()))
	_check(cham.b > cham.r, "có chấm xanh ở chỗ đứng yên")
	var top: Array = Heatmap.xep_hang(tool.su_kien)
	_check(top.size() == 2 and top[0].giay >= 8.0, "xếp hạng 2 chỗ")
	tool.free()

	# 5. ngoài phố thật: Bơ đứng yên 9 giây thì bị ghi, màn = pho
	var m: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	current_scene = m
	await _frames(20)
	m.player.can_move = true
	var truoc: int = nk.so_ket
	var bat_dau := Time.get_ticks_msec()
	while Time.get_ticks_msec() - bat_dau < 9500:
		await process_frame
	m.player.global_position += Vector3(6.0, 0.0, 0.0)
	await _frames(30)
	_check(nk.so_ket == truoc + 1, "đứng yên ngoài phố 9 giây ghi 1 chỗ")
	_check(FileAccess.get_file_as_string(nk.duong_csv).contains(",pho,thu_hai,"), "dòng ngoài phố ghi màn pho, ngày thu_hai")
	_check(FileAccess.get_file_as_string(nk.duong_txt).contains("Vào màn pho"), "nhật ký ghi đổi màn")

	# 6. tắt game: ghi dòng cuối và phần lỗi godot.log
	nk.ket_thuc()
	var txt := FileAccess.get_file_as_string(nk.duong_txt)
	_check(txt.contains("Tắt game") and (txt.contains("godot.log")), "lúc tắt ghi tổng kết + lỗi godot.log")
	_end()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  SAI ") + what)
	if not ok:
		fails += 1


func _end() -> void:
	if fails == 0:
		print("NHAT KY TEST OK")
	else:
		print("NHAT KY TEST FAIL: %d" % fails)
	quit(1 if fails else 0)
