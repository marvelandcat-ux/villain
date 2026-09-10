class_name LivingShadowSkill
extends Skill

## 살아있는 그림자 — 롤 제드의 W(살아있는 그림자)에서 착안. 앞으로 그림자를 던져두고,
## 그림자가 남아있는 동안 다시 쓰면 그 자리와 위치를 맞바꾼다(순간이동).
## 넉백시킨 상대 쪽으로 미리 그림자를 던져두면 순간이동으로 따라붙어 콤보를 이어갈 수 있다
## (주인공 스킬1). 실제 제드처럼 그림자가 스킬을 대신 써주는 것까지는 구현하지 않음(오픈 이슈)
@export var throw_distance: float = 150.0
## 이 시간 안에 맞바꾸지 않으면 그림자가 그냥 사라진다
@export var shadow_duration: float = 4.0

## 지금 나가 있는 그림자 (없으면 null)
var _shadow: Node2D = null
## 그림자 안에 든 본체 복제본(BodyRig) — 기본공격을 따라할 때 이 노드의 play_attack_swing()을 부른다
var _shadow_visual: Node2D = null
## 그림자를 던진 본체 — basic_attack_used를 듣고 있는 동안 끊을 때 필요해서 따로 들고 있는다
var _fighter_ref: Fighter = null

## 그림자가 나가 있는 동안은 쿨타임이 남아 있어도 다시 쓸 수 있다 —
## 맞바꾸기는 새로 스킬을 쓰는 게 아니라 던져둔 그림자를 회수하는 후속 동작이라서.
## (HUD 쿨타임 슬롯은 지금 이 상태를 따로 표시하지 않아서, 맞바꿀 수 있는데도 계속 도는 것처럼
## 보일 수 있음 — 오픈 이슈)
func can_use() -> bool:
	return (_shadow != null and is_instance_valid(_shadow)) or super.can_use()

func use(fighter: Fighter) -> void:
	if _shadow != null and is_instance_valid(_shadow):
		_swap(fighter)
		return
	if not super.can_use():
		return
	cooldown_left = cooldown
	if lock_duration > 0.0 and fighter:
		fighter.start_busy(lock_duration)
	_throw_shadow(fighter)

func _throw_shadow(fighter: Fighter) -> void:
	var parent: Node = fighter.get_parent()
	if parent == null:
		return
	var shadow := LivingShadow.new()
	shadow.name = "LivingShadow"
	var shadow_collision := CollisionShape2D.new()
	var shadow_shape := CapsuleShape2D.new()
	shadow_shape.radius = 20.0
	shadow_shape.height = 60.0
	shadow_collision.shape = shadow_shape
	shadow.add_child(shadow_collision)
	# 전용 그림자 그림 없이, 본체 Visual(BodyRig)을 복제해 파르스름한 반투명 실루엣으로 재사용한다.
	# DashSkill의 돌진 잔상과 달리 스크립트를 떼지 않는다 — 기본공격을 따라할 때 이 복제본의
	# play_attack_swing()을 그대로 불러서 팔 스윙 모션까지 흉내 내야 하기 때문(부모가 Fighter가
	# 아니라서 걷기·숨쉬기는 그냥 서 있는 자세로만 재생되고, 스윙은 내부 타이머라 그와 무관하게 동작한다)
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual:
		var ghost: Node2D = visual.duplicate()
		if ghost:
			ghost.modulate = Color(0.4, 0.55, 1.0, 0.55)
			shadow.add_child(ghost)
			ghost.position = Vector2.ZERO   # Visual은 보통 Fighter 원점에 있으니 그림자 원점에도 그대로 맞춘다
			_shadow_visual = ghost
	parent.add_child(shadow)
	shadow.global_position = fighter.global_position + Vector2(fighter.facing * throw_distance, 0)
	_shadow = shadow
	_fighter_ref = fighter
	if not fighter.basic_attack_used.is_connected(_on_basic_attack_used):
		fighter.basic_attack_used.connect(_on_basic_attack_used)
	# get_tree().create_timer()가 아니라 그림자의 자식 Timer로 만든다 — 대전 도중 나가기 등으로
	# 그림자가 먼저 사라지면 콜백째로 같이 정리되게 하려고(프로젝트 공용 관례, Fighter._after 참고)
	var timer := Timer.new()
	timer.wait_time = shadow_duration
	timer.one_shot = true
	shadow.add_child(timer)
	timer.timeout.connect(func():
		_shadow = null
		_shadow_visual = null
		_disconnect_mirror()
		shadow.queue_free()
	)
	timer.start()

## 그림자 자리로 순간이동하고 그림자는 회수한다 — 쿨타임은 건드리지 않는다(이미 던질 때 소모됨)
func _swap(fighter: Fighter) -> void:
	var shadow_pos: Vector2 = _shadow.global_position
	_shadow.queue_free()
	_shadow = null
	_shadow_visual = null
	_disconnect_mirror()
	fighter.global_position = shadow_pos
	fighter.velocity = Vector2.ZERO

func _disconnect_mirror() -> void:
	if _fighter_ref and is_instance_valid(_fighter_ref) and _fighter_ref.basic_attack_used.is_connected(_on_basic_attack_used):
		_fighter_ref.basic_attack_used.disconnect(_on_basic_attack_used)

## 본체가 기본공격을 낸 순간 알림을 받는다 — 그림자가 아직 살아있으면 스윙 모션과 판정을 그림자 자리에서도 낸다
func _on_basic_attack_used() -> void:
	if _shadow == null or not is_instance_valid(_shadow):
		return
	if _shadow_visual and is_instance_valid(_shadow_visual):
		if _fighter_ref and is_instance_valid(_fighter_ref):
			_shadow_visual.scale.x = absf(_shadow_visual.scale.x) * signf(_fighter_ref.facing)
		if _shadow_visual.has_method("play_attack_swing"):
			_shadow_visual.play_attack_swing()
	_mirror_basic_attack()

## 본체의 기본공격(MeleeAttack) 히트박스를 그대로 복제해 그림자 자리에서 한 번 더 낸다.
## 스윙 모션은 _on_basic_attack_used에서 이미(즉시) 재생시켰고, 여기서는 예비동작(windup)만
## 본체와 맞춰서 데미지가 나가는 타이밍을 맞춘다
func _mirror_basic_attack() -> void:
	var fighter: Fighter = _fighter_ref
	if fighter == null or not is_instance_valid(fighter):
		return
	if not (fighter.basic_attack is MeleeAttack):
		return
	var melee: MeleeAttack = fighter.basic_attack
	var facing: float = fighter.facing
	if melee.windup > 0.0:
		await get_tree().create_timer(melee.windup).timeout
	# windup 대기 중에 그림자가 맞바꿔지거나(순간이동) 시간이 다 돼서 사라졌을 수 있다 —
	# 그 경우 흉내 낼 자리가 없으니 조용히 넘어간다
	if not is_instance_valid(fighter) or _shadow == null or not is_instance_valid(_shadow):
		return
	var shadow_pos: Vector2 = _shadow.global_position
	var parent: Node = fighter.get_parent()
	if parent == null:
		return
	var mirror_hitbox: Hitbox = melee.hitbox.duplicate()
	parent.add_child(mirror_hitbox)
	mirror_hitbox.damage = fighter.compute_damage(melee.damage)
	mirror_hitbox.knockback = Vector2(melee.knockback.x * facing, melee.knockback.y)
	mirror_hitbox.source_fighter = fighter
	mirror_hitbox.global_position = shadow_pos + Vector2(melee.range * facing, 0)
	mirror_hitbox.monitoring = true
	mirror_hitbox.monitorable = true
	await get_tree().create_timer(melee.active_duration).timeout
	if is_instance_valid(mirror_hitbox):
		mirror_hitbox.queue_free()
