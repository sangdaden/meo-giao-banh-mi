class_name PlayMode
## Người chơi chọn chơi gì ở màn Chọn màn (scripts/ui/level_select.gd).
## Biến static giữ nguyên khi đổi scene, giống GameState.
## Mặc định là cả ca, nên chạy thẳng main.tscn hay --autotest vẫn như cũ.

enum Mode { FULL, KITCHEN, DELIVERY, ORDER }

const MENU_SCENE := "res://scenes/menu.tscn"
const KITCHEN_SCENE := "res://scenes/kitchen.tscn"
const DELIVERY_SCENE := "res://scenes/main.tscn"

## FULL: bếp rồi giao 5 đơn · KITCHEN: chỉ bếp · DELIVERY: chỉ giao 5 đơn · ORDER: giao một đơn
static var mode := Mode.FULL
## Đơn được chọn khi mode = ORDER (0–4).
static var order := 0
## true khi từ màn chơi về màn hình chính: mở lại màn Chọn màn.
static var back_to_select := false


## Bắt đầu chơi theo lựa chọn. Xóa điểm bếp cũ để chế độ không có bếp không được cộng giây.
static func start(tree: SceneTree, m: Mode, which := 0) -> void:
	mode = m
	order = which
	GameState.from_kitchen = false
	GameState.kitchen_bonus = 0.0
	GameState.kitchen_stars = 0
	GameState.kitchen_stars_per_bread.clear()
	var scene := DELIVERY_SCENE
	if m in [Mode.FULL, Mode.KITCHEN] and ResourceLoader.exists(KITCHEN_SCENE):
		scene = KITCHEN_SCENE
	tree.paused = false
	tree.change_scene_to_file(scene)


## Về màn hình chính và mở lại màn Chọn màn.
static func back_to_menu(tree: SceneTree) -> void:
	back_to_select = true
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
