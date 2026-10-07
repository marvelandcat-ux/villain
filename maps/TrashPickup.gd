extends Node2D

## 번화가 쓰레기통에서 튀어나온 쓰레기 한 조각(2026-10-08).
## 포물선으로 날아가 바닥·발판에 떨어져 **계속 쌓여 있다**(사라지지 않는다 — 사용자 결정).
## 캐릭터가 닿으면 그 캐릭터의 맵 스킬(`TrashBagThrowSkill.add_trash`)에 한 개 더해지고 사라진다.
## 맵 스킬이 꽉 찼으면(최대 스택) 줍지 않고 그대로 남는다.
##
## 물리 바디가 아니다 — 캐릭터와 부딪히면 안 되고 개수가 많아질 수 있어서,
## 떨어질 때만 아래로 레이캐스트해서 바닥을 찾는다(`PhysicsQuery`)

## 아래로 당기는 힘(px/s²)
@export var fall_gravity: float = 1300.0
## 날아가는 동안 도는 빠르기(라디안/초)
@export var spin_speed: float = 9.0
## 그림 아래끝 ~ 원점 거리(px). 바닥에 이만큼 띄워 놓는다
@export var foot: float = 9.0
## 주울 수 있는 가로 거리(캐릭터 중심 기준, px)
@export var pickup_half_width: float = 30.0
## 주울 수 있는 세로 범위(쓰레기 y - 캐릭터 중심 y). 캐릭터 머리 -60 ~ 발 +30
@export var pickup_min_dy: float = -75.0
@export var pickup_max_dy: float = 45.0
## 튀어나오고 이 시간(초) 동안은 못 줍는다 — 통에서 날아오르는 게 보이게
@export var pickup_delay: float = 0.25
## 맵 벽 안쪽으로만 다닌다(번화가 벽 ±926)
@export var x_limit: float = 900.0

var velocity: Vector2 = Vector2.ZERO
var _landed: bool = false
var _age: float = 0.0
var _taken: bool = false

## 그림과 처음 속도를 넣는다 — add_child 전에 부를 것
func setup(texture: Texture2D, art_scale: float, start_velocity: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(art_scale, art_scale)
	add_child(sprite)
	velocity = start_velocity
	rotation = randf_range(-PI, PI)

func _physics_process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_age += delta
	if not _landed:
		_fly(delta)
	if _age >= pickup_delay:
		_check_pickup()

func _fly(delta: float) -> void:
	velocity.y += fall_gravity * delta
	var next: Vector2 = global_position + velocity * delta
	next.x = clampf(next.x, -x_limit, x_limit)
	if velocity.y > 0.0:
		# 이번 프레임에 지나갈 구간 아래에 바닥(발판·전선 포함)이 있으면 그 위에 내려앉는다
		var hit: Dictionary = PhysicsQuery.raycast_ignoring_fighters(self,
			global_position + Vector2(0.0, foot), next + Vector2(0.0, foot))
		if not hit.is_empty():
			global_position = Vector2(hit.position.x, hit.position.y - foot)
			_landed = true
			rotation = randf_range(-0.35, 0.35)
			return
	global_position = next
	rotation += spin_speed * signf(velocity.x + 0.01) * delta
	if global_position.y > 2000.0:
		queue_free()

func _check_pickup() -> void:
	if _taken:
		return
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as Fighter
		if fighter == null or not is_instance_valid(fighter):
			continue
		if absf(fighter.global_position.x - global_position.x) > pickup_half_width:
			continue
		var dy: float = global_position.y - fighter.global_position.y
		if dy < pickup_min_dy or dy > pickup_max_dy:
			continue
		var skill = fighter.map_skill
		if skill == null or not skill.has_method("add_trash"):
			continue
		if not skill.add_trash(1):
			continue
		_vanish()
		return

## 주웠을 때 — 살짝 위로 빨려 올라가며 사라진다
func _vanish() -> void:
	_taken = true
	set_physics_process(false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 24.0, 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.15)
	tween.chain().tween_callback(queue_free)
