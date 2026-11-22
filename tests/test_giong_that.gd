extends SceneTree
## Kiểm tra giọng thật (ElevenLabs, scripts/giong_that.gd): mỗi câu trong bảng có file ogg nạp được, câu vẫn
## còn đúng nguyên văn trong code (sửa câu mà quên làm lại giọng thì đỏ), so câu bỏ qua ngoặc kép,
## và GiongUO.noi phát giọng thật cho câu có trong bảng, câu khác vẫn nói giọng ú ớ.
## Chạy: godot --headless --path . -s tests/test_giong_that.gd

var fails := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var code := _all_code()
	var ids := {}
	for c: Array in GiongThat.CAU:
		var path: String = GiongThat.DIR + c[2] + ".ogg"
		var st = load(path)
		_check(st is AudioStream and st.get_length() > 0.3 and st.get_length() < 8.0, "%s nạp được (%s)" % [c[2], path])
		_check(not ids.has(c[2]), "mã %s không trùng" % c[2])
		ids[c[2]] = true
		_check(GiongUO.VOICES.has(c[0]), "%s có trong GiongUO.VOICES" % c[0])
		var mau := RegEx.create_from_string("\\d+").sub(c[1], "%d", true)  # câu có số đơn: mẫu "%d" trong code
		_check(code.contains(c[1]) or code.contains(mau), "câu của %s còn trong code: %s" % [c[0], c[1]])
	_check(GiongThat.ma("Bà Sáu", "\"Mực, đừng làm bé mèo sợ!\"") == "basau_muc", "bỏ ngoặc kép khi so câu")
	_check(GiongThat.ma("Cô Ba", "Câu không có trong bảng.") == "", "câu lạ không có giọng thật")
	_check(GiongThat.ma("Bé Na", "Cảm ơn Bơ nha!") == "bena_cam_on" and GiongThat.ma("Chú Năm", "Cảm ơn Bơ nha!") == "", "cùng câu, mỗi người một giọng")

	GiongUO.noi("Cô Ba", "Ngoan quá, Bơ của cô!")
	await process_frame
	await process_frame
	_check(GiongThat.dang_noi("Cô Ba") and GiongUO.dang_noi("Cô Ba"), "câu có trong bảng phát giọng thật")
	GiongUO.noi("Cô Ba", "Hôm nay trời đẹp ghê.")
	await process_frame
	_check(not GiongThat.dang_noi("Cô Ba") and GiongUO.dang_noi("Cô Ba"), "câu khác thì dừng giọng thật, nói ú ớ")
	GiongUO.dung("Cô Ba")
	_check(not GiongUO.dang_noi("Cô Ba"), "dung() dừng cả hai")

	if fails == 0:
		print("TEST GIONG THAT OK (%d câu)" % GiongThat.CAU.size())
	quit(1 if fails > 0 else 0)


func _all_code() -> String:
	var out := ""
	var stack := ["res://scripts"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for d in DirAccess.get_directories_at(dir):
			stack.append(dir + "/" + d)
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") and f != "giong_that.gd":
				out += FileAccess.get_file_as_string(dir + "/" + f) + "\n"
	return out


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)
