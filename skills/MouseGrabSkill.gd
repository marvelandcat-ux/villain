class_name MouseGrabSkill
extends Skill

## 유선 마우스 그랩 — 마우스를 앞으로 던져 맞은 상대를 악플러 쪽으로 끌어온다 (악플러 스킬1, 임시).
## 실제 동작(날아가기·잡기·끌어오기)은 MouseGrab 노드가 전부 처리한다.
@export var throw_speed: float = 700.0
## 마우스가 날아가는 최대 거리(px). 이 안에 상대가 없으면 빗나가 사라진다
@export var max_range: float = 260.0
## 잡은 상대를 끌어오는 속도(px/초)
@export var reel_speed: float = 320.0
## 잡는 순간 주는 데미지
@export var damage: int = 4

func _execute(fighter: Fighter) -> void:
	var grab := MouseGrab.new()
	fighter.get_parent().add_child(grab)
	grab.setup(fighter, throw_speed, max_range, reel_speed, damage)
