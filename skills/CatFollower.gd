class_name CatFollower
extends CharacterBody2D

## 고양이 집에서 나온 고양이 — 지금은 **상대를 졸졸 따라다니기만** 한다(종류별 능력은 미정, TODO).
## 그림은 `CatSprite`(파츠 조립) 자식. 종류(검은·주황·흰)는 `kind`로 정하고 **add_child 전에** 넣을 것.
##
## 충돌 레이어를 0으로 둬서 캐릭터·다른 고양이와 몸으로 부딪치지 않고, 바닥·벽(마스크 1)만 밟는다

enum Kind { BLACK, ORANGE, WHITE }

const CAT_SPRITE := preload("res://skills/CatSprite.gd")

## 종류별 털 색 / 이름(머리 위 표시·디버그용)
const FUR_COLORS: Array[Color] = [Color(0.16, 0.16, 0.18), Color(0.95, 0.56, 0.2), Color(0.97, 0.97, 0.95)]
const KIND_NAMES: Array[String] = ["검은 고양이", "주황 고양이", "흰 고양이"]
const OUTLINE_COLOR := Color(0.1, 0.08, 0.08)

@export var move_speed: float = 200.0
## 상대에게 이만큼(px)까지 다가가면 멈춘다 — 고양이마다 조금씩 달라서 한 자리에 겹쳐 서지 않는다
@export var stop_distance_min: float = 36.0
@export var stop_distance_max: float = 70.0
## 벽에 막혔을 때 뛰어넘으려는 점프 속도(px/초)
@export var hop_speed: float = 360.0
@export var gravity_force: float = 1150.0
## 처음 나올 때 커지는 시간(초)
@export var pop_time: float = 0.2

var kind: int = Kind.BLACK
## 이 고양이를 부른 캐릭터 — 그 상대를 따라간다. 해제 여부는 `_has_owner`로 따로 기억한다
var owner_fighter: Fighter = null:
	set(value):
		owner_fighter = value
		_has_owner = value != null

var _has_owner: bool = false
var _facing: float = 1.0
var _stop_distance: float = 40.0
var _walk_phase: float = 0.0
var _age: float = 0.0
var _sprite = null

func _ready() -> void:
	add_to_group("catmom_cats")
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30.0, 20.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -10.0)
	add_child(shape)
	_stop_distance = randf_range(stop_distance_min, stop_distance_max)
	z_index = 5
	_sprite = CAT_SPRITE.new()
	_sprite.name = "Visual"
	_sprite.kind = kind
	add_child(_sprite)
	_update_sprite()

func _physics_process(delta: float) -> void:
	_age += minf(delta, 0.05)
	if not is_on_floor():
		velocity.y += gravity_force * delta
	var target: Fighter = _target()
	var want_x: float = 0.0
	if target:
		var dx: float = target.global_position.x - global_position.x
		if absf(dx) > _stop_distance:
			want_x = signf(dx) * move_speed
		if absf(dx) > 4.0:
			_facing = signf(dx)
	velocity.x = want_x
	if want_x != 0.0 and is_on_floor() and is_on_wall():
		velocity.y = -hop_speed
	move_and_slide()
	_walk_phase = _walk_phase + delta * 14.0 if want_x != 0.0 else 0.0
	_update_sprite()

## 방향·처음 커지기·걷기 박자를 그림에 넘긴다
func _update_sprite() -> void:
	if _sprite == null:
		return
	var pop: float = clampf(_age / maxf(pop_time, 0.01), 0.0, 1.0)
	var s: float = 0.6 + 0.4 * pop
	_sprite.scale = Vector2(_facing * s, s)
	_sprite.walk_phase = _walk_phase

func _target() -> Fighter:
	if not _has_owner or not is_instance_valid(owner_fighter):
		return null
	var foe: Fighter = owner_fighter.find_opponent()
	return foe if is_instance_valid(foe) else null

## 고양이 얼굴(머리 그림) — 머리 위 선택 표시·집 간판이 같은 그림을 쓴다. center가 얼굴 가운데, r은 예전 원형 머리 반지름 기준(귀 포함 가로 = r x 2.6)
static func draw_face(ci: CanvasItem, cat_kind: int, center: Vector2, r: float) -> void:
	CAT_SPRITE.draw_head(ci, cat_kind, center, r * 2.6)

