shader_type canvas_item;
render_mode blend_add;

// 체력바를 네온사인/LED 스트립처럼 보이게 한다(2026-09-18 사용자 요청 "네온이나 led 느낌").
// **핵심은 blend_add다** — 보통 알파 블렌드로는 아무리 밝게 섞어도 "칠해진 색"처럼 보이고,
// 더하기 블렌드라야 뒤에 깔린 어두운 HUD 위로 빛이 번져 나오는 것처럼 보인다.
// 이 material은 HPBar 노드 하나에만 걸려 있어서 옆의 검은 테두리(HPFrame)는 그대로 어둡게 남는다.
//
// 채움(StyleBoxFlat)에 준 shadow_color/shadow_size(halo)도 이 노드의 draw 안에 포함되므로
// 같이 더하기 블렌드를 타 — 차 있는 끝부분 경계가 빛이 새어나오는 것처럼 은은하게 번진다.

// 항상 켜져 있는 기본 밝기 — 1보다 크면 원래 색보다 밝게 타오른다
uniform float base_glow : hint_range(0.0, 2.0) = 1.0;
// 숨쉬듯 오르내리는 폭과 속도(LED 스트립의 breathing 패턴)
uniform float pulse_speed : hint_range(0.1, 8.0) = 1.6;
uniform float pulse_strength : hint_range(0.0, 1.5) = 0.6;
// 바를 따라 계속 흐르는 밝은 띠 — 유리관에 반사되는 빛처럼 훑고 지나간다
uniform float sweep_speed : hint_range(0.0, 4.0) = 0.5;
uniform float sweep_width : hint_range(0.02, 1.0) = 0.18;
uniform float sweep_strength : hint_range(0.0, 2.0) = 0.5;

void fragment() {
	vec3 col = COLOR.rgb * base_glow;

	float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5) * pulse_strength;
	col += COLOR.rgb * pulse;

	// UV.x는 이 draw call(채움 사각형) 안에서의 0~1 위치라, 찬 만큼의 폭 안에서만 훑는다
	float sweep_pos = fract(TIME * sweep_speed);
	float dist = abs(UV.x - sweep_pos);
	float sweep = smoothstep(sweep_width, 0.0, dist);
	col += vec3(1.0) * sweep * sweep_strength * COLOR.a;

	COLOR.rgb = col;
}
