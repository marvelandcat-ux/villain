extends Node2D

## 궁극기(검은 고양이) 동안 아주머니가 겨드랑이에 끼고 있는 검은 고양이 — 엉덩이(똥꼬)가 앞(+x)을 향하고 머리는 뒤.
## 리그(Visual)의 자식이라 좌우 반전을 저절로 따라간다. 고양이 그림은 `CatSprite`를 좌우로 뒤집어 붙이고(`show_behind_parent`),
## 원점 = 고양이 몸통 가운데

const CAT_SPRITE := preload("res://skills/CatSprite.gd")

## 쏠 때 잠깐 움찔(0~1)
var _recoil: float = 0.0
var _sprite = null

func _ready() -> void:
	_sprite = CAT_SPRITE.new()
	_sprite.kind = 0
	_sprite.show_behind_parent = true
	add_child(_sprite)
	_place_sprite()

## 한 발 쏜 순간 — 엉덩이가 뒤로 움찔한다
func kick() -> void:
	_recoil = 1.0

func _process(delta: float) -> void:
	if _recoil > 0.0:
		_recoil = maxf(_recoil - delta * 6.0, 0.0)
		_place_sprite()

## 몸통 가운데가 원점에 오게, 머리가 뒤(-x)로 가게 뒤집는다
func _place_sprite() -> void:
	if _sprite == null:
		return
	_sprite.scale = Vector2(-1.0, 1.0)
	var c: Vector2 = _sprite.body_center_scaled()
	_sprite.position = Vector2(-_recoil * 3.0 + c.x, -c.y)
