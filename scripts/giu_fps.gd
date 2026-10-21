class_name GiuFps
extends Node
## Giữ khung hình đều trên máy yếu: đo FPS, nếu thấp hơn mục tiêu một lúc thì hạ dần từng bậc
## (giảm độ phân giải 3D, rút ngắn tầm bóng đổ, cuối cùng tắt bóng). Không bao giờ nâng lại
## trong lượt chơi và không ghi vào cài đặt của người chơi, nên vào lại màn là thử lại từ đầu.
## Chỉ bật trên bản web (máy nào cũng có thể mở trình duyệt); bản PC chỉnh tay trong Cài đặt.
## Thử trên máy tính: chạy với tham số -- --giu-fps

const WARMUP := 3.0     ## giây đầu bỏ qua (nạp shader, dựng cảnh)
const WINDOW := 2.0     ## đo trung bình mỗi chừng này giây
const MARGIN := 0.88    ## dưới 88% mục tiêu (53 khi mục tiêu 60) thì hạ một bậc

var level := 0
var _wait := WARMUP
var _t := 0.0
var _frames := 0
var _sun: DirectionalLight3D


static func wanted() -> bool:
	return OS.has_feature("web") or "--giu-fps" in OS.get_cmdline_user_args()


func setup(sun: DirectionalLight3D) -> void:
	_sun = sun


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	_t += delta
	_frames += 1
	if _t < WINDOW:
		return
	var fps := _frames / _t
	_t = 0.0
	_frames = 0
	var cap := Engine.max_fps if Engine.max_fps > 0 else 60
	if fps < cap * MARGIN:
		_step_down(fps)


func _step_down(fps: float) -> void:
	var vp := get_viewport()
	level += 1
	match level:
		1, 2:
			vp.scaling_3d_scale = maxf(0.6, vp.scaling_3d_scale - 0.15)
			if level == 1:
				get_tree().call_group("giam_hat", "giam")  # buổi mưa: bớt một nửa hạt mưa (ThoiTiet)
		3:
			if _sun:
				_sun.directional_shadow_max_distance = minf(_sun.directional_shadow_max_distance, 14.0)
		4:
			if _sun:
				_sun.shadow_enabled = false
		_:
			set_process(false)
			return
	print("[giu fps] %.0f FPS, hạ bậc %d (độ phân giải 3D %.2f)" % [fps, level, vp.scaling_3d_scale])
	_wait = 0.5  # chờ nửa giây cho thay đổi có hiệu lực rồi mới đo lại
