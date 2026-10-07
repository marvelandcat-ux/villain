@tool
extends Node2D

## 번화가 택시(2026-10-08, **임시 — 그림 없이 `_draw()`로 그린다**).
## `min_interval`~`max_interval`초마다 도로 한쪽 화면 밖에서 나와 반대편 밖으로 달려 나간다(방향 랜덤).
## 닿은 캐릭터는 **피해 없이 높이 튀어 오른다**(스프링 `SpringJumpPad`와 같은 식 — 사용자 결정).
## 원점 = 택시 아래 가운데(바퀴가 도로에 닿는 자리). 그림이 나오면 `_draw()`만 스프라이트로 바꾸면 된다

@export var min_interval: float = 8.0
@export var max_interval: float = 15.0
## 달리는 속도(px/s)
@export var speed: float = 560.0
## 달리는 길의 양 끝(x) — 벽(±926) 바깥에서 나오고 들어간다
@export var start_x: float = 1100.0
## 튀어 오르는 속도(px/s). 중력 기준 약 1000이면 400px 넘게 뜬다
@export var bounce_velocity: float = 1000.0
## 택시 진행 방향으로 함께 미는 속도(px/s). 0이면 위로만 뜬다
@export var push_x: float = 0.0
## 같은 사람을 다시 튕기기까지 쉬는 시간(초) — 지붕에 다시 떨어지면 또 튕긴다
@export var rebounce_delay: float = 0.35
## 캐릭터 원점 ~ 발끝 거리(몸 캡슐 높이 60의 절반)
@export var fighter_foot: float = 30.0

@export_group("모양")
@export var body_length: float = 150.0
@export var body_color: Color = Color(1.0, 0.78, 0.12)
@export var outline_color: Color = Color(0.1, 0.1, 0.12)
@export var window_color: Color = Color(0.55, 0.78, 0.95)
@export var wheel_radius: float = 13.0
@export_group("")

## 택시 꼭대기 높이(표시등 빼고) — 판정에 쓴다
const ROOF_HEIGHT: float = 56.0

var _driving: bool = false
var _dir: float = 1.0
var _wait: float = 0.0
var _wheel_angle: float = 0.0
## {Fighter: 다시 튕길 수 있을 때까지 남은 시간}
var _cooldowns: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	visible = false
	_wait = randf_range(min_interval, max_interval)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	delta = minf(delta, 0.05)
	for f in _cooldowns.keys():
		_cooldowns[f] -= delta
		if _cooldowns[f] <= 0.0:
			_cooldowns.erase(f)
	if not _driving:
		_wait -= delta
		if _wait <= 0.0:
			_start()
		return
	position.x += _dir * speed * delta
	_wheel_angle += _dir * speed * delta / maxf(wheel_radius, 1.0)
	queue_redraw()
	_bounce_fighters()
	if position.x * _dir > start_x:
		_driving = false
		visible = false
		_wait = randf_range(min_interval, max_interval)

func _start() -> void:
	_dir = -1.0 if randf() < 0.5 else 1.0
	position.x = -start_x * _dir
	_driving = true
	visible = true
	queue_redraw()

func _bounce_fighters() -> void:
	var half: float = body_length * 0.5
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as Fighter
		if fighter == null or not is_instance_valid(fighter) or fighter.is_grabbed:
			continue
		if _cooldowns.has(fighter):
			continue
		# 몸 반지름(20)만큼 넉넉히 — 범퍼에 스치기만 해도 걸린다
		if absf(fighter.global_position.x - global_position.x) > half + 20.0:
			continue
		var feet: float = fighter.global_position.y + fighter_foot
		if feet < global_position.y - ROOF_HEIGHT - 4.0 or fighter.global_position.y > global_position.y + 10.0:
			continue
		fighter.velocity = Vector2(fighter.velocity.x + push_x * _dir, -bounce_velocity)
		fighter.cancel_landing_lag()
		fighter.start_air_trail(bounce_velocity / maxf(Fighter.gravity, 1.0))
		_cooldowns[fighter] = rebounce_delay

func _draw() -> void:
	var d: float = _dir
	var half: float = body_length * 0.5
	var wy: float = -wheel_radius
	# 아랫몸
	var body := PackedVector2Array([
		Vector2(-half, -12), Vector2(-half + 4, -34), Vector2(half - 4, -34), Vector2(half, -12),
	])
	draw_colored_polygon(body, body_color)
	draw_polyline(body + PackedVector2Array([body[0]]), outline_color, 3.0, true)
	# 지붕(앞유리가 진행 방향으로 기운다)
	var cab := PackedVector2Array([
		Vector2(-half * 0.62 * d, -34), Vector2(-half * 0.5 * d, -ROOF_HEIGHT),
		Vector2(half * 0.22 * d, -ROOF_HEIGHT), Vector2(half * 0.55 * d, -34),
	])
	draw_colored_polygon(cab, body_color)
	draw_polyline(cab + PackedVector2Array([cab[0]]), outline_color, 3.0, true)
	# 창문 두 칸
	var win_back := PackedVector2Array([
		Vector2(-half * 0.55 * d, -37), Vector2(-half * 0.46 * d, -ROOF_HEIGHT + 5),
		Vector2(-half * 0.06 * d, -ROOF_HEIGHT + 5), Vector2(-half * 0.06 * d, -37),
	])
	var win_front := PackedVector2Array([
		Vector2(half * 0.02 * d, -37), Vector2(half * 0.02 * d, -ROOF_HEIGHT + 5),
		Vector2(half * 0.2 * d, -ROOF_HEIGHT + 5), Vector2(half * 0.45 * d, -37),
	])
	draw_colored_polygon(win_back, window_color)
	draw_colored_polygon(win_front, window_color)
	# 체크무늬 띠
	var sq: float = 7.0
	var x: float = -half + 8.0
	var i: int = 0
	while x + sq <= half - 8.0:
		draw_rect(Rect2(x, -27, sq, sq * 0.5), outline_color if i % 2 == 0 else Color.WHITE)
		draw_rect(Rect2(x, -27 + sq * 0.5, sq, sq * 0.5), Color.WHITE if i % 2 == 0 else outline_color)
		x += sq
		i += 1
	# 지붕 표시등
	var sign_rect := Rect2(-half * 0.2 * d - 14.0, -ROOF_HEIGHT - 10.0, 28.0, 10.0)
	draw_rect(sign_rect, Color(1.0, 0.95, 0.75))
	draw_rect(sign_rect, outline_color, false, 2.0)
	# 전조등 / 후미등
	draw_circle(Vector2((half - 5) * d, -22), 4.0, Color(1.0, 1.0, 0.8))
	draw_rect(Rect2(-half * d - (0.0 if d > 0 else 5.0), -26, 5, 7), Color(0.9, 0.15, 0.1))
	# 바퀴(구르는 게 보이게 바큇살 한 줄)
	for wx in [-half * 0.62, half * 0.62]:
		var c := Vector2(wx, wy)
		draw_circle(c, wheel_radius, outline_color)
		draw_circle(c, wheel_radius * 0.5, Color(0.7, 0.7, 0.72))
		var spoke := Vector2(cos(_wheel_angle), sin(_wheel_angle)) * wheel_radius * 0.5
		draw_line(c - spoke, c + spoke, outline_color, 2.0)
