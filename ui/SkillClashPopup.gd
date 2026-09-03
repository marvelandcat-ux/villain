class_name SkillClashPopup
extends CanvasLayer

## 스킬 클래시(두 캐릭터가 같은 슬롯을 동시에 썼을 때) 연타 미니게임.
## 정해진 시간(duration) 동안 기본공격 키를 더 많이 누른 쪽이 이긴다.
## 사람이 조작하는 쪽은 자기 p{1|2}_basic_attack 키를 연타하고, AI가 조작하는 쪽은
## 무작위 간격으로 자동 연타한다 — 승패는 SkillClashManager가 받아서 스킬 발동/취소로 이어붙인다.
## SkillClashManager가 이미 get_tree().paused = true를 걸어두므로 이 노드는 process_mode ALWAYS로
## 계속 돈다(입력 폴링 자체는 pause와 무관하게 동작한다)

signal finished(a_won: bool)

@export var duration: float = 1.2
## AI가 한 번 연타하는 데 걸리는 시간 범위(초) — 매번 이 사이 값으로 다음 연타까지 기다린다
@export var ai_press_interval_min: float = 0.08
@export var ai_press_interval_max: float = 0.16

@onready var _label_a: Label = $Panel/Sides/SideA/NameLabel
@onready var _label_b: Label = $Panel/Sides/SideB/NameLabel
@onready var _bar_a: ProgressBar = $Panel/Sides/SideA/MashBar
@onready var _bar_b: ProgressBar = $Panel/Sides/SideB/MashBar
@onready var _timer_bar: ProgressBar = $Panel/TimerBar

var _elapsed: float = 0.0
var _count_a: int = 0
var _count_b: int = 0
var _action_a: String = ""
var _action_b: String = ""
var _ai_a: bool = false
var _ai_b: bool = false
var _ai_wait_a: float = 0.0
var _ai_wait_b: float = 0.0
var _running: bool = false

## fighter_a/fighter_b: 클래시를 벌이는 두 Fighter. finished(a_won)으로 결과를 알린다
func start(fighter_a: Fighter, fighter_b: Fighter) -> void:
	_label_a.text = fighter_a.stats.character_name if fighter_a.stats else "P1"
	_label_b.text = fighter_b.stats.character_name if fighter_b.stats else "P2"
	var control_a := _read_control(fighter_a)
	var control_b := _read_control(fighter_b)
	_action_a = control_a[0]
	_ai_a = control_a[1]
	_action_b = control_b[0]
	_ai_b = control_b[1]

	_elapsed = 0.0
	_count_a = 0
	_count_b = 0
	_bar_a.max_value = 1
	_bar_b.max_value = 1
	_bar_a.value = 0
	_bar_b.value = 0
	_timer_bar.max_value = 1.0
	_timer_bar.value = 1.0
	_ai_wait_a = randf_range(ai_press_interval_min, ai_press_interval_max)
	_ai_wait_b = randf_range(ai_press_interval_min, ai_press_interval_max)
	_running = true

## fighter를 조작하는 컨트롤러를 보고 [연타할 입력 액션, AI인지 여부]를 반환한다.
## 사람(PlayerController)이면 그 플레이어의 기본공격 키, AI(AIController)면 액션 없이 자동 연타
func _read_control(fighter: Fighter) -> Array:
	for child in fighter.get_children():
		if child is PlayerController:
			return ["p%d_basic_attack" % child.player_index, false]
		if child is AIController:
			return ["", true]
	return ["", true]

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	_timer_bar.value = clampf(1.0 - _elapsed / duration, 0.0, 1.0)

	if _ai_a:
		_ai_wait_a -= delta
		if _ai_wait_a <= 0.0:
			_count_a += 1
			_ai_wait_a = randf_range(ai_press_interval_min, ai_press_interval_max)
	elif _action_a != "" and Input.is_action_just_pressed(_action_a):
		_count_a += 1

	if _ai_b:
		_ai_wait_b -= delta
		if _ai_wait_b <= 0.0:
			_count_b += 1
			_ai_wait_b = randf_range(ai_press_interval_min, ai_press_interval_max)
	elif _action_b != "" and Input.is_action_just_pressed(_action_b):
		_count_b += 1

	var max_count: int = maxi(maxi(_count_a, _count_b), 1)
	_bar_a.max_value = max_count
	_bar_a.value = _count_a
	_bar_b.max_value = max_count
	_bar_b.value = _count_b

	if _elapsed >= duration:
		_running = false
		var a_won: bool = (randf() < 0.5) if _count_a == _count_b else (_count_a > _count_b)
		finished.emit(a_won)
