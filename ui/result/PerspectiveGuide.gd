extends Node2D

## 연행 장면 **원근 가이드** — 배경(건물 정면) 그림을 장면 카메라에 맞추는 밑그림.
## ArrestScene의 `show_perspective_guide`를 켜면 장면 위에 겹쳐 그려진다. 이걸 찍은 것이 `ui/result/backdrops/원근가이드.png`.
##  - 빨간 선 = 지평선(카메라 눈높이). 배경 그림의 눈높이도 이 높이여야 한다
##  - 빨간 점 = 소실점. 길·연석·계단 옆선처럼 안쪽으로 뻗는 선은 전부 여기로 모인다
##  - 초록 선 = 건물이 땅에 닿는 선. 파란 네모 = 출입문 자리(높이 = 캐릭터 키 x door_height)
##  - 회색 막대 = 그 깊이에서 캐릭터 한 명 키
## class_name을 일부러 안 단다 — 장면이 set_script로 붙인다

const FONT_PATH := "res://fonts/Jua-Regular.ttf"

var vanish_x: float = 760.0
var horizon_y: float = 470.0
var camera_height: float = 0.62
var focal: float = 1500.0
var view_rect: Rect2 = Rect2(0, 0, 1280, 720)
## 건물이 땅에 닿는 화면 높이 / 문 가운데 x / 문 높이(캐릭터 키 배수)
var facade_base_y: float = 508.0
var door_screen_x: float = 820.0
var door_height: float = 1.35
## 키 막대를 세울 발 위치들(화면) — [이름, 발 위치]
var markers: Array = []

var _font: Font = null

func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)

func _draw() -> void:
	var red := Color(0.95, 0.15, 0.2)
	var green := Color(0.1, 0.75, 0.3)
	var blue := Color(0.15, 0.45, 1.0)
	var grid := Color(0.1, 0.1, 0.15, 0.35)
	var left: float = view_rect.position.x
	var right: float = view_rect.end.x
	var bottom: float = view_rect.end.y
	# 바닥 격자 — 소실점으로 모이는 세로선(월드 x 1칸 = 캐릭터 키 1)
	for i in range(-14, 15):
		var x_world: float = float(i)
		var near_z: float = 2.2
		var a := _ground(x_world, near_z)
		draw_line(Vector2(vanish_x, horizon_y), a, grid, 1.0, true)
	# 깊이 선(가까울수록 간격이 넓다)
	for z in [3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 10.0, 12.0, 15.0, 20.0, 30.0]:
		var y: float = horizon_y + focal * camera_height / z
		if y < bottom:
			draw_line(Vector2(left, y), Vector2(right, y), grid, 1.0)
	# 지평선 + 소실점
	draw_line(Vector2(left, horizon_y), Vector2(right, horizon_y), red, 3.0)
	draw_circle(Vector2(vanish_x, horizon_y), 7.0, red)
	_label(Vector2(left + 16, horizon_y - 10), "지평선 = 눈높이 (화면 y %d) - 배경 그림의 눈높이도 여기" % int(horizon_y), red)
	_label(Vector2(vanish_x + 12, horizon_y + 26), "소실점 - 안쪽으로 뻗는 선은 전부 여기로", red)
	# 건물이 땅에 닿는 선 + 출입문 자리
	draw_line(Vector2(left, facade_base_y), Vector2(right, facade_base_y), green, 3.0)
	_label(Vector2(left + 16, facade_base_y + 24), "건물이 땅에 닿는 선 (y %d) - 건물 그림 밑변" % int(facade_base_y), green)
	var z_facade: float = focal * camera_height / maxf(facade_base_y - horizon_y, 1.0)
	var unit: float = focal / z_facade
	var door_h: float = door_height * unit
	var door_w: float = door_h * 1.1
	var door := Rect2(door_screen_x - door_w * 0.5, facade_base_y - door_h, door_w, door_h)
	draw_rect(door, Color(blue, 0.18), true)
	draw_rect(door, blue, false, 3.0)
	_label(door.position + Vector2(0, -10), "출입문 자리 (높이 = 캐릭터 %.2f명, %dpx)" % [door_height, int(door_h)], blue)
	# 깊이마다 캐릭터 키 막대
	for m in markers:
		var feet: Vector2 = m[1]
		var z: float = focal * camera_height / maxf(feet.y - horizon_y, 1.0)
		var h: float = focal / z
		draw_rect(Rect2(feet.x - 5.0, feet.y - h, 10.0, h), Color(0.2, 0.2, 0.25, 0.55), true)
		draw_line(Vector2(feet.x - 14.0, feet.y - h), Vector2(feet.x + 14.0, feet.y - h), Color(0.1, 0.1, 0.15), 2.0)
		_label(Vector2(feet.x + 10.0, feet.y - h + 6.0), str(m[0]), Color(0.1, 0.1, 0.15), 16)
	# 화면 테두리(1280x720 기준 화면)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.1, 0.1, 0.5), false, 2.0)

func _ground(x_world: float, z: float) -> Vector2:
	return Vector2(vanish_x + focal * x_world / z, horizon_y + focal * camera_height / z)

func _label(pos: Vector2, text: String, color: Color, size: int = 20) -> void:
	if _font == null:
		return
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, 6, Color(1, 1, 1, 0.9))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
