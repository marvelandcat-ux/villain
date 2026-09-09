shader_type canvas_item;

// 그림의 "알파 가장자리"를 따라 안쪽에 선을 그린다.
// 사각형 테두리가 아니라 **그려진 모양 그대로** 둘러싸므로, 사선 도형이든 뭐든 그림만 바꾸면 알아서 따라간다.
// 메인 메뉴 사선 메뉴 항목이 골라졌을 때 쓰는 용도지만, 알파가 있는 그림이면 어디든 재사용 가능.
//
// 주의: Godot 셰이더는 **사용자 함수 안에서 TEXTURE/UV 같은 내장 변수를 쓸 수 없다.**
// 처음에 alpha_at() 같은 헬퍼 함수로 짰다가 컴파일이 통째로 실패해서 선이 아예 안 나왔다.
// 그래서 여덟 방향을 fragment() 안에 펼쳐서 쓴다.

// 선 색
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 선 두께 (원본 텍스처 픽셀 기준)
uniform float line_width : hint_range(0.0, 12.0) = 3.0;
// 선이 얼마나 진한지. 0이면 선이 아예 없다 — 코드에서 이 값을 올렸다 내려서 켜고 끈다
uniform float line_alpha : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tint = COLOR;
	vec4 tex = texture(TEXTURE, UV);
	vec4 base = tex * tint;

	if (line_alpha > 0.001 && tex.a > 0.5) {
		vec2 o = TEXTURE_PIXEL_SIZE * line_width;
		// 여덟 방향 중 하나라도 비어 있으면 여기는 가장자리다.
		// 텍스처 밖은 "비어 있다"고 쳐야 그림이 가장자리에 딱 붙은 위·아래에도 선이 생긴다
		vec2 uv0 = UV + vec2(o.x, 0.0);
		vec2 uv1 = UV + vec2(-o.x, 0.0);
		vec2 uv2 = UV + vec2(0.0, o.y);
		vec2 uv3 = UV + vec2(0.0, -o.y);
		vec2 uv4 = UV + vec2(o.x, o.y);
		vec2 uv5 = UV + vec2(-o.x, o.y);
		vec2 uv6 = UV + vec2(o.x, -o.y);
		vec2 uv7 = UV + vec2(-o.x, -o.y);

		float a0 = (uv0.x > 1.0) ? 0.0 : texture(TEXTURE, uv0).a;
		float a1 = (uv1.x < 0.0) ? 0.0 : texture(TEXTURE, uv1).a;
		float a2 = (uv2.y > 1.0) ? 0.0 : texture(TEXTURE, uv2).a;
		float a3 = (uv3.y < 0.0) ? 0.0 : texture(TEXTURE, uv3).a;
		float a4 = (uv4.x > 1.0 || uv4.y > 1.0) ? 0.0 : texture(TEXTURE, uv4).a;
		float a5 = (uv5.x < 0.0 || uv5.y > 1.0) ? 0.0 : texture(TEXTURE, uv5).a;
		float a6 = (uv6.x > 1.0 || uv6.y < 0.0) ? 0.0 : texture(TEXTURE, uv6).a;
		float a7 = (uv7.x < 0.0 || uv7.y < 0.0) ? 0.0 : texture(TEXTURE, uv7).a;

		float n = min(min(min(a0, a1), min(a2, a3)), min(min(a4, a5), min(a6, a7)));
		float edge = 1.0 - smoothstep(0.2, 0.8, n);
		// 선은 도형 색(modulate)에 물들지 않고 제 색을 유지한다
		base = mix(base, vec4(line_color.rgb, line_color.a), edge * line_alpha);
	}

	COLOR = base;
}
