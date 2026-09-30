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
## | 대시 | A A / D D | ← ← / → → |
## | 방어 | S | ↓ |
@onready var fighter: Fighter = get_parent()

## 같은 방향키를 두 번 눌러 대시로 인정하는 간격(초).
## 길게 잡으면 걷다가 방향을 바꿀 때 의도치 않게 대시가 나가고, 짧으면 잘 안 나간다
const DOUBLE_TAP_WINDOW: float = 0.25

## 1이면 P1 키(A/D/W/S, F/G/H/R), 2면 P2 키(방향키, L/K/J/P)를 읽는다.
## Stage.gd가 Fighter에 붙일 때 지정한다 (기본값은 1P)
var player_index: int = 1

## false면 입력을 무시한다(대전 시작 카운트다운, 승패 판정 후 등) — 그래도 중력·바닥 착지는 계속 처리한다
var is_active: bool = true

## 마지막으로 눌린 방향(-1/0/1)과, 그 입력이 "첫 번째 탭"으로 유효한 남은 시간
var _tap_dir: float = 0.0
var _tap_left: float = 0.0

## 방어를 켠 직후 이 시간(초) 안에 점프를 누르면 "발판 통과" 의도로 보고
## 방어를 취소하고 쿨타임도 돌려준다 — 아래키가 방어와 발판 통과에 같이 쓰이기 때문
const GUARD_CANCEL_WINDOW: float = 0.25
var _guard_cancel_left: float = 0.0

## "left" → "p1_left" 처럼 이 컨트롤러가 담당하는 플레이어의 액션 이름을 만든다
func _action(action_name: String) -> String:
	return "p%d_%s" % [player_index, action_name]

func _physics_process(delta: float) -> void:
	# 두 번 누르기 인정 시간은 입력을 받든 안 받든 항상 흐른다 (창이 지나면 첫 입력을 잊는다)
	if _tap_left > 0.0:
		_tap_left = maxf(_tap_left - delta, 0.0)
		if is_zero_approx(_tap_left):
			_tap_dir = 0.0
	if _guard_cancel_left > 0.0:
		_guard_cancel_left = maxf(_guard_cancel_left - delta, 0.0)
	if is_active:
		# 아래 키를 누른 "순간" 방어가 켜진다 (누르고 있는 게 아니라 한 번 눌러 발동)
		if Input.is_action_just_pressed(_action("down")) and fighter.start_guard():
			_guard_cancel_left = GUARD_CANCEL_WINDOW
		if fighter.movement_override == null:
			var direction := Input.get_axis(_action("left"), _action("right"))
			fighter.move(direction)
			_check_double_tap_dash()
			if Input.is_action_just_pressed(_action("jump")):
				if Input.is_action_pressed(_action("down")):
					# 아래키를 누르자마자 점프 = 발판 통과 의도. 방금 켠 방어는 없던 일로 하고
					# 쿨타임도 돌려준다 — 안 그러면 발판을 내려갈 때마다 5초 쿨을 날린다
					if _guard_cancel_left > 0.0:
						fighter.cancel_guard(true)
						_guard_cancel_left = 0.0
					_drop_through_platform()
				else:
					fighter.jump()
			# 맵 전용 스킬(내리찍기 등)은 **전용 키**다(2026-09-30 사용자 지정: P1 E / P2 [).
			# 예전에는 공중에서 아래 키였는데, 아래 키가 방어·발판 통과까지 겸해서 헷갈렸다.
			# 공중에서만 나간다 — 맵에 스킬이 없으면 use_map_skill()이 그냥 아무 효과 없이 리턴한다
			if Input.is_action_just_pressed(_action("map_skill")) and not fighter.is_on_floor():
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

## 같은 방향키를 DOUBLE_TAP_WINDOW 안에 두 번 누르면 그 방향으로 대시한다.
## 두 번째가 인정되면 기록을 지운다 — 안 지우면 세 번째·네 번째 탭마다 계속 대시가 나간다.
## 방향을 반대로 누르면 그게 새로운 "첫 번째 탭"이 된다
func _check_double_tap_dash() -> void:
	var dir: float = 0.0
	if Input.is_action_just_pressed(_action("right")):
		dir = 1.0
	elif Input.is_action_just_pressed(_action("left")):
		dir = -1.0
	if is_zero_approx(dir):
		return
	if dir == _tap_dir and _tap_left > 0.0:
		fighter.dash(dir)
		_tap_dir = 0.0
		_tap_left = 0.0
	else:
		_tap_dir = dir
		_tap_left = DOUBLE_TAP_WINDOW

## 아래 방향 키를 누른 채 점프를 눌렀을 때 — 발밑 발판을 통과해서 아래층으로 내려간다.
## 통과 가능한 발판(one_way_collision) 위가 아니면 그냥 평범한 점프가 나간다 —
## 진짜 지면 위에서 아래키를 누른 채 점프했다고 아무 일도 안 일어나면 입력이 씹힌 것처럼 느껴지기 때문
func _drop_through_platform() -> void:
	if not fighter.drop_through_platform():
		fighter.jump()
