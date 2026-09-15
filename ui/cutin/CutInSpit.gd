@tool
class_name CutInSpit
extends Node2D

## 컷인용 침 — 스프라이트 없이 `_draw()`로 물방울을 그려 날린다(담배 연기 `CutInSmoke`와 같은 방식).
##
## 이 노드의 원점이 **뱉는 자리(입)** 다. `launch()`를 부르면 거기서 `direction` 쪽으로 튀어 나가
## `life`초 뒤에 사라진다. 진행 방향 뒤로 작아지는 물방울을 몇 개 깔아서 혜성처럼 늘어져 보이게 한다 —
## 하나만 그리면 너무 빨라서 점 하나가 깜빡인 것처럼 보인다.
##
## **@tool이라 에디터에서도 보인다** — 안 날아가는 동안에는 뱉는 자리에 물방울 하나와 날아갈 방향
## 화살표를 그려 준다. 그걸 보고 노드를 끌어다 입에 맞추고, `direction`으로 각도를 잡으면 된다.
## 게임에서는 이 미리보기가 안 나오고 실제로 날아갈 때만 그려진다.
##
## 나중에 침 그림을 받으면 `spit_texture`에 꽂기만 하면 된다. 그러면 도형 대신 그 그림을
## **진행 방향으로 돌려서** 그린다.

## 침 그림. 비워두면 도형(물방울)으로 그린다
@export var spit_texture: Texture2D:
	set(value):
		spit_texture = value
		queue_redraw()
## 그림을 쓸 때의 배율
@export var texture_scale: float = 1.0:
	set(value):
		texture_scale = value
		queue_redraw()
## 날아가는 방향. 기본값은 **왼쪽 아래** — 일진이 없는 쪽으로 내리 뱉는다
@export var direction: Vector2 = Vector2(-1.0, 0.5):
	set(value):
		direction = value
		queue_redraw()
## 처음 속도(px/초)
@export var speed: float = 700.0
## 아래로 처지는 가속도(px/초^2). **0이면 포물선 없이 일직선으로 날아간다**
@export var gravity: float = 0.0
## 날아가다 사라지기까지(초)
@export var life: float = 0.55
## 물방울 반지름(px)
@export var radius: float = 8.0:
	set(value):
		radius = value
		queue_redraw()
## 침 색
@export var color: Color = Color(0.92, 0.96, 0.99, 0.95):
	set(value):
		color = value
		queue_redraw()
## 뒤로 깔리는 물방울 수와 간격(px). 0이면 하나만 그린다
@export var trail_count: int = 4:
	set(value):
		trail_count = value
		queue_redraw()
@export var trail_spacing: float = 13.0:
	set(value):
		trail_spacing = value
		queue_redraw()

@export_group("에디터 미리보기")
## 에디터에서 방향 화살표를 그릴 길이(px). 게임에는 안 나온다
@export var preview_arrow: float = 90.0:
	set(value):
		preview_arrow = value
		queue_redraw()

var _flying: bool = false
var _age: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _offset: Vector2 = Vector2.ZERO

## 침을 뱉는다 (컷인이 부른다)
func launch() -> void:
	_flying = true
	_age = 0.0
	_offset = Vector2.ZERO
	_velocity = direction.normalized() * speed
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _flying:
		return
	_age += delta
	_velocity.y += gravity * delta
	_offset += _velocity * delta
	if _age >= life:
		_flying = false
	queue_redraw()

func _draw() -> void:
	if not _flying:
		if Engine.is_editor_hint():
			_draw_preview()
		return
	# 끝으로 갈수록 빠르게 옅어진다 — 툭 사라지는 것보다 스르륵 없어지는 게 자연스럽다
	var fade: float = clampf(1.0 - pow(_age / maxf(life, 0.01), 2.0), 0.0, 1.0)
	_draw_spit(_offset, _velocity.normalized(), fade)

## 침 한 뭉치 — 진행 방향(forward) 뒤로 작아지는 물방울을 깐다
func _draw_spit(at: Vector2, forward: Vector2, fade: float) -> void:
	if spit_texture:
		draw_set_transform(at, forward.angle(), Vector2.ONE * texture_scale)
		draw_texture(spit_texture, -spit_texture.get_size() * 0.5, Color(1.0, 1.0, 1.0, fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var count: int = maxi(trail_count, 0) + 1
	for i in range(count):
		var shrink: float = 1.0 - float(i) / float(count)
		draw_circle(at - forward * trail_spacing * float(i), radius * shrink,
			Color(color.r, color.g, color.b, color.a * fade * shrink))

## 에디터 전용 — 뱉는 자리에 침 한 뭉치와 날아갈 방향 화살표를 그린다.
## 이걸 보고 노드를 입에 맞추고 각도를 잡으면 된다
func _draw_preview() -> void:
	var forward: Vector2 = direction.normalized()
	_draw_spit(Vector2.ZERO, forward, 1.0)
	if preview_arrow <= 0.0:
		return
	var tip: Vector2 = forward * preview_arrow
	var guide := Color(1.0, 0.35, 0.35, 0.85)
	draw_line(Vector2.ZERO, tip, guide, 2.0)
	# 화살촉 — 끝에서 뒤로 15도씩 벌린 짧은 선 두 개
	for sign in [-1.0, 1.0]:
		draw_line(tip, tip - forward.rotated(deg_to_rad(18.0 * sign)) * 16.0, guide, 2.0)
