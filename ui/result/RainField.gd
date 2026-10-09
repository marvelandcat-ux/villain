extends Control

## 패배 화면의 비 — 두 겹을 `_draw()` 한 번에 그린다.
##  1) **늘어진 줄**: 화면 위 가장자리에서 아래로 늘어진 검은 줄(레퍼런스의 "주룩" 줄).
##     들어올 때 위에서 쭉 자라 내려오고, 가끔 끝에서 물방울이 똑 떨어진다
##  2) **빗줄기**: 위에서 떨어지는 짧은 선 — 검은 선 위주, 몇 줄은 옅은 회청색
## `start()`로 시작하고, 시간은 `MatchEnding`이 `tick()`으로 넣는다(실제 시간)

@export_group("늘어진 줄")
## 줄 수(0이면 안 그린다) — 뒤 층에만 둔다
@export var hanging_count: int = 0
## 길이 범위(화면 높이 비율)
@export var hanging_length_min: float = 0.07
@export var hanging_length_max: float = 0.46
## 굵기(px)
@export var hanging_width: float = 3.6
## 위에서 자라 내려오는 시간(초)
@export var hanging_grow_time: float = 0.42
## 끝에서 물방울이 떨어지는 간격(초, 줄마다 이 범위에서 뽑는다)
@export var drip_interval_min: float = 0.9
@export var drip_interval_max: float = 2.6

@export_group("빗줄기")
@export var streak_count: int = 60
@export var streak_speed_min: float = 1050.0
@export var streak_speed_max: float = 1650.0
@export var streak_length_min: float = 40.0
@export var streak_length_max: float = 150.0
@export var streak_width_min: float = 1.6
@export var streak_width_max: float = 3.2
## 바람에 기우는 각도(도, 양수면 아래로 갈수록 왼쪽)
@export var wind_deg: float = 5.0

@export_group("색")
@export var dark_color: Color = Color(0.03, 0.02, 0.07, 0.92)
@export var pale_color: Color = Color(0.66, 0.7, 0.86, 0.55)
## 옅은 회청색 줄이 나올 몫
@export_range(0.0, 1.0, 0.01) var pale_ratio: float = 0.22

var _time: float = 0.0
var _running: bool = false
var _rng := RandomNumberGenerator.new()
## 늘어진 줄마다 [x, 길이(px), 나타날 시각, 흔들림 위상, 다음 물방울까지 남은 초]
var _hanging: Array = []
## 빗줄기·물방울마다 [x, y(아래 끝), 속도, 길이, 굵기, 색, 물방울이면 true]
var _streaks: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()

## 비를 시작한다(지금 크기로 줄을 깐다)
func start() -> void:
	_time = 0.0
	_running = true
	_hanging.clear()
	_streaks.clear()
	if hanging_count > 0:
		var gap: float = size.x / float(hanging_count)
		for i in hanging_count:
			var x: float = gap * (float(i) + _rng.randf_range(0.2, 0.8))
			var length: float = size.y * _rng.randf_range(hanging_length_min, hanging_length_max)
			_hanging.append([x, length, _rng.randf_range(0.0, 0.22), _rng.randf() * TAU,
				_rng.randf_range(drip_interval_min, drip_interval_max)])
	for i in streak_count:
		var s: Array = _new_streak()
		# 처음엔 화면 위쪽에 흩어 둬서 위에서부터 차례로 들이친다
		s[1] = _rng.randf_range(-size.y * 1.2, -10.0)
		_streaks.append(s)

## 한 프레임 진행(dt = 실제 초)
func tick(dt: float) -> void:
	if not _running:
		return
	_time += dt
	for h in _hanging:
		h[4] -= dt
		if h[4] <= 0.0:
			h[4] = _rng.randf_range(drip_interval_min, drip_interval_max)
			if _time > float(h[2]) + hanging_grow_time:
				_streaks.append([float(h[0]), _hanging_length(h), 0.0, 12.0, hanging_width * 0.9, dark_color, true])
	var i: int = _streaks.size() - 1
	while i >= 0:
		var s: Array = _streaks[i]
		if s[6]:
			# 물방울은 매달려 있다 떨어지듯 점점 빨라진다
			s[2] = float(s[2]) + 2600.0 * dt
		s[1] = float(s[1]) + float(s[2]) * dt
		s[0] = float(s[0]) - float(s[2]) * dt * tan(deg_to_rad(wind_deg))
		if float(s[1]) - float(s[3]) > size.y + 20.0:
			if s[6]:
				_streaks.remove_at(i)
			else:
				_streaks[i] = _new_streak()
		i -= 1
	queue_redraw()

func _new_streak() -> Array:
	var length: float = _rng.randf_range(streak_length_min, streak_length_max)
	var col: Color = pale_color if _rng.randf() < pale_ratio else dark_color
	# 바람에 밀리는 만큼 오른쪽에 여유를 둬서 화면 왼쪽 아래가 비지 않게 한다
	var lean: float = size.y * tan(deg_to_rad(wind_deg))
	return [_rng.randf_range(-20.0, size.x + 20.0 + lean), _rng.randf_range(-160.0, -10.0),
		_rng.randf_range(streak_speed_min, streak_speed_max), length,
		_rng.randf_range(streak_width_min, streak_width_max), col, false]

func _hanging_length(h: Array) -> float:
	var u: float = clampf((_time - float(h[2])) / maxf(hanging_grow_time, 0.01), 0.0, 1.0)
	var grow: float = 1.0 - pow(1.0 - u, 3.0)
	return float(h[1]) * grow * (1.0 + 0.035 * sin(_time * 1.4 + float(h[3])))

func _draw() -> void:
	if not _running:
		return
	for h in _hanging:
		var length: float = _hanging_length(h)
		if length > 1.0:
			var x: float = float(h[0])
			draw_line(Vector2(x, -8.0), Vector2(x, length), dark_color, hanging_width, true)
	var slope: float = tan(deg_to_rad(wind_deg))
	for s in _streaks:
		var tip := Vector2(float(s[0]), float(s[1]))
		var length: float = float(s[3])
		draw_line(tip, tip + Vector2(length * slope, -length), s[5], float(s[4]), true)
