class_name BBGunSkill
extends Skill

## BB탄 쏘기 — 3발 연사 (잼민이 스킬2)
@export var projectile_scene: PackedScene
@export var shot_count: int = 3
@export var shot_interval: float = 0.12
@export var projectile_speed: float = 500.0
@export var damage: int = 6  ## 오픈 이슈 임시값

var _shots_left: int = 0
var _shot_timer: float = 0.0
var _direction: float = 1.0
var _fighter_ref: Fighter

func _process(delta: float) -> void:
	super._process(delta)
	if _shots_left <= 0:
		return
	_shot_timer -= delta
	if _shot_timer <= 0.0:
		_fire_one()
		_shots_left -= 1
		_shot_timer = shot_interval

func can_use() -> bool:
	return super.can_use() and _shots_left <= 0

func _execute(fighter: Fighter) -> void:
	_fighter_ref = fighter
	_direction = fighter.facing
	_shots_left = shot_count
	_shot_timer = 0.0

func _fire_one() -> void:
	if projectile_scene == null or _fighter_ref == null:
		return
	var projectile: Projectile = projectile_scene.instantiate()
	_fighter_ref.get_parent().add_child(projectile)
	# 자기 자신과 겹쳐서 즉시 사라지지 않도록 캐릭터 앞쪽으로 살짝 띄워서 스폰
	projectile.global_position = _fighter_ref.global_position + Vector2(_direction * 30.0, 0.0)
	projectile.setup(_direction, projectile_speed, _fighter_ref.compute_damage(damage), _fighter_ref)
