shader_type canvas_item;

// 검은 배경에서 인물 가장자리에 옅은 흰 빛이 도는 효과 (스토리 7번 돌 던지기 장면, 2026-09-13 사용자 요청).
// 바깥으로 번지는 폭을 TEXTURE_PIXEL_SIZE로 재기 때문에 노드 배율을 바꿔도 그림 기준 폭은 그대로다.
//
// **주의: 번지는 폭이 그림의 투명 여백보다 넓으면 빛이 잘린다.**
// 돌 던지는 그림들은 캔버스 1106x1422에 내용이 (69,92)~(1077,1345)라 여백이 가장 좁은 쪽이 29px이다 —
// glow_width를 그보다 크게 주면 오른쪽에서 빛이 뚝 끊긴다.

// 빛 색깔. 알파는 빛 전체의 진하기를 한 번 더 곱한다
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 몸 바깥으로 번지는 폭(텍스처 픽셀)
uniform float glow_width = 16.0;
// 가장 진한 곳(몸에 딱 붙은 곳)의 세기
uniform float glow_strength = 0.55;
// 몸 자체를 흰색 쪽으로 살짝 밝히는 정도 (0이면 원래 색 그대로)
uniform float body_light = 0.10;

// 둘레를 몇 방향으로 훑는지 / 한 방향에서 몇 단계 거리를 보는지.
// 늘리면 부드러워지지만 픽셀당 samples x steps 번 텍스처를 읽는다
const int SAMPLES = 12;
const int STEPS = 3;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	// 둘레를 훑어 "가까운 곳에 몸이 있는가"를 재고, 가까울수록 진하게 남긴다
	float ring = 0.0;
	for (int i = 0; i < SAMPLES; i++) {
		float ang = 6.2831853 * float(i) / float(SAMPLES);
		vec2 dir = vec2(cos(ang), sin(ang));
		for (int r = 1; r <= STEPS; r++) {
			float dist = glow_width * float(r) / float(STEPS);
			float a = texture(TEXTURE, UV + dir * dist * TEXTURE_PIXEL_SIZE).a;
			ring = max(ring, a * (1.0 - float(r - 1) / float(STEPS)));
		}
	}
	float halo = clamp(ring - src.a, 0.0, 1.0) * glow_strength;
	vec3 lit = mix(src.rgb, glow_color.rgb, body_light * src.a);
	COLOR = vec4(mix(glow_color.rgb, lit, src.a), max(src.a, halo * glow_color.a));
}
