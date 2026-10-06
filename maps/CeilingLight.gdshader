shader_type canvas_item;
render_mode blend_add;

// 천장 조명에서 아래로 퍼지는 빛 원뿔(악플러의 집, 2026-10-06).
// 사각형(ColorRect)에 덮어 가산 합성한다 — UV 위쪽 가운데가 전등, 아래로 갈수록 넓고 옅어진다.
// 방 전체 CanvasModulate(암전)가 곱해지므로 암전 때는 따로 끄지 않아도 같이 어두워진다.
// 낡은 방 느낌으로 아주 약하게 지글거리고(flicker), 빛 속에 먼지가 천천히 떠다닌다.

// 빛 색(따뜻한 백열등)
uniform vec4 light_color : source_color = vec4(1.0, 0.88, 0.6, 1.0);
// 전체 세기
uniform float strength : hint_range(0.0, 2.0) = 0.35;
// 원뿔 위쪽·아래쪽 폭(사각형 가로 대비 비율)
uniform float top_width : hint_range(0.0, 1.0) = 0.12;
uniform float bottom_width : hint_range(0.0, 1.0) = 1.0;
// 원뿔 옆 가장자리 부드러움(가로 UV)
uniform float edge_softness : hint_range(0.001, 0.5) = 0.18;
// 아래로 갈수록 옅어지는 정도(클수록 빨리 사라짐)
uniform float falloff : hint_range(0.2, 4.0) = 1.3;
// 전등 바로 아래 밝은 점 세기·크기
uniform float hotspot : hint_range(0.0, 2.0) = 0.6;
uniform float hotspot_size : hint_range(0.01, 0.5) = 0.12;
// 지글거림 세기·빠르기 — seed로 전등마다 박자를 다르게
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.12;
uniform float flicker_speed : hint_range(0.0, 30.0) = 9.0;
uniform float seed = 0.0;
// 빛 속 먼지 세기
uniform float dust_amount : hint_range(0.0, 1.0) = 0.35;
// 사각형 가로/세로 비율(먼지·밝은 점이 동그랗게 보이도록)
uniform float aspect = 0.6;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// 이어지는 1차원 값 노이즈
float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), u);
}

// 칸마다 하나씩, 천천히 떠다니는 먼지 점
float dust(vec2 uv) {
	vec2 p = vec2(uv.x * aspect, uv.y) * 14.0;
	p += vec2(sin(TIME * 0.21 + seed) * 0.6, -TIME * 0.12);
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = hash2(cell + seed);
	vec2 c = vec2(hash2(cell + 3.1), hash2(cell + 7.7));
	c += 0.15 * vec2(sin(TIME * 0.7 + h * 6.28), cos(TIME * 0.5 + h * 6.28));
	float d = length(f - c);
	// 칸 일부에만 먼지가 있다
	return step(0.72, h) * smoothstep(0.06, 0.0, d);
}

void fragment() {
	float v = UV.y;
	float x = abs(UV.x - 0.5);
	float half_w = mix(top_width, bottom_width, v) * 0.5;
	// 원뿔 안쪽일수록 1, 가장자리에서 부드럽게 0
	float side = 1.0 - smoothstep(half_w - edge_softness * max(v, 0.15), half_w, x);
	// 가운데가 조금 더 밝게
	float core = mix(0.65, 1.0, 1.0 - clamp(x / max(half_w, 0.001), 0.0, 1.0));
	float down = pow(1.0 - v, falloff);
	float cone = side * core * down;

	// 전등 바로 아래 둥근 번짐
	vec2 hp = vec2((UV.x - 0.5) * aspect, v) / hotspot_size;
	float spot = exp(-dot(hp, hp)) * hotspot;

	float flick = 1.0 - flicker_amount * vnoise(TIME * flicker_speed + seed * 13.0);
	float specks = dust(UV) * side * down * dust_amount;

	float intensity = (cone + spot + specks) * strength * flick;
	COLOR = vec4(light_color.rgb, clamp(intensity, 0.0, 1.0) * light_color.a * COLOR.a);
}
