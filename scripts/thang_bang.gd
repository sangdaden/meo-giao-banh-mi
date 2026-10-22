class_name ThangBang
extends Node
## Đi thăng bằng (Thứ Tư trở đi): Bơ đứng trên mặt hẹp dưới 0,3 m (ván gỗ SanThuong) thì tự chậm lại
## (DoKho "balance_speed", Thong thả 2,5 m/s), thân lắc nhẹ theo động tác Blender G2 "thang_bang".
## Chạy nhanh trên ván: Thong thả chao 0,6 s ("truot_chan") rồi tự đứng lại; Thử thách trượt rơi khỏi ván ("roi_van").
## Ngày nào cần thì gắn: ThangBang.attach(player, danh_sách_mặt_hẹp). Ngày khác không có node này nên Bơ như cũ.

signal wobbled                     ## chao trên ván (nhiệm vụ phụ "van_vung" nghe)
signal fell                        ## trượt rơi khỏi ván (Thử thách)
signal balance_changed(on: bool)

const WOBBLE_TIME := 0.6
const WOBBLE_COOLDOWN := 0.6       ## chao xong chờ chút mới tính chao lại (đang giữ Shift)
const CENTER_PULL := 4.0           ## kéo nhẹ Bơ về giữa ván cho khỏi lệch mép (mỗi giây)
const MOVING := 0.3

var player: CharacterBody3D
## Mặt hẹp: [{xf: Transform3D (gốc giữa mặt trên, trục X dọc ván), len, w}]
var surfaces: Array = []
var balancing := false
var wobbles := 0
var _cool := 0.0
var _on: Dictionary = {}


static func attach(p: CharacterBody3D, list: Array) -> ThangBang:
	var tb := ThangBang.new()
	tb.name = "ThangBang"
	tb.player = p
	tb.surfaces = list
	p.add_child(tb)
	return tb


## Thêm mặt hẹp khác (bờ tường, lan can... các ngày sau).
func add_narrow(xf: Transform3D, length: float, width: float) -> void:
	surfaces.append({"xf": xf, "len": length, "w": width})


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cool = maxf(_cool - delta, 0.0)
	var on := player.is_on_floor() and _find()
	if on != balancing:
		balancing = on
		balance_changed.emit(on)
		if not on:
			player.speed_cap = INF
			if player.clip == "thang_bang":
				player.stop_clip()
	if not balancing:
		return
	player.speed_cap = float(DoKho.v("balance_speed", 2.0))
	var xf: Transform3D = _on.xf
	var local := xf.affine_inverse() * player.global_position
	# Kéo về giữa ván theo bề ngang (không đẩy dọc ván)
	player.global_position -= xf.basis.z * local.z * minf(1.0, CENTER_PULL * delta)
	var hs := Vector2(player.velocity.x, player.velocity.z).length()
	if player.stance == "sprint" and hs > MOVING and _cool <= 0.0:
		_cool = WOBBLE_TIME + WOBBLE_COOLDOWN
		wobbles += 1
		wobbled.emit()
		if bool(DoKho.v("balance_fall", true)):
			_fall(xf, local)
		else:
			player.play_clip("truot_chan")
			player.hold(WOBBLE_TIME)
		return
	if _cool > WOBBLE_COOLDOWN:
		return  # đang chao
	if hs > MOVING:
		if player.clip != "thang_bang":
			player.play_clip("thang_bang")
	elif player.clip == "thang_bang":
		player.stop_clip()


## Thử thách: trượt chân rơi khỏi ván về phía Bơ đang lệch.
func _fall(xf: Transform3D, local: Vector3) -> void:
	var side := xf.basis.z * (signf(local.z) if absf(local.z) > 0.01 else 1.0)
	player.play_clip("roi_van")
	player.speed_cap = INF
	player.velocity = side * 3.0 + Vector3.UP * 2.0
	balancing = false
	balance_changed.emit(false)
	fell.emit()


func _find() -> bool:
	var p := player.global_position
	for s in surfaces:
		var local: Vector3 = (s.xf as Transform3D).affine_inverse() * p
		if absf(local.x) <= s.len / 2.0 + 0.05 and absf(local.z) < 0.35 and local.y > -0.15 and local.y < 0.3:
			_on = s
			return true
	return false
