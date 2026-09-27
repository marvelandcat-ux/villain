shader_type canvas_item;
render_mode unshaded;

// 앞 층(카메라 가까이 있는 물체)을 "초점이 안 맞은 것처럼" 살짝 흐리게 그린다.
// 그림 한 장을 주변 25군데에서 뽑아 평균낸다. unshaded라 맵 조명·형광등 빛을 안 받고, 색은 그리는 쪽이 준 색(COLOR)으로 칠한다
// 몇 픽셀만큼 번지게 할지 (원본 텍스처 픽셀 기준)
uniform float blur_amount : hint_range(0.0, 30.0) = 6.0;

void fragment() {
	vec2 step_size = TEXTURE_PIXEL_SIZE * blur_amount * 0.5;
	vec4 sum = vec4(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) / 4.5);
			sum += texture(TEXTURE, UV + vec2(float(x), float(y)) * step_size) * w;
			total += w;
		}
	}
	COLOR = (sum / total) * COLOR;
}
