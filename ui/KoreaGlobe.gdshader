shader_type canvas_item;

// 맵 선택 지구본 — 등장방형 지도 그림(가로 = 경도 한 바퀴)을 공에 감아 그린다.
// **바다만 돈다**: 땅 그림(land_tex, 투명 배경)은 정면에 고정, 바다 그림(ocean_tex)만 spin만큼 밀려 돈다.
// flatten 0 = 둥근 지구본, 1 = 평평하게 펼친 지도. 그 사이는 두 방식의 그림 좌표(UV)를 섞어서 공이 펴지듯 보인다.
// ⚠️ 그림 좌표 계산은 ui/MapSelect.gd의 _uv_at()과 똑같아야 한다(핀 자리) — 한쪽을 고치면 같이 고칠 것

uniform sampler2D ocean_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D land_tex : source_color, filter_linear_mipmap;
// 이 사각형(ColorRect)의 크기와, 그 안에서 지구본 중심(px)·반지름(px)
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 center = vec2(640.0, 330.0);
uniform float radius = 230.0;
// 바다 그림을 가로로 얼마나 밀었는지(u) — 늘리면 바다가 돈다. 땅은 늘 u 0.5가 정면
uniform float spin = 0.0;
// 지구본 축 기울기(라디안) — 펼칠수록 0으로
uniform float tilt = -0.3;
uniform float flatten : hint_range(0.0, 1.0) = 0.0;
// 펼친 지도의 반 크기(px)와, 그 가로가 보여 주는 그림 가로 폭(u)
uniform vec2 flat_half = vec2(560.0, 300.0);
uniform float flat_span_u = 0.5;
// 펼친 지도에서 zoom_uv를 중심으로 확대
uniform float zoom = 1.0;
uniform vec2 zoom_uv = vec2(0.5, 0.5);
// 그림자(왼쪽 아래 초승달)·빛 무리
uniform vec4 shadow_color : source_color = vec4(0.12, 0.08, 0.35, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.6;
uniform vec4 glow_color : source_color = vec4(0.6, 0.5, 1.0, 0.35);
uniform float glow_width = 90.0;

vec2 rotate2(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

vec2 sphere_uv(vec2 p) {
	vec2 q = rotate2(p, -tilt * (1.0 - flatten)) / radius;
	float z = sqrt(max(1.0 - dot(q, q), 0.0));
	float lat = asin(clamp(-q.y, -1.0, 1.0));
	float lon = atan(q.x, z);
	return vec2(0.5 + lon / TAU, 0.5 - lat / PI);
}

vec2 flat_uv(vec2 p) {
	float du = flat_span_u / (2.0 * flat_half.x);
	vec2 uv = vec2(0.5 + p.x * du, 0.5 + p.y * du * 2.0);
	return zoom_uv + (uv - zoom_uv) / zoom;
}

void fragment() {
	vec2 p = UV * rect_size - center;
	vec2 uv = mix(sphere_uv(p), flat_uv(p), flatten);
	vec4 surface = texture(ocean_tex, uv + vec2(spin, 0.0));
	vec4 land = texture(land_tex, uv);
	surface.rgb = mix(surface.rgb, land.rgb, land.a);

	// 둥근 공 → 둥근 모서리 사각형 (초타원 지수를 키운다)
	vec2 half_size = mix(vec2(radius), flat_half, flatten);
	float n = mix(2.0, 12.0, flatten);
	vec2 a = abs(p) / half_size;
	float d = pow(pow(a.x, n) + pow(a.y, n), 1.0 / n);
	float inside = 1.0 - smoothstep(1.0 - fwidth(d) * 1.5, 1.0, d);

	// 공일 때만 그림자 — 빛은 오른쪽 위 앞에서
	vec2 s = p / radius;
	float sz = sqrt(max(1.0 - dot(s, s), 0.0));
	float light = dot(vec3(s.x, -s.y, sz), normalize(vec3(0.55, 0.35, 0.75)));
	float dark = (1.0 - smoothstep(-0.05, 0.3, light)) * shadow_strength * (1.0 - flatten);
	surface.rgb = mix(surface.rgb, surface.rgb * shadow_color.rgb, dark);
	// 가장자리 살짝 밝은 테두리(대기)
	float rim = smoothstep(0.75, 1.0, length(s)) * 0.25 * (1.0 - flatten);
	surface.rgb = mix(surface.rgb, glow_color.rgb, rim);

	// 바깥 빛 무리
	float edge = max(length(p) - radius, 0.0);
	float glow = glow_color.a * exp(-edge / glow_width * 2.5) * (1.0 - flatten);
	vec4 halo = vec4(glow_color.rgb, glow);

	vec4 col = mix(halo, vec4(surface.rgb, 1.0), inside);
	COLOR = col * COLOR;
}
