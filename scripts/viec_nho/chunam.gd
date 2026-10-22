extends ViecNho
## Trang 9 · Chú Năm: khách bỏ quên mũ bảo hiểm trên mái hiên khối 1 (gần lò bánh). Leo chồng thùng lên mái
## hiên lấy mũ, mang về cho Chú Năm ở xe ôm đầu hẻm 42.

const HELMET := Vector2(-26.6, -6.55)
const STEP := Vector3(-27.6, 0, -5.6)


func begin() -> void:
	line = "Chú Năm: lấy mũ bảo hiểm trên mái hiên gần lò bánh (leo chồng thùng)"
	return_to = day.person_spot("chunam")
	return_name = "Chú Năm"
	CityProps.crate(self, STEP)
	CityProps.crate(self, STEP + Vector3(0, 0.8, 0))
	var helmet := prop("mu_khach_quen")
	helmet.get_child(0).rotation.z = deg_to_rad(30.0)  # nằm nghiêng trên mái hiên
	add_child(helmet)
	add_target(surface(get_world_3d(), HELMET.x, HELMET.y), helmet, 0.8, 0.6)
	carry_with(func():
		var h := prop("mu_khach_quen", false)
		h.scale = Vector3.ONE * 0.8
		return h)


func on_got(_i: int) -> void:
	line = "Chú Năm: mang mũ về xe ôm đầu hẻm 42"
	day.task_line(line)
	day.toast("Lấy được mũ rồi! Mang về cho Chú Năm.", 2.0)
