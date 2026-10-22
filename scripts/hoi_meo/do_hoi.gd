class_name DoHoi
## Đồ sân Hội mèo G11 (assets/models/chu_nhat, Sang duyệt 22/10/2026, bàn giao
## thiet-ke-man/goi-phac-thao/g11-hoi-meo/BAN-GIAO.md). Màu ở màu đỉnh; số trên cờ, thùng, bảng chấm là
## texture trong mesh so_1…so_N (ẩn hết, hiện đúng số). Vật liệu den_sang (đèn lồng, vòng nhịp) sáng lên buổi tối.

const DIR := "res://assets/models/chu_nhat/%s.glb"
## Clip lặp (glb xuất ra không đánh dấu lặp)
const LOOPS := ["phat", "lac", "bay", "nhip"]
## Socket cổ Bơ (hệ model): gốc huy chương, cùng chỗ cho mọi giống
const NECK := Vector3(0, 0.335, 0.13)
const MEDALS := ["", "huy_chuong_vang", "huy_chuong_bac", "huy_chuong_dong", "huy_chuong_tham_gia"]

static var _scenes := {}
static var _glow: StandardMaterial3D


## Đặt một món dưới parent (toạ độ local của parent); trả node gốc.
static func put(parent: Node, model: String, pos: Vector3, rot_y := 0.0, scale := Vector3.ONE) -> Node3D:
	if not _scenes.has(model):
		_scenes[model] = load(DIR % model)
	var n: Node3D = _scenes[model].instantiate()
	n.name = model
	n.position = pos
	n.rotation.y = rot_y
	n.scale = scale
	parent.add_child(n)
	var web := RenderingServer.get_rendering_device() == null
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var src: Mesh = mi.mesh
		if web:
			mi.mesh = ThuSau._srgb_mesh(src, "chu_nhat:" + model + ":" + str(mi.name))
		for i in src.get_surface_count():
			var m := src.surface_get_material(i)
			if m and m.resource_name == "den_sang":
				mi.set_surface_override_material(i, glow())
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ap: AnimationPlayer in n.find_children("*", "AnimationPlayer", true, false):
		for a in ap.get_animation_list():
			if a in LOOPS:
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	return n


## Đèn lồng, vòng nhịp: màu đỉnh, không đổ bóng, không nhận sáng (tự sáng buổi tối).
static func glow() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.vertex_color_use_as_albedo = true
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _glow


static func anim(n: Node, clip: String, speed := 1.0) -> void:
	if n == null:
		return
	for ap: AnimationPlayer in n.find_children("*", "AnimationPlayer", true, false):
		if ap.has_animation(clip):
			ap.play(clip, -1, speed)
			return


## Hiện số k (1…), ẩn các số khác (mesh so_1, so_1_sau...). k = 0: ẩn hết.
static func number(n: Node, k: int) -> void:
	for mi: MeshInstance3D in n.find_children("so_*", "MeshInstance3D", true, false):
		var s := str(mi.name).trim_prefix("so_").trim_suffix("_sau")
		mi.visible = s.is_valid_int() and int(s) == k


## Đổi màu một vật liệu theo tên (vd cờ đua co_vai cam → xanh khi Bơ đã qua).
static func tint(n: Node, mat_name: String, color: Color) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D and m.resource_name == mat_name:
				var c: StandardMaterial3D = m.duplicate()
				c.albedo_color = color
				mi.set_surface_override_material(i, c)


## Gắn model vào xương `bone` của skel, gốc model đặt ở điểm `at` (hệ model của mèo).
static func attach(skel: Skeleton3D, bone: String, model: String, at: Vector3) -> BoneAttachment3D:
	var bi := skel.find_bone(bone)
	if bi < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skel.add_child(att)
	var holder := Node3D.new()
	holder.transform = skel.get_bone_global_rest(bi).affine_inverse() * Transform3D(Basis(), at)
	att.add_child(holder)
	put(holder, model, Vector3.ZERO)
	return att
