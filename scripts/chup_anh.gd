class_name ChupAnh
extends CanvasLayer
## Chế độ chụp ảnh tự do (phím P, Thứ Bảy bật cả ngày). Bơ đứng lại, chuột/cần xoay camera như thường,
## 1–5 chọn dáng (clip G2 của Bơ), Enter/chuột trái chụp, P hoặc Esc thoát. Ảnh đẹp dán lên bìa Sổ hàng xóm.
## Bản máy tính ghi PNG vào user://anh_thu_bay/, bản web giữ trong bộ nhớ phiên (SoHangXom.photos).
## snap() cũng dùng cho ảnh chung tự chụp lúc giúp xong một người.

signal shot(key: String)

const POSES := [["chup_dung", "Đứng ngắm"], ["chup_vay", "Vẫy tay"], ["chup_nam", "Nằm nghiêng"], ["phoi_nang", "Phơi nắng"], ["ngu_cuon", "Ngủ cuộn"]]

var player: CharacterBody3D
var hud: CanvasLayer          ## HUD màn giao bánh: ẩn khi chụp
var extra_hide: Array = []    ## lớp giao diện khác cần ẩn lúc bấm máy (sổ, dòng việc)
var active := false
var count := 0

var _panel: Control
var _flash: ColorRect
var _pose := 0
var _keys := {}
var _busy := false


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
	UiTheme.place(_panel, 0.5, 1.0, Rect2(-330, -110, 660, 84))
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
	player.can_move = false
	player.velocity = Vector3.ZERO
	_set_pose(0)
	_panel.visible = true
	_refresh()


func close() -> void:
	if not active:
		return
	active = false
	player.stop_clip()
	player.can_move = true
	_panel.visible = false


func _refresh() -> void:
	var names := []
	for i in POSES.size():
		names.append(("[%d %s]" if i == _pose else "%d %s") % [i + 1, POSES[i][1]])
	(_panel.get_node("Chu") as Label).text = "Chụp ảnh · " + " · ".join(names) + "\nChuột xoay camera · Enter chụp · P thoát"


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
	if active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		take()


func _edge(key: Key) -> bool:
	var down := Input.is_physical_key_pressed(key)
	var was: bool = _keys.get(key, false)
	_keys[key] = down
	return down and not was


## Chụp tự do: ảnh dán lên bìa sổ.
func take() -> void:
	count += 1
	snap("bia")


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
