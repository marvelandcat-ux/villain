class_name MainMenu
extends Control

## 타이틀 화면 다음에 나오는 메인 메뉴.
## 왼쪽에 모드 버튼 4개(스토리 모드 / 대전 모드 / 조작 방법 / 설정),
## 오른쪽에 캐릭터 일러스트(ui/MenuIllust.tscn)가 파츠별로 따로 움직인다.
##
## 일러스트를 움직이는 건 전부 MenuIllust.gd가 하고, 여기서는 위치와 크기만 잡는다.
## 일러스트는 Control이 아니라 Node2D다 — Control은 앵커 레이아웃이 매 프레임 position을 되돌려놔서
## 코드로 움직이면 서로 싸운다.

## 그림 원본 크기에 상관없이 화면에서 이 높이(px)가 되도록 배율을 자동으로 맞춘다
@export var illust_height: float = 620.0
## 화면에서 일러스트의 한가운데가 놓일 자리
@export var illust_center: Vector2 = Vector2(950, 380)

@onready var _illust: MenuIllust = $Illust
@onready var _confirm: ConfirmPopup = $ConfirmPopup

## 확인 창에서 "확인"을 눌렀을 때 실행할 함수. 취소하면 버려진다
var _pending: Callable = Callable()

func _ready() -> void:
	_place_illustration()
	_confirm.confirmed.connect(_on_confirmed)
	_confirm.cancelled.connect(func(): _pending = Callable())
	# 키보드/패드로 바로 위아래 이동이 되도록 첫 버튼에 포커스를 준다
	$LeftPanel/Buttons/StoryButton.grab_focus()

## 파츠들은 원본 캔버스 좌표(왼쪽 위가 0,0)로 그려지므로, 가운데가 illust_center에 오도록 밀어준다
func _place_illustration() -> void:
	var size: Vector2 = _illust.get_image_size()
	if size.y <= 0.0:
		return
	var factor: float = illust_height / size.y
	_illust.scale = Vector2.ONE * factor
	_illust.position = illust_center - size * factor * 0.5

func _on_story_pressed() -> void:
	_ask("스토리 모드를 플레이하시겠습니까?", _start_story)

func _on_versus_pressed() -> void:
	_ask("대전 모드를 플레이하시겠습니까?", _start_versus)

## 확인 창을 띄우고, 확인을 누르면 action을 실행한다
func _ask(message: String, action: Callable) -> void:
	_pending = action
	_confirm.open(message)

func _on_confirmed() -> void:
	if _pending.is_valid():
		_pending.call()
	_pending = Callable()

## 스토리 모드 — 라운드 수·시간제한이 고정이고 진행도를 처음부터 다시 시작한다
func _start_story() -> void:
	GameState.game_mode = "story"
	GameState.rounds_to_win = 2
	GameState.time_limit_seconds = 120
	GameState.reset_story_progress()
	GameState.reset_round_wins()
	get_tree().change_scene_to_file("res://ui/EpisodeSelect.tscn")

## 대전 모드 — 방 설정(선취 라운드/시간제한)부터 고른다
func _start_versus() -> void:
	GameState.game_mode = "pvp"
	GameState.reset_round_wins()
	get_tree().change_scene_to_file("res://ui/RoomSettings.tscn")

func _on_how_to_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/HowToPlay.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/Settings.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if _confirm.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://ui/TitleScreen.tscn")
