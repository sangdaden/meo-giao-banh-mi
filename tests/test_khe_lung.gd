extends SceneTree
## Đo khe hở giữa đồ đeo lưng và lưng mèo (lỗi cũ: đồ lưng hở khỏi lưng Bơ đực khi thở).
## Mỗi món lưng trên Bơ đực, Bơ cái, ba dáng (đứng thở, ngồi, liếm): khoảng cách nhỏ nhất từ phần cứng của đồ
## (thân túi, thùng, giỏ) tới lông, tính trên lưới đã skin theo tư thế từng khung. Khe nở thêm quá 6 mm so với lúc
## đứng yên là lỗi (đế lót dày vài mm nên khe lúc đứng không bằng 0).
##   godot --headless --path . -s tests/test_khe_lung.gd

const ITEMS := ["tuibanh", "thung", "dongganh", "phaovit", "aochoang", "canhthienthan", "giomay", "camen", "giodan", "baolixi"]
const MAX_GAP := 0.006


func _initialize() -> void:
	_go.call_deferred()


## Vị trí đỉnh (hệ bộ xương) sau khi skin theo tư thế hiện tại. step: lấy một đỉnh mỗi step đỉnh.
static func _skinned(mi: MeshInstance3D, skel: Skeleton3D, step := 1, only := {}) -> PackedVector3Array:
	var out := PackedVector3Array()
	var skin := mi.skin
	var mats := []
	for b in skin.get_bind_count():
		var bi := skin.get_bind_bone(b)
		if bi < 0:
			bi = skel.find_bone(skin.get_bind_name(b))
		mats.append(skel.get_bone_global_pose(bi) * skin.get_bind_pose(b))
	var k := 0
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bo = a[Mesh.ARRAY_BONES]
		var w = a[Mesh.ARRAY_WEIGHTS]
		var n: int = bo.size() / v.size()
		for i in v.size():
			k += 1
			if (step > 1 and k % step != 0) or (not only.is_empty() and not only.has(k)):
				continue
			var p := Vector3.ZERO
			for j in n:
				var ww: float = w[i * n + j]
				if ww > 0.0:
					p += (mats[bo[i * n + j]] * (mi.transform * v[i])) * ww
			out.append(p)
	return out


func _go() -> void:
	var p := BoPreview.new()
	p.show_hint = false
	p.size = Vector2(64, 64)
	root.add_child(p)
	await process_frame
	var c = p.cat
	c.set_process(false)
	p.set_process(false)
	c.preview = true
	var bad := []
	for sex in ["duc", "cai"]:
		for item in ITEMS:
			c.set_breed("bo", {"back": item}, sex)
			var skel: Skeleton3D = c._skel
			var body := OutfitView._body_of(skel)
			var parts := []
			for kind in ["cung", "bam"]:  # món không có phần cứng (cánh, áo choàng): đo phần bám da
				for n in c._acc_nodes:
					for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
						if mi.skin and mi.get_meta("lung", "") == kind:
							parts.append(mi)
				if not parts.is_empty():
					break
			if body == null or parts.is_empty():
				bad.append("%s_%s: không có lưới skin" % [item, sex])
				continue
			# đỉnh lông gần đồ (trong 4 cm lúc đứng): chỉ đo trên vùng này
			var pts := PackedVector3Array()
			for mi in parts:
				pts.append_array(_skinned(mi, skel, 8))
			var cand := {}
			var all := _skinned(body, skel)
			for k in all.size():
				for q in pts:
					if q.distance_squared_to(all[k]) < 0.0016:
						cand[k + 1] = true
						break
			var worst := 0.0
			var where := ""
			var rest := -1.0
			for act in ["", "sit", "lick"]:
				c._action = act
				c._action_timer = 99.0
				for f in 120:
					c._animate(1.0 / 60.0, 0.0, 0.0, true)
					if f % 12 != 11:
						continue
					var fur := _skinned(body, skel, 1, cand)
					var gap := INF
					for mi in parts:
						for q in _skinned(mi, skel, 8):
							for r in fur:
								gap = minf(gap, q.distance_squared_to(r))
					gap = sqrt(gap)
					if rest < 0.0:
						rest = gap
					gap -= rest
					if gap > worst:
						worst = gap
						where = act if act != "" else "dung"
			c._action = ""
			print("%s %s khe lúc đứng %.1f mm, nở thêm nhiều nhất %.1f mm (%s)" % [sex, item, rest * 1000.0, worst * 1000.0, where])
			if worst > MAX_GAP:
				bad.append("%s_%s %.1f mm khi %s" % [item, sex, worst * 1000.0, where])
	if bad.is_empty():
		print("KHE LUNG TEST OK")
	else:
		print("KHE LUNG TEST FAIL: ", bad)
	quit(0 if bad.is_empty() else 1)
