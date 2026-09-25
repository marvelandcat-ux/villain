shader_type canvas_item;
render_mode unshaded;

// 먼 층(CanvasGroup)을 통째로 흐리게 한다 — 자식들을 한 장으로 합쳐 그린 결과(screen_texture)를 주변에서 여러 번 뽑아 평균낸다.
// 그림마다 따로 흐리면 벽 타일 이음매가 따로 번지므로, 반드시 CanvasGroup의 재질로 쓸 것.
// unshaded인 이유: 자식들이 합쳐질 때 이미 맵 조명·형광등 빛을 받았다 — 여기서 또 받으면 두 번 어두워진다
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// 몇 픽셀만큼 번지게 할지 — 화면 높이 720 기준 픽셀이라 창 크기가 달라도 흐린 정도가 같다
uniform float blur_px : hint_range(0.0, 8.0) = 0.8;
// 먼 층을 조금 더 어둡게(0 = 그대로, 1 = 검정) — 멀리 있는 건 흐리고 어둡게 보인다
uniform float dim : hint_range(0.0, 1.0) = 0.08;

void fragment() {
	// 화면 높이 720 기준 1픽셀이 지금 화면에서 UV로 얼마인지
	vec2 unit = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0) / 720.0;
	vec2 step_size = unit * blur_px;
	vec4 sum = vec4(0.0);
	float total = 0.0;
	// 5x5 가우시안 — 가운데가 가장 무겁다
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) / 4.5);
			sum += textureLod(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * step_size, 0.0) * w;
			total += w;
		}
	}
	vec4 c = sum / total;
	// CanvasGroup 버퍼는 알파가 곱해진 색이라 되돌린다
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	c.rgb *= 1.0 - dim;
	COLOR *= c;
}
