class_name MainMenu
extends Control

## 타이틀 화면 다음에 나오는 메인 메뉴.
## 왼쪽에 모드 버튼 4개(스토리 모드 / 대전 모드 / 조작 방법 / 설정),
## 오른쪽에 캐릭터 일러스트가 숨쉬듯 조금씩 움직인다.
##
## 일러스트는 Control이 아니라 Sprite2D다 — Control은 앵커 레이아웃이 매 프레임 position을 되돌려놔서
## 코드로 흔들면 서로 싸운다. Node2D 계열은 레이아웃을 안 받으므로 좌표를 그대로 쓸 수 있다.

## 오른쪽에 크게 띄울 일러스트. 비워두면 GameState.PORTRAITS에서 fallback_character의 그림을 대신 쓴다
@export var illustration: Texture2D
## illustration을 비워뒀을 때 대신 보여줄 캐릭터 이름
@export var fallback_character: String = "주정뱅이"
## 그림 크기에 상관없이 화면에서 이 높이(px)가 되도록 자동으로 배율을 맞춘다
@export var illust_height: float = 560.0

@export_group("일러스트 움직임")
## 위아래로 숨쉬듯 움직이는 폭(px)
@export var sway_bob: float = 14.0
## 좌우로 흔들리는 폭(px)
@export var sway_side: float = 8.0
## 기울어지는 최대 각도(도)
@export var sway_tilt_deg: float = 1.6
## 한 번 왕복하는 데 걸리는 시간(초). 클수록 느긋하다
@export var sway_period: float = 4.5

@onready var _illust: Sprite2D = $Illust

var _time: float = 0.0
var _illust_rest: Vector2

func _ready() -> void:
	_illust_rest = _illust.position
	_setup_illustration()
	# 키보드/패드로 바로 위아래 이동이 되도록 첫 버튼에 포커스를 준다
	$LeftPanel/Buttons/StoryButton.grab_focus()

## 지정된 그림이 없으면 캐릭터 초상화로 대신 채우고, 어떤 크기의 그림이든 illust_height에 맞춘다
func _setup_illustration() -> void:
	if illustration == null:
		var path: String = GameState.PORTRAITS.get(fallback_character, "")
		if path != "" and ResourceLoader.exists(path):
			illustration = load(path)
	_illust.texture = illustration
	if illustration == null:
		return
	var height: float = float(illustration.get_height())
	if height > 0.0:
		_illust.scale = Vector2.ONE * (illust_height / height)

func _process(delta: float) -> void:
	if _illust.texture == null:
		return
	_time += delta
	var w: float = TAU / maxf(sway_period, 0.01)
	# 위아래·좌우·기울기의 주기를 서로 다르게 줘서 같은 자리로 딱딱 돌아오지 않게 한다
	_illust.position = _illust_rest + Vector2(
		sin(_time * w * 0.7) * sway_side,
		sin(_time * w) * sway_bob)
	_illust.rotation = deg_to_rad(sway_tilt_deg) * sin(_time * w * 0.5)

## 스토리 모드 — 라운드 수·시간제한이 고정이고 진행도를 처음부터 다시 시작한다
func _on_story_pressed() -> void:
	GameState.game_mode = "story"
	GameState.rounds_to_win = 2
	GameState.time_limit_seconds = 120
	GameState.reset_story_progress()
	GameState.reset_round_wins()
	get_tree().change_scene_to_file("res://ui/EpisodeSelect.tscn")

## 대전 모드 — 방 설정(선취 라운드/시간제한)부터 고른다
func _on_versus_pressed() -> void:
	GameState.game_mode = "pvp"
	GameState.reset_round_wins()
	get_tree().change_scene_to_file("res://ui/RoomSettings.tscn")

func _on_how_to_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/HowToPlay.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/Settings.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://ui/TitleScreen.tscn")
