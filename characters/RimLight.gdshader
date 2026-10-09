shader_type canvas_item;

// 캐릭터 파츠용 "위에서 오는 빛" 셰이더(2026-10-08). 세 가지를 한 번에 한다:
//  1. 림 라이트(윤곽광): **광원을 향한 가장자리**(기본 = 윗가장자리)에만 빛이 맺힌다. 모든 윤곽선에 두르지 않는다
//  2. 아래 그늘: 광원 **반대쪽 가장자리**(아랫가장자리 = 지붕 밑)는 어둡게 — 턱 밑·팔 아래가 눌린다
//  3. 위아래 명암: 파츠 안에서도 빛 쪽은 살짝 밝고 반대쪽은 살짝 어둡다(완만한 그라데이션)
//
// `BodyRig.set_rim_light()`가 파츠마다 붙인다(맵의 `RimLight` 노드가 매 프레임 값을 넣어 준다). 평소엔 material이 없어 비용 0.
// - **안쪽으로 그린다**(BlockedOutline과 같은 이유 — 바깥으로 번지면 여백이 좁은 파츠에서 뚝 잘린다)
// - 두께는 **화면 픽셀**(rim_px) 기준: fwidth(UV)로 이 픽셀이 UV에서 얼마인지 재므로 파츠 배율·카메라 줌과 상관없이 같은 굵기다
// - 빛 방향(light_dir)은 **월드** 기준 "캐릭터 → 광원". vertex에서 MODEL_MATRIX의 역으로 파츠 로컬(=UV 축)로 돌린다 —
//   리그가 scale.x로 뒤집혀도, 손이 돌아가도 같은 쪽이 밝다. (Sprite2D flip_h는 MODEL_MATRIX에 없어 그 파츠는 좌우가 바뀐다 — 몸통 공격 변형 때만 잠깐)
// - COLOR(= 그림 x modulate 색조) 위에 **더하고 곱한다** — 색조·피격 번쩍임은 그대로 남는다

group_uniforms light;
// 캐릭터에서 광원 쪽(월드). 정규화 안 해도 된다. 기본 = 바로 위
uniform vec2 light_dir = vec2(0.0, -1.0);

group_uniforms rim;
// 빛 색
uniform vec4 rim_color : source_color = vec4(0.85, 0.92, 1.0, 1.0);
// 세기. 1이면 가장자리가 빛 색으로 거의 덮인다
uniform float rim_strength : hint_range(0.0, 2.0) = 0.7;
// 두께(화면 픽셀)
uniform float rim_px : hint_range(0.5, 8.0) = 2.0;
// 빛을 정면으로 받는 가장자리만 밝힐지(1) 옆면까지 넓게 밝힐지(0) — 작을수록 둘레를 많이 두른다
uniform float rim_focus : hint_range(0.0, 1.0) = 0.55;

group_uniforms shade;
// 광원 반대쪽 가장자리를 이 색 쪽으로 누른다
uniform vec4 shade_color : source_color = vec4(0.10, 0.08, 0.16, 1.0);
uniform float shade_strength : hint_range(0.0, 1.0) = 0.35;
// 그늘 두께(화면 픽셀) — 림보다 조금 두꺼운 게 자연스럽다
uniform float shade_px : hint_range(0.5, 12.0) = 3.0;

group_uniforms gradient;
// 파츠 안 위아래 명암. 0.1이면 빛 쪽 끝 +10%, 반대쪽 끝 -10%
uniform float gradient_strength : hint_range(0.0, 0.5) = 0.10;

varying vec2 v_light_local;

void vertex() {
	mat2 m = mat2(MODEL_MATRIX[0].xy, MODEL_MATRIX[1].xy);
	vec2 l = inverse(m) * light_dir;
	v_light_local = length(l) > 0.0001 ? normalize(l) : vec2(0.0, -1.0);
}

// 네 이웃 알파에서 "둘레 안에 빈 곳이 있는 정도"(0~1)와 바깥 법선을 뽑는다.
// (UV·TEXTURE 같은 내장값은 함수 안에서 못 쓰고, TEXTURE를 인자로 넘기면 헤드리스 컴파일러가 거부한다 —
//  그래서 샘플링은 fragment()에서 하고 숫자만 넘긴다)
void edge_from(float ax0, float ax1, float ay0, float ay1, out float edge, out vec2 normal) {
	edge = clamp(1.0 - min(min(ax0, ax1), min(ay0, ay1)), 0.0, 1.0);
	vec2 grad = vec2(ax1 - ax0, ay1 - ay0);   // 알파가 커지는 쪽 = 안쪽
	normal = length(grad) > 0.001 ? -normalize(grad) : vec2(0.0);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a > 0.05) {
		// 3. 위아래 명암 — 텍스처 가운데를 기준으로 빛 쪽이 +
		if (gradient_strength > 0.0) {
			float h = dot(UV - 0.5, v_light_local);   // 대략 -0.7 ~ 0.7
			COLOR.rgb *= 1.0 + gradient_strength * clamp(h * 2.0, -1.0, 1.0);
		}
		vec2 fw = fwidth(UV);
		// 1. 림 — 윗가장자리
		if (rim_strength > 0.0) {
			vec2 d = fw * rim_px;
			float edge; vec2 n;
			edge_from(texture(TEXTURE, UV - vec2(d.x, 0.0)).a, texture(TEXTURE, UV + vec2(d.x, 0.0)).a,
				texture(TEXTURE, UV - vec2(0.0, d.y)).a, texture(TEXTURE, UV + vec2(0.0, d.y)).a, edge, n);
			float facing = dot(n, v_light_local);
			float lit = smoothstep(rim_focus - 0.35, rim_focus + 0.35, facing);
			COLOR.rgb += rim_color.rgb * edge * lit * rim_strength * COLOR.a;
		}
		// 2. 그늘 — 아랫가장자리
		if (shade_strength > 0.0) {
			vec2 d = fw * shade_px;
			float edge; vec2 n;
			edge_from(texture(TEXTURE, UV - vec2(d.x, 0.0)).a, texture(TEXTURE, UV + vec2(d.x, 0.0)).a,
				texture(TEXTURE, UV - vec2(0.0, d.y)).a, texture(TEXTURE, UV + vec2(0.0, d.y)).a, edge, n);
			float away = smoothstep(0.1, 0.8, dot(n, -v_light_local));
			COLOR.rgb = mix(COLOR.rgb, shade_color.rgb * COLOR.a, edge * away * shade_strength);
		}
	}
}
