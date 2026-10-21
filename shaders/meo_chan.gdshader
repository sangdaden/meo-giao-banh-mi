shader_type spatial;
// Lông chân trước cho các giống mèo khác Bơ (cận cảnh bếp, góc nhìn thứ nhất).
// Màu nền lấy từ ảnh nướng sẵn theo model giống trong tủ đồ (tools/nuong_chan_meo.gd):
// nửa trái ảnh là chân FL, nửa phải là chân FR; ngang quanh chân, dọc từ bàn chân (dưới) lên vai (trên).
// Vằn / đốm / lông lấm tấm vẽ thêm bằng màu `mark`, chỉ ở chỗ màu nền gần màu lông chính `fur`
// (không vẽ lên tất trắng hay bụng). UV.y chạy dọc chân (0 ở bàn chân), UV.x quanh chân (0 là mặt trên/trước).

uniform float shell = 0.0;           // > 0: lớp lông viền (next_pass), đẩy ra theo pháp tuyến bấy nhiêu mét, có lỗ thưa
uniform sampler2D leg_tex : source_color, filter_linear;
uniform float half_offset = 0.0;     // 0 = nửa FL, 0.5 = nửa FR
uniform float mirror = 0.0;          // 1 = lật quanh chân (chân bên phải màn hình)
uniform vec3 fur : source_color = vec3(0.5);
uniform vec3 mark : source_color = vec3(0.2);
uniform int pattern = 0;             // 0 trơn, 1 vằn, 2 đốm, 3 lấm tấm (ticked)
uniform float stripe_count = 4.0;
uniform float use_solid = 0.0;       // 1 = cả khối một màu `solid` (bàn chân)
uniform vec3 solid : source_color = vec3(1.0);
uniform float hairless = 0.0;        // 1 = da trần (Sphynx): bóng hơn, không có sợi lông

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

varying vec3 opos;

void vertex() {
	opos = VERTEX;
	VERTEX += NORMAL * shell;
}

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void fragment() {
	if (shell > 0.0) {
		// Sợi lông: ô 2 mm, ô nào trúng thì có sợi; lớp ngoài thưa hơn lớp trong nên viền chân lởm chởm như lông.
		// Chỉ giữ ở chỗ mặt chân nghiêng khỏi camera (viền), mặt nhìn thẳng để trơn cho khỏi lấm tấm.
		float h = hash3(floor(opos * 500.0));
		float edge = 1.0 - smoothstep(0.25, 0.5, abs(dot(NORMAL, VIEW)));
		ALPHA = step(0.35 + shell * 60.0, h) * edge;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}
	float u = mix(UV.x, 1.0 - UV.x, mirror);
	float v = UV.y;
	vec3 c = texture(leg_tex, vec2(half_offset + clamp(u, 0.02, 0.98) * 0.5, 1.0 - clamp(v, 0.01, 0.99))).rgb;
	float top = 0.5 + 0.5 * cos(u * 6.2831853);   // 1 ở mặt trước/trên, 0 ở mặt sau/trong
	float on_fur = 1.0 - smoothstep(0.1, 0.28, distance(c, fur));
	if (pattern == 1) {
		float wave = noise(vec2(u * 6.0, v * 4.0)) * 1.8;
		float s = sin(v * stripe_count * 6.2831853 + wave);
		float band = smoothstep(0.75, 0.95, s) * smoothstep(0.2, 0.7, top);
		band *= 0.6 + 0.4 * noise(vec2(u * 20.0, v * 30.0));
		c = mix(c, mark, band * 0.75 * on_fur);
	} else if (pattern == 2) {
		vec2 p = vec2(u * 7.0, v * 10.0);
		vec2 cell = floor(p);
		vec2 ctr = cell + 0.25 + 0.5 * vec2(hash(cell), hash(cell + 7.1));
		float d = length((p - ctr) * vec2(1.0, 1.2));
		float ring = smoothstep(0.32, 0.24, d) - smoothstep(0.18, 0.1, d) * 0.6;
		c = mix(c, mark, clamp(ring, 0.0, 1.0) * step(0.35, hash(cell + 3.3)) * on_fur * 0.85);
	} else if (pattern == 3) {
		float t = noise(vec2(u * 50.0, v * 70.0));
		c = mix(c, mark, smoothstep(0.55, 0.85, t) * 0.45 * on_fur);
	}
	c = mix(c, solid, use_solid);
	float fib = noise(vec2(u * 140.0, v * 10.0)) * 0.6 + noise(vec2(u * 60.0, v * 25.0)) * 0.4;
	c *= mix(0.9 + 0.16 * fib, 1.0, hairless);
	ALBEDO = c;
	ROUGHNESS = mix(0.85, 0.55, hairless);
	SPECULAR = mix(0.15, 0.3, hairless);
	RIM = mix(0.45, 0.15, hairless);
	RIM_TINT = 0.6;
	BACKLIGHT = c * 0.08;
}
