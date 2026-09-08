class_name SandPit
extends Area2D

## 발이 푹푹 빠지는 모래사장 — 모래 위에 서 있는 동안만 이동속도가 느려진다 (놀이터 맵 가운데).
##
## 판정을 발치 높이(지면 바로 위)에만 둬서, 모래를 걸어서 지나가면 느려지고
## 점프해서 뛰어넘으면 걸리지 않는다 — 느린 구간을 감수하고 걷느냐, 점프로 넘느냐의 선택이 된다.
##
## 느려지는 효과는 set_modifier로 건 배수 하나뿐이라, 다른 둔화 효과(도발·기타연주 등)와
## 동시에 걸려도 서로 지우지 않고 곱해져서 적용된다.

## 모래 안에서의 이동속도 배수 (0.6이면 원래 속도의 60%)
@export_range(0.1, 1.0, 0.05) var slow_multiplier: float = 0.6

## set_modifier에 넘길 id — 모래사장이 여러 개 있어도 서로 효과를 지우지 않도록 노드마다 다른 값을 쓴다
var _modifier_id: int = 0
## 지금 모래 안에 있는 Fighter들 {Fighter: true}
var _inside: Dictionary = {}

func _ready() -> void:
	_modifier_id = get_instance_id()

## area_entered/exited 신호 대신 매 프레임 겹친 목록을 훑는다 — 라운드 리셋이나 순간이동으로
## 신호가 안 오는 경우가 있어서 "지금 겹쳐 있는가"를 다시 보는 쪽이 확실하다 (SpringJumpPad와 같은 방식)
func _physics_process(_delta: float) -> void:
	var now: Dictionary = {}
	for area in get_overlapping_areas():
		if not (area is Hurtbox):
			continue
		var fighter: Fighter = area.fighter
		if fighter == null or not is_instance_valid(fighter):
			continue
		now[fighter] = true
		# 이미 걸려 있는 캐릭터에 매 프레임 다시 걸 필요는 없다
		if not _inside.has(fighter):
			fighter.set_modifier("move_speed_multiplier", _modifier_id, slow_multiplier)

	# 모래를 벗어난 캐릭터는 원래 속도로 되돌린다 (사라진 캐릭터는 되돌릴 대상이 없으니 그냥 넘어간다)
	for fighter in _inside.keys():
		if now.has(fighter):
			continue
		if is_instance_valid(fighter):
			fighter.clear_modifier("move_speed_multiplier", _modifier_id)

	_inside = now
