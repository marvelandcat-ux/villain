shader_type canvas_item;
render_mode unshaded;

// 화면 전체 색보정 한 장(2026-10-08). 카메라가 비추는 화면(screen_texture)을 읽어 색보정 → 비네트 → 그레인 순으로 입힌다.
// 맵의 월드 노드(z 3000, 레터박스 4000 바로 아래)라 HUD·컷인(CanvasLayer)은 안 물든다.
// unshaded인 이유: 읽어 온 화면은 이미 CanvasModulate·조명을 받은 결과다 — 여기서 또 받으면 두 번 어두워진다.
// 세기 조절은 그리는 노드의 modulate 알파(COLOR.a)로 한다 — 0이면 원본 그대로, 1이면 전부 적용
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

group_uniforms grading;
// 곱해 주는 색 — 어두운 데는 어둡게 남아 밤·저녁 톤에 어울린다. tint_strength 0이면 안 곱한다
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.5, 1.5) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float brightness : hint_range(-0.3, 0.3) = 0.0;

group_uniforms vignette_group;
// 가장자리 어둡게 — 세기. 0이면 끔
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
// 어두워지기 시작하는 거리(화면 세로 절반 = 1.0, 모서리 ≈ 2.0). 가운데 캐릭터는 또렷하게 두려고 1.0 근처가 좋다
uniform float vignette_radius : hint_range(0.3, 1.5) = 0.9;
// 어두워지는 폭 — 넓을수록 부드럽다
uniform float vignette_softness : hint_range(0.05, 1.5) = 1.0;

group_uniforms grain_group;
// 필름 알갱이 세기(밝기 ±). 0.03~0.06이 은은하다
uniform float grain : hint_range(0.0, 0.3) = 0.0;
// 알갱이 한 칸 크기(화면 높이 720 기준 픽셀) — 창이 커져도 같은 굵기로 보인다
uniform float grain_size : hint_range(1.0, 4.0) = 1.5;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 src = texture(screen_texture, SCREEN_UV).rgb;
	vec3 c = src;
	// 색보정
	c = (c - 0.5) * contrast + 0.5 + brightness;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = mix(c, c * tint.rgb, tint_strength);
	// 비네트 — 가로세로 비율을 보정한 중심 거리
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = (SCREEN_UV - 0.5) * vec2(aspect, 1.0) * 2.0;
	float v = smoothstep(vignette_radius, vignette_radius + vignette_softness, length(d));
	c *= 1.0 - v * vignette;
	// 그레인 — 720p 기준 칸 크기로 쪼개고 프레임마다 다른 씨앗
	if (grain > 0.0) {
		float px_per_720 = (1.0 / SCREEN_PIXEL_SIZE.y) / 720.0;
		vec2 cell = floor(FRAGCOORD.xy / (grain_size * px_per_720));
		float n = hash21(cell + floor(TIME * 24.0) * vec2(13.1, 7.7));
		c += (n - 0.5) * grain;
	}
	c = clamp(c, 0.0, 1.0);
	COLOR = vec4(mix(src, c, COLOR.a), 1.0);
}
