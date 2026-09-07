class_name PortraitConfig
extends Resource

## 캐릭터별 초상화 배율(zoom)과 위치 보정(offset)을 담는 공유 설정.
## PortraitTuner(에디터 미리보기)와 CharacterSelect(실제 선택 화면)가 이 리소스 하나를 함께 읽는다.
## 값을 바꾸면 두 곳에 동시에 반영된다.

## 캐릭터 이름 -> 배율(1.0 = 기본, 크면 초상화가 커진다)
@export var zoom: Dictionary = {}
## 캐릭터 이름 -> 위치 보정(px). 초상화를 상자 안에서 살짝 옮길 때
@export var offset: Dictionary = {}

## 해당 캐릭터의 배율 (없으면 1.0)
func get_zoom(character_name: String) -> float:
	return float(zoom.get(character_name, 1.0))

## 해당 캐릭터의 위치 보정 (없으면 0)
func get_offset(character_name: String) -> Vector2:
	return offset.get(character_name, Vector2.ZERO)
