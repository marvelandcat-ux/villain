class_name GlassShard
extends Node2D

## 주정뱅이 술병이 깨질 때 바닥에 남는 초록 유리 파편 (순수 장식 — 판정 없음).
## Hitbox가 명중 지점에서 스폰하고 setup()으로 시작 위치를 넘기면, 아래로 떨어져 바닥에 그대로 쌓인다.
## 라운드가 바뀌면 씬이 리로드되면서 함께 사라진다.

## 떨어지는 데 걸리는 시간(초)
@export var fall_time: float = 0.35
## 떨어지면서 옆으로 튀는 최대 거리(px)
@export var scatter_x: float = 26.0
## 바닥에 쌓인 뒤 이 시간(초)이 지나면 서서히 투명해지며 사라진다
@export var lifetime: float = 10.0
## 사라질 때 투명해지는 데 걸리는 시간(초)
@export var fade_time: float = 1.5
## 바닥을 못 찾았을 때(공중) 대비 아래로 쏘는 레이캐스트 길이(px)
@export var ground_probe: float = 2000.0
## 파편 그림 후보 — 스폰할 때 이 중 하나를 무작위로 골라 쓴다 (비어 있으면 씬에 지정된 기본 그림을 그대로 둔다)
@export var textures: Array[Texture2D] = []

@onready var _piece: Sprite2D = get_node_or_null("Piece")

## 명중 지점에서 파편을 떨어뜨린다. Hitbox가 add_child 직후 호출한다
func setup(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	# 두 그림(유리조각/유리조각2) 중 하나를 무작위로 고르고, 조각 바닥이 땅선에 딱 닿게 맞춘다
	if _piece != null and not textures.is_empty():
		_piece.texture = textures.pick_random()
		_fit_piece_to_ground()
	# 매번 회전·크기·좌우 반전을 조금씩 다르게 줘서 자연스럽게 쌓이게 한다
	rotation = randf_range(-0.4, 0.4)
	var s: float = randf_range(0.8, 1.2)
	scale = Vector2(s * (-1.0 if randf() < 0.5 else 1.0), s)
	_fall(spawn_pos, s)

## 그림마다 위아래·좌우 투명 여백이 달라서, 실제 조각(불투명 픽셀)의 바닥이 노드 원점(=땅선)에 오도록
## offset을 계산한다. 이러면 어떤 그림이 뽑혀도 조각이 땅에 딱 앉고 절대 땅 밑으로 파묻히지 않는다
func _fit_piece_to_ground() -> void:
	var tex: Texture2D = _piece.texture
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	var used: Rect2i = img.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var w: float = float(tex.get_width())
	var h: float = float(tex.get_height())
	# centered=true 기준: 불투명 영역의 가로 중심을 원점에, 바닥을 원점에 맞춘다
	_piece.offset = Vector2(
		w * 0.5 - (float(used.position.x) + float(used.size.x) * 0.5),
		h * 0.5 - (float(used.position.y) + float(used.size.y))
	)

## 명중 높이에서 바닥까지 중력처럼 떨어진 뒤, 착지 순간 살짝 눌렸다 펴지고 그대로 멈춘다
func _fall(spawn_pos: Vector2, base_scale: float) -> void:
	var ground_y: float = _find_ground_y(spawn_pos)
	var land_x: float = spawn_pos.x + randf_range(-scatter_x, scatter_x)
	var target := Vector2(land_x, ground_y)
	var tween := create_tween()
	# 아래로 갈수록 빨라지게(EASE_IN) 떨어뜨린다
	tween.tween_property(self, "global_position", target, fall_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 떨어지는 동안 살짝 굴러가는 느낌으로 회전
	tween.parallel().tween_property(self, "rotation", rotation + randf_range(-1.0, 1.0), fall_time)
	# 착지 바운스 — 세로로 눌렸다 펴진다
	tween.tween_property(self, "scale:y", base_scale * 0.7, 0.06)
	tween.tween_property(self, "scale:y", base_scale, 0.08)
	# 바닥에 쌓인 뒤 lifetime이 지나면 서서히 투명해지며 사라진다 (self에 붙은 트윈이라 씬이 정리되면 같이 사라진다)
	tween.tween_interval(lifetime)
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)

## 스폰 지점에서 아래로 레이캐스트해 바닥 윗면 y를 찾는다. 캐릭터는 뚫고 지나가야 하므로 전부 제외한다
func _find_ground_y(from: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, ground_probe))
	query.collide_with_areas = false
	var excludes: Array[RID] = []
	for f in get_tree().get_nodes_in_group("fighters"):
		excludes.append(f.get_rid())
	query.exclude = excludes
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return from.y   # 바닥을 못 찾으면(공중 등) 그 자리에 둔다
	return hit.position.y
