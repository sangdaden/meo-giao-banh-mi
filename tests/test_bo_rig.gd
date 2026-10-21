extends SceneTree
## Kiểm tra bộ xương chính thức 22 xương của Bơ (tools/bo_game.py) và IK chân trong player.gd:
## đủ xương, bàn chân đứng yên trên đất khi thân hạ/ngả, khuỷu và gối gập khi chui, chiều cao từng tư thế
## (tính bằng skin trên CPU, đúng như GPU vẽ). Chạy: godot --headless --path . -s tests/test_bo_rig.gd

const PlayerScript := preload("res://scripts/player.gd")
const BONES_22 := ["root", "hips", "chest", "head", "ear_L", "ear_R", "tail_1", "tail_2", "tail_3", "tail_4",
	"upperarm_FL", "forearm_FL", "paw_FL", "upperarm_FR", "forearm_FR", "paw_FR",
	"thigh_BL", "shin_BL", "paw_BL", "thigh_BR", "shin_BR", "paw_BR"]

var fails := 0
var bo


func _initialize() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "sneak", "deliver"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1


## Diễn n khung hình ở một trạng thái (không chạy vật lý).
func _pose(stance: String, act := "", kind := "", act_t := 0.0, speed := 0.0) -> void:
	bo.stance = stance
	for i in 90:
		if act != "":
			bo._act = act
			bo._act_kind = kind
			bo._act_len = 0.6 if act == "startle" else 1.6
			bo._act_t = act_t
		bo._animate(1.0 / 60.0, speed, 0.0, true)


## Chiều cao cao nhất của lưới Bơ sau khi skin (hệ _body, đã tính tỉ lệ nén thân).
func _height() -> float:
	var sk: Skeleton3D = bo._skel
	var top := 0.0
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null:
			continue
		var skin_bones := []
		for b in mi.skin.get_bind_count():
			var bi := sk.find_bone(mi.skin.get_bind_name(b)) if mi.skin.get_bind_name(b) != "" else mi.skin.get_bind_bone(b)
			skin_bones.append(sk.get_bone_global_pose(bi) * mi.skin.get_bind_pose(b))
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / verts.size()
			for v in verts.size():
				var p := Vector3.ZERO
				for k in per:
					var w := weights[v * per + k]
					if w > 0.0:
						p += (skin_bones[bones[v * per + k]] * verts[v]) * w
				top = maxf(top, p.y)
	return top * bo._body.scale.y


func _paws_on_ground(what: String, legs := [0, 1, 2, 3]) -> void:
	var worst := 0.0
	for i in legs:
		var g: Vector3 = bo._skel.get_bone_global_pose(bo._leg_rig[i].ids[2]).origin
		worst = maxf(worst, absf(g.y - 0.04))
	_check(worst < 0.012, "%s: cổ chân cách chỗ chạm đất ≤ 1,2 cm (lệch %.3f m)" % [what, worst])


func _run() -> void:
	bo = PlayerScript.new()
	root.add_child(bo)
	await process_frame
	bo.set_process(false)
	bo.set_physics_process(false)
	var sk: Skeleton3D = bo._skel

	print("Bộ xương:")
	var missing := []
	for n in BONES_22:
		if sk.find_bone(n) < 0:
			missing.append(n)
	_check(missing.is_empty() and BONES_22.size() == 22, "đủ 22 xương chính %s" % [missing])
	_check(sk.get_bone_count() == 25, "thêm 3 xương phụ mắt, khăn (%d xương)" % sk.get_bone_count())
	_check(bo._leg_rig.size() == 4, "4 chân có IK")

	print("Đứng:")
	_pose("walk")
	var h_stand := _height()
	_check(absf(h_stand - 0.6) < 0.03, "cao tới chóp tai %.2f m (chuẩn 0,60)" % h_stand)
	_paws_on_ground("đứng")

	print("Chui:")
	_pose("crouch")
	var h := _height()
	_check(h <= crouch_limit(), "cao %.3f m ≤ 0,25 m (lọt gầm)" % h)
	_paws_on_ground("chui")
	var elbow := absf(sk.get_bone_pose_rotation(sk.find_bone("forearm_FL")).get_angle())
	var knee := absf(sk.get_bone_pose_rotation(sk.find_bone("shin_BL")).get_angle())
	_check(elbow > 0.3 and knee > 0.3, "khuỷu gập %.0f°, gối gập %.0f°" % [rad_to_deg(elbow), rad_to_deg(knee)])

	print("Rón rén:")
	_pose("sneak")
	h = _height()
	_check(h < h_stand - 0.03 and h > 0.38, "thấp hơn đứng: %.2f m (bản phác 0,44)" % h)
	_paws_on_ground("rón rén đứng yên")

	print("Giao cao:")
	_pose("walk", "deliver", "hand", 0.75)
	h = _height()
	_check(h > h_stand, "ngồi dậy cao %.2f m (bản phác 0,64)" % h)
	_paws_on_ground("giao cao, hai chân sau", [2, 3])

	print("Giật mình:")
	_pose("walk", "startle", "", 0.3)
	_paws_on_ground("giật mình")
	bo._act = ""
	print("KẾT QUẢ: " + ("TẤT CẢ OK" if fails == 0 else "%d LỖI" % fails))
	quit(1 if fails else 0)


func crouch_limit() -> float:
	return bo.crouch_height
