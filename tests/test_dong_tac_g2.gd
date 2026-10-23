extends SceneTree
## Kiểm tra 18 động tác Blender G2 (Sang duyệt 21/10) trong game: số liệu khớp bộ xương Bơ,
## play_clip chạy đủ, leo mép/ống dùng động tác Blender với chân đặt đúng chỗ, túi 3 ổ ngậm ở miệng.
## Chạy: godot --headless --path . -s tests/test_dong_tac_g2.gd

const PlayerScript := preload("res://scripts/player.gd")
const CLIPS := ["bam_mep", "keo_len", "leo_ong", "dap_tuong", "thang_bang", "truot_chan", "roi_van", "giu_nuoc",
	"ngoi_goi", "ngam_tui", "chup_vay", "chup_nam", "chup_dung", "phoi_nang", "ngu_cuon", "nhan_huy_chuong", "dua_tui", "nhan_tui"]

var bo: CharacterBody3D
var fails := 0


func _init() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "sneak", "deliver"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	_run.call_deferred()


func _box(size: Vector3, pos: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	b.position = pos
	root.add_child(b)


func _check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  LỖI  ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _place(p: Vector3) -> void:
	bo.climb = ""
	bo.global_position = p
	bo.velocity = Vector3.ZERO
	await _frames(8)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


## Vị trí xương trong thế giới (đã gồm dáng đang đặt)
func _bone_pos(bone_name: String) -> Vector3:
	var sk: Skeleton3D = bo._skel
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone_name)).origin


func _run() -> void:
	_box(Vector3(60, 1, 60), Vector3(0, -0.5, 0))
	# Tường mép 2,0 m, mặt tường ở z = -2,5
	_box(Vector3(3, 2.0, 1), Vector3(0, 1.0, -3))
	bo = PlayerScript.new()
	root.add_child(bo)
	bo.can_move = true
	bo.climb_moves = true
	await _place(Vector3(0, 0.05, 0))

	print("Số liệu động tác:")
	var data: Dictionary = PlayerScript.dong_tac()
	var clips: Dictionary = data.get("clips", {})
	_check(clips.size() >= 18, "đủ 18 động tác G2, có thêm động tác sau (%d)" % clips.size())
	var missing := []
	for n in CLIPS:
		if not clips.has(n):
			missing.append(n)
	_check(missing.is_empty(), "có đủ tên động tác %s" % [missing])
	# Dáng nghỉ trong số liệu phải trùng bộ xương của bo.glb, không thì động tác lệch
	var sk: Skeleton3D = bo._skel
	var worst := 0.0
	for bone_name: String in data.rest:
		var idx := sk.find_bone(bone_name)
		if idx < 0:
			worst = 99.0
			continue
		var r: Array = data.rest[bone_name].r
		var q := Quaternion(r[0], r[1], r[2], r[3])
		var rq := sk.get_bone_rest(idx).basis.get_rotation_quaternion()
		worst = maxf(worst, rad_to_deg(q.angle_to(rq)))
	_check(worst < 0.5, "dáng nghỉ khớp bo.glb (lệch tối đa %.2f°)" % worst)

	print("Chạy từng động tác:")
	var finished := []
	bo.clip_finished.connect(func(n): finished.append(n))
	for n: String in CLIPS:
		if n in PlayerScript.CLIMB_CLIPS:
			continue  # chỉ chạy khi đang leo, thử ở dưới
		var c: Dictionary = clips[n]
		bo.play_clip(n)
		await _frames(int(c.dur * 30.0))  # nửa động tác, đã vào hẳn (0,12 s)
		# Bơ là mèo gốc: dáng hông phải đúng khung trong số liệu
		var want: Quaternion = PlayerScript._clip_q(c.bones.hips.r, bo._clip_t * 30.0)
		var got: Quaternion = sk.get_bone_pose_rotation(sk.find_bone("hips"))
		var err := rad_to_deg(want.angle_to(got))
		var ok: bool = bo.clip == n and err < 1.0
		if c.loop:
			bo.stop_clip()
		await _frames(int(c.dur * 30.0) + 20)
		ok = ok and bo.clip == "" and (c.loop or finished.has(n))
		_check(ok, "%s (%.1f s%s): hông lệch %.2f°, xong về dáng code" % [n, c.dur, ", lặp" if c.loop else "", err])

	print("Bám mép, kéo lên (bam_mep, keo_len):")
	await _place(Vector3(0, 0.05, 0))
	Input.action_press("move_forward")
	await _frames(6)
	Input.action_press("jump")
	for i in 72:
		await physics_frame
		if bo.climb == "hang":
			break
	Input.action_release("jump")
	Input.action_release("move_forward")
	await _frames(30)
	_check(bo.climb == "hang" and bo.clip == "bam_mep", "đang bám, chạy bam_mep")
	var fl := _bone_pos("paw_FL")
	var fr := _bone_pos("paw_FR")
	_check(absf(fl.y - 2.0) < 0.1 and absf(fr.y - 2.0) < 0.1, "hai chân trước đặt trên mặt mép (y = %.2f, %.2f; mép 2,0)" % [fl.y, fr.y])
	_check(fl.z < -2.4 and fl.z > -2.75, "chân trước ở mép tường (z = %.2f; mặt tường -2,5)" % fl.z)
	var hb := _bone_pos("paw_BL")
	_check(hb.z > -2.5, "chân sau không xuyên tường (z = %.2f)" % hb.z)
	var last := _bone_pos("chest")
	var jump_max := 0.0
	await _tap("jump")
	var after := 0
	for i in 400:
		await process_frame
		after += 1 if bo.climb == "" else 0
		if after > 30:
			break
		var p := _bone_pos("chest")
		if bo.climb == "pull":
			jump_max = maxf(jump_max, p.distance_to(last))
		last = p
	_check(bo.climb == "" and absf(bo.global_position.y - 2.0) < 0.1, "lên mép (y = %.2f)" % bo.global_position.y)
	_check(jump_max < 0.04, "kéo lên: ngực đi liền mạch, không giật (bước lớn nhất %.3f m/nhịp)" % jump_max)
	await _frames(20)
	var rp: Vector3 = sk.get_bone_pose_position(sk.find_bone("root"))
	_check(bo.clip == "" and rp.length() < 0.06, "đứng trên mép về dáng thường (gốc lệch %.3f m)" % rp.length())

	print("Ôm ống (leo_ong):")
	_box(Vector3(3, 8, 1), Vector3(22, 4, -10.5))
	var pipe := Area3D.new()
	pipe.position = Vector3(22, 0, -9.92)
	pipe.collision_mask = 2
	pipe.set_meta("normal", Vector3.BACK)
	pipe.set_meta("top", 6.0)
	var ps := CollisionShape3D.new()
	var pb := BoxShape3D.new()
	pb.size = Vector3(0.5, 6, 0.6)
	ps.shape = pb
	ps.position.y = 3.0
	pipe.add_child(ps)
	pipe.body_entered.connect(func(b): if b.has_method("enter_pipe"): b.enter_pipe(pipe))
	pipe.body_exited.connect(func(b): if b.has_method("exit_pipe"): b.exit_pipe(pipe))
	root.add_child(pipe)
	await _place(Vector3(22, 0.05, -8.5))
	Input.action_press("move_forward")
	await _frames(90)
	_check(bo.climb == "pipe" and bo.clip == "leo_ong", "đang ôm ống, chạy leo_ong")
	var t0: float = bo._clip_t
	await _frames(10)
	_check(not is_equal_approx(t0, bo._clip_t), "động tác chạy theo tốc độ leo")
	var worst_paw := 0.0
	for b in ["paw_FL", "paw_FR"]:
		var p := _bone_pos(b)
		worst_paw = maxf(worst_paw, Vector2(p.x - 22.0, p.z + 9.92).length())
	_check(worst_paw < 0.16, "chân trước ôm quanh ống (xa trục ống nhất %.2f m)" % worst_paw)
	Input.action_release("move_forward")
	await _frames(4)
	var t1: float = bo._clip_t
	await _frames(10)
	_check(is_equal_approx(t1, bo._clip_t), "đứng yên trên ống thì động tác dừng")
	await _tap("jump")
	await _frames(40)
	_check(bo.climb == "" and bo.clip == "", "nhảy khỏi ống về dáng thường")

	print("Túi 3 ổ:")
	await _place(Vector3(5, 0.05, 5))
	bo.carry_tui3(true)
	await _frames(10)
	var tui: Node3D = bo._tui3
	_check(is_instance_valid(tui) and tui.visible, "túi hiện ở miệng")
	if is_instance_valid(tui):
		var up: Vector3 = bo._tui3_hang.global_basis.y.normalized()
		_check(up.dot(Vector3.UP) > 0.95, "túi thòng thẳng đứng (lệch %.0f°)" % rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1, 1))))
		var mouth: Vector3 = bo._tui3_hang.global_position
		var head := _bone_pos("head")
		_check(mouth.distance_to(head) < 0.25 and mouth.y > 0.25, "quai ở miệng (cách gốc đầu %.2f m, cao %.2f m)" % [mouth.distance_to(head), mouth.y])
	bo.play_clip("dua_tui")
	await _frames(80)
	_check(not bo._tui3_on and not tui.visible, "đưa túi xong: hết ngậm")
	bo.play_clip("nhan_tui")
	await _frames(80)
	_check(bo._tui3_on and tui.visible, "nhận túi xong: ngậm lại")
	bo.carry_tui3(false)
	await _frames(4)
	_check(not tui.visible, "nhả túi")

	print("Đổi giống mèo vẫn chạy động tác:")
	bo.set_breed("xiem")
	await _frames(4)
	bo.play_clip("ngoi_goi")
	await _frames(20)
	_check(bo.clip == "ngoi_goi", "Xiêm chạy ngoi_goi")
	bo.carry_tui3(true)
	await _frames(4)
	_check(is_instance_valid(bo._tui3) and bo._tui3.visible, "Xiêm ngậm túi 3 ổ")

	print("KẾT QUẢ: ", "TẤT CẢ OK" if fails == 0 else "%d LỖI" % fails)
	quit(0 if fails == 0 else 1)
