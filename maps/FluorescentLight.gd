@tool
class_name FluorescentLight
extends Node2D

## 벽에 달린 형광등 — 평소엔 켜져 있다가 가끔 파바박 깜빡인다 (지하철 승강장 장식, 승패와 무관).
## 스프라이트를 받기 전까지 임시 도형으로 그린다: 몸통·불 꺼진 형광관은 이 노드가 보통 블렌드로,
## 빛(형광관 빛·후광·아래 벽으로 떨어지는 빛)은 자식 Light 레이어가 더하기 블렌드로 그 위에 얹는다.
## 깜빡임은 Light 레이어의 투명도만 바꾸므로, 꺼지면 회백색 관만 남아 "불 꺼진 형광등"으로 보인다.
## @tool이라 에디터에서도 빛까지 보인다 — 깜빡임만 게임에서 돈다

## --- 모양 ---
## 형광관 길이(px)
@export var length: float = 90.0

## --- 빛 ---
## 빛 색 — 맵의 CanvasModulate(0.55, 0.58, 0.7)가 더하기 빛에도 곱해지므로 파란 기를 미리 빼둔 값.
## 통과하고 나면 살짝 푸르스름한 형광등 흰빛이 된다
@export var glow_color: Color = Color(1.0, 1.0, 0.9)
## 형광관 둘레 후광 반지름(px)과 세기 — 넓고 옅은 겹 + 좁고 진한 겹 두 개를 겹쳐 가장자리를 부드럽게 한다
@export var halo_radius: float = 30.0
@export var halo_alpha: float = 0.4
## 아래 벽으로 떨어지는 빛의 길이(px) / 끝에서 양옆으로 벌어지는 폭(px) / 세기
@export var cone_length: float = 120.0
@export var cone_spread: float = 45.0
@export var cone_alpha: float = 0.24
## 켜져 있을 때도 아주 미세하게 떨리는 폭 (0이면 일정하다)
@export var hum_amount: float = 0.04

## --- 깜빡임 ---
## 다음 깜빡임까지 기다리는 시간(초) 범위. 짧게 주면 "고장 난 형광등"이 된다
@export var flicker_interval_min: float = 5.0
@export var flicker_interval_max: float = 14.0
## 한 번 깜빡일 때 몇 번 꺼졌다 켜지는지
@export var blinks_min: int = 2
@export var blinks_max: int = 5
## 꺼져 있는 시간 / 다시 켜져 있는 시간(초) 범위 — 짧아야 "파박" 하고 튄다
@export var blink_off_min: float = 0.03
@export var blink_off_max: float = 0.1
@export var blink_on_min: float = 0.03
@export var blink_on_max: float = 0.12
## 깜빡이다가 한동안 푹 꺼져 있을 확률과 그 시간(초)
@export var long_off_chance: float = 0.25
@export var long_off_min: float = 0.4
@export var long_off_max: float = 1.2
## 꺼졌을 때 남는 밝기 (0이면 완전히 꺼짐)
@export var off_level: float = 0.06

## 후광 양 끝 반원을 몇 조각으로 나눠 그릴지
const HALO_SEGMENTS: int = 8

## 빛만 담는 더하기 블렌드 레이어 (코드로 만들고 owner를 안 줘서 씬에 저장되지 않는다)
var _light: Node2D
## 진행 중인 깜빡임 순서 — x = 밝기, y = 그 밝기로 버틸 남은 시간(초). 비어 있으면 평소처럼 켜져 있다
var _steps: Array[Vector2] = []
## 다음 깜빡임까지 남은 시간
var _wait: float = 0.0
## 미세한 떨림의 위상 — 형광등마다 다르게 시작해서 같이 떨지 않게 한다
var _hum_phase: float = 0.0

func _ready() -> void:
	_light = Node2D.new()
	_light.name = "Light"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = mat
	_light.draw.connect(_draw_light)
	add_child(_light)
	_hum_phase = randf() * TAU
	# 형광등들이 한꺼번에 깜빡이지 않게 첫 대기 시간을 제각각 뽑는다
	_wait = randf_range(0.5, flicker_interval_max)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# 에디터에서는 깜빡이지 않고, 인스펙터에서 바꾼 값이 바로 보이게 매 프레임 다시 그린다
		_light.modulate.a = 1.0
		queue_redraw()
		_light.queue_redraw()
		return
	_hum_phase += delta * 13.0
	# 주기가 다른 두 sin을 곱해 규칙적인 깜빡임으로 안 보이게 한다 (SubwayTrain 창문 불빛과 같은 방식)
	var hum: float = 1.0 - hum_amount * (0.5 + 0.5 * sin(_hum_phase) * sin(_hum_phase * 0.41 + 0.7))
	_light.modulate.a = _advance(delta) * hum

## 깜빡임 순서를 한 프레임 진행하고 지금 밝기를 돌려준다
func _advance(delta: float) -> float:
	if _steps.is_empty():
		_wait -= delta
		if _wait > 0.0:
			return 1.0
		_build_flicker()
	var step: Vector2 = _steps[0]
	step.y -= delta
	if step.y > 0.0:
		_steps[0] = step
		return step.x
	_steps.pop_front()
	if _steps.is_empty():
		_wait = randf_range(flicker_interval_min, flicker_interval_max)
		return 1.0
	return _steps[0].x

## 이번 깜빡임의 "꺼짐 -> 켜짐" 순서를 새로 뽑는다. 매번 횟수·길이가 달라서 패턴이 눈에 익지 않는다
func _build_flicker() -> void:
	_steps.clear()
	var blinks: int = randi_range(blinks_min, maxi(blinks_min, blinks_max))
	# 몇 번째 꺼짐에서 한동안 푹 꺼져 있을지 (-1이면 이번엔 안 그런다)
	var long_at: int = randi_range(0, blinks - 1) if randf() < long_off_chance else -1
	for i in blinks:
		var off_time: float = randf_range(long_off_min, long_off_max) if i == long_at else randf_range(blink_off_min, blink_off_max)
		_steps.append(Vector2(off_level, off_time))
		# 다시 켜질 때 가끔 절반만 들어온다 — 수명 다 된 형광관이 힘겹게 켜지는 느낌
		var on_level: float = 0.5 if randf() < 0.3 else 1.0
		_steps.append(Vector2(on_level, randf_range(blink_on_min, blink_on_max)))

## 임시 도형: 어두운 몸통 + 양끝 소켓 + 불 꺼진 회백색 형광관. 불빛은 Light 레이어가 이 위에 더한다
func _draw() -> void:
	var half: float = length * 0.5
	draw_rect(Rect2(-half - 7.0, -7.0, length + 14.0, 14.0), Color(0.16, 0.17, 0.2))
	draw_rect(Rect2(-half - 4.0, -4.0, 4.0, 8.0), Color(0.42, 0.43, 0.46))
	draw_rect(Rect2(half, -4.0, 4.0, 8.0), Color(0.42, 0.43, 0.46))
	draw_rect(Rect2(-half, -3.0, length, 6.0), Color(0.72, 0.74, 0.74))

## Light 레이어에 빛을 그린다 (_light의 draw 신호로 불린다)
func _draw_light() -> void:
	var half: float = length * 0.5
	# 아래 벽으로 떨어지는 빛 — 폭이 다른 세 겹을 옅게 겹쳐 양옆 경계선이 판때기처럼 서지 않게 한다
	for ratio in [1.0, 0.6, 0.25]:
		var spread: float = cone_spread * ratio
		_draw_fade_quad(
			Vector2(-half, 3.0), Vector2(half, 3.0),
			Vector2(half + spread, 3.0 + cone_length), Vector2(-half - spread, 3.0 + cone_length),
			cone_alpha / 3.0)
	# 형광관 둘레 후광 — 넓고 옅은 겹 + 좁고 진한 겹
	_draw_capsule_glow(half, halo_radius, halo_alpha * 0.5)
	_draw_capsule_glow(half, halo_radius * 0.4, halo_alpha)
	# 형광관 자체 — 몸통에 그려둔 회백색 관 위에 더해져 하얗게 빛난다
	_light.draw_rect(Rect2(-half, -3.0, length, 6.0), glow_color)

## 앞 두 점(a, b)은 밝고 뒤 두 점(c, d)은 투명한 사각형 — 멀어질수록 자연스럽게 사라진다
func _draw_fade_quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, alpha: float) -> void:
	var near := Color(glow_color, alpha)
	var far := Color(glow_color, 0.0)
	_light.draw_polygon(PackedVector2Array([a, b, c, d]), PackedColorArray([near, near, far, far]))

## 형광관 중심선에서 radius만큼 퍼지는 캡슐 모양 후광. 중심선이 가장 밝고 바깥이 0이다
func _draw_capsule_glow(half: float, radius: float, alpha: float) -> void:
	var mid := Color(glow_color, alpha)
	var edge := Color(glow_color, 0.0)
	# 위아래 띠
	for s in [-1.0, 1.0]:
		_light.draw_polygon(
			PackedVector2Array([Vector2(-half, 0.0), Vector2(half, 0.0), Vector2(half, radius * s), Vector2(-half, radius * s)]),
			PackedColorArray([mid, mid, edge, edge]))
	# 양 끝 반원 — 관 끝점을 중심으로 부채꼴 조각을 이어 붙인다
	for side in [-1.0, 1.0]:
		var center := Vector2(half * side, 0.0)
		for i in HALO_SEGMENTS:
			var a0: float = -PI * 0.5 + PI * i / HALO_SEGMENTS
			var a1: float = -PI * 0.5 + PI * (i + 1) / HALO_SEGMENTS
			var p0: Vector2 = center + Vector2(cos(a0) * side, sin(a0)) * radius
			var p1: Vector2 = center + Vector2(cos(a1) * side, sin(a1)) * radius
			_light.draw_polygon(PackedVector2Array([center, p0, p1]), PackedColorArray([mid, edge, edge]))
