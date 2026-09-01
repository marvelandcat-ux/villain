class_name Hitbox
extends Area2D

## 공격 판정 — 겹친 Hurtbox에게 데미지를 주고, 실제로 맞았으면 히트 이펙트를 띄운다
@export var damage: int = 10
@export var knockback: Vector2 = Vector2.ZERO
## true면 knockback을 그대로 쓰지 않고, 맞는 순간 "공격자 쪽으로" 방향을 계산해서 끌어당긴다 (청소기 흡입 등)
@export var pull_to_source: bool = false
@export var pull_strength: float = 250.0

## 이 히트박스를 만든 캐릭터. 자기 자신의 Hurtbox는 맞아도 무시된다.
## 맵 기믹(지나가는 열차 등)처럼 주인이 없는 히트박스는 null로 둔다
var source_fighter: Fighter:
	get:
		return _source_fighter
	set(value):
		_source_fighter = value
		_has_source = value != null

var _source_fighter: Fighter = null
## 주인이 "있었는지" 기억해둔다. 해제된 객체는 `== null`이 true라서 이걸로만 null과 구분할 수 있다
var _has_source: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	# 공격자가 판정보다 먼저 사라졌으면(훈련장에서 캐릭터를 바꾸면 옛 Fighter만 해제되고, 맵에 붙어있는
	# 기둥·투사체는 남는다) 해제된 객체를 take_hit에 넘기게 되어 타입 에러가 난다 — 그냥 무시한다.
	# 주인이 원래 없는 히트박스(지하철 열차 등)는 계속 정상 동작해야 하므로 _has_source로 구분한다
	if _has_source and not is_instance_valid(_source_fighter):
		return
	if area is Hurtbox and area.take_hit(damage, _compute_knockback(area), source_fighter):
		_spawn_spark(area.global_position)

func _compute_knockback(hurtbox: Hurtbox) -> Vector2:
	if not pull_to_source or source_fighter == null:
		return knockback
	var to_source: Vector2 = source_fighter.global_position - hurtbox.global_position
	if to_source.length() < 1.0:
		return Vector2.ZERO
	return to_source.normalized() * pull_strength

func _spawn_spark(pos: Vector2) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var spark: Node2D = load("res://combat/HitSpark.tscn").instantiate()
	scene_root.add_child(spark)
	spark.global_position = pos
