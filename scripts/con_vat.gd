class_name ConVat
extends Node
## Cơ chế chung con vật (gói "Tương tác với con vật" T1 + T2, kế hoạch tuong-tac-con-vat/KE-HOACH.md).
##
## Hợp đồng cho mọi luồng con vật:
##   - Con vật muốn đáp phím Q: vào nhóm "con_vat" và có func on_called(pos: Vector3) -> void.
##     Có biến goi_r (mét) thì dùng bán kính riêng, không thì DoKho "goi_con_vat_r".
##   - Phím Q (action "goi", Q hoặc LB) chạy ở mọi ngày ngoài phố: Bơ ngồi kêu meo (player.sit_call()),
##     player.called(pos) tới đây, ConVat gọi on_called(pos) cho con vật trong tầm.
##   - ConVat.meet(id): đánh dấu đã chơi với con vật `id` lần đầu (gọi nhiều lần không sao). Lưu mảng toàn cục
##     "ban_bon_chan" trong hồ sơ; trang "Bạn bốn chân" trong Sổ hàng xóm đọc ConVat.met(id).
##   - Đủ hết ALL thì tặng phụ kiện QUA (vòng cổ lục lạc xương cá, model chờ phác thảo; chưa có model vẫn ghi
##     vào tủ đồ như quà Sổ hàng xóm).
## Nối vào cảnh phố: ConVat.setup(player, main) (một dòng trong main.gd).

const GROUP := "con_vat"
const SAVE_KEY := "ban_bon_chan"
const ACTION := "goi"
## Phụ kiện thưởng khi gặp đủ (luồng "Phác thảo động tác và phụ kiện thưởng" làm model)
const QUA := "vongluclac"
const QUA_TEN := "Vòng cổ lục lạc xương cá"

## Bạn bốn chân theo thứ tự trang sổ: id -> [tên, chỗ gặp (gợi ý khi chưa gặp)]. Con mới thêm ở cuối.
const ALL := {
	"muc": ["Chó Mực", "Cuối hẻm 42"],
	"bot": ["Bột", "Mèo khoai môn nhà bên lò bánh"],
	"bo_cau": ["Đàn bồ câu", "Trên mái, ngày mưa"],
	"mit": ["Mít", "Mèo xiêm hay leo mái"],
	"mun": ["Mun", "Mèo đen giỏi trốn"],
	"gung": ["Gừng", "Mèo vàng hăng hái"],
	"tuyet": ["Tuyết", "Mèo trắng điệu đà"],
	"sua": ["Sữa", "Mèo hiền, chậm"],
	"lac": ["Lạc", "Mèo vui tính, nhảy kém"],
	"ba_muop": ["Bà Mướp", "Hội mèo Chủ Nhật"],
	"chao_mao": ["Chào mào", "Góc cờ Ông Bảy"],
	"buom": ["Bướm, chuồn chuồn", "Công viên khối 4"],
	"thach_sung": ["Thạch sùng", "Tường chung cư"],
	"ga": ["Đàn gà con", "Chợ sáng"],
	"ca": ["Cá vàng", "Thau cá chợ, bể cá Cà phê Mây"],
	"vit": ["Đàn vịt", "Phố ngập ngày mưa"],
	"chuot_ti": ["Chuột Tí", "Bếp Cô Ba"],
}

static var _inst: ConVat

var player: Node3D
var main: Node


## Gắn phím Q và nối player.called tới các con vật. main: cảnh phố (có state, hud), có thể null (test).
static func setup(p: Node3D, m: Node = null) -> ConVat:
	_add_action()
	var cv := ConVat.new()
	cv.name = "ConVat"
	cv.player = p
	cv.main = m
	if p.has_signal("called"):
		p.called.connect(cv._on_called)
	(m if m else p).add_child(cv)
	return cv


func _enter_tree() -> void:
	_inst = self


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


func _physics_process(_delta: float) -> void:
	if player == null or not Input.is_action_just_pressed(ACTION):
		return
	if main and "state" in main and main.state != main.State.PLAY:
		return
	if player.has_method("sit_call"):
		player.sit_call()  # đang ngồi, đang leo... thì sit_call tự bỏ qua; ngày tự gọi trước cũng chỉ phát một lần


func _on_called(pos: Vector3) -> void:
	call_near(get_tree(), pos)


## Gọi on_called(pos) cho mọi con vật trong nhóm ở gần pos. Trả về số con đã đáp.
static func call_near(tree: SceneTree, pos: Vector3) -> int:
	var r := float(DoKho.v("goi_con_vat_r", 8.0))
	var n := 0
	for a in tree.get_nodes_in_group(GROUP):
		if not (a is Node3D) or not a.is_inside_tree() or not a.has_method("on_called"):
			continue
		var rr: float = float(a.get("goi_r")) if a.get("goi_r") != null else r
		if (a as Node3D).global_position.distance_to(pos) <= rr:
			a.on_called(pos)
			n += 1
	return n


# ---------------------------------------------------------------- đã gặp (T2)

static func met_ids() -> Array:
	var list: Array = GameState.get_global(SAVE_KEY, [])
	if not "muc" in list and SoHangXom.muc_friend():  # làm bạn với Mực trước khi có trang này
		list = list + ["muc"]
	return list


static func met(id: String) -> bool:
	return id in met_ids()


static func count() -> int:
	return ALL.keys().filter(func(k): return met(k)).size()


static func full() -> bool:
	return count() >= ALL.size()


static func name_of(id: String) -> String:
	return str(ALL.get(id, [id])[0])


## Lần đầu chơi với con vật `id`. Trả về true nếu là bạn mới. Báo một dòng nhỏ; đủ hết thì tặng quà.
static func meet(id: String) -> bool:
	if id == "" or met(id):
		return false
	var list := met_ids().duplicate()
	list.append(id)
	GameState.set_global(SAVE_KEY, list)
	var gift := full()
	if gift:
		SoHangXom.grant_gift(QUA)
	GameState.write_save()
	if _inst and _inst.main and _inst.main.get("hud") and _inst.main.hud.has_method("show_toast"):
		var text := "Bạn bốn chân mới: %s (%d/%d)" % [name_of(id), count(), ALL.size()]  # Label tự dịch theo mẫu
		if gift:
			text += "\n" + "Đủ bạn bốn chân! Quà: %s" % QUA_TEN
		_inst.main.hud.show_toast(text, 3.0)
	return true


static func _add_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION, 0.2)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_Q
	InputMap.action_add_event(ACTION, k)
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_LEFT_SHOULDER
	InputMap.action_add_event(ACTION, b)
