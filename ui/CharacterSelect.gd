class_name CharacterSelect
extends Control

## P1(플레이어) 캐릭터를 먼저 고르고, 이어서 P2(AI) 캐릭터를 고르면 맵 선택 화면으로 넘어간다.
## 아래쪽 캐릭터 목록에서 하나를 누르면 위쪽 P1/P2 미리보기 칸에 이름과 색이 채워지는 방식

## 아직 캐릭터별 초상화가 없어서, 구분이 되도록 캐릭터마다 고정 색을 하나씩 지정해둔다.
## 목록에 없는 캐릭터는 DEFAULT_COLOR로 표시된다
const CHARACTER_COLORS := {
	"잼민이": Color(0.95, 0.85, 0.2),
	"악플러": Color(0.85, 0.25, 0.25),
	"주정뱅이": Color(0.8, 0.5, 0.2),
	"예수천국 불신지옥": Color(0.55, 0.35, 0.75),
	"캣맘": Color(0.9, 0.55, 0.7),
	"지하철빌런": Color(0.3, 0.65, 0.55),
	"층간피해빌런": Color(0.3, 0.5, 0.85),
}
const DEFAULT_COLOR := Color(0.35, 0.35, 0.4)

@onready var status_label: Label = $Center/VBox/StatusLabel
@onready var thumb_row: GridContainer = $Center/VBox/ThumbRow
@onready var confirm_button: Button = $Center/VBox/ConfirmButton
@onready var p1_preview_box: ColorRect = $Center/VBox/PreviewRow/P1Side/P1PreviewBox
@onready var p1_preview_label: Label = $Center/VBox/PreviewRow/P1Side/P1PreviewBox/P1PreviewLabel
@onready var p2_preview_box: ColorRect = $Center/VBox/PreviewRow/P2Side/P2PreviewBox
@onready var p2_preview_label: Label = $Center/VBox/PreviewRow/P2Side/P2PreviewBox/P2PreviewLabel

var _picking_p1: bool = true
## 아직 "확정" 버튼을 안 누른, 미리보기 칸에만 반영된 임시 선택. 빈 문자열이면 아무것도 안 고른 상태
var _pending_character: String = ""
var _thumb_buttons: Dictionary = {}  # {character_name: Button} — 선택 강조 표시용
var _is_spinning: bool = false

func _ready() -> void:
	status_label.text = "P1(플레이어) 캐릭터를 선택하세요"
	for character_name in GameState.CHARACTERS.keys():
		var color: Color = CHARACTER_COLORS.get(character_name, DEFAULT_COLOR)
		var button := _make_tile(character_name, color, 14, _on_character_picked.bind(character_name))
		thumb_row.add_child(button)
		_thumb_buttons[character_name] = button
	## 격자 맨 끝에 놓이는 "?" 칸 — 누를 때마다 캐릭터 하나를 무작위로 골라 미리보기에 반영한다(다른 칸처럼 확정은 별도)
	thumb_row.add_child(_make_tile("?", DEFAULT_COLOR, 28, _on_random_pressed))

func _make_tile(label: String, color: Color, font_size: int, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = false
	_apply_tile_style(button, color)
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(callback)
	return button

func _apply_tile_style(button: Button, color: Color) -> void:
	button.custom_minimum_size = Vector2(100, 90)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color * (1.15 if state == "hover" else (0.8 if state == "pressed" else 1.0))
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

## 미리보기 칸에 캐릭터 이름과 색만 반영한다(선택 확정 여부와는 무관 — 룰렛 연출 중에도 이걸로 화면을 갱신함)
func _show_preview(character_name: String) -> void:
	var color: Color = CHARACTER_COLORS.get(character_name, DEFAULT_COLOR)
	if _picking_p1:
		p1_preview_box.color = color
		p1_preview_label.text = character_name
	else:
		p2_preview_box.color = color
		p2_preview_label.text = character_name

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
		_show_preview(keys.pick_random())
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
	get_tree().change_scene_to_file("res://ui/RoomSettings.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
