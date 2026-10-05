@tool
class_name GymBackdrop
extends Node2D

## **헬스장 창밖 풍경 한 벌** — 창밖 도시 한 장과, 그 앞을 가리는 창틀 여러 칸을 함께 놓는다.
##
## 자리·크기는 전부 `settings`(`maps/GymBackdrop.tres`)에서 읽는다. 눈으로 보고 맞추는 곳은
## `maps/GymBackdropStudio.tscn`이고, 거기서 S를 누르면 그 파일만 덮어쓴다.
##
## 창틀은 **한 칸짜리 그림을 가로로 반복**해서 만든다 — 통짜 그림을 쓰면 칸 수나 간격을
## 못 바꾸고, 맵 폭이 바뀔 때마다 다시 그려야 한다

## 자리와 크기를 적어 둔 곳
@export var settings: GymBackdropSettings:
	set(value):
		settings = value
		_rebuild()
## 창밖에 깔리는 도시 그림(가로로 반복된다)
@export var city_texture: Texture2D:
	set(value):
		city_texture = value
		_rebuild()
## 창 사이를 메우는 안쪽 벽 그림
@export var wall_texture: Texture2D:
	set(value):
		wall_texture = value
		_rebuild()
## 창틀 한 칸 그림
@export var frame_texture: Texture2D:
	set(value):
		frame_texture = value
		_rebuild()
## 도시를 얼마나 죽여서 깔지 — 그대로 두면 전경보다 밝아 눈이 창밖으로 간다
@export var city_tint: Color = Color(0.62, 0.66, 0.78, 1.0):
	set(value):
		city_tint = value
		_rebuild()

var _sky: Node2D = null
var _city: Sprite2D = null
## 창틀 칸들
var _frames: Array[Sprite2D] = []
## 창 사이를 메운 벽 조각들
var _walls: Array[Sprite2D] = []

func _ready() -> void:
	_rebuild()

## 설정대로 다시 깔아 놓는다. 값이 바뀔 때마다 통째로 다시 만든다 —
## 칸 수가 바뀌면 노드 수도 달라져서, 자리만 고쳐서는 안 맞는다
func _rebuild() -> void:
	if not is_inside_tree():
		return
	_clear()
	if settings == null:
		return
	_build_sky()
	_build_city()
	_build_walls()
	_build_frames()

func _clear() -> void:
	if _sky:
		_sky.queue_free()
		_sky = null
	if _city:
		_city.queue_free()
		_city = null
	for frame in _frames:
		if is_instance_valid(frame):
			frame.queue_free()
	_frames.clear()
	for wall in _walls:
		if is_instance_valid(wall):
			wall.queue_free()
	_walls.clear()

## 하늘 — 위아래 두 색을 섞은 네모에 별을 뿌린다.
## `Polygon2D`의 꼭짓점 색으로 섞으면 셰이더 없이도 그라데이션이 된다
func _build_sky() -> void:
	var rect: Rect2 = settings.sky_rect
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_sky = Node2D.new()
	_sky.name = "Sky"
	add_child(_sky)
	var poly := Polygon2D.new()
	poly.name = "SkyFill"
	poly.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y)])
	poly.vertex_colors = PackedColorArray([
		settings.sky_top, settings.sky_top, settings.sky_bottom, settings.sky_bottom])
	_sky.add_child(poly)
	if settings.star_count <= 0:
		return
	# 별자리는 판마다 바뀌면 산만하다 — 씨앗을 고정해 늘 같은 자리에 뜬다
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261006
	var stars := Polygon2D.new()
	stars.name = "Stars"
	var points := PackedVector2Array()
	for i in settings.star_count:
		var at := Vector2(
			rng.randf_range(rect.position.x, rect.position.x + rect.size.x),
			rng.randf_range(rect.position.y, rect.position.y + rect.size.y * 0.72))
		var r: float = settings.star_size
		points.append_array(PackedVector2Array([
			at + Vector2(-r, 0.0), at + Vector2(0.0, -r), at + Vector2(r, 0.0), at + Vector2(0.0, r)]))
	stars.polygon = points
	stars.polygons = []
	for i in settings.star_count:
		stars.polygons.append(PackedInt32Array([i * 4, i * 4 + 1, i * 4 + 2, i * 4 + 3]))
	stars.color = settings.star_color
	_sky.add_child(stars)

func _build_city() -> void:
	if city_texture == null:
		return
	_city = Sprite2D.new()
	_city.name = "City"
	_city.texture = city_texture
	# 그림보다 넓게 잘라 내면 모자란 만큼 좌우로 반복된다(좌우 끝이 이어지는 그림이어야 한다)
	_city.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_city.region_enabled = true
	var height: float = city_texture.get_size().y
	_city.region_rect = Rect2(0.0, 0.0, settings.city_width, height)
	_city.position = settings.city_center
	_city.scale = settings.city_scale
	_city.modulate = city_tint
	add_child(_city)

## 창 **사이와 위아래**를 벽으로 메운다 — 창 안쪽만 남겨야 거기로 바깥이 보인다.
## 통짜 한 장을 깔고 구멍을 뚫는 대신 조각을 놓는 이유는, 구멍을 뚫으려면 마스크나
## 셰이더가 필요한데 창 수·간격이 바뀔 때마다 그걸 다시 맞춰야 하기 때문이다
func _build_walls() -> void:
	if wall_texture == null or settings.window_count <= 0:
		return
	var rect: Rect2 = settings.wall_rect
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var over: float = settings.wall_overlap
	# 창 한 칸이 차지하는 자리
	var fw: float = 0.0
	var fh: float = 0.0
	if frame_texture != null:
		fw = frame_texture.get_size().x * absf(settings.window_scale.x)
		fh = frame_texture.get_size().y * absf(settings.window_scale.y)
	var top: float = settings.window_center.y - fh * 0.5 + over
	var bottom: float = settings.window_center.y + fh * 0.5 - over
	# 창 줄 위와 아래를 가로로 통째로 덮는다
	_wall_piece(Rect2(rect.position.x, rect.position.y, rect.size.x, top - rect.position.y), "WallTop")
	_wall_piece(Rect2(rect.position.x, bottom, rect.size.x, rect.end.y - bottom), "WallBottom")
	# 창과 창 사이, 그리고 양쪽 끝
	var count: int = settings.window_count
	var span: float = settings.window_spacing * float(count - 1)
	var start_x: float = settings.window_center.x - span * 0.5
	var left_edge: float = rect.position.x
	for i in count:
		var cx: float = start_x + settings.window_spacing * float(i)
		var gap_right: float = cx - fw * 0.5 + over
		if gap_right > left_edge:
			_wall_piece(Rect2(left_edge, top, gap_right - left_edge, bottom - top), "WallGap%d" % i)
		left_edge = cx + fw * 0.5 - over
	if rect.end.x > left_edge:
		_wall_piece(Rect2(left_edge, top, rect.end.x - left_edge, bottom - top), "WallGapEnd")

## 벽 조각 하나. 그림의 **테두리 안쪽**만 떼어 네모만큼 늘린다
func _wall_piece(area: Rect2, piece_name: String) -> void:
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	var piece := Sprite2D.new()
	piece.name = piece_name
	piece.texture = wall_texture
	piece.centered = false
	piece.region_enabled = true
	# **늘리지 않고 반복시킨다** — 조각마다 늘리면 벽 무늬가 조각 크기대로 찌그러진다
	piece.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var tile: float = maxf(settings.wall_tile_scale, 0.01)
	var inset: float = settings.wall_inset
	piece.region_rect = Rect2(inset, inset, area.size.x / tile, area.size.y / tile)
	piece.position = area.position
	piece.scale = Vector2(tile, tile)
	piece.modulate = settings.wall_tint
	add_child(piece)
	_walls.append(piece)

func _build_frames() -> void:
	if frame_texture == null or settings.window_count <= 0:
		return
	var count: int = settings.window_count
	# 줄 전체가 `window_center`를 가운데에 두도록 왼쪽 끝부터 센다
	var span: float = settings.window_spacing * float(count - 1)
	var start_x: float = settings.window_center.x - span * 0.5
	for i in count:
		var frame := Sprite2D.new()
		frame.name = "Frame%d" % i
		frame.texture = frame_texture
		frame.position = Vector2(start_x + settings.window_spacing * float(i), settings.window_center.y)
		frame.scale = settings.window_scale
		add_child(frame)
		_frames.append(frame)

## 조정 씬이 값을 바꾼 뒤 부른다
func refresh() -> void:
	_rebuild()
