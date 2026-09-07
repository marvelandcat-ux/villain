extends Node

## 놀이터 스프라이트 3종의 실제 그림 영역과 "앉는 면 / 바닥 닿는 곳"을 재는 임시 도구
const ALPHA := 0.25

func _ready() -> void:
	for path in ["res://sprite/맵/놀이터/기린시소.png", "res://sprite/맵/놀이터/파란시소.png", "res://sprite/맵/놀이터/화분.png"]:
		var img: Image = (load(path) as Texture2D).get_image()
		var b: Array = _bounds(img, 0, img.get_width())
		print("--- ", path.get_file(), "  전체 ", img.get_width(), "x", img.get_height(),
			"  그림영역 x ", b[0], "~", b[1], " / y ", b[2], "~", b[3])
	# 기린: 주황색 안장(앉는 면)의 맨 윗줄
	var g: Image = (load("res://sprite/맵/놀이터/기린시소.png") as Texture2D).get_image()
	print("기린 주황 안장 윗줄 y=", _first_row(g, func(c: Color) -> bool:
		return c.a > 0.5 and c.r > 0.82 and c.g > 0.25 and c.g < 0.62 and c.b < 0.3))
	# 파란시소: 등(파란 몸통) 위쪽 — 가운데 x 구간에서 파란색이 처음 나오는 줄
	var bl: Image = (load("res://sprite/맵/놀이터/파란시소.png") as Texture2D).get_image()
	print("파란시소 파란 몸통 윗줄(x 300~780) y=", _first_row_in(bl, 300, 780, func(c: Color) -> bool:
		return c.a > 0.5 and c.b > 0.55 and c.r < 0.45))
	get_tree().quit()

func _bounds(img: Image, x0: int, x1: int) -> Array:
	var min_x: int = img.get_width()
	var max_x: int = -1
	var min_y: int = img.get_height()
	var max_y: int = -1
	for y in range(img.get_height()):
		for x in range(x0, mini(x1, img.get_width())):
			if img.get_pixel(x, y).a > ALPHA:
				min_x = mini(min_x, x); max_x = maxi(max_x, x)
				min_y = mini(min_y, y); max_y = maxi(max_y, y)
	return [min_x, max_x, min_y, max_y]

func _first_row(img: Image, test: Callable) -> int:
	return _first_row_in(img, 0, img.get_width(), test)

func _first_row_in(img: Image, x0: int, x1: int, test: Callable) -> int:
	for y in range(img.get_height()):
		for x in range(x0, mini(x1, img.get_width())):
			if test.call(img.get_pixel(x, y)):
				return y
	return -1
