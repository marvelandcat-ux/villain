class_name SpeedLines
extends Node2D

## 대시·자전거 돌진의 하얀 스피드 라인 (순수 장식, 판정 없음). 그림 없이 `_draw()`로 그린다.
## 줄은 **맵에 고정** — 출발한 자리에서 시작해 시전자가 간 데까지 늘어나고, 시전자가 멈추면 그 자리에 남는다.
## 앞쪽(시전자 쪽) 끝이 진하고 뒤쪽 꼬리로 갈수록 투명하며, 끝나면 꼬리 쪽부터 천천히 지워진다(2026-10-05 사용자 요청)

## 줄 하나 — x는 이 노드(출발점) 기준, 진행 방향 쪽이 +
class Line:
	var y: float = 0.0
	var tail_x: float = 0.0
	var head_back: float = 0.0   # 시전자 위치보다 이만큼 뒤에서 줄이 끝난다
	var width: float = 1.6

## 줄 개수
@export var line_count: int = 4
## 줄 색
@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.6)
## 줄이 생기는 높이 범위 (몸 기준, y는 음수가 위쪽)
@export var spread_y: Vector2 = Vector2(-40.0, 24.0)
## 끝난 뒤 꼬리부터 다 지워지기까지 걸리는 시간(초)
@export var fade_time: float = 0.45

var _caster: Node2D = null
var _dir: float = 1.0
var _left: float = 0.0
## 시전자가 진행 방향으로 가장 멀리 간 거리 (뒤로 밀려도 줄이 줄어들지 않게)
var _reach: float = 0.0
## 지워지는 진행도 0~1 (0 = 아직 안 지워짐)
var _fade: float = 0.0
var _lines: Array[Line] = []

## 돌진이 시작될 때 부른다 — **add_child 다음에** 부를 것(출발점을 시전자 자리로 잡는다)
func setup(caster: Node2D, direction: float, life: float) -> void:
	_caster = caster
	_dir = direction
	_left = life
	z_index = -1   # 캐릭터 뒤에 깔린다
	global_position = caster.global_position
	# 높이 범위를 줄 개수만큼 나눠 칸마다 하나씩 — 줄끼리 너무 붙지 않게
	var band: float = (spread_y.y - spread_y.x) / maxf(line_count, 1)
	for i in line_count:
		var l := Line.new()
		l.y = spread_y.x + band * (i + randf_range(0.2, 0.8))
		l.tail_x = randf_range(-10.0, 14.0)
		l.head_back = randf_range(4.0, 22.0)
		l.width = randf_range(1.4, 2.4)
		_lines.append(l)

## 돌진이 일찍 끝났을 때 부른다 — 줄은 그 자리에 남아 꼬리부터 지워진다
func stop() -> void:
	_left = 0.0

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	if _left > 0.0:
		_left = maxf(_left - delta, 0.0)
		if is_instance_valid(_caster):
			_reach = maxf(_reach, (_caster.global_position.x - global_position.x) * _dir)
		else:
			_left = 0.0
	else:
		_fade = minf(_fade + delta / maxf(fade_time, 0.01), 1.0)
		if _fade >= 1.0:
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	for l in _lines:
		var head: float = _reach - l.head_back
		if head <= l.tail_x:
			continue
		# 지워지는 동안 줄의 시작점(투명한 꼬리)이 앞쪽 끝으로 천천히 다가온다
		var tail: float = lerpf(l.tail_x, head, _fade)
		var head_col: Color = line_color
		head_col.a *= 1.0 - _fade * _fade   # 앞쪽 끝은 마지막에 가서야 옅어진다
		var tail_col: Color = head_col
		tail_col.a = 0.0
		draw_polyline_colors(PackedVector2Array([Vector2(tail * _dir, l.y), Vector2(head * _dir, l.y)]),
			PackedColorArray([tail_col, head_col]), l.width)
