extends Node
## Nhật ký chơi thử (P3, P4; autoload tên "NhatKy", khai báo trong project.godot).
##
## P4: mỗi lần mở game ghi một file user://logs/choi_thu_<ngày>_<giờ>.txt: máy, cài đặt, đổi màn, đơn bắt đầu/giao xong,
## chỗ lúng túng; lúc tắt game chép các dòng lỗi của Godot (user://logs/godot.log, bản desktop tự ghi) vào cuối file.
## Mọi file nằm chung thư mục user://logs với godot.log, Cài đặt > "Mở thư mục nhật ký" mở thẳng thư mục đó
## (bản web không mở được thư mục nên nút là "Tải nhật ký", tải file của lần chơi này về máy).
##
## P3: Bơ được điều khiển (player.can_move) mà loanh quanh trong một vùng nhỏ quá 8 giây là một "chỗ lúng túng":
##   dung_yen: cả 8 giây không ra khỏi vòng 1 m;  di_vong: đi được hơn 6 m mà vẫn không ra khỏi vòng 3,5 m.
## Mỗi chỗ ghi một dòng vào user://logs/ket_<ngày>_<giờ>.csv (khi Bơ đi khỏi chỗ đó, kèm tổng số giây và số lần bấm phím).
## Gộp các file csv của nhiều người lên ảnh bản đồ: tools/heatmap_ket.gd.
## Tạm dừng (menu Esc) không tính giờ vì node này dừng theo cây.
##
## Tắt khi chạy test / autotest (cờ --autotest*, chạy -s), trừ khi có cờ --nhat-ky.

const DIR := "user://logs"
const CUA_SO := 8.0        ## giây đứng loanh quanh thì tính là lúng túng
const BK_DUNG := 1.0       ## bán kính "đứng yên"
const BK_VONG := 3.5       ## bán kính "đi vòng"
const QUANG_VONG := 6.0    ## quãng đi tối thiểu trong 8 giây để gọi là đi vòng
const BK_RA := 4.0         ## đi xa tâm chỗ lúng túng hơn mức này là đã thoát
const MAU := 0.25          ## giây giữa hai lần lấy mẫu vị trí
const GIU_FILE := 30       ## giữ bao nhiêu lần chơi gần nhất (mỗi lần 1 txt + 1 csv)
const CSV_DAU := "ma_lan,gio,man,ngay,don,loai,x,y,z,giay,phim"

var bat := false
var ma_lan := ""           ## mã lần chơi = ngày giờ mở game, cũng là đuôi tên file
var duong_txt := ""
var duong_csv := ""
var so_ket := 0            ## số chỗ lúng túng đã ghi trong lần chơi này

var _txt: FileAccess
var _csv: FileAccess
var _t0 := 0
var _scene: Node
var _man := ""
var _don := -1
var _mau: Array = []       # [thời điểm, Vector3] trong 8 giây gần nhất
var _t := 0.0
var _hen := 0.0
var _bam: Array[float] = []  # thời điểm các lần bấm phím / chuột / tay cầm trong 8 giây gần nhất
var _ket := {}             # chỗ lúng túng đang diễn ra: loai, tam, bat_dau, phim


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var test := OS.get_cmdline_args().has("-s") or OS.get_cmdline_args().has("--script")
	for a in args:
		if a.begins_with("--autotest"):
			test = true
	if test and not args.has("--nhat-ky"):
		bat = false
		set_process(false)
		set_process_input(false)
		return
	bat_dau()


## Mở file nhật ký mới cho lần chơi này (test gọi thẳng để bật nhật ký khi chạy -s).
func bat_dau() -> void:
	bat = true
	set_process(true)
	set_process_input(true)
	_t0 = Time.get_ticks_msec()
	ma_lan = Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")
	DirAccess.make_dir_recursive_absolute(DIR)
	_don_dep()
	duong_txt = "%s/choi_thu_%s.txt" % [DIR, ma_lan]
	duong_csv = "%s/ket_%s.csv" % [DIR, ma_lan]
	_txt = FileAccess.open(duong_txt, FileAccess.WRITE)
	_csv = FileAccess.open(duong_csv, FileAccess.WRITE)
	if _csv:
		_csv.store_line(CSV_DAU)
		_csv.flush()
	ghi("Mèo Giao Bánh Mì, nhật ký chơi thử %s" % ma_lan)
	ghi("Godot %s · %s · %s · %s" % [Engine.get_version_info().string, OS.get_name(), OS.get_model_name(),
		RenderingServer.get_video_adapter_name()])
	ghi("Màn hình %s · ngôn ngữ %s · thử thách %s · mẹo %s" % [DisplayServer.screen_get_size(),
		GameSettings.get_value("ngon_ngu"), GameSettings.get_value("thu_thach"), GameSettings.get_value("tips")])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		ket_thuc()


## Ghi một dòng (kèm phút:giây từ lúc mở game) vào nhật ký.
func ghi(dong: String) -> void:
	if _txt == null:
		return
	var s := (Time.get_ticks_msec() - _t0) / 1000
	_txt.store_line("[%02d:%02d] %s" % [s / 60, s % 60, dong])
	_txt.flush()


## Đóng game: ghi chỗ lúng túng còn dở, chép lỗi của Godot vào cuối nhật ký.
func ket_thuc() -> void:
	if _txt == null:
		return
	_dong_ket()
	ghi("Tắt game. %d chỗ lúng túng." % so_ket)
	var loi := loi_godot()
	if loi.is_empty():
		ghi("Không thấy lỗi nào trong godot.log.")
	else:
		ghi("%d loại lỗi / cảnh báo trong godot.log:" % loi.size())
		for d in loi:
			_txt.store_line("    " + d)
	_txt.flush()
	_txt = null
	_csv = null


## Các lỗi / cảnh báo của lần chạy này trong user://logs/godot.log (chỉ bản desktop có file này),
## lỗi giống nhau gộp một dòng kèm số lần, mỗi lỗi kèm dòng "at:" chỉ chỗ trong code.
static func loi_godot(gioi_han := 60) -> PackedStringArray:
	var out := PackedStringArray()
	var f := FileAccess.open(DIR + "/godot.log", FileAccess.READ)
	if f == null:
		return out
	var dem := {}  # lỗi (kèm dòng at) -> số lần, giữ thứ tự gặp đầu tiên
	var truoc := ""
	while not f.eof_reached():
		var d := f.get_line()
		var la_loi := false
		for dau in ["ERROR", "SCRIPT ERROR", "WARNING", "USER ERROR", "USER SCRIPT ERROR", "USER WARNING"]:
			if d.begins_with(dau + ":"):
				la_loi = true
		if la_loi:
			if truoc != "":
				dem[truoc] = dem.get(truoc, 0) + 1
			truoc = d
		elif truoc != "" and d.strip_edges().begins_with("at:"):
			dem[truoc + " | " + d.strip_edges()] = dem.get(truoc + " | " + d.strip_edges(), 0) + 1
			truoc = ""
	if truoc != "":
		dem[truoc] = dem.get(truoc, 0) + 1
	for k in dem:
		if out.size() >= gioi_han:
			out.append("... còn %d loại lỗi nữa, xem godot.log" % (dem.size() - gioi_han))
			break
		out.append(("%d × " % dem[k] if dem[k] > 1 else "") + k)
	return out


## Mở thư mục nhật ký (desktop) hoặc tải file nhật ký của lần chơi này (web). Trả về false nếu không làm được.
func mo_thu_muc() -> bool:
	if _txt:
		_txt.flush()
	if OS.has_feature("web"):
		var f := FileAccess.open(duong_txt, FileAccess.READ)
		if f == null:
			return false
		var noi_dung := f.get_as_text()
		var csv := FileAccess.open(duong_csv, FileAccess.READ)
		if csv:
			noi_dung += "\n\n# " + duong_csv.get_file() + "\n" + csv.get_as_text()
		JavaScriptBridge.download_buffer(noi_dung.to_utf8_buffer(), duong_txt.get_file(), "text/plain")
		return true
	DirAccess.make_dir_recursive_absolute(DIR)
	return OS.shell_open(ProjectSettings.globalize_path(DIR)) == OK


func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventJoypadButton):
		if _ket.is_empty():
			_bam.append(_t)
			while _bam.size() > 0 and _t - _bam[0] > CUA_SO:
				_bam.pop_front()
		else:
			_ket.phim += 1


func _process(delta: float) -> void:
	_t += delta
	var sc := get_tree().current_scene
	if sc != _scene:
		_doi_man(sc)
	if _scene == null:
		return
	if "order_index" in _scene and int(_scene.order_index) != _don:
		_don = int(_scene.order_index)
		ghi("Đơn %d bắt đầu" % (_don + 1))
	if _t < _hen:
		return
	_hen = _t + MAU
	var p = _scene.get("player") if "player" in _scene else null
	if not (p is Node3D) or not is_instance_valid(p) or not p.is_inside_tree() or not p.get("can_move"):
		_mau.clear()
		_dong_ket()
		return
	lay_mau(_t, (p as Node3D).global_position)


## Một mẫu vị trí (test gọi thẳng hàm này để khỏi chờ thật).
func lay_mau(t: float, pos: Vector3) -> void:
	if not _ket.is_empty():
		var tam: Vector3 = _ket.tam
		if Vector2(pos.x - tam.x, pos.z - tam.z).length() > BK_RA:
			_dong_ket()
		else:
			_ket.cuoi = t
			return
	_mau.append([t, pos])
	while _mau.size() > 1 and t - _mau[1][0] >= CUA_SO:
		_mau.pop_front()
	if t - _mau[0][0] < CUA_SO:
		return
	var tam := Vector3.ZERO
	for m in _mau:
		tam += m[1]
	tam /= _mau.size()
	var r := 0.0
	var quang := 0.0
	var y_thap := INF
	var y_cao := -INF
	for i in _mau.size():
		var q: Vector3 = _mau[i][1]
		r = maxf(r, Vector2(q.x - tam.x, q.z - tam.z).length())
		y_thap = minf(y_thap, q.y)
		y_cao = maxf(y_cao, q.y)
		if i > 0:
			var q0: Vector3 = _mau[i - 1][1]
			quang += Vector2(q.x - q0.x, q.z - q0.z).length()
	var loai := ""
	if y_cao - y_thap > 1.5:
		pass  # đang leo lên / xuống (ống nước, ban công): không phải lúng túng
	elif r <= BK_DUNG:
		loai = "dung_yen"
	elif r <= BK_VONG and quang >= QUANG_VONG and _man != "kitchen":
		loai = "di_vong"  # bếp chỉ 5 × 3,4 m, đi qua đi lại là chuyện thường
	if loai == "":
		return
	var t0: float = _mau[0][0]
	_ket = {"loai": loai, "tam": tam, "bat_dau": t0, "cuoi": t, "phim": _bam.filter(func(b): return b >= t0).size()}
	_bam.clear()
	_mau.clear()


func _dong_ket() -> void:
	if _ket.is_empty():
		return
	var k := _ket
	_ket = {}
	var giay: float = k.cuoi - k.bat_dau
	var tam: Vector3 = k.tam
	so_ket += 1
	var s := (Time.get_ticks_msec() - _t0) / 1000
	if _csv:
		_csv.store_line("%s,%02d:%02d,%s,%s,%d,%s,%.1f,%.1f,%.1f,%.0f,%d" % [ma_lan, s / 60, s % 60, _man,
			PlayMode.day, _don + 1, k.loai, tam.x, tam.y, tam.z, giay, k.phim])
		_csv.flush()
	ghi("Lúng túng (%s) %.0f giây ở (%.1f, %.1f, %.1f), đơn %d, bấm %d phím" % [k.loai, giay, tam.x, tam.y, tam.z,
		_don + 1, k.phim])


func _doi_man(sc: Node) -> void:
	_dong_ket()
	_mau.clear()
	_scene = sc
	_don = -1
	_man = sc.scene_file_path.get_file().get_basename() if sc else ""
	if _man == "main":
		_man = "pho"
	if sc:
		ghi("Vào màn %s (ngày %s)" % [_man, PlayMode.day])
		if sc.has_signal("order_delivered"):
			sc.order_delivered.connect(func(i: int, _o): ghi("Đơn %d giao xong" % (i + 1)))


## Chỉ giữ GIU_FILE lần chơi gần nhất.
func _don_dep() -> void:
	var lan := {}  # mã lần chơi -> các file của lần đó
	for f in DirAccess.get_files_at(DIR):
		var ma := ""
		if f.begins_with("choi_thu_"):
			ma = f.trim_prefix("choi_thu_").get_basename()
		elif f.begins_with("ket_"):
			ma = f.trim_prefix("ket_").get_basename()
		if ma != "":
			lan[ma] = lan.get(ma, []) + [f]
	var ma_cu: Array = lan.keys()
	ma_cu.sort()
	for i in ma_cu.size() - (GIU_FILE - 1):
		for f in lan[ma_cu[i]]:
			DirAccess.remove_absolute(DIR + "/" + f)
