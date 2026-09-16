class_name MapSelect
extends Control

## 맵을 고르면 바로 그 맵으로 씬 전환 — 캐릭터는 이미 CharacterSelect에서 GameState에 저장돼 있다.
## 각 칸에는 MapPreview가 그 맵의 실제 바닥·벽 색과 배치를 미니 스케치로 그려서 맵 모습을 미리 보여준다.
## 배경 양옆에는 CharacterSelect에서 확정한 P1/P2 캐릭터가 인게임 몸(BodyRig)으로 서 있다 —
## 뭘 골랐는지 다시 한번 눈으로 확인시켜주는 용도

## 서 있는 캐릭터 배율 — 1.0이면 실제 대전 화면에서 보이는 것과 똑같은 크기(인게임 크기)로 서 있다
const STANDEE_SCALE := 1.0

@onready var map_grid: GridContainer = $Center/VBox/MapGrid
@onready var p1_standee: Node2D = $P1Standee
@onready var p2_standee: Node2D = $P2Standee

var _map_buttons: Dictionary = {}  # {map_name: Button} — 룰렛 연출에서 흰 테두리를 옮길 때 씀
var _is_spinning: bool = false

func _ready() -> void:
	for map_name in GameState.MAPS.keys():
		var button := _make_tile(map_name, GameState.MAPS[map_name], _on_map_picked.bind(map_name))
		map_grid.add_child(button)
		_map_buttons[map_name] = button
	map_grid.add_child(_make_tile("?", "", _on_random_pressed))

	# P1(왼쪽)은 오른쪽(가운데)을, P2(오른쪽)은 왼쪽(가운데)을 보게 마주 세운다
	_spawn_standee(p1_standee, GameState.p1_character_path, 1.0)
	_spawn_standee(p2_standee, GameState.p2_character_path, -1.0)

## container 자리에 그 캐릭터의 인게임 몸(BodyRig)을 세운다. Fighter가 없으니 걷지 않고
## 가만히 서서 숨쉬는 동작만 돈다 — CharacterSelect의 미리보기 상자와 같은 원리
func _spawn_standee(container: Node2D, character_path: String, facing: float) -> void:
	var character_name: String = GameState.character_name_for_path(character_path)
	if not GameState.has_character_rig(character_name):
		return
	var rig: Node2D = GameState.character_rig_scene(character_name).instantiate()
	container.add_child(rig)
	rig.scale = Vector2(STANDEE_SCALE * facing, STANDEE_SCALE)

func _make_tile(label: String, map_path: String, callback: Callable) -> Button:
	var button := Button.new()
	button.clip_text = false
	_apply_tile_style(button)
	button.pressed.connect(callback)

	if map_path == "":
		button.text = label
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 28)
		return button

	var preview := MapPreview.new()
	preview.anchor_right = 1.0
	preview.anchor_bottom = 1.0
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_map(map_path)
	button.add_child(preview)

	var name_label := Label.new()
	name_label.text = label
	name_label.anchor_right = 1.0
	name_label.anchor_top = 1.0
	name_label.anchor_bottom = 1.0
	name_label.offset_top = -20
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	button.add_child(name_label)

	return button

func _apply_tile_style(button: Button) -> void:
	button.custom_minimum_size = Vector2(160, 90)
	# hover/pressed/focus(마우스로 올렸거나 키보드로 이동해 지금 고르고 있는 칸)는 두꺼운 흰 테두리로 강조,
	# normal은 은은한 회색 테두리로 눈에 덜 띄게 해서 "지금 뭘 고르는 중인지"가 한눈에 구분되게 한다
	for state in ["normal", "hover", "pressed", "focus"]:
		var is_highlighted: bool = state != "normal"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.16, 0.19, 1) if is_highlighted else Color(0.09, 0.09, 0.11, 1)
		var border_width: int = 4 if is_highlighted else 2
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width
		style.border_color = Color(1, 1, 1) if is_highlighted else Color(0.6, 0.6, 0.65)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		button.add_theme_stylebox_override(state, style)

## 고른 맵으로 바로 들어가지 않고, 그 맵을 크게 보여주는 팝업을 잠깐 띄운 뒤,
## 홀로그램 타일이 화면을 뒤덮었다가 새 맵 위에서 걷히는 연출과 함께 들어간다.
## SceneTransition(오토로드)이 씬 전환에 걸쳐 타일을 들고 있으므로, 덮은 채로 씬이 바뀌고
## 새 맵이 자리잡은 뒤에 타일이 걷히며 드러난다 — 이 화면(MapSelect)은 그동안 사라져도 상관없다
func _on_map_picked(map_name: String) -> void:
	var picked_button: Button = _map_buttons.get(map_name)
	if picked_button:
		SelectionRipple.spawn(picked_button)
	_set_map_buttons_disabled(true)
	# 파동이 다 퍼지는 모습을 보여준 뒤에 어두운 팝업으로 덮는다
	await _wait(SelectionRipple.total_duration())
	await _show_map_popup(map_name)
	GameState.selected_map_path = GameState.MAPS[map_name]
	SceneTransition.go_to_scene(GameState.selected_map_path)

## 화면 전체를 어둡게 가리고 가운데에 큰 MapPreview + 맵 이름을 잠깐 보여준다.
## MapPreview는 칸에 쓰던 것과 같은 스크립트라, 크기만 키우면 그대로 큰 미리보기가 된다
func _show_map_popup(map_name: String) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -220
	panel.offset_bottom = 220
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.11, 1)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_color = Color(1, 1, 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = map_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(name_label)

	var preview := MapPreview.new()
	preview.custom_minimum_size = Vector2(560, 320)
	preview.set_map(GameState.MAPS[map_name])
	vbox.add_child(preview)

	await _wait(1.1)

## 캐릭터 선택 화면의 룰렛과 같은 방식 — 흰 테두리(포커스)가 빠르게 옮겨다니다가 점점 느려지며 멈춘다.
## 대기는 이 노드의 자식 Timer로 만들어서, 연출 도중 뒤로 나가 씬이 정리되면 Timer도 같이 사라져
## 남은 연출이 그냥 실행되지 않고 끝난다(에러 없이 조용히 중단됨)
func _on_random_pressed() -> void:
	if _is_spinning:
		return
	_is_spinning = true
	_set_map_buttons_disabled(true)

	var keys: Array = GameState.MAPS.keys()
	var start_index: int = randi() % keys.size()
	var spin_count: int = keys.size() * 3  # 최소 3바퀴는 돌고 멈추게
	var final_key: String = keys[start_index]
	for i in range(spin_count):
		final_key = keys[(start_index + i) % keys.size()]
		_focus_tile(final_key)
		var progress := float(i) / float(spin_count - 1)
		await _wait(lerp(0.0133, 0.22, progress))

	_set_map_buttons_disabled(false)
	_is_spinning = false
	_on_map_picked(final_key)

func _focus_tile(map_name: String) -> void:
	var button: Button = _map_buttons.get(map_name)
	if button:
		button.grab_focus()

func _set_map_buttons_disabled(disabled: bool) -> void:
	for child in map_grid.get_children():
		child.disabled = disabled

func _wait(duration: float) -> void:
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/CharacterSelect.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
