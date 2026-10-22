class_name MucBan
extends Node
## Chó Mực làm bạn đi theo Bơ (Thứ Bảy sau chương thẻ tên; Chủ Nhật và Tuần mới dùng lại).
## Không sửa dog.gd: tắt canh hẻm (awake = false) rồi dời "home" của Mực ra sau lưng Bơ, AI đi bộ tự tới đó.
## Clip G3: di_theo khi đi, ngoi khi Bơ đứng lại, sua_bo_cau khi gặp đàn bồ câu (đuổi cho bay tán loạn).
##
## Dùng: MucBan.attach(dog, player)            # thêm vào cây cảnh làm con của dog
##       MucBan.attach(dog, player, bo_cau)    # có đàn BoCau thì Mực sủa đuổi

const KEEP := 1.6          ## đứng cách Bơ chừng này
const SIDE := 0.7          ## lệch sang bên, khỏi chắn camera
const FAR := 22.0          ## xa hơn (Bơ trên mái, chạy quá xa) thì Mực chạy tắt tới chỗ đất gần Bơ
const BARK_RANGE := 3.0
const BARK_TIME := 1.6
const STUCK_TIME := 1.5    ## kẹt (bờ rào hẻm 42, tường) lâu hơn thì Mực chạy vòng tắt tới sau lưng Bơ

var dog: CharacterBody3D
var player: CharacterBody3D
var pigeons: Node3D
var _bark := 0.0
var _side := 1.0
var _stuck := 0.0
var _last_dist := 0.0


static func attach(the_dog: CharacterBody3D, the_player: CharacterBody3D, the_pigeons: Node3D = null) -> MucBan:
	var m := MucBan.new()
	m.name = "MucBan"
	m.dog = the_dog
	m.player = the_player
	m.pigeons = the_pigeons
	the_dog.add_child(m)
	return m


func _ready() -> void:
	dog.awake = false
	dog.set_tag_visible(true)


func _physics_process(delta: float) -> void:
	if dog == null or player == null:
		return
	dog.awake = false
	var zzz: Node3D = dog.get("_zzz")  # Mực tỉnh, đi theo Bơ: tắt chữ Z ngủ gật của AI canh hẻm
	if zzz:
		zzz.visible = false
	var pp := player.global_position
	var dp := dog.global_position
	var flat := Vector2(pp.x - dp.x, pp.z - dp.z)
	var dist := flat.length()
	if _bark > 0.0:
		_bark -= delta
		dog.home = dp
		dog.play_clip("sua_bo_cau")
		return
	if pigeons and pigeons.get("state") == "perch" and pigeons.has_method("scatter"):
		var c: Vector3 = pigeons.get("_center")
		if Vector2(dp.x - c.x, dp.z - c.z).length() < BARK_RANGE:
			_bark = BARK_TIME
			pigeons.scatter(dp)
			var snd := get_node_or_null("/root/Sound")
			if snd:
				snd.play_at("bark", dp)
			return
	_stuck = _stuck + delta if dist > KEEP + 1.5 and dist > _last_dist - 0.02 * delta * 60.0 else 0.0
	_last_dist = dist
	if dist > FAR or _stuck > STUCK_TIME:
		_stuck = 0.0
		var behind := pp - _back_dir() * KEEP
		behind.y = maxf(0.0, ViecNho.surface(dog.get_world_3d(), behind.x, behind.z, 0.6).y)
		dog.global_position = behind
		dog.home = behind
		return
	var target := pp - _back_dir() * KEEP + _back_dir().cross(Vector3.UP) * SIDE * _side
	target.y = dp.y
	if dist > KEEP + 0.8:
		dog.home = target
		dog.walk_speed = clampf(dist * 1.6, 2.5, 7.5)
		dog.play_clip("di_theo")
	else:
		dog.home = dp
		dog.play_clip("ngoi" if dist < KEEP + 0.4 else "di_theo")


## Hướng nhìn của Bơ trên mặt phẳng (Mực đứng phía sau).
func _back_dir() -> Vector3:
	var v := player.velocity
	v.y = 0.0
	if v.length() > 0.5:
		return v.normalized()
	var f: Vector3 = -player.visual.global_transform.basis.z if player.visual else Vector3.FORWARD
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD
