extends Node2D

## 검은 고양이 똥 유탄 — 고양이 아주머니 궁극기(검은 고양이)가 쏜다. 포물선으로 날아가다 땅·벽에 닿거나 **상대 피격 판정(Hurtbox)에 닿는 즉시**
## 터져서 `radius` 안에 범위 피해(스플래시). 피해는 그 자리에 잠깐 켜는 원형 Hitbox가 준다(방어·숫자·스파크가 평소대로).
## 그림은 `고양이 똥.png`(BBOX만 잘라 `poop_size`로 줄임). 터질 때 `CatPoopBlast`가 충격파 + 맞는 범위 원을 보여 준다.
## `setup()`은 맵에 add_child 한 **뒤에** 부른다

const POOP_TEXTURE := preload("res://sprite/고양이 아줌마/고양이들/고양이 똥.png")
## 그림에서 똥이 차지하는 영역(px) — **그림을 바꾸면 다시 잴 것**
const POOP_BBOX := Rect2(127, 143, 1026, 982)
const BLAST_SCRIPT := preload("res://skills/CatPoopBlast.gd")

@export var gravity_force: float = 1200.0
## 아무 데도 안 닿을 때의 안전 수명(초)
@export var max_life: float = 3.0
## 똥 자체의 닿는 판정 반지름(px) — 이게 상대 Hurtbox(머리 끝~발끝)에 겹치면 터진다
@export var contact_radius: float = 10.0
## 터지는 판정이 켜져 있는 시간(초) — 한 프레임만 켜면 겹침을 놓친다
@export var burst_time: float = 0.12
@export var poop_color: Color = Color(0.45, 0.28, 0.12)
## 날아가는 똥 그림의 가로 크기(px)
@export var poop_size: float = 20.0

var _velocity: Vector2 = Vector2.ZERO
var _owner_fighter: Fighter = null
var _has_owner: bool = false
var _damage: int = 10
var _radius: float = 70.0
var _knockback: Vector2 = Vector2.ZERO
var _life: float = 0.0
var _exploded: bool = false
## 실제로 터뜨렸는지 — 땅과 상대에 같은 프레임에 닿아도 한 번만 터진다
var _burst_done: bool = false

## 쏜 사람·처음 속도·피해·폭발 반지름·넉백(x는 날아가는 쪽 부호를 곱해서 쓴다)
func setup(owner_fighter: Fighter, velocity: Vector2, damage: int, radius: float, knockback: Vector2) -> void:
	_owner_fighter = owner_fighter
	_has_owner = owner_fighter != null
	_velocity = velocity
	_damage = damage
	_radius = radius
	_knockback = Vector2(absf(knockback.x) * signf(velocity.x if velocity.x != 0.0 else 1.0), knockback.y)
	z_index = 20
	var sprite := Sprite2D.new()
	sprite.texture = POOP_TEXTURE
	sprite.region_enabled = true
	sprite.region_rect = POOP_BBOX
	sprite.scale = Vector2.ONE * (poop_size / POOP_BBOX.size.x)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	var contact := Area2D.new()
	contact.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = contact_radius
	shape.shape = circle
	contact.add_child(shape)
	add_child(contact)
	contact.area_entered.connect(_on_contact)

## 상대(또는 상대 집)의 Hurtbox에 닿았다 — 쏜 사람 자신·그 사람에게 면역인 몸(자기 집)은 지나간다.
## 물리 신호 도중이라 터뜨리기(판정 추가)는 다음으로 미룬다
func _on_contact(area: Area2D) -> void:
	if _exploded or not (area is Hurtbox):
		return
	if _has_owner and (area.fighter == _owner_fighter or area.immune_source == _owner_fighter):
		return
	_exploded = true
	call_deferred("_explode")

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_life += delta
	if _life >= max_life:
		queue_free()
		return
	var prev: Vector2 = global_position
	_velocity.y += gravity_force * delta
	var next: Vector2 = prev + _velocity * delta
	var hit: Dictionary = PhysicsQuery.raycast_ignoring_fighters(self, prev, next)
	if not hit.is_empty():
		global_position = hit.position
		_explode()
		return
	global_position = next
	rotation += delta * 10.0 * signf(_velocity.x)

func _explode() -> void:
	if _burst_done:
		return
	_burst_done = true
	_exploded = true
	var map: Node = get_parent()
	if map == null or (_has_owner and not is_instance_valid(_owner_fighter)):
		queue_free()
		return
	var hitbox := Hitbox.new()
	hitbox.damage = _damage
	hitbox.knockback = _knockback
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	hitbox.add_child(shape)
	if _has_owner:
		hitbox.source_fighter = _owner_fighter
	map.add_child(hitbox)
	hitbox.global_position = global_position
	Timers.self_destruct(hitbox, burst_time)
	var blast = BLAST_SCRIPT.new()
	blast.radius = _radius
	map.add_child(blast)
	blast.global_position = global_position
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.2)
	queue_free()
