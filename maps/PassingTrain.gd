class_name PassingTrain
extends Node2D

## 일정 주기로 지나가는 지하철 — 경고 후 궤도 판정 지역에 있으면 큰 데미지를 입는다.
## 판정 높이가 낮아서 점프로 피할 수 있다 (지하철 아저씨 상징 맵)
## 열차가 다시 지나갈 때까지의 전체 주기(초, 경고+판정 시간 포함)
@export var interval: float = 6.0
## 경고(노란빛)로 알려주는 시간(초) — 이 동안은 아직 안 맞는다
@export var warning_duration: float = 1.0
## 실제로 판정이 켜져 있는 시간(초)
@export var active_duration: float = 0.3
## 판정에 닿았을 때의 데미지
@export var damage: int = 25

## 궤도 판정 지역을 보여주는 도형 — 경고/판정 중에만 색이 켜진다
@onready var visual: Polygon2D = $Visual
## 실제 데미지 판정
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

## duration초 후 재개된다 (Timers.after 참고 — 이 노드(맵)가 먼저 사라지면 남은 시퀀스는 조용히 끝난다)
func _wait(duration: float) -> void:
	var timer: Timer = Timers.after(self, duration)
	await timer.timeout
	timer.queue_free()
