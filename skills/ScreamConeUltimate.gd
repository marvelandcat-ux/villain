class_name ScreamConeUltimate
extends Skill

## 괴성 — 주정뱅이 궁극기(R). 컷인에서 참았다가, 바라보는 방향으로 부채꼴 범위에 술 냄새 섞인 고함을 지른다.
## 부채꼴 안에 있던 상대는 데미지를 받고 뒤로 밀려나며, 한동안 점프력이 떨어진다(다리 풀리는 느낌).
##
## 실제 판정과 그림은 ScreamCone.tscn이 전부 들고 있다 — 이 스킬은 시전자의 입 위치·방향·데미지만 정해서 띄운다.
## Skill은 Node라 좌표가 없으므로 부채꼴은 스킬의 자식이 아니라 맵에 붙인다
@export var cone_scene: PackedScene
@export var damage: int = 18
## 캐릭터 원점에서 입까지의 거리 — x는 바라보는 방향으로 자동 반전되고, y는 음수가 위쪽
@export var mouth_offset: Vector2 = Vector2(18.0, -24.0)
## 맞은 상대의 점프력 배수 (0.6이면 점프가 60%로 줄어든다)
@export var jump_multiplier: float = 0.6
## 점프력 디버프가 유지되는 시간(초)
@export var debuff_duration: float = 8.0

func _execute(fighter: Fighter) -> void:
	_play_shout_motion(fighter)
	if cone_scene == null:
		return

	# 부채꼴 길이·각도·연출은 전부 ScreamCone.tscn이 들고 있다 — 여기서 덮어쓰지 않는다.
	# (예전엔 여기에도 같은 값이 있어서, ScreamCone.tscn에서 아무리 고쳐도 안 먹는 함정이 있었음)
	var cone: ScreamCone = cone_scene.instantiate()
	fighter.get_parent().add_child(cone)
	cone.global_position = fighter.global_position + Vector2(mouth_offset.x * fighter.facing, mouth_offset.y)
	cone.area_entered.connect(_on_cone_hit.bind(fighter))
	cone.setup(fighter.facing, fighter.compute_damage(damage), fighter)

## 지르는 순간 스스로 부르르 떤다
func _play_shout_motion(fighter: Fighter) -> void:
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual == null:
		return
	var tween := fighter.create_tween()
	tween.set_loops(4)
	tween.tween_property(visual, "scale", Vector2(1.15, 0.9), 0.06)
	tween.tween_property(visual, "scale", Vector2(1, 1), 0.06)

## 데미지·넉백은 Hitbox가 알아서 주고, 여기서는 점프력 디버프만 얹는다
func _on_cone_hit(area: Area2D, screamer: Fighter) -> void:
	if not (area is Hurtbox) or area.fighter == screamer:
		return
	area.fighter.apply_temp_multiplier("jump_multiplier", jump_multiplier, debuff_duration)
	# 다리 풀린 느낌으로 보라색으로 물듦
	area.fighter.set_tint("jump_debuff", Color(0.75, 0.6, 0.85), debuff_duration)
