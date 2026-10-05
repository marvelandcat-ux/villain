class_name GymWrap
extends Node2D

## **헬스장 층 넘나들기** — 맵 끝까지 걸어가면 **반대 층의 반대쪽**에서 나온다.
##
## 2층 바닥이 맵 가로를 통째로 덮고 있어서 점프로는 올라갈 수 없다. 대신
##   1층 왼쪽 끝  → 2층 오른쪽 끝
##   1층 오른쪽 끝 → 2층 왼쪽 끝
##   2층 왼쪽 끝  → 1층 오른쪽 끝
##   2층 오른쪽 끝 → 1층 왼쪽 끝
## 이렇게 돌아간다(2026-10-06 사용자 지정). 계단을 그릴 필요도, 올라가는 조작을 따로 둘 필요도 없다.
##
## ⚠️ **좌우 벽이 없어야 한다.** 벽이 있으면 끝에 닿기 전에 막혀서 넘어갈 수가 없다.
##
## 넘어갈 때 **발밑 높이 차이는 그대로 둔다** — 뛰어오른 채로 끝에 닿으면 반대 층에서도 떠 있다.
## 그래야 이동이 끊기지 않고 이어지는 느낌이 난다

## 맵의 좌우 끝(가운데에서의 거리). 이 선을 넘으면 넘어간다
@export var edge_x: float = 884.0
## 넘어간 뒤 반대쪽 끝에서 **이만큼 안쪽**에 놓는다. 0이면 바로 또 넘어가 버린다
@export var inset: float = 40.0
## 1층 바닥 윗면 y
@export var ground_y: float = 410.0
## 2층 바닥 윗면 y
@export var upper_y: float = 100.0

## 방금 넘어온 선수는 잠깐 다시 안 넘기게 막는다 — 안 그러면 두 층을 깜빡거린다
@export var cooldown: float = 0.25

## {선수: 남은 잠금 시간}
var _locked: Dictionary = {}

func _physics_process(delta: float) -> void:
	for key in _locked.keys():
		_locked[key] = _locked[key] - delta
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if not (fighter is Node2D):
			continue
		_check(fighter as Node2D)

func _check(fighter: Node2D) -> void:
	var id: int = fighter.get_instance_id()
	if _locked.get(id, 0.0) > 0.0:
		return
	var at: Vector2 = fighter.global_position
	if absf(at.x) < edge_x:
		return
	# 지금 어느 층에 있는지 — 두 바닥의 한가운데를 기준으로 가른다
	var middle: float = (ground_y + upper_y) * 0.5
	var on_upper: bool = at.y < middle
	# 층을 바꾸면 발밑 높이가 그만큼 통째로 움직인다
	var drop: float = ground_y - upper_y
	var new_y: float = at.y + (drop if on_upper else -drop)
	# 반대쪽 끝으로 — 왼쪽 끝으로 나갔으면 오른쪽 끝에서 들어온다
	var new_x: float = (edge_x - inset) if at.x <= -edge_x else -(edge_x - inset)
	fighter.global_position = Vector2(new_x, new_y)
	_locked[id] = cooldown
	# 카메라가 따라오느라 주욱 끌려가지 않게, 넘어간 자리로 바로 옮겨 준다
	var cam: Node = get_parent().get_node_or_null("Camera2D")
	if cam is Node2D:
		(cam as Node2D).global_position.x = new_x
