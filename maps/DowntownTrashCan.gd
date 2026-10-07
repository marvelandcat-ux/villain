extends Node2D

## 번화가 쓰레기통 하나(2026-10-08). 뚜껑(`Lid`)이 얹혀 있고, `DowntownTrashSpawner`가 고르면
## 뚜껑이 **위로 튕겨 열렸다가 다시 내려와 덮이고**, 그 사이 쓰레기가 통 위로 튀어나와 흩어진다.
## 쓰레기 조각은 `TrashPickup.gd` — 이 통의 부모(`TrashCans`)에 붙어 맵에 계속 남는다

const PICKUP_SCRIPT := preload("res://maps/TrashPickup.gd")

## 튀어나올 쓰레기 그림들(하나씩 랜덤)
@export var trash_textures: Array[Texture2D] = []
## 쓰레기 그림 배율 — 그림이 1254px 캔버스라 0.03이면 화면에서 약 20~30px
@export var trash_scale: float = 0.03
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

@onready var _lid: Node2D = get_node_or_null("Lid")
var _lid_rest_pos: Vector2
var _lid_rest_rot: float
var _lid_tween: Tween

func _ready() -> void:
	if _lid:
		_lid_rest_pos = _lid.position
		_lid_rest_rot = _lid.rotation

## 뚜껑을 튕기고 쓰레기를 count개 뱉는다
func burst(count: int) -> void:
	_pop_lid()
	for i in count:
		if i == 0:
			_spawn_one()
		else:
			Timers.after(self, spawn_gap * i, _spawn_one)

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
	piece.setup(trash_textures.pick_random(), trash_scale, vel)
	parent.add_child(piece)
	piece.global_position = to_global(spawn_offset)

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
