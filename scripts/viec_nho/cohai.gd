extends ViecNho
## Trang 8 · Cô Hai: tháp lon trước tạp hóa bị đổ. Chạm 5 lon lăn khắp vỉa hè để đẩy về tháp;
## lon trên cùng phải nhảy lên đặt (đứng dưới đất thì không với tới).

const TOWER := Vector3(10.3, 0, -6.3)
const CAN := Vector3(0.12, 0.17, 0.12)
const SPOTS := [Vector3(11.4, 0, -5.5), Vector3(7.2, 0, -5.4), Vector3(5.4, 0, -6.2), Vector3(3.6, 0, -5.6), Vector3(9.4, 0, -5.3)]
## Chỗ từng lon trong tháp 3 + 2 + 1 (lon thứ 6 ở trên cùng)
const SLOTS := [Vector3(-0.13, 0, 0), Vector3(0, 0, 0), Vector3(0.13, 0, 0), Vector3(-0.065, 0.17, 0), Vector3(0.065, 0.17, 0), Vector3(0, 0.34, 0)]
## Đỉnh tháp cao hơn tầm Bơ đứng: phải nhảy (Bơ cao ~0,45 m, với được trong 0,3 m quanh chân)
const TOP_Y := 0.75

var _cans: Array[Node3D] = []


func begin() -> void:
	line = "Cô Hai: đẩy 5 lon về tháp · 0/5"
	Blocks.box(self, Vector3(0.5, 0.02, 0.3), TOWER + Vector3(0, 0.01, 0), Color("#9B6A3A"))
	for s in SPOTS:
		var can := trinket(CAN, Color("#C8412F").lerp(Color("#F2C14E"), randf()), "cyl")
		add_child(can)
		_cans.append(can)
		add_target(s, can, 0.75, 0.6)


func on_got(i: int) -> void:
	var can := _cans[i]
	can.visible = true
	var tw := create_tween()
	tw.tween_property(can, "global_position", TOWER + SLOTS[i], 0.6).set_trans(Tween.TRANS_QUAD)
	targets[i].node = null  # lon nằm yên trong tháp, không nhấp nhô nữa
	can.rotation = Vector3.ZERO
	var n := got_count()
	if n == 5:
		var top := trinket(CAN, Color("#3F8A5C"), "cyl")
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
