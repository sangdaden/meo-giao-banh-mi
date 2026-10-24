class_name TrangWeb
extends RefCounted
## Bản web: báo cho trang (web/update-check.js) game đang ở đâu, để dải "Có bản mới" chỉ hiện lúc an toàn (PH1).
## Trang đọc window.meoGame = {trang_thai, lang}:
##   "menu"     màn hình chính
##   "ket_ngay" bảng kết quả cuối ca / cuối ngày / kết tuần
##   "choi"     còn lại (đang trong một ngày, đang tải): trang không báo, không tải lại, không tải trước file mới.
## Gọi bao(trang_thai, node): khi node rời cây thì tự về "choi". Bản PC không làm gì.


static func bao(trang_thai: String, node: Node = null) -> void:
	if not OS.has_feature("web"):
		return
	_ghi(trang_thai)
	if node and trang_thai != "choi":
		node.tree_exiting.connect(func(): _ghi("choi"), CONNECT_ONE_SHOT)


## Đổi ngôn ngữ (NgonNgu.dat gọi) để dải báo đổi chữ theo.
static func bao_ngon_ngu(ma: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(window.meoGame=window.meoGame||{}).lang=%s;window.meoGameDoi&&window.meoGameDoi();" % JSON.stringify(ma), true)


static func _ghi(trang_thai: String) -> void:
	var lang := "vi"
	var tree := Engine.get_main_loop() as SceneTree
	var nn: Node = tree.root.get_node_or_null("/root/NgonNgu") if tree else null
	if nn:
		lang = str(nn.get("ma"))
	JavaScriptBridge.eval("window.meoGame={trang_thai:%s,lang:%s};window.meoGameDoi&&window.meoGameDoi();"
		% [JSON.stringify(trang_thai), JSON.stringify(lang)], true)
