@tool
class_name Pigeon
extends Node2D

## 승강장 바닥을 돌아다니는 비둘기 (순수 장식 — 충돌·판정 없음).
## 평소엔 뒤뚱뒤뚱 걷다가 바닥을 쪼고, **열차 경고등이 켜지면 푸드덕 날아 화면 밖으로** 사라졌다가
## 열차가 지나가고 잠시 뒤에 다시 내려앉는다 — "열차가 온다"를 눈으로 한 번 더 알려주는 역할도 한다.
##
## **노드를 놓은 자리가 비둘기가 서 있는 바닥**이다(에디터에서 옮기면 그 높이에 내려앉는다).
## 그림 없이 `_draw()`로 그리므로 스프라이트를 받으면 `_draw()`만 바꾸면 된다

enum Mode { GROUND, FLEE, AWAY, RETURN }

## --- 모양 ---
## 비둘기 크기(px). 캐릭터가 90px이라 이 정도면 발치에 오는 크기다
@export var size_px: float = 16.0
@export var body_color: Color = Color(0.6, 0.62, 0.68)
@export var head_color: Color = Color(0.46, 0.55, 0.7)
@export var beak_color: Color = Color(0.96, 0.7, 0.26)
@export var outline_color: Color = Color(0.09, 0.1, 0.13)

## --- 평소 ---
## 걷는 속도(px/초)와 처음 자리에서 벗어날 수 있는 거리(px)
@export var walk_speed: float = 26.0
@export var walk_range: float = 90.0
## 한 번 쪼고 다음 쪼기까지 기다리는 시간(초) 범위
@export var peck_interval_min: float = 0.9
@export var peck_interval_max: float = 2.6
## 쪼는 동작 한 번에 걸리는 시간(초)
@export var peck_time: float = 0.28

## --- 열차가 올 때 ---
## 날아오르는 속도(px/초)
@export var flee_speed: float = 260.0
## 날개짓 빠르기
@export var flap_speed: float = 16.0
## 열차가 다 지나간 뒤 몇 초 있다 돌아오는지
@export var return_delay: float = 1.6

var _mode: int = Mode.GROUND
var _home: Vector2 = Vector2.ZERO
var _face: float = 1.0
var _time: float = 0.0
var _peck_left: float = 1.0
var _peck: float = 0.0
var _walk_left: float = 0.0
var _flap: float = 0.0
var _wait: float = 0.0
var _fly_dir: Vector2 = Vector2(-1.0, -1.0)
var _train: SubwayTrain = null

func _ready() -> void:
	_home = position
	_peck_left = randf_range(peck_interval_min, peck_interval_max)
	_face = 1.0 if randf() < 0.5 else -1.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_time += delta
	var danger: bool = false
	var train: SubwayTrain = _find_train()
	if train:
		danger = train.is_dangerous()
	match _mode:
		Mode.GROUND:
			if danger:
				_take_off(train)
			else:
				_walk_and_peck(delta)
		Mode.FLEE:
			_flap += delta * flap_speed
			position += _fly_dir * flee_speed * delta
			# 처음 자리에서 충분히 멀어지면 화면 밖으로 친다
			if position.y < _home.y - 320.0:
				_mode = Mode.AWAY
				_wait = return_delay
				visible = false
		Mode.AWAY:
			if not danger:
				_wait -= delta
				if _wait <= 0.0:
					# 처음 자리 근처 위쪽에서 다시 내려온다
					position = Vector2(_home.x + randf_range(-60.0, 60.0), _home.y - 300.0)
					_face = 1.0 if randf() < 0.5 else -1.0
					visible = true
					_mode = Mode.RETURN
		Mode.RETURN:
			_flap += delta * flap_speed
			position.y = minf(position.y + flee_speed * 0.55 * delta, _home.y)
			if is_equal_approx(position.y, _home.y):
				_mode = Mode.GROUND
				_peck_left = randf_range(peck_interval_min, peck_interval_max)
	queue_redraw()

## "subway_train" 그룹의 열차를 찾아 기억해둔다 (열차가 없는 맵이면 계속 바닥에 있는다)
func _find_train() -> SubwayTrain:
	if not is_instance_valid(_train):
		_train = get_tree().get_first_node_in_group("subway_train") as SubwayTrain
	return _train

## 열차가 오는 쪽의 **반대편 위로** 날아오른다 (열차 쪽으로 날아가면 치이는 것처럼 보인다)
func _take_off(train: SubwayTrain) -> void:
	var away: float = -1.0
	if train:
		away = -signf(train.get_direction())
		if is_zero_approx(away):
			away = -1.0
	_fly_dir = Vector2(away * 0.55, -1.0).normalized()
	_face = away
	_mode = Mode.FLEE
	_peck = 0.0

## 가만히 있다가 가끔 몇 걸음 걷고, 멈춰 서서 바닥을 쫀다
func _walk_and_peck(delta: float) -> void:
	if _peck > 0.0:
		_peck = maxf(_peck - delta / maxf(peck_time, 0.01), 0.0)
		return
	if _walk_left > 0.0:
		_walk_left -= delta
		position.x = clampf(position.x + _face * walk_speed * delta, _home.x - walk_range, _home.x + walk_range)
		return
	_peck_left -= delta
	if _peck_left > 0.0:
		return
	_peck_left = randf_range(peck_interval_min, peck_interval_max)
	if randf() < 0.45:
		# 가끔은 쪼는 대신 방향을 정해 몇 걸음 걷는다
		_face = 1.0 if randf() < 0.5 else -1.0
		if position.x > _home.x + walk_range * 0.8:
			_face = -1.0
		elif position.x < _home.x - walk_range * 0.8:
			_face = 1.0
		_walk_left = randf_range(0.4, 1.1)
	else:
		_peck = 1.0

func _draw() -> void:
	var s: float = size_px
	var flying: bool = _mode == Mode.FLEE or _mode == Mode.RETURN
	# 쫄 때는 머리와 몸이 같이 앞아래로 기운다
	var dip: float = sin(_peck * PI) * 0.5
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_face, 1.0))

	var body_c := Vector2(0.0, -s * 0.42)
	var body_r := Vector2(s * 0.46, s * 0.32)
	if not flying and _peck > 0.0:
		body_c += Vector2(s * 0.06 * dip, s * 0.05 * dip)
	# 다리 (날 때는 접는다)
	if not flying:
		var step: float = sin(_time * 9.0) * s * 0.08 if _walk_left > 0.0 else 0.0
		draw_line(Vector2(-s * 0.06 + step, -s * 0.16), Vector2(-s * 0.06 + step, 0.0), outline_color, s * 0.05)
		draw_line(Vector2(s * 0.08 - step, -s * 0.16), Vector2(s * 0.08 - step, 0.0), outline_color, s * 0.05)
	# 꼬리
	draw_colored_polygon(PackedVector2Array([
		Vector2(-s * 0.35, -s * 0.5), Vector2(-s * 0.85, -s * 0.62 + s * 0.1 * dip), Vector2(-s * 0.33, -s * 0.3),
	]), body_color)
	# 몸통
	_draw_ellipse(body_c, body_r, body_color)
	# 날개 — 날 때는 퍼덕이고, 땅에서는 몸에 붙어 있다
	var wing_ang: float = sin(_flap) * 0.9 if flying else 0.15
	var wing := PackedVector2Array([
		Vector2(-s * 0.05, -s * 0.52), Vector2(s * 0.3, -s * 0.34), Vector2(-s * 0.28, -s * 0.24),
	])
	var rotated := PackedVector2Array()
	for p in wing:
		var v: Vector2 = (p - body_c).rotated(wing_ang) + body_c
		rotated.append(v)
	draw_colored_polygon(rotated, head_color)
	# 머리 + 부리 + 눈
	var head := Vector2(s * 0.33, -s * 0.78) + Vector2(s * 0.16 * dip, s * 0.55 * dip)
	draw_circle(head, s * 0.19, head_color)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(s * 0.12, -s * 0.04), head + Vector2(s * 0.36, s * 0.02), head + Vector2(s * 0.12, s * 0.08),
	]), beak_color)
	draw_circle(head + Vector2(s * 0.06, -s * 0.04), s * 0.045, outline_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 타원을 12각형으로 그린다 (draw_circle은 정원뿐이라 몸통이 안 된다)
func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, color)
