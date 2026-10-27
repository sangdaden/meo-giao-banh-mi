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


## Đếm một sự kiện (web/do-luot.js gửi Umami, Vũ Trụ Mark K1). Bản PC không làm gì.
static func dem(ten: String, du_lieu := {}) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.meoDo&&window.meoDo(%s,%s);" % [JSON.stringify(ten), JSON.stringify(du_lieu)], true)


static func _ghi(trang_thai: String) -> void:
	if trang_thai == "ket_ngay":
		dem("meo-ket-ngay", {"ngay": PlayMode.day})
	var lang := "vi"
	var tree := Engine.get_main_loop() as SceneTree
	var nn: Node = tree.root.get_node_or_null("/root/NgonNgu") if tree else null
	if nn:
		lang = str(nn.get("ma"))
	JavaScriptBridge.eval("window.meoGame={trang_thai:%s,lang:%s};window.meoGameDoi&&window.meoGameDoi();"
		% [JSON.stringify(trang_thai), JSON.stringify(lang)], true)


## Nhịp tim cho "người gác" của trang (web/update-check.js): mỗi giây báo trang game còn chạy và đang ở cảnh nào.
## Trang không nghe nhịp quá lâu (tab đang mở) thì hiện bảng "Game không phản hồi" có nút Tải lại thay vì để đứng đen.
static func bat_nhip(tree: SceneTree) -> void:
	if not OS.has_feature("web") or tree.root.has_node("TrangWebNhip"):
		return
	var t := Timer.new()
	t.name = "TrangWebNhip"
	t.wait_time = 1.0
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	t.timeout.connect(func():
		var canh := tree.current_scene.scene_file_path.get_file().get_basename() if tree.current_scene else ""
		JavaScriptBridge.eval("window.meoNhip&&window.meoNhip(%s);" % JSON.stringify(canh), true))
	tree.root.add_child.call_deferred(t)
	t.autostart = true
