extends SceneTree
## Kiểm tra giọng ú ớ (E1): tách âm tiết và dấu thanh, chọn giọng theo tên/xưng hô, tiếng tạo ra có tiếng
## và đúng độ dài, cao độ đi đúng hướng dấu (sắc lên, huyền xuống), Cô Ba "nói" khi hiện bong bóng ở màn giao bánh.
## Chạy: godot --headless --path . -s tests/test_giong_uo.gd

var fails := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Dấu thanh và nguyên âm chính
	var tones := []
	for s: Dictionary in GiongUO.syllables("ma, mà má mả mã mạ."):
		tones.append(s.tone)
	_check(tones == [0, 1, 2, 3, 4, 5], "sáu dấu thanh: %s" % [tones])
	var s1: Array = GiongUO.syllables("Chào Bơ! Sáng nay có 5 đơn, giao lúc bánh còn giòn nha!")
	_check(s1.size() == 13, "câu Cô Ba 13 âm tiết (%d)" % s1.size())
	_check(s1[0].vowel == "a" and s1[0].onset == "gio" and s1[1].vowel == "ơ" and s1[1].end == "!", "chào/Bơ!: nguyên âm, phụ âm đầu, dấu chấm than")
	_check(s1[1].gap > 2.0 and s1[6].gap > 1.0, "nghỉ sau dấu chấm than và dấu phẩy")
	_check(GiongUO.syllables("hoa")[0].vowel == "a" and GiongUO.syllables("quê")[0].vowel == "e" and GiongUO.syllables("mít")[0].stop, "hoa → a, quê → e, mít tắc")
	_check(GiongUO.syllables("\"...\"").is_empty(), "không có chữ thì không nói")

	# Giọng
	_check(GiongUO.voice("Cô Ba").f0 > 200.0 and GiongUO.voice("Ông Bảy").f0 < 130.0, "Cô Ba cao, Ông Bảy trầm")
	var vy := GiongUO.voice("Chị Vy")
	_check(vy.f0 > 220.0 and vy.f0 < 300.0 and vy == GiongUO.voice("Chị Vy"), "người lạ lấy giọng theo xưng hô, cùng tên cùng giọng")
	_check(GiongUO.voice("meo:Mít").get("kind", "") == "meo" and GiongUO.voice("meo:Bà Mướp").get("kind", "") == "meo", "mèo có giọng meo")

	# Tiếng tạo ra
	var v := GiongUO.voice("Cô Ba")
	var t0 := Time.get_ticks_usec()
	var w := GiongUO.render(v, GiongUO.syllables("má")[0], 7)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var n := w.data.size() / 2
	_check(absf(float(n) / GiongUO.SR - v.syl) < 0.02, "một tiếng dài đúng nhịp (%.3f s)" % (float(n) / GiongUO.SR))
	var peak := 0
	for i in n:
		peak = maxi(peak, absi(w.data.decode_s16(i * 2)))
	_check(peak > 20000, "tiếng có âm lượng (đỉnh %d)" % peak)
	_check(ms < 40.0, "tạo một tiếng nhanh (%.1f ms)" % ms)
	_check(GiongUO.contour(2, 0.9, 1.0, "") > 1.15 and GiongUO.contour(1, 0.9, 1.0, "") < 0.9, "sắc đi lên, huyền đi xuống")
	_check(GiongUO.contour(0, 0.9, 1.0, "?") > GiongUO.contour(0, 0.9, 1.0, ""), "câu hỏi cao giọng cuối câu")

	# Trong màn giao bánh: Cô Ba nói thì có giọng, nói xong thì hết
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var residents: Node = main.get("residents")
	residents.say("Chào Bơ! Sáng nay có 3 đơn.", 3.0, "vay")
	await process_frame
	_check(GiongUO.dang_noi("Cô Ba"), "Cô Ba hiện bong bóng thì nói ú ớ")
	var played := false
	for i in 60:
		await process_frame
		for p: AudioStreamPlayer in GiongUO._mgr._pool:
			played = played or p.playing
	_check(played, "có máy phát đang phát tiếng")
	await create_timer(2.5).timeout
	_check(not GiongUO.dang_noi("Cô Ba"), "nói xong câu thì dừng")
	GiongUO.noi("Ông Tám", "Ê con mèo này!", residents.coba)
	GiongUO.noi("Ông Tám", "Suỵt!")
	_check(GiongUO._mgr._talks["Ông Tám"].syl.size() == 1, "nói câu mới thì bỏ câu cũ")

	if fails == 0:
		print("TEST GIONG UO OK")
	else:
		print("TEST GIONG UO: %d lỗi" % fails)
	quit(1 if fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  LỖI: ", what)
