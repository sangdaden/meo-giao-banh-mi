class_name XeCoBa
## Xe bánh mì Cô Ba đứng yên trước lò: dùng lại xe đẩy chi tiết Sang duyệt 21/10
## (assets/models/pho/xe_banh_mi_day.glb, cùng model với xe bán dạo trong traffic.gd, sơn đỏ).
## Mặt khách (bảng chữ) nhìn +Z, tay đẩy ở +X, gốc giữa đáy thân xe. Thay khối tạm xe_banh_mi cũ.
## Khoảng 4 800 tam giác; thân xe dùng vật liệu chung của PhoModels nên gộp chung lệnh vẽ với nhà quanh lò.

const GLB := "res://assets/models/pho/xe_banh_mi_day.glb"
const TOP := 1.36            ## nóc tủ kính (Z_GLASS trong tools/khu_pho/xe_banh_mi_day.py)
## Giữa nóc tủ kính (tủ lệch về phía không có tay đẩy, sau bảng hiệu): Cô Ba đặt khay bánh ở đây
const TRAY := Vector3(-0.21, TOP, 0.05)
const BODY := Vector3(1.5, 1.38, 0.68)  ## thân xe + tủ kính, để làm hộp va chạm


## Đặt xe vào parent tại pos (giữa đáy thân xe), quay rot_y. collide = có hộp va chạm (màn phố).
static func put(parent: Node, pos: Vector3, rot_y := 0.0, collide := true) -> Node3D:
	var root := Node3D.new()
	root.name = "XeCoBa"
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)
	var model: Node3D = (load(GLB) as PackedScene).instantiate()
	root.add_child(model)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.8, 0.93, 0.95, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fire := StandardMaterial3D.new()
	fire.albedo_color = Color("#FF7A2E")
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if n.begins_with("kinh"):
			mi.material_override = glass
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif n.begins_with("lua"):
			mi.material_override = fire
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mi.mesh = _srgb(mi.mesh)
			mi.material_override = PhoModels.material()  # màu đỉnh chung: Blocks.merge_static gộp vào ô phố
	if collide:
		Blocks.collider(root, BODY, Vector3(0, BODY.y / 2.0, 0), Blocks.LAYER_PROP)
	return root


## Bản web (Compatibility) không đổi màu đỉnh linear sang sRGB như Forward+ (giống PhoModels.mesh)
static func _srgb(m: Mesh) -> Mesh:
	if RenderingServer.get_rendering_device() != null or not m is ArrayMesh or m.get_surface_count() == 0:
		return m
	var dst := ArrayMesh.new()
	for i in m.get_surface_count():
		var arrays := m.surface_get_arrays(i)
		if arrays[Mesh.ARRAY_COLOR] != null:
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for k in cols.size():
				cols[k] = cols[k].linear_to_srgb()
			arrays[Mesh.ARRAY_COLOR] = cols
		dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return dst
