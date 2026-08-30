class_name BloodCannonSkill
extends Skill

## 혈사포 — 잠깐 멈춰서 모았다가(차지), 앞으로 길게 뻗는 초록빛 레이저를 쏜다.
## 차지 중에는 초록빛으로 물들어서 상대에게 미리 경고를 준다. 아이작(The Binding of Isaac)의
## "브림스톤" 모티브 (주정뱅이 스킬2)
## 길이는 스킬1(DrunkenRageSkill)을 쓴 횟수(fighter.custom_data["cannon_stacks"])에 비례해서 늘어나고,
## max_beam_length(맵 한쪽 끝에서 반대쪽 끝까지 닿는 정도)에서 멈춘다. 이 스킬을 쓰면 스택은 0으로 초기화된다
@export var damage: int = 22
@export var base_beam_length: float = 480.0
@export var beam_length_per_stack: float = 120.0
@export var max_beam_length: float = 900.0
@export var beam_height: float = 34.0
@export var charge_time: float = 0.35
@export var beam_active_duration: float = 0.15
@export var knockback: Vector2 = Vector2(260, -70)

@onready var hitbox: Hitbox = $Hitbox
@onready var hitbox_collision: CollisionShape2D = $Hitbox/HitboxCollision
@onready var beam_visual: Polygon2D = $Hitbox/BeamVisual

func _execute(fighter: Fighter) -> void:
	fighter.set_tint("blood_cannon_charge", Color(0.55, 0.95, 0.35))
	await get_tree().create_timer(charge_time).timeout
	fighter.clear_tint("blood_cannon_charge")

	var stacks: int = fighter.custom_data.get("cannon_stacks", 0)
	var beam_length: float = minf(base_beam_length + beam_length_per_stack * stacks, max_beam_length)
	fighter.custom_data["cannon_stacks"] = 0

	hitbox.damage = fighter.compute_damage(damage)
	hitbox.knockback = Vector2(knockback.x * fighter.facing, knockback.y)
	hitbox.source_fighter = fighter
	# Hitbox의 부모(BloodCannonSkill)가 Node2D가 아닌 Node라서 global_position으로 직접 배치해야 한다.
	# 캐릭터 앞쪽으로 길게 뻗는 판정이라, 중심을 beam_length의 절반만큼 앞으로 밀어서 배치한다
	hitbox.global_position = fighter.global_position + Vector2(beam_length / 2.0 * fighter.facing, 0)
	# 실제 판정 크기도 스택에 맞게 늘려야 눈에 보이는 빔 길이와 맞는다(안 그러면 겉보기엔 길어도 판정은 그대로인 버그)
	hitbox_collision.shape.size = Vector2(beam_length, beam_height)

	var half_w: float = beam_length / 2.0
	var half_h: float = beam_height / 2.0
	beam_visual.polygon = PackedVector2Array([
		Vector2(-half_w, -half_h), Vector2(half_w, -half_h),
		Vector2(half_w, half_h), Vector2(-half_w, half_h),
	])
	beam_visual.visible = true

	hitbox.monitoring = true
	hitbox.monitorable = true
	await get_tree().create_timer(beam_active_duration).timeout
	hitbox.monitoring = false
	hitbox.monitorable = false
	beam_visual.visible = false
