extends ViecNho
## Trang 5 · Anh Hùng: 4 con ốc lăn dưới gầm 4 chiếc xe máy trước tiệm (gầm 0,32 m: phải chui, Ctrl/C).
## Ốc chỉ phát sáng khi Bơ tới gần (2,5 m). Xe là khối tạm, chờ model G8.

const BIKES := [Vector3(30.0, 0, 25.0), Vector3(31.9, 0, 25.3), Vector3(36.2, 0, 25.0), Vector3(38.0, 0, 25.3)]


func begin() -> void:
	line = "Anh Hùng: chui gầm xe tìm 4 con ốc (ốc sáng lên khi tới gần) · 0/4"
	reveal_radius = 2.5
	for b in BIKES:
		var body := Blocks.solid_box(self, Vector3(1.5, 0.55, 0.4), b + Vector3(0, 0.32 + 0.275, 0), Color("#4F7FA8").lerp(Color("#C8412F"), randf()), Blocks.LAYER_PROP)
		body.name = "XeTam"
		for wx in [-0.6, 0.6]:
			Blocks.solid_box(self, Vector3(0.08, 0.32, 0.1), b + Vector3(wx, 0.16, 0), Color("#2B2724"), Blocks.LAYER_PROP)
		var nut := trinket(Vector3(0.06, 0.04, 0.06), Color("#C9CED2"), "cyl")
		add_child(nut)
		add_target(b, nut, 0.55, 0.5, true)


func on_got(_i: int) -> void:
	var n := got_count()
	line = "Anh Hùng: chui gầm xe tìm 4 con ốc · %d/4" % n
	day.task_line(line)
	day.toast("Được một con ốc! (%d/4)" % n, 1.5)
