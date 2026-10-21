class_name TimerRing
extends Control
## Đồng hồ vòng tròn ở giữa trên màn hình. Dưới 5 giây chuyển đỏ và rung nhẹ.

var ratio := 1.0
var seconds := 0.0
var active := false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 3.0
	var urgent := active and seconds < 5.0
	if urgent:
		c += Vector2(sin(Time.get_ticks_msec() * 0.05) * 2.0, 0)
	var ring := r * 0.2
	draw_circle(c, r, UiTheme.PAPER)
	draw_arc(c, r, 0, TAU, 64, UiTheme.INK, 4.0, true)
	draw_arc(c, r - ring * 0.5 - 6, 0, TAU, 64, UiTheme.SAND, ring, true)
	if active:
		draw_arc(c, r - ring * 0.5 - 6, -PI / 2, -PI / 2 + TAU * clampf(ratio, 0, 1), 64, UiTheme.RED if urgent else UiTheme.CRUST, ring, true)
	var font := UiTheme.font("display")
	var whole := int(ceil(seconds))
	var text := "%d:%02d" % [whole / 60, whole % 60] if active else "--"
	var fs := int(r * 0.62)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, c + Vector2(-tw.x / 2.0, fs * 0.33), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.RED if urgent else UiTheme.INK)
