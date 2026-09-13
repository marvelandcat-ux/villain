class_name TunaThrowSkill
extends Skill

## 참치캔 투척 — 캔이 손에서 실제로 포물선을 그리며 날아가 떨어진 자리에서 잠시 후 고양이가 튀어나와
## 상대에게 빠르게 돌진해 한 번 할퀴고 사라진다 (고양이 아주머니 스킬1).
## 날아가는 도중 상대 몸에 직접 맞으면 캔이 그대로 몸에 부착된 채(맞은 사람의 Visual의 자식이 되어
## 같이 움직인다) stuck_duration만큼 붙어 있다가 떨어져 사라진다 — 데미지는 없는 순수 연출이다
@export var throw_distance: float = 150.0
## 캔이 손에서 떨어진 자리까지 날아가는 데 걸리는 시간(초) — delay 안에 포함되는 시간이라
## 캔이 뜬 이후 고양이가 나오기까지의 전체 텀(delay)은 그대로다
@export var throw_travel_time: float = 0.3
## 날아가는 동안 포물선으로 얼마나 뜨는지(px). 0이면 직선으로 날아간다
@export var throw_arc_height: float = 40.0
@export var delay: float = 0.8
@export var damage: int = 10
@export var dash_speed: float = 700.0
@export var cat_scene: PackedScene
## 사람 몸에 맞아 부착됐을 때, 이만큼 지나면 캔이 떨어져 사라진다
@export var stuck_duration: float = 3.0
## 부착될 때 맞은 사람의 Visual 기준 붙는 자리(로컬 좌표) — 대략 상체 높이
@export var attach_offset: Vector2 = Vector2(0, -20)
@export var impact_spark: PackedScene = preload("res://combat/HitSpark.tscn")

func _execute(fighter: Fighter) -> void:
	var can_pos: Vector2 = fighter.global_position + Vector2(fighter.facing * throw_distance, 0)
	var can: Polygon2D = _spawn_can(fighter)
	var hit_victim: Fighter = await _throw_can(can, fighter, fighter.global_position, can_pos)
	if not is_instance_valid(fighter):
		if is_instance_valid(can):
			can.queue_free()
		return
	# delay 중 날아가는 데 이미 쓴 시간을 빼고 남은 만큼만 더 기다린다(붙어 있든 바닥에 놓여 있든 동일)
	var remaining: float = maxf(delay - throw_travel_time, 0.0)
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout
	# 사람 몸에 붙은 경우가 아니면(그냥 바닥에 놓인 경우) 여기서 치운다.
	# 몸에 붙은 캔은 stuck_duration 타이머가 알아서 나중에 치운다
	if hit_victim == null and is_instance_valid(can):
		can.queue_free()
	if not is_instance_valid(fighter):
		return
	# 캔이 실제로 멈춘 자리(사람에게 붙었으면 그 사람 위치)를 향해 고양이가 튀어나온다
	var rush_pos: Vector2 = can.global_position if is_instance_valid(can) else can_pos
	_spawn_rush_cat(fighter, rush_pos)

## 참치캔 그림 (전용 아트 없이 도형만)
func _spawn_can(fighter: Fighter) -> Polygon2D:
	var can := Polygon2D.new()
	can.color = Color(0.6, 0.75, 0.9)
	can.polygon = PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)])
	fighter.get_parent().add_child(can)
	can.global_position = fighter.global_position
	return can

## 캔이 던진 사람에게서 착지 지점까지 포물선을 그리며 날아가고, 빙글빙글 도는 회전도 같이 준다.
## 날아가는 도중 상대 Hurtbox에 닿으면 그 자리에서 즉시 멈춰 몸에 부착되고, 맞은 Fighter를 돌려준다.
## 아무도 안 맞고 도착했으면 null을 돌려준다
func _throw_can(can: Polygon2D, thrower: Fighter, from_pos: Vector2, to_pos: Vector2) -> Fighter:
	var hit_zone := _make_hit_zone()
	can.add_child(hit_zone)
	var hit_result: Dictionary = {"victim": null}
	hit_zone.area_entered.connect(func(area: Area2D):
		if hit_result.victim != null:
			return
		if area is Hurtbox and area.fighter != thrower:
			hit_result.victim = area.fighter
	)
	var tween := can.create_tween()
	tween.tween_method(
		func(t: float): can.global_position = from_pos.lerp(to_pos, t) - Vector2(0, sin(t * PI) * throw_arc_height),
		0.0, 1.0, throw_travel_time)
	tween.parallel().tween_property(can, "rotation", TAU * 2.0, throw_travel_time)
	# 튠이 끝나는 것과 "누군가에게 맞는 것" 중 먼저 벌어지는 쪽까지 매 프레임 지켜본다
	while hit_result.victim == null and is_instance_valid(tween) and tween.is_running():
		await can.get_tree().process_frame
	hit_zone.queue_free()
	if hit_result.victim == null or not is_instance_valid(hit_result.victim):
		return null
	if is_instance_valid(tween):
		tween.kill()
	_attach_can_to_fighter(can, hit_result.victim)
	return hit_result.victim

## 캔 주위에 겹침만 검사하는 작은 판정 영역을 만든다 (데미지는 안 준다 — Hitbox가 아니라 순수 Area2D)
func _make_hit_zone() -> Area2D:
	var zone := Area2D.new()
	zone.monitoring = true
	zone.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	zone.add_child(shape)
	return zone

## 캔을 맞은 사람의 Visual 자식으로 옮겨 붙인다 — 그때부터 그 사람이 움직이는 대로 같이 따라다닌다
func _attach_can_to_fighter(can: Polygon2D, victim: Fighter) -> void:
	_spawn_impact_spark(can.global_position)
	var attach_point: Node = victim.get_node_or_null("Visual")
	if attach_point == null:
		attach_point = victim
	can.reparent(attach_point)
	can.position = attach_offset
	can.rotation = 0.0
	_after_stuck_timeout(can)

## 부착 순간 작은 스파크를 한 번 터뜨려 "맞았다"는 걸 눈으로 알려준다 (데미지는 없다)
func _spawn_impact_spark(pos: Vector2) -> void:
	if impact_spark == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var fx: Node2D = impact_spark.instantiate()
	scene_root.add_child(fx)
	fx.global_position = pos

## stuck_duration 뒤 부착된 캔을 치운다. can의 자식 Timer를 쓰는 이유는 CLAUDE.md에 정리된 함정과 같다 —
## 그 전에 라운드가 리로드되어 can이 먼저 사라지면 자식 Timer도 같이 사라져 콜백이 아예 실행되지 않는다
func _after_stuck_timeout(can: Polygon2D) -> void:
	var timer := Timer.new()
	timer.wait_time = stuck_duration
	timer.one_shot = true
	can.add_child(timer)
	timer.timeout.connect(func():
		if is_instance_valid(can):
			can.queue_free()
	)
	timer.start()

func _spawn_rush_cat(fighter: Fighter, from_pos: Vector2) -> void:
	if cat_scene == null:
		return
	var cat: CatPet = cat_scene.instantiate()
	fighter.get_parent().add_child(cat)
	cat.global_position = from_pos
	cat.owner_fighter = fighter
	cat.lifetime = 2.0
	cat.move_speed = dash_speed
	cat.damage = damage
	cat.attack_range = 40.0
