shader_type canvas_item;
render_mode unshaded;

// 카운터 히트 때 캐릭터 뒤 배경을 살짝 흐린다(2026-10-10, combat/CounterHitFx.gd).
// 카메라 화면(screen_texture)을 주변에서 여러 번 뽑아 평균낸 뒤 덮는다 — 캐릭터는 이 판(z 2000)보다 위로 잠깐 올라가 있어 또렷하다.
// 뽑는 방식은 maps/far_blur.gdshader와 같다(밉맵에 기대지 않아서 렌더러가 달라도 똑같이 흐려진다).
// unshaded인 이유는 ScreenGrade와 같다: 읽어 온 화면은 이미 CanvasModulate·조명을 받은 결과라 또 받으면 두 번 어두워진다.
// 세기는 그리는 노드의 modulate 알파(COLOR.a) — 0이면 원본 그대로, 1이면 다 흐림
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// 몇 픽셀만큼 번지게 할지 — 화면 높이 720 기준 픽셀이라 창 크기가 달라도 흐린 정도가 같다. 2026-10-10 사용자 요청으로 50%(2.2 → 1.1)
uniform float blur_px : hint_range(0.0, 8.0) = 1.1;
// 흐린 배경을 살짝 어둡게 — 캐릭터가 더 떠 보인다. 0이면 안 어둡게
uniform float darken : hint_range(0.0, 0.6) = 0.12;

void fragment() {
	vec3 src = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	// 화면 높이 720 기준 1픽셀이 지금 화면에서 UV로 얼마인지
	vec2 unit = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0) / 720.0;
	vec2 step_size = unit * blur_px;
	vec3 sum = vec3(0.0);
	float total = 0.0;
	// 5x5 가우시안 — 가운데가 가장 무겁다
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) / 4.5);
			sum += textureLod(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * step_size, 0.0).rgb * w;
			total += w;
		}
	}
	vec3 c = sum / total;
	c *= 1.0 - darken;
	COLOR = vec4(mix(src, c, COLOR.a), 1.0);
}
