extends SceneTree
## Kiểm tra nút "Lưu ảnh tuần" (Vũ Trụ Mark B1, scripts/phim/anh_tuan_luu.gd) và phễu người chơi bản web (P1,
## scripts/trang_web.gd): màn hết tuần có nút, chữ mới có bản tiếng Anh, bản không màn hình không dựng ảnh,
## các hàm đếm không lỗi khi không phải bản web. Không ghi file nào ra máy.
## Chạy: godot --headless --path . -s tests/test_anh_tuan_luu.gd

const EnGiaoDien := preload("res://scripts/dich/en_giao_dien.gd")

var fails := 0


func _init() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1


func _run() -> void:
	print("Tiếng Anh")
	for chu in ["Lưu ảnh tuần", "Đã tải ảnh tuần về máy.", "Đã lưu ảnh tuần vào thư mục Ảnh.", "Chưa lưu được ảnh",
			"Tuần của Bơ", "Chơi miễn phí trên trình duyệt: " + AnhTuanLuu.LINK, "%d/%d sao", "Sổ hàng xóm: %d trang",
			"Mèo giao bánh của tuần"]:
		_check(EnGiaoDien.EN.has(chu), "có bản tiếng Anh: " + chu)

	print("Màn hết tuần")
	var tk := TongKetTuan.new()
	tk.week_stars = 12
	tk.week_stars_max = 15
	root.add_child(tk)
	await process_frame
	tk._start_credits()
	tk._end_credits()
	await process_frame
	var co := false
	for b: Button in tk.find_children("*", "Button", true, false):
		co = co or b.text == "Lưu ảnh tuần"
	_check(co, "có nút Lưu ảnh tuần")
	var img = await AnhTuanLuu.ghep(tk, {"week_stars": 12, "week_stars_max": 15})
	_check(img == null, "không màn hình thì không dựng ảnh")
	_check(AnhTuanLuu.luu(null) == "", "không có ảnh thì không lưu gì")
	tk.queue_free()

	print("Phễu bản web")
	TrangWeb.tai_xong()
	TrangWeb.tai_xong()
	var n := Node.new()
	TrangWeb.theo_don(n)
	n.free()
	_check(true, "gọi hàm đếm ngoài bản web không lỗi")

	print("ANH TUAN LUU TEST OK" if fails == 0 else "ANH TUAN LUU TEST FAIL (%d)" % fails)
	quit(1 if fails else 0)
