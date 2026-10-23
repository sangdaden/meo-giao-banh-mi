extends SceneTree
## Xuất câu mẫu của từng giọng ú ớ ra WAV (trang nghe thử cho Sang). Đo thời gian tạo tiếng.
## Chạy: godot --headless --path . -s tools/giong_uo/xuat_mau.gd -- <thư mục ra>

const LINES := [
	["Cô Ba", "Chào Bơ! Sáng nay có 5 đơn, giao lúc bánh còn giòn nha!"],
	["Cô Ba", "Đơn 2: bánh mì trứng cho Bà Sáu, nhà số 9. Hẻm 42 có Chó Mực, đi rón rén!"],
	["Chú Tư", "Cảm ơn Bơ nha, bánh còn nóng hổi!"],
	["Bé Na", "Bơ giỏi quá, tìm được hết!"],
	["Chị Mây", "Đẹp quá! Thực đơn mới có mèo mẫu rồi."],
	["Anh Hùng", "Kịp lắm! Bơ ngồi chơi chút nha."],
	["Bà Sáu", "Bơ tới rồi đó! Đưa bà nè."],
	["Ông Bảy", "Suỵt! Ừ, để đó đi con."],
	["Ông Tám", "Ê con mèo này! Đổ bàn cờ bây giờ!"],
	["Cô Hai", "Còn lon trên cùng, nhảy lên đặt nha!"],
	["Chú Năm", "Lấy được mũ rồi hả? Cảm ơn con."],
	["Chị Thu", "Suỵt, em bé ngủ rồi. Cảm ơn Bơ nha!"],
	["Chị Vy", "Trễ giờ làm rồi, cho chị qua với!"],
	["meo:Bà Mướp", "Huy chương cho Bơ, mèo giao bánh của tuần!"],
	["meo:Lạc", "Hay quá Bơ ơiii!"],
	["meo:Mít", "Bơ ơi, ngậm quai đi!"],
	["Chó Mực", "Gâu! Gừ gừ."],
	["Cô Ba", "Ma, mà, má, mả, mã, mạ."],
	["Chú Tư", "Ma, mà, má, mả, mã, mạ."],
]


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://giong_uo"
	DirAccess.make_dir_recursive_absolute(out)
	var t0 := Time.get_ticks_usec()
	var idx := []
	for i in LINES.size():
		var who: String = LINES[i][0]
		var wav := GiongUO.line_wav(who, LINES[i][1])
		var f := "%s/%02d.wav" % [out, i]
		wav.save_to_wav(f)
		var v := GiongUO.voice(who)
		var times := []
		var t := 0.0
		for s: Dictionary in GiongUO.syllables(LINES[i][1]):
			times.append(snappedf(t, 0.001))
			t += float(v.syl) * ((0.72 if s.stop else 1.0) + 0.18 + float(s.gap))
		idx.append({"file": "%02d.wav" % i, "who": who, "text": LINES[i][1], "times": times, "v": v})
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var fa := FileAccess.open(out + "/index.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(idx, "  "))
	print("xuất %d câu, %d tiếng trong bộ đệm, %.0f ms (%.2f ms/tiếng)" % [LINES.size(), GiongUO._cache.size(), ms, ms / GiongUO._cache.size()])
	quit()
