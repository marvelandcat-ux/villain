class_name Hitbox
extends Area2D

## 공격 판정 — 겹친 Hurtbox에게 데미지를 주고, 실제로 맞았으면 히트 이펙트를 띄운다
@export var damage: int = 10
@export var knockback: Vector2 = Vector2.ZERO
## true면 knockback을 그대로 쓰지 않고, 맞는 순간 "공격자 쪽으로" 방향을 계산해서 끌어당긴다 (청소기 흡입 등)
@export var pull_to_source: bool = false
@export var pull_strength: float = 250.0
<<<<<<< HEAD
## 명중 순간 게임 전체를 멈추는 시간(초, hit-stop). 0이면 안 멈춘다. 센 공격일수록 크게 주면 묵직해진다
@export var hitstop_duration: float = 0.06
=======
## 0보다 크면 겹쳐 있는 동안 이 간격(초)마다 계속 다시 때린다 (지나가는 열차에 계속 밀리는 연출).
## 0이면 예전처럼 처음 겹친 순간에 딱 한 번만 때린다 — 스킬 히트박스는 전부 0을 쓴다
@export var repeat_interval: float = 0.0
>>>>>>> 4431582d1dec5efeb00ec5aa1ae1c3a7afc42ed4

## 이 히트박스를 만든 캐릭터. 자기 자신의 Hurtbox는 맞아도 무시된다.
## 맵 기믹(지나가는 열차 등)처럼 주인이 없는 히트박스는 null로 둔다
var source_fighter: Fighter:
	get:
		return _source_fighter
	set(value):
		_source_fighter = value
		_has_source = value != null

var _source_fighter: Fighter = null
## 주인이 "있었는지" 기억해둔다. 해제된 객체는 `== null`이 true라서 이걸로만 null과 구분할 수 있다
var _has_source: bool = false
## repeat_interval을 쓸 때, 겹쳐 있는 Hurtbox마다 다음 타격까지 남은 시간 {Hurtbox: float}
var _repeat_cooldowns: Dictionary = {}

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if _try_hit(area):
		# 방금 때렸으니 반복 타격은 repeat_interval 뒤부터 (겹친 프레임에 두 번 맞지 않게)
		_repeat_cooldowns[area] = repeat_interval

func _on_area_exited(area: Area2D) -> void:
	_repeat_cooldowns.erase(area)

## repeat_interval이 켜져 있으면, 겹쳐 있는 동안 그 간격마다 계속 다시 때린다.
## HazardPlatform과 같은 방식(대상별 쿨타임)이라 매 프레임 연속으로 맞지는 않는다
func _process(delta: float) -> void:
	if repeat_interval <= 0.0 or not monitoring:
		return
	for area in get_overlapping_areas():
		var left: float = _repeat_cooldowns.get(area, 0.0) - delta
		if left <= 0.0:
			if not _try_hit(area):
				continue
			left = repeat_interval
		_repeat_cooldowns[area] = left

## 실제 타격 한 번. 맞았으면 true
func _try_hit(area: Area2D) -> bool:
	# 공격자가 판정보다 먼저 사라졌으면(훈련장에서 캐릭터를 바꾸면 옛 Fighter만 해제되고, 맵에 붙어있는
	# 기둥·투사체는 남는다) 해제된 객체를 take_hit에 넘기게 되어 타입 에러가 난다 — 그냥 무시한다.
	# 주인이 원래 없는 히트박스(지하철 열차 등)는 계속 정상 동작해야 하므로 _has_source로 구분한다
	if _has_source and not is_instance_valid(_source_fighter):
<<<<<<< HEAD
		return
	if area is Hurtbox and area.take_hit(damage, _compute_knockback(area), source_fighter):
		_spawn_spark(area.global_position)
		# 맞은 순간 아주 잠깐 시간을 멈춰 타격감을 준다
		if hitstop_duration > 0.0:
			HitStop.hit(hitstop_duration)
=======
		return false
	if not (area is Hurtbox):
		return false
	if not area.take_hit(damage, _compute_knockback(area), source_fighter):
		return false
	_spawn_spark(area.global_position)
	return true

## 판정을 껐다 켤 때(열차가 지나가고 다음 열차가 올 때) 반복 타격 쿨타임을 초기화한다
func clear_repeat_state() -> void:
	_repeat_cooldowns.clear()
>>>>>>> 4431582d1dec5efeb00ec5aa1ae1c3a7afc42ed4

func _compute_knockback(hurtbox: Hurtbox) -> Vector2:
	if not pull_to_source or source_fighter == null:
		return knockback
	var to_source: Vector2 = source_fighter.global_position - hurtbox.global_position
	if to_source.length() < 1.0:
		return Vector2.ZERO
	return to_source.normalized() * pull_strength

func _spawn_spark(pos: Vector2) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var spark: Node2D = load("res://combat/HitSpark.tscn").instantiate()
	scene_root.add_child(spark)
	spark.global_position = pos
