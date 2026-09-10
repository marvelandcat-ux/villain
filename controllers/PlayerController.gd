class_name PlayerController
extends Node

## 키보드 입력을 읽어서 부모 Fighter를 조작한다.
## P1/P2가 같은 키보드를 나눠 쓰기 때문에, 액션 이름을 "p1_"/"p2_" 접두사로 구분해서 읽는다.
##
## | 조작 | P1 | P2 |
## |---|---|---|
## | 이동 | A / D | ← / → |
## | 점프 | W | ↑ |
## | 기본공격 | F | L |
## | 스킬1 | G | K |
## | 스킬2 | H | J |
## | 궁극기 | R | P |
## | 플랫폼 아래로 | S + W | ↓ + ↑ |
@onready var fighter: Fighter = get_parent()

## 1이면 P1 키(A/D/W/S, F/G/H/R), 2면 P2 키(방향키, L/K/J/P)를 읽는다.
## Stage.gd가 Fighter에 붙일 때 지정한다 (기본값은 1P)
var player_index: int = 1

## false면 입력을 무시한다(대전 시작 카운트다운, 승패 판정 후 등) — 그래도 중력·바닥 착지는 계속 처리한다
var is_active: bool = true

## "left" → "p1_left" 처럼 이 컨트롤러가 담당하는 플레이어의 액션 이름을 만든다
func _action(action_name: String) -> String:
	return "p%d_%s" % [player_index, action_name]

func _physics_process(delta: float) -> void:
	if is_active:
		if fighter.movement_override == null:
			var direction := Input.get_axis(_action("left"), _action("right"))
			fighter.move(direction)
			if Input.is_action_just_pressed(_action("jump")):
				if Input.is_action_pressed(_action("down")):
					_drop_through_platform()
				else:
					fighter.jump()
			# 아래 키만 단독으로 누르면(점프와 조합이 아니면) 지상에서는 원래 아무 일도 없던 입력이라,
			# 공중에서만 맵 전용 스킬(내리찍기 등)에 자유롭게 배정할 수 있다. map_skill이 없는
			# 보통 맵에서는 use_map_skill()이 그냥 아무 효과 없이 리턴한다
			elif Input.is_action_just_pressed(_action("down")) and not fighter.is_on_floor():
				fighter.use_map_skill()

		if Input.is_action_just_pressed(_action("basic_attack")):
			fighter.use_basic_attack()
		if Input.is_action_just_pressed(_action("skill_1")):
			fighter.use_skill_1()
		if Input.is_action_just_pressed(_action("skill_2")):
			fighter.use_skill_2()
		if Input.is_action_just_pressed(_action("ultimate")):
			fighter.use_ultimate()
	else:
		# 멈춘 순간의 관성으로 계속 미끄러지지 않도록 수평 속도를 0으로 고정
		fighter.move(0.0)

	fighter.apply_physics(delta)

## 아래 방향 키를 누른 채 점프를 눌렀을 때 — 발밑 발판을 통과해서 아래층으로 내려간다.
## 통과 가능한 발판(one_way_collision) 위가 아니면 그냥 평범한 점프가 나간다 —
## 진짜 지면 위에서 아래키를 누른 채 점프했다고 아무 일도 안 일어나면 입력이 씹힌 것처럼 느껴지기 때문
func _drop_through_platform() -> void:
	if not fighter.drop_through_platform():
		fighter.jump()
