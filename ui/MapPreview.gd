class_name MapPreview
extends Control

## 맵 씬을 실제로 실행하지 않고(트리에 넣지 않아 _ready()가 안 돎) 그 안의 Polygon2D들만 훑어서
## 바닥·벽·장애물 모양과 색을 그대로 뽑아온 뒤, 이 칸 크기에 맞춰 축소한 미니 스케치로 그린다.
## 그래서 맵을 새로 그릴 필요 없이, 실제 맵의 색과 배치가 곧 선택 화면 미리보기가 된다.

var _polygons: Array = []  # [{points: PackedVector2Array(global), color: Color}, ...]
var _bbox_min := Vector2.ZERO
var _bbox_max := Vector2.ZERO

## Camera2D/CombatHUD처럼 판정·연출용이라 스테이지 모양과 무관한 가지는 건너뛴다
func set_map(map_path: String) -> void:
	var scene: PackedScene = load(map_path)
	var root: Node = scene.instantiate()
	_polygons.clear()
	_collect_polygons(root, Vector2.ZERO)
	root.free()

	if _polygons.is_empty():
		return
	_bbox_min = _polygons[0].points[0]
	_bbox_max = _polygons[0].points[0]
	for entry in _polygons:
		for p in entry.points:
			_bbox_min = _bbox_min.min(p)
			_bbox_max = _bbox_max.max(p)
	# 벽 없는 맵(링아웃형)은 바닥 폭 하나만 잡혀서 세로가 거의 없다 —
	# 위쪽에 여백을 더해줘서 "허공에 뜬 좁은 발판" 느낌이 나게 한다
	if _bbox_max.y - _bbox_min.y < 150.0:
		_bbox_min.y -= 220.0

	queue_redraw()

func _collect_polygons(node: Node, parent_offset: Vector2) -> void:
	if node is Camera2D or node is CanvasLayer:
		return
	var offset := parent_offset
	if node is Node2D:
		offset += node.position
	if node is Polygon2D and node.polygon.size() > 0:
		var points := PackedVector2Array()
		for p in node.polygon:
			points.append(p + offset)
		_polygons.append({"points": points, "color": node.color})
	for child in node.get_children():
		_collect_polygons(child, offset)

func _draw() -> void:
	if _polygons.is_empty():
		return
	var bbox_size: Vector2 = _bbox_max - _bbox_min
	if bbox_size.x <= 0.0 or bbox_size.y <= 0.0:
		return
	var margin := 6.0
	var avail: Vector2 = size - Vector2(margin, margin) * 2.0
	var scale_factor: float = min(avail.x / bbox_size.x, avail.y / bbox_size.y)
	var top_left: Vector2 = (size - bbox_size * scale_factor) / 2.0
	for entry in _polygons:
		var pts := PackedVector2Array()
		for p in entry.points:
			pts.append((p - _bbox_min) * scale_factor + top_left)
		draw_colored_polygon(pts, entry.color)
