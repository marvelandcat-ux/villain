class_name ShoulderChargeSkill
extends Skill

## 어깨 들이박기 — 일진 스킬2(H). 어깨를 앞세워 짧게 돌진하다가 상대에 닿으면
## **둘 다 위로 솟구치고**, 상대만 공중에서 `stun_duration`만큼 굳는다.
##
## 캐릭터끼리는 몸 충돌이 꺼져 있어(`add_collision_exception_with`) 물리 충돌로는 못 잡는다 —
## `DashSkill`과 같이 **몸 사이 거리**로 맞았는지 판정한다.

## 돌진 속도(px/초)와 돌진이 유지되는 시간(초)
@export var charge_speed: float = 560.0
@export var charge_duration: float = 0.4
@export var damage: int = 8
## 부딪힌 순간 **둘 다** 뜨는 속도(px/초). 일진과 상대가 같은 값을 써서 나란히 떠오른다.
## 높이는 속도의 제곱에 비례한다 — 440이면 중력 1150에서 약 84px
@export var launch_speed: float = 440.0
## 뜨면서 앞으로 밀리는 속도 (둘 다 같은 값, 0이면 제자리에서 수직으로만 뜬다)
@export var launch_push: float = 90.0
## 상대가 공중에서 굳어 있는 시간(초)
@export var stun_duration: float = 1.0
## 부딪혔다고 볼 몸 사이 거리(px)
@export var hit_range_x: float = 44.0
@export var hit_range_y: float = 46.0
## 부딪히는 순간 몸이 눌리는 배율 (가로로 퍼지고 세로로 납작)
@export var impact_squash: Vector2 = Vector2(1.2, 0.86)
## 돌진하는 동안 바꿔 낄 얼굴 (일진은 신남일진). 비어 있으면 얼굴을 안 바꾼다
@export var charge_face: Texture2D
## 그 얼굴의 배율 — 기본 머리와 그림 크기가 다르면 잡아준다((0,0)이면 기본 배율)
@export var charge_face_scale: Vector2 = Vector2.ZERO
## 잔상을 몇 초마다 남길지 (0이면 안 남긴다)
@export var trail_interval: float = 0.045

## 타입을 안 붙인다 — 새로 만든 class_name은 전역 클래스 캐시가 갱신되기 전엔 못 찾아서
## 파싱 에러가 난다(Fighter._shield를 무타입으로 둔 것과 같은 이유). preload로 직접 가져온다
const CHARGE_WIND := preload("res://skills/ChargeWind.gd")
var _wind = null

var _time_left: float = 0.0
var _trail_timer: float = 0.0
var _direction: float = 1.0
var _hit: bool = false

func _execute(fighter: Fighter) -> void:
	_time_left = charge_duration
	_direction = signf(fighter.facing)
	if is_zero_approx(_direction):
		_direction = 1.0
	_hit = false
	_trail_timer = 0.0
	# 돌진하는 동안엔 다른 행동을 막는다 (뜬 뒤에는 풀린다)
	fighter.start_busy(charge_duration)
	fighter.movement_override = self
	_set_charge_look(fighter, true)
	# 몸 주위로 바람 줄이 흐른다 — 맵에 붙이고 시전자를 따라다니게 한다
	var parent: Node = fighter.get_parent()
	if parent != null:
		_wind = CHARGE_WIND.new()
		parent.add_child(_wind)
		_wind.setup(fighter, _direction, charge_duration)

## 돌진 자세(두 손 모으고 앞으로 기울기)와 얼굴을 켜고 끈다
func _set_charge_look(fighter: Fighter, on: bool) -> void:
	if not is_instance_valid(fighter):
		return
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual == null:
		return
	if visual.has_method("set_charging"):
		visual.set_charging(on)
	if charge_face != null and visual.has_method("set_action_face"):
		# 리그의 액션 표정 슬롯을 이 스킬 얼굴로 바꿔 끼운다 —
		# 캐릭터가 표정을 여러 개(담배·돌진) 쓰므로 쓰는 쪽이 그때그때 넣어준다
		if on:
			visual.action_head_texture = charge_face
			visual.action_head_scale = charge_face_scale
		visual.set_action_face(on)

## Fighter.apply_physics가 이동 속도를 물어볼 때 — 돌진 중엔 걷기 대신 이 속도로 간다
func get_move_velocity_x() -> float:
	return _direction * charge_speed

## move_and_slide 직후 매 프레임 호출된다
func after_physics(fighter: Fighter, delta: float) -> void:
	_time_left -= delta
	if not _hit:
		var enemy: Fighter = _enemy_in_range(fighter)
		if enemy != null:
			_hit = true
			_slam(fighter, enemy)
			_end(fighter)
			return
	# 잔상 — 몸이 흐르듯 남아 속도감을 준다
	_trail_timer -= delta
	if trail_interval > 0.0 and _trail_timer <= 0.0:
		_trail_timer = trail_interval
		_spawn_afterimage(fighter)
	if _time_left <= 0.0 or fighter.is_on_wall():
		_end(fighter)

## 돌진 방향 앞쪽(또는 거의 겹친) 상대를 찾는다 — 등 뒤에 있는 상대에는 안 맞는다
func _enemy_in_range(fighter: Fighter) -> Fighter:
	for other in fighter.get_tree().get_nodes_in_group("fighters"):
		if other == fighter or not (other is Fighter) or not is_instance_valid(other):
			continue
		var dx: float = other.global_position.x - fighter.global_position.x
		var dy: float = other.global_position.y - fighter.global_position.y
		if absf(dx) > hit_range_x or absf(dy) > hit_range_y:
			continue
		if dx * _direction < -20.0:
			continue
		return other
	return null

## 어깨가 닿은 순간 — 상대는 크게 뜨고 굳고, 자신도 같이 솟구친다
func _slam(fighter: Fighter, enemy: Fighter) -> void:
	# pop_override 0: 넉백에 이미 뜨는 힘이 들어 있으므로 기본 팝업을 얹지 않는다
	enemy.take_damage(fighter.compute_damage(damage), Vector2(launch_push * _direction, -launch_speed), 0.0)
	# 가드로 막혔으면 아예 안 뜨고 굳지도 않는다
	if enemy.is_guarding:
		_squash(fighter)
		return
	enemy.apply_hitstun(stun_duration)
	StunStars.spawn(enemy, stun_duration)
	# **둘의 속도를 똑같이 덮어쓴다** — take_damage는 기존 속도에 더하는 방식이라(velocity.y += )
	# 그냥 두면 상대만 미묘하게 다른 높이로 뜬다. 여기서 같은 값으로 맞춰야 나란히 올라간다
	var launch := Vector2(_direction * launch_push, -launch_speed)
	enemy.velocity = launch
	fighter.velocity = launch
	_squash(fighter)
	_burst(fighter)

## 부딪히는 순간 몸이 한 번 눌린다. **Visual.scale을 직접 건드리면 안 된다** —
## 좌우 반전이 scale.x 부호라 캐릭터가 오른쪽으로 뒤집힌다. play_squash가 부호를 지켜준다
func _squash(fighter: Fighter) -> void:
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual and visual.has_method("play_squash"):
		visual.play_squash(impact_squash)

## 부딪힌 자리에 터지는 이펙트 (자전거 돌진이 벽에 박을 때 쓰는 것과 같은 것)
func _burst(fighter: Fighter) -> void:
	var parent: Node = fighter.get_parent()
	if parent == null:
		return
	var burst := CrashBurst.new()
	parent.add_child(burst)
	burst.global_position = fighter.global_position + Vector2(_direction * 22.0, -6.0)

## 돌진을 끝내고 이동 권한·자세·얼굴을 되돌린다
func _end(fighter: Fighter) -> void:
	# 돌진이 끝나면 남은 행동 잠금을 바로 푼다 — 받아 올린 직후 평타로 이어갈 수 있게 한 것
	fighter.end_busy()
	if fighter.movement_override == self:
		fighter.movement_override = null
	_set_charge_look(fighter, false)
	if is_instance_valid(_wind):
		_wind.stop()
	_wind = null

## 돌진 중 몸을 복제해 뒤에 남긴다 (자전거 돌진과 같은 방식 — 복제본의 스크립트를 떼는 게 핵심)
func _spawn_afterimage(fighter: Fighter) -> void:
	var visual: Node2D = fighter.get_node_or_null("Visual")
	var parent: Node = fighter.get_parent()
	if visual == null or parent == null:
		return
	var ghost := visual.duplicate() as Node2D
	if ghost == null:
		return
	ghost.set_script(null)
	parent.add_child(ghost)
	ghost.z_index = -2
	ghost.global_position = visual.global_position
	ghost.scale = visual.scale
	ghost.modulate = Color(0.85, 0.9, 1.0, 0.4)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)
