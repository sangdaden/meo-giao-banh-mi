class_name GoiWeb
extends Node
## Q1 "Gói nhẹ bản web": bản web chỉ tải index.pck (trang chủ, màn dạy chơi, bếp, Thứ Hai và đồ dùng chung);
## đồ riêng của từng ngày và tủ đồ mèo nằm trong gói goi/<tên>.pck cạnh index.html, tải khi cần.
##
## - PlayMode gọi GoiWeb.go(tree, cảnh, GoiWeb.for_day(ngày)) thay cho change_scene_to_file: thiếu gói thì hiện
##   màn chờ "Đang mang đồ ra phố…" cho tới khi tải xong rồi mới đổi cảnh. Vào ngày rồi thì tải nốt các gói
##   còn lại ở nền (PREFETCH_DELAY giây sau), nên chuyển ngày sau thường không phải chờ.
## - Gói tải về được giữ trong user://goi/ (bản web: IndexedDB của trình duyệt), lần sau mở game khỏi tải lại.
##   Tên file có md5 của gói nên bản mới hơn tự tải gói mới.
## - Danh sách gói (tên file, cỡ, md5) là res://goi_web.json, do tools/goi_web/tach_goi.py thêm vào index.pck
##   lúc CI xuất bản web. Bản desktop không có file này: mọi hàm ở đây chạy thẳng như chưa có gói.
## - Chia đồ vào gói: tools/goi_web/lap_goi.py (ghi tools/goi_web/goi.json). Đồ mới chưa có trong goi.json thì
##   nằm trong index.pck, không cần làm gì thêm.
## Thử: godot --headless --path . -s tests/test_goi_web.gd

const MANIFEST := "res://goi_web.json"
const DIR := "user://goi/"
const PREFETCH_DELAY := 20.0
## Ngày có nhiều mèo đủ giống (mèo Thứ Bảy, Hội mèo): cần cả tủ đồ
const TU_DO_DAYS := ["thu_bay", "chu_nhat"]

signal pack_loaded(pack: String)

static var _manifest = null
static var _done := {}
static var _node: GoiWeb

var _queue: Array[String] = []
var _http: HTTPRequest
var _current := ""
var _waits: Array = []  # [gói cần, callable, màn chờ]
var _failed := {}


## Danh sách gói của bản đang chạy ({} khi không có gói, như bản desktop).
static func manifest() -> Dictionary:
	if _manifest == null:
		_manifest = {}
		if FileAccess.file_exists(MANIFEST):
			var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
			if data is Dictionary:
				_manifest = data
	return _manifest


## Gói này có trong bản đang chạy mà chưa nạp.
static func pending(pack: String) -> bool:
	return manifest().has(pack) and not _done.has(pack)


static func loaded(pack: String) -> bool:
	return not pending(pack)


## Các gói còn thiếu để chơi ngày `day`.
static func for_day(day: String) -> Array[String]:
	var out: Array[String] = []
	if pending(day):
		out.append(day)
	if pending("tu_do") and (day in TU_DO_DAYS or wears_skin()):
		out.append("tu_do")
	return out


## Bơ đang mặc giống khác hay là mèo cái (model trong gói tủ đồ).
static func wears_skin() -> bool:
	return Outfit.breed() != "bo" or Outfit.sex() == "cai"


## Đổi sang cảnh `scene` sau khi có đủ các gói `packs` (thiếu thì hiện màn chờ).
static func go(tree: SceneTree, scene: String, packs: Array[String]) -> void:
	var change := func():
		tree.change_scene_to_file(scene)
		if not manifest().is_empty():
			node()._prefetch_later()
	if packs.is_empty():
		change.call()
	else:
		node().wait(packs, change)


## Gọi `done` khi đã có đủ các gói `packs` (thiếu thì hiện màn chờ).
static func then(packs: Array[String], done: Callable) -> void:
	if packs.all(func(p: String) -> bool: return loaded(p)):
		done.call()
	else:
		node().wait(packs, done)


## Tải ở nền, không màn chờ (vd. tủ đồ khi Bơ đang mặc giống khác, lúc ở trang chủ).
static func fetch(pack: String) -> void:
	if pending(pack):
		node()._enqueue(pack, false)


static func node() -> GoiWeb:
	if not is_instance_valid(_node):
		_node = GoiWeb.new()
		_node.name = "GoiWeb"
		_node.process_mode = Node.PROCESS_MODE_ALWAYS
		(Engine.get_main_loop() as SceneTree).root.add_child(_node)
	return _node


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = false
	_http.request_completed.connect(_on_completed)
	add_child(_http)
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean_old()


## Chờ các gói `packs` rồi gọi `done`; hiện màn chờ trong lúc tải.
func wait(packs: Array[String], done: Callable) -> void:
	var screen := ManChoTai.new()
	screen.packs = packs
	screen.retry.connect(func():
		for p in packs:
			_failed.erase(p)
			_enqueue(p, true))
	get_tree().root.add_child(screen)
	_waits.append([packs, done, screen])
	for i in range(packs.size() - 1, -1, -1):
		_enqueue(packs[i], true)
	_check_waits()


func _enqueue(pack: String, front: bool) -> void:
	if not pending(pack) or pack == _current:
		return
	_queue.erase(pack)
	if front:
		_queue.push_front(pack)
	else:
		_queue.append(pack)
	if _current == "":
		_next.call_deferred()


func _prefetch_later() -> void:
	get_tree().create_timer(PREFETCH_DELAY, true).timeout.connect(func():
		for p: String in manifest():
			if not _failed.has(p):
				_enqueue(p, false))


func _next() -> void:
	if _current != "":
		return
	while not _queue.is_empty() and not pending(_queue[0]):
		_queue.pop_front()
	if _queue.is_empty():
		return
	_current = _queue.pop_front()
	var path := _local(_current)
	if FileAccess.file_exists(path) and _size(path) == int(manifest()[_current].size):
		_mount(path)
		return
	_http.download_file = path + ".tai"
	var err := _http.request(_url(_current))
	if err != OK:
		_fail()


func _on_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var path := _local(_current)
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and _size(path + ".tai") == int(manifest()[_current].size):
		DirAccess.remove_absolute(path)
		DirAccess.rename_absolute(path + ".tai", path)
		_mount(path)
	else:
		push_warning("GoiWeb: tải gói %s lỗi (result %d, HTTP %d)" % [_current, result, code])
		DirAccess.remove_absolute(path + ".tai")
		_fail()


func _mount(path: String) -> void:
	var pack := _current
	_current = ""
	if ProjectSettings.load_resource_pack(path, false):
		_done[pack] = true
		pack_loaded.emit(pack)
	else:
		push_warning("GoiWeb: không nạp được " + path)
		DirAccess.remove_absolute(path)
		_failed[pack] = true
		_show_error(pack)
	_check_waits()
	_next()


func _fail() -> void:
	_failed[_current] = true
	_show_error(_current)
	_current = ""
	_next()


func _show_error(pack: String) -> void:
	for w in _waits:
		if pack in w[0] and is_instance_valid(w[2]):
			(w[2] as ManChoTai).show_error()


func _check_waits() -> void:
	for w in _waits.duplicate():
		if not is_instance_valid(w[2]) or (w[2] as Node).is_queued_for_deletion():
			_waits.erase(w)  # màn chờ đã đóng (bấm Về trang chủ): thôi đổi cảnh
			continue
		if (w[0] as Array).all(func(p: String) -> bool: return loaded(p)):
			_waits.erase(w)
			(w[2] as Node).queue_free()
			(w[1] as Callable).call()


func _process(_delta: float) -> void:
	if _current == "" or _waits.is_empty():
		return
	for w in _waits:
		if _current in w[0] and is_instance_valid(w[2]):
			(w[2] as ManChoTai).set_progress(_current, _http.get_downloaded_bytes(), int(manifest()[_current].size))


## Đang tải gói nào, được bao nhiêu byte (màn chờ đọc).
func progress_of(pack: String) -> int:
	if loaded(pack):
		return int(manifest().get(pack, {}).get("size", 0))
	return _http.get_downloaded_bytes() if pack == _current else 0


static func _local(pack: String) -> String:
	return DIR + "%s-%s.pck" % [pack, str(manifest()[pack].md5).left(12)]


static func _size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else -1


## Địa chỉ gói: cạnh index.html, thêm md5 để trình duyệt không dùng bản cũ trong bộ nhớ đệm.
static func _url(pack: String) -> String:
	var base := "http://127.0.0.1:8060/"
	if OS.has_feature("web"):
		base = str(JavaScriptBridge.eval("location.href.split(/[?#]/)[0].replace(/[^\\/]*$/, '')"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--goi-web="):  # thử trên máy: -- --goi-web=http://127.0.0.1:8060/
			base = arg.trim_prefix("--goi-web=")
	return base + str(manifest()[pack].file) + "?h=" + str(manifest()[pack].md5)


## Bỏ gói của bản cũ (tên khác với gói hiện tại) cho nhẹ bộ nhớ trình duyệt.
func _clean_old() -> void:
	if manifest().is_empty():
		return
	var keep := {}
	for p: String in manifest():
		keep[_local(p).get_file()] = true
	for f in DirAccess.get_files_at(DIR):
		if not keep.has(f):
			DirAccess.remove_absolute(DIR + f)
