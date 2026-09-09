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

## --- 아래는 실제 전투 수치가 아니라 도감(ui/CharacterDex)에만 쓰이는 표시용 별점(1~5)이다.
## max_hp/move_speed/attack_multiplier는 로스터 전체가 아직 거의 똑같은 값이라(밸런스 미확정),
## 그 숫자를 그대로 막대로 그리면 캐릭터마다 다 똑같아 보인다 — 그래서 "이 캐릭터가 어떤 느낌인지"를
## 기획자가 직접 1~5로 매겨서 인스펙터 슬라이더로 조절하게 분리했다
@export_range(1, 5, 1) var attack_rating: int = 3
@export_range(1, 5, 1) var hp_rating: int = 3
@export_range(1, 5, 1) var speed_rating: int = 3
## 도감 상세 설명 (여러 줄 가능)
@export_multiline var description: String = ""
