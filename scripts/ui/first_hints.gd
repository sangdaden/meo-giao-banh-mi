class_name FirstHints
extends Node
## Mẹo lần đầu chơi Thứ Hai: lần đầu gặp gầm thấp, lần đầu tới gần Chó Mực, lần đầu tới nhà khách.
## Mỗi mẹo chỉ hiện một lần (lưu ở GameSettings "tips_seen"); tắt hẳn ở Cài đặt > Mẹo lần đầu chơi.
## main.gd chỉ cần add_child(FirstHints.new()); node tự đọc player, dog, hud, customer_zones của main.

const DOG_NEAR := 9.0  # m: tới gần Chó Mực đang ngủ chừng này thì nhắc rón rén

var main: Node
var _seen := PackedStringArray()
var _off := false


func _ready() -> void:
	main = get_parent()
	_off = not GameSettings.get_value("tips") or "--autotest" in OS.get_cmdline_user_args()
	_seen = PackedStringArray(str(GameSettings.get_value("tips_seen")).split(",", false))


func _process(_delta: float) -> void:
	if _off or main == null or main.get("state") != 1 or main.player == null or main.hud == null:  # State.PLAY
		return
	var p: CharacterBody3D = main.player
	if not has_seen("gam") and p.stance == "crouch" and not _key("crouch"):
		_show("gam", "Gầm thấp", "Bơ tự cúi người chui qua gầm. Muốn chui sẵn thì giữ phím chui, thả ra là đứng dậy.",
			[[_label("crouch", "C"), "giữ để chui"]])
	elif not has_seen("muc") and main.dog and p.global_position.distance_to(main.dog.global_position) < DOG_NEAR \
			and int(main.dog.get("state")) == 0:  # dog.gd State.SLEEP
		_show("muc", "Chó Mực đang ngủ", "Chạy nhanh hay va đồ là Mực thức dậy đuổi theo. Rón rén thì bước êm, đi ngang được.",
			[[_label("sneak", "Z"), "giữ để rón rén"], ["Shift", "đừng chạy nhanh"]])
	elif not has_seen("khach") and p.carrying and main.order_index < main.customer_zones.size() \
			and main.customer_zones[main.order_index].overlaps_body(p):
		_show("khach", "Tới nhà khách rồi", "Bấm phím giao để Bơ trao bánh. Bánh còn nóng và giao kịp giờ thì được nhiều sao.",
			[[_label("deliver", "E"), "giao bánh"]])


func has_seen(id: String) -> bool:
	return id in _seen


func _show(id: String, title: String, body: String, keys: Array) -> void:
	_seen.append(id)
	GameSettings.set_value("tips_seen", ",".join(_seen))
	main.hud.show_tip(title, body, keys, 7.0)


func _key(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


## Có tay cầm thì ghi kèm nút tay cầm (B chui, L3 rón rén, Y giao).
func _label(action: String, key: String) -> String:
	if Input.get_connected_joypads().is_empty():
		return key
	return key + " / " + {"crouch": "B", "sneak": "L3", "deliver": "Y"}.get(action, "")
