class_name Blackout
extends CanvasModulate

## 방 조명이 주기적으로 나갔다 들어오는 "암전" 기믹 (악플러의 방).
## CanvasModulate 자신이 곧 방 전체 조명이라 color를 직접 조절한다 — 씬에 이 노드 하나만 두면 된다.
## CombatHUD는 별도 CanvasLayer라 영향을 안 받아서, 암전 중에도 체력·타이머는 그대로 보인다.
## 시야만 가리는 연출이라 판정·데미지는 평소와 똑같이 들어간다.
## 캐릭터 등 뒤 쿨타임 원(`CooldownPies`)은 조명을 안 받으므로, 어두운 동안엔 방어·대시·빨간 X(패링 잠금)를 따로 숨긴다

## 암전이 다시 오기까지의 주기(초). 불이 완전히 돌아온 시점부터 잰다
@export var interval: float = 12.0
## 꺼지기 직전 형광등처럼 몇 번 깜빡이는지
@export var flicker_count: int = 2
## 깜빡임 한 번(꺼짐+켜짐)의 시간(초)
@export var flicker_interval: float = 0.12
## 완전히 어두운 상태가 유지되는 시간(초) — 암전마다 min~max 사이에서 랜덤으로 뽑는다
@export var blackout_duration_min: float = 4.0
@export var blackout_duration_max: float = 6.0
## 암전 중 밝기(0=완전 암흑, 1=평소와 같음). 0으로 두면 화면이 꺼진 것처럼 보여 살짝 남겨둔다
@export var blackout_brightness: float = 0.06
## 꺼지고 켜질 때 밝기가 부드럽게 바뀌는 시간(초)
@export var fade_time: float = 0.3

## 암전 중에도 살짝 빛나 보일 대상(모니터 화면 등, ADD 블렌드 권장). 비워두면 아무 일도 안 한다
@export var glow_target_path: NodePath
## glow_target이 암전 중 도달하는 최대 알파 — CanvasModulate가 곱해져도 알아볼 수 있을 만큼 밝게 잡는다
@export var glow_alpha: float = 0.85

## **스토리 모드에선 처음부터 끝까지 어둡게 둔다**(2026-10-07 사용자 — 에피소드 2 악플러의 집).
## 깜빡임·복귀 없이 시작하자마자 암전 상태로 들어가 그대로 멈춘다. 후레쉬(`FlashlightSkill`)가 그 어둠을 뚫는다
@export var always_dark_in_story: bool = true

## 암전 중 주변을 비출 조명(모니터 앞 PointLight2D). 방이 어두워지는 박자에 맞춰 켜지고, 불이 돌아오면 꺼진다.
## CanvasModulate가 방 전체를 어둡게 깔아도 Light2D는 그 위에 빛을 더하므로 이 조명 근처만 밝게 보인다 —
## 근처에 선 캐릭터도 같이 밝아져서, 암전 중엔 모니터 앞에 있으면 위치가 드러난다. 비워두면 아무 일도 안 한다
@export var light_target_path: NodePath
## light_target이 암전 중 도달하는 밝기(energy). 평소엔 0이라 불이 켜져 있을 땐 아무 영향이 없다
@export var light_energy: float = 1.2

## 씬에 저장된 평소 조명 색 — 이 밝기를 기준으로 어둡게/밝게 만든다
var _normal_color: Color = Color.WHITE
var _timer: float = 0.0
## 불이 꺼진 동안 true(깜빡임이 끝나고 어두워지기 시작한 순간 ~ 다시 밝아지기 시작한 순간).
## 암전에 맞춰 반응할 것들(엄마 눈빛 등)은 "blackout" 그룹에서 이 노드를 찾아 읽는다
var is_dark: bool = false

@onready var _glow: CanvasItem = get_node_or_null(glow_target_path) as CanvasItem
@onready var _light: Light2D = get_node_or_null(light_target_path) as Light2D

func _ready() -> void:
	add_to_group("blackout")
	_normal_color = color
	_timer = interval
	if _glow:
		_glow.modulate.a = 0.0
	if _light:
		_light.energy = 0.0
	if always_dark_in_story and GameState.game_mode == "story":
		_stay_dark()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval
		_run_sequence()

## 경고(깜빡임) -> 암전(+모니터 빛) -> 유지 -> 복귀 순서로 진행한다
func _run_sequence() -> void:
	await _flicker()
	_set_pies_hidden(true)
	is_dark = true
	await _fade_to(blackout_brightness, glow_alpha, light_energy)
	await _wait(randf_range(blackout_duration_min, maxf(blackout_duration_min, blackout_duration_max)))
	_set_pies_hidden(false)
	is_dark = false
	await _fade_to(1.0, 0.0, 0.0)

## 시작부터 암전 상태로 들어가 그대로 멈춘다 — 주기·깜빡임·복귀를 다 끈다
func _stay_dark() -> void:
	set_process(false)
	is_dark = true
	color = _dim(blackout_brightness)
	if _glow:
		_glow.modulate.a = glow_alpha
	if _light:
		_light.energy = light_energy
	# 쿨타임 원은 캐릭터가 생길 때 같이 생긴다 — 이 노드가 맵(Stage)보다 먼저 준비되므로 한 박자 미뤄 숨긴다
	_set_pies_hidden.call_deferred(true)

## 쿨타임 원 숨기기/보이기 — 라운드가 리로드되면 원도 새로 만들어지므로 따로 되돌릴 필요는 없다
func _set_pies_hidden(value: bool) -> void:
	get_tree().call_group("cooldown_pies", "set_blackout_hidden", value)

## 꺼지기 전 형광등처럼 flicker_count번만 깜빡이고 바로 암전으로 들어간다
func _flicker() -> void:
	var tween := create_tween()
	for i in flicker_count:
		tween.tween_property(self, "color", _dim(0.25), flicker_interval * 0.5)
		tween.tween_property(self, "color", _normal_color, flicker_interval * 0.5)
	await tween.finished

## brightness배로 어둡게(또는 밝게, 1.0이면 원래대로) 만들면서, 동시에 glow_target의 밝기를
## target_glow_alpha로, light_target의 밝기를 target_light_energy로 맞춘다 —
## 방이 어두워지는 것과 모니터 화면·모니터 불빛이 밝아지는 게 같은 박자로 겹친다
func _fade_to(brightness: float, target_glow_alpha: float, target_light_energy: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "color", _dim(brightness), fade_time)
	if _glow:
		tween.tween_property(_glow, "modulate:a", target_glow_alpha, fade_time)
	if _light:
		tween.tween_property(_light, "energy", target_light_energy, fade_time)
	await tween.finished

## 평소 조명색의 RGB만 brightness배로 줄인다 — 알파는 그대로 둔다
## 지금 방 조명이 평소 대비 몇 배인지(1 = 평소, 암전이면 blackout_brightness, 깜빡일 때 오르내림).
## 천장 등의 빛(`CeilingLamp`)이 이 값을 따라 같이 꺼지고 깜빡인다
func light_level() -> float:
	return clampf(color.v / maxf(_normal_color.v, 0.001), 0.0, 1.0)

func _dim(brightness: float) -> Color:
	return Color(_normal_color.r * brightness, _normal_color.g * brightness, _normal_color.b * brightness, _normal_color.a)

## Timers.after 참고 — 이 노드가 먼저 사라지면(라운드 리로드 등) 남은 시퀀스는 조용히 끝난다
func _wait(duration: float) -> void:
	var timer: Timer = Timers.after(self, duration)
	await timer.timeout
	timer.queue_free()
