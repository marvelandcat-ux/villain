class_name Hitbox
extends Area2D

## 공격 판정 — 겹친 Hurtbox에게 데미지를 주고, 실제로 맞았으면 히트 이펙트를 띄운다
@export var damage: int = 10
@export var knockback: Vector2 = Vector2.ZERO
## true면 knockback을 그대로 쓰지 않고, 맞는 순간 "공격자 쪽으로" 방향을 계산해서 끌어당긴다 (청소기 흡입 등)
@export var pull_to_source: bool = false
@export var pull_strength: float = 250.0

## 이 히트박스를 만든 캐릭터. 자기 자신의 Hurtbox는 맞아도 무시된다
var source_fighter: Fighter

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
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
