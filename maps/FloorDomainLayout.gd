@tool
extends Node2D

## **영역전개(윗집) 바닥·벽 맞추는 자리.** 층간소음 빌런 궁극기가 이 씬을 읽어
## 두 층의 바닥 높이와 좌우 벽 자리를 정한다.
##
## 쓰는 법: `FloorDomainLayout.tscn`을 열고 아래 조각들을 **배경 그림 위에서 끌어다 맞추면 된다**.
## 숫자를 외울 필요 없이 보이는 대로 놓으면 게임에서 그대로 쓴다.
##
## - `UpperFloor` — 위층 바닥 윗면(엄마 발이 닿는 선)
## - `SlabBottom` — 위층 바닥 아랫면 = 아래층 천장(상대 머리가 닿는 선)
## - `LowerFloor` — 아래층 바닥 윗면(상대 발이 닿는 선)
## - `Ceiling` — 위층 천장(엄마가 더 못 뜨는 선)
## - `LeftWall` / `RightWall` — 좌우 벽 안쪽 면
## - `MomSpawn` / `FoeSpawn` — 영역에 들어올 때 **엄마와 상대가 설 가로 자리**(세로는 각 층 바닥에 맞춘다)
##
## 배경은 `centered = false`로 (0,0)에 둔다 — 그래야 조각의 자리가 곧 **그림 픽셀**이 된다

## 가로선을 그릴 조각들(위에서부터)과 세로선을 그릴 조각들
const ROW_PARTS: Array[String] = ["Ceiling", "UpperFloor", "SlabBottom", "LowerFloor"]
const COL_PARTS: Array[String] = ["LeftWall", "RightWall", "MomSpawn", "FoeSpawn"]

## 선 색과 굵기 — 에디터에서만 보이고 게임에는 안 나간다
@export var row_color: Color = Color(1.0, 0.35, 0.3, 0.9)
@export var col_color: Color = Color(0.35, 0.7, 1.0, 0.9)
## 두 사람이 설 자리를 나타내는 선 색
@export var spawn_color: Color = Color(0.4, 1.0, 0.5, 0.9)
@export var line_width: float = 3.0
## 선 옆에 이름을 띄울지
@export var show_labels: bool = true
@export var label_size: int = 28

func _ready() -> void:
	set_notify_transform(true)
	_push_background_back()

## 배경을 한 칸 뒤로 보낸다 — 루트가 그리는 선은 자식보다 **먼저** 그려져서
## 그냥 두면 배경 그림에 덮여 안 보인다(2026-10-04)
func _push_background_back() -> void:
	var bg := get_node_or_null("Background") as CanvasItem
	if bg and bg.z_index != -1:
		bg.z_index = -1

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_push_background_back()
		queue_redraw()

func _draw() -> void:
	var size: Vector2 = _image_size()
	var font: Font = ThemeDB.fallback_font
	for part_name in ROW_PARTS:
		var part: Node2D = get_node_or_null(part_name) as Node2D
		if part == null:
			continue
		var y: float = part.position.y
		draw_line(Vector2(-60.0, y), Vector2(size.x + 60.0, y), row_color, line_width)
		if show_labels and font:
			draw_string(font, Vector2(8.0, y - 10.0), "%s  y=%d" % [part_name, int(roundf(y))],
				HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, row_color)
	for part_name in COL_PARTS:
		var part: Node2D = get_node_or_null(part_name) as Node2D
		if part == null:
			continue
		var x: float = part.position.x
		var c: Color = spawn_color if part_name.ends_with("Spawn") else col_color
		draw_line(Vector2(x, -60.0), Vector2(x, size.y + 60.0), c, line_width)
		if show_labels and font:
			draw_string(font, Vector2(x + 8.0, 40.0), "%s  x=%d" % [part_name, int(roundf(x))],
				HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, c)

## 배경 그림 크기 — 없으면 적당한 값으로 친다
func _image_size() -> Vector2:
	var bg := get_node_or_null("Background") as Sprite2D
	if bg and bg.texture:
		return bg.texture.get_size()
	return Vector2(1944, 809)
