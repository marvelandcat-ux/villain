class_name UltimateCutIn
extends CanvasLayer

## 궁극기 연출 — 궁을 쓰면 게임 전체를 멈추고, 카메라가 시전자 쪽으로 빨려들어간 뒤
## 컷인 그림을 보여주고, 원래 화면으로 돌아온 다음 실제 궁이 발동된다.
##
## 기획 결정(확정):
##  - 연출 중에는 시간이 멈춘다 (get_tree().paused). 이 노드만 PROCESS_MODE_ALWAYS라 계속 돈다
##  - 스킵은 없다
##  - 궁은 "연출이 시작될 때 시전자가 있던 자리에서, 그때 바라보던 방향"으로 나간다.
##    상대도 멈춰 있지만 자동 조준이 아니라서 방향이 어긋나면 빗나갈 수 있다(확정타 아님)
##  - 컷인 장면은 캐릭터 스탯(CharacterStats.ultimate_cutin_scene)에 지정한다.
##    미리 그린 그림이 아니라 파츠를 코드로 흔드는 씬이라 한 장면이면 된다(ui/cutin/ 참고).
##    지정 안 된 캐릭터는 이름만 크게 띄우는 임시 화면이 나온다.
##    궁 스킬에 `cutin_scene_for(fighter)`가 있으면 그 결과가 우선한다(같은 캐릭터라도 궁이 갈리는 경우)

## 카메라가 시전자에게 빨려들어가는 시간(초)
@export var zoom_in_time: float = 0.25
## 컷인 장면을 보여주는 기본 시간(초).
## 컷인 장면이 cutin_duration을 들고 있으면 그 값이 우선한다(잼민이 컷인은 2.4초짜리다)
@export var hold_time: float = 1.0
## 원래 화면으로 돌아오는 시간(초)
@export var zoom_out_time: float = 0.25
## 시전자에게 얼마나 확대해서 들어갈지 (원래 배율의 몇 배)
@export var cutin_zoom: float = 2.5

enum Phase { IDLE, ZOOM_IN, CUTIN, ZOOM_OUT }

@onready var _dim: ColorRect = $Dim
@onready var _holder: Node2D = $CutInHolder
@onready var _placeholder: ColorRect = $Placeholder
@onready var _name_label: Label = $NameLabel

var _phase: int = Phase.IDLE
var _elapsed: float = 0.0
var _fighter: Fighter
var _camera: Camera2D
var _camera_from_position: Vector2
var _camera_from_zoom: Vector2
## 연출이 시작된 순간의 시전자 위치/방향 — 연출이 끝나고 이 상태로 궁을 쏜다
var _fire_position: Vector2
var _fire_facing: float
## 이번 연출에서 띄운 컷인 장면 (연출이 끝나면 지운다)
var _cutin: Node2D
## 이번 연출에서 실제로 쓰는 컷인 표시 시간 — 장면이 cutin_duration을 들고 있으면 그 값으로 바뀐다
var _hold: float = 1.0

func _ready() -> void:
	add_to_group("ultimate_cutin")
	visible = false

## 궁극기 연출을 시작한다. 이미 연출 중이면 무시한다
func play(fighter: Fighter) -> void:
	if _phase != Phase.IDLE or fighter == null:
		return
	_fighter = fighter
	_fire_position = fighter.global_position
	_fire_facing = fighter.facing
	_camera = get_viewport().get_camera_2d()
	if _camera:
		_camera_from_position = _camera.global_position
		_camera_from_zoom = _camera.zoom

	_name_label.text = "%s\n궁극기" % (fighter.stats.character_name if fighter.stats else "")
	# 장면마다 필요한 길이가 다르므로 기본값을 깔아두고 _spawn_cutin이 덮어쓰게 한다
	_hold = hold_time
	_spawn_cutin(fighter)

	visible = true
	_phase = Phase.ZOOM_IN
	_elapsed = 0.0
	get_tree().paused = true

func _process(delta: float) -> void:
	if _phase == Phase.IDLE:
		return
	_elapsed += delta
	match _phase:
		Phase.ZOOM_IN:
			_update_zoom_in()
		Phase.CUTIN:
			_update_cutin()
		Phase.ZOOM_OUT:
			_update_zoom_out()

## 카메라가 시전자 쪽으로 빨려들어가면서 화면이 어두워진다
func _update_zoom_in() -> void:
	var t: float = clampf(_elapsed / zoom_in_time, 0.0, 1.0)
	# 뒤로 갈수록 빨라지게 (빨려들어가는 느낌)
	var eased: float = t * t
	_move_camera(eased)
	_dim.color.a = 0.55 * eased
	_set_cutin_alpha(eased)
	if t >= 1.0:
		_phase = Phase.CUTIN
		_elapsed = 0.0

## 컷인 장면이 스스로 돌아가는 동안(떨림이 점점 심해진다) 기다린다
func _update_cutin() -> void:
	_dim.color.a = 0.55
	if _elapsed >= _hold:
		_phase = Phase.ZOOM_OUT
		_elapsed = 0.0

## 원래 화면으로 돌아오고, 다 돌아오면 실제로 궁을 발동시킨다
func _update_zoom_out() -> void:
	var t: float = clampf(_elapsed / zoom_out_time, 0.0, 1.0)
	_move_camera(1.0 - t)
	_dim.color.a = 0.55 * (1.0 - t)
	_set_cutin_alpha(1.0 - t)
	if t >= 1.0:
		_finish()

## t가 0이면 원래 카메라, 1이면 시전자를 확대해서 잡은 상태
func _move_camera(t: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	_camera.global_position = _camera_from_position.lerp(_fire_position, t)
	_camera.zoom = _camera_from_zoom.lerp(_camera_from_zoom * cutin_zoom, t)

## 캐릭터에 지정된 컷인 장면을 화면 한가운데에 띄우고 재생시킨다.
## 지정된 장면이 없으면 이름만 뜨는 임시 화면을 쓴다
func _spawn_cutin(fighter: Fighter) -> void:
	var scene: PackedScene = fighter.stats.ultimate_cutin_scene if fighter.stats else null
	# 궁이 상황에 따라 장면을 고르면 그쪽이 우선한다(고양이 아주머니 = 고른 고양이별). null을 주면 위의 기본값을 쓴다
	var ult: Skill = fighter.skill_ultimate
	if ult and ult.has_method("cutin_scene_for"):
		var chosen: PackedScene = ult.cutin_scene_for(fighter)
		if chosen:
			scene = chosen
	_placeholder.visible = scene == null
	_name_label.visible = scene == null
	if scene == null:
		return
	_cutin = scene.instantiate()
	_holder.add_child(_cutin)
	_holder.position = get_viewport().get_visible_rect().size / 2.0
	# 컷인 장면 안의 애니메이션도 멈춤 상태에서 돌아야 한다
	_cutin.process_mode = Node.PROCESS_MODE_ALWAYS
	# 장면이 자기 길이를 들고 있으면 그 길이만큼 보여준다 (잼민이 3프레임 컷인처럼 긴 장면용)
	if "cutin_duration" in _cutin and _cutin.cutin_duration > 0.0:
		_hold = _cutin.cutin_duration
	if _cutin.has_method("play"):
		# 떨림이 커지는 시간을 컷인 표시 시간과 맞춘다
		if "ramp_time" in _cutin:
			_cutin.ramp_time = _hold
		_cutin.play()

func _set_cutin_alpha(alpha: float) -> void:
	_holder.modulate.a = alpha
	_placeholder.modulate.a = alpha
	_name_label.modulate.a = alpha

func _finish() -> void:
	_phase = Phase.IDLE
	visible = false
	if _cutin and is_instance_valid(_cutin):
		_cutin.queue_free()
	_cutin = null
	get_tree().paused = false
	if _fighter and is_instance_valid(_fighter):
		# 연출 시작 시점의 자리·방향 그대로 궁이 나간다
		_fighter.global_position = _fire_position
		_fighter.facing = _fire_facing
		_fighter.fire_ultimate_now()
	_fighter = null
