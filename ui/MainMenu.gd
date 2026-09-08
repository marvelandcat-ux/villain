class_name MainMenu
extends Control

## 타이틀 화면 다음에 나오는 메인 메뉴.
## 왼쪽에 모드 버튼 4개(스토리 모드 / 대전 모드 / 조작 방법 / 설정),
## 오른쪽에 캐릭터 일러스트(ui/MenuIllust.tscn)가 파츠별로 따로 움직인다.
##
## 일러스트를 움직이는 건 각 일러스트 씬(MenuIllust / JaemminIllust)이 하고,
## 위치·크기는 씬에 저장된 값을 그대로 쓴다.
##
## 이름이 "Illust"로 시작하는 자식이 여러 개면 illust_swap_seconds마다 한 장씩 번갈아 보여준다 —
## **트리에 놓인 순서가 곧 보여주는 순서**라, 순서를 바꾸려면 씬 트리에서 노드를 위아래로 옮기면 된다.
## 이름이 "Background"로 시작하는 자식도 같은 방식으로 모아서 **순서대로 짝을 지어** 같이 바꾼다
## (0번 일러스트 <-> 0번 배경). 배경 수가 모자라면 그 일러스트는 배경을 안 바꾼다.
## 바뀔 때는 툭 끊기지 않게 illust_fade_seconds 동안 서로 겹치며 페이드된다.
## 일러스트는 Control이 아니라 Node2D다 — Control은 앵커 레이아웃이 매 프레임 position을 되돌려놔서
## 코드로 움직이면 서로 싸운다.

## 일러스트를 코드로 자동 배치할지. **꺼두는 게 기본**이다 — 끄면 씬에 저장된 위치·크기를 그대로 써서
## 에디터에서 보이는 그대로가 게임 화면이 된다(눈으로 끌어다 맞출 수 있다).
## 새 일러스트를 넣어 크기가 완전히 다를 때만 잠깐 켜서 자동으로 맞춘 뒤, 나온 값을 저장하고 다시 끈다
@export var auto_place_illustration: bool = false
## 자동 배치를 켰을 때: 그림 원본 크기에 상관없이 화면에서 이 높이(px)가 되도록 배율을 맞춘다
@export var illust_height: float = 620.0
## 자동 배치를 켰을 때: 화면에서 일러스트의 한가운데가 놓일 자리
@export var illust_center: Vector2 = Vector2(950, 380)

@export_group("일러스트 번갈아 보여주기")
## 일러스트 한 장을 보여주는 시간(초). 0이면 안 바꾸고 맨 앞 한 장만 계속 보여준다
@export var illust_swap_seconds: float = 10.0
## 다음 장으로 넘어갈 때 겹치며 바뀌는 시간(초). 0이면 툭 하고 바로 바뀐다
@export var illust_fade_seconds: float = 0.9

@onready var _illust: MenuIllust = $Illust
@onready var _confirm: ConfirmPopup = $ConfirmPopup

## 번갈아 보여줄 일러스트들과 그 짝이 되는 배경들 (트리 순서대로)
var _illusts: Array[Node2D] = []
var _backgrounds: Array[Node2D] = []
var _illust_index: int = 0
var _illust_time: float = 0.0
## 지금 페이드 중인지, 얼마나 진행됐는지, 어디로 넘어가는 중인지
var _fading: bool = false
var _fade_time: float = 0.0
var _next_index: int = 0

## 확인 창에서 "확인"을 눌렀을 때 실행할 함수. 취소하면 버려진다
var _pending: Callable = Callable()

func _ready() -> void:
	if auto_place_illustration:
		_place_illustration()
	_collect_illustrations()
	_confirm.confirmed.connect(_on_confirmed)
	_confirm.cancelled.connect(func(): _pending = Callable())
	# 키보드/패드로 바로 위아래 이동이 되도록 첫 버튼에 포커스를 준다
	$LeftPanel/Buttons/StoryButton.grab_focus()

## 이름이 "Illust"/"Background"로 시작하는 자식을 트리 순서대로 모으고, 첫 짝만 남기고 숨긴다
func _collect_illustrations() -> void:
	for child in get_children():
		if child is Node2D and child.name.begins_with("Illust"):
			_illusts.append(child)
		elif child is Node2D and child.name.begins_with("Background"):
			_backgrounds.append(child)
	for i in range(_illusts.size()):
		if i == 0:
			_show_pair(i, 1.0)
		else:
			_hide_pair(i)
	_illust_index = 0
	_illust_time = 0.0
	_fading = false

## i번째 일러스트와 그 짝 배경 (배경이 모자라면 null)
func _pair_background(i: int) -> Node2D:
	return _backgrounds[i] if i < _backgrounds.size() else null

func _show_pair(i: int, alpha: float) -> void:
	_illusts[i].visible = true
	_illusts[i].modulate.a = alpha
	var bg: Node2D = _pair_background(i)
	if bg:
		bg.visible = true
		bg.modulate.a = alpha

func _hide_pair(i: int) -> void:
	_illusts[i].visible = false
	_illusts[i].modulate.a = 1.0
	var bg: Node2D = _pair_background(i)
	if bg:
		bg.visible = false
		bg.modulate.a = 1.0

func _set_pair_alpha(i: int, alpha: float) -> void:
	_illusts[i].modulate.a = alpha
	var bg: Node2D = _pair_background(i)
	if bg:
		bg.modulate.a = alpha

func _process(delta: float) -> void:
	if _illusts.size() < 2 or illust_swap_seconds <= 0.0:
		return
	if _fading:
		_fade_time += delta
		var t: float = clampf(_fade_time / maxf(illust_fade_seconds, 0.001), 0.0, 1.0)
		# 가는 쪽과 오는 쪽이 겹치며 바뀐다
		_set_pair_alpha(_illust_index, 1.0 - t)
		_set_pair_alpha(_next_index, t)
		if t >= 1.0:
			_hide_pair(_illust_index)
			_illust_index = _next_index
			_fading = false
			_illust_time = 0.0
		return

	_illust_time += delta
	if _illust_time < illust_swap_seconds:
		return
	_next_index = (_illust_index + 1) % _illusts.size()
	_fading = true
	_fade_time = 0.0
	_show_pair(_next_index, 0.0)
	# 나타나는 순간부터 동작을 처음부터 돌린다 (그런 함수가 있는 일러스트만)
	var next: Node2D = _illusts[_next_index]
	if next.has_method("restart"):
		next.restart()

## 파츠들은 원본 캔버스 좌표(왼쪽 위가 0,0)로 그려지므로, 가운데가 illust_center에 오도록 밀어준다.
## auto_place_illustration을 켰을 때만 돈다 — 평소엔 씬에 저장된 위치·크기가 그대로 쓰인다
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
