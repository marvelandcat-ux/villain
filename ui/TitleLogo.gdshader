shader_type canvas_item;

// 타이틀 로고 글자 안쪽(타이틀_채움.png)과 빛 번짐(타이틀_빛.png)을 칠한다 — 값은 ui/TitleLogo.gd가 매 프레임 넣는다.
// 하양(base_color)과 왼쪽 -> 오른쪽으로 흐르는 무지개를 rainbow(0~1)로 섞고, 사선 빛줄기(sweep_*)가 훑고 지나간다.
// is_glow면 같은 색으로 번짐 그림을 glow_strength만큼 깐다(글자 둘레 은은한 빛)

uniform vec4 base_color : source_color = vec4(0.93, 0.92, 1.0, 1.0);
uniform float rainbow : hint_range(0.0, 1.0) = 0.0;
// 무지개가 흐른 거리(1 = 한 바퀴) — 커질수록 색이 오른쪽으로 흘러간다
uniform float flow = 0.0;
// 로고 가로 폭에 무지개가 몇 바퀴 들어가는지
uniform float rainbow_scale = 0.9;
uniform float saturation : hint_range(0.0, 1.0) = 0.75;
// 빛줄기 가운데 위치(로고 가로 0~1, 밖이면 안 보임)·폭·세기·기울기
uniform float sweep_pos = -1.0;
uniform float sweep_width = 0.07;
uniform float sweep_strength = 1.0;
uniform float sweep_slant = 0.35;
uniform bool is_glow = false;
uniform float glow_strength = 0.4;

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec3 rb = hsv2rgb(vec3(fract(UV.x * rainbow_scale - flow), saturation, 1.0));
	vec3 col = mix(base_color.rgb, rb, rainbow);
	float d = abs(UV.x + (UV.y - 0.5) * sweep_slant - sweep_pos);
	float s = (1.0 - smoothstep(0.0, sweep_width, d)) * sweep_strength;
	if (is_glow) {
		COLOR = vec4(col, a * clamp(glow_strength + s * 0.6, 0.0, 1.0));
	} else {
		col = mix(col, vec3(1.0), s);
		// 하얀 글자 위에서도 빛줄기가 보이게 살짝 더 밝힌다(화면에서 1을 넘는 만큼은 잘려도 가장자리가 부드럽게 보인다)
		COLOR = vec4(col * (1.0 + s * 0.25), a);
	}
}
