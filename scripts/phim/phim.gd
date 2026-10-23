class_name Phim
extends Node3D
## Cảnh phim C1 (trang phác thảo Sang duyệt 23/10/2026): phim mở đầu 40 s (scripts/phim/mo_dau.gd) và cảnh kết tuần
## sau Hội mèo (scripts/phim/ket_tuan.gd). Đây là phần chạy chung: camera, phụ đề, chữ lớn, màn đen, giữ phím để bỏ qua.
## Chạy bằng cảnh scenes/phim.tscn:
##   Phim.mo_dau(get_tree(), "tuan")         # chiếu phim mở đầu rồi vào Thứ Hai ("menu": xem lại từ trang chủ)
##   Phim.ket_tuan(get_tree(), {...})        # cảnh kết tuần, data như TongKetTuan (scripts/chu_nhat.gd gọi)
## Kịch bản là một Node có run(phim) (coroutine) và tuỳ chọn skip(); kịch bản gọi phim.finish() khi xong.
## Thử nhanh không màn hình: godot --headless --path . res://scenes/phim.tscn -- --phim=mo_dau --phim-test
## (chạy nhanh 12 lần, in "PHIM MO_DAU OK" rồi thoát).

const SCENE := "res://scenes/phim.tscn"
const SKIP_HOLD := 1.0
const PlayerScript := preload("res://scripts/player.gd")

## "mo_dau" | "ket_tuan"
static var which := "mo_dau"
## Phim mở đầu xong thì: "tuan" chơi Thứ Hai (Chơi mới), "menu" về trang chủ (xem lại)
static var after := "tuan"
## Cảnh kết tuần: số liệu bảng tổng kết (medals, neighbour_pages, week_stars, week_stars_max, extra_medal, new_week_text, best)
static var data := {}

var cam: Camera3D
var script_node: Node
var done := false
var test := false
var _ui: CanvasLayer
var _bars: Array[ColorRect] = []
var _sub: PanelContainer
var _sub_who: Label
var _sub_text: Label
var _title: Label
var _fade: ColorRect
var _skip_box: Control
var _skip_bar: ColorRect
var _skip_t := 0.0
var _skip_used := false
var _move := {}            ## camera đang lướt: from_pos, from_look, from_fov, to_pos, to_look, to_fov, t, len
var _look := Vector3.ZERO
var _track: Node3D         ## camera bám theo node này (đi ngang, đi lùi trước mặt)
var _track_pos := Vector3.ZERO
var _track_look := Vector3.ZERO
var _sub_tw: Tween


static func mo_dau(tree: SceneTree, then := "tuan") -> void:
	which = "mo_dau"
	after = then
	tree.paused = false
	tree.change_scene_to_file(SCENE)


static func ket_tuan(tree: SceneTree, summary: Dictionary) -> void:
	which = "ket_tuan"
	data = summary
	tree.paused = false
	tree.change_scene_to_file(SCENE)


## Phim mở đầu tự chiếu khi bắt đầu tuần đầu tiên (chưa có ngày lưu) và khi bấm Chơi mới.
static func intro_ready() -> bool:
	return ResourceLoader.exists(SCENE)


## Bắt đầu một tuần mới từ trang chủ, có phim mở đầu trước (Sang 23/10: tự chiếu, bỏ qua được).
static func new_game(tree: SceneTree) -> void:
	PlayMode.reset_week()
	if intro_ready():
		mo_dau(tree, "tuan")
	else:
		PlayMode.play_week(tree)


## K1 cảnh kết tuần (Sang duyệt 23/10): ngay sau lễ trao huy chương, Bà Mướp gọi cả hội cười, đèn flash, khung hình dừng
## thành tấm ảnh giấy bay vào góc (ảnh Chủ Nhật trên bảng "Tuần của Bơ"), rồi sang phim kết tuần. chu_nhat.gd gọi.
static func anh_hoi(node: Node, ba_muop: Node, summary: Dictionary) -> void:
	var tree := node.get_tree()
	if ba_muop and ba_muop.has_method("say"):
		ba_muop.say("Cười lên nào cả hội!", 2.5)
	await tree.create_timer(1.8).timeout
	await AnhTuan.chup(node, "chu_nhat")  # chụp trước khi nháy, ảnh không dính màn trắng
	var layer := CanvasLayer.new()
	layer.layer = 40
	node.add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	UiTheme.full_rect(flash)
	layer.add_child(flash)
	node.create_tween().tween_property(flash, "color:a", 0.0, 0.5)
	var snd := node.get_node_or_null("/root/Sound")
	if snd:
		snd.play("record")
	var tex := AnhTuan.texture("chu_nhat")
	if tex:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.box(Color("#FBF3E2"), 6, 14, Color(0, 0, 0, 0.25), 1))
		var img := TextureRect.new()
		img.texture = tex
		img.custom_minimum_size = Vector2(448, 336)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.add_child(img)
		UiTheme.place(card, 0.5, 0.5, Rect2(-238, -182, 476, 364))
		card.pivot_offset = Vector2(238, 182)
		card.rotation_degrees = -4.0
		layer.add_child(card)
		var vs := node.get_viewport().get_visible_rect().size
		var tw := node.create_tween()
		tw.tween_interval(1.1)
		tw.set_parallel()
		tw.tween_property(card, "scale", Vector2.ONE * 0.32, 0.7).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(card, "position", Vector2(vs.x - 238 - 170, -182 + 110), 0.7).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(card, "rotation_degrees", 6.0, 0.7)
	await tree.create_timer(2.3).timeout
	ket_tuan(tree, summary)


func _ready() -> void:
	if not InputMap.has_action("jump"):  # chữ chạy (TongKetTuan) bỏ qua bằng phím cách như trong màn chơi
		InputMap.add_action("jump")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_SPACE
		InputMap.action_add_event("jump", ev)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--phim="):
			which = a.substr(7)
	test = "--phim-test" in args
	if test:
		Engine.time_scale = 12.0
	GameSettings.apply_graphics(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	cam = Camera3D.new()
	cam.cull_mask = 0xFFFFF & ~PlayerScript.LAYER_FP_PAWS
	cam.near = 0.05
	add_child(cam)
	cam.current = true
	_build_ui()
	script_node = load("res://scripts/phim/%s.gd" % which).new()
	script_node.name = which
	add_child(script_node)
	script_node.run(self)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ---------------------------------------------------------------- dùng trong kịch bản

## Chờ secs giây. Trả false nếu phim đã xong (bị bỏ qua) để kịch bản dừng: if not await p.wait(2): return
func wait(secs: float) -> bool:
	if done:
		return false
	await get_tree().create_timer(secs, false).timeout
	return not done and is_inside_tree()


## Đặt camera ngay (cắt cảnh). pos, look theo toạ độ Godot; lens là tiêu cự máy 35 mm như bản phác thảo Blender.
func cut(pos: Vector3, look: Vector3, lens := 32.0) -> void:
	_move = {}
	_track = null
	cam.fov = fov(lens)
	_place(pos, look)


## Lướt camera từ chỗ đang đứng tới pos/look trong secs giây (êm đầu êm cuối).
func move(pos: Vector3, look: Vector3, lens: float, secs: float) -> void:
	_track = null
	_move = {"from_pos": cam.global_position, "from_look": _look, "from_fov": cam.fov,
		"to_pos": pos, "to_look": look, "to_fov": fov(lens), "t": 0.0, "len": maxf(secs, 0.01)}


## Camera đi theo node: đặt ở node + pos_off, nhìn node + look_off (máy đi ngang, đi lùi trước mặt).
func track(node: Node3D, pos_off: Vector3, look_off: Vector3, lens := 32.0) -> void:
	_move = {}
	_track = node
	_track_pos = pos_off
	_track_look = look_off
	cam.fov = fov(lens)


## Góc nhìn dọc (độ) của ống kính lens mm, khung 16:9 như cảnh phác thảo.
static func fov(lens: float) -> float:
	return rad_to_deg(2.0 * atan(18.0 / lens * 9.0 / 16.0))


## Phụ đề: tên người nói và câu thoại, tự tắt sau secs giây. who "" là lời dẫn.
func say(who: String, text: String, secs := 3.5, sfx := "") -> void:
	_sub_who.text = who
	_sub_who.visible = who != ""
	_sub_text.text = text
	if _sub_tw:
		_sub_tw.kill()
	_sub.modulate.a = 0.0
	_sub.visible = true
	_sub_tw = create_tween()
	_sub_tw.tween_property(_sub, "modulate:a", 1.0, 0.25)
	_sub_tw.tween_interval(maxf(secs - 0.5, 0.2))
	_sub_tw.tween_property(_sub, "modulate:a", 0.0, 0.25)
	_sub_tw.tween_callback(_sub.hide)
	if sfx != "":
		sound(sfx)


## Chữ lớn giữa màn hình (tên game, "Thứ Hai"), hiện rồi tan.
func title(text: String, secs := 3.0, size := 92) -> void:
	_title.text = text
	_title.add_theme_font_size_override("font_size", size)
	_title.modulate.a = 0.0
	_title.visible = true
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 0.6)
	tw.tween_interval(maxf(secs - 1.4, 0.2))
	tw.tween_property(_title, "modulate:a", 0.0, 0.8)
	tw.tween_callback(_title.hide)


## Màn đen phủ (alpha 1) hoặc mở ra (alpha 0) trong secs giây; color để chớp trắng (đèn flash).
func fade(alpha: float, secs := 0.6, color := Color(0.04, 0.03, 0.05)) -> void:
	_fade.color = Color(color, _fade.color.a)
	create_tween().tween_property(_fade, "color:a", alpha, secs)


## Viền đen trên dưới kiểu phim: hiện (on) hoặc thu lại.
func bars(on: bool, secs := 0.6) -> void:
	for i in 2:
		var b := _bars[i]
		var h := get_viewport().get_visible_rect().size.y * 0.085
		create_tween().tween_property(b, "custom_minimum_size:y", h if on else 0.0, secs)


func sound(sound_name: String, volume_db := 0.0) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.play(sound_name, volume_db)


func music(track_name: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.music(track_name)


func ambience(track_name: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.ambience(track_name)


## Cho phép hay tắt giữ phím để bỏ qua (cảnh kết tuần tắt lúc đang hiện bảng tổng kết, đã có nút riêng).
func allow_skip(on: bool) -> void:
	_skip_box.visible = on
	_skip_t = 0.0


## Kịch bản xong: làm bước tiếp theo (vào Thứ Hai, về trang chủ...) qua then, sau khi màn đen phủ kín.
func finish(then: Callable) -> void:
	if done:
		return
	done = true
	if test:
		print("PHIM %s OK" % which.to_upper())
		get_tree().quit(0)
		return
	fade(1.0, 0.5)
	await get_tree().create_timer(0.55, false).timeout
	then.call()


# ---------------------------------------------------------------- bên trong

func _place(pos: Vector3, look: Vector3) -> void:
	cam.global_position = pos
	_look = look
	if not pos.is_equal_approx(look):
		cam.look_at(look, Vector3.UP)


func _process(delta: float) -> void:
	if _track and is_instance_valid(_track):
		var p := _track.global_position
		var want_pos := p + _track_pos
		var want_look := p + _track_look
		var k := 1.0 - exp(-6.0 * delta)
		_place(cam.global_position.lerp(want_pos, k), _look.lerp(want_look, k))
	elif not _move.is_empty():
		_move.t += delta
		var u := smoothstep(0.0, 1.0, clampf(_move.t / _move.len, 0.0, 1.0))
		cam.fov = lerpf(_move.from_fov, _move.to_fov, u)
		_place(_move.from_pos.lerp(_move.to_pos, u), _move.from_look.lerp(_move.to_look, u))
		if _move.t >= _move.len:
			_move = {}
	# Giữ phím cách / Enter / chuột / nút A 1 giây để bỏ qua
	if _skip_box.visible and not done:
		var held := Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_accept") \
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
		_skip_t = minf(_skip_t + delta / Engine.time_scale, SKIP_HOLD) if held else maxf(_skip_t - delta * 2.0, 0.0)
		_skip_bar.scale.x = _skip_t / SKIP_HOLD
		if _skip_t >= SKIP_HOLD:
			_skip_t = 0.0
			if script_node.has_method("skip"):
				script_node.skip()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	var col := VBoxContainer.new()
	UiTheme.full_rect(col)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	_ui.add_child(col)
	for i in 2:
		var b := ColorRect.new()
		b.color = Color(0.04, 0.03, 0.05)
		b.custom_minimum_size = Vector2(0, 0)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bars.append(b)
	col.add_child(_bars[0])
	var mid := Control.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(mid)
	col.add_child(_bars[1])

	_sub = PanelContainer.new()
	_sub.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.PAPER, 0.94), 20, 16, UiTheme.INK, 3, 4))
	UiTheme.place(_sub, 0.5, 1.0, Rect2(-430, -80, 860, 0))
	_sub.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sub.visible = false
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_sub)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	_sub.add_child(sv)
	_sub_who = UiTheme.label("", 18, UiTheme.RED, "bold")
	sv.add_child(_sub_who)
	_sub_text = UiTheme.label("", 25, UiTheme.INK, "body")
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(_sub_text)

	_title = UiTheme.outlined("", 92, UiTheme.FUR, 16)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.full_rect(_title)
	_title.visible = false
	_ui.add_child(_title)

	_skip_box = VBoxContainer.new()
	UiTheme.place(_skip_box, 1.0, 1.0, Rect2(-300, -46, 270, 34))
	_skip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_skip_box)
	var hint := UiTheme.label("Giữ phím cách để bỏ qua", 15, Color(UiTheme.PAPER, 0.75), "bold")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_box.add_child(hint)
	var track_bg := ColorRect.new()
	track_bg.color = Color(UiTheme.PAPER, 0.2)
	track_bg.custom_minimum_size = Vector2(0, 4)
	track_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_box.add_child(track_bg)
	_skip_bar = ColorRect.new()
	_skip_bar.color = UiTheme.FUR
	UiTheme.full_rect(_skip_bar)
	_skip_bar.scale.x = 0.0
	_skip_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_bg.add_child(_skip_bar)

	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.03, 0.05, 1.0)
	UiTheme.full_rect(_fade)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)
