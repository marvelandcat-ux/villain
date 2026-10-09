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
## | 플랫폼 아래로 | S S | ↓ ↓ |
## | 대시 | A A / D D | ← ← / → → |
## | 방어 | F + G | L + K |
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

## 방어 = 기본공격 + 스킬1 **같이 누르기**(2026-10-08 사용자 지정 — 아래키는 발판 내려가기 전용).
## 둘 중 하나가 눌리면 이 시간(초)만큼 나머지 하나를 기다린다. 안 오면 눌린 것만 그대로 나간다 —
## 그래서 혼자 누른 평타·스킬1은 이만큼 늦게 나간다. 길면 손이 느린 사람도 방어가 되지만 평타가 굼떠진다
const GUARD_CHORD_WINDOW: float = 0.06
var _chord_left: float = 0.0
var _pending_attack: bool = false
var _pending_skill_1: bool = false


## "left" → "p1_left" 처럼 이 컨트롤러가 담당하는 플레이어의 액션 이름을 만든다
func _action(action_name: String) -> String:
	return "p%d_%s" % [player_index, action_name]

func _physics_process(delta: float) -> void:
	# 두 번 누르기 인정 시간은 입력을 받든 안 받든 항상 흐른다 (창이 지나면 첫 입력을 잊는다)
	if _tap_left > 0.0:
		_tap_left = maxf(_tap_left - delta, 0.0)
		if is_zero_approx(_tap_left):
			_tap_dir = 0.0
	if is_active:
		if Input.is_action_just_pressed(_action("down")):
			_drop_through()
		if fighter.movement_override == null:
			var direction := Input.get_axis(_action("left"), _action("right"))
			fighter.move(direction)
			_check_double_tap_dash()
			if Input.is_action_just_pressed(_action("jump")):
				fighter.jump()
			# 맵 전용 스킬(내리찍기 등)은 **전용 키**다(2026-09-30 사용자 지정: P1 E / P2 [).
			# 예전에는 공중에서 아래 키였는데, 아래 키가 방어·발판 통과까지 겸해서 헷갈렸다.
			# **지상/공중을 여기서 가리지 않는다**(2026-10-02) — 공사현장 내리찍기는 공중 전용이고
			# 헬스장 운동은 지상 전용이라, 어디서 쓸 수 있는지는 **스킬이 스스로 판단한다**
			# (`GroundPoundSkill`은 지상이면 _execute에서 그냥 돌아간다).
			# 맵에 스킬이 없으면 use_map_skill()이 아무 효과 없이 리턴한다
			if Input.is_action_just_pressed(_action("map_skill")):
				fighter.use_map_skill()

		_handle_attack_and_guard(delta)
		if Input.is_action_just_pressed(_action("skill_2")):
			fighter.use_skill_2()
		if Input.is_action_just_pressed(_action("ultimate")):
			fighter.use_ultimate()
	else:
		_pending_attack = false
		_pending_skill_1 = false
		_chord_left = 0.0
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

## 아래키를 **한 번** 누르면 발밑 발판을 통과해 아래층으로 내려간다(2026-10-08 사용자 요청 — 예전엔 두 번).
## 아래키가 방어를 겸하던 시절의 두 번 누르기는 이제 필요 없다. 통과 가능한 발판 위가 아니면(진짜 지면·공중) 아무 일도 없다
func _drop_through() -> void:
	if fighter.movement_override == null:
		fighter.drop_through_platform()

## 기본공격·스킬1 입력을 GUARD_CHORD_WINDOW 동안 모아 본다.
## 둘 다 모이면 방어, 창이 끝날 때까지 하나뿐이면 그것만 쓴다.
## 방어가 꺼진 방(GameState.guard_enabled)에서는 기다리지 않고 바로 쓴다 — 기다려 봤자 방어가 안 나간다
func _handle_attack_and_guard(delta: float) -> void:
	var attack_now := Input.is_action_just_pressed(_action("basic_attack"))
	var skill_now := Input.is_action_just_pressed(_action("skill_1"))
	if not GameState.guard_enabled:
		if attack_now:
			fighter.use_basic_attack()
		if skill_now:
			fighter.use_skill_1()
		return
	if (attack_now or skill_now) and not (_pending_attack or _pending_skill_1):
		_chord_left = GUARD_CHORD_WINDOW
	_pending_attack = _pending_attack or attack_now
	_pending_skill_1 = _pending_skill_1 or skill_now
	if not (_pending_attack or _pending_skill_1):
		return
	if _pending_attack and _pending_skill_1:
		# 같이 눌렀으면 방어만 — 쿨이라 못 켜도 평타·스킬은 안 나간다(방어하려던 손이 스킬을 날리면 억울하다)
		fighter.start_guard()
	else:
		_chord_left -= delta
		if _chord_left > 0.0:
			return
		if _pending_attack:
			fighter.use_basic_attack()
		else:
			fighter.use_skill_1()
	_pending_attack = false
	_pending_skill_1 = false
	_chord_left = 0.0
