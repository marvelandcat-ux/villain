extends Node2D

## 궁극기(흰 고양이) 동안 아주머니가 가슴 앞에 들고 있는 흰 고양이 — 할퀼 때마다 가까운 앞발을 앞(+x)으로 뻗고 발톱 자국 세 줄이 번쩍인다.
## 리그(Visual)의 자식이라 좌우 반전을 저절로 따라간다. 고양이 그림은 `CatSprite`(`show_behind_parent`), 발톱 자국은 이 노드가 위에 그린다.
## 원점 = 고양이 몸통 가운데

const CAT_SPRITE := preload("res://skills/CatSprite.gd")
const OUTLINE := Color(0.08, 0.06, 0.06)

## 발톱 자국이 그려지는 자리(이 노드 기준)
@export var slash_center: Vector2 = Vector2(40.0, -6.0)
@export var slash_color: Color = Color(1.0, 1.0, 1.0, 0.95)
## 한 번 할퀴는 모션 시간(초)
@export var swipe_time: float = 0.16

var _swipe: float = 0.0
## 번갈아 위/아래로 긋는다
var _flip: bool = false
var _sprite = null

func _ready() -> void:
	_sprite = CAT_SPRITE.new()
	_sprite.kind = 2
	_sprite.show_behind_parent = true
	add_child(_sprite)
	_sprite.position = -_sprite.body_center_scaled()

## 한 번 할퀸 순간
func swipe() -> void:
	_swipe = swipe_time
	_flip = not _flip
	queue_redraw()

func _process(delta: float) -> void:
	if _swipe <= 0.0:
		return
	_swipe = maxf(_swipe - delta, 0.0)
	if _sprite:
		_sprite.paw_reach = sin(_swipe / maxf(swipe_time, 0.01) * PI)
	queue_redraw()

func _draw() -> void:
	if _swipe <= 0.0:
		return
	var t: float = _swipe / maxf(swipe_time, 0.01)
	var c := Color(slash_color.r, slash_color.g, slash_color.b, slash_color.a * t)
	var dir: float = -1.0 if _flip else 1.0
	for i in 3:
		var off: float = (i - 1) * 6.0
		var a := slash_center + Vector2(-8.0 + off, -12.0 * dir)
		var b := slash_center + Vector2(4.0 + off, 12.0 * dir)
		draw_line(a, b, OUTLINE, 4.0, true)
		draw_line(a, b, c, 2.4, true)
