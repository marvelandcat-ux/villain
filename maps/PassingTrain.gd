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
	await get_tree().create_timer(warning_duration).timeout
	visual.modulate = Color(0.8, 0.8, 0.85, 1.0)
	hitbox.damage = damage
	hitbox.monitoring = true
	hitbox.monitorable = true
	await get_tree().create_timer(active_duration).timeout
	hitbox.monitoring = false
	hitbox.monitorable = false
	visual.modulate.a = 0.0
