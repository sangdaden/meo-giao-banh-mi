extends SceneTree
## Thử chơi liền các ngày (PlayMode): xong ngày nào thì hồ sơ lưu ngày kế tiếp, hết tuần sang Tuần mới,
## ngày chưa làm thì bỏ qua, chế độ tập không đổi ngày, chơi lại Chủ Nhật không cộng tuần hai lần.
## Chạy: godot --headless --path . -s tests/test_lien_ngay.gd
## In "LIEN NGAY TEST OK" và thoát mã 0 nếu mọi tình huống đúng.

var fails := 0


func _initialize() -> void:
	GameState.use_test_save("user://test_lien_ngay.cfg")
	_check("hồ sơ mới bắt đầu từ Thứ Hai", PlayMode.current_day() == "thu_hai" and PlayMode.week() == 1)

	# Đi hết tuần như bấm "Sang ..." ở mỗi bảng tổng kết
	var played: Array = []
	var day := PlayMode.current_day()
	for k in Days.ORDER.size():
		played.append(day)
		_finish(day)
		day = PlayMode.current_day()
		if PlayMode.week() > 1:
			break
	var expect := Days.ORDER.filter(func(d): return Days.playable(d))
	_check("đi qua đúng các ngày đã làm theo thứ tự %s" % [played], played == expect)
	_check("hết tuần thì sang Tuần mới, lại Thứ Hai", PlayMode.current_day() == "thu_hai" and PlayMode.week() == 2)

	# Chơi lại ngày cuối tuần 1 (đã ở tuần 2 trong hồ sơ nhưng ván này là của tuần 1): không cộng thêm tuần
	PlayMode.week_playing = 1
	PlayMode.continuous = true
	GameState.day = expect[-1]
	PlayMode.day_done(expect[-1])
	_check("chơi lại ngày cuối tuần không cộng tuần hai lần", PlayMode.week() == 2)

	# Chế độ tập (chỉ bếp, chỉ giao, một đơn) không đổi ngày đang chơi
	GameState.set_global("ngay_tiep", "thu_ba")
	PlayMode.continuous = false
	PlayMode.day_done("thu_ba")
	_check("chế độ tập không đổi ngày kế tiếp", PlayMode.current_day() == "thu_ba")

	# Nhãn nút ở bảng tổng kết
	PlayMode.continuous = true
	GameState.day = "thu_hai"
	_check("nhãn nút sau Thứ Hai", PlayMode.next_label() == "Sang Thứ Ba")
	GameState.day = expect[-1]
	_check("nhãn nút ngày cuối tuần", PlayMode.next_label() == "Sang Tuần mới")

	# Ngày lưu trong hồ sơ là ngày chưa làm (bản cũ, hay ngày bị gỡ): nhảy tới ngày đã làm kế đó
	GameState.set_global("ngay_tiep", "khong_co")
	_check("ngày lạ trong hồ sơ thì về Thứ Hai", PlayMode.current_day() == "thu_hai")

	# Scoring.end_day gọi day_done: xong ca Thứ Ba trong mạch tuần thì hồ sơ lưu Thứ Tư
	GameState.set_global("ngay_tiep", "thu_ba")
	PlayMode.week_playing = PlayMode.week()
	PlayMode.continuous = true
	GameState.day = "thu_ba"
	Scoring.begin_day("thu_ba")
	Scoring.end_day()
	_check("Scoring.end_day lưu ngày kế tiếp", PlayMode.current_day() == PlayMode.next_of("thu_ba")[0])

	print("LIEN NGAY TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


## Xong cả ngày id trong mạch tuần, như start_day rồi tổng kết.
func _finish(id: String) -> void:
	PlayMode.week_playing = PlayMode.week()
	PlayMode.continuous = true
	GameState.day = id
	PlayMode.day_done(id)


func _check(what: String, ok: bool) -> void:
	print("  ", "ok  " if ok else "SAI ", what)
	if not ok:
		fails += 1
