class_name SlopeStair
extends StaticBody2D

## 비스듬한 계단 발판(악플러의 집). 판정은 기울인 원웨이 사각형 — 위에서만 밟히고, 아래+점프로 내려갈 수 있다.
## 캐릭터 기본 바닥 붙잡기(floor_snap_length 1px)로는 경사를 걸어 내려갈 때 매 프레임 살짝 떠서 통통 튄다.
## 그래서 이 맵에 있는 동안만 캐릭터들의 바닥 붙잡기를 늘리고, 오르막·내리막 속도도 평지와 같게 맞춘다.
## (라운드마다 씬을 다시 불러오고 캐릭터도 새로 만들어지므로 되돌릴 필요는 없다)

## 경사를 따라 붙어 있게 해 줄 거리(px). 경사 34도·이동속도 ~425 기준 한 프레임에 ~5px 내려가므로 여유 있게
@export var snap_length: float = 12.0

func _ready() -> void:
	# 캐릭터는 Stage._ready()에서 만들어지는데, 그건 이 노드의 _ready()보다 나중이다 — 한 박자 미룬다
	_tune_fighters.call_deferred()

func _tune_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		var body := node as CharacterBody2D
		if body == null:
			continue
		body.floor_snap_length = maxf(body.floor_snap_length, snap_length)
		body.floor_constant_speed = true
