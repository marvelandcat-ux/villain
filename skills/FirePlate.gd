class_name FirePlate
extends Area2D

## 바닥에 깔리는 화상 장판 — 겹쳐있는 상대에게 주기적으로 데미지를 준다. 자기 자신은 무시한다 (지하철 아저씨 궁극기 "떡볶이"가 재사용)
@export var damage_per_tick: int = 4
@export var tick_interval: float = 1.0
@export var lifetime: float = 6.0

## 이 장판을 깐 캐릭터. 자기 자신은 안 맞는다.
## **주인이 "있었는지"를 `_has_source`로 따로 기억한다** — 해제된 객체는 `== null`이 true라서
## 처음부터 주인이 없는 장판(맵 기믹)과 구분이 안 된다(`Hitbox`와 같은 방식)
var source_fighter: Fighter:
	get:
		return _source_fighter
	set(value):
		_source_fighter = value
		_has_source = value != null

var _source_fighter: Fighter = null
var _has_source: bool = false
var _tick_timer: float = 0.0

func _ready() -> void:
	Timers.self_destruct(self, lifetime)
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
	# ⚠️ 주인이 장판보다 먼저 사라지는 경우가 있다 — 라운드가 끝나거나 훈련장에서 캐릭터를 바꾸면
	# Fighter만 해제되고 맵에 붙어 있는 이 장판은 lifetime까지 남는다. 그 상태로 계속 때리면
	# **해제된 객체를 `take_hit(..., source_fighter: Fighter)`에 넘겨 타입 에러**가 난다
	# ("argument 3 (previously freed) is not a subclass..."). 주인 없는 국물은 남겨둘 이유가 없으니 치운다
	if _has_source and not is_instance_valid(_source_fighter):
		queue_free()
		return
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = tick_interval
	for area in get_overlapping_areas():
		if area is Hurtbox:
			area.take_hit(damage_per_tick, Vector2.ZERO, source_fighter)
