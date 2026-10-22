extends ViecNho
## Trang 6 · Bà Sáu: hái 5 chùm bông giấy trên giàn trùm cổng nhà (mặt trên cao 2,3 m) để cúng.
## Leo lên bằng thang tre hai bên giàn hoặc chồng thùng cạnh giàn. Gai trên giàn làm chậm (DoKho "thorn_slow"), không đau.

const BAR_Y := 2.55
const BAR_Z := CityProps.GIAN_POS.z
const XS := [-19.6, -19.0, -18.5, -18.0, -17.4]
const STEP := Vector3(-17.45, 0, 20.75)

var _basket: Node3D


func begin() -> void:
	line = "Bà Sáu: leo lên giàn hái 5 chùm bông giấy · 0/5"
	CityProps.crate(self, STEP)
	CityProps.crate(self, STEP + Vector3(0, 0.8, 0))
	for x in XS:
		var flower := prop("chum_bong_giay")
		add_child(flower)
		add_target(Vector3(x, BAR_Y, BAR_Z), flower, 0.6, 0.6)
	# rổ tre cạnh ghế Bà Sáu: hái được chùm nào thì chùm đó nằm trong rổ
	var ba: Node3D = day.people.get("basau")
	var at := (ba.global_position if ba else CityProps.BA_SAU_CHAIR) + Vector3(0.55, 0, 0.1)
	_basket = prop("ro_tre", false)
	add_child(_basket)
	_basket.global_position = surface(get_world_3d(), at.x, at.z, 1.2)


func tick(delta: float) -> void:
	super.tick(delta)
	var p := player.global_position
	var on_bar := p.y > 2.3 and p.x > -20.2 and p.x < -16.8 and absf(p.z - BAR_Z) < 0.7
	player.speed_scale = float(DoKho.v("thorn_slow", 0.5)) if on_bar and not is_done() else 1.0


func on_got(_i: int) -> void:
	var n := got_count()
	var bunch := prop("chum_bong_giay", false)
	bunch.scale = Vector3.ONE * 0.6
	_basket.add_child(bunch)
	bunch.position = Vector3((n % 3 - 1) * 0.06, 0.1 + (n / 3) * 0.05, (n % 2) * 0.05 - 0.025)
	bunch.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
	line = "Bà Sáu: leo lên giàn hái 5 chùm bông giấy · %d/5" % n
	day.task_line(line)
	day.toast("Hái được một chùm! (%d/5)" % n, 1.5)


func finish() -> void:
	player.speed_scale = 1.0
	super.finish()
