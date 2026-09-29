class_name Projectile
extends Hitbox

## 직선으로 날아가는 투사체 공용 컴포넌트 (비비탄, 토하기 등). Hitbox를 상속해서 맞으면 실제 데미지를 준다
@export var lifetime: float = 1.5
## 진행 방향으로 매초 이만큼 빨라진다(px/s²). 0이면 등속. 시간이 지날수록 빨라지는 총알에 쓴다
@export var acceleration: float = 0.0
## 가속으로 붙는 속도의 상한(px/s). 0이면 무제한 (너무 빨라져 얇은 벽을 뚫는 것 방지)
@export var max_speed: float = 0.0

## --- 생동감 연출 ---
## 이 속도(px/s)일 때 그림이 원래 크기(늘어남 1배)다. 이보다 빠르면 진행 방향으로 길쭉해진다. 0이면 늘이지 않는다
@export var stretch_ref_speed: float = 650.0
## 속도선(스트레치) 최대 배수 — 아무리 빨라도 이 이상은 안 늘어난다
@export var stretch_max: float = 2.4
## 잔상을 이 간격(초)마다 하나 남긴다. 0이면 잔상 없음
@export var trail_interval: float = 0.02
## 잔상 처음 투명도(0~1)
@export var trail_alpha: float = 0.35
## 잔상이 사라지는 데 걸리는 시간(초)
@export var trail_fade: float = 0.15
## 벽/바닥에 맞았을 때 터뜨리는 충돌 이펙트 (비면 스파크 없음)
@export var impact_effect: PackedScene = preload("res://combat/HitSpark.tscn")

var _velocity_x: float = 0.0
## 진행 방향(+1/-1) — 가속을 이 방향으로 더한다
var _direction: float = 1.0
## 그림 노드와 그 원래 크기 — 속도선(스트레치)·잔상에 쓴다
var _visual: Node2D
var _visual_base_scale: Vector2 = Vector2.ONE
## 다음 잔상까지 남은 시간
var _trail_timer: float = 0.0

## 잘려서 만들 반쪽 조각(악플러 풍차). 새 스크립트라 preload로 가져온다(class_name 캐시 전 파싱 에러 방지)
const SLICED_PROJECTILE := preload("res://combat/SlicedProjectile.gd")

func _ready() -> void:
	super._ready()
	body_entered.connect(_on_body_entered)
	# 회전 난무 등이 범위 안 투사체를 찾을 수 있게 그룹에 넣는다
	add_to_group("projectiles")
	# 그림 노드와 원래 크기를 기억해둔다 (속도선·잔상용)
	_visual = get_node_or_null("Visual")
	if _visual:
		_visual_base_scale = _visual.scale

## 반토막 난다(악플러 풍차에 맞음) — 그림을 위/아래 반쪽 두 조각으로 나눠 맵에 남기고 자신은 사라진다
func slice_in_half() -> void:
	var parent: Node = get_parent()
	if parent != null and _visual is Sprite2D:
		var spr: Sprite2D = _visual
		var tex: Texture2D = spr.texture
		if tex != null:
			var world_scale: Vector2 = spr.global_scale
			# region이 있으면 그 사각형을, 없으면 텍스처 전체를 위/아래로 반 나눈다
			var full: Rect2 = spr.region_rect if spr.region_enabled else Rect2(Vector2.ZERO, tex.get_size())
			var half_h: float = full.size.y * 0.5
			var top_rect := Rect2(full.position, Vector2(full.size.x, half_h))
			var bot_rect := Rect2(full.position + Vector2(0.0, half_h), Vector2(full.size.x, half_h))
			var dir: float = 1.0 if _direction >= 0.0 else -1.0
			# 위 반쪽은 튀어 오르고, 아래 반쪽은 낮게 — 둘 다 진행하던 쪽으로 살짝 흩어지며 돈다
			_spawn_half(parent, tex, top_rect, world_scale, Vector2(dir * 60.0, -140.0), -6.0)
			_spawn_half(parent, tex, bot_rect, world_scale, Vector2(dir * 40.0, -40.0), 6.0)
	queue_free()

func _spawn_half(parent: Node, tex: Texture2D, region: Rect2, sprite_scale: Vector2, vel: Vector2, spin: float) -> void:
	var half := SLICED_PROJECTILE.new()
	parent.add_child(half)
	half.setup(tex, true, region, sprite_scale, true, global_position, vel, spin)

## 발사 방향(1 또는 -1), 속도, 최종 데미지, 발사자를 지정한다
func setup(direction: float, speed: float, projectile_damage: int, shooter: Fighter) -> void:
	_direction = 1.0 if direction >= 0.0 else -1.0
	_velocity_x = direction * speed
	damage = projectile_damage
	source_fighter = shooter
	knockback = Vector2(direction * 100.0, -20.0)
	rotation = 0.0 if direction >= 0.0 else PI
	_start_lifetime_timer()

## 수명 타이머는 _ready()가 아니라 setup()에서 만든다 — _ready()는 add_child 하는 순간 바로 실행돼서,
## 호출자가 그 다음 줄에서 lifetime을 바꿔도 이미 기본값(1.5)으로 타이머가 만들어진 뒤였다.
## 이것 때문에 토하기의 스택별 사거리(lifetime_per_stack)가 한동안 전혀 안 먹고 있었음.
## 투사체 자신의 자식 Timer라서 투사체가 먼저 사라지면 타이머도 같이 정리된다
func _start_lifetime_timer() -> void:
	Timers.self_destruct(self, lifetime)

func _physics_process(delta: float) -> void:
	# 시간이 지날수록 진행 방향으로 빨라진다 (max_speed가 있으면 거기서 멈춘다)
	if acceleration != 0.0:
		_velocity_x += _direction * acceleration * delta
		if max_speed > 0.0:
			_velocity_x = clampf(_velocity_x, -max_speed, max_speed)
	position.x += _velocity_x * delta
	_apply_stretch()
	_update_trail(delta)

## 속도가 빠를수록 그림을 진행 방향으로 길쭉하게 늘인다 (속도선)
func _apply_stretch() -> void:
	if _visual == null or stretch_ref_speed <= 0.0:
		return
	var stretch: float = clampf(absf(_velocity_x) / stretch_ref_speed, 1.0, stretch_max)
	_visual.scale = Vector2(_visual_base_scale.x * stretch, _visual_base_scale.y)

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

func _on_area_entered(area: Area2D) -> void:
	super._on_area_entered(area)
	# 쏜 사람 본인의 Hurtbox는 무시한다. 총구가 캐릭터 안쪽에서 시작하거나 투사체 판정이 크면
	# 발사하자마자 자기 몸에 닿아서 그대로 사라져버린다(토사물 그림을 넣으면서 실제로 겪음)
	if area is Hurtbox and area.fighter != source_fighter:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	# 벽 등 물리 바디에 부딪히면 데미지 없이 사라진다.
	# 쏜 사람 본인의 몸(CharacterBody2D)은 무시 — 안 그러면 느린 투사체가 몸을 빠져나가기 전에
	# 자기 몸에 부딪혀 그대로 사라진다(0스택 토하기처럼 느린 경우 실제로 발생)
	if body == source_fighter:
		return
	_spawn_impact()
	queue_free()

## 벽/바닥에 부딪힌 자리에 작은 충돌 이펙트를 터뜨린다 ("탁!" 하는 느낌)
func _spawn_impact() -> void:
	if impact_effect == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var fx: Node2D = impact_effect.instantiate()
	scene_root.add_child(fx)
	fx.global_position = global_position
