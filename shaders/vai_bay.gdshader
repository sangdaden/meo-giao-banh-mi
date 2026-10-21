shader_type spatial;
// Đồ vải bay theo gió (áo choàng siêu nhân). Lưới dựng ở tools/xuat_skin_game.py (cape_sheet trong acc.py):
// UV.x chạy ngang áo (-1 mép trái .. 1 mép phải), UV.y dọc áo (glTF lật: 1 ở cổ, 0 ở gấu áo),
// UV2.x là khoảng từ đỉnh tới sống lưng áo cùng hàng (để bung phẳng áo khi gió thổi).
// Cùng công thức với phòng thử đồ trên trang Tủ đồ, player.gd đẩy tốc độ vào mỗi khung hình.

uniform float speed = 0.0;   // 0 đứng, ~0,6 đi, 1 chạy nhanh (đã làm mượt)
uniform float fall = 0.0;    // -1 đang bật lên .. 1 đang rơi: rơi thì áo hất lên, bật lên thì áo rủ xuống
uniform float turn = 0.0;    // -1..1 quẹo: gấu áo văng ra phía ngoài vòng
uniform vec3 hinge = vec3(0.0, 0.056, 0.12);  // mép cổ áo (toạ độ mesh)
uniform float roughness_v = 0.9;

void vertex() {
	float u = UV.x;
	float k = 1.0 - UV.y;
	float s = speed;
	vec3 p = VERTEX;
	p.y += s * 0.5 * UV2.x * min(1.0, k * 3.0);   // gió bung áo phẳng ra
	p.x *= 1.0 + s * 0.25 * k;
	p.z -= s * 0.05 * k;
	float w = TIME * (3.0 + 7.0 * s);
	float a = s * (0.06 + 0.34 * k) + s * 0.08 * k * sin(w * 1.2 - k * 5.0);  // nhấc gấu áo ra sau
	a += clamp(fall, -0.25, 1.0) * 0.4 * k;
	a += 0.012 * k * sin(TIME * 1.7 - k * 3.0);   // đứng yên vẫn đung đưa khẽ
	vec3 q = p - hinge;
	float ca = cos(a), sa = sin(a);
	q = vec3(q.x, q.y * ca - q.z * sa, q.y * sa + q.z * ca);
	p = q + hinge;
	p.y += (0.003 + s * 0.03) * k * sin(11.0 * k - w * 1.3 + u * 2.2);   // sóng vải chạy dọc áo
	p.x += s * 0.012 * k * sin(7.0 * k - w + 1.3) * abs(u);
	p.x += turn * 0.09 * k * k;
	VERTEX = p;
	NORMAL = vec3(NORMAL.x, NORMAL.y * ca - NORMAL.z * sa, NORMAL.y * sa + NORMAL.z * ca);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness_v;
	RIM = 0.3;
}
