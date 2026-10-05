@tool
extends Node2D

## **제트 엔진 불꽃** — 런닝머신 10스택 로켓 신발 뒤꿈치에서 뒤로 활활 뿜는다(2026-10-06 사용자 지정).
## 자기 좌표의 **왼쪽(-x)으로** 뿜는다 — 신발 그림이 오른쪽을 보고 있어서 뒤가 왼쪽이다.
## 바깥 주황 -> 노랑 -> 하얀 심지 세 겹을 매 프레임 길이를 흔들어 그린다.
##
## 리그를 전혀 모른다 — 대시 잔상이 리그를 복제하면 이 노드도 같이 복제되는데,
## 그때도 혼자 계속 일렁이다 잔상과 함께 사라지면 된다

## 불꽃 길이·굵기(자기 좌표 px — 신발 그림 픽셀 기준이라 신발과 같이 커진다)
@export var length: float = 230.0
@export var width: float = 70.0
## 세기(0~1). 리그가 달리는 빠르기로 넣어 준다
@export_range(0.0, 1.0, 0.05) var power: float = 1.0
## 세기 0(멈춰 있음)일 때도 이만큼은 탄다(길이 비율)
@export_range(0.0, 1.0, 0.05) var idle_power: float = 0.45
## 일렁이는 빠르기
@export var flicker_speed: float = 22.0
## 세 겹 색(바깥 -> 안)
@export var outer_color: Color = Color(1.0, 0.38, 0.08, 0.85)
@export var mid_color: Color = Color(1.0, 0.78, 0.2, 0.95)
@export var core_color: Color = Color(1.0, 0.98, 0.85, 1.0)

const STEPS := 14

var _time: float = 0.0

func _init() -> void:
	# 신발(부모) 뒤에 그린다 — 뒤꿈치 속에서 뿜어 나오는 것처럼
	show_behind_parent = true

func _process(delta: float) -> void:
	_time += minf(delta, 0.05)
	queue_redraw()

func _draw() -> void:
	var p: float = lerpf(idle_power, 1.0, clampf(power, 0.0, 1.0))
	var wobble: float = 0.82 + 0.18 * sin(_time * flicker_speed) * sin(_time * flicker_speed * 0.37 + 1.3)
	_flame(length * p * wobble, width, outer_color, 0.0)
	_flame(length * p * wobble * 0.72, width * 0.66, mid_color, 2.1)
	_flame(length * p * wobble * 0.42, width * 0.36, core_color, 4.4)

## 뒤로 뻗는 물방울 꼴 하나 — 뿌리는 둥글게 부풀고 끝으로 갈수록 뾰족해지며 옆이 살짝 출렁인다.
## 폭이 0이 되는 끝이 있어서 draw_colored_polygon 대신 삼각형을 하나씩 그린다(CLAUDE.md 함정)
func _flame(reach: float, wid: float, color: Color, phase: float) -> void:
	if reach <= 1.0 or wid <= 0.5:
		return
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in STEPS + 1:
		var t: float = float(i) / STEPS
		# 앞 15%에서 둥글게 최대 폭까지 부풀고, 나머지 구간에서 끝으로 가늘어진다
		var shape: float = sqrt(t / 0.15) if t < 0.15 else pow(1.0 - (t - 0.15) / 0.85, 0.8)
		var half: float = wid * 0.5 * shape * (1.0 + 0.12 * sin(_time * 30.0 + t * 9.0 + phase))
		var sway: float = sin(_time * 17.0 + t * 6.0 + phase) * wid * 0.08 * t
		var x: float = -reach * t
		top.append(Vector2(x, -half + sway))
		bottom.append(Vector2(x, half + sway))
	var colors := PackedColorArray([color, color, color])
	for i in STEPS:
		draw_primitive(PackedVector2Array([top[i], top[i + 1], bottom[i + 1]]), colors, PackedVector2Array())
		draw_primitive(PackedVector2Array([top[i], bottom[i + 1], bottom[i]]), colors, PackedVector2Array())
