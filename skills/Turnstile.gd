class_name Turnstile
extends StaticBody2D

## 지하철 아저씨 스킬1이 만드는 개찰구 장애물 — 낮아서 점프로만 넘을 수 있고, 시간이 지나면 사라진다.
## 그림은 **마주 보는 개찰구 한 쌍**(`sprite/지하철빌/개찰구.png` 닫힘 / `개찰구2.png` 열림)을 반으로 잘라 쓴다(2026-09-30 사용자 결정):
## 스킬이 놓는 장애물 2개가 각각 왼쪽·오른쪽 개찰구가 되어 날개가 가운데서 맞물린다. 어느 쪽 반을 쓸지는 flap_dir이 정한다.
## 배율은 그림 속 두 개찰구 몸통 중심 간격(817px)이 스킬의 장애물 간격(`TurnstileSkill.spacing` 78px)이 되게 맞춘 값이다 —
## **spacing을 바꾸면 visual_scale도 같이 바꿔야** 날개가 맞물린다. 그림 몸통은 폭 약 28 x 높이 66인데 충돌 상자는
## 예전 크기 40x45 그대로다(사용자 결정 — 난이도 유지). 그림 바닥은 충돌 바닥에 맞춘다(위로 약 20px 삐져나옴).
## 사라질 때는 열린 그림(초록 화살표)으로 바뀌고 막힘이 풀린 뒤 스르륵 사라진다

@export var lifetime: float = 5.0
## 닫힌 / 열린 그림 (마주 보는 한 쌍이 한 장에)
@export var closed_texture: Texture2D
@export var open_texture: Texture2D
## 그림 배율 — 817px(한 쌍 몸통 중심 간격) x 이 값 = 78px(장애물 간격). 2026-09-30 사용자 요청으로 1.3배(0.0734 -> 0.0954)
@export var visual_scale: float = 0.0954
## 열린 뒤 사라지기까지(초)
@export var open_fade_time: float = 0.4

## 날개가 가리키는 쪽(+1 오른쪽 / -1 왼쪽). +1이면 그림의 왼쪽 개찰구(날개가 오른쪽으로 뻗음), -1이면 오른쪽 개찰구.
## **add_child 전에** 넣을 것(_ready에서 그림을 고른다)
var flap_dir: float = 1.0

## 그림의 가운데 선 — 왼쪽/오른쪽 개찰구를 가르는 x
const SPLIT_X: float = 768.0
## 몸통 바닥선 y(두 그림 공통)
const BOTTOM_Y: float = 886.0
## 몸통 가운데 x — [닫힘 왼쪽, 닫힘 오른쪽, 열림 왼쪽, 열림 오른쪽] (그림을 바꾸면 다시 잴 것 — 몸통만 있는 아래쪽 줄로 잰다)
const CABINET_X: Array[float] = [355.0, 1172.0, 355.0, 1177.0]

@onready var _visual: Sprite2D = $Visual
@onready var _collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_show(closed_texture, false)
	Timers.after(self, lifetime, _open)

## 반쪽 그림을 몸통 가운데·바닥이 충돌 상자 가운데·바닥에 오도록 놓는다
func _show(tex: Texture2D, opened: bool) -> void:
	if tex == null:
		return
	var right_half: bool = flap_dir < 0.0
	var x0: float = SPLIT_X if right_half else 0.0
	var cabinet_x: float = CABINET_X[(2 if opened else 0) + (1 if right_half else 0)]
	_visual.texture = tex
	_visual.centered = false
	_visual.region_enabled = true
	_visual.region_rect = Rect2(x0, 0.0, SPLIT_X, float(tex.get_height()))
	_visual.scale = Vector2(visual_scale, visual_scale)
	var half_h: float = (_collision.shape as RectangleShape2D).size.y * 0.5
	_visual.position = Vector2(-(cabinet_x - x0) * visual_scale, half_h - BOTTOM_Y * visual_scale)

func _open() -> void:
	_show(open_texture, true)
	_collision.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, open_fade_time)
	tween.tween_callback(queue_free)
