class_name CharacterSelect
extends Control

## 위쪽 큰 미리보기 상자 크기 (CharacterSelect.tscn의 P1/P2 PreviewBox custom_minimum_size와 같은 값 — 정사각형)
const PREVIEW_BOX_SIZE := Vector2(300, 300)

## 초상화의 그림·배율·위치는 전부 ui/PortraitFrames.tscn에서 읽는다(GameState가 로드해둠).
## 그 씬을 에디터에서 열어 각 캐릭터 얼굴을 프레임 안에서 조절하면 여기 선택 화면에 그대로 반영된다

## 대전 모드(pvp) 전용 화면이다. P1(플레이어) 캐릭터를 먼저 고르고, 이어서 P2 캐릭터를 고르면 맵 선택 화면으로 넘어간다.
## (예전엔 옛 스토리 모드도 이 화면을 같이 썼는데, 2026-09-12 스토리 모드를 새로 짜면서 그 분기를 걷어냈다)
## 아래쪽 캐릭터 목록에서 하나를 누르면 위쪽 P1/P2 미리보기 칸에 이름과 색이 채워지는 방식
##
## 목록 칸(ThumbRow 밑 FanTile들)은 코드로 만들지 않고 씬에 캐릭터마다 별개의 노드로 미리 놓아뒀다 —
## 사다리꼴 모양이 서로 이어지도록 칸마다 corners(꼭짓점)를 직접 잡아둔 것이라, 모양을 바꾸고 싶으면
## 에디터에서 그 노드의 corners/position을 직접 조절하면 된다(FanTile.gd 참고. 일반 칸은 전부 같은
## 평행사변형 모양이라 하나를 복사-붙여넣기해서 새 칸을 만들 수 있다). 여기서는 character_key를 보고
## 어떤 GameState.CHARACTERS 캐릭터인지 연결만 한다 — character_key가 빈 칸은 "?" 랜덤 칸으로 취급

@onready var status_label: Label = $Center/VBox/StatusLabel
@onready var thumb_row: Control = $Center/VBox/ThumbRow
@onready var confirm_button: Button = $Center/VBox/ConfirmButton
@onready var back_button: Button = $Center/VBox/BackButton
@onready var p1_preview_box: ColorRect = $Center/VBox/PreviewRow/P1Side/P1PreviewBox
@onready var p1_preview_image: TextureRect = $Center/VBox/PreviewRow/P1Side/P1PreviewBox/P1PreviewImage
@onready var p1_preview_label: Label = $Center/VBox/PreviewRow/P1Side/P1PreviewBox/P1PreviewLabel
@onready var p2_preview_box: ColorRect = $Center/VBox/PreviewRow/P2Side/P2PreviewBox
@onready var p2_preview_image: TextureRect = $Center/VBox/PreviewRow/P2Side/P2PreviewBox/P2PreviewImage
@onready var p2_preview_label: Label = $Center/VBox/PreviewRow/P2Side/P2PreviewBox/P2PreviewLabel

var _picking_p1: bool = true
## 아직 "확정" 버튼을 안 누른, 미리보기 칸에만 반영된 임시 선택. 빈 문자열이면 아무것도 안 고른 상태
var _pending_character: String = ""
var _thumb_buttons: Dictionary = {}  # {character_name: Button} — 선택 강조 표시용
var _is_spinning: bool = false

## 씬에 미리 놓아둔 FanTile들을 훑어서 character_key로 어떤 캐릭터인지 확인하고 클릭 시그널을 연결한다.
## 칸의 모양·위치는 전부 씬(.tscn)에 이미 정해져 있으므로 여기서는 안 건드린다
func _ready() -> void:
	for child in thumb_row.get_children():
		if not (child is FanTile):
			continue
		var tile: FanTile = child
		if tile.character_key == "":
			tile.pressed.connect(_on_random_pressed)
		else:
			tile.pressed.connect(_on_character_picked.bind(tile.character_key))
			_thumb_buttons[tile.character_key] = tile

	status_label.text = "P1(플레이어) 캐릭터를 선택하세요"

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
	if not GameState.has_portrait(character_name):
		image.texture = null
		return
	image.texture = GameState.portrait_texture(character_name)
	var parent_box := image.get_parent()
	if parent_box is Control:
		parent_box.clip_contents = true
	# 그리드 타일과 같은 편집 씬 값으로 프레이밍 (큰 미리보기 상자 크기에 맞춰 환산)
	GameState.frame_portrait(image, character_name, PREVIEW_BOX_SIZE)

## 슬롯머신처럼 캐릭터가 빠르게 바뀌다가 점점 느려지며 멈추는 연출. 멈춘 결과가 그대로 임시 선택(pending)이 된다.
## 대기는 이 노드(CharacterSelect)의 자식 Timer로 만들어서, 연출 도중 뒤로 나가 씬이 정리되면
## Timer도 같이 사라져 남은 연출이 그냥 실행되지 않고 끝난다(에러 없이 조용히 중단됨)
func _on_random_pressed() -> void:
	if _is_spinning:
		return
	_is_spinning = true
	confirm_button.disabled = true
	_set_thumb_buttons_disabled(true)

	# GameState.CHARACTERS 전체가 아니라 실제로 이 화면에 칸이 있는 캐릭터만 후보로 삼는다 —
	# 로컬 대전에서 뺀 캐릭터(주인공 등)는 칸 자체가 없으므로 랜덤에도 안 나와야 한다
	var keys: Array = _thumb_buttons.keys()
	var start_index: int = randi() % keys.size()
	var spin_count: int = keys.size() * 3  # 최소 3바퀴는 돌고 멈추게
	var final_key: String = keys[start_index]
	for i in range(spin_count):
		final_key = keys[(start_index + i) % keys.size()]
		_show_preview(final_key)
		_focus_thumb(final_key)
		var progress := float(i) / float(spin_count - 1)
		await _wait(lerp(0.0133, 0.22, progress))

	_set_thumb_buttons_disabled(false)
	_is_spinning = false
	_on_character_picked(final_key)

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
