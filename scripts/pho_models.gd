class_name PhoModels
## Nhà và đồ phố dựng trong Blender theo trang "Khu phố Lò Bánh" (Sang duyệt 21/10).
## Xuất bằng tools/khu_pho/xuat_game.py vào assets/models/pho/: mét thật, một vật liệu, màu đỉnh.
## Gốc model: nhà thì góc trái mặt tiền (x 0..rộng, mặt tiền ở z = 0 nhìn +z, thân nhà lùi về -z),
## đồ phố thì giữa đáy. Model chỉ để nhìn; va chạm vẫn là hộp đặt riêng (Blocks.collider).
## Mọi model dùng chung material() nên Blocks.merge_static gộp được thành ít lệnh vẽ.

const DIR := "res://assets/models/pho/"
## Nhà lấp chỗ trống và bề ngang danh nghĩa (mét), khớp FILLERS trong xuat_game.py
const FILLERS := {
	"nha_A": 4.0, "nha_B": 3.8, "nha_C": 4.6, "nha_D": 5.0, "nha_E": 4.2,
	"nha_F": 5.5, "nha_G": 4.4, "nha_H": 5.8, "nha_I": 3.6, "nha_K": 4.8,
}

static var _meshes := {}
static var _mat: StandardMaterial3D


## Vật liệu màu đỉnh dùng chung. Vẽ hai mặt vì mái tôn, bạt, đồ phơi chỉ là tấm mỏng.
static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 0.85
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat


static func mesh(model: String) -> ArrayMesh:
	if _meshes.has(model):
		return _meshes[model]
	var scene: PackedScene = load(model if model.begins_with("res://") else DIR + model + ".glb")
	var root := scene.instantiate()
	var src: Mesh = null
	for n in root.find_children("*", "MeshInstance3D", true, false):
		src = (n as MeshInstance3D).mesh
		break
	# Bản web (Compatibility) không đổi màu đỉnh từ linear sang sRGB như Forward+ (giống player.gd)
	var to_srgb := RenderingServer.get_rendering_device() == null
	var dst := ArrayMesh.new()
	for i in src.get_surface_count():
		var arrays := src.surface_get_arrays(i)
		if to_srgb and arrays[Mesh.ARRAY_COLOR] != null:
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for k in cols.size():
				cols[k] = cols[k].linear_to_srgb()
			arrays[Mesh.ARRAY_COLOR] = cols
		dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	root.free()
	_meshes[model] = dst
	return dst


## Đặt một model. rot_y tính bằng radian, scale để giãn nhà/mái hiên theo bề ngang ô.
static func put(parent: Node, model: String, pos: Vector3, rot_y := 0.0, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(model)
	mi.material_override = material()
	mi.position = pos
	mi.rotation.y = rot_y
	mi.scale = scale
	parent.add_child(mi)
	return mi


## Bản model bỏ hết tam giác nằm xa hơn z_max trước mặt tiền (gốc model, chưa xoay): gỡ đồ đúc liền
## phía trước nhà như hàng rào cũ khi bản đồ đổi.
static func mesh_cut_front(model: String, z_max: float) -> ArrayMesh:
	var key := "%s<%s" % [model, z_max]
	if _meshes.has(key):
		return _meshes[key]
	var src := mesh(model)
	var dst := ArrayMesh.new()
	for i in src.get_surface_count():
		var arrays := src.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			idx.resize(verts.size())
			for k in verts.size():
				idx[k] = k
		var keep := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if verts[idx[t]].z <= z_max or verts[idx[t + 1]].z <= z_max or verts[idx[t + 2]].z <= z_max:
				keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
		arrays[Mesh.ARRAY_INDEX] = keep
		dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = dst
	return dst


## Hộp bao của model (theo gốc model, chưa xoay).
static func aabb(model: String) -> AABB:
	return mesh(model).get_aabb()


## Đặt nhà vào dãy phố. x0: mép trái theo trục X thế giới, w: bề ngang ô, model_w: bề ngang thật của model
## (giãn trục X cho vừa ô), face_z: mặt tiền, faces_south: mặt tiền nhìn +z (dãy nam của khối) hay -z (dãy bắc).
static func put_house(parent: Node, model: String, x0: float, w: float, model_w: float, face_z: float, faces_south: bool) -> MeshInstance3D:
	var sx := w / model_w
	if faces_south:
		return put(parent, model, Vector3(x0, 0, face_z), 0.0, Vector3(sx, 1, 1))
	return put(parent, model, Vector3(x0 + w, 0, face_z), PI, Vector3(sx, 1, 1))
