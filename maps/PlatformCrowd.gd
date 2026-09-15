@tool
class_name PlatformCrowd
extends Node2D

## 건너편 승강장에 서 있는 사람들의 실루엣 (순수 장식 — 충돌·판정 없음).
## 노드 하나가 사람 여러 명을 그린다. **노드를 놓은 자리가 "발이 닿는 선"** 이고 거기서 위로 그린다.
## 열차가 다가오면(경고등~통과) 다 같이 한 발 물러서고 몸이 뒤로 젖혀진다 — 역에 사람이 있다는 느낌과
## "열차가 온다"는 신호를 같이 준다.
##
## 그림 없이 `_draw()`로 그리므로, 사람 스프라이트를 받으면 `_draw_person()`만 바꾸면 된다.
## @tool이라 에디터에서도 보여서 위치를 눈으로 잡을 수 있다 — 흔들림은 게임에서만 돈다

## --- 사람 ---
## 몇 명 그릴지
@export var count: int = 6
## 맨 왼쪽과 맨 오른쪽 사이 폭(px)
@export var spread_x: float = 900.0
## 사람 키(px). **싸우는 캐릭터(약 90px)보다 작아야** 건너편에 있는 것으로 읽힌다
@export var person_height: float = 52.0
## 실루엣 색 — 맵 조명(CanvasModulate)이 곱해지므로 너무 어둡게 잡으면 벽에 묻힌다
@export var body_color: Color = Color(0.15, 0.17, 0.23, 0.95)
## 사람마다 키를 다르게 하는 폭 (0.15면 85~115%)
@export var height_variance: float = 0.15

## --- 가만히 서 있을 때 ---
## 숨쉬듯 오르내리는 폭(px)과 빠르기
@export var bob_px: float = 1.6
@export var bob_speed: float = 1.1
## 좌우로 까딱이는 각도(도)
@export var sway_deg: float = 1.6

## --- 열차가 올 때 ---
## 뒤로 물러나는 거리(px — 위로 올라가는 게 선로에서 멀어지는 것이다)
@export var alarm_step_back: float = 5.0
## 뒤로 젖히는 각도(도)
@export var alarm_lean_deg: float = 5.0
## 물러나고 되돌아오는 빠르기(1/초)
@export var alarm_speed: float = 3.0

var _time: float = 0.0
## 0=평소, 1=열차가 오는 중. 사이 값으로 부드럽게 오간다
var _alarm: float = 0.0
var _train: SubwayTrain = null

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()   # 에디터에서는 멈춰 있되 인스펙터 값은 바로 반영한다
		return
	_time += delta
	var danger: bool = false
	var train: SubwayTrain = _find_train()
	if train:
		danger = train.is_dangerous()
	_alarm = move_toward(_alarm, 1.0 if danger else 0.0, alarm_speed * delta)
	queue_redraw()

## "subway_train" 그룹의 열차를 찾아 기억해둔다 (열차가 없는 맵이면 그냥 서 있기만 한다)
func _find_train() -> SubwayTrain:
	if not is_instance_valid(_train):
		_train = get_tree().get_first_node_in_group("subway_train") as SubwayTrain
	return _train

func _draw() -> void:
	for i in count:
		_draw_person(i)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 사람 한 명. 발 자리를 축으로 기울이므로 발이 바닥에 붙은 채 몸만 움직인다
func _draw_person(i: int) -> void:
	var f: float = float(i)
	var slot: float = (f + 0.5) / float(maxi(count, 1))
	# 자리마다 조금씩 어긋나게 세운다 — 똑같은 간격이면 울타리처럼 보인다
	var x: float = -spread_x * 0.5 + spread_x * slot + 13.0 * sin(f * 12.9898)
	var h: float = person_height * (1.0 + height_variance * sin(f * 7.717 + 1.3))
	var phase: float = f * 2.399
	var bob: float = sin(_time * bob_speed + phase) * bob_px
	var lean: float = deg_to_rad(sin(_time * bob_speed * 0.6 + phase) * sway_deg - alarm_lean_deg * _alarm)
	draw_set_transform(Vector2(x, -bob - alarm_step_back * _alarm), lean, Vector2.ONE)

	var col: Color = body_color
	col.a *= 0.82 + 0.18 * absf(sin(f * 3.137))   # 앞뒤로 선 느낌이 나게 사람마다 조금씩 흐리게
	var leg_h: float = h * 0.30
	var hip: float = h * 0.12
	var shoulder: float = h * 0.16
	var top: float = -h * 0.78
	draw_rect(Rect2(-h * 0.09, -leg_h, h * 0.07, leg_h), col)
	draw_rect(Rect2(h * 0.02, -leg_h, h * 0.07, leg_h), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-hip, -leg_h), Vector2(hip, -leg_h),
		Vector2(shoulder, top), Vector2(-shoulder, top),
	]), col)
	draw_circle(Vector2(0.0, top - h * 0.11), h * 0.12, col)
