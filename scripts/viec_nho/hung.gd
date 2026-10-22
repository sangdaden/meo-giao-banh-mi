extends ViecNho
## Trang 5 · Anh Hùng: 4 con ốc lăn dưới gầm 4 chiếc xe máy trước tiệm (gầm 0,32 m: phải chui, Ctrl/C).
## Ốc (G8) chỉ hiện khi Bơ tới gần (2,5 m), trong 1,5 m thì vầng vàng nhấp nháy 1,2 Hz. Xe là xe máy phố có sẵn.

const BIKES := [Vector3(30.0, 0, 25.0), Vector3(31.9, 0, 25.3), Vector3(36.2, 0, 25.0), Vector3(38.0, 0, 25.3)]
const NUTS := ["oc_bu_long", "oc_dai_oc", "oc_vit", "oc_tai_hong"]
const BIKE_MODELS := ["xe_may_xanh", "xe_may_den", "xe_may_do", "xe_may_trang"]
const GLOW_NEAR := 1.5

var _glows: Array[Node3D] = []


func begin() -> void:
	line = "Anh Hùng: chui gầm xe tìm 4 con ốc (ốc sáng lên khi tới gần) · 0/4"
	reveal_radius = 2.5
	for i in BIKES.size():
		var b: Vector3 = BIKES[i]
		# thân xe chặn trên gầm 0,32 m (phải chui), bánh xe hai đầu
		var body := Blocks.collider(self, Vector3(1.5, 0.55, 0.4), b + Vector3(0, 0.32 + 0.275, 0), Blocks.LAYER_PROP)
		body.name = "XeDau"
		for wx in [-0.6, 0.6]:
			Blocks.collider(self, Vector3(0.08, 0.32, 0.1), b + Vector3(wx, 0.16, 0), Blocks.LAYER_PROP)
		PhoModels.put(body, BIKE_MODELS[i], Vector3(0, -0.595, 0), PI)
		var nut := prop(NUTS[i])
		var shine := prop("oc_vang_sang", false)
		shine.visible = false
		nut.add_child(shine)
		_glows.append(shine)
		add_child(nut)
		add_target(b, nut, 0.55, 0.5, true)
	var hung: Node3D = day.people.get("hung")
	if hung:
		var tray := prop("khay_oc", false)
		add_child(tray)
		tray.global_position = surface(get_world_3d(), hung.global_position.x + 0.7, hung.global_position.z + 0.3, 1.2)


func tick(delta: float) -> void:
	super.tick(delta)
	var on := fmod(Time.get_ticks_msec() / 1000.0 * 1.2, 1.0) < 0.6
	for i in _glows.size():
		var t: Dictionary = targets[i]
		_glows[i].visible = on and not t.got and player.global_position.distance_to(t.pos) < GLOW_NEAR


func on_got(_i: int) -> void:
	var n := got_count()
	line = "Anh Hùng: chui gầm xe tìm 4 con ốc · %d/4" % n
	day.task_line(line)
	day.toast("Được một con ốc! (%d/4)" % n, 1.5)
