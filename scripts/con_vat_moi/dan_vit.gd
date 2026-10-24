extends Node3D
## V5 · Đàn vịt bơi lúc phố ngập Thứ Tư: nước dâng (ThoiTiet.ngap, đơn 2 và đơn 4) thì bốn con vịt bơi vòng dọc mép
## đường lớn phía bắc, đoạn phía đông (xa góc ngã tư). Con đầu có lưng đỡ được Bơ: nhảy lên lưng thì vịt chìm nhẹ,
## vỗ cánh (bi_dap) rồi chở Bơ đi một quãng. Q gần đàn thì cả đàn dừng lại quạc quạc. Lần đầu ConVat.meet("vit").
## Model: vit (con đầu), vit_nhe (ba con theo sau). Khi bơi, mặt nước ở y ≈ 0,105 so với gốc vịt.

## Vòng bơi hình sân vận động: hai đoạn thẳng dài 2·HALF_X dọc trục x, hai đầu là nửa vòng tròn bán kính TURN_R
const CENTER := Vector3(14.0, 0, -4.3)  ## sát bó vỉa (z −4,9): xe buýt làn z −2,5 chạy qua không chạm vịt
const HALF_X := 4.5
const TURN_R := 0.45
const SPEED := 0.45            ## m/giây
const SPACING := 0.55          ## các con theo sau cách nhau chừng này (m)
const FOLLOWERS := 3
const WATER_LINE := 0.105
const MIN_LEVEL := 0.07        ## nước cạn hơn thì vịt chưa ra
const BACK := Vector3(0.36, 0.06, 0.48)   ## lưng con đầu (hộp va chạm cho Bơ đứng)
const BACK_Y := 0.2
const VIEW_END := 24.0

var player: CharacterBody3D
var toast: Callable
var goi_r := 6.0
var ducks: Array[Node3D] = []
var back: AnimatableBody3D
var rides := 0
var _thoi_tiet: Node
var _s := 0.0                  ## quãng đã bơi trên vòng (m)
var _pause := 0.0
var _riding := false
var _out := false
var _hinted := false


func _ready() -> void:
	name = "DanVit"
	add_to_group("con_vat")
	var scene := get_parent().get_parent() if get_parent() else null
	if scene:
		_thoi_tiet = scene.find_child("ThoiTiet", true, false)
	for i in FOLLOWERS + 1:
		var d := MoHinhConVat.put(self, "vit" if i == 0 else "vit_nhe", Vector3.ZERO, 0.0, VIEW_END)
		MoHinhConVat.play(d, "boi")
		ducks.append(d)
	back = AnimatableBody3D.new()
	back.name = "LungVit"
	back.sync_to_physics = true
	back.collision_layer = Blocks.LAYER_PROP
	back.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BACK
	cs.shape = box
	back.add_child(cs)
	add_child(back)
	_show(false)


func level() -> float:
	if _thoi_tiet == null and is_inside_tree():
		_thoi_tiet = get_tree().current_scene.find_child("ThoiTiet", true, false) if get_tree().current_scene else null
	var f: Variant = _thoi_tiet.get("flood") if _thoi_tiet else null
	return f.position.y if f is Node3D and is_instance_valid(f) and f.visible else 0.0


func on_called(_pos: Vector3) -> void:
	if not _out:
		return
	_pause = 3.0
	for d in ducks:
		MoHinhConVat.play(d, "quac", false, 0.1)
	MoHinhConVat.pop_text(ducks[0], "Quạc quạc!", 0.45)
	ConVat.meet("vit")


func _physics_process(delta: float) -> void:
	var lv := level()
	var out := lv > MIN_LEVEL
	if out != _out:
		_show(out)
	if not out:
		return
	_pause = maxf(_pause - delta, 0.0)
	if _pause <= 0.0:
		_s += SPEED * delta
	var y := lv - WATER_LINE
	for i in ducks.size():
		var d := ducks[i]
		var pd := _path(_s - SPACING * i)  # [x, z, hướng x, hướng z]
		d.position = CENTER + Vector3(pd[0], y, pd[1])
		d.rotation.y = atan2(pd[2], pd[3])
		if not MoHinhConVat.busy(d):
			MoHinhConVat.play(d, "noi" if _pause > 0.0 else "boi")
	var lead := ducks[0]
	back.global_transform = Transform3D(Basis(Vector3.UP, lead.rotation.y), lead.global_position + Vector3(0, BACK_Y - BACK.y / 2.0, 0))
	_check_rider()


## Chỗ từng con vịt đang bơi (ConVat.road_points: xe máy, xe buýt dừng nhường đàn vịt qua đường).
func road_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	if _out:
		for d in ducks:
			out.append(Vector3(d.global_position.x, 0.0, d.global_position.z))
	return out


## Điểm trên vòng bơi sau quãng s (m): [x, z, hướng x, hướng z] so với CENTER.
func _path(s: float) -> Array:
	var a := 2.0 * HALF_X
	var arc := PI * TURN_R
	s = fposmod(s, 2.0 * a + 2.0 * arc)
	if s < a:
		return [-HALF_X + s, -TURN_R, 1.0, 0.0]
	s -= a
	if s < arc:
		var f := -PI / 2.0 + s / TURN_R
		return [HALF_X + TURN_R * cos(f), TURN_R * sin(f), -sin(f), cos(f)]
	s -= arc
	if s < a:
		return [HALF_X - s, TURN_R, -1.0, 0.0]
	s -= a
	var g := PI / 2.0 + s / TURN_R
	return [-HALF_X + TURN_R * cos(g), TURN_R * sin(g), -sin(g), cos(g)]


func _check_rider() -> void:
	if player == null:
		return
	var on := false
	if player.is_on_floor():
		for i in player.get_slide_collision_count():
			if player.get_slide_collision(i).get_collider() == back:
				on = true
				break
	if on and not _riding:
		rides += 1
		MoHinhConVat.play(ducks[0], "bi_dap", false, 0.05)
		MoHinhConVat.pop_text(ducks[0], "Quạc!", 0.5, 1.0)
		ConVat.meet("vit")
		if rides == 1 and toast.is_valid():
			toast.call("Bơ cưỡi vịt! Vịt chở Bơ đi một quãng.", 2.8)
	_riding = on


func _show(on: bool) -> void:
	_out = on
	visible = on
	back.collision_layer = Blocks.LAYER_PROP if on else 0
	if on and not _hinted and toast.is_valid():
		_hinted = true
		toast.call("Nước ngập, đàn vịt ra bơi ngoài đường lớn!", 2.6)
