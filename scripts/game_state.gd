class_name GameState
## Dữ liệu dùng chung giữa các màn (biến static giữ nguyên khi đổi scene).
## Màn bếp ghi điểm vào đây, màn giao bánh đọc ra.
## Phần cuối file là lưu game: một file user://luu_game.cfg, mỗi ngày trong tuần một mục.
## user:// chạy được cả bản máy tính lẫn bản web (bản web lưu vào IndexedDB của trình duyệt).

## true khi vừa chơi xong màn bếp: màn giao bánh bỏ qua màn hình bắt đầu.
static var from_kitchen := false
## Số giây cộng thêm vào đồng hồ mỗi đơn giao (0–6), tính từ điểm màn bếp.
## Cách cũ, giờ chỉ dùng khi màn bếp chưa ghi sao từng ổ (xem Scoring.bonus_seconds).
static var kitchen_bonus := 0.0
## Số sao màn bếp (0–3), mỗi sao 2 giây.
static var kitchen_stars := 0
## Số đơn giao mỗi ngày (bằng số phần tử kitchen_stars_per_bread khi màn bếp đã ghi).
const ORDERS_PER_DAY := 5
## Sao bếp của từng ổ (5 phần tử, 0–3), màn bếp ghi. Rỗng = chưa có, dùng kitchen_stars cho mọi ổ.
static var kitchen_stars_per_bread: Array[int] = []
## Ngày đang chơi, dùng làm tên mục trong file lưu.
static var day := "thu_hai"
## Phiếu ghi món của từng đơn trong ngày ("" | "khong_ot" | "them_pate" | "nhieu_do_chua", như Days)
## và ổ của đơn đó ráp đúng phiếu chưa. Màn bếp điền lúc vào bếp và ghi kết quả sau khi ráp.
static var bread_notes: Array[String] = []
static var bread_note_ok: Array[bool] = []
## Ráp nhanh: số thứ tự đơn (0–4) cần một ổ trứng ráp gấp, -1 = không. main.gd đặt rồi chuyển sang
## màn bếp; bếp mở thẳng cận cảnh bàn ráp, ghi sao ổ đó, đặt lại -1, bật from_quick_assemble rồi về phố.
static var quick_assemble_request := -1
static var from_quick_assemble := false
## Số trứng còn nguyên Bơ mang về từ tạp hóa (luồng Tạp hóa ghi). ≤ 3 quả thì ổ trứng tối đa 1 sao bếp.
static var eggs_brought := 6

const SAVE_PATH := "user://luu_game.cfg"
## File kỷ lục cũ, màn hình chính vẫn đọc khóa [ky_luc] sao.
const RECORD_PATH := "user://ky_luc.cfg"
const DAY_NAMES := {"thu_hai": "Thứ Hai", "thu_ba": "Thứ Ba", "thu_tu": "Thứ Tư", "thu_nam": "Thứ Năm",
	"thu_sau": "Thứ Sáu", "thu_bay": "Thứ Bảy", "chu_nhat": "Chủ Nhật"}

## Đường dẫn file lưu đang dùng; tự kiểm tra đổi sang file riêng để không đụng file thật.
static var save_path := SAVE_PATH
static var _save: ConfigFile
## true khi file lưu do bản game mới hơn ghi (vd. bản web còn đệm bản cũ): giữ nguyên mọi khóa, không chuyển đổi.
static var save_from_newer := false

# ---------------------------------------------------------------- phiên bản file lưu (Q2)
## Số phiên bản file lưu, ghi ở [luu_game] phien_ban. File của bản trước Q2 không có mục này = phiên bản 0.
## LUẬT (CLAUDE.md): thêm, đổi tên hay đổi kiểu một khóa lưu thì
##   1. thêm/sửa khóa trong SAVE_KEYS (ghi phiên bản thêm vào),
##   2. tăng SAVE_VERSION và thêm một hàm _len_v<N>() vào cuối danh sách bước bên dưới (bước rỗng cũng được),
##   3. chạy `godot --headless --path . -s tests/test_luu_game.gd -- --ghi-mau` TRƯỚC khi tăng số
##      để giữ một file mẫu của phiên bản cũ trong tests/luu_game_cu/.
const SAVE_VERSION := 1
const VERSION_SECTION := "luu_game"
const VERSION_KEY := "phien_ban"
## Mọi khóa trong file lưu: tên → [kiểu, "chung" hay "ngay", phiên bản thêm vào].
## Khóa sai kiểu (file hỏng, sửa tay) bị bỏ khi mở, game dùng giá trị mặc định như lúc chưa có.
const SAVE_KEYS := {
	# [chung]: ví, hồ sơ, tủ đồ, mạch tuần
	"vi_tien_boa": [TYPE_INT, "chung", 0],
	"tong_sao": [TYPE_INT, "chung", 0],
	"don_kip": [TYPE_INT, "chung", 0],
	"kip_ca_5": [TYPE_INT, "chung", 0],
	"da_mua": [TYPE_ARRAY, "chung", 0],
	"de_danh": [TYPE_ARRAY, "chung", 0],
	"tiem_da_mua": [TYPE_ARRAY, "chung", 0],
	"tiem_dang_bay": [TYPE_ARRAY, "chung", 0],
	"ngay_tiep": [TYPE_STRING, "chung", 0],
	"tuan": [TYPE_INT, "chung", 0],
	"tuan_moi": [TYPE_BOOL, "chung", 0],
	"da_tap": [TYPE_BOOL, "chung", 0],
	"da_xem_mo_dau": [TYPE_BOOL, "chung", 0],
	"ban_bon_chan": [TYPE_ARRAY, "chung", 0],
	"muc_quen": [TYPE_ARRAY, "chung", 0],
	"ngu_trua_muc": [TYPE_INT, "chung", 0],
	# [<mã ngày>]: điểm, kỷ lục, đồ nhặt của từng ngày
	"tem": [TYPE_ARRAY, "ngay", 0],
	"sao_cao_nhat": [TYPE_INT, "ngay", 0],
	"boa_cao_nhat": [TYPE_INT, "ngay", 0],
	"hang_cao_nhat": [TYPE_STRING, "ngay", 0],
	"so_lan_choi": [TYPE_INT, "ngay", 0],
	"ky_luc_don": [TYPE_ARRAY, "ngay", 0],
	"sao_don": [TYPE_ARRAY, "ngay", 0],
	"bong_mo": [TYPE_DICTIONARY, "ngay", 0],
	"huy_hieu": [TYPE_ARRAY, "ngay", 0],
	"sao_bep": [TYPE_INT, "ngay", 0],
	"banh_mi_bo": [TYPE_ARRAY, "ngay", 0],
	"so_trang": [TYPE_ARRAY, "ngay", 0],
	"muc_ban": [TYPE_BOOL, "ngay", 0],
	"anh_trang": [TYPE_DICTIONARY, "ngay", 0],
	"thu_moi": [TYPE_BOOL, "ngay", 0],
	"huy_chuong": [TYPE_ARRAY, "ngay", 0],
	"ky_luc": [TYPE_DICTIONARY, "ngay", 0],
	"bo_cau_non": [TYPE_BOOL, "ngay", 0],
	"ga_ve_bu": [TYPE_BOOL, "ngay", 0],
}


## Mở file lưu (một lần), file chưa có thì tạo rỗng. File cũ được chuyển lên phiên bản hiện tại
## (giữ bản sao <file>.v<N>.bak); file hỏng không đọc được thì cất thành <file>.hong rồi bắt đầu file mới.
static func save_file() -> ConfigFile:
	if _save == null:
		_save = ConfigFile.new()
		save_from_newer = false
		var err := _save.load(save_path)
		if err == OK:
			_upgrade(_save)
		else:
			if err != ERR_FILE_NOT_FOUND and FileAccess.file_exists(save_path):
				push_warning("File lưu hỏng (%s), cất thành %s.hong" % [error_string(err), save_path])
				DirAccess.copy_absolute(save_path, save_path + ".hong")
			_save = ConfigFile.new()
			_save.set_value(VERSION_SECTION, VERSION_KEY, SAVE_VERSION)
	return _save


## Phiên bản ghi trong file (0 = file của bản trước khi có số phiên bản).
static func version_of(cf: ConfigFile) -> int:
	return int(cf.get_value(VERSION_SECTION, VERSION_KEY, 0))


## Đưa file `cf` (đã đọc từ save_path) lên SAVE_VERSION. Trả về phiên bản cũ.
static func _upgrade(cf: ConfigFile) -> int:
	var v := version_of(cf)
	if v > SAVE_VERSION:
		save_from_newer = true
		push_warning("File lưu phiên bản %d mới hơn bản game (%d): giữ nguyên, không chuyển đổi" % [v, SAVE_VERSION])
		return v
	if v < SAVE_VERSION:
		DirAccess.copy_absolute(save_path, "%s.v%d.bak" % [save_path, v])
		migrate(cf)
		var err := cf.save(save_path)
		if err != OK:
			push_warning("Không ghi được file lưu sau khi chuyển đổi: %s" % error_string(err))
	else:
		_clean(cf)
	return v


## Chạy các bước chuyển đổi từ phiên bản trong file lên SAVE_VERSION (không đọc/ghi đĩa; test gọi thẳng).
static func migrate(cf: ConfigFile) -> void:
	var v := version_of(cf)
	while v < SAVE_VERSION:
		match v:
			0: _len_v1(cf)
		v += 1
		cf.set_value(VERSION_SECTION, VERSION_KEY, v)
	_clean(cf)


## Bỏ khóa đã đăng ký mà sai kiểu (game sẽ dùng mặc định). Khóa lạ thì giữ nguyên.
static func _clean(cf: ConfigFile) -> void:
	if save_from_newer:
		return
	for sec in cf.get_sections():
		if sec == VERSION_SECTION:
			continue
		var scope := "chung" if sec == "chung" else "ngay"
		for key in cf.get_section_keys(sec):
			var spec: Array = SAVE_KEYS.get(key, [])
			if spec.is_empty() or spec[1] != scope:
				continue
			var val: Variant = cf.get_value(sec, key)
			var want: int = spec[0]
			if typeof(val) == want:
				continue
			if want == TYPE_INT and typeof(val) == TYPE_FLOAT:
				cf.set_value(sec, key, int(val))
				continue
			push_warning("File lưu: bỏ [%s] %s sai kiểu (%s)" % [sec, key, type_string(typeof(val))])
			cf.erase_section_key(sec, key)


# Các bước chuyển đổi, mỗi phiên bản một hàm; thêm ở cuối.

## 0 → 1: bắt đầu đánh số. Ai đã dán trang Mực trong Sổ hàng xóm (Thứ Bảy) trước khi có trang
## "Bạn bốn chân" thì ghi Mực vào danh sách bạn (trước đây ConVat.met_ids bù lúc đọc).
static func _len_v1(cf: ConfigFile) -> void:
	if bool(cf.get_value("thu_bay", "muc_ban", false)):
		var list: Variant = cf.get_value("chung", "ban_bon_chan", [])
		if list is Array and not "muc" in list:
			cf.set_value("chung", "ban_bon_chan", (list as Array) + ["muc"])


static func get_day(key: String, default: Variant = null, which := "") -> Variant:
	return save_file().get_value(which if which != "" else day, key, default)


static func set_day(key: String, value: Variant, which := "") -> void:
	save_file().set_value(which if which != "" else day, key, value)


## Dữ liệu chung cả game (ví), không theo ngày.
static func get_global(key: String, default: Variant = null) -> Variant:
	return save_file().get_value("chung", key, default)


static func set_global(key: String, value: Variant) -> void:
	save_file().set_value("chung", key, value)


static func write_save() -> void:
	var err := save_file().save(save_path)
	if err != OK:
		push_warning("Không lưu được game: %s" % error_string(err))


## Ghi kỷ lục tổng sao vào file cũ để màn hình chính hiện.
static func write_star_record(total: int) -> void:
	var cf := ConfigFile.new()
	cf.load(RECORD_PATH)
	if total > int(cf.get_value("ky_luc", "sao", -1)):
		cf.set_value("ky_luc", "sao", total)
		cf.save(RECORD_PATH)


## Tổng số tem đã nhặt qua mọi ngày (35 tem mở nón đầu bếp vàng).
static func stamps_all() -> int:
	var n := 0
	for d in DAY_NAMES:
		n += (get_day("tem", [], d) as Array).size()
	return n


## Chỉ dùng khi tự kiểm tra: chuyển sang file lưu riêng và xóa trắng nó.
static func use_test_save(path: String) -> void:
	save_path = path
	DirAccess.remove_absolute(path)
	_save = ConfigFile.new()
	_save.set_value(VERSION_SECTION, VERSION_KEY, SAVE_VERSION)
	save_from_newer = false
