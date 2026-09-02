class_name CharacterSelect
extends Control

## 로컬 대전(pvp)과 스토리 모드 둘 다 이 화면 하나를 같이 쓴다.
## - pvp: P1(플레이어) 캐릭터를 먼저 고르고, 이어서 P2(AI) 캐릭터를 고르면 맵 선택 화면으로 넘어간다
## - story: P2는 GameState.STORY_OPPONENTS[story_index]로 이미 정해져 있어서 P2 칸에 미리 공개해두고,
##   P1만 고르면 바로 확정되어 GameState.STORY_MAP_PATH로 넘어간다 (맵은 고정이라 맵 선택 화면 생략)
## 아래쪽 캐릭터 목록에서 하나를 누르면 위쪽 P1/P2 미리보기 칸에 이름과 색이 채워지는 방식

@onready var status_label: Label = $Center/VBox/StatusLabel
@onready var thumb_row: HBoxContainer = $Center/VBox/ThumbRow
@onready var confirm_button: Button = $Center/VBox/ConfirmButton
@onready var back_button: Button = $Center/VBox/BackButton
@onready var p2_name_label: Label = $Center/VBox/PreviewRow/P2Side/P2NameLabel
@onready var p1_preview_box: ColorRect = $Center/VBox/PreviewRow/P1Side/P1PreviewBox
@onready var p1_preview_image: TextureRect = $Center/VBox/PreviewRow/P1Side/P1PreviewBox/P1PreviewImage
@onready var p1_preview_label: Label = $Center/VBox/PreviewRow/P1Side/P1PreviewBox/P1PreviewLabel
@onready var p2_preview_box: ColorRect = $Center/VBox/PreviewRow/P2Side/P2PreviewBox
@onready var p2_preview_image: TextureRect = $Center/VBox/PreviewRow/P2Side/P2PreviewBox/P2PreviewImage
@onready var p2_preview_label: Label = $Center/VBox/PreviewRow/P2Side/P2PreviewBox/P2PreviewLabel

## 스토리 모드에서는 P2가 GameState.STORY_OPPONENTS로 이미 정해져 있어서 P1만 고르면 된다
var _is_story_mode: bool = false
var _picking_p1: bool = true
## 아직 "확정" 버튼을 안 누른, 미리보기 칸에만 반영된 임시 선택. 빈 문자열이면 아무것도 안 고른 상태
var _pending_character: String = ""
var _thumb_buttons: Dictionary = {}  # {character_name: Button} — 선택 강조 표시용
var _is_spinning: bool = false

func _ready() -> void:
	_is_story_mode = GameState.game_mode == "story"
	for character_name in GameState.CHARACTERS.keys():
		var color: Color = GameState.CHARACTER_COLORS.get(character_name, GameState.DEFAULT_COLOR)
		var button := _make_tile(character_name, color, 14, _on_character_picked.bind(character_name))
		thumb_row.add_child(button)
		_thumb_buttons[character_name] = button
	## 격자 맨 끝에 놓이는 "?" 칸 — 누를 때마다 캐릭터 하나를 무작위로 골라 미리보기에 반영한다(다른 칸처럼 확정은 별도)
	thumb_row.add_child(_make_tile("?", GameState.DEFAULT_COLOR, 28, _on_random_pressed))

	if _is_story_mode:
		status_label.text = "당신의 캐릭터를 선택하세요"
		back_button.text = "모드 선택으로 (ESC)"
		var opponent_name := _find_character_name(GameState.STORY_OPPONENTS[GameState.story_index])
		p2_name_label.text = "상대"
		p2_preview_box.color = GameState.CHARACTER_COLORS.get(opponent_name, GameState.DEFAULT_COLOR)
		p2_preview_label.text = opponent_name
		_apply_portrait(p2_preview_image, opponent_name)
	else:
		status_label.text = "P1(플레이어) 캐릭터를 선택하세요"

## 캐릭터 씬 경로로 GameState.CHARACTERS에 등록된 표시 이름을 역으로 찾는다 (스토리 상대 공개용)
func _find_character_name(path: String) -> String:
	for character_name in GameState.CHARACTERS.keys():
		if GameState.CHARACTERS[character_name] == path:
			return character_name
	return "?"

func _make_tile(label: String, color: Color, font_size: int, callback: Callable) -> Button:
	var button := Button.new()
	button.clip_text = false
	_apply_tile_style(button, color)
	button.pressed.connect(callback)

	var portrait_path: String = GameState.PORTRAITS.get(label, "")
	if portrait_path != "":
		# 초상화가 있는 캐릭터는 글자 대신 그림으로 채우고, 이름은 하단에 작게 걸친다
		var image := TextureRect.new()
		image.texture = load(portrait_path)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.anchor_right = 1.0
		image.anchor_bottom = 1.0
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(image)

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
	else:
		button.text = label
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", font_size)

	return button

func _apply_tile_style(button: Button, color: Color) -> void:
	button.custom_minimum_size = Vector2(100, 90)
	# hover/pressed/focus(마우스로 올렸거나 키보드로 이동해 지금 고르고 있는 칸)는 두꺼운 흰 테두리로 강조해서
	# "지금 뭘 고르는 중인지"가 한눈에 구분되게 한다 (MapSelect의 칸 강조와 같은 방식)
	for state in ["normal", "hover", "pressed", "focus"]:
		var is_highlighted: bool = state != "normal"
		var style := StyleBoxFlat.new()
		style.bg_color = color * (1.15 if state == "hover" else (0.8 if state == "pressed" else 1.0))
		var border_width: int = 4 if is_highlighted else 0
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width
		style.border_color = Color(1, 1, 1)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		button.add_theme_stylebox_override(state, style)

## 목록에서 캐릭터를 눌러도 바로 확정되지 않고, 미리보기 칸에만 반영된다.
## 실제로 P1/P2에 배정되는 건 "확정" 버튼을 눌렀을 때(_on_confirm_pressed)뿐이다
func _on_character_picked(character_name: String) -> void:
	_pending_character = character_name
	_show_preview(character_name)
	confirm_button.disabled = false
	_update_highlight()
	_focus_thumb(character_name)

## 목록 칸에 흰 테두리(포커스 스타일)를 준다 — 룰렛이 도는 동안 매 칸마다 불러서 테두리가 옮겨 다니게 한다
func _focus_thumb(character_name: String) -> void:
	var button: Button = _thumb_buttons.get(character_name)
	if button:
		button.grab_focus()

## 미리보기 칸에 캐릭터 이름·색·초상화를 반영한다(선택 확정 여부와는 무관 — 룰렛 연출 중에도 이걸로 화면을 갱신함)
func _show_preview(character_name: String) -> void:
	var color: Color = GameState.CHARACTER_COLORS.get(character_name, GameState.DEFAULT_COLOR)
	if _picking_p1:
		p1_preview_box.color = color
		p1_preview_label.text = character_name
		_apply_portrait(p1_preview_image, character_name)
	else:
		p2_preview_box.color = color
		p2_preview_label.text = character_name
		_apply_portrait(p2_preview_image, character_name)

## 초상화 그림이 있는 캐릭터면 TextureRect에 채워 보여주고, 없으면 비워서 뒤의 색상 배경(P#PreviewBox)이 그대로 보이게 한다
func _apply_portrait(image: TextureRect, character_name: String) -> void:
	var portrait_path: String = GameState.PORTRAITS.get(character_name, "")
	image.texture = load(portrait_path) if portrait_path != "" else null

## 슬롯머신처럼 캐릭터가 빠르게 바뀌다가 점점 느려지며 멈추는 연출. 멈춘 결과가 그대로 임시 선택(pending)이 된다.
## 대기는 이 노드(CharacterSelect)의 자식 Timer로 만들어서, 연출 도중 뒤로 나가 씬이 정리되면
## Timer도 같이 사라져 남은 연출이 그냥 실행되지 않고 끝난다(에러 없이 조용히 중단됨)
func _on_random_pressed() -> void:
	if _is_spinning:
		return
	_is_spinning = true
	confirm_button.disabled = true
	_set_thumb_buttons_disabled(true)

	var keys: Array = GameState.CHARACTERS.keys()
	var spin_count := 14
	for i in range(spin_count):
		var key: String = keys.pick_random()
		_show_preview(key)
		_focus_thumb(key)
		var progress := float(i) / float(spin_count - 1)
		await _wait(lerp(0.04, 0.22, progress))

	_set_thumb_buttons_disabled(false)
	_is_spinning = false
	_on_character_picked(keys.pick_random())

func _wait(duration: float) -> void:
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()

func _set_thumb_buttons_disabled(disabled: bool) -> void:
	for child in thumb_row.get_children():
		child.disabled = disabled

func _on_confirm_pressed() -> void:
	if _pending_character == "":
		return
	var path: String = GameState.CHARACTERS[_pending_character]
	if _picking_p1:
		GameState.p1_character_path = path
		if _is_story_mode:
			GameState.p2_character_path = GameState.STORY_OPPONENTS[GameState.story_index]
			GameState.selected_map_path = GameState.STORY_MAP_PATH
			get_tree().change_scene_to_file(GameState.selected_map_path)
			return
		_picking_p1 = false
		status_label.text = "P1: %s 확정! P2(AI) 캐릭터를 선택하세요" % _pending_character
		_pending_character = ""
		confirm_button.disabled = true
		_update_highlight()
	else:
		GameState.p2_character_path = path
		get_tree().change_scene_to_file("res://ui/MapSelect.tscn")

## 아직 확정 안 한 임시 선택 하나만 밝게, 나머지는 어둡게 해서 지금 뭘 고르는 중인지 눈으로 보이게 한다
func _update_highlight() -> void:
	for character_name in _thumb_buttons:
		var button: Button = _thumb_buttons[character_name]
		var is_selected: bool = (character_name == _pending_character)
		button.modulate = Color(1, 1, 1) if (is_selected or _pending_character == "") else Color(0.55, 0.55, 0.55)

func _on_back_pressed() -> void:
	if _is_story_mode:
		get_tree().change_scene_to_file("res://ui/ModeSelect.tscn")
	else:
		get_tree().change_scene_to_file("res://ui/RoomSettings.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
