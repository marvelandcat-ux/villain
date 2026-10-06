extends Node2D

## 궁극기(검은 고양이) 동안 아주머니가 겨드랑이에 끼고 있는 검은 고양이 — 엉덩이(똥꼬)가 앞(+x)을 향하고 머리는 뒤.
## 리그(Visual)의 자식이라 좌우 반전을 저절로 따라간다. 고양이 그림은 `CatSprite`를 좌우로 뒤집어 붙이고(`show_behind_parent`),
## 그 위에 이 노드가 똥꼬 동그라미와 남은 탄 점을 그린다. 원점 = 고양이 몸통 가운데

const CAT_SPRITE := preload("res://skills/CatSprite.gd")
const OUTLINE := Color(0.08, 0.06, 0.06)

## 남은 탄 점이 뜨는 자리(이 노드 기준)
@export var ammo_offset: Vector2 = Vector2(-8.0, -80.0)
@export var ammo_color: Color = Color(0.45, 0.28, 0.12)

var shots_left: int = 5:
	set(value):
		shots_left = value
		queue_redraw()
var max_shots: int = 5
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
		queue_redraw()

## 몸통 가운데가 원점에 오게, 머리가 뒤(-x)로 가게 뒤집는다
func _place_sprite() -> void:
	if _sprite == null:
		return
	_sprite.scale = Vector2(-1.0, 1.0)
	var c: Vector2 = _sprite.body_center_scaled()
	_sprite.position = Vector2(-_recoil * 3.0 + c.x, -c.y)

func _draw() -> void:
	var gap: float = 8.0
	var start: float = ammo_offset.x - gap * (max_shots - 1) * 0.5
	for i in max_shots:
		var dot := Vector2(start + gap * i, ammo_offset.y)
		draw_circle(dot, 3.4, OUTLINE)
		draw_circle(dot, 2.5, ammo_color if i < shots_left else Color(0.75, 0.75, 0.75, 0.6))
