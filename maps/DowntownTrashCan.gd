extends Node2D

## 번화가 쓰레기통 하나(2026-10-08). 뚜껑(`Lid`)이 얹혀 있고, `DowntownTrashSpawner`가 고르면
## 뚜껑이 **위로 튕겨 열렸다가 다시 내려와 덮이고**, 그 사이 쓰레기가 통 위로 튀어나와 흩어진다.
## 쓰레기 조각은 `TrashPickup.gd` — 이 통의 부모(`TrashCans`)에 붙어 맵에 계속 남는다.
##
## **몸(판정, 2026-10-08 사용자 요청)**: `_ready()`에서 원웨이 발판 `StaticBody2D`를 하나 만들어 **뚜껑 위에 설 수 있다**
## (옆에서는 통과). 쓰레기가 터지는 순간 뚜껑 위에 서 있던 캐릭터는 **스프링처럼 위로 튕겨 나간다**(피해 없음,
## `cancel_landing_lag` — 착지 즉시 튕기는 기믹 규칙). 판정 크기는 `쓰래기 통 쓰래기 없는 버전.png` 실측
## (불투명 몸통 x ±38 / y -5~+70, 뚜껑 판판한 윗면 약 -14 — **그림을 바꾸면 다시 잴 것**). 원점은 그림 가운데라 밑면이 +70.
## 2026-10-10: 윗면이 -40이라 뚜껑보다 26px 위 허공에 서 있었다(사용자 지적) → 뚜껑 그림 실측 -14로 내림

const PICKUP_SCRIPT := preload("res://maps/TrashPickup.gd")

## 튀어나올 쓰레기 그림들(하나씩 랜덤)
@export var trash_textures: Array[Texture2D] = []
## 쓰레기 그림 배율 — `trash_px`가 0일 때만 쓰는 예비값(그림이 1254px 캔버스라 0.03이면 화면에서 약 20~30px)
@export var trash_scale: float = 0.03
## 쓰레기 한 조각이 화면에서 차지할 크기(px, 보이는 영역의 긴 변). 그림마다 캔버스가 달라도(1254 / 1024x1536 / 1774x887)
## 같은 크기로 나온다. 2026-10-08 사용자 요청으로 예전(약 25px)의 **2배**
@export var trash_px: float = 29.0
## 쓰레기가 나오는 자리(이 노드 기준) — 통 입구
@export var spawn_offset: Vector2 = Vector2(0, -12)
## 튀어나오는 가로 속도 범위(px/s, 방향은 랜덤)
@export var launch_x_range: Vector2 = Vector2(60, 240)
## 튀어나오는 위쪽 속도 범위(px/s)
@export var launch_up_range: Vector2 = Vector2(380, 560)
## 한 개씩 나오는 간격(초) — 한꺼번에 나오면 덩어리로 보인다
@export var spawn_gap: float = 0.06

@export_group("뚜껑")
## 뚜껑이 튀어 오르는 높이(px)
@export var lid_pop_height: float = 56.0
## 올라가는 시간 / 내려와 덮이는 시간(초)
@export var lid_rise_time: float = 0.16
@export var lid_fall_time: float = 0.22
## 올라가며 기우는 각도(도, 방향은 랜덤)
@export var lid_tilt_deg: float = 28.0
@export_group("")

@export_group("몸(판정)")
## 원웨이 발판을 만들지 — 끄면 예전처럼 그림만
@export var solid: bool = true
## 판정 상자 크기·가운데(통 그림 `Can` 자리 기준 — 그림을 노드에서 비켜 놓아도 따라간다). 윗면 = center.y - size.y/2 = 뚜껑 윗면
@export var collider_size: Vector2 = Vector2(76, 84)
@export var collider_center: Vector2 = Vector2(0, 28)
## 쓰레기가 터질 때 뚜껑 위 사람을 띄우는 속도(px/s). 중력 1150 기준 620이면 약 165px 뜬다
@export var eject_velocity: float = 620.0
## 위에 서 있는지 볼 때 가로 여유(px) — 몸 반지름만큼
@export var eject_margin: float = 22.0
## 캐릭터 원점 ~ 발끝(몸 캡슐 높이 60의 절반)
@export var fighter_foot: float = 30.0
@export_group("")

@onready var _lid: Node2D = get_node_or_null("Lid")
var _lid_rest_pos: Vector2
var _lid_rest_rot: float
var _lid_tween: Tween
var _body: StaticBody2D = null

func _ready() -> void:
	if _lid:
		_lid_rest_pos = _lid.position
		_lid_rest_rot = _lid.rotation
	if solid:
		_build_body()

## 뚜껑 위에 설 수 있는 원웨이 발판. 캐릭터 레이어 그대로(맵 바닥과 같은 StaticBody2D)
func _build_body() -> void:
	_body = StaticBody2D.new()
	_body.name = "Body"
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = collider_size
	cs.shape = rect
	cs.position = _collider_origin()
	cs.one_way_collision = true
	# 뚜껑이 튀어 오를 때 발이 판정 안으로 파묻혀도 빠지지 않게 넉넉히
	cs.one_way_collision_margin = 8.0
	_body.add_child(cs)
	add_child(_body)

## 판정 상자 가운데(이 노드 기준) — 통 그림(`Can`)이 비켜 있으면 그만큼 같이 옮긴다(Can3은 (4, -4) 비켜 있다)
func _collider_origin() -> Vector2:
	var can: Node2D = get_node_or_null("Can")
	return collider_center + (can.position if can else Vector2.ZERO)

## 뚜껑 윗면 월드 y
func top_y() -> float:
	return to_global(_collider_origin() - Vector2(0.0, collider_size.y * 0.5)).y

## 뚜껑을 튕기고 쓰레기를 count개 뱉는다. 뚜껑 위에 서 있던 사람은 같이 튕겨 나간다
func burst(count: int) -> void:
	_eject_riders()
	_pop_lid()
	for i in count:
		if i == 0:
			_spawn_one()
		else:
			Timers.after(self, spawn_gap * i, _spawn_one)

## 뚜껑 위(판정 윗면 근처, 가로 범위 안)에 발을 딛고 있는 캐릭터를 위로 띄운다
func _eject_riders() -> void:
	if not solid:
		return
	var half_w: float = collider_size.x * 0.5 + eject_margin
	var top: float = top_y()
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as Fighter
		if fighter == null or not is_instance_valid(fighter) or fighter.is_grabbed:
			continue
		if absf(fighter.global_position.x - global_position.x) > half_w:
			continue
		var feet: float = fighter.global_position.y + fighter_foot
		if absf(feet - top) > 14.0:
			continue
		# 넉백처럼 더하지 않고 덮어쓴다 — 서 있던 속도(0)에서 바로 솟구친다
		fighter.velocity.y = -eject_velocity
		fighter.cancel_landing_lag()

## 아무 자리(`world_pos`)에서 쓰레기 count개를 사방으로 뿌린다 — 쓰레기 모으기 모드에서 죽은 사람이 떨어뜨릴 때(Stage)
func drop_from(world_pos: Vector2, count: int) -> void:
	if trash_textures.is_empty():
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	for i in count:
		var piece = PICKUP_SCRIPT.new()
		var vel := Vector2(randf_range(-260.0, 260.0), -randf_range(launch_up_range.x, launch_up_range.y))
		var tex: Texture2D = trash_textures.pick_random()
		piece.setup(tex, _scale_for(tex), vel)
		parent.add_child(piece)
		piece.global_position = world_pos

func _spawn_one() -> void:
	if trash_textures.is_empty():
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	var piece = PICKUP_SCRIPT.new()
	var dir: float = -1.0 if randf() < 0.5 else 1.0
	var vel := Vector2(dir * randf_range(launch_x_range.x, launch_x_range.y),
		-randf_range(launch_up_range.x, launch_up_range.y))
	var tex: Texture2D = trash_textures.pick_random()
	piece.setup(tex, _scale_for(tex), vel)
	parent.add_child(piece)
	piece.global_position = to_global(spawn_offset)

## 그림의 보이는 영역(TrashPickup이 재서 캐시해 둔 것)을 `trash_px`에 맞추는 배율
func _scale_for(tex: Texture2D) -> float:
	if trash_px <= 0.0 or tex == null:
		return trash_scale
	var r: Rect2 = PICKUP_SCRIPT._opaque_rect_of(tex)
	var longest: float = maxf(r.size.x, r.size.y)
	return trash_scale if longest <= 0.0 else trash_px / longest

## 위로 튀어 올랐다(빠르게) → 다시 떨어져 덮이고(가속) → 덜컥 한 번 흔들린다
func _pop_lid() -> void:
	if _lid == null:
		return
	if _lid_tween and _lid_tween.is_valid():
		_lid_tween.kill()
	_lid.position = _lid_rest_pos
	_lid.rotation = _lid_rest_rot
	var tilt: float = deg_to_rad(lid_tilt_deg) * (-1.0 if randf() < 0.5 else 1.0)
	_lid_tween = create_tween()
	_lid_tween.set_parallel(true)
	_lid_tween.tween_property(_lid, "position:y", _lid_rest_pos.y - lid_pop_height, lid_rise_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lid_tween.tween_property(_lid, "rotation", _lid_rest_rot + tilt, lid_rise_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lid_tween.chain().tween_property(_lid, "position:y", _lid_rest_pos.y, lid_fall_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_lid_tween.tween_property(_lid, "rotation", _lid_rest_rot, lid_fall_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 덮이는 순간 덜컥
	_lid_tween.chain().tween_property(_lid, "rotation", _lid_rest_rot - tilt * 0.12, 0.05)
	_lid_tween.chain().tween_property(_lid, "rotation", _lid_rest_rot, 0.07)
