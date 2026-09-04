class_name DashSkill
extends Skill

## 픽시 돌진 — 브레이크 없이 돌진하다가 벽에 부딪히면 자신이 피해를 입는다 (촉법소년 스킬1)
## 돌진 속도 = 캐릭터 기본 이동속도(stats.move_speed)의 이 배수. 1.41이면 이동속도 160 기준 약 226 (걷기보다 확실히 빠른 자전거)
@export var dash_speed_multiplier: float = 1.41
@export var dash_duration: float = 0.9
@export var self_damage_on_wall: int = 10  ## 오픈 이슈 임시값
## 벽에 부딪혔을 때 튕겨 나오는 넉백 (돌진 방향의 반대 + 살짝 위로)
@export var wall_bounce: Vector2 = Vector2(150, -80)
## 잔상을 몇 초마다 남길지
@export var trail_interval: float = 0.04

var _time_left: float = 0.0
var _direction: float = 1.0
var _trail_timer: float = 0.0
## 발동 순간 계산해둔 실제 돌진 속도 (캐릭터 이동속도 × 배수)
var _dash_speed: float = 0.0

func _execute(fighter: Fighter) -> void:
	_time_left = dash_duration
	_direction = fighter.facing
	_trail_timer = 0.0
	_dash_speed = fighter.stats.move_speed * dash_speed_multiplier
	fighter.movement_override = self
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual:
		# 자전거 타는 캐릭터(촉법소년)는 몸을 안 찌그러뜨린다 — 스피드감은 자전거가 담당.
		# 그 외 캐릭터는 예전처럼 가로로 늘려 돌진감을 준다
		if visual.has_method("set_riding"):
			visual.set_riding(true)
		else:
			visual.scale = Vector2(1.35, 0.8)
	_spawn_afterimage(fighter)

## 돌진 중 매 물리 프레임 적용할 수평 속도 (Fighter.apply_physics에서 호출)
func get_move_velocity_x() -> float:
	return _direction * _dash_speed

## Fighter.apply_physics가 move_and_slide 직후 매 프레임 호출한다
func after_physics(fighter: Fighter, delta: float) -> void:
	_time_left -= delta
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = trail_interval
		_spawn_afterimage(fighter)
	if fighter.is_on_wall():
		fighter.take_damage(self_damage_on_wall, Vector2(-_direction * wall_bounce.x, wall_bounce.y))
		_end_dash(fighter)
	elif _time_left <= 0.0:
		_end_dash(fighter)

func _end_dash(fighter: Fighter) -> void:
	fighter.movement_override = null
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual:
		# 자전거를 뒤로 빼며 사라지게 한다. 스쿼시를 안 걸었던 캐릭터만 크기를 되돌린다
		if visual.has_method("set_riding"):
			visual.set_riding(false)
		else:
			visual.scale = Vector2(1, 1)

## 돌진하는 잔상(반투명 복제)을 하나 남기고 서서히 지운다.
## Visual이 임시 사각형(Polygon2D)이든 스프라이트 몸(BodyRig 등 Node2D)이든 상관없이 그대로 복제해서 쓴다
func _spawn_afterimage(fighter: Fighter) -> void:
	var visual: Node2D = fighter.get_node_or_null("Visual")
	var parent: Node = fighter.get_parent()
	if visual == null or parent == null:
		return
	var ghost := visual.duplicate() as Node2D
	if ghost == null:
		return
	# 잔상은 복제한 그 순간의 모습으로 고정한다 — 스크립트(BodyRig의 매 프레임 자세 계산)가 돌지 않게 뗀다
	ghost.set_script(null)
	parent.add_child(ghost)
	ghost.global_position = visual.global_position
	ghost.scale = visual.scale
	ghost.modulate.a = 0.45
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)
