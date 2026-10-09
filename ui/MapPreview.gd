class_name MapPreview
extends Control

## 맵 씬을 실제로 실행하지 않고(트리에 넣지 않아 _ready()가 안 돎) 그 안의 Polygon2D와 Sprite2D만 훑어서
## 바닥·벽·장애물 모양과 색(그리고 스프라이트 그림)을 그대로 뽑아온 뒤, 이 칸 크기에 맞춰 축소한 미니 스케치로 그린다.
## 그래서 맵을 새로 그릴 필요 없이, 실제 맵의 색과 배치가 곧 선택 화면 미리보기가 된다.

## 그릴 조각들. {kind: "poly", points: PackedVector2Array, color: Color, deco: bool} 또는
## {kind: "tex", texture: Texture2D, src: Rect2, rect: Rect2, deco: bool}
## deco가 true면 이름이 "Deco"로 시작하는 배경 장식(벽·선로·열차 그림 등)이라, 크기 기준(bbox)에는 안 넣고
## 화면에 그리기만 한다 — 실제 스테이지보다 훨씬 커서 같이 재면 스테이지가 점처럼 작아지기 때문
## 실제 게임 화면을 찍어 둔 사진 폴더(`tools/MapThumbGen.tscn`이 만든다). 맵 선택·도감·맵 상세가 **이 사진을 먼저 쓰고**,
## 사진이 없는 맵만 아래 스케치로 그린다 — 스케치는 크기·뒤집기·조명을 몰라서 헬스장 등이 깨져 보였다(2026-10-09)
const SNAPSHOT_DIR := "res://ui/map_thumbs"

var _shapes: Array = []
var _bbox_min := Vector2.ZERO
var _bbox_max := Vector2.ZERO

func _ready() -> void:
	# 뒷배경 그림이 bbox보다 훨씬 커서 이 칸 밖으로 삐져나가므로, 칸 경계에서 잘려 보이게 한다
	clip_contents = true

## 맵 씬 경로 -> 그 맵의 사진 경로(`ui/map_thumbs/<맵 파일 이름>.png`)
static func snapshot_path(map_path: String) -> String:
	return "%s/%s.png" % [SNAPSHOT_DIR, map_path.get_file().get_basename()]

## 그 맵의 사진. 찍어 둔 게 없으면 null
static func snapshot_texture(map_path: String) -> Texture2D:
	var path: String = snapshot_path(map_path)
	return load(path) if ResourceLoader.exists(path) else null

## Camera2D/CombatHUD처럼 판정·연출용이라 스테이지 모양과 무관한 가지는 건너뛴다.
func set_map(map_path: String) -> void:
	var scene: PackedScene = load(map_path)
	var root: Node = scene.instantiate()
	_shapes.clear()
	_collect(root, Vector2.ZERO, false)
	root.free()

	if _shapes.is_empty():
		return
	var first: bool = true
	for entry in _shapes:
		if entry.deco:
			continue
		for p in _corners(entry):
			if first:
				_bbox_min = p
				_bbox_max = p
				first = false
			else:
				_bbox_min = _bbox_min.min(p)
				_bbox_max = _bbox_max.max(p)
	# 스테이지 조각(바닥·벽)이 하나도 없으면(이론상) bbox를 못 잡으므로 그냥 둔다
	if first:
		return
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

## is_deco는 부모가 "Deco"로 시작하는 노드였는지를 자손까지 물려준다(부모가 장식이면 자손도 전부 장식)
func _collect(node: Node, parent_offset: Vector2, is_deco: bool) -> void:
	if node is Camera2D or node is CanvasLayer:
		return
	if node.name.begins_with("Deco"):
		is_deco = true
	var offset := parent_offset
	if node is Node2D:
		offset += node.position
	if node is Polygon2D and node.polygon.size() > 0:
		var points := PackedVector2Array()
		for p in node.polygon:
			points.append(p + offset)
		_shapes.append({"kind": "poly", "points": points, "color": node.color, "deco": is_deco})
	elif node is Sprite2D and node.texture != null:
		var entry := _sprite_entry(node, offset)
		entry["deco"] = is_deco
		_shapes.append(entry)
	for child in node.get_children():
		_collect(child, offset, is_deco)

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

## 배경 장식을 먼저 깔고 그 위에 실제 스테이지(바닥·벽)를 그린다 — 순서가 바뀌면 스테이지가 배경에 덮인다
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
		if entry.deco:
			_draw_entry(entry, scale_factor, top_left)
	for entry in _shapes:
		if not entry.deco:
			_draw_entry(entry, scale_factor, top_left)

func _draw_entry(entry: Dictionary, scale_factor: float, top_left: Vector2) -> void:
	if entry.kind == "poly":
		var pts := PackedVector2Array()
		for p in entry.points:
			pts.append((p - _bbox_min) * scale_factor + top_left)
		draw_colored_polygon(pts, entry.color)
	else:
		var r: Rect2 = entry.rect
		var dest := Rect2((r.position - _bbox_min) * scale_factor + top_left, r.size * scale_factor)
		draw_texture_rect_region(entry.texture, dest, entry.src)
