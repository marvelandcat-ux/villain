extends Node2D

## 훈련장 전용 — 씬 안의 충돌 영역을 전부 색깔별로 그려서 보여준다.
## 부모(훈련장 루트) 아래를 매 프레임 훑어서 CollisionShape2D / CollisionPolygon2D를 찾는다 —
## 맵에 따로 붙는 투사체·토 기둥·부채꼴도 같이 잡힌다. CanvasLayer(HUD·컷인) 밑은 화면 좌표라 건너뛴다.
##
## 히트박스는 켜진 순간이 짧아서(기본공격 0.15초) 꺼진 뒤에도 `hitbox_linger`초 동안 잔상으로 남긴다.

const COLOR_HITBOX := Color(1.0, 0.2, 0.2)
const COLOR_HURTBOX := Color(0.2, 1.0, 0.35)
const COLOR_BODY := Color(0.3, 0.6, 1.0)
const COLOR_SOLID := Color(0.85, 0.85, 0.85)
const COLOR_ONE_WAY := Color(1.0, 0.8, 0.2)
const COLOR_AREA := Color(0.8, 0.4, 1.0)
const FILL_ALPHA: float = 0.22
const LINE_WIDTH: float = 2.0
const CIRCLE_SEGMENTS: int = 24
const HALF_SEGMENTS: int = 12
## WorldBoundaryShape2D(끝없는 직선)를 그릴 때 양쪽으로 뻗는 길이
const BOUNDARY_HALF_LENGTH: float = 5000.0

## 히트박스가 꺼진 뒤 잔상이 남아 있는 시간(초)
@export var hitbox_linger: float = 0.5

## 켜고 끄기 — 끄면 그리기도 훑기도 멈춘다
var enabled: bool = false:
	set(value):
		enabled = value
		visible = value
		_shapes.clear()
		_ghosts.clear()
		queue_redraw()

## 이번 프레임에 그릴 영역: { outlines, color }
var _shapes: Array = []
## 히트박스 잔상: 충돌 노드 instance_id -> { outlines, color, time }
var _ghosts: Dictionary = {}
## 이번 프레임에 켜져 있던 히트박스 (잔상 대신 실제 모양으로 그린다)
var _live_ids: Dictionary = {}
var _now: float = 0.0

func _ready() -> void:
	# 부모 트랜스폼과 상관없이 월드 좌표 그대로 그리고, 모든 그림 위에 얹는다
	top_level = true
	global_transform = Transform2D.IDENTITY
	z_as_relative = false
	z_index = 4000
	visible = enabled

func _process(_delta: float) -> void:
	if not enabled:
		return
	_now = Time.get_ticks_msec() / 1000.0
	_shapes.clear()
	_live_ids.clear()
	_collect(get_parent())
	for id in _ghosts.keys():
		if _now - _ghosts[id].time > hitbox_linger:
			_ghosts.erase(id)
	queue_redraw()

func _draw() -> void:
	for id in _ghosts:
		if _live_ids.has(id):
			continue
		var ghost: Dictionary = _ghosts[id]
		var strength: float = 1.0 - (_now - ghost.time) / hitbox_linger
		_draw_outlines(ghost.outlines, ghost.color, clampf(strength, 0.0, 1.0) * 0.7)
	for entry in _shapes:
		_draw_outlines(entry.outlines, entry.color, 1.0)

# ------------------------------------------------------------------
# 훑기
# ------------------------------------------------------------------
func _collect(node: Node) -> void:
	for child in node.get_children():
		if child == self or child is CanvasLayer:
			continue
		if child is CollisionShape2D:
			if not child.disabled and child.shape != null:
				_add(child, _shape_outlines(child.shape), child.one_way_collision)
		elif child is CollisionPolygon2D:
			if not child.disabled and child.polygon.size() >= 2:
				var closed: bool = child.build_mode == CollisionPolygon2D.BUILD_SOLIDS
				_add(child, [{"points": child.polygon, "closed": closed}], child.one_way_collision)
		_collect(child)

## 충돌 노드 하나를 주인 종류에 따라 색을 골라 목록에 넣는다
func _add(node: Node2D, local_outlines: Array, one_way: bool) -> void:
	var holder: Node = node.get_parent()
	var color: Color
	if holder is Hitbox:
		# 꺼져 있는 히트박스는 판정이 없으므로 안 그린다 (꺼진 직후는 잔상이 대신한다)
		if not holder.monitoring:
			return
		color = COLOR_HITBOX
	elif holder is Hurtbox:
		color = COLOR_HURTBOX
	elif holder is CharacterBody2D:
		color = COLOR_BODY
	elif holder is Area2D:
		color = COLOR_AREA
	elif one_way:
		color = COLOR_ONE_WAY
	else:
		color = COLOR_SOLID

	var xform: Transform2D = node.global_transform
	var world: Array = []
	for outline in local_outlines:
		world.append({"points": xform * (outline.points as PackedVector2Array), "closed": outline.closed})
	_shapes.append({"outlines": world, "color": color})

	if holder is Hitbox:
		var id: int = node.get_instance_id()
		_live_ids[id] = true
		_ghosts[id] = {"outlines": world, "color": color, "time": _now}

# ------------------------------------------------------------------
# 모양 -> 외곽선 (로컬 좌표)
# ------------------------------------------------------------------
func _shape_outlines(shape: Shape2D) -> Array:
	if shape is RectangleShape2D:
		var h: Vector2 = shape.size * 0.5
		return [_closed(PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)]))]
	if shape is CircleShape2D:
		return [_closed(_arc(Vector2.ZERO, shape.radius, 0.0, TAU, CIRCLE_SEGMENTS))]
	if shape is CapsuleShape2D:
		# height는 반원까지 포함한 전체 높이다
		var r: float = shape.radius
		var half: float = maxf(shape.height * 0.5 - r, 0.0)
		var points := _arc(Vector2(0, -half), r, PI, TAU, HALF_SEGMENTS)
		points.append_array(_arc(Vector2(0, half), r, 0.0, PI, HALF_SEGMENTS))
		return [_closed(points)]
	if shape is ConvexPolygonShape2D:
		return [_closed(shape.points)]
	if shape is ConcavePolygonShape2D:
		var result: Array = []
		var segments: PackedVector2Array = shape.segments
		for i in range(0, segments.size() - 1, 2):
			result.append(_open(PackedVector2Array([segments[i], segments[i + 1]])))
		return result
	if shape is SegmentShape2D:
		return [_open(PackedVector2Array([shape.a, shape.b]))]
	if shape is SeparationRayShape2D:
		return [_open(PackedVector2Array([Vector2.ZERO, Vector2(0, shape.length)]))]
	if shape is WorldBoundaryShape2D:
		var base: Vector2 = shape.normal * shape.distance
		var tangent: Vector2 = shape.normal.orthogonal() * BOUNDARY_HALF_LENGTH
		return [_open(PackedVector2Array([base - tangent, base + tangent]))]
	return []

func _arc(center: Vector2, radius: float, from_angle: float, to_angle: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var angle: float = lerpf(from_angle, to_angle, float(i) / steps)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _closed(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "closed": true}

func _open(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "closed": false}

# ------------------------------------------------------------------
# 그리기
# ------------------------------------------------------------------
func _draw_outlines(outlines: Array, color: Color, strength: float) -> void:
	for outline in outlines:
		var points: PackedVector2Array = outline.points
		if points.size() < 2:
			continue
		var line_color := Color(color, strength)
		if outline.closed and points.size() >= 3:
			# 오목한 폴리곤이 삼각형으로 안 쪼개지면 채우기만 건너뛴다 (에러 방지)
			if not Geometry2D.triangulate_polygon(points).is_empty():
				draw_colored_polygon(points, Color(color, FILL_ALPHA * strength))
			var loop := points.duplicate()
			loop.append(points[0])
			draw_polyline(loop, line_color, LINE_WIDTH)
		else:
			draw_polyline(points, line_color, LINE_WIDTH)
