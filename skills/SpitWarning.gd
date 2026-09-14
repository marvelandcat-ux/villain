class_name SpitWarning
extends Node2D

## 침이 날아올 자리를 미리 알려주는 **하늘색 파선** (순수 장식 — 판정이 없다).
## 그림 없이 `_draw()`로 그리므로 색·굵기·점선 간격을 인스펙터에서 바로 만질 수 있다.
## `IljinCrewMember`가 침을 뱉기 직전에 입 앞에 띄운다.

## 선 색 (하늘색)
@export var line_color: Color = Color(0.45, 0.85, 1.0, 0.95)
## 선 굵기(px)
@export var thickness: float = 3.0
## 점선 한 칸 길이와 빈칸 길이(px)
@export var dash: float = 15.0
@export var gap: float = 11.0
## 점선이 날아갈 방향으로 흘러가는 속도(px/초). 0이면 제자리에 멈춰 있다
@export var flow_speed: float = 120.0
## 보이는 동안 깜빡이는 횟수
@export var blink_cycles: float = 3.0
## 가장 옅을 때의 진하기 (0이면 완전히 사라졌다 나타난다)
@export_range(0.0, 1.0, 0.05) var min_alpha: float = 0.35

var _length: float = 0.0
var _dir: float = 1.0
var _left: float = 0.0
var _span: float = 0.0
var _phase: float = 0.0

## 띄우는 쪽이 스폰 직후 부른다. direction은 +1/-1, length는 침이 실제로 날아갈 거리(px)
func setup(direction: float, length: float, duration: float) -> void:
	_dir = 1.0 if direction >= 0.0 else -1.0
	_length = maxf(length, 0.0)
	_span = maxf(duration, 0.01)
	_left = _span
	queue_redraw()

func _process(delta: float) -> void:
	_phase += flow_speed * delta
	_left = maxf(_left - delta, 0.0)
	queue_redraw()
	if _left <= 0.0:
		queue_free()

func _draw() -> void:
	var step: float = dash + gap
	if _length <= 0.0 or step <= 0.0:
		return
	var col: Color = line_color
	# 보이는 동안 깜빡인다 — 가만히 켜두면 배경에 그어진 선처럼 보여서 "경고"로 안 읽힌다
	var done: float = 1.0 - _left / _span
	var wave: float = 0.5 + 0.5 * cos(done * TAU * blink_cycles)
	col.a *= lerpf(min_alpha, 1.0, wave)
	# 시작점을 한 칸 뒤로 물려서 점선이 앞으로 흐르는 것처럼 보이게 한다
	var x: float = -fposmod(_phase, step)
	while x < _length:
		var a: float = maxf(x, 0.0)
		var b: float = minf(x + dash, _length)
		if b > a:
			draw_line(Vector2(a * _dir, 0.0), Vector2(b * _dir, 0.0), col, thickness)
		x += step
