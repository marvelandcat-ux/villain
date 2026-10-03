extends Node2D

## 고양이 아주머니 머리 위에 잠깐 뜨는 "지금 고른 고양이" 표시 — 동그란 말풍선 안에 고양이 얼굴(임시 그림).
## 캐릭터 루트의 자식이라 따라다니고, 좌우 반전은 Visual만 하므로 뒤집히지 않는다

const CAT_FOLLOWER := preload("res://skills/CatFollower.gd")

## 말풍선 반지름(px)
@export var bubble_radius: float = 15.0
@export var bubble_color: Color = Color(1.0, 1.0, 1.0, 0.92)
@export var outline_color: Color = Color(0.15, 0.1, 0.08)
## 처음 튀어나오는 시간 / 사라지기 전 흐려지는 시간(초)
@export var pop_time: float = 0.12
@export var fade_time: float = 0.25

var _kind: int = 0
var _duration: float = 1.5
var _left: float = 0.0

## kind 고양이 얼굴을 duration초 동안 보여준다. 떠 있는 중에 또 부르면 바뀐 얼굴로 처음부터 다시
func show_kind(kind: int, duration: float) -> void:
	_kind = kind
	_duration = maxf(duration, 0.05)
	_left = _duration
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	var elapsed: float = _duration - _left
	var s: float = 1.0
	if elapsed < pop_time:
		var t: float = elapsed / maxf(pop_time, 0.01)
		s = 0.5 + 0.7 * t if t < 0.7 else 0.99 + (1.0 - t) * 0.7
	scale = Vector2(s, s)
	modulate.a = clampf(_left / maxf(fade_time, 0.01), 0.0, 1.0)
	if _left <= 0.0:
		visible = false

func _draw() -> void:
	# 말풍선 + 아래 꼬리
	var tail := PackedVector2Array([Vector2(-4.0, bubble_radius - 2.0), Vector2(4.0, bubble_radius - 2.0), Vector2(0.0, bubble_radius + 6.0)])
	draw_colored_polygon(tail, outline_color)
	draw_circle(Vector2.ZERO, bubble_radius + 1.5, outline_color)
	draw_circle(Vector2.ZERO, bubble_radius, bubble_color)
	var inner := PackedVector2Array([Vector2(-2.5, bubble_radius - 3.0), Vector2(2.5, bubble_radius - 3.0), Vector2(0.0, bubble_radius + 3.5)])
	draw_colored_polygon(inner, bubble_color)
	CAT_FOLLOWER.draw_face(self, _kind, Vector2(0.0, 2.5), bubble_radius * 0.5)
