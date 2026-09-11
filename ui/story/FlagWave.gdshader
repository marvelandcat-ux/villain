shader_type canvas_item;

// 깃발을 살짝 펄럭이게 한다 — 깃대에 붙은 쪽은 고정, 깃대에서 멀어질수록 조금씩 더 흔들린다.
// 픽셀을 옆으로 밀어서 샘플링하는 방식이라 그림 한 장으로 된다(뼈대·메시 불필요).
// 깃대 선은 텍스처 픽셀 좌표로 x = hoist_x0 + hoist_slope * y. 깃발은 이 선의 왼쪽으로 늘어져 있다고 본다.
// (경찰서 깃발 3개는 모두 오른쪽이 깃대 — 반대 방향 깃발을 쓰려면 away 부호를 뒤집을 것)

// 깃대 선이 그림 맨 윗줄(y=0)에서 지나는 x(px)
uniform float hoist_x0 = 0.0;
// 아래로 1px 내려갈 때 깃대 선이 옆으로 가는 양 (음수면 왼쪽으로 기울어짐)
uniform float hoist_slope = 0.0;
// 깃대에서 깃발 끝자락까지의 폭(px) — 끝자락이 amplitude만큼 흔들린다
uniform float flag_width = 30.0;
// 끝자락이 흔들리는 최대 거리(px). "살짝"이라 작게 둔다
uniform float amplitude = 3.0;
// 물결이 지나가는 빠르기(라디안/초)
uniform float wave_speed = 2.6;
// 물결 한 마디 길이(px)
uniform float wavelength = 70.0;
// 깃발마다 박자를 어긋나게 하는 값(라디안) — 셋이 똑같이 움직이면 기계 같다
uniform float phase = 0.0;
// 물결 따라 밝기가 살짝 변하는 정도 — 주름진 느낌
uniform float shade = 0.08;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	float away = (hoist_x0 + hoist_slope * px.y) - px.x;
	float k = clamp(away / max(flag_width, 1.0), 0.0, 1.0);
	float ang = TIME * wave_speed - (px.y + away * 0.5) / max(wavelength, 1.0) * 6.2831853 + phase;
	vec2 offset = vec2(amplitude * k * sin(ang), amplitude * 0.35 * k * cos(ang * 0.7));
	vec4 c = texture(TEXTURE, (px - offset) * TEXTURE_PIXEL_SIZE);
	c.rgb *= 1.0 + shade * k * cos(ang);
	COLOR = c * v_modulate;
}
