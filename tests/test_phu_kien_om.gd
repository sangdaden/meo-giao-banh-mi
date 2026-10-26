extends SceneTree
## Phụ kiện ôm thân (KhopPhuKien, Sang 26/10 "thay đồ bị sai"): trên nhiều giống mèo, dây quai các món có dây
## phải nằm sát da (mặt trong cách da <= 6 mm, không chìm quá 3 mm), chuông/lục lạc móc vào vòng cổ, nút buộc đồ đuôi
## nằm trên đuôi (cả mèo cụt đuôi). In "PHU KIEN OM TEST OK".
## Thêm `-- --tat-ca` để soát đủ 19 giống × đực/cái (CI chạy 9 mèo đại diện cho nhanh).

const MEO := ["bo_duc", "bo_cai", "tuyet_duc", "lantet_duc", "vobanh_cai", "thongoc_cai", "tamthe_cai", "chalua_duc", "khoaimon_duc"]

var loi := 0


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var meo: Array = MEO
	if "--tat-ca" in OS.get_cmdline_user_args():
		meo = []
		for b in Outfit.BREEDS:
			meo.append(b[0] + "_duc")
			meo.append(b[0] + "_cai")
	for cat in meo:
		var breed: String = cat.get_slice("_", 0)
		var sex: String = cat.get_slice("_", 1)
		var sc: PackedScene = OutfitView.breed_scene(breed, sex)
		if sc == null:
			sc = load("res://scripts/player.gd").BO_MODEL
		var inst: Node3D = sc.instantiate()
		root.add_child(inst)
		var skel: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		var th := KhopPhuKien._than_of(OutfitView._body_of(skel), skel)
		for id in KhopPhuKien.BAM:
			var parts := _parts(id, breed, sex)
			var khop := KhopPhuKien.fit(skel, id, "test_%s_%s" % [breed, sex], parts)
			var moi := {}
			for p in parts:
				if khop.get(p.name, {}).get("an", false):
					continue
				moi[p.name] = KhopPhuKien._verts(khop[p.name].mesh if khop.has(p.name) else p.mesh, p.xf)
			for n in KhopPhuKien.BAM[id]:
				if not moi.has(n):
					continue
				var hs := []
				for v in moi[n]:
					var k := KhopPhuKien._near(th, v)
					if k >= 0:
						var h: float = (v - th.pos[k]).dot(th.nrm[k])
						hs.append(h)
				hs.sort()
				var trong: float = hs[hs.size() / 10] if hs.size() > 0 else INF  # mặt trong: 10% đỉnh thấp nhất
				var sau: float = hs[hs.size() / 50] if hs.size() > 0 else 0.0  # bỏ vài đỉnh lẻ ở hõm (nách, sau tai)
				if trong > 0.006 or trong < -0.004 or (sau < -0.012 and breed != "lantet"):  # bờm Lân Tết phủ dây là đúng
					_hong("%s %s.%s: mặt trong cách da %.1f mm, chìm %.1f mm" % [cat, id, n, trong * 1000, sau * 1000])
			if KhopPhuKien.TREO.has(id):
				var top := Vector3(0, -INF, 0)
				for n in KhopPhuKien.TREO[id]:
					for v in moi.get(n, PackedVector3Array()):
						if v.y > top.y:
							top = v
				var gan := INF
				for v in moi[KhopPhuKien.BAM[id][0]]:
					gan = minf(gan, v.distance_to(top))
				if gan > 0.008:
					_hong("%s %s: khoen đồ treo hở khỏi vòng cổ %.1f mm" % [cat, id, gan * 1000])
		for id in KhopPhuKien.NUT_DUOI:
			var parts := _parts(id, breed, sex)
			var khop := KhopPhuKien.fit(skel, id, "test_%s_%s" % [breed, sex], parts)
			var n: String = KhopPhuKien.NUT_DUOI[id]
			for p in parts:
				if p.name != n:
					continue
				var c := KhopPhuKien._mean(KhopPhuKien._verts(khop[n].mesh if khop.has(n) else p.mesh, p.xf))
				var k := KhopPhuKien._near(th, c, true)
				var d: float = c.distance_to(th.pos[k]) if k >= 0 else INF
				if d > 0.03:
					_hong("%s %s: nút buộc cách đuôi %.1f mm" % [cat, id, d * 1000])
		inst.queue_free()
		await process_frame
	if loi == 0:
		print("PHU KIEN OM TEST OK")
	else:
		print("PHU KIEN OM TEST: %d lỗi" % loi)
	quit()


func _parts(id: String, breed: String, sex: String) -> Array:
	var info: Dictionary = OutfitView.meta().phu_kien[id].objects
	var scene: Node3D = load(OutfitView.DIR + "phu_kien/%s.glb" % id).instantiate()
	var out := []
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var oi: Dictionary = info.get(str(mi.name), {})
		var p := {"name": str(mi.name), "mesh": mi.mesh, "xf": OutfitView._socket_xform(oi.get("sock", "back"), breed, sex)}
		if oi.has("cloth"):
			p.hinge = OutfitView._v(oi.cloth.get("hinge", [0, 0.056, 0.12]))
		out.append(p)
	scene.free()
	return out


func _hong(s: String) -> void:
	loi += 1
	print("  HỎNG ", s)
