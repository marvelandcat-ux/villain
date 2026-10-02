shader_type canvas_item;

// 기본공격이 상대 방어에 막혀 잠겨 있는 동안 캐릭터 파츠에 두르는 빨간 테두리.
// `BodyRig._set_blocked_outline()`이 잠긴 동안에만 런타임으로 붙였다 뗀다 — 평소에는 material이 아예 없다.
//
// **바깥이 아니라 안쪽으로 그리는 테두리다.** 바깥으로 번지게 하면 그림의 투명 여백 안에서만 그릴 수 있어서,
// 여백이 좁은 파츠(발 179x101 중 내용이 159x73)에서는 테두리가 뚝 잘린다. 안쪽으로 그리면 여백과 상관없이
// 어느 파츠에서든 같은 두께로 나온다. (`ui/story/RimGlow.gdshader`는 반대로 바깥으로 번지는 쪽이다)
//
// 두께(outline_width)는 **텍스처 픽셀** 기준이다. 이 리그는 파츠마다 배율이 제각각이라
// (머리 0.048 / 손 0.11 / 몸 0.035) GDScript가 "화면 픽셀 / 그 파츠의 배율"로 환산해서 넣어준다 —
// 안 그러면 같은 값을 줘도 머리만 머리카락처럼 얇게 나온다.

// 테두리 색
uniform vec4 outline_color : source_color = vec4(1.0, 0.12, 0.12, 1.0);
// 안쪽으로 칠하는 두께(텍스처 픽셀)
uniform float outline_width = 40.0;
// 테두리 진하기 (깜빡임에 맞춰 코드가 매 프레임 넣는다. 0이면 원래 그림 그대로)
uniform float outline_alpha = 1.0;

// 둘레를 몇 방향으로 훑는지 / 한 방향에서 몇 단계 거리를 보는지
const int SAMPLES = 10;
const int STEPS = 2;

void fragment() {
	// COLOR(= 노드 modulate·색조)를 곱한다 — 안 곱하면 테두리가 붙은 동안 걸려 있던 색조(주정뱅이 술 빨개짐 등)·피격 번쩍임이 사라졌다
	vec4 tint = COLOR;
	vec4 src = texture(TEXTURE, UV);
	float edge = 0.0;
	// 몸이 있는 자리에서만 본다 — 둘레에 빈 곳이 가까울수록 "가장자리"다
	if (src.a > 0.35 && outline_alpha > 0.0) {
		for (int i = 0; i < SAMPLES; i++) {
			float ang = 6.2831853 * float(i) / float(SAMPLES);
			vec2 dir = vec2(cos(ang), sin(ang));
			for (int r = 1; r <= STEPS; r++) {
				float dist = outline_width * float(r) / float(STEPS);
				float a = texture(TEXTURE, UV + dir * dist * TEXTURE_PIXEL_SIZE).a;
				// 가까운 데서 비면 진하게, 멀리서 비면 옅게 — 안쪽으로 갈수록 부드럽게 사라진다
				edge = max(edge, (1.0 - a) * (1.0 - float(r - 1) / float(STEPS + 1)));
			}
		}
	}
	float amount = clamp(edge, 0.0, 1.0) * outline_alpha;
	// 투명도는 원래대로 두고 색만 빨갛게 덮는다 (실루엣이 안 두꺼워진다)
	COLOR = vec4(mix(src.rgb * tint.rgb, outline_color.rgb, amount), src.a * tint.a);
}
