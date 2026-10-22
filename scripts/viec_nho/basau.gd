extends ViecNho
## Trang 6 · Bà Sáu: hái 5 chùm bông giấy trên giàn trước nhà (thanh ngang cao 2,45 m) để cúng.
## Leo lên bằng chồng thùng cạnh giàn hoặc bám mép từ ghế mây. Gai trên giàn làm chậm (DoKho "thorn_slow"), không đau.

const BAR_Y := 2.5
const BAR_Z := 23.7
const XS := [-19.6, -19.0, -18.5, -18.0, -17.4]
const STEP := Vector3(-17.6, 0, 22.6)


func begin() -> void:
	line = "Bà Sáu: leo lên giàn hái 5 chùm bông giấy · 0/5"
	CityProps.crate(self, STEP)
	CityProps.crate(self, STEP + Vector3(0, 0.8, 0))
	for x in XS:
		var flower := trinket(Vector3(0.18, 0.14, 0.18), Color("#E0559A"), "sphere")
		add_child(flower)
		add_target(Vector3(x, BAR_Y, BAR_Z), flower, 0.6, 0.6)


func tick(delta: float) -> void:
	super.tick(delta)
	var p := player.global_position
	var on_bar := p.y > 2.3 and p.x > -20.2 and p.x < -16.8 and absf(p.z - BAR_Z) < 0.5
	player.speed_scale = float(DoKho.v("thorn_slow", 0.5)) if on_bar and not is_done() else 1.0


func on_got(_i: int) -> void:
	var n := got_count()
	line = "Bà Sáu: leo lên giàn hái 5 chùm bông giấy · %d/5" % n
	day.task_line(line)
	day.toast("Hái được một chùm! (%d/5)" % n, 1.5)


func finish() -> void:
	player.speed_scale = 1.0
	super.finish()
