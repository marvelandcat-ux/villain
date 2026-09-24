extends Node2D

## 훈련장 — 스토리 모드/로컬 대전과 별개로, 캐릭터 하나만 평평한 바닥에 세워두고
## 중력·점프력·이동속도 같은 기본 수치를 실시간으로 바꿔보며 감각을 정하는 방.
## 상대도, 라운드도, 시간 제한도 없다(그래서 Stage.gd를 상속하지 않는다).
##
## 여기서 정한 값을 게임 전체에 반영하려면:
##   중력/점프력 → characters/Fighter.gd 의 DEFAULT_GRAVITY / DEFAULT_JUMP_VELOCITY
##   이동속도    → stats/*.tres 의 move_speed (훈련장에서는 배수로만 조절한다)

## 바닥 윗면의 y좌표 (씬의 Ground 노드 위치와 맞춰둔 값)
const GROUND_TOP_Y: float = 280.0
## 거리 감각을 보기 위한 눈금 간격 — 가로 100px, 세로 50px
const GRID_STEP_X: float = 100.0
const GRID_STEP_Y: float = 50.0
## 눈금을 그리는 좌우 범위 (바닥 절반 길이)
const GRID_HALF_WIDTH: float = 1000.0
## 이 아래로 떨어지면 바닥 밖으로 나간 것으로 보고 다시 세운다
const FALL_LIMIT_Y: float = 900.0

var _fighter: Fighter
## 스킬 데미지·넉백을 확인할 고정 타겟(샌드백) — 가만히 서서 맞아주기만 한다
var _dummy: Fighter
## 이동속도 배수 (stats.move_speed에 곱해진다)
var _speed_scale: float = 1.0

# --- 점프 측정값 ---
var _air_time: float = 0.0
var _jump_start: Vector2 = Vector2.ZERO
var _peak_height: float = 0.0
var _last_height: float = 0.0
var _last_air_time: float = 0.0
var _last_distance: float = 0.0

# --- UI 참조 ---
var _gravity_label: Label
var _jump_label: Label
var _speed_label: Label
var _readout_label: Label
var _gravity_slider: HSlider
var _jump_slider: HSlider
var _speed_slider: HSlider
var _dummy_hp_label: Label
var _collision_legend: RichTextLabel

## 충돌 영역(히트박스·허트박스·몸·발판) 보기 — 패널 체크박스로 켜고 끈다
## (타입을 안 붙인 이유: Node2D로 두면 스크립트에만 있는 `enabled`를 못 찾아 파싱 에러가 난다)
var _collision_view

func _ready() -> void:
	# 훈련장에서도 궁극기 컷인을 확인할 수 있게 같이 심는다
	add_child(load("res://ui/UltimateCutIn.tscn").instantiate())
	_collision_view = preload("res://maps/CollisionDebugView.gd").new()
	_collision_view.name = "CollisionDebugView"
	add_child(_collision_view)
	_build_ui()
	_spawn_character(GameState.p1_character_path)
	_spawn_dummy()

func _process(delta: float) -> void:
	if not (_fighter and is_instance_valid(_fighter)):
		return

	# 카메라는 좌우로만 따라간다 (위아래로 흔들리면 점프 높이를 눈으로 재기 어려워서)
	var camera: Camera2D = $Camera2D
	camera.global_position.x = lerpf(camera.global_position.x, _fighter.global_position.x, 5.0 * delta)

	_measure_jump(delta)

	if _fighter.global_position.y > FALL_LIMIT_Y:
		_respawn()

	_update_readout()

## 공중에 떠 있는 동안 최고 높이·체공 시간·수평 이동 거리를 재고, 착지하는 순간 결과로 확정한다
func _measure_jump(delta: float) -> void:
	if _fighter.is_on_floor():
		# 2px도 못 뜬 건 스폰 직후 살짝 떨어진 것 등이라 점프 기록으로 치지 않는다
		if _air_time > 0.0 and _peak_height >= 2.0:
			_last_air_time = _air_time
			_last_height = _peak_height
			_last_distance = absf(_fighter.global_position.x - _jump_start.x)
		_air_time = 0.0
		_peak_height = 0.0
		return
	if _air_time == 0.0:
		_jump_start = _fighter.global_position
	_air_time += delta
	_peak_height = maxf(_peak_height, _jump_start.y - _fighter.global_position.y)

## 바닥과 눈금선을 직접 그린다 (루트 Node2D의 _draw는 자식들보다 뒤에 그려져서 배경이 된다)
func _draw() -> void:
	var top: float = GROUND_TOP_Y - 400.0
	var x: float = -GRID_HALF_WIDTH
	while x <= GRID_HALF_WIDTH:
		# 100px마다 세로선, 500px마다는 진하게
		var strong: bool = fmod(absf(x), 500.0) < 1.0
		draw_line(Vector2(x, top), Vector2(x, GROUND_TOP_Y),
			Color(0.35, 0.4, 0.5, 0.5 if strong else 0.22), 2.0 if strong else 1.0)
		x += GRID_STEP_X
	var y: float = GROUND_TOP_Y - GRID_STEP_Y
	while y >= top:
		draw_line(Vector2(-GRID_HALF_WIDTH, y), Vector2(GRID_HALF_WIDTH, y), Color(0.35, 0.4, 0.5, 0.18), 1.0)
		y -= GRID_STEP_Y

func _spawn_character(character_path: String) -> void:
	if _fighter and is_instance_valid(_fighter):
		_fighter.queue_free()
	var scene: PackedScene = load(character_path)
	_fighter = scene.instantiate()
	add_child(_fighter)
	_fighter.global_position = $PlayerSpawn.global_position
	var controller := PlayerController.new()
	controller.player_index = 1
	_fighter.add_child(controller)
	_disable_cooldowns()
	_apply_speed_scale()
	_reset_measurements()

## 스킬을 실제로 맞춰볼 고정 타겟(샌드백)을 스폰한다. HP가 매우 커서 실전처럼 죽지 않고,
## DummyController가 붙어서 가만히 서 있기만 한다(입력도, AI 판단도 없음)
func _spawn_dummy() -> void:
	var scene: PackedScene = load("res://characters/dummy/TrainingDummy.tscn")
	_dummy = scene.instantiate()
	add_child(_dummy)
	_dummy.global_position = $DummySpawn.global_position
	_dummy.add_child(DummyController.new())

## 더미를 원래 자리로 되돌리고 HP를 최대로 채운다 (계속 때리다 보면 넉백으로 멀리 밀려나므로)
func _reset_dummy() -> void:
	if not (_dummy and is_instance_valid(_dummy)):
		return
	_dummy.global_position = $DummySpawn.global_position
	_dummy.velocity = Vector2.ZERO
	_dummy.current_hp = _dummy.stats.max_hp
	_dummy.health_changed.emit(_dummy.current_hp, _dummy.stats.max_hp)

## 훈련장에서는 스킬 쿨타임을 없앤다 — 값을 마음껏 시험해볼 수 있게 모든 스킬 노드의 cooldown을 0으로 만든다
func _disable_cooldowns() -> void:
	if not (_fighter and is_instance_valid(_fighter)):
		return
	for child in _fighter.get_children():
		if child is Skill:
			child.cooldown = 0.0
			child.cooldown_left = 0.0

## 캐릭터를 지우지 않고 스폰 위치로 되돌린다
func _respawn() -> void:
	if not (_fighter and is_instance_valid(_fighter)):
		return
	_fighter.global_position = $PlayerSpawn.global_position
	_fighter.velocity = Vector2.ZERO
	_reset_measurements()

func _reset_measurements() -> void:
	_air_time = 0.0
	_peak_height = 0.0
	_last_height = 0.0
	_last_air_time = 0.0
	_last_distance = 0.0

func _apply_speed_scale() -> void:
	if _fighter and is_instance_valid(_fighter):
		_fighter.set_modifier("move_speed_multiplier", "training", _speed_scale)

## ESC로 메인 메뉴로 나간다. 조절한 중력/점프력은 게임을 끄기 전까지 그대로 유지돼서
## 곧바로 로컬 대전에서 같은 값으로 시험해볼 수 있다
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

# ------------------------------------------------------------------
# UI — 게임 화면이 아니라 값 조절용 도구라서 씬에 배치하지 않고 코드로 만든다
# ------------------------------------------------------------------
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TrainingUI"
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(430, 0)
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "훈련장 — 기본 수치 조절"
	box.add_child(title)

	var picker := OptionButton.new()
	# 대전 로스터에 없는 캐릭터(경찰관처럼 스토리 전용)도 여기서는 세워볼 수 있어야 한다
	var roster: Dictionary = GameState.training_characters()
	for character_name in roster.keys():
		picker.add_item(character_name)
	var current: int = roster.values().find(GameState.p1_character_path)
	if current >= 0:
		picker.select(current)
	picker.item_selected.connect(_on_character_selected)
	box.add_child(picker)

	_gravity_label = Label.new()
	box.add_child(_gravity_label)
	_gravity_slider = _add_slider(box, 100.0, 2500.0, 10.0, Fighter.gravity, _on_gravity_changed)

	_jump_label = Label.new()
	box.add_child(_jump_label)
	_jump_slider = _add_slider(box, 100.0, 900.0, 5.0, -Fighter.jump_velocity, _on_jump_changed)

	_speed_label = Label.new()
	box.add_child(_speed_label)
	_speed_slider = _add_slider(box, 0.2, 3.0, 0.05, _speed_scale, _on_speed_changed)

	box.add_child(HSeparator.new())

	_readout_label = Label.new()
	box.add_child(_readout_label)

	box.add_child(HSeparator.new())

	var collision_toggle := CheckBox.new()
	collision_toggle.text = "충돌 영역 보기"
	collision_toggle.toggled.connect(_on_collision_toggled)
	box.add_child(collision_toggle)

	_collision_legend = RichTextLabel.new()
	_collision_legend.bbcode_enabled = true
	_collision_legend.fit_content = true
	_collision_legend.scroll_active = false
	_collision_legend.text = (
		"[color=#ff3333]히트박스(때리는 곳)[/color]   [color=#33ff59]허트박스(맞는 곳)[/color]\n"
		+ "[color=#4d99ff]몸 충돌[/color]   [color=#d9d9d9]벽·바닥[/color]   "
		+ "[color=#ffcc33]발판(아래서 통과)[/color]   [color=#cc66ff]기타 영역[/color]")
	_collision_legend.visible = false
	box.add_child(_collision_legend)

	var respawn_button := Button.new()
	respawn_button.text = "제자리로 되돌리기"
	respawn_button.pressed.connect(_respawn)
	box.add_child(respawn_button)

	_dummy_hp_label = Label.new()
	box.add_child(_dummy_hp_label)

	var dummy_reset_button := Button.new()
	dummy_reset_button.text = "더미 리셋 (위치+HP)"
	dummy_reset_button.pressed.connect(_reset_dummy)
	box.add_child(dummy_reset_button)

	var reset_button := Button.new()
	reset_button.text = "기본값으로 되돌리기"
	reset_button.pressed.connect(_on_reset_pressed)
	box.add_child(reset_button)

	var hint := Label.new()
	hint.text = "이동 A/D · 점프 W · 공격 F · 스킬 G/H · 궁극기 R\nESC: 메인 메뉴로"
	box.add_child(hint)

## 슬라이더 하나를 만들어 붙이고 그 슬라이더를 돌려준다
func _add_slider(parent: VBoxContainer, min_value: float, max_value: float, step: float,
		value: float, on_changed: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.value_changed.connect(on_changed)
	parent.add_child(slider)
	return slider

func _on_collision_toggled(pressed: bool) -> void:
	_collision_view.enabled = pressed
	_collision_legend.visible = pressed
	# 체크박스가 포커스를 쥐고 있으면 스페이스·엔터가 체크를 다시 뒤집는다
	get_viewport().gui_release_focus()

func _on_character_selected(index: int) -> void:
	GameState.p1_character_path = GameState.training_characters().values()[index]
	_spawn_character(GameState.p1_character_path)

func _on_gravity_changed(value: float) -> void:
	Fighter.gravity = value

## 슬라이더는 보기 편하게 양수를 쓰고, 실제 점프력은 위쪽이 음수라 부호를 뒤집어서 넣는다
func _on_jump_changed(value: float) -> void:
	Fighter.jump_velocity = -value

func _on_speed_changed(value: float) -> void:
	_speed_scale = value
	_apply_speed_scale()

func _on_reset_pressed() -> void:
	Fighter.gravity = Fighter.DEFAULT_GRAVITY
	Fighter.jump_velocity = Fighter.DEFAULT_JUMP_VELOCITY
	_speed_scale = 1.0
	_apply_speed_scale()
	# 슬라이더 손잡이 위치도 같이 되돌린다 (set_value_no_signal이라 콜백이 다시 불리지 않는다)
	_gravity_slider.set_value_no_signal(Fighter.DEFAULT_GRAVITY)
	_jump_slider.set_value_no_signal(-Fighter.DEFAULT_JUMP_VELOCITY)
	_speed_slider.set_value_no_signal(1.0)

func _update_readout() -> void:
	var speed: float = 0.0
	var move_speed: float = 0.0
	if _fighter and is_instance_valid(_fighter):
		speed = absf(_fighter.velocity.x)
		move_speed = _fighter.stats.move_speed * _speed_scale
	_gravity_label.text = "중력: %d" % int(Fighter.gravity)
	_jump_label.text = "점프력: %d (실제 값 %d)" % [int(-Fighter.jump_velocity), int(Fighter.jump_velocity)]
	_speed_label.text = "이동속도 배수: %.2f  →  %d px/s" % [_speed_scale, int(move_speed)]
	_readout_label.text = "현재 속도: %d px/s\n마지막 점프 — 높이 %d px / 체공 %.2f초 / 이동 %d px" % [
		int(speed), int(_last_height), _last_air_time, int(_last_distance)]
	if _dummy and is_instance_valid(_dummy):
		_dummy_hp_label.text = "더미 HP: %d" % _dummy.current_hp
