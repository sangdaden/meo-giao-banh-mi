class_name Blocks
## Hàm tiện ích dựng khối hộp tạm (placeholder) bằng code.
## Khi có model .glb từ Blender, thay các khối này bằng scene model thật.

static var _materials := {}

## Lớp va chạm: 1 = thế giới lớn (đất, nhà), 2 = mèo, 4 = chó, 8 = đồ nhỏ (thùng, xe, cột, người).
## Camera chỉ né lớp 1, nên đi ngang qua thùng hàng camera không bị giật sát vào lưng mèo.
const LAYER_WORLD := 1
const LAYER_PROP := 8
## Đồ thấp hơn chừng này (m) không đổ bóng (merge_static).
const SMALL_SHADOW := 1.0
## Bản chỉ để đổ bóng (shadow_arrays) bỏ cụm rời nhỏ hơn chừng này (m).
const SHADOW_BIT := 0.6
## Model có meta "ban_xa" (nhà ráp) gộp theo ô FAR_CELL m; ô có tâm xa hơn FAR_SWITCH m thì vẽ bản xa.
const FAR_CELL := 12.0
const FAR_SWITCH := 40.0


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
## Model gộp được sinh LOD (ImporterMesh) để nhà ở xa vẽ ít tam giác hơn.
## Khối mỏng sát đất (vạch kẻ, vỉa hè, vũng nước) và đồ thấp dưới 1 m không đổ bóng. Model có meta "bong_tho" (một Mesh, vd.
## nhà ráp NhaRap.shadow_mesh) thì lượt bóng vẽ mesh đó, gộp riêng theo ô; còn lại đổ bóng bằng chính mesh của nó.
## Model có meta "ban_xa" (một Mesh, vd. NhaRap.far_mesh) gộp theo ô FAR_CELL và đổi sang bản xa khi ô xa hơn FAR_SWITCH.
static func merge_static(root: Node3D, cell := 0.0) -> void:
	var tools := {}
	var shadow_tools := {}
	var far_tools := {}
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
			# Đồ thấp hơn 1 m (thùng, ghế, bàn nhựa, chậu) không đổ bóng; tấm dài sát đất cũng vậy
			no_shadow = no_shadow or (aabb.size.y < SMALL_SHADOW and aabb.size.x < 2.0 and aabb.size.z < 2.0)
			key += ":%d:%d:%s" % [floori(c.x / cell), floori(c.z / cell), small]
		if no_shadow:
			key += ":flat"
		var rough: Mesh = mi.get_meta("bong_tho") if m == model_mat and not no_shadow and mi.has_meta("bong_tho") else null
		if rough:
			key += ":tho"  # ô riêng: bản đủ không đổ bóng, các model khác trong ô vẫn đổ bóng bằng chính nó
		var far: Mesh = mi.get_meta("ban_xa") if m == model_mat and mi.has_meta("ban_xa") else null
		if far:
			# Ô nhỏ hơn cho nhà có bản xa: tầm nhìn tính từ tâm ô, ô nhỏ thì căn gần nhất của ô xa không quá gần camera
			var fc := aabb.get_center()
			key += ":xa%d:%d" % [floori(fc.x / FAR_CELL), floori(fc.z / FAR_CELL)]
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = st
			mats[key] = m
			info[key] = [small, no_shadow, m == model_mat]
		tools[key].append_from(mi.mesh, 0, xf)
		if rough:
			if not shadow_tools.has(key):
				shadow_tools[key] = SurfaceTool.new()
				shadow_tools[key].begin(Mesh.PRIMITIVE_TRIANGLES)
			if rough.get_surface_count() > 0:
				shadow_tools[key].append_from(rough, 0, xf)
		if far and far.get_surface_count() > 0:
			if not far_tools.has(key):
				far_tools[key] = SurfaceTool.new()
				far_tools[key].begin(Mesh.PRIMITIVE_TRIANGLES)
			far_tools[key].append_from(far, 0, xf)
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
		if info[key][1] or shadow_tools.has(key):
			out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(out)
		if far_tools.has(key):
			# Ô nhà xa hơn FAR_SWITCH (tính từ tâm ô) vẽ bản xa (~300 tam giác mỗi căn) thay bản đủ (~2 300)
			out.visibility_range_end = FAR_SWITCH
			out.visibility_range_end_margin = 2.0
			var fx := MeshInstance3D.new()
			fx.name = "BanXa"
			fx.mesh = far_tools[key].commit()
			fx.material_override = mats[key]
			fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fx.visibility_range_begin = FAR_SWITCH
			fx.visibility_range_begin_margin = 2.0
			root.add_child(fx)
		if shadow_tools.has(key):
			# Lượt bóng vẽ bản thô của ô (bỏ chi tiết vụn), bản đủ chỉ vẽ ở lượt chính
			var sh := MeshInstance3D.new()
			sh.name = "BongTho"
			sh.mesh = shadow_tools[key].commit()
			sh.material_override = mats[key]
			sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			sh.visibility_range_end = out.visibility_range_end
			root.add_child(sh)


## Bản chỉ để đổ bóng của một mặt mesh (arrays có chỉ số đỉnh): bỏ những cụm tam giác rời (nối nhau qua đỉnh trùng vị trí)
## có cạnh hộp bao dài nhất dưới bit mét: khung cửa, chậu, máy lạnh, gờ, chữ nổi, bóng đèn. Tường, sàn, mái, mái hiên giữ
## nguyên chỗ nên bóng trên đường và gầm tiệm như cũ. Trả về arrays chỉ có vị trí, pháp tuyến, chỉ số.
static func shadow_arrays(a: Array, bit := SHADOW_BIT) -> Array:
	var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var pi: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if pi.is_empty():
		pi.resize(pv.size())
		for k in pv.size():
			pi[k] = k
	# Hàn đỉnh trùng vị trí (mặt hộp tách pháp tuyến nên đỉnh bị nhân đôi), rồi gom cụm bằng union-find
	var weld := {}
	var vid := PackedInt32Array()
	vid.resize(pv.size())
	for k in pv.size():
		var wk := Vector3i((pv[k] * 1000.0).round())
		if not weld.has(wk):
			weld[wk] = weld.size()
		vid[k] = weld[wk]
	var par := PackedInt32Array()
	par.resize(weld.size())
	for k in par.size():
		par[k] = k
	for t in range(0, pi.size(), 3):
		var r0 := _root(par, vid[pi[t]])
		for j in [1, 2]:
			var r := _root(par, vid[pi[t + j]])
			if r != r0:
				par[r] = r0
	var boxes := {}
	for t in range(0, pi.size(), 3):
		var r := _root(par, vid[pi[t]])
		var b: AABB = boxes.get(r, AABB(pv[pi[t]], Vector3.ZERO))
		for j in 3:
			b = b.expand(pv[pi[t + j]])
		boxes[r] = b
	var keep := PackedInt32Array()
	for t in range(0, pi.size(), 3):
		var sz: Vector3 = (boxes[_root(par, vid[pi[t]])] as AABB).size
		if maxf(sz.x, maxf(sz.y, sz.z)) >= bit:
			keep.append_array([pi[t], pi[t + 1], pi[t + 2]])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = pv
	out[Mesh.ARRAY_NORMAL] = a[Mesh.ARRAY_NORMAL]
	out[Mesh.ARRAY_INDEX] = keep
	return out


## Mesh chỉ để đổ bóng (shadow_arrays cho mọi mặt, gộp một mặt). Rỗng nếu không còn gì.
static func shadow_mesh(src: Mesh, bit := SHADOW_BIT) -> ArrayMesh:
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in src.get_surface_count():
		var a := shadow_arrays(src.surface_get_arrays(i), bit)
		var base := v.size()
		v.append_array(a[Mesh.ARRAY_VERTEX])
		nm.append_array(a[Mesh.ARRAY_NORMAL])
		for k: int in a[Mesh.ARRAY_INDEX]:
			idx.append(base + k)
	var out := ArrayMesh.new()
	if not idx.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = nm
		arrays[Mesh.ARRAY_INDEX] = idx
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


static func _root(par: PackedInt32Array, i: int) -> int:
	while par[i] != i:
		par[i] = par[par[i]]
		i = par[i]
	return i
