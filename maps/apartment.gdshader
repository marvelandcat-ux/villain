shader_type canvas_item;

// 아파트 한 동의 벽면을 통째로 그리는 셰이더 (놀이터 맵 배경).
//
// **창문을 노드로 찍지 않는 이유:** 20층짜리 한 동에 창문만 100개가 넘는다.
// 아홉 동이면 노드 900개라 씬 파일이 감당이 안 되고, 색 하나 바꾸려 해도 전부 다시 만들어야 한다.
// 여기서는 폴리곤 한 장 + 셰이더로 격자를 절차적으로 그리고, 층수·창 크기·색을 전부 인스펙터에서 만진다.
//
// 좌표는 **노드 로컬 픽셀**을 그대로 쓴다(vertex()에서 넘겨받는다). 그래서 동마다 원점이 지붕 왼쪽 위에
// 오도록 폴리곤을 만들면, 층이 지붕부터 아래로 세어지고 동끼리 격자 위상이 따로 논다 —
// 전역 좌표를 쓰면 아홉 동의 창문 줄이 전부 한 줄로 맞아버려서 한 덩어리처럼 보인다.

varying vec2 v_local;

/// 벽 색
uniform vec4 wall_color : source_color = vec4(0.88, 0.85, 0.78, 1.0);
/// 창문 색
uniform vec4 window_color : source_color = vec4(0.60, 0.70, 0.78, 1.0);
/// 층과 층 사이 난간(가로줄) 색
uniform vec4 ledge_color : source_color = vec4(0.72, 0.69, 0.62, 1.0);
/// 한 호실의 가로 폭(px). 벽 폭과 딱 나눠떨어질 필요는 없다
uniform float column_w_px = 62.0;
/// 한 층의 높이(px)
uniform float floor_h_px = 46.0;
/// 한 칸에서 창문이 차지하는 비율 (가로, 세로)
uniform vec2 window_fill = vec2(0.52, 0.42);
/// 칸 안에서 창문의 세로 위치 (0=칸 위, 1=칸 아래). 아래쪽에 난간이 있어서 살짝 위로 올린다
uniform float window_center_y = 0.44;
/// 난간이 칸 아래에서 차지하는 두께 비율
uniform float ledge_h = 0.13;
/// 이 동의 폭·높이(px). **`UV`는 못 쓴다** — Polygon2D는 텍스처가 없으면 UV가 전부 0이라
/// "오른쪽 끝"을 UV로 판별할 수가 없다. 그래서 크기를 직접 받아 로컬 좌표와 견준다
uniform vec2 body_size = vec2(320.0, 600.0);
/// 오른쪽 끝을 어둡게 해서 입체감을 준다 (차지하는 가로 비율)
uniform float side_shade_w = 0.10;
/// 그 그늘의 어두운 정도
uniform float side_shade = 0.90;
/// 멀리 있는 동일수록 하늘색에 섞어 흐리게 만든다 (0=선명, 1=하늘색)
uniform float haze : hint_range(0.0, 1.0) = 0.0;
/// 섞을 하늘색. 맵의 하늘 폴리곤과 같은 값이어야 자연스럽다
uniform vec4 haze_color : source_color = vec4(0.63, 0.81, 0.95, 1.0);

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec2 cell = vec2(max(column_w_px, 1.0), max(floor_h_px, 1.0));
	vec2 f = fract(v_local / cell);

	vec4 c = wall_color;
	// 창문
	vec2 half_win = window_fill * 0.5;
	if (abs(f.x - 0.5) < half_win.x && abs(f.y - window_center_y) < half_win.y) {
		c = window_color;
	}
	// 층 사이 난간. 창문보다 나중에 칠해서 창문 아래를 덮는다
	if (f.y > 1.0 - ledge_h) {
		c = ledge_color;
	}
	// 오른쪽 면 그늘
	if (v_local.x > body_size.x * (1.0 - side_shade_w)) {
		c.rgb *= side_shade;
	}
	c.rgb = mix(c.rgb, haze_color.rgb, haze);
	c.a = 1.0;
	COLOR = c;
}
