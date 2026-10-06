shader_type canvas_item;

// 금빛 손·발 — 스쿼트 10스택(2026-10-06). 그림 안쪽을 금색으로 칠하고 사선 반짝임이 지나간다.
// **윤곽선은 "어두운 색"이 아니라 "가장자리 근처"로 가른다** — 검은 신발(악플러)은 안쪽도 검어서
// 어두운 색을 윤곽선으로 보면 금색이 하나도 안 칠해진다. 그래서 투명한 곳이 가까운 픽셀만 원래 색(검은 테두리)으로 둔다.
// 색조(피격 반짝임·디버프 색 같은 modulate)를 잃지 않게 꼭짓점 색을 따로 받아 마지막에 곱한다(CLAUDE.md 셰이더 함정)

uniform vec4 deep_gold : source_color = vec4(0.82, 0.55, 0.06, 1.0);
uniform vec4 light_gold : source_color = vec4(1.0, 0.93, 0.55, 1.0);
// 가장자리에서 이만큼(그림 긴 변의 비율) 안쪽까지를 윤곽선으로 본다
uniform float outline_ratio = 0.07;
// 사선 반짝임이 지나가는 빠르기(초당 횟수)와 세기
uniform float shine_speed = 0.55;
uniform float shine_strength = 0.45;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	// 여덟 방향으로 조금 떨어진 곳에 투명한 데가 있으면 가장자리(윤곽선)다
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 off = outline_ratio * max(size.x, size.y) * TEXTURE_PIXEL_SIZE;
	float inside = 1.0;
	inside = min(inside, texture(TEXTURE, UV + vec2(off.x, 0.0)).a);
	inside = min(inside, texture(TEXTURE, UV - vec2(off.x, 0.0)).a);
	inside = min(inside, texture(TEXTURE, UV + vec2(0.0, off.y)).a);
	inside = min(inside, texture(TEXTURE, UV - vec2(0.0, off.y)).a);
	inside = min(inside, texture(TEXTURE, UV + off * 0.7).a);
	inside = min(inside, texture(TEXTURE, UV - off * 0.7).a);
	inside = min(inside, texture(TEXTURE, UV + vec2(off.x, -off.y) * 0.7).a);
	inside = min(inside, texture(TEXTURE, UV + vec2(-off.x, off.y) * 0.7).a);
	float fill = smoothstep(0.3, 0.8, inside);
	// 어두운 곳은 진한 금, 밝은 곳은 옅은 금 — 검은 칠도 금색으로 보이게 바닥을 진한 금으로 둔다
	vec3 gold = mix(deep_gold.rgb, light_gold.rgb, smoothstep(0.0, 1.0, lum));
	vec3 col = mix(tex.rgb, gold, fill);
	// 사선으로 지나가는 반짝임 띠
	float band = fract(UV.x + UV.y * 0.6 - TIME * shine_speed);
	float shine = smoothstep(0.0, 0.035, band) * (1.0 - smoothstep(0.035, 0.09, band));
	col += vec3(shine_strength) * shine * fill;
	COLOR = vec4(col, tex.a) * tint;
}
