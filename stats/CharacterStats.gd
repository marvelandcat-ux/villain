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
## 궁극기 컷인 장면 (ui/cutin/ 아래의 씬). 그림을 여러 장 그리는 대신 파츠를 코드로 흔드는 방식이라
## 씬 하나면 된다. 비어 있으면 캐릭터 이름만 뜨는 임시 화면이 나온다
@export var ultimate_cutin_scene: PackedScene
