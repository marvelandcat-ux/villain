shader_type canvas_item;

// 한 장짜리 일러스트에서 "가슴과 팔만" 숨쉬듯 부풀리는 셰이더.
// 파츠를 나누지 않고, 지정한 타원 범위 안쪽만 UV를 중심 쪽으로 당겨서(=확대해서) 부풀린 것처럼 보이게 한다.
// 범위 밖(머리·다리)은 falloff가 0이라 완전히 제자리에 있는다.

// 부풀릴 중심 (텍스처 UV 기준, 0~1). 가슴 한가운데를 가리키면 된다
uniform vec2 breath_center = vec2(0.6, 0.56);
// 부풀릴 범위의 가로/세로 반지름 (UV 기준). 가로를 넓게 잡으면 양팔까지 같이 움직인다
uniform vec2 breath_radius = vec2(0.42, 0.22);
// 가장 부풀었을 때의 확대 비율 (0.02 = 2%)
uniform float breath_amount : hint_range(0.0, 0.2) = 0.03;
// 스크립트가 매 프레임 넣어주는 호흡 위상. sin을 여기서 계산한다
uniform float breath_phase = 0.0;

void fragment() {
	vec2 offset = (UV - breath_center) / max(breath_radius, vec2(0.0001));
	// 중심에서 1, 타원 경계에서 0으로 부드럽게 떨어진다
	float falloff = smoothstep(1.0, 0.0, length(offset));
	// k < 1 이면 더 좁은 영역을 끌어와 그리므로 그 부분이 확대돼 보인다
	float k = 1.0 - breath_amount * (0.5 + 0.5 * sin(breath_phase)) * falloff;
	vec2 uv = breath_center + (UV - breath_center) * k;
	COLOR = texture(TEXTURE, uv);
}
