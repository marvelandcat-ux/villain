class_name Skill
extends Node

## 모든 스킬의 공용 베이스 — 쿨타임 관리와 use(fighter) 인터페이스를 제공한다.
## 실제 효과는 하위 클래스가 _execute(fighter)를 오버라이드해서 구현한다.
@export var cooldown: float = 1.0
## 이 스킬을 쓰는 동안(모션이 재생되는 동안) 다른 스킬·기본공격을 못 쓰게 막는 시간(초).
## 0이면 안 막는다. 마시기/토하기처럼 동작이 긴 스킬에만 값을 준다
@export var lock_duration: float = 0.0
## HUD 쿨타임 슬롯에 뜨는 스킬 로고. 비워두면 로고 대신 캐릭터 색 사각형이 차오른다
@export var icon: Texture2D
## 켜면 라운드가 시작될 때 이 스킬이 **쿨타임을 물고 시작한다**(바로 못 쓴다).
## 궁극기를 라운드 초반부터 던지지 못하게 하는 용도 — 전 캐릭터 궁극기에 켜져 있다.
##
## **라운드 시작과 게임 시작이 따로 필요 없는 이유:** 라운드가 바뀔 때 `Stage`가
## `reload_current_scene()`으로 씬을 통째로 다시 만들어서 `_ready()`가 매 라운드 다시 돈다
@export var start_on_cooldown: bool = false

var cooldown_left: float = 0.0
## 0보다 크면 cooldown 대신 이 값이 쓰인다 — 버프가 잠깐 쿨타임을 **고정값으로** 덮어쓸 때 쓴다
## (악플러 열등감이 기본공격 쿨을 0.3초로 묶는 용도). 버프가 끝나면 0으로 되돌려 원래 cooldown으로 돌아간다.
## 배수(attack_speed_multiplier)와 달리 원래 값이 얼마든 결과가 같은 절대값이다
var cooldown_override: float = 0.0

## 지금 실제로 쓸 쿨타임 — 덮어쓰기가 걸려 있으면 그 값, 아니면 원래 cooldown
func effective_cooldown() -> float:
	return cooldown_override if cooldown_override > 0.0 else cooldown

func _ready() -> void:
	if start_on_cooldown:
		cooldown_left = effective_cooldown()

func _process(delta: float) -> void:
	if cooldown_left <= 0.0:
		return
	var fighter := get_parent() as Fighter
	var rate: float = fighter.cooldown_rate_multiplier if fighter else 1.0
	# 기본공격은 "공격속도" 버프(attack_speed_multiplier)만큼 쿨타임이 더 빨리 돈다 (악플러 열등감 등)
	if fighter and fighter.basic_attack == self:
		rate *= fighter.attack_speed_multiplier
	cooldown_left -= delta * rate

func can_use() -> bool:
	return cooldown_left <= 0.0

## 스킬을 사용한다. 쿨타임이 남아있으면 아무 일도 일어나지 않는다
func use(fighter: Fighter) -> void:
	if not can_use():
		return
	cooldown_left = effective_cooldown()
	# 모션이 긴 스킬은 그동안 다른 스킬을 못 쓰게 잠근다 (이동은 계속 가능)
	if lock_duration > 0.0 and fighter:
		fighter.start_busy(lock_duration)
	_execute(fighter)

## 스킬 클래시(연타 미니게임)에서 졌을 때 호출한다 — 실제 효과(_execute)는 내지 않고
## 쿨타임만 정상적으로 소모시킨다. "동시에 썼지만 상대에게 밀려서 불발됐다"는 느낌
func cancel_use() -> void:
	cooldown_left = effective_cooldown()

## 하위 클래스가 실제 효과를 구현하는 곳
func _execute(_fighter: Fighter) -> void:
	pass

## true면 이 스킬이 자기 공격 모션을 직접 재생한다는 뜻 — Fighter가 기본 스윙(play_attack_swing())을
## 덧대지 않는다. 타별로 스윙이 다른 콤보 평타처럼, 모션 타이밍/종류를 스킬이 직접 제어할 때 쓴다
func handles_own_visual() -> bool:
	return false
