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

## 맵의 **왼쪽 끝과 오른쪽 끝** x. 이 선을 넘으면 반대 층 반대쪽에서 나온다.
## 맵을 화면 좌표(0~1720)에 맞춰 놓아서 가운데가 0이 아니다 — 그래서 양끝을 따로 적는다
@export var left_x: float = 0.0
@export var right_x: float = 1720.0
## 넘어간 뒤 반대쪽 끝에서 **이만큼 안쪽**에 놓는다. 0이면 바로 또 넘어가 버린다
@export var inset: float = 40.0
## 1층 바닥 윗면 y
@export var ground_y: float = 410.0
## 2층 바닥 윗면 y
@export var upper_y: float = 100.0
## 2층 바닥 판 **아랫면** y = 1층 천장. 2층에서 높이 뛴 채 내려오면 판 속에 박히지 않게 이 아래로 내려놓는다
@export var lower_ceiling_y: float = 145.0

## 방금 넘어온 선수는 잠깐 다시 안 넘기게 막는다 — 안 그러면 두 층을 깜빡거린다
@export var cooldown: float = 0.25

## 캐릭터 원점에서 몸 충돌 윗끝까지(몸 캡슐 높이 60의 반)
const BODY_HALF := 30.0

## {선수: 남은 잠금 시간}
var _locked: Dictionary = {}

func _ready() -> void:
	# AI가 "끝까지 걸어가면 다른 층"이라는 걸 알 수 있게 찾을 이름표를 단다
	add_to_group("level_wrap")

## 이 위치가 2층인지. **2층 바닥 윗면 하나로 가른다** — 2층 선수의 원점은 늘 그 위,
## 1층 선수는 천장(2층 판 아랫면)에 막혀 그 아래다. 두 바닥의 한가운데로 가르면
## 1층에서 이단 점프한 선수(원점이 천장 밑까지 올라감)를 2층으로 잘못 봐서 땅 밑으로 보냈다
func is_upper(pos: Vector2) -> bool:
	return pos.y < upper_y

## from에서 to가 있는 **다른 층**으로 가려면 걸어가야 할 x(맵 끝 바깥). 같은 층이면 NAN.
## 왼쪽 끝으로 나가면 반대 층 오른쪽 끝에서 나오므로, "끝까지 걷는 거리 + 나온 자리에서 to까지"가 짧은 쪽을 고른다
func exit_x_toward(from: Vector2, to: Vector2) -> float:
	if is_upper(from) == is_upper(to):
		return NAN
	var via_left: float = (from.x - left_x) + absf(to.x - (right_x - inset))
	var via_right: float = (right_x - from.x) + absf(to.x - (left_x + inset))
	return left_x - 10.0 if via_left <= via_right else right_x + 10.0

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
	if at.x > left_x and at.x < right_x:
		return
	# 층을 바꾸면 발밑 높이가 그만큼 통째로 움직인다
	var drop: float = ground_y - upper_y
	var new_y: float = at.y - drop
	if is_upper(at):
		# 1층으로 — 2층에서 높이 뛴 채였으면 천장(2층 판) 속에 박히니 머리가 천장 밑에 오게 내린다
		new_y = maxf(at.y + drop, lower_ceiling_y + BODY_HALF + 2.0)
	# 반대쪽 끝으로 — 왼쪽 끝으로 나갔으면 오른쪽 끝에서 들어온다
	var new_x: float = (right_x - inset) if at.x <= left_x else (left_x + inset)
	fighter.global_position = Vector2(new_x, new_y)
	_locked[id] = cooldown
	# 따라가는 카메라면 화면이 주욱 끌려가지 않게 곧바로 맞춘다(고정 카메라는 그대로 둔다)
	var cam: Node = get_parent().get_node_or_null("Camera2D")
	if cam and cam.has_method("snap_to_fighters"):
		cam.call("snap_to_fighters")
