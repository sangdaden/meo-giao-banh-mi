extends ViecNho
## Trang 2 · Chú Tư: gió thổi tờ báo bay lên mái hiên. Tờ báo dừng chờ ở mỗi chặng; tới sát là nó bay tiếp.
## Thong thả chờ mãi (DoKho "paper_wait"); Thử thách chờ 6 s rồi bay về chặng đầu. Hết chặng thì mang về cho Chú Tư.
## Chặng: mái hiên khối 2 trên sạp báo, mái hiên phía tây, nóc chồng thùng bậc thang. Lên mái hiên bằng chồng thùng (-11,7; -5,6).

const STAGES := [Vector2(-3.5, -6.55), Vector2(-8.0, -6.55), Vector2(-11.7, -5.6)]

var _paper: Node3D
var _wait := 0.0


func begin() -> void:
	line = "Chú Tư: đuổi theo tờ báo trên mái hiên (lên bằng chồng thùng phía tây)"
	ordered = true
	return_to = day.person_spot("chutu")
	return_name = "Chú Tư"
	_paper = trinket(Vector3(0.34, 0.03, 0.26), Color("#E8E2D0"))
	add_child(_paper)
	for s in STAGES:
		add_target(surface(get_world_3d(), s.x, s.y) + Vector3(0, 0.02, 0), null, 0.8, 0.6)
	carry_with(func(): return trinket(Vector3(0.26, 0.03, 0.2), Color("#E8E2D0")))
	_fly_to(0)
	_sfx("paper_slip")


func tick(delta: float) -> void:
	super.tick(delta)
	var i := _first_open()
	if i < 0 or _state != "find":
		return
	_wait += delta
	if _wait > float(DoKho.v("paper_wait", 6.0)) and i > 0:
		for t in targets:
			t.got = false
		day.toast("Gió thổi tờ báo bay về chỗ cũ rồi! Đuổi lại nha.", 2.5)
		_fly_to(0)


func on_got(i: int) -> void:
	if i + 1 < targets.size():
		day.toast("Tờ báo bay tiếp! (%d/%d)" % [i + 1, targets.size()], 1.8)
		_fly_to(i + 1)
	else:
		_paper.visible = false
		day.toast("Bắt được tờ báo! Mang về cho Chú Tư.", 2.5)


func _fly_to(i: int) -> void:
	_wait = 0.0
	_paper.visible = true
	var tw := create_tween()
	tw.tween_property(_paper, "global_position", targets[i].pos + Vector3(0, 0.05, 0), 0.9).set_trans(Tween.TRANS_SINE)
