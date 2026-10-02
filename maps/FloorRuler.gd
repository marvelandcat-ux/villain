@tool
extends Node2D

## 바닥 눈금자(훈련장) — 노드 자리(= 바닥 윗면)에서 아래로 `step`px마다 눈금을 긋는다.
## 0이 노드 x 자리이고, `label_every`번째 눈금마다 거리 숫자를 붙인다. 사거리·넉백 거리 잴 때 쓴다

@export var half_width: float = 980.0:
	set(v):
		half_width = v
		queue_redraw()
@export var step: float = 50.0:
	set(v):
		step = maxf(v, 1.0)
		queue_redraw()
## 몇 번째 눈금마다 길게 긋고 숫자를 붙일지(2면 100px마다)
@export var label_every: int = 2:
	set(v):
		label_every = maxi(v, 1)
		queue_redraw()
@export var color: Color = Color(1, 1, 1, 0.75)
@export var font_size: int = 10

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_line(Vector2(-half_width, 0), Vector2(half_width, 0), color, 1.0)
	var count: int = int(floorf(half_width / step))
	for i in range(-count, count + 1):
		var x: float = i * step
		var major: bool = i % label_every == 0
		draw_line(Vector2(x, 0), Vector2(x, 12.0 if major else 6.0), color, 2.0 if major else 1.0)
		if major:
			var text: String = str(int(absf(x)))
			var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, Vector2(x - w * 0.5, 12.0 + font_size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
