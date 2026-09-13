class_name GroundPoundSkill
extends Skill

## 맵 전용 스킬 — 공중에서 쓰면 그 자리에서 빠르게 내리꽂히다가, 발밑 바닥에 닿는 순간
## 주위에 데미지를 주고 그 발판이 BreakablePlatform이면 부순다. 아파트 맵처럼 Stage.map_skill_scene에
## 이 씬을 지정해두면 스폰되는 두 캐릭터 모두에게 자동으로 붙는다 — 캐릭터 씬은 전혀 안 건드린다.
##
## 조준이 아니라 "떨어지는 그 자리"가 착지점이라, 내리찍는 동안은 DashSkill과 같은 방식(movement_override)으로
## 좌우 이동을 잠근다 — 수직으로만 떨어지는 게 이 스킬의 정체성이다.
##
## 마리오 엉덩이 찍기처럼, 누르는 즉시 떨어지지 않고 잠깐 웅크린 채 허공에 멈췄다가(windup) 내리꽂힌다(falling).
## 허공에 멈추는 동안은 중력도 무시한다 — Fighter.apply_physics는 movement_override가 있어도 중력은
## 그대로 더하므로, after_physics에서 매 프레임 속도를 0으로 눌러서 그 프레임분 중력을 지운다

@export var windup_duration: float = 0.18
@export var slam_speed: float = 1500.0
@export var damage: int = 14
@export var radius: float = 100.0
@export var knockback: Vector2 = Vector2(0, -180)
## 착지 순간부터 판정이 켜져 있는 시간(초) — 너무 짧으면 겹쳐 있어도 못 맞고 지나간다
@export var impact_active_duration: float = 0.15
## 착지 순간 위로 살짝 튕겨서 그대로 멈춰 뻣뻣해 보이지 않게 한다
@export var landing_bounce: float = -120.0

@onready var hitbox: Hitbox = $Hitbox

## "idle"(평소) → "windup"(웅크리고 허공에 정지) → "falling"(내리꽂힘) → 착지하면 다시 "idle"
var _phase: String = "idle"
var _windup_time_left: float = 0.0

## radius export 값을 실제 판정 도형(CircleShape2D)에 반영한다 — 씬의 도형 크기와 export 값을
## 따로 관리하면(AoeAttack이 그렇다) 둘 중 하나만 고치고 잊어버리기 쉬워서, 여기서는 코드가 맞춰준다
func _ready() -> void:
	var collision: CollisionShape2D = hitbox.get_node_or_null("HitboxCollision")
	if collision and collision.shape is CircleShape2D:
		collision.shape.radius = radius

func _execute(fighter: Fighter) -> void:
	if fighter.is_on_floor():
		# 지상에서는 쓸 수 없는 스킬이다 — 쿨타임만 날리지 않게 그대로 돌려준다
		cooldown_left = 0.0
		return
	_phase = "windup"
	_windup_time_left = windup_duration
	fighter.velocity = Vector2.ZERO
	fighter.movement_override = self
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual:
		visual.scale = Vector2(1.2, 0.65)   # 웅크리는 느낌으로 눌러 찌그러뜨림

## 웅크리는 동안도, 내리찍는 동안도 좌우 이동은 불가능하다 — 오직 수직으로만 움직인다
func get_move_velocity_x() -> float:
	return 0.0

## Fighter.apply_physics가 move_and_slide 직후 매 프레임 호출한다
func after_physics(fighter: Fighter, delta: float) -> void:
	if _phase == "windup":
		# 중력이 이미 이번 프레임 속도에 더해진 뒤라, 0으로 눌러서 허공에 멈춘 것처럼 만든다
		fighter.velocity = Vector2.ZERO
		_windup_time_left -= delta
		if _windup_time_left <= 0.0:
			_begin_slam(fighter)
		return
	if _phase != "falling":
		return
	# 매 프레임 속도를 다시 눌러줘서(중력이 더해져도) 항상 최소 slam_speed 이상으로 떨어지게 한다
	fighter.velocity.y = maxf(fighter.velocity.y, slam_speed)
	if fighter.is_on_floor():
		_impact(fighter)

## 웅크림이 끝나고 실제로 내리꽂히기 시작한다
func _begin_slam(fighter: Fighter) -> void:
	_phase = "falling"
	fighter.velocity.y = slam_speed
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual:
		visual.scale = Vector2(0.82, 1.25)   # 내리꽂히는 느낌으로 세로로 늘림

func _impact(fighter: Fighter) -> void:
	_phase = "idle"
	fighter.movement_override = null
	fighter.velocity.y = landing_bounce
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual:
		visual.scale = Vector2.ONE
	hitbox.damage = fighter.compute_damage(damage)
	hitbox.knockback = knockback
	hitbox.source_fighter = fighter
	hitbox.global_position = fighter.global_position
	hitbox.monitoring = true
	hitbox.monitorable = true
	_break_floor_under(fighter)
	await fighter.get_tree().create_timer(impact_active_duration).timeout
	# 착지 판정이 켜져 있는 짧은 시간 동안 라운드가 리로드될 수도 있으니, 그때는 hitbox까지 같이
	# 사라지므로 is_instance_valid로 확인한다
	if is_instance_valid(hitbox):
		hitbox.monitoring = false
		hitbox.monitorable = false

## 착지 지점의 발판이 BreakablePlatform이면 부순다. get_one_way_floor()는 방금 move_and_slide()가
## 남긴 충돌 정보로 "지금 밟은 원웨이 발판"을 그대로 알려주므로, 별도 레이캐스트 없이 바로 알 수 있다.
## break_platform() 메서드가 없는 보통 바닥(진짜 지면)이면 아무 일도 안 일어난다
func _break_floor_under(fighter: Fighter) -> void:
	var platform: PhysicsBody2D = fighter.get_one_way_floor()
	if platform and platform.has_method("break_platform"):
		platform.break_platform()
