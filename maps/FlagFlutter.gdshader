shader_type canvas_item;

// 옆으로 뻗은 깃발을 그림 한 장으로 펄럭이게 한다(튜토리얼 국기, 2026-10-01).
// 깃대 쪽(hoist_x 왼쪽)은 고정, 오른쪽 끝으로 갈수록 크게 출렁이는 물결이 깃대에서 끝으로 흘러간다.
// 픽셀을 밀어서 샘플링하는 방식이라 출렁이는 만큼 그림 위아래·오른쪽에 투명 여백이 있어야 한다.
// (아래로 늘어진 깃발은 ui/story/FlagWave.gdshader)

// 깃대와 천이 만나는 x(텍스처 px). 이보다 왼쪽(깃대)은 안 움직인다
uniform float hoist_x = 355.0;
// 깃대에서 천 끝까지 폭(px) — 끝에서 흔들림이 최대
uniform float flag_width = 470.0;
// 끝자락이 위아래로 출렁이는 최대 거리(px)
uniform float amplitude = 28.0;
// 물결이 흘러가는 빠르기(라디안/초)
uniform float wave_speed = 4.0;
// 물결 한 마디 길이(px)
uniform float wavelength = 320.0;
// 끝자락이 깃대 쪽으로 살짝 당겨졌다 펴지는 정도(px)
uniform float stretch = 10.0;
// 물결 따라 밝기가 변하는 정도 — 주름 그늘
uniform float shade = 0.12;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	float away = px.x - hoist_x;
	float k = clamp(away / max(flag_width, 1.0), 0.0, 1.0);
	// 깃대 근처는 거의 안 움직이게 곡선으로
	float w = k * k * (3.0 - 2.0 * k);
	float ang = TIME * wave_speed - away / max(wavelength, 1.0) * 6.2831853;
	// 큰 물결 + 잔물결을 섞어 기계적인 반복을 줄인다
	float wave = sin(ang) + 0.3 * sin(ang * 2.3 + 1.7);
	vec2 offset = vec2(stretch * w * (0.5 + 0.5 * cos(ang)), amplitude * w * wave);
	vec4 c = texture(TEXTURE, (px - offset) * TEXTURE_PIXEL_SIZE);
	c.rgb *= 1.0 + shade * w * cos(ang);
	COLOR = c * v_modulate;
}
