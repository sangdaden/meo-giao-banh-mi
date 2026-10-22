class_name PlayMode
## Người chơi chơi gì: cả tuần liền mạch (nút Bắt đầu), hoặc một ngày, một phần, một đơn chọn ở màn
## Chọn màn (scripts/ui/level_select.gd, nút Chọn màn hay Esc ở trang chủ).
## Biến static giữ nguyên khi đổi scene, giống GameState.
## Mặc định là cả ca, nên chạy thẳng main.tscn hay --autotest vẫn như cũ.
##
## Chơi liền các ngày (Sang 22/10/2026): hồ sơ lưu ngày kế tiếp ("ngay_tiep") và số tuần ("tuan") trong mục
## "chung". Xong ngày nào (Scoring.end_day gọi day_done) thì ngày kế tiếp được lưu ngay; bảng tổng kết có nút
## "Sang Thứ ..." gọi go_next_day. Hết Chủ Nhật thì sang Tuần mới, lại từ Thứ Hai. Ngày chưa làm thì bỏ qua.

enum Mode { FULL, KITCHEN, DELIVERY, ORDER }

const MENU_SCENE := "res://scenes/menu.tscn"
const KITCHEN_SCENE := "res://scenes/kitchen.tscn"
const DELIVERY_SCENE := "res://scenes/main.tscn"
const CHUNG_CU_SCENE := "res://scenes/chung_cu.tscn"   ## Thứ Năm: leo chung cư (cảnh riêng, chơi thử từ màn Chọn màn)

## FULL: bếp rồi giao 5 đơn · KITCHEN: chỉ bếp · DELIVERY: chỉ giao 5 đơn · ORDER: giao một đơn
static var mode := Mode.FULL
## Ngày đang chơi, mã như Days.ORDER ("thu_hai", "thu_ba"...).
static var day := "thu_hai"
## Đơn được chọn khi mode = ORDER (0–4).
static var order := 0
## true khi từ màn chơi về màn hình chính: mở lại màn Chọn màn.
static var back_to_select := false
## true khi đang chơi cả ngày trong mạch tuần: xong ngày thì sang ngày kế. Chế độ tập (chỉ bếp, chỉ giao, một đơn) là false.
static var continuous := false
## Tuần của ngày đang chơi, để chơi lại Chủ Nhật không cộng tuần hai lần.
static var week_playing := 1


## Ngày sẽ chơi khi bấm Bắt đầu: ngày kế tiếp trong hồ sơ, ngày chưa làm thì nhảy tới ngày làm rồi kế đó.
static func current_day() -> String:
	var id := str(GameState.get_global("ngay_tiep", Days.ORDER[0]))
	if not Days.ORDER.has(id):
		id = Days.ORDER[0]
	return id if Days.playable(id) else _playable_from(id)[0]


static func week() -> int:
	return int(GameState.get_global("tuan", 1))


## Ngày chơi được đầu tiên tính từ ngày id (gồm id), vòng sang tuần sau nếu cần: [ngày, có sang tuần mới không].
static func _playable_from(id: String) -> Array:
	var i := maxi(Days.ORDER.find(id), 0)
	for k in Days.ORDER.size():
		var j := i + k
		var d: String = Days.ORDER[j % Days.ORDER.size()]
		if Days.playable(d):
			return [d, j >= Days.ORDER.size()]
	return [Days.ORDER[0], false]


## Ngày chơi sau ngày id: [ngày, có sang tuần mới không]. Chủ Nhật (hay ngày cuối đã làm) thì sang Thứ Hai tuần sau.
static func next_of(id: String) -> Array:
	var i := Days.ORDER.find(id)
	if i < 0 or i + 1 >= Days.ORDER.size():
		return [_playable_from(Days.ORDER[0])[0], true]
	return _playable_from(Days.ORDER[i + 1])


## Bắt đầu (trang chủ): chơi tiếp ngày đang dở trong hồ sơ.
static func play_week(tree: SceneTree) -> void:
	start_day(tree, current_day())


## Chơi mới (trang chủ): ngày đang chơi về Thứ Hai tuần 1. Kỷ lục, ví, tủ đồ giữ nguyên.
static func new_game(tree: SceneTree) -> void:
	reset_week()
	start_day(tree, current_day())


## Phần lưu của Chơi mới: chỉ đưa ngày và tuần về đầu.
static func reset_week() -> void:
	GameState.set_global("tuan", 1)
	GameState.set_global("ngay_tiep", _playable_from(Days.ORDER[0])[0])
	GameState.write_save()


## Chơi cả một ngày trong mạch tuần: ngày có bếp thì vào bếp, ngày tự do (Thứ Bảy) vào thẳng phố.
static func start_day(tree: SceneTree, id: String) -> void:
	GameState.set_global("ngay_tiep", id)
	GameState.write_save()
	week_playing = week()
	start(tree, Mode.DELIVERY if Days.is_free(id) else Mode.FULL, 0, id)
	continuous = true


## Xong cả ngày id: lưu ngày kế tiếp vào hồ sơ (bấm Bắt đầu lần sau là vào ngày đó). Chế độ tập thì không đổi.
static func day_done(id: String) -> void:
	if not continuous:
		return
	var n := next_of(id)
	GameState.set_global("ngay_tiep", n[0])
	if n[1]:
		GameState.set_global("tuan", week_playing + 1)
	GameState.write_save()


## Nút ở bảng tổng kết: "Sang Thứ Ba", hết tuần thì "Sang Tuần mới".
static func next_label() -> String:
	var n := next_of(GameState.day)
	return "Sang Tuần mới" if n[1] else "Sang " + str(GameState.DAY_NAMES.get(n[0], n[0]))


## Bấm nút ở bảng tổng kết: chơi ngày kế tiếp.
static func go_next_day(tree: SceneTree) -> void:
	day_done(GameState.day)  # phòng khi màn đó chưa gọi
	start_day(tree, current_day())


## Bắt đầu chơi theo lựa chọn. Xóa điểm bếp cũ để chế độ không có bếp không được cộng giây.
static func start(tree: SceneTree, m: Mode, which := 0, which_day := "") -> void:
	if which_day != "":
		day = which_day
	GameState.day = day  # màn bếp ghi sao_bep vào mục của ngày này
	mode = m
	order = which
	continuous = false  # start_day bật lại sau khi gọi start
	GameState.from_kitchen = false
	GameState.kitchen_bonus = 0.0
	GameState.kitchen_stars = 0
	GameState.kitchen_stars_per_bread.clear()
	var scene := DELIVERY_SCENE
	if m in [Mode.FULL, Mode.KITCHEN] and ResourceLoader.exists(KITCHEN_SCENE):
		scene = KITCHEN_SCENE
	tree.paused = false
	tree.change_scene_to_file(scene)


## Chơi thử cảnh leo chung cư của Thứ Năm (một đơn cho Bé Na, không có bếp).
static func start_chung_cu(tree: SceneTree) -> void:
	continuous = false
	GameState.day = "thu_nam"  # kỷ lục ghi vào mục Thứ Năm
	mode = Mode.ORDER
	order = 0
	GameState.from_kitchen = false
	tree.paused = false
	tree.change_scene_to_file(CHUNG_CU_SCENE)


## Về màn hình chính và mở lại màn Chọn màn.
static func back_to_menu(tree: SceneTree) -> void:
	back_to_select = true
	tree.paused = false
	tree.change_scene_to_file(MENU_SCENE)


## Về thẳng trang chủ (menu Esc > Về trang chủ), không mở màn Chọn màn.
static func go_home(tree: SceneTree) -> void:
	back_to_select = false
	tree.paused = false
	tree.change_scene_to_file(MENU_SCENE)


## Chơi xong bếp có đi giao tiếp không (chế độ "chỉ bếp" thì không).
static func kitchen_only() -> bool:
	return mode == Mode.KITCHEN


## Chỉ số đơn đầu và đơn cuối được chơi trong màn giao.
static func first_order() -> int:
	return order if mode == Mode.ORDER else 0


static func last_order(count: int) -> int:
	return order if mode == Mode.ORDER else count - 1


## Chơi một đơn lẻ: không tính vào kỷ lục cả ngày.
static func single_order() -> bool:
	return mode == Mode.ORDER
