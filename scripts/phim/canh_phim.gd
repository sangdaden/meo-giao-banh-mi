class_name CanhPhim
## Hai bối cảnh của phim mở đầu và cảnh kết tuần (trang C1 Sang duyệt 23/10/2026), dựng từ model thật của game:
## - pho(): mặt tiền Lò bánh Cô Ba giữa dãy nhà, vỉa hè, đường, dãy nhà bên kia đường. Sáng sớm hoặc đêm đèn lồng.
## - tiem(): góc trong tiệm: tường sau, lò gạch, quầy, bảng "Tuần của Bơ", giỏ ngủ, đèn treo, đèn lồng.
## Toạ độ ghi theo bản phác thảo Blender (x phải, y vào trong tiệm, z lên) rồi đổi sang Godot bằng B():
## Godot (x, z, -y). Mặt tiền nhà nhìn +Z (ra đường), như dãy nam trong khu phố.

const PROPS := "res://assets/models/phim/"
## Bảng "Tuần của Bơ": mặt ảnh trong bang_tuan.glb theo thứ tự ngày
const BOARD_DAYS := {"thu_hai": "AnhT2", "thu_ba": "AnhT3", "thu_tu": "AnhT4", "thu_nam": "AnhT5",
	"thu_sau": "AnhT6", "thu_bay": "AnhT7", "chu_nhat": "AnhCN"}
## Móc huy chương trên bảng (giữa, ngay trên ảnh Chủ Nhật), toạ độ phác thảo
const MEDAL_HOOK := Vector3(0.35, 1.93, 1.18)


## Toạ độ bản phác thảo Blender -> Godot.
static func B(x: float, y: float, z := 0.0) -> Vector3:
	return Vector3(x, z, -y)


## Dãy phố quanh Lò bánh. buoi: "sang" (rạng sáng Thứ Hai) | "dem" (đêm Chủ Nhật, đèn lồng sáng).
static func pho(parent: Node3D, buoi: String) -> Dictionary:
	AnhSang.build(parent, "pho_sang" if buoi == "sang" else "pho_toi")
	var set := Node3D.new()
	set.name = "Pho"
	parent.add_child(set)
	PhoModels.put(set, "nha_C", B(-9.6, 0))
	PhoModels.put(set, "nha_A", B(-4.2, 0))
	PhoModels.put(set, "lo_banh", B(0, 0))
	PhoModels.put(set, "mai_hien_do", Vector3(2.6, 3.0, 0.0), 0.0, Vector3(5.2, 1, 1))
	PhoModels.put(set, "nha_B", B(5.7, 0))
	PhoModels.put(set, "nha_C", B(9.8, 0))
	PhoModels.put(set, "xe_banh_mi", B(4.4, -1.25))
	PhoModels.put(set, "den_duong", B(-1.6, -2.9))
	PhoModels.put(set, "den_duong", B(6.2, -2.9))
	PhoModels.put(set, "cay_xanh", B(7.8, -3.2))
	# Dãy nhà bên kia đường, mặt tiền nhìn về Lò bánh
	var x := -14.0
	for m in ["nha_D", "nha_F", "nha_E", "nha_H", "nha_G", "nha_K", "nha_I"]:
		var w: float = PhoModels.FILLERS[m]
		PhoModels.put(set, m, Vector3(x + w, 0, 15.5), PI)
		x += w + 0.3
	_box(set, Vector3(44, 0.12, 2.8), B(2, -1.8, -0.06), Color("#B9AE9C"))   # vỉa hè
	_box(set, Vector3(44, 0.16, 0.18), B(2, -3.25, -0.06), Color("#9C9384"))  # bó vỉa
	_box(set, Vector3(64, 0.1, 9.6), B(2, -8.2, -0.12), Color("#4A4A4C"))    # mặt đường
	_box(set, Vector3(44, 0.12, 2.8), B(2, -14.2, -0.06), Color("#B9AE9C"))  # vỉa hè bên kia
	for i in range(-7, 9):
		_box(set, Vector3(1.4, 0.01, 0.14), B(i * 3.2, -8.2, -0.065), Color("#E9E4D6"))
	var lamps := []
	if buoi == "dem":
		for i in 2:
			var lamp := Tiem.make("den_long_tiem", 1.4 * i)
			set.add_child(lamp)
			lamp.position = Vector3(0.6 if i == 0 else 4.6, 2.86, 0.25)
			lamp.scale = Vector3.ONE * 1.8
			lamps.append(lamp)
		Tiem.glow.call_deferred(parent.get_tree(), 1.0)
		# Ánh lồng đèn hắt xuống vỉa hè trước cửa (phim chỉ có một cảnh nên được thêm đèn thật)
		for p in [Vector3(0.6, 2.3, 0.9), Vector3(4.6, 2.3, 0.9)]:
			_omni(set, p, Color("#FF9A55"), 1.6, 4.5)
		_omni(set, B(-1.6, -2.9, 5.6), Color("#FFD9A0"), 1.2, 7.0)  # đèn đường
		_omni(set, B(6.2, -2.9, 5.6), Color("#FFD9A0"), 1.2, 7.0)
		_omni(set, B(2.7, 0.5, 1.6), Color("#FFB070"), 1.0, 3.0)     # cửa tiệm hé sáng
	return {"set": set, "lamps": lamps}


## Góc trong tiệm. den: "dem" (đèn treo + đèn lồng), "tat" (tắt đèn treo, còn đèn lồng), "sang" (nắng sớm qua cửa).
## Trả về {board, gio, den_treo (OmniLight3D), long (mảng OmniLight3D)}.
static func tiem(parent: Node3D, den: String) -> Dictionary:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2A2018")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#E9C9A0") if den == "sang" else Color("#8A6A50")
	env.ambient_light_energy = 0.45 if den == "sang" else 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var set := Node3D.new()
	set.name = "Tiem"
	parent.add_child(set)
	_floor(set)
	_box(set, Vector3(8, 3.2, 0.2), B(0, 2.2, 1.6), Color("#E9D2B0"))
	_box(set, Vector3(0.2, 3.2, 6), B(-3.1, 0, 1.6), Color("#E2C7A3"))
	_box(set, Vector3(0.2, 3.2, 6), B(3.4, 0, 1.6), Color("#E2C7A3"))
	_box(set, Vector3(8, 0.35, 0.22), B(0, 2.0, 0.17), Color("#B5603F"))
	_box(set, Vector3(8, 0.2, 6), B(0, 0, 3.3), Color("#C9AE8C"))
	KitchenModels.place(set, "lo_gach", B(-2.2, 1.55))
	KitchenModels.place(set, "quay_ba", B(1.9, 1.7))
	KitchenModels.place(set, "quay_ba", B(2.55, 1.7))
	KitchenModels.place(set, "bao_bot", B(-1.35, 1.7))
	KitchenModels.place(set, "bao_bot", B(-1.12, 1.82), 40.0)
	KitchenModels.place(set, "ro_tre", B(2.2, 1.7, 0.85))
	KitchenModels.place(set, "den_treo", B(0.3, 0.6, 2.45))
	var cat := Tiem.make("meo_vay_tay")
	set.add_child(cat)
	cat.position = B(2.4, 1.75, 0.85)
	var mai := Tiem.make("chau_mai")
	set.add_child(mai)
	mai.position = B(-2.55, -0.6)
	var long := []
	for p in [B(-0.6, 1.0, 2.6), B(1.2, 1.0, 2.6)]:
		var lamp := Tiem.make("den_long_tiem", p.x)
		set.add_child(lamp)
		lamp.position = p
		long.append(_omni(set, p + Vector3(0, -0.25, 0), Color("#FF8A50"), 0.7 if den != "sang" else 0.3, 2.6))
	Tiem.glow.call_deferred(parent.get_tree(), 1.0 if den != "sang" else 0.4)
	var board: Node3D = load(PROPS + "bang_tuan.glb").instantiate()
	set.add_child(board)
	board.position = B(0.35, 1.98)
	var gio: Node3D = load(PROPS + "gio_ngu.glb").instantiate()
	set.add_child(gio)
	gio.position = B(-1.25, 1.1)
	gio.scale = Vector3.ONE * 1.15
	var treo := _omni(set, B(0.3, 0.6, 2.0), Color("#FFC98A"), 0.0 if den == "tat" else 1.3, 5.5)
	treo.shadow_enabled = true
	if den == "sang":
		var sun := DirectionalLight3D.new()
		sun.light_color = Color("#FFD6A0")
		sun.light_energy = 1.1
		sun.rotation_degrees = Vector3(-25, -25, 0)  # nắng sớm xiên qua cửa trước vào tường sau
		sun.shadow_enabled = true
		set.add_child(sun)
	else:
		var moon := DirectionalLight3D.new()
		moon.light_color = Color("#9DB4E8")
		moon.light_energy = 0.15
		moon.rotation_degrees = Vector3(-40, 20, 0)
		set.add_child(moon)
	return {"set": set, "board": board, "gio": gio, "den_treo": treo, "long": long}


## Dán ảnh 7 ngày lên bảng (AnhTuan); ngày chưa có ảnh giữ ảnh vẽ sẵn trong model nhưng mờ đi.
static func dan_anh(board: Node3D) -> void:
	for day: String in BOARD_DAYS:
		var mi := board.find_child(BOARD_DAYS[day] + "*", true, false) as MeshInstance3D
		if mi == null:
			continue
		var tex := AnhTuan.texture(day)
		var m := StandardMaterial3D.new()
		m.roughness = 0.45
		if tex:
			m.albedo_texture = tex
		else:
			var src := mi.get_active_material(0) as StandardMaterial3D
			if src:
				m.albedo_texture = src.albedo_texture
			m.albedo_color = Color(1, 1, 1).lerp(Color("#FBF3E2"), 0.55)  # ngày chưa chơi: ảnh vẽ sẵn bạc màu
		mi.material_override = m


## Model .glb của phim (khăn cầm tay, giỏ ngủ, bảng tuần).
static func prop(parent: Node, id: String) -> Node3D:
	var n: Node3D = load(PROPS + id + ".glb").instantiate()
	parent.add_child(n)
	return n


static func _box(parent: Node3D, size: Vector3, center: Vector3, color: Color) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	bm.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position = center
	parent.add_child(mi)
	return mi


static func _omni(parent: Node3D, pos: Vector3, color: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	parent.add_child(l)
	return l


## Sàn gạch bông hai màu ô 1 m (một mesh, màu đỉnh).
static func _floor(parent: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for ix in range(-4, 4):
		for iz in range(-3, 4):
			st.set_color(Color("#B98A62") if (ix + iz) % 2 == 0 else Color("#D2AE84"))
			var a := Vector3(ix, 0, iz)
			for v in [a, a + Vector3(1, 0, 0), a + Vector3(1, 0, 1), a, a + Vector3(1, 0, 1), a + Vector3(0, 0, 1)]:
				st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	parent.add_child(mi)
