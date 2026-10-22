extends ViecNho
## Trang 8 · Cô Hai: tháp lon trước tạp hóa bị đổ. Chạm 5 lon lăn khắp vỉa hè để đẩy về tháp;
## lon trên cùng phải nhảy lên đặt (đứng dưới đất thì không với tới).

const TOWER := Vector3(10.3, 0, -6.3)
const SPOTS := [Vector3(11.4, 0, -5.5), Vector3(7.2, 0, -5.4), Vector3(5.4, 0, -6.2), Vector3(3.6, 0, -5.6), Vector3(9.4, 0, -5.3)]
## Chỗ từng lon trong tháp 3 + 2 + 1 trên kệ gỗ cao 0,12 m (G8; lon thứ 6 bánh quy ở trên cùng)
const SLOTS := [Vector3(-0.155, 0.12, 0), Vector3(0, 0.12, 0), Vector3(0.155, 0.12, 0), Vector3(-0.0775, 0.292, 0), Vector3(0.0775, 0.292, 0), Vector3(0, 0.464, 0)]
const CANS := ["lon_1_sua", "lon_2_sua", "lon_3_caphe", "lon_4_caphe", "lon_5_sua", "lon_6_banhquy"]

var _ring: Node3D
## Đỉnh tháp cao hơn tầm Bơ đứng: phải nhảy (Bơ cao ~0,45 m, với được trong 0,3 m quanh chân)
const TOP_Y := 0.75

var _cans: Array[Node3D] = []


func begin() -> void:
	line = "Cô Hai: đẩy 5 lon về tháp · 0/5"
	var shelf := prop("ke_lon", false)
	add_child(shelf)
	shelf.global_position = TOWER
	_ring = prop("vong_dich_lon", false)  # vòng đích ở ô trống kế tiếp
	add_child(_ring)
	_ring.global_position = TOWER + SLOTS[0] + Vector3(0, 0.005, 0)
	for i in SPOTS.size():
		var can := prop(CANS[i])
		can.get_child(0).rotation.x = PI / 2.0  # lon đổ nằm lăn trên vỉa hè
		can.get_child(0).position.y = 0.078
		add_child(can)
		_cans.append(can)
		add_target(SPOTS[i], can, 0.75, 0.6)


func on_got(i: int) -> void:
	var can := _cans[i]
	can.visible = true
	var tw := create_tween()
	tw.tween_property(can, "global_position", TOWER + SLOTS[i], 0.6).set_trans(Tween.TRANS_QUAD)
	targets[i].node = null  # lon nằm yên trong tháp, không nhấp nhô nữa
	can.rotation = Vector3.ZERO
	can.get_child(0).rotation.x = 0.0  # dựng đứng lại
	can.get_child(0).position.y = 0.0
	if can.get_child_count() > 1:
		can.get_child(1).visible = false  # tắt vòng sáng
	var n := got_count()
	_ring.visible = n < 6
	if n < 6:
		_ring.global_position = TOWER + SLOTS[n] + Vector3(0, 0.005, 0)
	if n == 5:
		var top := prop(CANS[5])
		add_child(top)
		_cans.append(top)
		add_target(TOWER + Vector3(0, TOP_Y, 0), top, 0.8, 0.3)
		line = "Cô Hai: nhảy lên đặt lon trên cùng!"
		day.toast("Còn lon trên cùng: nhảy lên đặt nha!", 2.0)
	else:
		line = "Cô Hai: đẩy 5 lon về tháp · %d/5" % mini(n, 5)
		if n > 5:
			_sfx("jingle_win")
	day.task_line(line)
