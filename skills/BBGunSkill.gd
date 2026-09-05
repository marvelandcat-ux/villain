class_name BBGunSkill
extends Skill

## BB탄 쏘기 — 3발 연사 (촉법소년 스킬2)
@export var projectile_scene: PackedScene
@export var shot_count: int = 3
@export var shot_interval: float = 0.12
@export var projectile_speed: float = 650.0
## 총알이 날아가면서 매초 이만큼 빨라진다(px/s²)
@export var projectile_accel: float = 1200.0
## 가속으로 붙는 속도의 상한(px/s)
@export var projectile_max_speed: float = 1400.0
@export var damage: int = 6  ## 오픈 이슈 임시값
## 총알이 나오는 위치(총구) — 캐릭터 원점 기준. x는 앞으로 나가는 거리(바라보는 방향으로 자동 반전), y는 높이(음수가 위)
@export var muzzle_offset: Vector2 = Vector2(42, -8)

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
	# 몸에서 총을 꺼내 두 손 모아 겨누는 모션 — 마지막 발 뒤에도 잠깐 겨눈 채 있도록 여유를 준다
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_gun_motion"):
		visual.play_gun_motion(shot_count * shot_interval + 0.15)

func _fire_one() -> void:
	if projectile_scene == null or _fighter_ref == null:
		return
	var projectile: Projectile = projectile_scene.instantiate()
	_fighter_ref.get_parent().add_child(projectile)
	projectile.acceleration = projectile_accel
	projectile.max_speed = projectile_max_speed
	# 총구 위치에서 스폰 — muzzle_offset.x는 바라보는 방향으로 반전. 자기 몸(반지름 20)보다 앞이라 즉시 사라지지 않는다
	var muzzle_pos: Vector2 = _fighter_ref.global_position + Vector2(muzzle_offset.x * _direction, muzzle_offset.y)
	projectile.global_position = muzzle_pos
	projectile.setup(_direction, projectile_speed, _fighter_ref.compute_damage(damage), _fighter_ref)
	_spawn_muzzle_flash(muzzle_pos)
	# 발사 반동 — 총·손이 뒤로 살짝 밀린다
	var visual: Node2D = _fighter_ref.get_node_or_null("Visual")
	if visual and visual.has_method("gun_recoil"):
		visual.gun_recoil()

## 발사 순간 총구에 잠깐 반짝이는 이펙트
func _spawn_muzzle_flash(pos: Vector2) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var flash: Node2D = load("res://combat/HitSpark.tscn").instantiate()
	scene_root.add_child(flash)
	flash.global_position = pos
	flash.scale = Vector2(0.6, 0.6)
