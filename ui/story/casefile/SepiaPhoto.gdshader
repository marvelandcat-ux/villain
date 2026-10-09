shader_type canvas_item;

// 사건 파일 사진 — 그림을 빛바랜 갈색 사진처럼(세피아) 바꾼다(2026-10-07, 에피소드 1 사건 파일 사진과 같은 느낌).
// 어두운 곳은 진한 갈색, 밝은 곳은 종이색. 검은 옷이 시커멓게 뭉개지지 않게 밝기를 조금 끌어올린다.
// 사건 파일이 서서히 나타날 때(@show) 같이 흐려지도록 꼭짓점 색(modulate)을 마지막에 곱한다(CLAUDE.md 셰이더 함정)

uniform vec4 dark : source_color = vec4(0.27, 0.18, 0.1, 1.0);
uniform vec4 light : source_color = vec4(0.97, 0.9, 0.75, 1.0);
// 0이면 그대로, 클수록 어두운 곳이 밝아진다
uniform float lift : hint_range(0.0, 0.9) = 0.35;
uniform float opacity : hint_range(0.0, 1.0) = 0.93;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	lum = pow(clamp(lum, 0.0, 1.0), 1.0 - lift);
	COLOR = vec4(mix(dark.rgb, light.rgb, lum), tex.a * opacity) * tint;
}
