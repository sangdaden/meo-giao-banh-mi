class_name TimerRing
extends Control
## Đồng hồ vòng tròn ở giữa trên màn hình. Dưới 5 giây chuyển đỏ và rung nhẹ.

var ratio := 1.0
var seconds := 0.0
var active := false

const PAPER := Color("#FFF8EA")
const INK := Color("#1F2A2A")
const CRUST := Color("#D98E2B")
const RED := Color("#C8412F")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 4.0
	var urgent := active and seconds < 5.0
	if urgent:
		c += Vector2(sin(Time.get_ticks_msec() * 0.05) * 2.0, 0)
	draw_circle(c, r, PAPER)
	draw_arc(c, r, 0, TAU, 64, INK, 4.0, true)
	if active:
		draw_arc(c, r - 10, -PI / 2, -PI / 2 + TAU * clampf(ratio, 0, 1), 64, RED if urgent else CRUST, 10.0, true)
	var font := get_theme_default_font()
	var whole := int(ceil(seconds))
	var text := "%d:%02d" % [whole / 60, whole % 60] if active else "--"
	var fs := 26
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, c + Vector2(-tw.x / 2.0, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, RED if urgent else INK)
