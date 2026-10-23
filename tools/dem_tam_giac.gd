extends SceneTree
## Chẩn đoán tam giác ở một góc camera (docs/ngan-sach-hieu-nang.md, mục "Đo xem cái gì ngốn tam giác").
## Dựng lại khu phố (City.build) chưa gộp, gom từng model/khối theo tên, ước số tam giác LOD0 trong khung nhìn
## và số tam giác các vật đổ bóng trong tầm bóng web. Thêm phần động (người, xe, ly...) của màn chơi thật.
## Nhà ráp còn được chia theo khoảng cách từ camera tới tâm ô gộp (để biết bản xa giúp được bao nhiêu).
## --tat: tắt từng nhóm lớn rồi đo lại (số thật, đã tính LOD, bản xa, bản bóng).
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
##     -s tools/dem_tam_giac.gd -- [--goc=pho_nga_tu] [--bong=26] [--tat]

const SHOTS := {
	"pho_bo_can_canh": [Vector3(-32.0, 0.75, -1.9), Vector3(-33, 0.3, -3.3)],
	"pho_lo_banh": [Vector3(-33, 1.7, -1.0), Vector3(-33, 0.9, -6.5)],
	"pho_nga_tu": [Vector3(-24, 1.8, 2.5), Vector3(-10, 0.8, -1.0)],
	"pho_duong_ngang": [Vector3(-6, 1.7, 1.5), Vector3(14, 1.0, 0.0)],
	"pho_ca_phe": [Vector3(-1.0, 1.7, 1.0), Vector3(5.4, 0.6, 5.4)],
	"pho_sua_xe": [Vector3(30.6, 1.7, 30.0), Vector3(30.6, 0.8, 24.0)],
}

var cache := {}
var names := {}
var far_hist := {}


func _initialize() -> void:
	_run.call_deferred()


func _tris(m: Mesh) -> int:
	if cache.has(m):
		return cache[m]
	var t := 0
	for i in m.get_surface_count():
		var a := m.surface_get_arrays(i)
		var idx = a[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null and idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	cache[m] = t
	return t


func _name_of(gi: GeometryInstance3D, base: Node) -> String:
	if gi is MeshInstance3D and names.has(gi.mesh):
		return names[gi.mesh]
	var n := String(gi.name)
	if n.begins_with("@"):
		var p := gi.get_parent()
		while p and p != base and String(p.name).begins_with("@"):
			p = p.get_parent()
		n = (String(p.name) if p and p != base else "") + "/" + gi.get_class()
		if gi is MeshInstance3D and gi.mesh is BoxMesh:
			n = "khoi_hop"
	return n.rstrip("0123456789")


func _scan(base: Node, cam: Camera3D, shadow_dist: float, groups: Dictionary, tag: String) -> void:
	var planes := cam.get_frustum()
	for gi: GeometryInstance3D in base.find_children("*", "GeometryInstance3D", true, false):
		if not gi.is_visible_in_tree() and tag == "dong":
			continue
		var aabb := gi.global_transform * gi.get_aabb()
		var inside := true
		for p in planes:
			if p.distance_to(aabb.get_support(-p.normal)) > 0.0:
				inside = false
				break
		var d := cam.global_position.clamp(aabb.position, aabb.end).distance_to(cam.global_position)
		if gi.visibility_range_end > 0.0 and d > gi.visibility_range_end + gi.visibility_range_end_margin:
			continue
		var t := 0
		if gi is MeshInstance3D and gi.mesh:
			t = _tris(gi.mesh)
		elif gi is MultiMeshInstance3D and gi.multimesh and gi.multimesh.mesh:
			var cnt: int = gi.multimesh.visible_instance_count
			t = _tris(gi.multimesh.mesh) * (cnt if cnt >= 0 else gi.multimesh.instance_count)
		if t == 0:
			continue
		var key := tag + " " + _name_of(gi, base)
		var shadow := gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if tag == "pho" and shadow:
			# merge_static: đồ dưới 0,6 m và tấm mỏng sát đất không đổ bóng
			shadow = aabb.size.y >= 0.06 and not (aabb.size.x < 0.6 and aabb.size.y < 0.6 and aabb.size.z < 0.6)
		if not groups.has(key):
			groups[key] = [0, 0, 0, 0, 0.0]
		var g: Array = groups[key]
		if inside:
			g[0] += t
			g[1] += 1
			if key == "pho nha_rap":
				var cc := aabb.get_center()
				var center := Vector3((floori(cc.x / Blocks.FAR_CELL) + 0.5) * Blocks.FAR_CELL, cam.global_position.y,
					(floori(cc.z / Blocks.FAR_CELL) + 0.5) * Blocks.FAR_CELL)
				var b := "nha_rap ô cách %d+ m" % (floori(cam.global_position.distance_to(center) / 10.0) * 10)
				far_hist[b] = far_hist.get(b, 0) + t
		if shadow and d < shadow_dist:
			g[2] += t
			g[3] += 1
		g[4] = maxf(g[4], aabb.size.y)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var goc := "pho_nga_tu"
	var shadow_dist := 26.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--goc="):
			goc = a.substr(6)
		elif a.begins_with("--bong="):
			shadow_dist = float(a.substr(7))
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 10:
		await process_frame
	for layer in scene.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 300.0
	scene.add_child(cam)
	cam.make_current()
	cam.position = SHOTS[goc][0]
	cam.look_at(SHOTS[goc][1])
	var tri := 0
	var st := 0
	for i in 15:
		await process_frame
		tri = maxi(tri, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		st = maxi(st, root.get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
	print("[dem] %s: đo thật tổng %d, bóng %d" % [goc, tri, st])
	var groups := {}
	# Phần động của màn chơi (thêm sau merge_static): người, xe, ly, Bơ...
	for c in scene.get_children():
		if c is Node3D and String(c.name) != "Merged" and not String(c.name).begins_with("@"):
			_scan(c, cam, shadow_dist, groups, "dong")
	# Khu phố dựng lại, chưa gộp: tên model
	for k in PhoModels._meshes:
		if PhoModels._meshes[k]:
			names[PhoModels._meshes[k]] = String(k).get_file().get_basename()
	for k in NhaRap._houses:
		names[NhaRap._houses[k]] = "nha_rap"
	var city := Node3D.new()
	city.visible = false
	scene.add_child(city)
	City.build(city)
	for k in PhoModels._meshes:
		if PhoModels._meshes[k]:
			names[PhoModels._meshes[k]] = String(k).get_file().get_basename()
	for k in NhaRap._houses:
		names[NhaRap._houses[k]] = "nha_rap"
	_scan(city, cam, shadow_dist, groups, "pho")
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a][0] + groups[a][2] > groups[b][0] + groups[b][2])
	var sum := [0, 0]
	print("[dem] %-44s %8s %4s | %8s %4s | %5s" % ["nhóm", "tg khung", "số", "tg bóng", "số", "cao"])
	for k in keys:
		var g: Array = groups[k]
		sum[0] += g[0]
		sum[1] += g[2]
		if g[0] + g[2] > 1500:
			print("[dem] %-44s %8d %4d | %8d %4d | %5.1f" % [k, g[0], g[1], g[2], g[3], g[4]])
	print("[dem] ước LOD0: khung %d, bóng %d" % sum)
	var fk := far_hist.keys()
	fk.sort()
	for k in fk:
		print("[dem] %s: %d" % [k, far_hist[k]])
	city.free()
	if "--tat" in OS.get_cmdline_user_args():
		await _toggles(scene, tri, st)
	quit(0)


## Tắt từng nhóm, đo lại: số tam giác thật bớt được (đã tính LOD).
func _toggles(scene: Node, tri: int, st: int) -> void:
	var sets := {
		"ly cà phê": scene.find_children("ly_caphe*", "", true, false),
		"người có xương": scene.find_children("Nguoi_*", "", true, false),
		"Bơ": [scene.get_node("Bo")],
		"giao thông": [scene.get_node_or_null("GiaoThong")],
		"vành phố": [scene.get_node_or_null("VanhPho")],
		"chi tiết phố": scene.get_children().filter(func(c): return String(c.name).begins_with("ChiTietPho")),
		"đồ gắn tường + chữ": scene.get_children().filter(func(c): return String(c.name).begins_with("DoGanTuong") or String(c.name).begins_with("ChuBangHieu")),
		"gộp: có bóng": scene.get_children().filter(func(c): return c is MeshInstance3D and String(c.name).begins_with("@") and c.cast_shadow == 1 and c.material_override == PhoModels.material()),
		"gộp: bản bóng thô": scene.get_children().filter(func(c): return c is MeshInstance3D and c.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY),
		"gộp: không bóng": scene.get_children().filter(func(c): return c is MeshInstance3D and String(c.name).begins_with("@") and c.cast_shadow == 0 and c.material_override == PhoModels.material()),
		"gộp: khối hộp": scene.get_children().filter(func(c): return c is MeshInstance3D and String(c.name).begins_with("@") and c.material_override != PhoModels.material()),
	}
	for k in sets:
		var arr: Array = sets[k].filter(func(n): return n != null and n.visible)
		for n in arr:
			n.visible = false
		var t2 := 0
		var s2 := 0
		for i in 12:
			await process_frame
			t2 = maxi(t2, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
			s2 = maxi(s2, root.get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
		for n in arr:
			n.visible = true
		print("[dem] tắt %-22s (%3d nút): bớt %7d, trong đó bóng %7d" % [k, arr.size(), tri - t2, st - s2])
