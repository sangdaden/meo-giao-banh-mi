class_name ViecNho
extends Node3D
## Một việc nhờ trong Sổ hàng xóm Thứ Bảy (scripts/thu_bay.gd gọi). Không đồng hồ, không thua.
## Phần lớn việc là "tìm đồ": danh sách điểm (targets) Bơ phải chạm tới, theo thứ tự hoặc không, có khi phải
## mang từng món về một chỗ (carry_each) hay mang cả về người nhờ (return_to). Mỗi việc là một file nhỏ kế thừa,
## chỉ đặt điểm và lời nhắc trong begin(); việc khác kiểu (chọn nhân, tạo dáng, ru em bé) tự viết tick().
## Đồ là khối tạm, chờ model G8 (phác thảo việc nhờ Thứ Bảy).

signal finished

## ThuBay đang chạy: main, player, hud, toast(), task_line()
var day: Node
var player: CharacterBody3D
## Dòng việc trên HUD
var line := ""

## Mỗi điểm: {"pos", "node", "got", "reach" (ngang), "reach_y" (dọc), "need_crouch", "hint" (Label3D)}
var targets: Array = []
var ordered := false
var carry_each := false
var return_to := Vector3.INF
var return_name := ""
## Chữ gợi ý hiện cạnh điểm khi Bơ tới gần trong hint_radius ("hi hi", "leng keng")
var hint_text := ""
var hint_radius := 0.0
## Điểm chỉ hiện khi Bơ tới gần trong reveal_radius (con ốc phát sáng); INF = luôn hiện
var reveal_radius := INF
var carry_model: Node3D       ## món Bơ đang ngậm (bám theo miệng)

var _state := "find"          ## find | return | done
var _carry_proto: Callable    ## dựng hình món ngậm
var _index := 0


func setup(thu_bay: Node) -> void:
	day = thu_bay
	player = thu_bay.player


## Dựng điểm, gán line. Lớp con viết lại.
func begin() -> void:
	pass


func tick(delta: float) -> void:
	_tick_targets(delta)


## Autotest: chỗ đứng kế tiếp của bot. INF = không cần đi.
func bot_goal() -> Vector3:
	if _state == "return":
		return return_to
	for t in targets:
		if not t.got:
			return t.pos
	return return_to


## Autotest: hành động không đi lại được (bấm phím, chọn trên bảng).
func bot_act() -> void:
	pass


func is_done() -> bool:
	return _state == "done"


func finish() -> void:
	if _state == "done":
		return
	_state = "done"
	_drop_carry()
	finished.emit()


## Thêm một điểm. Trả về chỉ số.
func add_target(pos: Vector3, node: Node3D, reach := 0.9, reach_y := 0.8, need_crouch := false) -> int:
	var t := {"pos": pos, "node": node, "got": false, "reach": reach, "reach_y": reach_y, "need_crouch": need_crouch, "hint": null}
	if node:
		node.global_position = pos
	if hint_text != "":
		var h := Blocks.label(self, hint_text, pos + Vector3(0, 0.7, 0), 44, Color("#FFF8EA"))
		h.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		h.outline_size = 10
		h.outline_modulate = Color("#3D2A1E")
		h.visible = false
		t.hint = h
	targets.append(t)
	return targets.size() - 1


func _tick_targets(delta: float) -> void:
	if _state == "done":
		return
	var pp := player.global_position
	var t_now := Time.get_ticks_msec() / 1000.0
	for i in targets.size():
		var t: Dictionary = targets[i]
		var active: bool = not t.got and _state == "find" and (not ordered or i == _first_open())
		if t.node:
			var flat := Vector2(pp.x - t.pos.x, pp.z - t.pos.z).length()
			t.node.visible = not t.got and (active or not ordered) and flat < reveal_radius
			if t.node.visible:
				t.node.rotation.y += delta * 1.5
				t.node.global_position.y = t.pos.y + 0.05 + sin(t_now * 3.0 + i) * 0.03
		if t.hint:
			var d := pp.distance_to(t.pos)
			t.hint.visible = active and d < hint_radius
			if t.hint.visible:
				t.hint.font_size = int(lerpf(64.0, 32.0, clampf(d / maxf(hint_radius, 0.1), 0.0, 1.0)))
		if active and _reached(t):
			_got(i)
			return
	if _state == "return" and _near(return_to, 1.4, 1.2):
		_state = "find"
		_drop_carry()
		on_returned(_index)
		if _all_got():
			finish()


func _first_open() -> int:
	for i in targets.size():
		if not targets[i].got:
			return i
	return -1


func _all_got() -> bool:
	return targets.all(func(t): return t.got)


func _reached(t: Dictionary) -> bool:
	if t.need_crouch and player.stance != "crouch":
		return false
	var pp := player.global_position
	var flat := Vector2(pp.x - t.pos.x, pp.z - t.pos.z).length()
	return flat < t.reach and absf(pp.y - t.pos.y) < t.reach_y


func _near(pos: Vector3, r: float, ry: float) -> bool:
	if not pos.is_finite():
		return false
	var pp := player.global_position
	return Vector2(pp.x - pos.x, pp.z - pos.z).length() < r and absf(pp.y - pos.y) < ry


func _got(i: int) -> void:
	_index = i
	targets[i].got = true
	if targets[i].node:
		targets[i].node.visible = false
	if targets[i].hint:
		targets[i].hint.visible = false
	_sfx("pickup")
	on_got(i)
	if carry_each and return_to.is_finite():
		_state = "return"
		_pick_carry()
	elif _all_got():
		if return_to.is_finite():
			_state = "return"
			_pick_carry()
		else:
			finish()


## Lớp con nghe: vừa chạm điểm i / vừa mang món i về.
func on_got(_i: int) -> void:
	pass


func on_returned(_i: int) -> void:
	pass


## Đếm số điểm đã lấy
func got_count() -> int:
	return targets.filter(func(t): return t.got).size()


func _pick_carry() -> void:
	if not _carry_proto.is_valid():
		return
	_drop_carry()
	carry_model = _carry_proto.call()
	carry_model.top_level = true
	add_child(carry_model)


func _drop_carry() -> void:
	if carry_model:
		carry_model.queue_free()
		carry_model = null


func carry_with(proto: Callable) -> void:
	_carry_proto = proto


func _process(_delta: float) -> void:
	if carry_model and player:
		var fwd: Vector3 = -player.visual.global_transform.basis.z if player.visual else Vector3.FORWARD
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
		carry_model.global_position = player.smooth_position() + Vector3(0, 0.38, 0) + fwd * 0.3


# ------------------------------------------------------------ khối tạm dùng chung

## Một món nhỏ lấp lánh (khối tạm): hình + vòng sáng mờ để dễ thấy từ xa.
static func trinket(size: Vector3, color: Color, shape := "box") -> Node3D:
	var n := Node3D.new()
	var m: Mesh
	match shape:
		"sphere":
			var s := SphereMesh.new()
			s.radius = size.x / 2.0
			s.height = size.y
			s.radial_segments = 10
			s.rings = 5
			m = s
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = size.x / 2.0
			c.bottom_radius = size.x / 2.0
			c.height = size.y
			c.radial_segments = 12
			c.rings = 1
			m = c
		_:
			var b := BoxMesh.new()
			b.size = size
			m = b
	var mi := Blocks.mesh(n, m, Vector3(0, size.y / 2.0, 0), color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := SphereMesh.new()
	glow.radius = maxf(size.x, size.z) * 0.9 + 0.08
	glow.height = glow.radius * 2.0
	glow.radial_segments = 10
	glow.rings = 5
	var g := Blocks.mesh(n, glow, Vector3(0, size.y / 2.0, 0), Color(1.0, 0.92, 0.55, 0.22), true)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## Đồ thật G8 (assets/models/thu_bay/<ten>.glb, gốc giữa đáy, mặt trước +Z). glow: thêm vòng sáng mờ như khối tạm
## để dễ thấy từ xa (đồ cần tìm); đồ đứng yên (kệ, rổ, bảng) thì không.
static func prop(ten: String, glow := true) -> Node3D:
	var n := Node3D.new()
	var m: Node3D = load("res://assets/models/thu_bay/%s.glb" % ten).instantiate()
	n.add_child(m)
	var size := Vector3(0.2, 0.2, 0.2)
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		size = mi.get_aabb().size
		if size.length() < 0.6:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if glow:
		var g := SphereMesh.new()
		g.radius = maxf(size.x, size.z) * 0.9 + 0.08
		g.height = g.radius * 2.0
		g.radial_segments = 10
		g.rings = 5
		var gm := Blocks.mesh(n, g, Vector3(0, size.y / 2.0, 0), Color(1.0, 0.92, 0.55, 0.22), true)
		gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## Mặt trên của vật ở (x, z) dưới độ cao from_y (mái hiên, mái nhà, mặt đất). Gọi sau khi phố đã có va chạm.
static func surface(world: World3D, x: float, z: float, from_y := 3.4) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, -1.0, z), Blocks.LAYER_WORLD | Blocks.LAYER_PROP)
	var hit := world.direct_space_state.intersect_ray(q)
	return hit.position if hit else Vector3(x, 0.0, z)


## Tiếng động qua autoload Sound (không gọi thẳng tên autoload: chạy được cả khi chụp ảnh bằng -s).
func _sfx(sound_name: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.play(sound_name)
