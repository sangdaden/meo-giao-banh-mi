class_name Blocks
## Hàm tiện ích dựng khối hộp tạm (placeholder) bằng code.
## Khi có model .glb từ Blender, thay các khối này bằng scene model thật.

static var _materials := {}

## Lớp va chạm: 1 = thế giới lớn (đất, nhà), 2 = mèo, 4 = chó, 8 = đồ nhỏ (thùng, xe, cột, người).
## Camera chỉ né lớp 1, nên đi ngang qua thùng hàng camera không bị giật sát vào lưng mèo.
const LAYER_WORLD := 1
const LAYER_PROP := 8


## Vật liệu màu trơn, dùng chung cho các khối cùng màu để đỡ tốn bộ nhớ.
static func mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), unshaded]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = m
	return m


## Thêm một khối hộp chỉ để nhìn (không va chạm).
static func box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Thêm một khối hộp đặc: nhìn thấy và có va chạm (tường, thùng hàng...).
static func solid_box(parent: Node, size: Vector3, pos: Vector3, color: Color, layer := LAYER_WORLD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = pos
	parent.add_child(body)
	box(body, size, Vector3.ZERO, color)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	return body


## Chỉ có hộp va chạm, không có hình (hình là model .glb đặt riêng, xem PhoModels).
static func collider(parent: Node, size: Vector3, pos: Vector3, layer := LAYER_WORLD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = pos
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	return body


## Tường vô hình chặn mép bản đồ.
static func invisible_wall(parent: Node, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)


static func mesh(parent: Node, m: Mesh, pos: Vector3, color: Color, unshaded := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(color, unshaded)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Chữ nổi trong thế giới 3D, luôn quay về phía camera.
static func label(parent: Node, text: String, pos: Vector3, size := 48, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0.12, 0.16, 0.16)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	parent.add_child(l)
	return l


## Gộp mọi khối tĩnh cùng vật liệu dưới root thành một mesh duy nhất.
## Mỗi MeshInstance3D là một lệnh vẽ (draw call); khu phố có khoảng 700 khối nên
## trình duyệt vẽ không kịp 60 FPS. Gộp lại chỉ còn vài chục lệnh vẽ.
## Va chạm (StaticBody3D) vẫn giữ nguyên, chỉ phần hình được gộp.
## Model nhà và đồ phố (vật liệu PhoModels) nặng hơn khối nhiều nên gộp theo ô cell x cell mét:
## ô nằm ngoài camera thì không vẽ. Đồ nhỏ (dưới 1,5 m) gộp riêng và tắt khi xa hơn 45 m.
## Model gộp được sinh LOD (ImporterMesh) để nhà ở xa vẽ ít tam giác hơn, cả ở lượt bóng.
## Khối mỏng sát đất (vạch kẻ, vỉa hè, vũng nước) và đồ dưới 0,6 m không đổ bóng.
static func merge_static(root: Node3D, cell := 0.0) -> void:
	var tools := {}
	var mats := {}
	var info := {}
	var to_root := root.global_transform.affine_inverse()
	var model_mat: Material = PhoModels.material() if cell > 0.0 else null
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var m: Material = mi.material_override
		if m == null:
			continue  # mesh tự mang vật liệu (vd. model góc cờ): để nguyên, không gộp
		var xf := to_root * mi.global_transform
		var aabb := xf * mi.mesh.get_aabb()
		var key := str(m.get_instance_id())
		var small := false
		var no_shadow := mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or aabb.size.y < 0.06
		if m == model_mat:
			var c := aabb.get_center()
			small = aabb.size.x < 1.5 and aabb.size.y < 1.5 and aabb.size.z < 1.5
			no_shadow = no_shadow or (aabb.size.x < 0.6 and aabb.size.y < 0.6 and aabb.size.z < 0.6)
			key += ":%d:%d:%s" % [floori(c.x / cell), floori(c.z / cell), small]
		if no_shadow:
			key += ":flat"
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = st
			mats[key] = m
			info[key] = [small, no_shadow, m == model_mat]
		tools[key].append_from(mi.mesh, 0, xf)
		mi.mesh = null  # bỏ mesh trước khi xoá node, nếu không bản headless báo 'Parameter "m" is null'
		mi.get_parent().remove_child(mi)
		mi.free()
	for key in tools:
		var out := MeshInstance3D.new()
		out.name = "Merged"
		if info[key][2]:
			var im := ImporterMesh.new()
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, tools[key].commit_to_arrays(), [], {}, mats[key])
			im.generate_lods(25, 60, [])
			out.mesh = im.get_mesh()
		else:
			out.mesh = tools[key].commit()
		out.material_override = mats[key]
		if info[key][0]:
			out.visibility_range_end = 45.0
			out.visibility_range_end_margin = 5.0
			out.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if info[key][1]:
			out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(out)
