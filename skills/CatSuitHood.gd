extends Node2D

## 궁극기(주황 고양이) 동안 뒤집어쓴 주황 고양이 옷의 머리 부분 — 얼굴 둘레를 감싸는 고리 + 꼭대기의 왕눈 두 개.
## 리그 `Head`의 자식으로 붙이고 scale을 머리 배율의 역수로 맞춰서 px 단위로 그린다(머리를 따라 움직인다).
## 몸은 캐릭터 색조(`set_tint`)로 주황빛만 낸다. 그림은 임시로 `_draw()`

@export var suit_color: Color = Color(0.98, 0.72, 0.15)
@export var outline_color: Color = Color(0.35, 0.22, 0.05)
## 얼굴 둘레 고리 반지름·두께(px)
@export var ring_radius: float = 25.0
@export var ring_width: float = 9.0

func _draw() -> void:
	# 뒤통수까지 감싸는 고리(가운데는 얼굴이 보이게 비운다)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40, outline_color, ring_width + 2.5, true)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40, suit_color, ring_width, true)
	# 이마 위 코
	draw_circle(Vector2(0.0, -ring_radius + 1.0), 3.5, Color(0.12, 0.08, 0.05))
	# 꼭대기 왕눈
	for side in [-1.0, 1.0]:
		var c := Vector2(side * 14.0, -ring_radius - 2.0)
		draw_circle(c, 8.0, outline_color)
		draw_circle(c, 6.8, Color(1, 1, 1))
		draw_circle(c + Vector2(side * 1.5, 1.0), 2.4, Color(0.05, 0.05, 0.05))
