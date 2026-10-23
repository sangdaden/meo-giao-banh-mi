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
##   mode: "free" (ngày tự do không đơn, Thứ Bảy) | "festival"; favours: việc nhờ của ngày tự do
##   nodes: script node riêng của ngày, main.gd thêm vào cảnh phố (node tự gỡ nếu không phải ngày của nó).
##          Node có thể có: begin() (ngày tự do bắt đầu), resume_day() -> bool (quay về giữa ngày từ cảnh khác).
##   hud: script mảnh giao diện riêng của ngày (Control có biến hud), main.gd gắn vào HUD qua hud.add_piece()
##   help, help_note: dòng riêng của ngày trong bảng "Cách chơi" (menu Esc), ghép sau phím chung bằng
##          scripts/ui/chu_huong_dan.gd (thiếu help thì thêm dòng "E giao bánh")

## Thứ tự các ngày trong tuần
const ORDER := ["thu_hai", "thu_ba", "thu_tu", "thu_nam", "thu_sau", "thu_bay", "chu_nhat"]
## Bản chơi thử: mở sẵn mọi ngày đã làm. false thì ngày sau chỉ mở khi đã chơi xong ngày trước.
const PLAYTEST_UNLOCK_ALL := true

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


## Ngày đã làm xong phần chơi (có đơn, hoặc ngày tự do không đơn như Thứ Bảy).
static func playable(id: String) -> bool:
	return not data(id).get("orders", []).is_empty() or is_free(id)


## Ngày tự do: không đơn giao, không đồng hồ (Thứ Bảy dạo phố, scripts/thu_bay.gd).
static func is_free(id: String) -> bool:
	return data(id).get("mode", "") == "free"


## Việc nhờ của ngày tự do (Sổ hàng xóm), rỗng nếu ngày đó không có.
static func favours(id: String) -> Array:
	return data(id).get("favours", [])


## Ngày chơi được và đã mở: bản chơi thử mở hết; không thì phải chơi hết ngày trước ít nhất một lần.
static func unlocked(id: String) -> bool:
	if not playable(id):
		return false
	var i := ORDER.find(id)
	if PLAYTEST_UNLOCK_ALL or i <= 0:
		return true
	return int(GameState.get_day("so_lan_choi", 0, ORDER[i - 1])) > 0


## Ngày kế tiếp trong tuần ("" nếu là Chủ Nhật).
static func next_day(id: String) -> String:
	var i := ORDER.find(id)
	return ORDER[i + 1] if i >= 0 and i + 1 < ORDER.size() else ""


static func note_name(note: String) -> String:
	return NOTE_NAMES.get(note, note)
