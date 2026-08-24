class_name Hitbox
extends Area2D

## 공격 판정 — 겹친 Hurtbox에게 데미지를 주고, 실제로 맞았으면 히트 이펙트를 띄운다
@export var damage: int = 10
@export var knockback: Vector2 = Vector2.ZERO

## 이 히트박스를 만든 캐릭터. 자기 자신의 Hurtbox는 맞아도 무시된다
var source_fighter: Fighter

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox and area.take_hit(damage, knockback, source_fighter):
		_spawn_spark(area.global_position)

func _spawn_spark(pos: Vector2) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var spark: Node2D = load("res://combat/HitSpark.tscn").instantiate()
	scene_root.add_child(spark)
	spark.global_position = pos
