shader_type canvas_item;
render_mode unshaded;

// 카운터 히트 때 **카메라가 옆으로 살짝 돌아 보는** 원근 연출(2026-10-10, combat/CounterHitFx.gd).
// 2D라 카메라를 실제로 돌릴 수 없어서, 다 그려진 게임 화면을 읽어 "세로축 둘레로 돈 판"처럼 사다리꼴로 휘어 다시 그린다.
// 한쪽 가장자리는 가까워져 커지고 반대쪽은 멀어져 작아진다. 수평선은 안 기운다. HUD(CanvasLayer)는 이 뒤에 그려져 안 휜다.
// unshaded인 이유는 ScreenGrade와 같다: 읽어 온 화면은 이미 조명·색보정을 받은 결과다
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// 돈 각도(라디안). 부호가 방향 — 양수면 오른쪽이 가까워진다. 0이면 원본 그대로
uniform float yaw = 0.0;
// 눈과 화면 사이 거리(화면 반높이 단위). 작을수록 원근이 세다
uniform float depth = 2.2;
// 화면 가로/세로 비 — 가로 거리를 세로와 같은 단위로 재려고
uniform float aspect = 1.7778;
// 휘면서 생기는 빈 가장자리를 안 보이게 살짝 확대(1보다 작을수록 더 확대). 스크립트가 각도에 맞춰 계산한다
uniform float fit = 1.0;
// 휜 뒤 전체를 이만큼 밀어 **맞은 사람 자리가 제자리에 남게** 한다(아래 좌표 단위, 스크립트가 계산)
uniform vec2 shift = vec2(0.0);

void fragment() {
	// 화면 좌표(-1~1, 가로는 aspect배) — 가운데가 0
	vec2 s = (SCREEN_UV - 0.5) * 2.0;
	s.x *= aspect;
	s *= fit;
	// 화면 점 s를 지나는 시선이 "yaw만큼 돈 판"과 만나는 곳의 판 좌표 p를 구한다(원근 투영의 역)
	float c = cos(yaw);
	float sn = sin(yaw);
	float px = s.x * depth / (depth * c - s.x * sn);
	float py = s.y * (depth + px * sn) / depth;
	vec2 p = vec2(px, py) - shift;
	vec2 uv = vec2(p.x / aspect, p.y) * 0.5 + 0.5;
	COLOR = vec4(textureLod(screen_texture, uv, 0.0).rgb, 1.0);
}
