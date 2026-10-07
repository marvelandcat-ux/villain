@tool
class_name GymPlacement
extends Resource

## **헬스장 기구 배치표** — 기구 셋(바벨 컬 / 스쿼트 / 런닝머신)을 어디에 둘지 적어 둔 묶음이다.
##
## 배치 하나가 "이번 판은 이렇게 놓는다"에 해당하고, 라운드가 바뀔 때마다 `GymLayout`이
## 이 중 하나를 골라 쓴다. 자리는 **눈으로 보고 맞춘 최종 좌표**라, 읽는 쪽은 그대로 넣기만 하면 된다
## ⚠️ **세로는 `GymLayout`이 다시 구한다**(층 높이 + `GymMachine.sink()`). 표에 적힌 y는 **어느 층인지**만 쓴다 —
## 기구 크기를 바꾸면 묻히는 깊이가 달라져서, 표에 박힌 y를 그대로 쓰면 바닥에 박히거나 공중에 뜬다(2026-10-07).
##
## 셋을 한 배열에 섞지 않고 기구마다 배열을 따로 둔 이유는, 배열 길이가 서로 어긋나도
## 그 기구만 기본 자리로 떨어지고 나머지는 멀쩡히 돌기 때문이다.
##
## 자리를 고치는 곳: **이 `.tres`를 인스펙터에서 직접 고친다.** 끌어서 맞추던 편집 씬
## (`GymPlacementStudio`)은 2026-10-06 '개혁'에서 스크립트가 빠지며 죽어서 지웠다
## (되살리려면 `git show b94dda2^:maps/GymPlacementStudio.gd`)

## 기구 종류 — `GymMachine.Kind`와 같은 번호다
enum Kind { CURL, SQUAT, TREADMILL }

## 배치마다의 자리. 세 배열의 **같은 번호끼리 한 세트**다
@export var curl: PackedVector2Array = PackedVector2Array()
@export var squat: PackedVector2Array = PackedVector2Array()
@export var treadmill: PackedVector2Array = PackedVector2Array()

## 좌우로 뒤집을지 — 0이면 그대로, 1이면 뒤집는다. 위 배열과 번호가 맞물린다
@export var curl_flip: PackedByteArray = PackedByteArray()
@export var squat_flip: PackedByteArray = PackedByteArray()
@export var treadmill_flip: PackedByteArray = PackedByteArray()

## 적어 둔 배치가 몇 개인지 — **세 기구 모두 자리가 있는 수**만 센다
func count() -> int:
	return mini(curl.size(), mini(squat.size(), treadmill.size()))

## 그 기구의 자리 배열을 꺼낸다(바꿔 쓰면 원본이 바뀐다)
func _spots(kind: int) -> PackedVector2Array:
	match kind:
		Kind.SQUAT:
			return squat
		Kind.TREADMILL:
			return treadmill
		_:
			return curl

func _flips(kind: int) -> PackedByteArray:
	match kind:
		Kind.SQUAT:
			return squat_flip
		Kind.TREADMILL:
			return treadmill_flip
		_:
			return curl_flip

## `index`번 배치에서 그 기구가 설 자리. 적어 둔 게 없으면 `fallback`을 그대로 돌려준다
func spot(kind: int, index: int, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var list: PackedVector2Array = _spots(kind)
	if index < 0 or index >= list.size():
		return fallback
	return list[index]

## `index`번 배치에서 그 기구를 뒤집는지
func flipped(kind: int, index: int) -> bool:
	var list: PackedByteArray = _flips(kind)
	if index < 0 or index >= list.size():
		return false
	return list[index] != 0

## 자리를 적어 넣는다(편집 씬이 쓴다). 배열이 짧으면 그 번호까지 늘린다
func set_spot(kind: int, index: int, at: Vector2, flip: bool) -> void:
	if index < 0:
		return
	var list: PackedVector2Array = _spots(kind)
	var flags: PackedByteArray = _flips(kind)
	while list.size() <= index:
		list.append(Vector2.ZERO)
	while flags.size() <= index:
		flags.append(0)
	list[index] = at
	flags[index] = 1 if flip else 0
	match kind:
		Kind.SQUAT:
			squat = list
			squat_flip = flags
		Kind.TREADMILL:
			treadmill = list
			treadmill_flip = flags
		_:
			curl = list
			curl_flip = flags
