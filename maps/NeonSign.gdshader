shader_type canvas_item;

// 간판 **글자** 네온(2026-10-08, 번화가 술집 거리). 건물 그림에서 "주변보다 확 밝은 가는 획"(네온 글자)만 골라
//  1. 살짝 과노출시키고(boost)  2. 둘레로 빛을 번지게 하고(glow)  3. 은은하게 깜빡인다(flicker).
// 간판 바탕(분홍 판·빨간 벽돌)처럼 **넓고 고른** 색은 주변과 밝기 차가 없어서 안 잡힌다 — 사용자 요청 "글자 부분에만".
// 흰 에어컨·회색 벽은 채도가 낮아 빠진다. 그림을 안 고치고 재질만 붙이면 되므로 간판 그림이 바뀌어도 그대로 쓴다.
// 번화가 `Building*` 중 간판 있는 것들에 공용 ShaderMaterial 하나로 붙어 있다(`NeonSignMaterial`).
// 번짐 두께는 **화면 픽셀**(fwidth) 기준이라 건물 배율이 달라도 같은 굵기다.
//
// ⚠️ canvas_item의 fragment에서 COLOR는 **이미 그림 색 x modulate**다. 거기에 그림 색을 또 곱하면 건물이 통째로 어두워진다
//    (2026-10-08 실제로 겪음). 그래서 vertex에서 modulate만 따로 받아(v_modulate) 그걸 곱한다

group_uniforms pick;
// 글자로 볼 최소 채도(흰·회색 제외)와 최소 밝기
uniform float neon_sat_min : hint_range(0.0, 1.0) = 0.15;
uniform float neon_val_min : hint_range(0.0, 1.0) = 0.72;
// 주변(둘레 평균)보다 이만큼은 밝아야 글자다 — 넓은 바탕은 0이라 빠진다
uniform float contrast_min : hint_range(0.0, 0.5) = 0.07;

group_uniforms look;
// 글자 픽셀을 얼마나 더 밝힐지(0 = 그대로)
uniform float boost : hint_range(0.0, 1.5) = 0.3;
// 둘레로 번지는 빛 세기와 반지름(화면 픽셀)
uniform float glow_strength : hint_range(0.0, 2.0) = 0.8;
uniform float glow_px : hint_range(1.0, 24.0) = 6.0;
// 깜빡임 폭(0 = 안 깜빡임)과 빠르기
uniform float flicker : hint_range(0.0, 0.5) = 0.06;
uniform float flicker_speed : hint_range(0.0, 30.0) = 6.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;   // 노드 modulate·색조만
}

float val_of(vec3 c) {
	return max(c.r, max(c.g, c.b));
}

// 채도·밝기 문턱(0~1)
float bright_sat(vec4 c) {
	float mx = val_of(c.rgb);
	float mn = min(c.r, min(c.g, c.b));
	float sat = mx > 0.001 ? (mx - mn) / mx : 0.0;
	return smoothstep(neon_sat_min - 0.05, neon_sat_min + 0.05, sat)
		* smoothstep(neon_val_min - 0.1, neon_val_min + 0.1, mx) * c.a;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float t = TIME * flicker_speed;
	float f = 1.0 + flicker * (0.6 * sin(t) + 0.4 * sin(t * 2.71 + 1.3));
	vec2 d = fwidth(UV) * glow_px;
	float v0 = val_of(src.rgb);
	// 둘레 16방향(두 반지름)을 한 번 훑어 (1) 둘레 평균 밝기 (2) 나보다 밝은 글자 픽셀의 빛을 모은다
	float ring_val = 0.0;
	vec3 glow_sum = vec3(0.0);
	float glow_amt = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = 0.7853982 * float(i);
		vec2 dir = vec2(cos(ang), sin(ang));
		for (int r = 1; r <= 2; r++) {
			vec4 s = texture(TEXTURE, UV + dir * d * float(r));
			float vs = val_of(s.rgb) * s.a;
			ring_val += vs;
			// 그 픽셀이 글자이고(채도·밝기) 나보다 contrast_min 이상 밝으면 그 빛이 내게 번진다
			float m = bright_sat(s) * smoothstep(contrast_min, contrast_min + 0.12, vs - v0) * (r == 1 ? 1.0 : 0.5);
			glow_sum += s.rgb * m;
			glow_amt += m;
		}
	}
	ring_val /= 16.0;
	// 나 자신이 글자인 정도 — 채도·밝기 + 둘레보다 밝음
	float m0 = bright_sat(src) * smoothstep(contrast_min, contrast_min + 0.12, v0 - ring_val);
	vec3 glow_col = glow_amt > 0.001 ? glow_sum / glow_amt : vec3(0.0);
	float glow = clamp(glow_amt / 10.0, 0.0, 1.0) * glow_strength * f;
	vec3 rgb = src.rgb * (1.0 + boost * m0 * f) + glow_col * glow;
	float a = max(src.a, glow * 0.8);
	COLOR = vec4(rgb * v_modulate.rgb, a * v_modulate.a);
}
