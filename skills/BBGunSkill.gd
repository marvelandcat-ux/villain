class_name BBGunSkill
extends Skill

## 비비탄 쏘기 — 3발 연사 (촉법소년 스킬2)
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
## 주머니에서 총을 꺼내 겨누기까지 걸리는 시간(초) — 이게 지나야 첫 발이 나간다(2026-09-29 사용자 요청 "주머니에서 바로 꺼내는 느낌").
## 길수록 꺼내는 게 잘 보이지만 스킬이 굼떠진다
@export var draw_time: float = 0.2
## 다 쏜 뒤 총을 다시 주머니에 넣는 시간(초, 2026-09-29 사용자 요청). 0이면 넣는 동작 없이 사라진다
@export var holster_time: float = 0.25

var _shots_left: int = 0
var _shot_timer: float = 0.0
var _direction: float = 1.0
var _fighter_ref: Fighter
## 지금 총 쏘는 표정 상태인지 (연사 끝나면 원래 표정으로 되돌리려고 추적)
var _face_active: bool = false

func _process(delta: float) -> void:
	super._process(delta)
	if _shots_left <= 0:
		# 연사가 끝나면 원래 표정으로 되돌린다
		if _face_active:
			_face_active = false
			var v: Node2D = _fighter_ref.get_node_or_null("Visual") if _fighter_ref else null
			if v and v.has_method("set_action_face"):
				v.set_action_face(false)
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
	# 총을 다 꺼내 겨눈 뒤에 첫 발
	_shot_timer = maxf(draw_time, 0.0)
	# 주머니에서 총을 꺼내 두 손 모아 겨누고, 마지막 발 뒤 잠깐 겨눈 채 있다가, 다시 주머니에 넣는 모션
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_gun_motion"):
		var holster: float = maxf(holster_time, 0.0)
		visual.play_gun_motion(draw_time + shot_count * shot_interval + 0.15 + holster, draw_time, holster)
	# 총 쏘는 동안 달리는 표정으로 바꾼다 (연사가 끝나면 _process에서 되돌린다)
	if visual and visual.has_method("set_action_face"):
		visual.set_action_face(true)
		_face_active = true

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
