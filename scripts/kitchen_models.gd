class_name KitchenModels
## Đồ bếp kiểu D bằng .glb thật (assets/models/bep/, Sang duyệt 21/10/2026).
## Mỗi file một mesh, màu nằm trong màu đỉnh; gốc ở giữa đáy, mặt trước nhìn về +Z, đơn vị mét.
## Mọi món dùng chung một vật liệu màu đỉnh nên Blocks.merge_static gộp được đồ đứng yên
## thành một lệnh vẽ. Món cần vật liệu riêng (lửa phát sáng, kính, đổi màu khi nướng) dùng own().

const DIR := "res://assets/models/bep/"

static var _meshes := {}
static var _shared: StandardMaterial3D


## Mesh của một món, đã đổi màu đỉnh sang sRGB nếu đang chạy Compatibility (bản web).
static func mesh(model: String) -> Mesh:
	if _meshes.has(model):
		return _meshes[model]
	var scene: PackedScene = load(DIR + model + ".glb")
	var root := scene.instantiate()
	var src: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var m: Mesh = src.mesh
	var xf := src.transform
	var n: Node = src.get_parent()
	while n != root and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	# Chạy không màn hình (bot kiểm tra) thì không có dữ liệu đỉnh để đổi màu
	var compat := RenderingServer.get_rendering_device() == null and DisplayServer.get_name() != "headless"
	if compat or xf != Transform3D.IDENTITY:
		var dst := ArrayMesh.new()
		for i in m.get_surface_count():
			var arrays := m.surface_get_arrays(i)
			if xf != Transform3D.IDENTITY:
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for k in verts.size():
					verts[k] = xf * verts[k]
				arrays[Mesh.ARRAY_VERTEX] = verts
				var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for k in norms.size():
					norms[k] = (xf.basis * norms[k]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = norms
				arrays[Mesh.ARRAY_TANGENT] = null
			if compat and arrays[Mesh.ARRAY_COLOR] != null:
				var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				for k in cols.size():
					cols[k] = cols[k].linear_to_srgb()
				arrays[Mesh.ARRAY_COLOR] = cols
			dst.add_surface_from_arrays(m.surface_get_primitive_type(i), arrays)
		m = dst
	root.free()
	_meshes[model] = m
	return m


static func shared_mat() -> StandardMaterial3D:
	if _shared == null:
		_shared = own_mat()
	return _shared


## Vật liệu màu đỉnh riêng: đổi albedo_color để nhuộm (nhân với màu đỉnh), emission để phát sáng.
static func own_mat(tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = tint
	m.roughness = 0.8
	if tint.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Đặt một món. rot_y tính bằng độ; scale đều. Dùng vật liệu chung (gộp được).
static func place(parent: Node, model: String, pos: Vector3, rot_y := 0.0, scale := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = model
	mi.mesh = mesh(model)
	mi.material_override = shared_mat()
	mi.position = pos
	mi.rotation_degrees.y = rot_y
	mi.scale = Vector3.ONE * scale
	parent.add_child(mi)
	return mi


## Như place nhưng vật liệu riêng (không gộp), để nhuộm màu hay làm mờ dần.
static func own(parent: Node, model: String, pos: Vector3, rot_y := 0.0, scale := 1.0, tint := Color.WHITE) -> MeshInstance3D:
	var mi := place(parent, model, pos, rot_y, scale)
	mi.material_override = own_mat(tint)
	return mi


## Đặt món kèm khối va chạm theo hộp bao (đồ to: bàn, lò, xe, bồn rửa). Trả về StaticBody3D.
static func solid(parent: Node, model: String, pos: Vector3, rot_y := 0.0, layer := Blocks.LAYER_PROP) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = model
	body.collision_layer = layer
	body.position = pos
	body.rotation_degrees.y = rot_y
	parent.add_child(body)
	place(body, model, Vector3.ZERO)
	var box := mesh(model).get_aabb()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	cs.position = box.get_center()
	body.add_child(cs)
	return body


## Kích thước hộp bao (rộng X, cao Y, sâu Z) của một món, mét.
static func size(model: String) -> Vector3:
	return mesh(model).get_aabb().size


## `glass` là màu sRGB như trong Blender. Tách các tam giác có màu đỉnh gần `glass` ra một mesh riêng phủ vật liệu kính trong.
## Dùng cho tủ kính xe bánh mì: camera nhìn xuyên qua kính vào bếp.
static func split_glass(mi: MeshInstance3D, glass: Color, tol := 0.08) -> MeshInstance3D:
	var src := mi.mesh
	var keep := SurfaceTool.new()
	keep.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass_st := SurfaceTool.new()
	glass_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var found := 0
	var compat := RenderingServer.get_rendering_device() == null
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for k in verts.size():
				idx[k] = k
		for t in range(0, idx.size(), 3):
			var c := cols[idx[t]] if compat else cols[idx[t]].linear_to_srgb()
			var is_glass := absf(c.r - glass.r) < tol and absf(c.g - glass.g) < tol and absf(c.b - glass.b) < tol
			var st := glass_st if is_glass else keep
			found += int(is_glass)
			for k in 3:
				st.set_color(cols[idx[t + k]])
				st.set_normal(norms[idx[t + k]])
				st.add_vertex(verts[idx[t + k]])
	if found == 0:
		return null
	mi.mesh = keep.commit()
	var g := MeshInstance3D.new()
	g.name = "Kinh"
	g.mesh = glass_st.commit()
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.75, 0.92, 0.96, 0.22)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.1
	gm.metallic_specular = 0.8
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	g.material_override = gm
	mi.get_parent().add_child(g)
	g.transform = mi.transform
	return g
