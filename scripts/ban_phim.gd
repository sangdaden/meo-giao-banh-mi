class_name BanPhim
extends Node
## F2: đổi phím và tay cầm (autoload tên "DieuKhien", khai trong project.godot).
##
## Mỗi cảnh vẫn tự khai phím mặc định như cũ (main.gd, kitchen.gd, hud.gd, con_vat.gd...). Bảng PHIM dưới đây
## ghi lại đúng các phím đó; autoload này thấy có phím mới khai (hoặc người chơi vừa đổi) thì đặt lại phím
## của các hành động đã có theo bảng + phần người chơi đổi (GameSettings "ban_phim").
## Người chơi chỉ đổi phím chính và nút tay cầm chính của mỗi việc; phím phụ (mũi tên, Ctrl, Alt, Enter, chuột)
## giữ nguyên, trừ khi phím phụ đó đã thành phím chính của việc khác.
## Thêm phím mới cho người chơi đổi: thêm một dòng ở cuối PHIM (và câu tiếng Anh cho nhãn).
##
## Tay cầm trong menu: A là ui_accept (bấm nút đang chọn), B là ui_cancel (quay lại).

## [hành động, nhãn, nhóm, phím chính, phím phụ, nút chính, nút phụ, trục cần]
## Nhóm: "chung" (mọi màn), "pho" (ngoài phố), "bep" (bếp Cô Ba), "thu_bay". Hai việc chung nhóm thì không trùng phím.
const PHIM := [
	["move_forward", "Đi lên", "chung", KEY_W, [KEY_UP], -1, [], [[JOY_AXIS_LEFT_Y, -1.0]]],
	["move_back", "Đi xuống", "chung", KEY_S, [KEY_DOWN], -1, [], [[JOY_AXIS_LEFT_Y, 1.0]]],
	["move_left", "Sang trái", "chung", KEY_A, [KEY_LEFT], -1, [], [[JOY_AXIS_LEFT_X, -1.0]]],
	["move_right", "Sang phải", "chung", KEY_D, [KEY_RIGHT], -1, [], [[JOY_AXIS_LEFT_X, 1.0]]],
	["jump", "Nhảy", "chung", KEY_SPACE, [], JOY_BUTTON_A, [], []],
	["sprint", "Chạy nhanh", "chung", KEY_SHIFT, [], JOY_BUTTON_RIGHT_SHOULDER, [JOY_BUTTON_X], []],
	["crouch", "Chui", "pho", KEY_C, ["pc", KEY_CTRL], JOY_BUTTON_B, [], []],
	["sneak", "Rón rén", "pho", KEY_Z, ["pc", KEY_ALT], JOY_BUTTON_LEFT_STICK, [], []],
	["deliver", "Giao bánh", "pho", KEY_E, [], JOY_BUTTON_Y, [], []],
	["goi", "Kêu meo", "pho", KEY_Q, [], JOY_BUTTON_LEFT_SHOULDER, [], []],
	["ban_do", "Bản đồ lớn", "pho", KEY_B, [], JOY_BUTTON_DPAD_UP, [], []],
	["the_nhiem_vu", "Thẻ nhiệm vụ", "pho", KEY_TAB, [], JOY_BUTTON_BACK, [], []],
	["cuu_ket", "Về chỗ an toàn (giữ)", "chung", KEY_R, [], JOY_BUTTON_DPAD_DOWN, [], []],
	["tu_di_pho", "Tự đi theo mũi tên (giữ)", "pho", KEY_F, [], JOY_BUTTON_DPAD_RIGHT, [], []],
	["interact", "Làm (bếp)", "bep", KEY_E, [KEY_ENTER, KEY_KP_ENTER, "chuot"], JOY_BUTTON_B, [], []],
	["tu_di", "Tự đi tới trạm (bếp)", "bep", KEY_TAB, [], JOY_BUTTON_Y, [], []],
	["so_hang_xom", "Sổ hàng xóm", "thu_bay", KEY_TAB, [], JOY_BUTTON_BACK, [], []],
	["chup_anh", "Chụp ảnh", "thu_bay", KEY_P, [], -1, [], []],
]

## Đổi phím: GameSettings "ban_phim" = {hành động: {"phim": keycode, "nut": joy button}} (chỉ phần khác mặc định).
const KHOA := "ban_phim"

## true khi người chơi vừa bấm tay cầm (false khi vừa bấm bàn phím / chuột).
static var tay_cam := false

static var _so_hanh_dong := -1
static var _toc_do_dat := 1.0  # Engine.time_scale lần cuối đặt cho Tùy chọn hỗ trợ "Tốc độ game"
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_them_nut_menu()
	ap_dung()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	var n := InputMap.get_actions().size()
	if n != _so_hanh_dong:
		ap_dung()  # cảnh vừa khai thêm phím: đặt lại theo phần người chơi đã đổi
	_cap_nhat_toc_do()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		tay_cam = true
	elif event is InputEventKey or event is InputEventMouseButton:
		tay_cam = false


## A bấm nút, B quay lại trong mọi menu (Godot mặc định chỉ có D-pad và cần trái cho ui_*).
static func _them_nut_menu() -> void:
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var co := false
		for e in InputMap.action_get_events(pair[0]):
			co = co or (e is InputEventJoypadButton and e.button_index == pair[1])
		if not co:
			var j := InputEventJoypadButton.new()
			j.button_index = pair[1]
			InputMap.action_add_event(pair[0], j)


# ---------------------------------------------------------------- đọc / đổi

static func dong(action: String) -> Array:
	for d in PHIM:
		if d[0] == action:
			return d
	return []


static func _doi() -> Dictionary:
	var v = GameSettings.get_value(KHOA)
	return v if v is Dictionary else {}


## Phím chính đang dùng của một việc (KEY_NONE nếu không có).
static func phim(action: String) -> int:
	var d := dong(action)
	if d.is_empty():
		return KEY_NONE
	return int(_doi().get(action, {}).get("phim", d[3]))


## Nút tay cầm chính đang dùng (-1 nếu không có).
static func nut(action: String) -> int:
	var d := dong(action)
	if d.is_empty():
		return -1
	return int(_doi().get(action, {}).get("nut", d[5]))


static func _cung_luc(a: String, b: String) -> bool:
	return a == b or a == "chung" or b == "chung" or ([a, b].has("pho") and [a, b].has("thu_bay"))


## Gán phím mới cho một việc. Phím đã là phím chính của việc khác cùng lúc thì hai việc đổi chỗ cho nhau.
## Trả về danh sách việc bị đổi chỗ (để giao diện báo).
static func dat_phim(action: String, keycode: int) -> Array:
	return _dat(action, "phim", keycode, phim(action))


static func dat_nut(action: String, button: int) -> Array:
	return _dat(action, "nut", button, nut(action))


static func _dat(action: String, loai: String, moi: int, cu: int) -> Array:
	var d := dong(action)
	if d.is_empty() or moi == cu:
		return []
	var doi := _doi().duplicate(true)
	var bi_doi := []
	for o in PHIM:
		if o[0] == action or not _cung_luc(d[2], o[2]):
			continue
		var hien := phim(o[0]) if loai == "phim" else nut(o[0])
		if hien == moi:
			_ghi(doi, o, loai, cu)
			bi_doi.append(o[0])
	_ghi(doi, d, loai, moi)
	GameSettings.set_value(KHOA, doi)
	ap_dung()
	return bi_doi


static func _ghi(doi: Dictionary, d: Array, loai: String, gia_tri: int) -> void:
	var mac_dinh: int = d[3] if loai == "phim" else d[5]
	var m: Dictionary = doi.get(d[0], {})
	if gia_tri == mac_dinh:
		m.erase(loai)
	else:
		m[loai] = gia_tri
	if m.is_empty():
		doi.erase(d[0])
	else:
		doi[d[0]] = m


## Về phím mặc định (tất cả).
static func mac_dinh() -> void:
	GameSettings.set_value(KHOA, {})
	ap_dung()


## Đặt lại phím cho mọi hành động đã khai (cảnh nào chưa khai thì để cảnh đó tự khai lúc vào).
static func ap_dung() -> void:
	_so_hanh_dong = InputMap.get_actions().size()
	var chinh := {}  # phím chính của từng việc, để bỏ phím phụ trùng
	for d in PHIM:
		chinh[d[0]] = phim(d[0])
	var pc := not OS.has_feature("web")
	for d in PHIM:
		var action: String = d[0]
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var k := phim(action)
		if k != KEY_NONE:
			_them_phim(action, k)
		var chi_pc := false
		for p in d[4]:
			if p is String:
				if p == "pc":
					chi_pc = true
				elif p == "chuot":
					var mb := InputEventMouseButton.new()
					mb.button_index = MOUSE_BUTTON_LEFT
					InputMap.action_add_event(action, mb)
				continue
			if chi_pc and not pc:
				continue
			var trung := false
			for o in PHIM:
				trung = trung or (o[0] != action and _cung_luc(d[2], o[2]) and chinh[o[0]] == p)
			if not trung and p != k:
				_them_phim(action, p)
		var b := nut(action)
		if b >= 0:
			_them_nut(action, b)
		for p in d[6]:
			if p != b:
				_them_nut(action, p)
		for a in d[7]:
			var e := InputEventJoypadMotion.new()
			e.axis = a[0]
			e.axis_value = a[1]
			InputMap.action_add_event(action, e)


static func _them_phim(action: String, k: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	InputMap.action_add_event(action, e)


static func _them_nut(action: String, b: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	InputMap.action_add_event(action, e)


# ---------------------------------------------------------------- tên phím cho người chơi

static func ten_phim(k: int) -> String:
	if k == KEY_NONE:
		return "—"
	match k:
		KEY_SPACE: return "Space"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_TAB: return "Tab"
		KEY_ESCAPE: return "Esc"
	return OS.get_keycode_string(k)


const TEN_NUT := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start", JOY_BUTTON_GUIDE: "Home",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓",
	JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →",
}


static func ten_nut(b: int) -> String:
	if b < 0:
		return "—"
	return TEN_NUT.get(b, "Nút %d" % b)


## Chữ trên phím in trong bảng "Cách chơi" và dãy gợi ý (UiTheme.keycap): đổi theo phím người chơi đã gán.
## Chữ không phải tên phím thì trả nguyên.
static func chu_phim(text: String) -> String:
	if _doi().is_empty():
		return text
	if text.begins_with("Giữ "):
		var sau := chu_phim(text.trim_prefix("Giữ "))
		return "Giữ " + sau
	if text == "W A S D":
		return " ".join([ten_phim(phim("move_forward")), ten_phim(phim("move_left")),
			ten_phim(phim("move_back")), ten_phim(phim("move_right"))])
	var bep := _dang_o_bep()
	var map := {
		"Space": "jump", "Shift": "sprint", "C": "crouch", "Z": "sneak", "Q": "goi", "B": "ban_do",
		"R": "cuu_ket", "F": "tu_di_pho", "P": "chup_anh",
		"E": "interact" if bep else "deliver", "Tab": "tu_di" if bep else "the_nhiem_vu",
	}
	if map.has(text):
		return ten_phim(phim(map[text]))
	return text


static func _dang_o_bep() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var s := tree.current_scene if tree else null
	return s != null and s.get_script() != null and "kitchen" in str(s.get_script().resource_path)


# ---------------------------------------------------------------- B3: tốc độ game

## Tùy chọn hỗ trợ "Tốc độ game" chỉ áp lúc đang chơi (cảnh có Bơ), menu và phim vẫn chạy đủ nhanh.
## Không đụng khi chỗ khác đang tự đặt time_scale (tua phim ×12).
static func _cap_nhat_toc_do() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var s := tree.current_scene if tree else null
	var muon := 1.0
	if s != null and "player" in s and s.player != null:
		muon = DoKho.toc_do_game()
	if is_equal_approx(Engine.time_scale, muon):
		_toc_do_dat = muon
		return
	if is_equal_approx(Engine.time_scale, 1.0) or is_equal_approx(Engine.time_scale, _toc_do_dat):
		Engine.time_scale = muon
		_toc_do_dat = muon
