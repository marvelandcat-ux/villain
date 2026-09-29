class_name TaserGunSkill
extends Skill

## 테이저건 — 경찰 스킬1. 총을 꺼내 **전기 침 한 발**을 쏘고, 맞은 상대를 기절시킨다.
##
## 뼈대는 촉법소년의 비비탄(`BBGunSkill`)과 같다 — 총 모션(`play_gun_motion`)을 켜고
## `Projectile`을 하나 날린다. 다른 점은 **한 발만 나가고, 맞으면 기절이 붙는다**는 것.
##
## 기절은 총알이 아니라 이 스킬이 건다 — `Projectile`(=`Hitbox`)이 맞힐 때마다 쏘는
## `connected` 신호를 받아서 처리한다. 총알 쪽에 기절을 넣으면 같은 총알 씬을 쓰는
## 다른 스킬까지 전부 기절을 걸게 된다

## 날릴 총알 씬 (skills/TaserBolt.tscn)
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 900.0
## 총알이 날아가면서 매초 이만큼 빨라진다(px/s²) / 그 상한
@export var projectile_accel: float = 900.0
@export var projectile_max_speed: float = 1500.0
@export var damage: int = 10
## 총알이 나오는 위치(총구) — 캐릭터 원점 기준. x는 바라보는 방향으로 자동 반전, y는 음수가 위
@export var muzzle_offset: Vector2 = Vector2(42, -8)
## **맞은 상대가 굳어 있는 시간(초).** 이 동안 이동·점프·공격·스킬이 전부 막힌다
@export var stun_time: float = 2.0
## 쏘고 나서 총을 든 자세를 유지하는 시간(초)
@export var hold_time: float = 0.35

var _fighter_ref: Fighter
var _direction: float = 1.0
## 총 쏘는 표정으로 바꿔 둔 상태인지 (끝나면 되돌리려고 추적)
var _face_time: float = 0.0

func _process(delta: float) -> void:
	super._process(delta)
	if _face_time <= 0.0:
		return
	_face_time = maxf(_face_time - delta, 0.0)
	if _face_time > 0.0:
		return
	var visual: Node2D = _fighter_ref.get_node_or_null("Visual") if is_instance_valid(_fighter_ref) else null
	if visual and visual.has_method("set_action_face"):
		visual.set_action_face(false)

func _execute(fighter: Fighter) -> void:
	_fighter_ref = fighter
	_direction = fighter.facing
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_gun_motion"):
		visual.play_gun_motion(hold_time)
	if visual and visual.has_method("set_action_face"):
		visual.set_action_face(true)
		_face_time = hold_time
	_fire()

func _fire() -> void:
	if projectile_scene == null or not is_instance_valid(_fighter_ref):
		return
	var projectile: Projectile = projectile_scene.instantiate()
	_fighter_ref.get_parent().add_child(projectile)
	projectile.acceleration = projectile_accel
	projectile.max_speed = projectile_max_speed
	# 총구는 자기 몸(반지름 20)보다 앞이라야 쏘자마자 자기 히트박스에 닿아 사라지지 않는다
	var muzzle_pos: Vector2 = _fighter_ref.global_position + Vector2(muzzle_offset.x * _direction, muzzle_offset.y)
	projectile.global_position = muzzle_pos
	projectile.setup(_direction, projectile_speed, _fighter_ref.compute_damage(damage), _fighter_ref)
	projectile.connected.connect(_on_bolt_connected)
	var visual: Node2D = _fighter_ref.get_node_or_null("Visual")
	if visual and visual.has_method("gun_recoil"):
		visual.gun_recoil()

## 전기 침이 상대에게 꽂혔을 때 — 데미지는 총알이 이미 넣었고, 여기서 기절만 건다
func _on_bolt_connected(victim: Node) -> void:
	if not (victim is Fighter) or not is_instance_valid(victim):
		return
	var target: Fighter = victim as Fighter
	# 막았으면 기절도 없다. 방어가 데미지만 줄이고 기절은 그대로면 막을 이유가 없어진다
	if target.blocks_debuff():
		return
	target.apply_hitstun(stun_time)
	StunStars.spawn(target, stun_time)
