class_name AmThanhNgay
## AT2: nhạc nền và tiếng nền riêng của từng ngày.
## Mỗi ngày khai báo trong scripts/ngay/<mã>.gd (const DATA) các khóa, đều không bắt buộc:
##   "music": tên bài (assets/audio/music_<tên>.ogg), mặc định "delivery"
##   "amb":   tên tiếng nền (assets/audio/amb_<tên>.ogg), mặc định "morning"; buổi có mưa (--buoi=pho_mua) thì "mua"
##   "music_<buổi>", "amb_<buổi>": nhạc/tiếng nền khi ngày đổi buổi giữa chừng (vd Chủ Nhật "toi": Hội mèo),
##          script của ngày gọi AmThanhNgay.phat(day, "<buổi>"); thiếu khóa buổi thì dùng khóa chung.
## sound_director.gd (vào PLAY, hết bị rượt), market.gd (ra khỏi chợ), muc_tuan.gd (Bơ ngủ dậy) đọc qua đây,
## nên đổi âm thanh một ngày chỉ sửa file ngày đó. Cảnh không có file ngày (màn dạy chơi) gọi phat_rieng().

const NHAC_MAC_DINH := "delivery"
const NEN_MAC_DINH := "morning"

## Buổi đang chơi của mỗi ngày (đặt bởi phat(day, buoi)), để nhạc trở lại đúng bài sau khi hết rượt.
static var _buoi := {}


## Bài nhạc của ngày `day` (mã ngày, vd PlayMode.day) ở buổi `buoi` ("" = buổi đang chơi).
static func nhac(day: String, buoi := "") -> String:
	var d := Days.data(day)
	var b: String = buoi if buoi != "" else str(_buoi.get(day, ""))
	if b != "" and d.has("music_" + b):
		return str(d["music_" + b])
	return str(d.get("music", NHAC_MAC_DINH))


## Tiếng nền của ngày `day` ở buổi `buoi`.
static func nen(day: String, buoi := "") -> String:
	var d := Days.data(day)
	var b: String = buoi if buoi != "" else str(_buoi.get(day, ""))
	if b != "" and d.has("amb_" + b):
		return str(d["amb_" + b])
	if d.has("amb"):
		return str(d.amb)
	return "mua" if ThoiTiet.dang_mua() else NEN_MAC_DINH


## Phát nhạc + tiếng nền của ngày. Vào lúc chơi gọi phat(day); đổi buổi giữa ngày gọi phat(day, "<buổi>").
static func phat(day: String, buoi := "") -> void:
	_buoi[day] = buoi
	phat_rieng(nhac(day, buoi), nen(day, buoi))


## Cảnh riêng ngoài các ngày (vd màn dạy chơi): đưa thẳng tên bài và tiếng nền.
static func phat_rieng(music: String, amb: String, fade := -1.0) -> void:
	var snd := _sound()
	if snd == null:
		return
	if music != "":
		snd.music(music)
	if amb != "":
		if fade >= 0.0:
			snd.ambience(amb, fade)
		else:
			snd.ambience(amb)


## Autoload Sound qua cây cảnh (chạy test bằng -s không có tên autoload lúc dịch script).
static func _sound() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Sound") if tree else null
