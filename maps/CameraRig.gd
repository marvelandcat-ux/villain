class_name CameraRig
extends Camera2D

## 두 파이터의 중간 지점을 부드럽게 따라가는 카메라.
## 맵에 LeftWall/RightWall이 있으면 그 바깥면을 카메라 한계선으로 잡아, 벽 너머(배경 끝, 빈 공간)가
## 화면에 들어오지 않게 한다
@export var follow_speed: float = 4.0
@export var min_y: float = 100.0
@export var max_y: float = 250.0
## 벽 바깥이 안 보이도록 카메라 이동 범위를 제한할지. 벽이 없는 링아웃형 맵에서는 꺼도 된다
@export var clamp_to_walls: bool = true
## 한계선을 벽 바깥면에서 더 안쪽으로 당기고 싶을 때 쓰는 여유 폭(px)
@export var wall_margin: float = 0.0
## 1.0이면 벽 사이가 화면에 딱 맞아서(= 벽 밖이 절대 안 보이는 최소 배율) 카메라가 좌우로 전혀 안 움직인다.
## 1보다 키우면 그만큼 더 확대되는 대신 좌우로 따라다닐 여유가 생긴다 (1.1이면 벽 사이 폭의 약 9%)
@export_range(1.0, 2.0, 0.01) var extra_zoom: float = 1.0
## 흔들림이 초당 이만큼 잦아든다 (클수록 빨리 멈춘다)
@export var shake_decay: float = 3.0
## 흔들림이 최대(trauma 1.0)일 때 화면이 흔들리는 폭(px)
@export var shake_max_offset: float = 12.0

## 현재 흔들림 세기 0~1 — 타격이 들어오면 데미지에 비례해 쌓이고, 매 프레임 감쇠한다
var _trauma: float = 0.0

func _ready() -> void:
	# 타격 판정(Hitbox)이 찾아서 흔들 수 있도록 그룹에 등록한다
	add_to_group("game_camera")
	if not clamp_to_walls:
		return
	_apply_wall_limits()
	# 창 크기가 바뀌면 보이는 폭도 바뀌므로(stretch aspect가 expand라서) 그때마다 다시 계산한다
	get_viewport().size_changed.connect(_apply_wall_limits)

func _process(delta: float) -> void:
	var fighters := get_tree().get_nodes_in_group("fighters")
	if fighters.size() >= 2:
		var mid: Vector2 = (fighters[0].global_position + fighters[1].global_position) / 2.0
		mid.y = clampf(mid.y, min_y, max_y)
		global_position = global_position.lerp(mid, follow_speed * delta)
	_apply_shake(delta)

## 타격 세기(trauma)를 더한다 — Hitbox가 명중 시 데미지에 비례해서 호출한다
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

## 화면(offset)을 랜덤으로 흔들고 trauma를 서서히 줄인다. trauma가 0이면 offset을 원위치로 되돌린다
func _apply_shake(delta: float) -> void:
	if _trauma <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		return
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_max_offset * _trauma

## 좌우 벽의 바깥면을 찾아 카메라 한계선(limit_left/right)으로 설정한다.
## 벽 사이 폭이 화면 폭보다 좁으면 한계선만으로는 화면이 벽 밖을 물게 되므로,
## 벽 사이가 화면에 딱 맞을 만큼만 확대(zoom)해서 그 문제를 없앤다
func _apply_wall_limits() -> void:
	var left: float = _wall_edge("LeftWall", -1.0)
	var right: float = _wall_edge("RightWall", 1.0)
	if is_nan(left) or is_nan(right):
		return
	left += wall_margin
	right -= wall_margin
	var span: float = right - left
	if span <= 0.0:
		return
	var view_width: float = get_viewport_rect().size.x
	var needed_zoom: float = view_width / span * extra_zoom
	if needed_zoom > zoom.x:
		zoom = Vector2(needed_zoom, needed_zoom)
	limit_left = int(floorf(left))
	limit_right = int(ceilf(right))

## 벽 StaticBody2D의 바깥쪽 면 x좌표를 돌려준다.
## dir이 -1이면 왼쪽 벽의 왼쪽 면, 1이면 오른쪽 벽의 오른쪽 면. 벽이 없으면 NAN
func _wall_edge(node_name: String, dir: float) -> float:
	var parent := get_parent()
	if parent == null:
		return NAN
	var wall := parent.get_node_or_null(node_name) as Node2D
	if wall == null:
		return NAN
	var half_width: float = 0.0
	for child in wall.get_children():
		var collision := child as CollisionShape2D
		if collision == null:
			continue
		var rect := collision.shape as RectangleShape2D
		if rect == null:
			continue
		half_width = maxf(half_width, rect.size.x * 0.5 * absf(collision.global_scale.x))
	return wall.global_position.x + dir * half_width
