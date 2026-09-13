class_name ChargeWind
extends Node2D

## 돌진할 때 몸 주위로 흐르는 바람 줄 — 일진 어깨 들이박기용 (순수 장식, 판정 없음).
## 시전자를 매 프레임 따라다니면서 짧은 선을 뒤로 흘려보낸다. 그림 없이 `_draw()`로 그린다.

## 선 하나
class Streak:
	var pos: Vector2 = Vector2.ZERO
	var len: float = 20.0
	var speed: float = 380.0
	var age: float = 0.0
	var life: float = 0.28
	var width: float = 1.6

## 선을 얼마마다 하나씩 뿌리는지(초)
@export var spawn_interval: float = 0.02
## 한 번에 몇 개씩
@export var per_spawn: int = 2
## 선 색
@export var streak_color: Color = Color(1.0, 1.0, 1.0, 0.55)
## 선이 생기는 범위 (몸 기준, y는 음수가 위쪽)
@export var spread_y: Vector2 = Vector2(-40.0, 24.0)
@export var spread_x: float = 26.0

var _caster: Fighter = null
var _dir: float = 1.0
var _left: float = 0.0
var _timer: float = 0.0
var _streaks: Array[Streak] = []

## 돌진이 시작될 때 스킬이 부른다
func setup(caster: Fighter, direction: float, life: float) -> void:
	_caster = caster
	_dir = direction
	_left = life
	z_index = -1   # 캐릭터 뒤에 깔린다

## 돌진이 일찍 끝났을 때(상대를 받았을 때) 스킬이 부른다 — 남은 선은 흩어질 때까지 그린다
func stop() -> void:
	_left = 0.0

func _process(delta: float) -> void:
	if is_instance_valid(_caster):
		global_position = _caster.global_position
	else:
		_left = 0.0
	if _left > 0.0:
		_left = maxf(_left - delta, 0.0)
		_timer -= delta
		while _timer <= 0.0:
			_timer += spawn_interval
			for i in per_spawn:
				_streaks.append(_make_streak())
	var alive: Array[Streak] = []
	for s in _streaks:
		s.age += delta
		if s.age >= s.life:
			continue
		s.pos.x -= _dir * s.speed * delta
		alive.append(s)
	_streaks = alive
	queue_redraw()
	if _left <= 0.0 and _streaks.is_empty():
		queue_free()

func _make_streak() -> Streak:
	var s := Streak.new()
	# 몸 앞쪽에서 생겨 뒤로 흘러간다 — 길이·속도를 조금씩 다르게 줘야 줄이 겹쳐 보이지 않는다
	s.pos = Vector2(_dir * randf_range(0.0, spread_x), randf_range(spread_y.x, spread_y.y))
	s.len = randf_range(14.0, 34.0)
	s.speed = randf_range(300.0, 520.0)
	s.life = randf_range(0.18, 0.34)
	s.width = randf_range(1.2, 2.2)
	return s

func _draw() -> void:
	for s in _streaks:
		var t: float = s.age / s.life
		var col: Color = streak_color
		col.a *= 1.0 - t
		# 진행 방향의 반대로 길게 눕는다
		draw_line(s.pos, s.pos - Vector2(_dir * s.len, 0.0), col, s.width)
