class_name Days
## Danh sách ngày trong tuần và hàm đọc dữ liệu ngày. Dữ liệu mỗi ngày nằm ở file riêng scripts/ngay/<mã ngày>.gd
## (const DATA), nên thêm hay sửa một ngày KHÔNG sửa file này: tạo hoặc sửa scripts/ngay/<mã>.gd là xong.
## main.gd đọc ngày đang chơi qua Days.get_day(PlayMode.day); màn Chọn màn đọc để hiện danh sách đơn.
## Mã ngày trùng tên mục trong file lưu (GameState.DAY_NAMES): "thu_hai", "thu_ba", ...
## Ngày ngoài tuần (vd. màn dạy chơi) chỉ cần file scripts/ngay/<mã>.gd rồi PlayMode.day = "<mã>".
## Theo trang thiết kế màn chơi (Sang duyệt 21/10/2026) và gói việc Thứ Ba (thiet-ke-man/goi-viec-thu-ba.md).
##
## Khóa của một đơn:
##   who, place, item, pos (chỗ khách), time (giây sau khi nhận), color (màu áo, màu thẻ)
##   delivery: cách giao trong deliveries.gd (hand | basket | counter | under_car | chair; ngày sau thêm
##             on_seat, beside_tea... chưa có thì deliveries.gd dựng người đứng chìa tay, bấm E đưa bánh)
##   side_quest: id nhiệm vụ phụ (tên hiển thị ở Scoring.SIDE_QUEST_NAMES)
##   boss: true nếu Chó Mực thức canh hẻm trong đơn này
##   kind: "deliver" (mặc định: nhận ở lò, giao cho khách) | "errand" (đơn ngược: tới chỗ khách lấy đồ, mang về lò)
##   note: ghi chú món trên phiếu: "" | "khong_ot" | "them_pate" | "nhieu_do_chua"
##   errand_item: món phải mang về khi kind = "errand" ("trung6" = túi 6 trứng)
##   quick_assemble: true thì giao xong đơn này (còn đơn sau) sang bếp ráp nhanh rồi quay lại (túi trứng Thứ Ba)
##   basket_period: giây một lượt giỏ Bé Na đưa qua lại (deliveries.gd, mặc định của Thứ Hai)
##   gio, gio_group, dog_start: đơn giỗ Thứ Sáu (scripts/thu_sau.gd)
##   delivery shelf | shutter | loft | scene, errand_item "da": Thứ Năm (scripts/thu_nam.gd)
## Khóa của một ngày:
##   title, blurb, intro, time_mult, extras, orders; orders_hard (nếu có) thay cho orders ở Chế độ thử thách
##   moi: một câu "ngày này có gì mới", màn kết ngày trước nhắc (GC5, scripts/ui/nhac_ket_ngay.gd)
##   mode: "free" (ngày tự do không đơn, Thứ Bảy) | "festival"; favours: việc nhờ của ngày tự do
##   nodes: script node riêng của ngày, main.gd thêm vào cảnh phố (node tự gỡ nếu không phải ngày của nó).
##          Node có thể có: begin() (ngày tự do bắt đầu), resume_day() -> bool (quay về giữa ngày từ cảnh khác).
##   hud: script mảnh giao diện riêng của ngày (Control có biến hud), main.gd gắn vào HUD qua hud.add_piece()
##   help, help_note: dòng riêng của ngày trong bảng "Cách chơi" (menu Esc), ghép sau phím chung bằng
##          scripts/ui/chu_huong_dan.gd (thiếu help thì thêm dòng "E giao bánh")

## Thứ tự các ngày trong tuần
const ORDER := ["thu_hai", "thu_ba", "thu_tu", "thu_nam", "thu_sau", "thu_bay", "chu_nhat"]
## GC1: bản phát hành mở ngày theo thứ tự (ngày sau mở khi đã chơi xong ngày trước ít nhất một lần).
## Người chơi thử bật Cài đặt > "Mở hết các ngày" (GameSettings "mo_het_ngay") hoặc chạy với cờ -- --mo-het-ngay.
const PLAYTEST_UNLOCK_ALL := false
## W2: bản demo chỉ có các ngày này (cộng màn dạy chơi). Bật bằng ProjectSettings "meo/ban_demo"
## (tools/web/xuat_web.sh với BAN_DEMO=co), tính năng xuất "demo", hoặc cờ -- --demo.
const DEMO_DAYS := ["thu_hai", "thu_ba"]

## Tên hiển thị của ghi chú món
const NOTE_NAMES := {"khong_ot": "không ớt", "them_pate": "thêm pate", "nhieu_do_chua": "nhiều đồ chua"}

## Dữ liệu các ngày trong tuần đã có file, theo thứ tự ORDER (chi_tiet_pho.gd, nguoi_qua_duong.gd duyệt qua).
## Ngày ngoài tuần được nạp thêm vào đây lần đầu get_day() gọi tới.
static var DATA: Dictionary = _load_week()


static func file_of(id: String) -> String:
	return "res://scripts/ngay/%s.gd" % id


static func _load_week() -> Dictionary:
	var all := {}
	for id: String in ORDER:
		var d := _read(id)
		if not d.is_empty():
			all[id] = d
	return all


static func _read(id: String) -> Dictionary:
	var path := file_of(id)
	if id == "" or not ResourceLoader.exists(path):
		return {}
	var s: Script = load(path)
	return s.get_script_constant_map().get("DATA", {}) if s else {}


## Dữ liệu gốc của một ngày (rỗng nếu không có file).
static func data(id: String) -> Dictionary:
	if not DATA.has(id):
		var d := _read(id)
		if d.is_empty():
			return {}
		DATA[id] = d
	return DATA[id]



## Dữ liệu một ngày: {id, name, title, blurb, intro, time_mult, extras, orders, nodes, hud, help, help_note}.
## Ngày chưa làm có orders rỗng; mã không có file thì trả Thứ Hai.
static func get_day(id: String) -> Dictionary:
	var d := data(id)
	var known := not d.is_empty()
	if not known:
		d = data("thu_hai")
	return {
		"id": id if known else "thu_hai",
		"name": GameState.DAY_NAMES.get(id, id),
		"title": d.get("title", ""),
		"blurb": d.get("blurb", ""),
		"intro": d.get("intro", ""),
		"time_mult": float(d.get("time_mult", 1.0)),
		"extras": d.get("extras", {}),
		"orders": d.get("orders_hard", d.get("orders", [])) if DoKho.hard() else d.get("orders", []),
		"nodes": d.get("nodes", []),
		"hud": d.get("hud", []),
		"help": d.get("help", []),
		"help_note": d.get("help_note", ""),
	}


## Script node riêng của mọi ngày trong tuần cộng ngày đang chơi, theo thứ tự ORDER, không trùng.
## main.gd thêm hết vào cảnh phố như trước khi tách file; node nào không phải ngày của nó thì tự gỡ
## (giữ được các cờ thử như -- --cho bật chợ ở ngày khác).
static func all_nodes(current: String) -> Array:
	var out := []
	for id: String in ORDER + [current]:
		for path: String in data(id).get("nodes", []):
			if not path in out:
				out.append(path)
	return out


static func orders(id: String) -> Array:
	return get_day(id).orders


## Ngày đã làm xong phần chơi (có đơn, hoặc ngày tự do không đơn như Thứ Bảy). Bản demo: chỉ DEMO_DAYS.
static func playable(id: String) -> bool:
	if demo() and not id in DEMO_DAYS and id in ORDER:
		return false
	return not data(id).get("orders", []).is_empty() or is_free(id)


## Bản demo Thứ Hai + Thứ Ba (W2).
static func demo() -> bool:
	return bool(ProjectSettings.get_setting("meo/ban_demo", false)) or OS.has_feature("demo") \
		or "--demo" in OS.get_cmdline_user_args()


## Ngày có trong bản đầy đủ nhưng bản demo khóa lại.
static func full_only(id: String) -> bool:
	return demo() and id in ORDER and not id in DEMO_DAYS


## Người chơi thử: mở hết các ngày đã làm (Cài đặt hoặc cờ -- --mo-het-ngay).
static func unlock_all() -> bool:
	return PLAYTEST_UNLOCK_ALL or bool(GameSettings.get_value("mo_het_ngay")) \
		or "--mo-het-ngay" in OS.get_cmdline_user_args()


## Ngày tự do: không đơn giao, không đồng hồ (Thứ Bảy dạo phố, scripts/thu_bay.gd).
static func is_free(id: String) -> bool:
	return data(id).get("mode", "") == "free"


## Việc nhờ của ngày tự do (Sổ hàng xóm), rỗng nếu ngày đó không có.
static func favours(id: String) -> Array:
	return data(id).get("favours", [])


## Ngày chơi được và đã mở: Thứ Hai luôn mở; ngày sau mở khi ngày chơi được liền trước đã chơi xong một lần
## (cả ca hoặc chỉ giao). "Mở hết các ngày" thì mở mọi ngày đã làm. Ngày ngoài tuần luôn mở.
static func unlocked(id: String) -> bool:
	if not playable(id):
		return false
	var i := ORDER.find(id)
	if i <= 0 or unlock_all():
		return true
	var prev := previous_playable(id)
	return prev == "" or int(GameState.get_day("so_lan_choi", 0, prev)) > 0


## Ngày chơi được liền trước id trong tuần ("" nếu không có), bỏ qua ngày chưa làm.
static func previous_playable(id: String) -> String:
	var i := ORDER.find(id)
	for j in range(i - 1, -1, -1):
		if playable(ORDER[j]):
			return ORDER[j]
	return ""


## Ngày kế tiếp trong tuần ("" nếu là Chủ Nhật).
static func next_day(id: String) -> String:
	var i := ORDER.find(id)
	return ORDER[i + 1] if i >= 0 and i + 1 < ORDER.size() else ""


static func note_name(note: String) -> String:
	return NOTE_NAMES.get(note, note)
