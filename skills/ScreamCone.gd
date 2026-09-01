class_name ScreamCone
extends Hitbox

## 주정뱅이 궁극기 "괴성"의 부채꼴 판정 + 연출을 한 몸으로 들고 있는 노드.
## Hitbox를 상속해서 부채꼴 안에 들어온 Hurtbox에게 바로 데미지를 준다.
##
## Skill은 Node라서 좌표를 못 가진다(부모 트랜스폼 체인이 끊겨서 히트박스가 항상 (0,0)에 생긴다).
## 그래서 이 노드는 스킬의 자식이 아니라 맵에 직접 붙이고 global_position으로 입 위치에 놓는다.
##
## - 빨간 부채꼴 = 실제 판정 범위. Collision(CollisionPolygon2D)과 완전히 똑같은 도형을 그리므로
##   화면에 보이는 빨간 영역 = 맞는 영역이다.
## - 검은 음파 = wave_texture에 넣은 그림이 입에서 부채꼴 끝까지 퍼져나간다.
##   아직 그림을 안 넣었으면 코드로 그린 검은 호(弧)가 대신 나간다.

## 부채꼴 길이(px)
@export var cone_range: float = 320.0
## 부채꼴 반각(도). 26이면 위아래로 26도씩, 총 52도로 벌어진다
@export var half_angle_deg: float = 26.0
## 판정이 켜져 있는 시간(초)
@export var active_duration: float = 0.35
## 판정이 끝난 뒤 빨간 범위가 사라지는 데 걸리는 시간(초)
@export var fade_duration: float = 0.3
## 맞은 상대가 밀려나는 힘. x는 시전자 정면 방향으로 자동 반전되고, y는 음수가 위쪽
@export var knockback_force: Vector2 = Vector2(280.0, -140.0)
## 빨간 범위를 안쪽까지 칠할지. 끄면 테두리만 남는다 (음파 그림이 잘 보이도록 기본은 꺼둠)
@export var show_range_fill: bool = false
## 범위 안쪽 색(빨강) — show_range_fill이 true일 때만 보인다
@export var range_color: Color = Color(1.0, 0.15, 0.15, 0.22)
## 범위 테두리 색(빨강)
@export var outline_color: Color = Color(1.0, 0.1, 0.1, 0.85)
## 범위 테두리 굵기(px)
@export var outline_width: float = 4.0
## 앞으로 퍼져나가는 음파 그림(검은색). 비워두면 코드로 그린 호가 대신 나간다
@export var wave_texture: Texture2D
## 음파를 몇 겹 내보낼지
@export var wave_count: int = 4
## 음파가 한 겹씩 출발하는 간격(초)
@export var wave_interval: float = 0.07
## 음파 한 겹이 입에서 부채꼴 끝까지 가는 데 걸리는 시간(초)
@export var wave_travel_time: float = 0.4
## 음파가 처음 나올 때의 크기 비율 (0.12면 입 앞 12% 지점에서 작게 시작)
@export var wave_start_scale: float = 0.12
## 부채꼴 호를 몇 조각으로 쪼개서 그릴지 — 클수록 곡선이 매끄럽다
@export var arc_segments: int = 18

var _facing: float = 1.0

## 지르는 방향(1 또는 -1), 최종 데미지, 시전자를 지정하고 판정·연출을 시작한다.
## 맵에 add_child로 붙이고 global_position을 잡은 다음에 호출할 것
func setup(direction: float, cone_damage: int, screamer: Fighter) -> void:
	_facing = signf(direction) if direction != 0.0 else 1.0
	damage = cone_damage
	source_fighter = screamer
	knockback = Vector2(knockback_force.x * _facing, knockback_force.y)
	_build_cone()
	_spawn_waves()
	_run_lifetime()

## 판정용 폴리곤과 빨간 범위 표시를 같은 좌표로 만든다
func _build_cone() -> void:
	var shape: PackedVector2Array = _cone_points()

	var collision: CollisionPolygon2D = $Collision
	collision.polygon = shape

	var fill: Polygon2D = $RangeFill
	fill.visible = show_range_fill
	fill.polygon = shape
	fill.color = range_color

	var outline: Line2D = $RangeOutline
	outline.points = shape
	# 시작점으로 되돌아와야 부채꼴이 닫힌 도형으로 보인다
	outline.add_point(shape[0])
	outline.width = outline_width
	outline.default_color = outline_color

## 입(원점)에서 시작해 반지름 cone_range의 호까지 이어지는 부채꼴 점들
func _cone_points() -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var half: float = deg_to_rad(half_angle_deg)
	for i in range(arc_segments + 1):
		var t: float = float(i) / float(arc_segments)
		var angle: float = lerpf(-half, half, t)
		points.append(Vector2(cos(angle) * cone_range * _facing, sin(angle) * cone_range))
	return points

## 음파 겹들을 만들어 시간차를 두고 퍼져나가게 한다
func _spawn_waves() -> void:
	var waves: Node2D = $Waves
	for i in range(wave_count):
		var wave: Node2D = _make_wave()
		wave.scale = Vector2.ONE * wave_start_scale
		wave.hide()
		waves.add_child(wave)

		# 겹마다 조금씩 늦게 출발한다. 부모 Node2D의 크기를 키우면
		# 안에 있는 호가 앞으로 나가는 동시에 부채꼴처럼 벌어진다
		var delay: float = wave_interval * i
		var tween := create_tween().set_parallel(true)
		tween.tween_callback(wave.show).set_delay(delay)
		tween.tween_property(wave, "scale", Vector2.ONE, wave_travel_time) \
			.set_delay(delay).set_ease(Tween.EASE_OUT)
		tween.tween_property(wave, "modulate:a", 0.0, wave_travel_time) \
			.set_delay(delay).set_ease(Tween.EASE_IN)

## 음파 한 겹 — 스프라이트가 지정돼 있으면 그림, 없으면 코드로 그린 검은 호
func _make_wave() -> Node2D:
	var wave := Node2D.new()
	if wave_texture == null:
		wave.add_child(_make_arc_line())
		return wave

	var sprite := Sprite2D.new()
	sprite.texture = wave_texture
	sprite.position = Vector2(cone_range * _facing, 0.0)
	sprite.flip_h = _facing < 0.0
	# 그림 높이를 부채꼴 입구 높이에 맞춘다 (가로세로 비율은 그대로)
	var opening: float = 2.0 * sin(deg_to_rad(half_angle_deg)) * cone_range
	var texture_height: float = float(wave_texture.get_height())
	if texture_height > 0.0:
		sprite.scale = Vector2.ONE * (opening / texture_height)
	wave.add_child(sprite)
	return wave

## 스프라이트가 아직 없을 때 쓰는 임시 음파 — 부채꼴 끝을 따라 그린 검은 호
func _make_arc_line() -> Line2D:
	var line := Line2D.new()
	line.width = 6.0
	line.default_color = Color(0.05, 0.05, 0.05, 1.0)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var half: float = deg_to_rad(half_angle_deg)
	for i in range(arc_segments + 1):
		var t: float = float(i) / float(arc_segments)
		var angle: float = lerpf(-half, half, t)
		line.add_point(Vector2(cos(angle) * cone_range * _facing, sin(angle) * cone_range))
	return line

## 판정을 켰다가 active_duration 뒤에 끄고, 빨간 범위를 지운 다음, 음파까지 다 날아가면 스스로 사라진다
func _run_lifetime() -> void:
	monitoring = true
	monitorable = true

	var waves_end: float = wave_interval * maxf(wave_count - 1, 0) + wave_travel_time
	var tween := create_tween()
	tween.tween_interval(active_duration)
	tween.tween_callback(_disable_hitbox)
	tween.set_parallel(true)
	tween.tween_property($RangeFill, "modulate:a", 0.0, fade_duration)
	tween.tween_property($RangeOutline, "modulate:a", 0.0, fade_duration)
	tween.set_parallel(false)
	tween.tween_interval(maxf(waves_end - active_duration - fade_duration, 0.0))
	tween.tween_callback(queue_free)

func _disable_hitbox() -> void:
	monitoring = false
	monitorable = false
