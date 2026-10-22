class_name BongThoai
extends Node3D
## Bong bóng thoại trên đầu người Thứ Bảy (G9 Sang duyệt 22/10): "cho" (!, có việc nhờ), "dang" (..., đang giúp),
## "xong" (tim, đã dán trang sổ). Model 540 tam giác, gốc ở đáy đuôi; đặt tại đỉnh đầu + 0,26 m, luôn quay mặt về camera.
## Hiện 0,25 s (0 → 1,12 → 1), nhún 1,2 s lặp ±3 cm ±4°, đổi trạng thái 0,3 s, tắt 0,2 s.
##
## Dùng:  var b := BongThoai.new(); add_child(b); b.follow = nguoi; b.set_state("cho")

const MODELS := {
	"cho": preload("res://assets/models/thu_bay/bong_cho.glb"),
	"dang": preload("res://assets/models/thu_bay/bong_dang.glb"),
	"xong": preload("res://assets/models/thu_bay/bong_xong.glb"),
}
const ABOVE := 0.26        ## cao hơn đỉnh đầu
const HEAD_TOP := 0.22     ## từ gốc xương "head" tới đỉnh đầu (người lớn)
const BOB_TIME := 1.2
const BOB_Y := 0.03
const BOB_TILT := 4.0

var follow: Node3D          ## Nguoi hoặc Chó Mực
var height := -1.0          ## > 0: cao cố định trên gốc follow (Mực); < 0: theo xương head của Nguoi
var state := ""
var _model: Node3D
var _tween: Tween
var _t := 0.0
var _head := -2


func set_state(new_state: String) -> void:
	if new_state == state:
		return
	var old := state
	state = new_state
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if new_state == "":
		_tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_tween.tween_callback(func(): visible = false)
		return
	visible = true
	if old == "":
		_swap(new_state)
		scale = Vector3.ONE * 0.01
		_tween.tween_property(self, "scale", Vector3.ONE * 1.12, 0.17).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector3.ONE, 0.08)
	else:  # đổi: thu nhỏ, đổi model, bật lại (tổng 0,3 s)
		_tween.tween_property(self, "scale", Vector3.ONE * 0.2, 0.12).set_ease(Tween.EASE_IN)
		_tween.tween_callback(_swap.bind(new_state))
		_tween.tween_property(self, "scale", Vector3.ONE * 1.12, 0.12).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector3.ONE, 0.06)


func _swap(s: String) -> void:
	if _model:
		_model.queue_free()
	_model = MODELS[s].instantiate()
	add_child(_model)
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	if not visible or follow == null or not is_instance_valid(follow):
		return
	_t = fmod(_t + delta, BOB_TIME)
	var w := sin(_t / BOB_TIME * TAU)
	global_position = _top() + Vector3(0, ABOVE + w * BOB_Y, 0)
	var cam := get_viewport().get_camera_3d()
	var yaw := 0.0
	if cam:
		var d := cam.global_position - global_position
		yaw = atan2(d.x, d.z)  # mặt trước model là +Z
	rotation = Vector3(0, yaw, deg_to_rad(BOB_TILT) * w)


## Đỉnh đầu: gốc xương head của Nguoi + 0,22 m (ngồi, đứng, Bé Na đều đúng), không có xương thì cao cố định.
func _top() -> Vector3:
	var base := follow.global_position
	if height > 0.0:
		return base + Vector3(0, height, 0)
	var sk: Skeleton3D = follow.get("skeleton")
	if sk:
		if _head == -2:
			_head = sk.find_bone("head")
		if _head >= 0:
			return sk.global_transform * sk.get_bone_global_pose(_head).origin + Vector3(0, HEAD_TOP, 0)
	return base + Vector3(0, 1.65, 0)
