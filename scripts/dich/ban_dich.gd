extends Translation
## Bản dịch tiếng Anh cho cả game (F3). Chữ gốc trong code vẫn là tiếng Việt; bảng ở scripts/dich/en_*.gd
## ghi "chữ Việt": "chữ Anh". Label, Button, RichTextLabel, Label3D, tooltip tự dịch qua bảng này khi
## ngôn ngữ là "en", nên phần lớn code không cần gọi tr().
##
## Ngoài câu khớp nguyên văn, bảng nhận "mẫu" có %s / %d / %.1f... (như "Còn %d giây"): chữ đã ghép xong
## ("Còn 12 giây") khớp mẫu thì dịch theo mẫu tiếng Anh, phần %s lại được dịch tiếp (tên món, tên người).
## Không khớp gì thì thử tách theo dòng, " · " và ", " rồi dịch từng mảnh.
##
## Thêm chữ mới: thêm một dòng vào bảng en_*.gd của nhóm mình (cuối nhóm). Chạy
## tests/test_ngon_ngu.gd để xem còn câu tiếng Việt nào chưa dịch.

const BANG := [
	preload("res://scripts/dich/en_giao_dien.gd"),
	preload("res://scripts/dich/en_choi.gd"),
	preload("res://scripts/dich/en_bep.gd"),
	preload("res://scripts/dich/en_ngay.gd"),
	preload("res://scripts/dich/en_hoi_meo.gd"),
]

## Chữ có dấu tiếng Việt: dùng để dò câu chưa dịch.
const _DAU := "àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ"
const _TACH := ["\n", " · ", ", ", " | "]

var _exact := {}
var _thuong := {}  # khóa viết thường -> chữ Anh, cho tên món bị .to_lower() trước khi ghép câu
var _mau := []  # mỗi mục: [RegEx, mẫu Anh, các loại chỗ trống]
var _cache := {}
var _dau := {}
var _ten := {}  # từ có dấu được phép nằm trong câu Anh: tên người, món (Bơ, Cô Ba, bánh mì...)
## Bật khi test: ghi lại câu tiếng Việt chưa có trong bảng.
var ghi_thieu := false
var thieu := {}


func _init() -> void:
	locale = "en"
	for c in _DAU:
		_dau[c] = true
		_dau[c.to_upper()] = true
	for bang in BANG:
		for k in bang.EN:
			nap(k, bang.EN[k])
	for en in _exact.values():
		for w in _tu(en):
			_ten[w] = true
	# Mẫu dài (nhiều chữ cố định) thử trước, để "Lấy %s rồi" thắng "%s rồi".
	_mau.sort_custom(func(a, b): return a[3] > b[3])


func nap(vi: String, en: String) -> void:
	var gon := vi.strip_edges()
	if gon != vi and gon != "" and not _exact.has(gon):
		nap(gon, en.strip_edges())
	if not _co_cho_trong(vi):
		_exact[vi] = en
		if not _thuong.has(vi.to_lower()):
			_thuong[vi.to_lower()] = en
		return
	var re := RegEx.new()
	var pat := "^"
	var kinds := []
	var lit := 0
	var i := 0
	while i < vi.length():
		var c := vi[i]
		if c == "%":
			var m := _SPEC.search(vi, i)
			if m and m.get_start() == i:
				var t := m.get_string(1)
				if t == "%":
					pat += "%"
				else:
					kinds.append(t)
					pat += "(.+?)" if t == "s" else ("(-?[0-9]+)" if t == "d" else "(-?[0-9]+(?:[.,][0-9]+)?)")
				i = m.get_end()
				continue
		pat += _esc(c)
		lit += 1
		i += 1
	re.compile(pat + "$")
	# "%s%s" liền nhau không tách được: chỉ giữ khớp nguyên văn, thêm mẫu riêng cho từng biến thể.
	if re.is_valid() and pat.find(")(") == -1:
		_mau.append([re, en, kinds, lit])
	_exact[vi] = en


static var _SPEC := _spec_re()


static func _spec_re() -> RegEx:
	var r := RegEx.new()
	r.compile("%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?([sdfi%])")
	return r


static func _co_cho_trong(s: String) -> bool:
	for m in _SPEC.search_all(s):
		if m.get_string(1) != "%":
			return true
	return false


static func _esc(c: String) -> String:
	return "\\" + c if c in "\\^$.|?*+()[]{}/" else c


func _get_message(src: StringName, _context: StringName) -> StringName:
	var s := String(src)
	if s == "":
		return &""
	if _cache.has(s):
		return _cache[s]
	var out := dich(s, 0)
	if _cache.size() > 6000:
		_cache.clear()
	_cache[s] = StringName(out)
	if ghi_thieu and not xong(out):
		thieu[s] = out
	return _cache[s]


## Dịch một chuỗi; trả lại nguyên chuỗi khi không có trong bảng.
func dich(s: String, sau: int) -> String:
	if _exact.has(s):
		return _exact[s]
	if sau > 4:
		return s
	var gon := s.strip_edges()
	if gon != s and gon != "":
		var i := s.find(gon)
		var d := dich(gon, sau + 1)
		if d != gon:
			return s.substr(0, i) + d + s.substr(i + gon.length())
	var th: String = _thuong.get(s.to_lower(), "")
	if th != "":
		# "nơ bướm" (đã .to_lower()) -> "bow tie"
		return th[0].to_lower() + th.substr(1) if s[0] == s[0].to_lower() else th
	# Mẫu: lấy mẫu đầu tiên dịch trọn câu; không mẫu nào trọn thì lấy mẫu khớp đầu tiên.
	var tam := ""
	for m in _mau:
		var r: RegExMatch = m[0].search(s)
		if r == null:
			continue
		var args := []
		for k in m[2].size():
			var a := r.get_string(k + 1)
			args.append(dich(a, sau + 1) if m[2][k] == "s" else a)
		var o := _dien(m[1], args)
		if xong(o):
			return o
		if tam == "":
			tam = o
	# Câu ghép: dịch từng dòng / từng mảnh
	for sep in _TACH:
		if s.find(sep) != -1:
			var parts := s.split(sep)
			var doi := false
			for i in parts.size():
				var p := parts[i]
				var lead := p.length() - p.lstrip(" ").length()
				var core := p.strip_edges()
				var d := dich(core, sau + 1) if core != "" else core
				if d != core:
					parts[i] = p.substr(0, lead) + d + p.substr(lead + core.length())
					doi = true
			if doi:
				var o: String = sep.join(parts)
				if xong(o) or tam == "":
					return o
	return tam if tam != "" else s


## Điền đối số vào mẫu tiếng Anh. Mẫu có thể dùng {0}, {1} để đổi thứ tự; không thì %s/%d theo thứ tự.
static func _dien(en: String, args: Array) -> String:
	if en.find("{0}") != -1:
		var o := en
		for i in args.size():
			o = o.replace("{%d}" % i, args[i])
		return o
	var out := ""
	var i := 0
	var k := 0
	while i < en.length():
		if en[i] == "%":
			var m := _SPEC.search(en, i)
			if m and m.get_start() == i:
				var t := m.get_string(1)
				out += "%" if t == "%" else (str(args[k]) if k < args.size() else "")
				if t != "%":
					k += 1
				i = m.get_end()
				continue
		out += en[i]
		i += 1
	return out


## Câu đã dịch trọn: không còn từ có dấu nào ngoài tên riêng có trong bảng.
func xong(s: String) -> bool:
	if not co_dau(s):
		return true
	for w in _tu(s):
		if not _ten.has(w):
			return false
	return true


## Các từ có dấu trong câu.
func _tu(s: String) -> Array:
	var out := []
	for w in _TU.search_all(s):
		var t := w.get_string()
		if co_dau(t):
			out.append(t)
	return out


static var _TU := _tu_re()


static func _tu_re() -> RegEx:
	var r := RegEx.new()
	r.compile("[\\p{L}]+")
	return r


func co_dau(s: String) -> bool:
	for c in s:
		if _dau.has(c):
			return true
	return false
