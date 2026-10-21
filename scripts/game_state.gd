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
## Sao bếp của từng ổ (5 phần tử, 0–3), màn bếp ghi. Rỗng = chưa có, dùng kitchen_stars cho mọi ổ.
static var kitchen_stars_per_bread: Array[int] = []
## Ngày đang chơi, dùng làm tên mục trong file lưu.
static var day := "thu_hai"

const SAVE_PATH := "user://luu_game.cfg"
## File kỷ lục cũ, màn hình chính vẫn đọc khóa [ky_luc] sao.
const RECORD_PATH := "user://ky_luc.cfg"
const DAY_NAMES := {"thu_hai": "Thứ Hai", "thu_ba": "Thứ Ba", "thu_tu": "Thứ Tư", "thu_nam": "Thứ Năm",
	"thu_sau": "Thứ Sáu", "thu_bay": "Thứ Bảy", "chu_nhat": "Chủ Nhật"}

## Đường dẫn file lưu đang dùng; tự kiểm tra đổi sang file riêng để không đụng file thật.
static var save_path := SAVE_PATH
static var _save: ConfigFile


## Mở file lưu (một lần), file chưa có thì tạo rỗng.
static func save_file() -> ConfigFile:
	if _save == null:
		_save = ConfigFile.new()
		_save.load(save_path)
	return _save


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
