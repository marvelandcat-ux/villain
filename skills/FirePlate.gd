class_name FirePlate
extends Area2D

## 바닥에 깔리는 화상 장판 — 겹쳐있는 상대에게 주기적으로 데미지를 준다. 자기 자신은 무시한다 (지하철빌런 궁극기 "떡볶이"가 재사용)
@export var damage_per_tick: int = 4
@export var tick_interval: float = 1.0
@export var lifetime: float = 6.0

var source_fighter: Fighter
var _tick_timer: float = 0.0

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()
	_start_pulse()

## 이글이글 타오르는 느낌을 주는 반복 펄스
func _start_pulse() -> void:
	var visual: Node2D = get_node_or_null("Visual")
	if visual == null:
		return
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(visual, "scale", Vector2(1.1, 1.1), 0.4)
	tween.tween_property(visual, "scale", Vector2(0.95, 0.95), 0.4)

func _process(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = tick_interval
	for area in get_overlapping_areas():
		if area is Hurtbox:
wd			area.take_hit(damage_per_tick, Vector2.ZERO, source_fighter)
