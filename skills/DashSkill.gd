class_name DashSkill
extends Skill

## 픽시 돌진 — 브레이크 없이 돌진하다가 벽에 부딪히면 자신이 피해를 입는다 (촉법소년 스킬1)
## 돌진 속도 = 캐릭터 기본 이동속도(stats.move_speed)의 이 배수. 2.5면 이동속도 160 기준 400 (걷기보다 확 빠른 픽시 자전거)
@export var dash_speed_multiplier: float = 2.5
@export var dash_duration: float = 0.9
@export var self_damage_on_wall: int = 10  ## 오픈 이슈 임시값
## 벽에 부딪혔을 때 튕겨 나오는 넉백 (돌진 방향의 반대 + 살짝 위로)
@export var wall_bounce: Vector2 = Vector2(150, -80)
## 잔상을 몇 초마다 남길지
@export var trail_interval: float = 0.04
## 뒷바퀴 스키드 먼지를 몇 초마다 튈지
@export var skid_interval: float = 0.05
## 바닥 색을 못 찾았을 때 쓸 기본 먼지색 (바닥과 대비되게 어두운 흙색)
@export var default_dust_color: Color = Color(0.3, 0.26, 0.22, 0.9)
## 뒷바퀴 위치(캐릭터 원점 기준) — x는 진행 반대쪽(뒤)이라 음수, y는 바닥 높이. x는 진행 방향으로 반전된다
@export var rear_wheel_offset: Vector2 = Vector2(-16, 26)
## 돌진하는 동안 몸 주위로 바람 줄이 흐른다 (일진 어깨 들이박기와 같은 연출). 끄면 예전처럼 잔상·먼지만
@export var wind_lines: bool = true

## 적을 들이받으면 적이 입는 데미지
@export var enemy_hit_damage: int = 10
## 적을 들이받으면 촉법소년 자신도 입는 데미지 (자전거는 브레이크가 없다)
@export var enemy_hit_self_damage: int = 10
## 서로 튕겨나가는 넉백 — 적은 진행 방향으로, 자신은 반대로 날아간다.
## 이 값이 넉백의 기준값이다.
## 실제 넉백 = 이 값 × 진행도 배율(min~mid~max) × knockback_scale_ratio. 지금 절반 탔을 때는 0.7배
## 2026-09-10: 2배(660, -360)는 너무 멀리 날아가고 원래 값(330, -180)은 약해서, 중간인 1.5배로 확정.
## 브랜치 머지 때 옛 값(220, -120 / 340, -150)으로 되돌아간 적이 있으니 충돌 나면 이 값을 남길 것
@export var enemy_collision_knockback: Vector2 = Vector2(495, -270)
## 돌진 진행도(0=막 출발 ~ 1=다 탐)에 따라 넉백에 곱하는 배율. 절반(0.5)을 기준으로 두 구간으로 나뉜다:
## 0~0.5는 min -> mid(0배 -> 1배), 0.5~1은 mid -> max(1배 -> 1.5배).
## 2026-09-11: 원래 끝까지 한 직선(0 -> 2배)이었는데 다 타고 박으면 너무 멀리 날아가서,
## 절반 이후의 증가 속도만 반으로 줄였다(max 2.0 -> 1.5). 절반 이전은 그대로다
@export var min_knockback_scale: float = 0.0
@export var mid_knockback_scale: float = 1.0
@export var max_knockback_scale: float = 1.5
## 위 진행도 배율을 얼마만큼만 적용할지. 곡선 모양(min/mid/max)은 그대로 두고 결과에 한 번 더 곱한다.
## 2026-09-11: 1.5배 곡선도 세다고 해서 0.7로 낮췄다 → 실제 배율은 0 / 0.7 / 1.05배(출발·절반·다 탐)
@export var knockback_scale_ratio: float = 0.7
## 적을 들이받았다고 볼 몸 사이 거리(px). 캐릭터끼리 몸 충돌이 꺼져 있어(add_collision_exception_with)
## 물리 충돌 대신 이 거리로 판정한다. 서로 밀어내는 최소 간격(BODY_PUSH_WIDTH=38)보다 살짝 크게 잡아 접촉 순간 잡는다
@export var enemy_hit_range_x: float = 42.0
@export var enemy_hit_range_y: float = 46.0

## 타입을 안 붙이고 preload로 가져온다 — 새 class_name은 전역 클래스 캐시가 갱신되기 전엔
## 못 찾아서 파싱 에러가 난다(ShoulderChargeSkill이 ChargeWind를 가져오는 것과 같은 이유)
const CHARGE_WIND := preload("res://skills/ChargeWind.gd")
var _wind = null

var _time_left: float = 0.0
var _direction: float = 1.0
var _trail_timer: float = 0.0
## 발동 순간 계산해둔 실제 돌진 속도 (캐릭터 이동속도 × 배수)
var _dash_speed: float = 0.0
## 이번 돌진에서 이미 적을 들이받았는지 (한 번만 충돌 처리)
var _hit_enemy: bool = false
## 다음 스키드 먼지까지 남은 시간, 돌진 시작 때 잡아둔 바닥 색
var _skid_timer: float = 0.0
var _ground_color: Color = Color.WHITE

func _execute(fighter: Fighter) -> void:
	_time_left = dash_duration
	_direction = fighter.facing
	_trail_timer = 0.0
	_hit_enemy = false
	_skid_timer = 0.0
	_ground_color = _sample_ground_color(fighter)
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
		# 돌진하는 동안 달리는 표정으로 바꾼다 (그 표정이 있는 캐릭터만)
		if visual.has_method("set_action_face"):
			visual.set_action_face(true)
	_spawn_afterimage(fighter)
	_start_wind(fighter)

## 몸 주위로 흐르는 바람 줄을 띄운다 — **맵에 붙이고 시전자를 따라다니게 한다**
## (캐릭터의 자식으로 달면 좌우 반전에 같이 뒤집혀서 바람이 진행 방향과 반대로 흐른다)
func _start_wind(fighter: Fighter) -> void:
	if not wind_lines:
		return
	var parent: Node = fighter.get_parent()
	if parent == null:
		return
	_wind = CHARGE_WIND.new()
	parent.add_child(_wind)
	_wind.setup(fighter, _direction, dash_duration)

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
	# 뒷바퀴 스키드 먼지 (바닥에 붙어 있을 때만 — 공중에선 마찰이 없다)
	_skid_timer -= delta
	if _skid_timer <= 0.0 and fighter.is_on_floor():
		_skid_timer = skid_interval
		_spawn_skid(fighter)
	# 적 충돌은 벽 충돌보다 먼저 검사한다 — 적도 물리 바디라 부딪히면 is_on_wall이 켜질 수 있어서,
	# 여기서 안 걸러내면 벽 자해 코드가 대신 터진다
	if not _hit_enemy:
		var enemy: Fighter = _get_enemy_in_range(fighter)
		if enemy:
			_hit_enemy = true
			_collide_with_enemy(fighter, enemy)
			_end_dash(fighter)
			return
	if fighter.is_on_wall():
		fighter.take_damage(self_damage_on_wall, Vector2(-_direction * wall_bounce.x, wall_bounce.y))
		# 벽에 박은 자리(자전거 앞)에 터지는 이펙트
		_spawn_burst(fighter, fighter.global_position + Vector2(_direction * 20.0, 0.0))
		_end_dash(fighter)
	elif _time_left <= 0.0:
		_end_dash(fighter)

## 충돌 지점에 터지는 이펙트를 스폰한다
func _spawn_burst(fighter: Fighter, pos: Vector2) -> void:
	var parent: Node = fighter.get_parent()
	if parent == null:
		return
	CrashBurst.spawn(parent, pos)

## 돌진 중 몸 근처(enemy_hit_range 안)에 들어온 상대 Fighter를 찾는다.
## 캐릭터끼리는 몸 충돌(add_collision_exception_with)이 꺼져 있어 get_slide_collision으로는 안 잡히므로 거리로 판정한다.
## 돌진 방향 앞쪽(또는 거의 겹친) 상대만 대상으로 해서, 등지고 출발할 때 뒤에 있는 상대에 헛맞지 않게 한다
func _get_enemy_in_range(fighter: Fighter) -> Fighter:
	return Fighter.find_fighter_in_box(fighter, enemy_hit_range_x, enemy_hit_range_y, _direction)

## 적을 들이받았을 때 — 적은 진행 방향으로, 촉법소년은 반대로 세게 튕겨나가고 둘 다 데미지를 입는다
func _collide_with_enemy(fighter: Fighter, enemy: Fighter) -> void:
	# 오래 달렸을수록(지속시간 진행도) 넉백이 세진다. 절반까지는 min→mid, 그 뒤로는 mid→max로 완만하게 오른다
	var progress: float = clampf((dash_duration - _time_left) / dash_duration, 0.0, 1.0)
	var scale: float
	if progress < 0.5:
		scale = lerpf(min_knockback_scale, mid_knockback_scale, progress / 0.5)
	else:
		scale = lerpf(mid_knockback_scale, max_knockback_scale, (progress - 0.5) / 0.5)
	var kb: Vector2 = enemy_collision_knockback * scale * knockback_scale_ratio
	# 부딪힌 지점(둘 사이 중간)에 터지는 이펙트
	_spawn_burst(fighter, (fighter.global_position + enemy.global_position) * 0.5)
	# 적: 돌진 방향으로 날아감
	enemy.take_damage(enemy_hit_damage, Vector2(kb.x * _direction, kb.y))
	# 촉법소년: 돌진 관성을 먼저 지운다 — 안 그러면 +돌진속도가 뒤로 튕기는 넉백을 상쇄해 거의 안 밀린다
	fighter.velocity = Vector2.ZERO
	# 반대 방향으로 튕겨나가며 자기도 피해 (브레이크 없는 픽시)
	fighter.take_damage(enemy_hit_self_damage, Vector2(-kb.x * _direction, kb.y))

## 밖에서 돌진을 강제로 끊는다 — 주인공이 던진 돌(ThrownStone)에 맞으면 여기로 들어온다.
## 남은 돌진 시간·관성을 버리고 즉시 자전거에서 내린다 (급정거).
## ThrownStone은 `movement_override`에 이 함수가 있는지만 보고 부르므로,
## 다른 이동 가로채기 스킬은 이 함수가 없어서 돌을 맞아도 안 끊긴다
func interrupt(fighter: Fighter) -> void:
	if fighter == null or fighter.movement_override != self:
		return
	_time_left = 0.0
	fighter.velocity.x = 0.0
	_end_dash(fighter)

func _end_dash(fighter: Fighter) -> void:
	fighter.movement_override = null
	# 벽·적에 부딪혀 일찍 끝났을 수도 있다 — 남은 바람 줄은 흩어질 때까지 그리고 스스로 사라진다
	if is_instance_valid(_wind):
		_wind.stop()
	_wind = null
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual:
		# 자전거를 뒤로 빼며 사라지게 한다. 스쿼시를 안 걸었던 캐릭터만 크기를 되돌린다
		if visual.has_method("set_riding"):
			visual.set_riding(false)
		else:
			visual.scale = Vector2(1, 1)
		# 돌진이 끝나면 원래 표정으로
		if visual.has_method("set_action_face"):
			visual.set_action_face(false)

## 돌진 시작 지점 아래로 레이캐스트해 바닥의 색을 가져온다 (바닥 StaticBody의 Polygon2D 색).
## 캐릭터는 제외하고, 못 찾으면(스프라이트 바닥 등) 기본 먼지색을 쓴다
func _sample_ground_color(fighter: Fighter) -> Color:
	var from: Vector2 = fighter.global_position
	var hit: Dictionary = PhysicsQuery.raycast_ignoring_fighters(fighter, from, from + Vector2(0.0, 200.0))
	if hit.is_empty():
		return default_dust_color
	for child in hit.collider.get_children():
		if child is Polygon2D:
			# 바닥 색을 그대로 쓰면 바닥에 묻혀 안 보인다 — 조금 어둡게(스크래치 자국처럼) 해서 대비를 준다
			var c: Color = child.color.darkened(0.35)
			c.a = 0.9
			return c
	return default_dust_color

## 뒷바퀴 위치에 바닥 색 먼지 한 조각을 튀긴다 (진행 반대쪽으로 흩날림)
func _spawn_skid(fighter: Fighter) -> void:
	var parent: Node = fighter.get_parent()
	if parent == null:
		return
	var dust: Node2D = load("res://skills/SkidDust.tscn").instantiate()
	parent.add_child(dust)
	dust.z_index = -1   # 자전거·본체보다 뒤에 (바닥에 붙어 보이게)
	dust.global_position = fighter.global_position + Vector2(rear_wheel_offset.x * _direction, rear_wheel_offset.y)
	dust.setup(_ground_color, _direction)

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
	# 잔상은 본체보다 뒤에 그려져야 한다 — 나중에 add_child되면 기본적으로 앞에 겹치므로 z를 낮춘다.
	# 잔상 내부 손(z_index=1, 상대값)까지 확실히 뒤로 보내려고 -2로 둔다 (본체는 z 0, 손 z 1)
	ghost.z_index = -2
	ghost.global_position = visual.global_position
	ghost.scale = visual.scale
	ghost.modulate.a = 0.45
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)
