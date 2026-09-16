class_name CharacterSelect
extends Control

## 위쪽 큰 미리보기 상자 크기 (CharacterSelect.tscn의 P1/P2 PreviewBox custom_minimum_size와 같은 값 — 정사각형)
const PREVIEW_BOX_SIZE := Vector2(300, 300)

## 인게임 리그는 아주 작게(몸 33x30 / 머리 55x55) 그려져 있어서, 상자 안에서 잘 보이도록 이만큼 키운다
const PREVIEW_RIG_SCALE := 2.8
## 상자 안에서 리그 원점이 놓일 자리 — x는 가운데, y는 발이 상자 아래쪽 근처(이름표 아래)에 오도록 잡은 값
const PREVIEW_RIG_ORIGIN := Vector2(150, 210)

## P1/P2 차례에 따라 바뀌는 배경 그림
const P1_BACKGROUND := "res://sprite/대전모드/배경.png"
const P2_BACKGROUND := "res://sprite/대전모드/배경2.png"

## 대전 모드(pvp) 전용 화면이다. P1(플레이어) 캐릭터를 먼저 고르고, 이어서 P2 캐릭터를 고르면 맵 선택 화면으로 넘어간다.
## (예전엔 옛 스토리 모드도 이 화면을 같이 썼는데, 2026-09-12 스토리 모드를 새로 짜면서 그 분기를 걷어냈다)
## 아래쪽 캐릭터 목록에서 하나를 누르면 위쪽 P1/P2 미리보기 칸에 이름과 색이 채워지는 방식
##
## 목록 칸(ThumbRow 밑 FanTile들)은 코드로 만들지 않고 씬에 캐릭터마다 별개의 노드로 미리 놓아뒀다 —
## 사다리꼴 모양이 서로 이어지도록 칸마다 corners(꼭짓점)를 직접 잡아둔 것이라, 모양을 바꾸고 싶으면
## 에디터에서 그 노드의 corners/position을 직접 조절하면 된다(FanTile.gd 참고. 일반 칸은 전부 같은
## 평행사변형 모양이라 하나를 복사-붙여넣기해서 새 칸을 만들 수 있다). 여기서는 character_key를 보고
## 어떤 GameState.CHARACTERS 캐릭터인지 연결만 한다 — character_key가 빈 칸은 "?" 랜덤 칸으로 취급

@onready var background: Sprite2D = $Background
@onready var status_label: Label = $Center/VBox/StatusLabel
@onready var thumb_row: Control = $Center/VBox/ThumbRow
@onready var confirm_button: Button = $Center/VBox/ConfirmButton
@onready var back_button: Button = $BackButton
@onready var p1_preview_box: Control = $Center/VBox/PreviewRow/P1Side/P1PreviewBox
@onready var p1_preview_label: Label = $Center/VBox/PreviewRow/P1Side/P1PreviewBox/P1PreviewLabel
@onready var p2_preview_box: Control = $Center/VBox/PreviewRow/P2Side/P2PreviewBox
@onready var p2_preview_label: Label = $Center/VBox/PreviewRow/P2Side/P2PreviewBox/P2PreviewLabel

var _picking_p1: bool = true
## 아직 "확정" 버튼을 안 누른, 미리보기 칸에만 반영된 임시 선택. 빈 문자열이면 아무것도 안 고른 상태
var _pending_character: String = ""
var _thumb_buttons: Dictionary = {}  # {character_name: Button} — 선택 강조 표시용
var _is_spinning: bool = false
## 지금 P1/P2 미리보기 상자에 떠 있는 리그 인스턴스 — 캐릭터가 바뀌면 이걸 지우고 새로 만든다
var _p1_rig: Node2D = null
var _p2_rig: Node2D = null

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
			tile.gui_input.connect(_on_tile_gui_input.bind(tile.character_key))
			_thumb_buttons[tile.character_key] = tile

	status_label.text = "P1(플레이어) 캐릭터를 선택하세요"
	background.texture = load(P1_BACKGROUND)

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

## 칸을 더블클릭하면 고르는 동시에 바로 확정한다 — "확정" 버튼을 따로 누를 필요 없이 한 번에 넘어간다.
## FanTile은 Button.pressed로는 더블클릭을 구분 못 해서, 원시 입력(gui_input)에서 직접 확인한다
func _on_tile_gui_input(event: InputEvent, character_name: String) -> void:
	if _is_spinning:
		return
	if event is InputEventMouseButton and event.pressed and event.double_click:
		_on_character_picked(character_name)
		_on_confirm_pressed()

## 미리보기 칸에 캐릭터 이름·전신을 반영한다(선택 확정 여부와는 무관 — 룰렛 연출 중에도 이걸로 화면을 갱신함).
## P1은 기본 방향(오른쪽), P2는 좌우로 뒤집어서 — 화면 가운데(VS)를 마주 보게 한다
func _show_preview(character_name: String) -> void:
	if _picking_p1:
		p1_preview_label.text = character_name
		_p1_rig = _apply_rig_preview(p1_preview_box, _p1_rig, character_name, 1.0)
	else:
		p2_preview_label.text = character_name
		_p2_rig = _apply_rig_preview(p2_preview_box, _p2_rig, character_name, -1.0)

## 캐릭터의 인게임 몸(BodyRig)을 미리보기 상자에 띄운다 — 상자는 더 이상 색칠된 네모가 아니라 빈 Control이고,
## 그 위에 실제 대전에서 쓰는 리그를 얹어 "인게임에서 보이는 그대로"의 전신을 보여준다.
## Fighter가 없으니 BodyRig.gd는 걷지 않고 가만히 서서 숨쉬는 동작만 돈다 — 정지 미리보기로 딱 좋다.
## old_rig가 있으면 먼저 지우고, 새로 만든 인스턴스를 돌려준다(호출하는 쪽이 다음 번 old_rig로 넘겨줌).
## facing이 음수면 좌우로 뒤집는다 — BodyRig는 Fighter가 없을 땐 scale.x 부호를 안 건드리므로
## 여기서 한 번 정해두면 계속 그 방향을 유지한다
func _apply_rig_preview(box: Control, old_rig: Node2D, character_name: String, facing: float) -> Node2D:
	if is_instance_valid(old_rig):
		old_rig.queue_free()
	if not GameState.has_character_rig(character_name):
		return null
	var scene: PackedScene = GameState.character_rig_scene(character_name)
	var rig: Node2D = scene.instantiate()
	box.add_child(rig)
	box.move_child(rig, 0)  # 이름표(P#PreviewLabel)보다 먼저 그려서 이름표가 캐릭터 위에 뜨게 한다
	box.clip_contents = true
	rig.scale = Vector2(PREVIEW_RIG_SCALE * facing, PREVIEW_RIG_SCALE)
	rig.position = PREVIEW_RIG_ORIGIN
	return rig

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

## "확정" 버튼을 눌렀을 때만(임시 선택 단계가 아니라) 그 칸에 파동 효과를 재생한다
func _on_confirm_pressed() -> void:
	if _pending_character == "":
		return
	var confirmed_tile: FanTile = _thumb_buttons.get(_pending_character)
	if confirmed_tile:
		SelectionRipple.spawn(confirmed_tile, confirmed_tile.ripple_corners())
	var path: String = GameState.CHARACTERS[_pending_character]
	if _picking_p1:
		GameState.p1_character_path = path
		_picking_p1 = false
		status_label.text = "P1: %s 확정! P2(AI) 캐릭터를 선택하세요" % _pending_character
		_pending_character = ""
		confirm_button.disabled = true
		_update_highlight()
		background.texture = load(P2_BACKGROUND)
	else:
		GameState.p2_character_path = path
		# 파동이 다 보이도록 잠깐 기다렸다가 맵 선택 화면으로 넘어간다
		await _wait(SelectionRipple.total_duration())
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
