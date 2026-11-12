class_name AnhTuanLuu
extends RefCounted
## Nút "Lưu ảnh tuần" ở màn hết tuần (Vũ Trụ Mark B1, Sang chọn 30/10/2026): ghép 7 ảnh ngày của AnhTuan thành
## một tấm 1080×1350 (khổ dọc Facebook/Instagram) có tên game, số sao cả tuần và địa chỉ meo.markhocai.com,
## để người chơi đăng khoe. Bản web tải file về máy, bản PC ghi vào thư mục Ảnh (Pictures) rồi mở thư mục.
##
## Dựng bằng Control trong một SubViewport (Image không tự vẽ được chữ). Không chạy trên máy không có màn hình.
##   var anh := await AnhTuanLuu.ghep(node, {"week_stars": 12, "week_stars_max": 15, "neighbour_pages": 9})
##   AnhTuanLuu.luu(anh)   # trả về chữ báo cho người chơi, "" nếu không lưu được

const SIZE := Vector2i(1080, 1350)
const O := Vector2(320, 240)       ## ô ảnh một ngày (ảnh gốc 256×192, cùng tỉ lệ 4:3)
const GAP := 30.0
const LINK := "meo.markhocai.com"
const FILE := "tuan-cua-bo.png"


## Dựng tấm ảnh tuần. data: week_stars, week_stars_max, neighbour_pages (khóa nào thiếu thì dòng đó ẩn).
static func ghep(node: Node, data := {}) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(_trang(data))
	node.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image() if is_instance_valid(vp) else null
	if is_instance_valid(vp):
		vp.queue_free()
	return img


## Ghi tấm ảnh ra cho người chơi. Trả chữ báo kết quả (đã dịch sẵn qua tr khi hiện bằng Label).
static func luu(img: Image) -> String:
	if img == null or img.is_empty():
		return ""
	TrangWeb.dem("meo-luu-anh-tuan")
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), FILE, "image/png")
		return "Đã tải ảnh tuần về máy."
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		dir = ProjectSettings.globalize_path("user://anh_tuan")
	var path := dir.path_join("tuan-cua-bo-%s.png" % Time.get_date_string_from_system())
	if img.save_png(path) != OK:
		return ""
	OS.shell_open(dir)
	return "Đã lưu ảnh tuần vào thư mục Ảnh."


static func _trang(data: Dictionary) -> Control:
	var T := UiTheme
	var nen := ColorRect.new()
	nen.color = T.PAPER
	nen.size = Vector2(SIZE)
	# mái hiên sọc đỏ trắng ở trên cùng, như bảng hiệu lò bánh
	for i in 12:
		var soc := ColorRect.new()
		soc.color = T.RED if i % 2 == 0 else Color.WHITE
		soc.position = Vector2(i * SIZE.x / 12.0, 0)
		soc.size = Vector2(SIZE.x / 12.0 + 1, 26)
		nen.add_child(soc)
	var ten := T.label("Mèo Giao Bánh Mì", 40, T.INK, "display")
	ten.position = Vector2(GAP, 50)
	nen.add_child(ten)
	var tieu_de := T.label("Tuần của Bơ", 96, T.FUR, "display")
	tieu_de.add_theme_color_override("font_outline_color", T.INK)
	tieu_de.add_theme_constant_override("outline_size", 12)
	tieu_de.position = Vector2(GAP, 92)
	nen.add_child(tieu_de)
	# 7 ngày + một ô số liệu, lưới 3 cột
	var y0 := 250.0
	var days: Array = GameState.DAY_NAMES.keys()
	for i in 9:
		var p := Vector2(GAP + (i % 3) * (O.x + GAP), y0 + (i / 3) * (O.y + 58))
		if i < days.size():
			nen.add_child(_o_ngay(days[i], p))
		elif i == 7:
			nen.add_child(_o_so(data, p))
	var cuoi := T.label("Chơi miễn phí trên trình duyệt: " + LINK, 30, T.INK, "bold")
	cuoi.position = Vector2(GAP, SIZE.y - 76)
	nen.add_child(cuoi)
	return nen


static func _o_ngay(day: String, p: Vector2) -> Control:
	var T := UiTheme
	var khung := ColorRect.new()
	khung.color = T.INK
	khung.position = p
	khung.size = O
	var tex := AnhTuan.texture(day)
	if tex:
		var anh := TextureRect.new()
		anh.texture = tex
		anh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		anh.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		anh.position = Vector2(4, 4)
		anh.size = O - Vector2(8, 8)
		khung.add_child(anh)
	else:
		var trong := ColorRect.new()
		trong.color = T.SAND
		trong.position = Vector2(4, 4)
		trong.size = O - Vector2(8, 8)
		khung.add_child(trong)
	var ten := T.label(str(GameState.DAY_NAMES.get(day, day)), 26, T.INK, "bold")
	ten.position = Vector2(0, O.y + 8)
	khung.add_child(ten)
	return khung


static func _o_so(data: Dictionary, p: Vector2) -> Control:
	var T := UiTheme
	var o := VBoxContainer.new()
	o.position = p + Vector2(10, 20)
	o.size = O - Vector2(20, 40)
	o.add_theme_constant_override("separation", 10)
	if data.has("week_stars_max") and int(data.week_stars_max) > 0:
		o.add_child(T.label("%d/%d sao" % [int(data.week_stars), int(data.week_stars_max)], 44, T.CRUST_DARK, "display"))
	if data.has("neighbour_pages"):
		o.add_child(T.label("Sổ hàng xóm: %d trang" % int(data.neighbour_pages), 24, T.INK, "bold"))
	o.add_child(T.label("Mèo giao bánh của tuần", 24, T.MUTED, "body"))
	return o
