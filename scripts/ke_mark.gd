class_name KeMark
extends RefCounted
## Cửa từ game sang kênh Mark học AI (Vũ Trụ Mark K2, Sang chọn đợt 1 ngày 26/10/2026).
## Mark và Bơ chung một khu phố: Mark ở chung cư tầng 3, sáng nào cũng mua bánh mì ở lò Cô Ba.
## Link gắn utm để Umami của markhocai.com đếm được người từ game sang (K1); bản web của game đếm thêm
## sự kiện "meo-sang-kenh" (web/do-luot.js).

const URL := "https://markhocai.com/"
## Người chơi chọn English: kênh video là tiếng Việt, nên dẫn sang Mark Ở Vũ Trụ Khác bản tiếng Anh (Vũ Trụ Mark D4, 30/10/2026)
const URL_EN := "https://markhocai.com/en/vu-tru-khac.html"
## Chữ đặt cạnh nút, giống nhau ở màn hình chính và màn hết tuần
const LOI := "Anh Mark ở chung cư tầng 3 làm video về AI, ghé xem nha!"
const NUT := "  Ghé kênh anh Mark"


## Địa chỉ có gắn nguồn. cho: chỗ bấm trong game ("menu", "het_tuan"); en: đang chơi bằng tiếng Anh.
static func link(cho: String, en := la_en()) -> String:
	return "%s?utm_source=meo-giao-banh-mi&utm_medium=game&utm_content=%s" % [URL_EN if en else URL, cho.uri_encode()]


static func la_en() -> bool:
	var cay := Engine.get_main_loop() as SceneTree
	var ngon_ngu: Node = cay.root.get_node_or_null("/root/NgonNgu") if cay else null
	return ngon_ngu != null and ngon_ngu.ma == "en"


## Mở trang trong trình duyệt (bản web mở tab mới, bản máy tính mở trình duyệt mặc định).
static func mo(cho: String) -> void:
	TrangWeb.dem("meo-sang-kenh", {"cho": cho})
	OS.shell_open(link(cho))
