class_name Blackout
extends CanvasModulate

## 방 조명이 주기적으로 나갔다 들어오는 "암전" 기믹 (악플러의 방).
## CanvasModulate 자신이 곧 방 전체 조명이라 color를 직접 조절한다 — 씬에 이 노드 하나만 두면 된다.
## CombatHUD는 별도 CanvasLayer라 영향을 안 받아서, 암전 중에도 체력·타이머는 그대로 보인다.
## 시야만 가리는 연출이라 판정·데미지는 평소와 똑같이 들어간다

## 암전이 다시 오기까지의 주기(초). 불이 완전히 돌아온 시점부터 잰다
@export var interval: float = 12.0
## 꺼지기 직전 형광등처럼 몇 번 깜빡이는지
@export var flicker_count: int = 2
## 깜빡임 한 번(꺼짐+켜짐)의 시간(초)
@export var flicker_interval: float = 0.12
## 완전히 어두운 상태가 유지되는 시간(초)
@export var blackout_duration: float = 4.0
## 암전 중 밝기(0=완전 암흑, 1=평소와 같음). 0으로 두면 화면이 꺼진 것처럼 보여 살짝 남겨둔다
@export var blackout_brightness: float = 0.06
## 꺼지고 켜질 때 밝기가 부드럽게 바뀌는 시간(초)
@export var fade_time: float = 0.3

## 암전 중에도 살짝 빛나 보일 대상(모니터 화면 등, ADD 블렌드 권장). 비워두면 아무 일도 안 한다
@export var glow_target_path: NodePath
## glow_target이 암전 중 도달하는 최대 알파 — CanvasModulate가 곱해져도 알아볼 수 있을 만큼 밝게 잡는다
@export var glow_alpha: float = 0.85

## 씬에 저장된 평소 조명 색 — 이 밝기를 기준으로 어둡게/밝게 만든다
var _normal_color: Color = Color.WHITE
var _timer: float = 0.0

@onready var _glow: CanvasItem = get_node_or_null(glow_target_path) as CanvasItem

func _ready() -> void:
	_normal_color = color
	_timer = interval
	if _glow:
		_glow.modulate.a = 0.0

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval
		_run_sequence()

## 경고(깜빡임) -> 암전(+모니터 빛) -> 유지 -> 복귀 순서로 진행한다
func _run_sequence() -> void:
	await _flicker()
	await _fade_to(blackout_brightness, glow_alpha)
	await _wait(blackout_duration)
	await _fade_to(1.0, 0.0)

## 꺼지기 전 형광등처럼 flicker_count번만 깜빡이고 바로 암전으로 들어간다
func _flicker() -> void:
	var tween := create_tween()
	for i in flicker_count:
		tween.tween_property(self, "color", _dim(0.25), flicker_interval * 0.5)
		tween.tween_property(self, "color", _normal_color, flicker_interval * 0.5)
	await tween.finished

## brightness배로 어둡게(또는 밝게, 1.0이면 원래대로) 만들면서, 동시에 glow_target의 밝기를
## target_glow_alpha로 맞춘다 — 방이 어두워지는 것과 모니터가 밝아지는 게 같은 박자로 겹친다
func _fade_to(brightness: float, target_glow_alpha: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "color", _dim(brightness), fade_time)
	if _glow:
		tween.tween_property(_glow, "modulate:a", target_glow_alpha, fade_time)
	await tween.finished

## 평소 조명색의 RGB만 brightness배로 줄인다 — 알파는 그대로 둔다
func _dim(brightness: float) -> Color:
	return Color(_normal_color.r * brightness, _normal_color.g * brightness, _normal_color.b * brightness, _normal_color.a)

## Timers.after 참고 — 이 노드가 먼저 사라지면(라운드 리로드 등) 남은 시퀀스는 조용히 끝난다
func _wait(duration: float) -> void:
	var timer: Timer = Timers.after(self, duration)
	await timer.timeout
	timer.queue_free()
