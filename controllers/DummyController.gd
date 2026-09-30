class_name DummyController
extends Node

## 아무 판단도 하지 않고 제자리에 서 있기만 하는 컨트롤러 — 스킬 데미지·넉백을 확인할
## 고정된 타겟이 필요한 훈련용 샌드백(characters/dummy/TrainingDummy.tscn)에 붙인다.
## Fighter는 스스로 물리를 처리하지 않고 컨트롤러가 매 프레임 apply_physics를 불러줘야 하므로
## (중력·피격 경직·넉백 감속이 전부 거기서 처리된다) 그것만 대신 호출해준다.
## auto_attack을 켜면 상대 쪽을 보고 attack_interval마다 기본공격을 계속 한다(카운터·방어 연습용, 훈련장 체크박스)

## 켜면 기본공격을 계속 한다
var auto_attack: bool = false
## 기본공격 간격(초)
var attack_interval: float = 0.8

@onready var fighter: Fighter = get_parent()

var _attack_left: float = 0.0

func _physics_process(delta: float) -> void:
	fighter.move(0.0)
	if auto_attack:
		_update_auto_attack(delta)
	fighter.apply_physics(delta)

func _update_auto_attack(delta: float) -> void:
	_attack_left -= delta
	if _attack_left > 0.0 or fighter.is_busy():
		return
	var opponent: Fighter = fighter.find_opponent()
	if opponent and is_instance_valid(opponent):
		var dx: float = opponent.global_position.x - fighter.global_position.x
		if not is_zero_approx(dx):
			fighter.facing = signf(dx)
	fighter.use_basic_attack()
	_attack_left = attack_interval
