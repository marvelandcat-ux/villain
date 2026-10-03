extends Node2D

## 황근출 궁 내무반 배경(`군대 집.webp`) 위에 올리는 창문 + 창밖 풍경(판정 없음).
## 배경 그림에 그려진 창문 두 개 자리에 `창문.webp`를 덮고, 유리 칸 안에만 `창문 배경.webp`(나무·구름)를 보여 준다.
## 창밖 풍경은 카메라보다 덜 움직여(parallax < 1) 멀리 있는 것처럼 유리 안에서 미묘하게 밀린다 —
## 유리 칸마다 Sprite2D 하나를 두고 `region_rect`를 옮겨서 칸 밖으로는 안 삐져나온다.
##
## **배경 Sprite2D(`_bg`)의 자식**으로 붙인다(`BarracksUltimate._build_arena()`). 그래서 좌표는 전부 배경 그림 픽셀(가운데 원점),
## 배율·나타나는 투명도는 배경을 그대로 따라간다

@export var window_texture: Texture2D = preload("res://sprite/황근출 해병/궁극기/창문.webp")
@export var view_texture: Texture2D = preload("res://sprite/황근출 해병/궁극기/창문 배경.webp")
## 배경 그림에 그려진 창문 바깥 테두리(배경 그림 픽셀) — 새 창문이 이 칸을 꼭 맞게 덮는다. 배경 그림을 바꾸면 다시 잴 것
@export var window_rects: Array[Rect2] = [Rect2(16, 158, 343, 163), Rect2(837, 158, 344, 164)]
## `창문.webp`에서 바깥 테두리 / 유리 칸들(창문 그림 픽셀) — 창문 그림을 바꾸면 다시 잴 것
@export var window_frame: Rect2 = Rect2(132, 144, 1511, 617)
@export var window_panes: Array[Rect2] = [Rect2(222, 232, 634, 452), Rect2(914, 232, 637, 452)]
## `창문 배경.webp`에서 실제로 칠해진 영역(창문 배경 그림 픽셀)
@export var view_content: Rect2 = Rect2(451, 219, 1260, 254)
## 풍경 폭 = 유리 전체 폭 x 이 값 — 1보다 커야 옆으로 밀릴 여유가 생긴다
@export var view_width_ratio: float = 1.6
## 풍경 아래끝을 유리 아래끝보다 이만큼(배경 그림 픽셀) 밑에 둔다 — 나무 밑동의 잘린 선이 안 보이게
@export var view_bottom_overlap: float = 6.0
## 창문마다 풍경을 옆으로 얼마나 다르게 보여줄지(창문 배경 그림 픽셀) — 두 창문이 똑같아 보이지 않게
@export var view_offsets: PackedFloat32Array = PackedFloat32Array([-120.0, 160.0])
## 카메라 따라 움직이는 비율 — 1보다 작을수록 멀리 있는 것처럼 덜 움직여 유리 안에서 더 밀린다
@export var parallax: float = 0.75

## 유리 칸마다 {sprite, rect(배경 그림 기준 칸), cx(유리 가운데 x), bottom(풍경 아래끝 y), scale, offset}
var _panes: Array = []

func _ready() -> void:
	var parent_tex: Texture2D = (get_parent() as Sprite2D).texture if get_parent() is Sprite2D else null
	var origin: Vector2 = parent_tex.get_size() * 0.5 if parent_tex else Vector2.ZERO
	for i in window_rects.size():
		_add_window(window_rects[i], origin, view_offsets[i] if i < view_offsets.size() else 0.0)
	_update_view()

func _add_window(rect: Rect2, origin: Vector2, offset: float) -> void:
	if window_texture == null or window_frame.size.x <= 0.0 or window_frame.size.y <= 0.0:
		return
	var k := Vector2(rect.size.x / window_frame.size.x, rect.size.y / window_frame.size.y)
	var win := Sprite2D.new()
	win.texture = window_texture
	win.region_enabled = true
	win.region_rect = window_frame
	win.scale = k
	win.position = rect.get_center() - origin
	add_child(win)
	if view_texture == null or window_panes.is_empty():
		return
	# 창문 그림 픽셀 → 배경 그림 픽셀
	var pane_rects: Array = []
	for p in window_panes:
		pane_rects.append(Rect2(rect.position + (p.position - window_frame.position) * k, p.size * k))
	var glass: Rect2 = pane_rects[0]
	for r in pane_rects:
		glass = glass.merge(r)
	var s: float = glass.size.x * view_width_ratio / view_content.size.x
	for r in pane_rects:
		var view := Sprite2D.new()
		view.texture = view_texture
		view.region_enabled = true
		view.scale = Vector2(s, s)
		view.position = (r as Rect2).get_center() - origin
		add_child(view)
		_panes.append({"sprite": view, "rect": r, "cx": glass.get_center().x, "bottom": glass.end.y + view_bottom_overlap,
			"scale": s, "offset": offset})

func _process(_delta: float) -> void:
	_update_view()

## 카메라가 내무반 가운데에서 벗어난 만큼 풍경을 (1 - parallax)배 같이 밀어, 유리 안에서 보이는 부분을 옮긴다
func _update_view() -> void:
	var shift: float = 0.0
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam:
		shift = to_local(cam.get_screen_center_position()).x * (1.0 - parallax)
	for p in _panes:
		var view: Sprite2D = p["sprite"]
		var r: Rect2 = p["rect"]
		var s: float = p["scale"]
		var x0: float = view_content.get_center().x + float(p["offset"]) + (r.position.x - float(p["cx"]) - shift) / s
		var y0: float = view_content.end.y + (r.position.y - float(p["bottom"])) / s
		view.region_rect = Rect2(x0, y0, r.size.x / s, r.size.y / s)
