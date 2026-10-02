shader_type canvas_item;
render_mode blend_add;

// 화면 위쪽 가운데 태양에서 아래로 내리쬐는 햇빛 빛줄기(god rays, 튜토리얼 2026-10-01).
// 전체 화면 ColorRect에 덮어 가산 합성한다 — 어두운 곳은 투명, 빛줄기만 노랗고 하얗게 더해진다.
// 수렴점(sun_pos)을 화면 위로 멀리 빼서 작은 점에서 퍼지는 티를 없애고, 빛줄기가 거의 평행하게
// 내려오되 가장자리로 갈수록 살짝 대각선으로 벌어지게 한다. 태양 번짐은 가로로 넓은 타원.
// 빛줄기는 주기적인 sin 대신 노이즈를 섞어 굵기·밝기가 들쭉날쭉하게 — 더 자연스럽게.

// 빛줄기가 모이는 가상의 태양 자리(UV, y가 음수면 화면 위로 벗어남 — 멀수록 평행해짐)
uniform vec2 sun_pos = vec2(0.5, -1.0);
// 빛줄기 색(노란 느낌 + 하양)
uniform vec4 ray_color : source_color = vec4(1.0, 0.95, 0.72, 1.0);
// 빛줄기 세기
uniform float strength : hint_range(0.0, 2.0) = 0.6;
// 태양 번짐 세기
uniform float glow_strength : hint_range(0.0, 2.0) = 0.5;
// 태양 번짐 가로 반폭(UV) — 클수록 가로로 넓음(0.6이면 화면 폭을 넘김)
uniform float sun_width : hint_range(0.1, 1.5) = 0.6;
// 태양 번짐 세로 반높이(UV)
uniform float sun_height : hint_range(0.05, 1.0) = 0.35;
// 빛줄기 성김(작을수록 성기고 굵음)
uniform float ray_count : hint_range(5.0, 120.0) = 42.0;
// 빛줄기 또렷함(작을수록 흐릿·부드러움)
uniform float ray_sharpness : hint_range(0.5, 6.0) = 1.4;
// 빛줄기가 닿는 거리(수렴점 기준)
uniform float ray_reach : hint_range(0.5, 5.0) = 3.0;
// 빛줄기가 일렁이는 빠르기
uniform float sway_speed : hint_range(0.0, 2.0) = 0.2;
// 가로세로 비율 보정(화면 폭/높이)
uniform float aspect = 1.777;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

// 이어지는 1차원 값 노이즈 — 셀마다 랜덤값을 부드럽게 보간
float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), u);
}

void fragment() {
	vec2 dir = UV - sun_pos;
	dir.x *= aspect;
	float dist = length(dir);
	// 아래 방향(dir.y+)을 0으로 잡은 각도 — 가운데는 세로, 가장자리로 갈수록 대각선
	float angle = atan(dir.x, dir.y);

	// 노이즈 세 겹을 섞어 굵기·간격·밝기가 제각각인 빛줄기를 만든다
	float a = angle * ray_count;
	float t = TIME * sway_speed;
	float n = vnoise(a + t * 0.3) * 0.55
			+ vnoise(a * 2.3 - t * 0.2) * 0.30
			+ vnoise(a * 5.1 + t * 0.15) * 0.15;
	float rays = pow(smoothstep(0.4, 0.95, n), ray_sharpness);

	// 수렴점에서 멀어질수록, 화면 아래로 갈수록 옅어짐
	float fall = smoothstep(ray_reach, 0.0, dist);
	float top_fade = smoothstep(1.0, 0.0, UV.y);
	float intensity = rays * fall * top_fade * strength;

	// 화면 위쪽 가운데에 가로로 넓고 부드럽게 퍼지는 태양 번짐
	vec2 g = UV - vec2(sun_pos.x, 0.0);
	g.x /= sun_width;
	g.y /= sun_height;
	float glow = pow(smoothstep(1.0, 0.0, length(g)), 1.8);
	intensity += glow * glow_strength;

	COLOR = vec4(ray_color.rgb, clamp(intensity, 0.0, 1.0) * ray_color.a);
}
