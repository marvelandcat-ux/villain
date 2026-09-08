class_name DummyController
extends Node

## 아무 판단도 하지 않고 제자리에 서 있기만 하는 컨트롤러 — 스킬 데미지·넉백을 확인할
## 고정된 타겟이 필요한 훈련용 샌드백(characters/dummy/TrainingDummy.tscn)에 붙인다.
## Fighter는 스스로 물리를 처리하지 않고 컨트롤러가 매 프레임 apply_physics를 불러줘야 하므로
## (중력·피격 경직·넉백 감속이 전부 거기서 처리된다) 그것만 대신 호출해준다
@onready var fighter: Fighter = get_parent()

func _physics_process(delta: float) -> void:
	fighter.move(0.0)
	fighter.apply_physics(delta)
