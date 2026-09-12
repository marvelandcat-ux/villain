shader_type canvas_item;

// 원본 캔버스 가장자리에서 잘린 구름의 단면을 흐린다 — 폭은 DriftingClouds.gd가 매 프레임 넣어준다.
// 흐림 폭을 줄마다 울퉁불퉁하게 흔들어서, 칼로 자른 곧은 단면이나 곧은 세로 띠로 안 보이게 한다.

// 왼쪽/오른쪽 단면에서 흐리는 폭(px, 텍스처 기준). 0이면 안 흐린다
uniform float fade_left = 0.0;
uniform float fade_right = 0.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

float edge_width(float fade, float y) {
	float wob = 18.0 * sin(y * 0.083 + 1.3) + 9.0 * sin(y * 0.21 + 0.4) + 4.0 * sin(y * 0.47 + 2.2);
	return max(fade * (1.0 + wob / 40.0), 1.0);
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = UV * size;
	float k = 1.0;
	if (fade_left > 0.01) {
		k = min(k, smoothstep(0.0, edge_width(fade_left, px.y), px.x));
	}
	if (fade_right > 0.01) {
		k = min(k, smoothstep(0.0, edge_width(fade_right, px.y), size.x - px.x));
	}
	vec4 c = texture(TEXTURE, UV);
	c.a *= k;
	COLOR = c * v_modulate;
}
