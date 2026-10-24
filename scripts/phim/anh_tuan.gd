class_name AnhTuan
## Ảnh 7 ngày trên bảng "Tuần của Bơ" (cảnh kết tuần C1, Sang chọn 23/10/2026):
## game tự chụp một khung hình lúc giao mỗi đơn, đơn giao sau cùng của ngày là ảnh của ngày đó;
## Thứ Bảy dùng ảnh Sang chụp bằng phím P (Sổ hàng xóm) nếu có; Chủ Nhật là ảnh chung Hội mèo.
## Ảnh 256×192 ghi ra user://anh_tuan/<ngày>.jpg (bản web: ổ lưu của trình duyệt) và giữ trong bộ nhớ phiên.
##
## main.gd chỉ cần AnhTuan.setup(self) sau khi dựng camera.

const DIR := "user://anh_tuan"
const SIZE := Vector2i(256, 192)
const AFTER := 0.35   ## chụp sau khi giao chừng này giây: Bơ đang trong dáng giao, khách đang nhận

static var photos := {}


static func setup(main: Node) -> void:
	if DisplayServer.get_name() == "headless" or not main.has_signal("order_delivered"):
		return
	# Hẹn giờ của SceneTree sống qua lúc đổi cảnh (vd. đơn 5 sang chung cư), nên giữ main bằng weakref:
	# bắt thẳng main vào lambda thì Godot báo "Lambda capture at index 0 was freed" khi main đã bị xóa.
	var ref: WeakRef = weakref(main)
	main.order_delivered.connect(func(_i: int, _o: Dictionary):
		main.get_tree().create_timer(AFTER).timeout.connect(func():
			var m: Node = ref.get_ref()
			if m:
				chup(m, GameState.day)))


## Chụp khung hình camera đang dùng (không có HUD) thành ảnh của ngày `day`.
static func chup(node: Node, day: String) -> void:
	var src := node.get_viewport().get_camera_3d()
	if src == null:
		return
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.world_3d = node.get_viewport().world_3d
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cam := Camera3D.new()
	cam.fov = src.fov
	cam.near = src.near
	cam.far = src.far
	cam.cull_mask = src.cull_mask
	vp.add_child(cam)
	node.add_child(vp)
	cam.global_transform = src.global_transform
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if is_instance_valid(vp):
		keep(day, vp.get_texture().get_image())
		vp.queue_free()


## Giữ ảnh của ngày (cắt giữa cho đúng 4:3, thu về 256×192) và ghi file.
static func keep(day: String, img: Image) -> void:
	if img == null or img.is_empty():
		return
	img = img.duplicate()
	var want := float(SIZE.x) / SIZE.y
	var w := img.get_width()
	var h := img.get_height()
	if absf(float(w) / h - want) > 0.01:
		var cw := mini(w, int(h * want))
		var ch := mini(h, int(cw / want))
		img = img.get_region(Rect2i((w - cw) / 2, (h - ch) / 2, cw, ch))
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGB8)
	photos[day] = img
	DirAccess.make_dir_recursive_absolute(DIR)
	img.save_jpg("%s/%s.jpg" % [DIR, day], 0.85)


## Ảnh của ngày (phiên này hoặc file đã lưu). Thứ Bảy chưa có thì lấy ảnh bìa Sổ hàng xóm. null nếu chưa có.
static func image(day: String) -> Image:
	if photos.has(day):
		return photos[day]
	var path := "%s/%s.jpg" % [DIR, day]
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img and not img.is_empty():
			photos[day] = img
			return img
	if day == "thu_bay":
		var bia := SoHangXom.photo("bia")
		if bia:
			keep(day, bia)
			return photos.get(day)
	return null


static func texture(day: String) -> Texture2D:
	var img := image(day)
	return ImageTexture.create_from_image(img) if img else null
