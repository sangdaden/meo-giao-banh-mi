class_name ChupAnh
extends CanvasLayer
## Chế độ chụp ảnh tự do (phím P, mọi ngày ngoài phố). Bơ đứng lại, chuột/cần xoay camera như thường,
## 1–5 chọn dáng (clip G2 của Bơ), Enter/chuột trái chụp, P hoặc Esc thoát. Đồng hồ đơn dừng khi đang chụp (dang_chup).
## Thứ Bảy (thu_bay.gd tự dựng): ảnh dán lên bìa Sổ hàng xóm, bản máy tính ghi PNG vào user://anh_thu_bay/,
## bản web giữ trong bộ nhớ phiên (SoHangXom.photos). snap() cũng dùng cho ảnh chung tự chụp lúc giúp xong một người.
## Ngày khác (U3, main.gd gọi ChupAnh.setup): ảnh Sang tự chụp thay ảnh tự động của ngày trên bảng "Tuần của Bơ"
## (AnhTuan.keep_tu_chup), ảnh chụp sau cùng của ngày là ảnh lên bảng.

signal shot(key: String)

const POSES := [["chup_dung", "Đứng ngắm"], ["chup_vay", "Vẫy tay"], ["chup_nam", "Nằm nghiêng"], ["phoi_nang", "Phơi nắng"], ["ngu_cuon", "Ngủ cuộn"]]

## true khi đang mở chế độ chụp ở bất kỳ ngày nào: đồng hồ đơn (main.gd, thu_sau.gd) và chỗ nằm đứng lại
static var dang_chup := false

var player: CharacterBody3D
var hud: CanvasLayer          ## HUD màn giao bánh: ẩn khi chụp
var extra_hide: Array = []    ## lớp giao diện khác cần ẩn lúc bấm máy (sổ, dòng việc)
var active := false
var count := 0
var day := ""                 ## ngày đang chơi; khác Thứ Bảy thì ảnh tự chụp lên bảng tuần
var tu_bam := false           ## tự nghe phím P / Esc (ngày giao bánh); Thứ Bảy thì thu_bay.gd gọi toggle()
var allow := Callable()       ## tu_bam: trả true khi được mở máy (đang chơi, chưa xong ngày)

var _panel: Control
var _flash: ColorRect
var _pose := 0
var _keys := {}
var _busy := false


## U3: chụp ảnh ở mọi ngày ngoài phố (Thứ Bảy đã có máy riêng trong thu_bay.gd).
## `can` trả true khi được mở máy (main.gd: đang chơi, chưa rời cảnh).
static func setup(m: Node, can: Callable) -> ChupAnh:
	var d = m.get("day")
	var id := str(d.get("id", "")) if d is Dictionary else ""
	if id == "" or id == SoHangXom.DAY:
		return null
	_them_phim()
	var c := ChupAnh.new()
	c.name = "ChupAnh"
	c.player = m.get("player")
	c.hud = m.get("hud")
	c.day = id
	c.tu_bam = true
	c.allow = can
	if m.get("arrow"):
		c.extra_hide = [m.get("arrow")]  # mũi tên chỉ đường trên đầu Bơ không lọt vào ảnh
	m.add_child(c)
	return c


static func _them_phim() -> void:
	if InputMap.has_action("chup_anh"):
		return
	InputMap.add_action("chup_anh")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_P
	InputMap.action_add_event("chup_anh", k)


func _exit_tree() -> void:
	if active:
		dang_chup = false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PAPER, 16, 12))
	UiTheme.place(_panel, 0.5, 1.0, Rect2(-390, -130, 780, 106))
	var l := UiTheme.label("", 17, UiTheme.INK, "bold")
	l.name = "Chu"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	_panel.add_child(l)
	_panel.visible = false
	add_child(_panel)


func toggle() -> void:
	if active:
		close()
	else:
		open()


func open() -> void:
	if active or not player.is_on_floor():
		return
	active = true
	dang_chup = true
	player.can_move = false
	player.velocity = Vector3.ZERO
	_set_pose(0)
	_panel.visible = true
	_refresh()


func close() -> void:
	if not active:
		return
	active = false
	dang_chup = false
	player.stop_clip()
	player.can_move = true
	_panel.visible = false


func _refresh() -> void:
	var names := []
	for i in POSES.size():
		names.append(("[%d %s]" if i == _pose else "%d %s") % [i + 1, POSES[i][1]])
	var where := "Ảnh dán lên bìa Sổ hàng xóm" if not tu_bam else "Ảnh chụp sau cùng lên bảng Tuần của Bơ · đồng hồ đang dừng"
	(_panel.get_node("Chu") as Label).text = "Chụp ảnh · " + " · ".join(names) + "\nChuột xoay camera · Enter chụp · P thoát" + "\n" + where


func _set_pose(i: int) -> void:
	_pose = i
	player.play_clip(POSES[i][0])
	_refresh()


func _process(_delta: float) -> void:
	if not active:
		return
	for i in POSES.size():
		if _edge(KEY_1 + i):
			_set_pose(i)
	if _edge(KEY_ENTER) or _edge(KEY_KP_ENTER):
		take()


func _unhandled_input(event: InputEvent) -> void:
	if tu_bam:
		if active and (event.is_action_pressed("pause") or event.is_action_pressed("chup_anh")):
			close()
			get_viewport().set_input_as_handled()
			return
		if not active and event.is_action_pressed("chup_anh") and not get_tree().paused and (not allow.is_valid() or allow.call()):
			open()
			if active:
				get_viewport().set_input_as_handled()
			return
	if active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		take()


func _edge(key: Key) -> bool:
	var down := Input.is_physical_key_pressed(key)
	var was: bool = _keys.get(key, false)
	_keys[key] = down
	return down and not was


## Chụp tự do: Thứ Bảy dán lên bìa sổ, ngày khác lên bảng tuần.
func take() -> void:
	count += 1
	snap("tuan" if tu_bam else "bia")


## Ẩn giao diện, chờ một khung hình vẽ xong rồi lấy ảnh màn hình, nháy trắng.
func snap(key: String) -> void:
	if _busy:
		return
	_busy = true
	var hidden := []
	for n in [hud, _panel] + extra_hide:
		if n and n.visible:
			n.visible = false
			hidden.append(n)
	await RenderingServer.frame_post_draw
	var img: Image = null
	if DisplayServer.get_name() != "headless":  # tự kiểm tra chạy không màn hình: không có ảnh để lấy
		img = get_viewport().get_texture().get_image()
	if key == "tuan":
		AnhTuan.keep_tu_chup(day, img)
	else:
		SoHangXom.keep_photo(key, img)
	for n in hidden:
		if is_instance_valid(n):
			n.visible = true
	_sfx("record")
	_flash.color.a = 0.8
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	_busy = false
	shot.emit(key)


## Tiếng động qua autoload Sound (không gọi thẳng tên autoload: chạy được cả khi chụp ảnh bằng -s).
func _sfx(sound_name: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.play(sound_name)
