class_name PassingTrain
extends Node2D

## 일정 주기로 지나가는 지하철 — 경고 후 궤도 판정 지역에 있으면 큰 데미지를 입는다.
## 판정 높이가 낮아서 점프로 피할 수 있다 (지하철빌런 상징 맵)
@export var interval: float = 6.0
@export var warning_duration: float = 1.0
@export var active_duration: float = 0.3
@export var damage: int = 25

@onready var visual: Polygon2D = $Visual
@onready var hitbox: Hitbox = $Hitbox

var _timer: float = 0.0

func _ready() -> void:
	_timer = interval
	visual.modulate.a = 0.0

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval
		_run_sequence()

func _run_sequence() -> void:
	visual.modulate = Color(1, 0.9, 0.2, 0.5)
	await _wait(warning_duration)
	visual.modulate = Color(0.8, 0.8, 0.85, 1.0)
	hitbox.damage = damage
	hitbox.monitoring = true
	hitbox.monitorable = true
	await _wait(active_duration)
	hitbox.monitoring = false
	hitbox.monitorable = false
	visual.modulate.a = 0.0

## duration초 후 재개된다. get_tree().create_timer()와 달리 이 노드의 자식 Timer로 만들어서,
## 대전 도중 나가기 등으로 이 노드(맵)가 먼저 사라지면 Timer도 같이 사라져 남은 시퀀스가 실행되지 않고 조용히 끝난다
## (Fighter._after()와 같은 이유 — get_tree().create_timer()는 SceneTree에 매여서 맵보다 오래 살아남는다)
func _wait(duration: float) -> void:
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()
