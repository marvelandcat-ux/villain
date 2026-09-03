class_name SkillClashPopup
extends CanvasLayer

## 스킬 클래시(두 캐릭터가 같은 슬롯을 동시에 썼을 때) 연타 미니게임.
## 팝업 창 없이 카메라만 두 캐릭터 중간으로 줌인되고, 화면 위에 밀당 게이지(가운데 0.5에서 시작)만 뜬다.
## 방금 부딪힌 슬롯의 키를 자기 쪽으로 더 많이 연타한 쪽이 이긴다(스킬1끼리 부딪히면 스킬1 키, 궁극기끼리면 궁극기 키).
## 사람이 조작하는 쪽은 자기 p{1|2}_<slot_id> 키를 연타하고, AI가 조작하는 쪽은 무작위 간격으로 자동 연타한다
## — 승패는 SkillClashManager가 받아서 스킬 발동/취소로 이어붙인다.
## SkillClashManager가 이미 get_tree().paused = true를 걸어두므로 이 노드는 process_mode ALWAYS로
## 계속 돈다(입력 폴링・카메라 갱신 모두 pause와 무관하게 동작한다)

signal finished(a_won: bool)

## 줌인/줌아웃에 걸리는 시간(초) — 이 구간에도 연타는 이미 카운트된다
@export var zoom_in_time: float = 0.18
@export var zoom_out_time: float = 0.18
## 밀당이 계속되는 최대 시간(초) — 게이지가 끝까지 안 밀리면 이 시간이 다 됐을 때 우세한 쪽이 이긴다
@export var mash_duration: float = 1.0
## 원래 카메라 배율의 몇 배로 확대해서 들어갈지
@export var zoom_amount: float = 1.6
## 한 번 연타할 때마다 게이지(0~1)가 자기 쪽으로 밀리는 양 — 작을수록 오래 밀당해야 한다
@export var push_per_press: float = 0.05
## AI가 한 번 연타하는 데 걸리는 시간 범위(초) — 매번 이 사이 값으로 다음 연타까지 기다린다
@export var ai_press_interval_min: float = 0.08
@export var ai_press_interval_max: float = 0.16

enum Phase { IDLE, ZOOM_IN, MASH, ZOOM_OUT }

@onready var _gauge_blue: ColorRect = $Gauge/Frame/Inner/Blue
@onready var _gauge_red: ColorRect = $Gauge/Frame/Inner/Red

var _phase: int = Phase.IDLE
var _elapsed: float = 0.0
## 밀당 게이지 — 0.5가 중앙(무승부 상태), 1.0이면 A 완승, 0.0이면 B 완승
var _balance: float = 0.5
var _decided_early: bool = false
var _a_won: bool = false

var _action_a: String = ""
var _action_b: String = ""
var _ai_a: bool = false
var _ai_b: bool = false
var _ai_wait_a: float = 0.0
var _ai_wait_b: float = 0.0

var _camera: Camera2D
var _camera_from_position: Vector2
var _camera_from_zoom: Vector2
var _camera_target_position: Vector2

## fighter_a/fighter_b: 클래시를 벌이는 두 Fighter. slot_id: 부딪힌 스킬 슬롯("skill_1"/"skill_2"/
## "ultimate"/"basic_attack") — 이 슬롯의 키를 연타해야 한다. finished(a_won)으로 결과를 알린다
func start(fighter_a: Fighter, fighter_b: Fighter, slot_id: String) -> void:
	var control_a := _read_control(fighter_a, slot_id)
	var control_b := _read_control(fighter_b, slot_id)
	_action_a = control_a[0]
	_ai_a = control_a[1]
	_action_b = control_b[0]
	_ai_b = control_b[1]

	_camera = get_viewport().get_camera_2d()
	if _camera:
		_camera_from_position = _camera.global_position
		_camera_from_zoom = _camera.zoom
		_camera_target_position = (fighter_a.global_position + fighter_b.global_position) / 2.0

	_elapsed = 0.0
	_balance = 0.5
	_decided_early = false
	_ai_wait_a = randf_range(ai_press_interval_min, ai_press_interval_max)
	_ai_wait_b = randf_range(ai_press_interval_min, ai_press_interval_max)
	_update_gauge_visual()
	_phase = Phase.ZOOM_IN

## fighter를 조작하는 컨트롤러를 보고 [연타할 입력 액션, AI인지 여부]를 반환한다.
## 사람(PlayerController)이면 그 플레이어의 slot_id 키(예: p1_skill_1), AI(AIController)면 액션 없이 자동 연타
func _read_control(fighter: Fighter, slot_id: String) -> Array:
	for child in fighter.get_children():
		if child is PlayerController:
			return ["p%d_%s" % [child.player_index, slot_id], false]
		if child is AIController:
			return ["", true]
	return ["", true]

func _process(delta: float) -> void:
	match _phase:
		Phase.ZOOM_IN:
			var t: float = clampf(_elapsed / zoom_in_time, 0.0, 1.0)
			_apply_camera(t)
			_tick_mash(delta)
			_elapsed += delta
			if t >= 1.0:
				_phase = Phase.MASH
				_elapsed = 0.0
		Phase.MASH:
			_apply_camera(1.0)
			_tick_mash(delta)
			_elapsed += delta
			if _decided_early or _elapsed >= mash_duration:
				if not _decided_early:
					_a_won = (randf() < 0.5) if _balance == 0.5 else (_balance > 0.5)
				_phase = Phase.ZOOM_OUT
				_elapsed = 0.0
		Phase.ZOOM_OUT:
			var t2: float = clampf(_elapsed / zoom_out_time, 0.0, 1.0)
			_apply_camera(1.0 - t2)
			_elapsed += delta
			if t2 >= 1.0:
				_phase = Phase.IDLE
				finished.emit(_a_won)

## 아직 승부가 안 났으면 이번 프레임의 연타 입력(사람은 실제 키, AI는 시뮬레이션)을 게이지에 반영한다
func _tick_mash(delta: float) -> void:
	if _decided_early:
		return
	if _ai_a:
		_ai_wait_a -= delta
		if _ai_wait_a <= 0.0:
			_push(true)
			_ai_wait_a = randf_range(ai_press_interval_min, ai_press_interval_max)
	elif _action_a != "" and Input.is_action_just_pressed(_action_a):
		_push(true)

	if _ai_b:
		_ai_wait_b -= delta
		if _ai_wait_b <= 0.0:
			_push(false)
			_ai_wait_b = randf_range(ai_press_interval_min, ai_press_interval_max)
	elif _action_b != "" and Input.is_action_just_pressed(_action_b):
		_push(false)

## 한 번의 연타를 게이지에 반영한다. 끝까지 밀리면 그 자리에서 바로 승부가 난다(밀당 도중 조기 종료)
func _push(is_a_side: bool) -> void:
	_balance = clampf(_balance + (push_per_press if is_a_side else -push_per_press), 0.0, 1.0)
	_update_gauge_visual()
	if _balance >= 1.0:
		_a_won = true
		_decided_early = true
	elif _balance <= 0.0:
		_a_won = false
		_decided_early = true

func _update_gauge_visual() -> void:
	_gauge_blue.anchor_right = _balance
	_gauge_red.anchor_left = _balance

## t가 0이면 원래 카메라, 1이면 두 캐릭터 중간을 확대해서 잡은 상태
func _apply_camera(t: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	_camera.global_position = _camera_from_position.lerp(_camera_target_position, t)
	_camera.zoom = _camera_from_zoom.lerp(_camera_from_zoom * zoom_amount, t)
