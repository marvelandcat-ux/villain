shader_type canvas_item;

// 컷인 배경으로 깔리는 그림을 흐리게 만드는 셰이더.
// 텍스처를 주변 9군데에서 같이 뽑아 평균내는 방식이라 별도 이미지가 필요 없다.
// blur_amount는 몇 픽셀만큼 번지게 할지 (원본 텍스처 픽셀 기준)
uniform float blur_amount : hint_range(0.0, 30.0) = 8.0;

void fragment() {
	vec2 step_size = TEXTURE_PIXEL_SIZE * blur_amount;
	vec4 sum = vec4(0.0);
	// 가운데를 가장 무겁게 두는 3x3 가중치 (1 2 1 / 2 4 2 / 1 2 1) / 16
	sum += texture(TEXTURE, UV + vec2(-step_size.x, -step_size.y)) * 0.0625;
	sum += texture(TEXTURE, UV + vec2(0.0, -step_size.y)) * 0.125;
	sum += texture(TEXTURE, UV + vec2(step_size.x, -step_size.y)) * 0.0625;
	sum += texture(TEXTURE, UV + vec2(-step_size.x, 0.0)) * 0.125;
	sum += texture(TEXTURE, UV) * 0.25;
	sum += texture(TEXTURE, UV + vec2(step_size.x, 0.0)) * 0.125;
	sum += texture(TEXTURE, UV + vec2(-step_size.x, step_size.y)) * 0.0625;
	sum += texture(TEXTURE, UV + vec2(0.0, step_size.y)) * 0.125;
	sum += texture(TEXTURE, UV + vec2(step_size.x, step_size.y)) * 0.0625;
	COLOR = sum * COLOR;
}
