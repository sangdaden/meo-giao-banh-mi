class_name MoHinhConVat
## Model con vật mới V1–V6 (luồng "Phác thảo con vật mới", Sang duyệt 23/10/2026, trang
## https://claude.ai/artifact/HhyiCtnuF7vQRNnWeePBxv, bàn giao tuong-tac-con-vat/phac-thao/BAN-GIAO.md).
## File ở assets/models/con_vat/. glTF Y lên, mét, mặt trước nhìn +Z, gốc giữa chân trên mặt đất.
## Vật liệu: lông màu đỉnh (*_mau), mắt bóng màu đỉnh (*_mat), cánh texture (*_tex), kính/nước (*_kinh).
## Con nhỏ: không đổ bóng, tắt khi xa (view_end).

const DIR := "res://assets/models/con_vat/%s.glb"

static var _scenes := {}
static var _mats := {}
static var _meshes := {}


## Đặt một model; trả node gốc. view_end <= 0 thì không giới hạn tầm nhìn.
static func put(parent: Node, model: String, pos := Vector3.ZERO, rot_y := 0.0, view_end := 20.0) -> Node3D:
	if not _scenes.has(model):
		_scenes[model] = load(DIR % model)
	var n: Node3D = _scenes[model].instantiate()
	n.name = model
	parent.add_child(n)
	n.position = pos
	n.rotation.y = rot_y
	var web := RenderingServer.get_rendering_device() == null
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var src: Mesh = mi.mesh
		mi.mesh = _mesh(src, model + ":" + str(mi.name), web)
		for i in src.get_surface_count():
			mi.set_surface_override_material(i, _material(src.surface_get_material(i)))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if view_end > 0.0:
			mi.visibility_range_end = view_end
			mi.visibility_range_end_margin = 2.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return n


## Bản web đổi màu đỉnh sang sRGB (như ThuSau._srgb_mesh). Cánh bướm, chuồn chuồn: file xuất UV texture ở kênh
## TEXCOORD_1 (texCoord -1 trong vật liệu), Godot đọc UV kênh 0 nên cánh đen; chép UV2 sang UV cho mặt cánh.
static func _mesh(src: Mesh, key: String, web: bool) -> Mesh:
	var wing := false
	for i in src.get_surface_count():
		var m := src.surface_get_material(i)
		wing = wing or (m != null and m.resource_name.ends_with("_tex"))
	if not web and not wing:
		return src
	if _meshes.has(key):
		return _meshes[key]
	var dst := ArrayMesh.new()
	for i in src.get_surface_count():
		var arrays := src.surface_get_arrays(i)
		var m := src.surface_get_material(i)
		if web and arrays[Mesh.ARRAY_COLOR] != null:
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for c in cols.size():
				cols[c] = cols[c].linear_to_srgb()
			arrays[Mesh.ARRAY_COLOR] = cols
		if m != null and m.resource_name.ends_with("_tex") and arrays[Mesh.ARRAY_TEX_UV2] != null:
			arrays[Mesh.ARRAY_TEX_UV] = arrays[Mesh.ARRAY_TEX_UV2]
		dst.add_surface_from_arrays(src.surface_get_primitive_type(i), arrays, [], {}, src.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		dst.surface_set_material(i, m)
	_meshes[key] = dst
	return dst


static func _material(src: Material) -> Material:
	var key := src.resource_name if src else ""
	var kind := "mau"
	if key.ends_with("_mat"):
		kind = "mat"
	elif key.ends_with("_tex") or key.ends_with("_kinh"):
		kind = key  # cánh, kính: giữ texture và alpha của file, chỉ cho vẽ hai mặt
	if _mats.has(kind):
		return _mats[kind]
	var m: BaseMaterial3D
	if kind in ["mau", "mat"]:
		m = StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85 if kind == "mau" else 0.18
		if kind == "mat":
			m.metallic_specular = 0.8
	else:
		m = (src as BaseMaterial3D).duplicate() if src is BaseMaterial3D else StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[kind] = m
	return m


static func anim(n: Node) -> AnimationPlayer:
	var list := n.find_children("*", "AnimationPlayer", true, false)
	return list[0] if not list.is_empty() else null


## Chạy clip; loop = lặp. blend: giây chuyển mượt. Clip không có thì bỏ qua.
static func play(n: Node, clip: String, loop := true, blend := 0.2, speed := 1.0) -> void:
	var ap := anim(n)
	if ap == null or not ap.has_animation(clip):
		return
	ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	if ap.current_animation == clip and ap.is_playing():
		return
	ap.play(clip, blend, speed)


## Đang chạy clip một lần và chưa xong
static func busy(n: Node) -> bool:
	var ap := anim(n)
	return ap != null and ap.is_playing() and ap.get_animation(ap.current_animation).loop_mode == Animation.LOOP_NONE


## Chữ nhỏ bay lên trên đầu con vật (Label3D tự dịch)
static func pop_text(parent: Node3D, text: String, height := 0.4, secs := 1.4) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.004
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color("#FFF6D8")
	l.outline_modulate = Color(0.15, 0.1, 0.05, 0.9)
	parent.add_child(l)
	l.position = Vector3(0, height, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", height + 0.35, secs)
	tw.parallel().tween_property(l, "modulate:a", 0.0, secs).set_delay(secs * 0.5)
	tw.tween_callback(l.queue_free)
