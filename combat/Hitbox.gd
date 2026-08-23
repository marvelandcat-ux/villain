class_name Hitbox
extends Area2D

## 공격 판정 — 겹친 Hurtbox에게 데미지를 준다
@export var damage: int = 10
@export var knockback: Vector2 = Vector2.ZERO

## 이 히트박스를 만든 캐릭터. 자기 자신의 Hurtbox는 맞아도 무시된다
var source_fighter: Fighter

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		area.take_hit(damage, knockback, source_fighter)
