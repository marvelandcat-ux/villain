class_name MapPreview
extends Control

## 맵 씬을 실제로 실행하지 않고(트리에 넣지 않아 _ready()가 안 돎) 그 안의 Polygon2D와 Sprite2D만 훑어서
## 바닥·벽·장애물 모양과 색(그리고 스프라이트 그림)을 그대로 뽑아온 뒤, 이 칸 크기에 맞춰 축소한 미니 스케치로 그린다.
## 그래서 맵을 새로 그릴 필요 없이, 실제 맵의 색과 배치가 곧 선택 화면 미리보기가 된다.

## 그릴 조각들. {kind: "poly", points: PackedVector2Array, color: Color} 또는
## {kind: "tex", texture: Texture2D, src: Rect2, rect: Rect2}
var _shapes: Array = []
var _bbox_min := Vector2.ZERO
var _bbox_max := Vector2.ZERO

## Camera2D/CombatHUD처럼 판정·연출용이라 스테이지 모양과 무관한 가지는 건너뛴다.
## 이름이 "Deco"로 시작하는 노드도 통째로 건너뛴다 — 배경 벽·선로 그림처럼 화면 밖까지 크게 깔아둔
## 장식은 실제 스테이지(바닥·발판)보다 훨씬 커서, 같이 재면 미리보기 안에서 스테이지가 점처럼 작아진다
func set_map(map_path: String) -> void:
	var scene: PackedScene = load(map_path)
	var root: Node = scene.instantiate()
	_shapes.clear()
	_collect(root, Vector2.ZERO)
	root.free()

	if _shapes.is_empty():
		return
	var first: bool = true
	for entry in _shapes:
		for p in _corners(entry):
			if first:
				_bbox_min = p
				_bbox_max = p
				first = false
			else:
				_bbox_min = _bbox_min.min(p)
				_bbox_max = _bbox_max.max(p)
	# 벽 없는 맵(링아웃형)은 바닥 폭 하나만 잡혀서 세로가 거의 없다 —
	# 위쪽에 여백을 더해줘서 "허공에 뜬 좁은 발판" 느낌이 나게 한다
	if _bbox_max.y - _bbox_min.y < 150.0:
		_bbox_min.y -= 220.0

	queue_redraw()

## 바운딩 박스 계산용 — 조각이 차지하는 좌표들
func _corners(entry: Dictionary) -> Array:
	if entry.kind == "poly":
		return Array(entry.points)
	var r: Rect2 = entry.rect
	return [r.position, r.end]

func _collect(node: Node, parent_offset: Vector2) -> void:
	if node is Camera2D or node is CanvasLayer or node.name.begins_with("Deco"):
		return
	var offset := parent_offset
	if node is Node2D:
		offset += node.position
	if node is Polygon2D and node.polygon.size() > 0:
		var points := PackedVector2Array()
		for p in node.polygon:
			points.append(p + offset)
		_shapes.append({"kind": "poly", "points": points, "color": node.color})
	elif node is Sprite2D and node.texture != null:
		_shapes.append(_sprite_entry(node, offset))
	for child in node.get_children():
		_collect(child, offset)

## Sprite2D가 화면에서 차지하는 사각형을 맵 좌표로 계산한다.
## region_enabled면 그림 일부만 잘라 쓰므로 잘라낸 크기를 기준으로 잡고,
## centered면 position이 그림 한가운데라 반 크기만큼 왼쪽 위로 당긴다
func _sprite_entry(node: Sprite2D, offset: Vector2) -> Dictionary:
	var src: Rect2 = node.region_rect if node.region_enabled else Rect2(Vector2.ZERO, node.texture.get_size())
	var size: Vector2 = src.size * node.scale
	var top_left: Vector2 = offset + node.offset
	if node.centered:
		top_left -= size / 2.0
	return {"kind": "tex", "texture": node.texture, "src": src, "rect": Rect2(top_left, size)}

func _draw() -> void:
	if _shapes.is_empty():
		return
	var bbox_size: Vector2 = _bbox_max - _bbox_min
	if bbox_size.x <= 0.0 or bbox_size.y <= 0.0:
		return
	var margin := 6.0
	var avail: Vector2 = size - Vector2(margin, margin) * 2.0
	var scale_factor: float = min(avail.x / bbox_size.x, avail.y / bbox_size.y)
	var top_left: Vector2 = (size - bbox_size * scale_factor) / 2.0
	for entry in _shapes:
		if entry.kind == "poly":
			var pts := PackedVector2Array()
			for p in entry.points:
				pts.append((p - _bbox_min) * scale_factor + top_left)
			draw_colored_polygon(pts, entry.color)
		else:
			var r: Rect2 = entry.rect
			var dest := Rect2((r.position - _bbox_min) * scale_factor + top_left, r.size * scale_factor)
			draw_texture_rect_region(entry.texture, dest, entry.src)
