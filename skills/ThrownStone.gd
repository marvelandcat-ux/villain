class_name ThrownStone
extends Hitbox

## 던진 돌 — 직선으로 쫘악 뻗어나가 맞은 상대에게 데미지를 주고, **돌진(자전거)을 끊는다**.
## `fall_gravity`를 올리면 포물선으로도 쓸 수 있지만, 기본은 중력 0짜리 직구다.
## 주인공 스토리 모드 스킬2(StoneThrowSkill)가 쓴다.
##
## 돌진을 끊는 방식: 맞은 Fighter가 `movement_override`(이동을 가로채는 스킬)를 물고 있고
## 그 스킬에 `interrupt(fighter)`가 있으면 그걸 부른다. 지금은 DashSkill(잼민이 자전거)만 이 함수를 갖고 있다.
## 자전거를 안 타고 있을 때 맞으면 그냥 데미지만 들어간다

## 매초 이만큼 아래로 당겨진다(px/s²). **0이면 안 떨어지고 직선으로 간다**
@export var fall_gravity: float = 0.0
## 날아가는 동안 돌이 도는 빠르기(라디안/초) — 진행 방향으로 돈다.
## 빠른 직구라 크게 돌려야 "날아간다"는 느낌이 난다
@export var spin_speed: float = 16.0
## 아무것도 안 맞아도 이 시간이 지나면 사라진다(초)
@export var lifetime: float = 3.0
## 돌진을 끊을지. 끄면 데미지만 주는 평범한 투척물이 된다
@export var stop_dash: bool = true
## 부딪힌 자리에 터뜨릴 이펙트 (비면 아무것도 안 터진다)
@export var impact_effect: PackedScene = preload("res://combat/HitSpark.tscn")
## 잔상을 이 간격(초)마다 하나 남긴다. 0이면 잔상 없음.
## 촘촘할수록 선이 이어져 보여서 "쫘악" 뻗는 느낌이 난다
@export var trail_interval: float = 0.012
## 잔상 처음 투명도(0~1)와 사라지는 데 걸리는 시간(초)
@export var trail_alpha: float = 0.42
@export var trail_fade: float = 0.22

var _velocity: Vector2 = Vector2.ZERO
## 진행 방향(+1/-1) — 도는 방향에 쓴다
var _direction: float = 1.0
## 그림 노드 (잔상을 복제할 대상)
var _visual: Node2D
## 다음 잔상까지 남은 시간
var _trail_timer: float = 0.0
## 이미 한 번 처리(명중·충돌)돼서 사라지는 중인지 — 같은 프레임에 두 번 터지지 않게 막는다
var _spent: bool = false

func _ready() -> void:
	super._ready()
	# 비둘기(`DowntownPigeons`)가 "날아오는 게 있나" 볼 때 쓰는 표식. `projectiles` 그룹은 평타 가르기 대상이라 안 섞는다
	add_to_group("thrown_stones")
	body_entered.connect(_on_body_entered)
	connected.connect(_on_connected)
	_visual = get_node_or_null("Visual")

## 던지기 — 방향(1/-1), 수평 속도, 처음 위로 뜨는 속도(양수가 위), 최종 데미지, 던진 사람
func launch(direction: float, speed_x: float, launch_up: float, stone_damage: int, thrower: Fighter) -> void:
	_direction = 1.0 if direction >= 0.0 else -1.0
	_velocity = Vector2(_direction * speed_x, -launch_up)
	damage = stone_damage
	source_fighter = thrower
	knockback = Vector2(_direction * 120.0, -30.0)
	# 수명 타이머는 launch에서 만든다 — _ready()는 add_child 순간 돌아서
	# 그 뒤에 호출자가 lifetime을 바꿔도 이미 기본값으로 타이머가 잡힌 뒤다 (Projectile.gd와 같은 함정)
	Timers.self_destruct(self, lifetime)

func _physics_process(delta: float) -> void:
	_velocity.y += fall_gravity * delta
	position += _velocity * delta
	rotation += spin_speed * _direction * delta
	_update_trail(delta)

## 일정 간격마다 지금 모습의 반투명 잔상을 남기고 서서히 지운다 (본체보다 뒤에 그린다)
func _update_trail(delta: float) -> void:
	if trail_interval <= 0.0 or _visual == null:
		return
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = trail_interval
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var ghost := _visual.duplicate() as Node2D
	if ghost == null:
		return
	scene_root.add_child(ghost)
	ghost.global_position = _visual.global_position
	ghost.global_rotation = _visual.global_rotation
	ghost.scale = _visual.scale
	ghost.z_index = -1
	ghost.modulate.a = trail_alpha
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, trail_fade)
	tween.tween_callback(ghost.queue_free)

## 사람을 맞혔을 때 (Hitbox가 데미지를 먹인 뒤 connected로 알려준다)
func _on_connected(victim: Node) -> void:
	if _spent:
		return
	_spent = true
	if stop_dash:
		_stop_dash(victim)
	_spawn_impact()
	queue_free()

## 맞은 사람이 돌진 중이면 그 자리에서 끊는다 (자전거가 급정거한다)
func _stop_dash(victim: Node) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	if not ("movement_override" in victim):
		return
	var override = victim.movement_override
	if override == null or not is_instance_valid(override):
		return
	if not override.has_method("interrupt"):
		return
	override.interrupt(victim)

func _on_body_entered(body: Node2D) -> void:
	# 벽·바닥에 부딪히면 데미지 없이 사라진다.
	# **캐릭터의 몸(CharacterBody2D)은 벽으로 치지 않는다** — 캐릭터의 몸이 Hurtbox보다
	# 한 프레임 먼저 닿는 경우가 있어서, 여기서 돌을 치워버리면 데미지 판정(Hurtbox)에
	# 닿기 전에 사라지거나 `_spent`가 먼저 켜져 돌진 중단이 안 걸린다.
	# 사람에게 맞는 처리는 전부 Hurtbox(`_on_connected`)가 맡는다
	if _spent or body == source_fighter or body.is_in_group("fighters"):
		return
	_spent = true
	_spawn_impact()
	queue_free()

## 부딪힌 자리에 작은 충돌 이펙트를 터뜨린다
func _spawn_impact() -> void:
	if impact_effect == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var fx: Node2D = impact_effect.instantiate()
	scene_root.add_child(fx)
	fx.global_position = global_position
	fx.scale = Vector2(0.7, 0.7)

