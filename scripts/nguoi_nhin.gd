extends SkeletonModifier3D
## Đầu người dân quay nhìn Bơ khi Bơ lại gần (cộng thêm lên animation Blender, không thay nó).
## Cổ chịu 40%, đầu 60%; giới hạn quay ngang 70°, cúi/ngẩng 35°; quay mềm, không giật.

const YAW_MAX := deg_to_rad(70.0)
const PITCH_MAX := deg_to_rad(35.0)

var owner_person: Node3D  ## Nguoi sở hữu (đọc look_target, look_range)
var _yaw := 0.0
var _pitch := 0.0
var _neck := -1
var _head := -1


func _ready() -> void:
	var sk := get_skeleton()
	_neck = sk.find_bone("neck")
	_head = sk.find_bone("head")


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _head < 0 or owner_person == null:
		return
	var dt := get_process_delta_time()
	var want_yaw := 0.0
	var want_pitch := 0.0
	var target: Node3D = owner_person.look_target
	var head_g := sk.get_bone_global_pose(_head)
	if target and is_instance_valid(target):
		var local := sk.global_transform.affine_inverse() * (target.global_position + Vector3(0, 0.2, 0))
		var d := local - head_g.origin
		var flat := Vector2(d.x, d.z).length()
		if flat < owner_person.look_range and flat > 0.05:
			want_yaw = clampf(atan2(d.x, d.z), -YAW_MAX, YAW_MAX)
			want_pitch = clampf(atan2(-d.y, flat), -PITCH_MAX, PITCH_MAX)
			# Bơ ở sau lưng thì thôi, không vặn cổ như cú mèo
			if absf(atan2(d.x, d.z)) > deg_to_rad(110.0):
				want_yaw = 0.0
				want_pitch = 0.0
	var k := 1.0 - exp(-5.0 * dt)
	_yaw = lerpf(_yaw, want_yaw, k)
	_pitch = lerpf(_pitch, want_pitch, k)
	if absf(_yaw) < 0.002 and absf(_pitch) < 0.002:
		return
	_turn(sk, _neck, 0.4)
	_turn(sk, _head, 0.6)


## Xoay xương i quanh khớp của nó (trong không gian skeleton) một phần share của góc nhìn.
func _turn(sk: Skeleton3D, i: int, share: float) -> void:
	if i < 0:
		return
	var g := sk.get_bone_global_pose(i)
	var r := Basis(Vector3.UP, _yaw * share) * Basis(Vector3.RIGHT, _pitch * share)
	var ng := Transform3D(r * g.basis, g.origin)
	var parent := sk.get_bone_parent(i)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var local := pg.affine_inverse() * ng
	sk.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
