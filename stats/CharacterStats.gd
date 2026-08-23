class_name CharacterStats
extends Resource

## 캐릭터 이름 (표시용)
@export var character_name: String = ""
## 최대 체력
@export var max_hp: int = 100
## 이동 속도
@export var move_speed: float = 200.0
## 기본 공격력 배율 (스킬 데미지 계산의 기준값)
@export var attack_multiplier: float = 1.0
