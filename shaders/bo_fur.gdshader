shader_type spatial;
// Lông chân trước của Bơ cho cận cảnh bếp, màu theo Bơ kiểu D:
// cam, vằn nâu đỏ mảnh đứt quãng ở mặt ngoài, mặt trong kem nhạt, "tất" kem ở cổ chân.
// UV.y chạy dọc chân (0 ở bàn chân), UV.x quanh chân (0 là mặt trên/ngoài).

uniform float shell = 0.0;           // > 0: lớp lông viền (next_pass), đẩy ra theo pháp tuyến bấy nhiêu mét, có lỗ thưa
uniform vec3 fur : source_color = vec3(0.91, 0.57, 0.23);
uniform vec3 stripe : source_color = vec3(0.70, 0.36, 0.15);
uniform vec3 cream : source_color = vec3(0.98, 0.90, 0.78);
uniform float sock = 0.14;           // phần kem ở cổ chân (theo UV.y)
uniform float stripe_count = 6.0;    // số vằn dọc chân
uniform float all_cream = 0.0;       // 1 = cả khối màu kem (bàn chân)

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
	float u = UV.x;
	float v = UV.y;
	float top = 0.5 + 0.5 * cos(u * 6.2831853);   // 1 ở mặt ngoài, 0 ở mặt trong
	vec3 c = fur;
	// Vằn: dải ngang mảnh, mép mờ, uốn lượn, chỉ ở mặt ngoài và nhạt dần sang hai bên
	float wave = noise(vec2(u * 6.0, v * 4.0)) * 1.8;
	float s = sin(v * stripe_count * 6.2831853 + wave);
	float band = smoothstep(0.8, 0.97, s) * smoothstep(0.3, 0.75, top) * step(sock + 0.06, v);
	band *= 0.55 + 0.45 * noise(vec2(u * 20.0, v * 30.0));
	c = mix(c, stripe, band * 0.5);
	// Mặt trong chân nhạt màu kem
	c = mix(c, cream, smoothstep(0.65, 1.0, 1.0 - top) * 0.55);
	// Tất kem ở cổ chân, mép lởm chởm như lông
	float edge = sock + (noise(vec2(u * 18.0, 3.0)) - 0.5) * 0.05;
	c = mix(c, cream, smoothstep(edge + 0.02, edge - 0.02, v));
	c = mix(c, cream, all_cream);
	// Sợi lông chạy dọc chân, làm mặt lông không bóng lì như ống nhựa
	float fib = noise(vec2(u * 140.0, v * 10.0)) * 0.6 + noise(vec2(u * 60.0, v * 25.0)) * 0.4;
	c *= 0.9 + 0.16 * fib;
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
	RIM = 0.45;
	RIM_TINT = 0.6;
	BACKLIGHT = vec3(0.08, 0.05, 0.03);
}
