shader_type spatial;
// Đồ vải bay theo gió (áo choàng siêu nhân, đuôi khăn, ruy băng, lá cờ) và đồ treo đung đưa (chuông, đèn, bóng).
// Lưới dựng ở tools/xuat_skin_game.py. Với vải:
// UV.x chạy ngang áo (-1 mép trái .. 1 mép phải), UV.y dọc áo (glTF lật: 1 ở cổ, 0 ở gấu áo),
// UV2.x là khoảng từ đỉnh tới sống lưng áo cùng hàng (để bung phẳng áo khi gió thổi; chỉ áo choàng, ridge = 1).
// Cùng công thức với phòng thử đồ trên trang Tủ đồ, player.gd đẩy tốc độ vào mỗi khung hình.

uniform float speed = 0.0;   // 0 đứng, ~0,6 đi, 1 chạy nhanh (đã làm mượt)
uniform float fall = 0.0;    // -1 đang bật lên .. 1 đang rơi: rơi thì áo hất lên, bật lên thì áo rủ xuống
uniform float turn = 0.0;    // -1..1 quẹo: gấu áo văng ra phía ngoài vòng
uniform vec3 hinge = vec3(0.0, 0.056, 0.12);  // mép cổ áo / điểm treo (toạ độ mesh)
uniform float roughness_v = 0.9;
uniform int mode = 0;        // 0 vải bay, 1 lá cờ (chỉ sóng, không xoay quanh cán), 2 đồ treo lắc (con lắc quanh hinge), 3 bánh xe lăn
uniform float amp = 1.0;     // biên độ (nơ bướm rung nhẹ 0,25)
uniform float ridge = 1.0;   // 1: dùng UV2.x để bung phẳng (áo choàng); 0: UV2 là toạ độ ảnh hoa văn
uniform float lac_dir = 1.0; // đồ treo dưới điểm treo 1, đồ bay trên điểm treo (bóng bay) -1: đều văng ra sau
uniform float emit = 0.0;    // đèn ông sao, nến phát sáng
uniform float roll = 0.0;    // góc lăn của bánh xe (rad), player.gd cộng dồn theo quãng đường
uniform float axle = 0.0;    // bánh xe: hai trục trước/sau ở hinge.z ± axle
uniform bool use_tex = false;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;  // hoa văn lặp (ô caro, chấm bi), đọc theo UV2

void vertex() {
	float s = speed;
	vec3 p = VERTEX;
	float w = TIME * (3.0 + 7.0 * s);
	float ca = 1.0, sa = 0.0;
	if (mode == 3) {
		vec3 c = hinge;
		c.z += p.z > hinge.z ? axle : -axle;
		ca = cos(roll); sa = sin(roll);
		vec3 q = p - c;
		q = vec3(q.x, q.y * ca - q.z * sa, q.y * sa + q.z * ca);
		p = q + c;
	} else if (mode == 2) {
		float a = lac_dir * (s * 0.35 + clamp(fall, -0.25, 1.0) * 0.25 + 0.05 * sin(TIME * 2.2) * (1.0 + s));
		ca = cos(a); sa = sin(a);
		vec3 q = p - hinge;
		q = vec3(q.x, q.y * ca - q.z * sa, q.y * sa + q.z * ca);
		q.x += turn * 0.15 * abs(q.y);
		p = q + hinge;
	} else {
		float u = UV.x;
		float k = 1.0 - UV.y;
		if (mode == 1) {
			p.x += amp * (0.004 + s * 0.02) * k * sin(10.0 * k - w * 1.3);   // lá cờ phấp phới quanh cán
			p.y += amp * 0.004 * s * k * sin(7.0 * k - w + u * 2.0);
		} else {
			p.y += ridge * s * 0.5 * UV2.x * min(1.0, k * 3.0);   // gió bung áo phẳng ra
			p.x *= 1.0 + amp * s * 0.25 * k;
			p.z -= amp * s * 0.05 * k;
			float a = s * (0.06 + 0.34 * k) + s * 0.08 * k * sin(w * 1.2 - k * 5.0);  // nhấc gấu áo ra sau
			a += clamp(fall, -0.25, 1.0) * 0.4 * k;
			a += 0.012 * k * sin(TIME * 1.7 - k * 3.0);   // đứng yên vẫn đung đưa khẽ
			a *= amp;
			vec3 q = p - hinge;
			ca = cos(a); sa = sin(a);
			q = vec3(q.x, q.y * ca - q.z * sa, q.y * sa + q.z * ca);
			p = q + hinge;
			p.y += amp * (0.003 + s * 0.03) * k * sin(11.0 * k - w * 1.3 + u * 2.2);   // sóng vải chạy dọc áo
			p.x += amp * s * 0.012 * k * sin(7.0 * k - w + 1.3) * abs(u);
			p.x += amp * turn * 0.09 * k * k;
		}
	}
	VERTEX = p;
	NORMAL = vec3(NORMAL.x, NORMAL.y * ca - NORMAL.z * sa, NORMAL.y * sa + NORMAL.z * ca);
}

void fragment() {
	ALBEDO = use_tex ? texture(tex, UV2).rgb : COLOR.rgb;
	ROUGHNESS = roughness_v;
	EMISSION = ALBEDO * emit;
	RIM = 0.3;
}
