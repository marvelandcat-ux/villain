extends Node

## 게임 전역 상태 오토로드 — 캐릭터/맵 선택 화면과 실제 대전 씬 사이에서 선택값을 들고 다닌다.

## 선택 가능한 캐릭터 (표시 이름 -> 씬 경로)
const CHARACTERS := {
	"잼민이": "res://characters/jaemini/Jaemini.tscn",
	"악플러": "res://characters/akpeulleo/Akpeulleo.tscn",
	"주정뱅이": "res://characters/jujeongbaengi/Jujeongbaengi.tscn",
	"캣맘": "res://characters/catmom/CatMom.tscn",
	"지하철빌런": "res://characters/subwayvillain/SubwayVillain.tscn",
	"층간피해빌런": "res://characters/floornoise/FloorNoise.tscn",
}

## 아직 캐릭터별 초상화가 없어서, 구분이 되도록 캐릭터마다 고정 색을 하나씩 지정해둔다.
## CharacterSelect(선택 화면)와 FighterPanel(대전 중 HUD)이 같이 쓴다. 목록에 없는 캐릭터는 DEFAULT_COLOR로 표시된다
const CHARACTER_COLORS := {
	"잼민이": Color(0.95, 0.85, 0.2),
	"악플러": Color(0.85, 0.25, 0.25),
	"주정뱅이": Color(0.8, 0.5, 0.2),
	"캣맘": Color(0.9, 0.55, 0.7),
	"지하철빌런": Color(0.3, 0.65, 0.55),
	"층간피해빌런": Color(0.3, 0.5, 0.85),
}
const DEFAULT_COLOR := Color(0.35, 0.35, 0.4)

## 정면 초상화 그림이 있는 캐릭터만 등록 — CharacterSelect가 이 목록에 있으면 이미지로,
## 없으면(아직 그림이 없는 캐릭터) 위 CHARACTER_COLORS 색상 타일로 대신 보여준다
const PORTRAITS := {
	"주정뱅이": "res://sprite/주정뱅이/몸/주정뱅이얼굴정면.png",
	"악플러": "res://sprite/악플러/몸/악플러정면머리.png",
}

## 선택 가능한 맵 (표시 이름 -> 씬 경로)
const MAPS := {
	"편의점 앞": "res://maps/ConvenienceStore.tscn",
	"PC방": "res://maps/PcBang.tscn",
	"학교 옥상 (링아웃)": "res://maps/SchoolRooftop.tscn",
	"지하철 승강장 (링아웃)": "res://maps/SubwayPlatform.tscn",
	"아파트 단지 놀이터": "res://maps/ApartmentPlayground.tscn",
	"악플러의 방(쓰레기집)": "res://maps/TrashRoom.tscn",
	"층간소음 아파트": "res://maps/NoisyApartment.tscn",
	"놀이터": "res://maps/Playground.tscn",
	"지하철 선로": "res://maps/SubwayTrack.tscn",
}

## 스토리 모드에서 순서대로 맞서는 상대 목록 (캐릭터 씬 경로) — 로스터 등록 순서 그대로 사용
const STORY_OPPONENTS: Array = [
	"res://characters/jaemini/Jaemini.tscn",
	"res://characters/akpeulleo/Akpeulleo.tscn",
	"res://characters/jujeongbaengi/Jujeongbaengi.tscn",
	"res://characters/catmom/CatMom.tscn",
	"res://characters/subwayvillain/SubwayVillain.tscn",
	"res://characters/floornoise/FloorNoise.tscn",
]
## 스토리 모드에서 매 상대전마다 쓰는 맵 (간단하게 고정)
const STORY_MAP_PATH := "res://maps/ConvenienceStore.tscn"

var p1_character_path: String = CHARACTERS.values()[0]
var p2_character_path: String = CHARACTERS.values()[1]
var selected_map_path: String = MAPS.values()[0]

## "story" 또는 "pvp"
var game_mode: String = "pvp"
## 이 라운드 수를 먼저 따내면 최종 승리 (예: 2 = 3판2선승제)
var rounds_to_win: int = 2
## 0이면 시간 제한 없음
var time_limit_seconds: int = 0
var p1_round_wins: int = 0
var p2_round_wins: int = 0
## 스토리 모드에서 지금 몇 번째 상대인지 (STORY_OPPONENTS 인덱스)
var story_index: int = 0

## .env 파일에서 불러온 Claude API 키. ClaudeAIController가 P2 AI 판단에 사용한다.
## .env는 git에 커밋하지 않는 로컬 파일이라(.env.example 참고) 파일이 없으면 빈 문자열로 남는다
var anthropic_api_key: String = ""

## 재배정 가능한 조작키 액션과 project.godot에 원래 박혀있던 기본 물리 키코드.
## ui/Settings.gd의 키 목록·초기화 버튼이 이 딕셔너리를 그대로 사용한다
const DEFAULT_KEYBINDS := {
	"p1_left": KEY_A, "p1_right": KEY_D, "p1_jump": KEY_W, "p1_down": KEY_S,
	"p1_basic_attack": KEY_F, "p1_skill_1": KEY_G, "p1_skill_2": KEY_H, "p1_ultimate": KEY_R,
	"p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_jump": KEY_UP, "p2_down": KEY_DOWN,
	"p2_basic_attack": KEY_L, "p2_skill_1": KEY_K, "p2_skill_2": KEY_J, "p2_ultimate": KEY_P,
}
const SETTINGS_PATH := "user://settings.cfg"

## 창 모드에서 고를 수 있는 해상도 (전부 16:9라 검은 여백 없이 꽉 채워짐)
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const DEFAULT_MASTER_VOLUME := 1.0

var is_fullscreen: bool = false
var resolution_index: int = 0
var master_volume: float = DEFAULT_MASTER_VOLUME

func _ready() -> void:
	_load_env()
	_load_settings()

## 새 대전을 시작하기 전에 라운드 스코어를 초기화한다
func reset_round_wins() -> void:
	p1_round_wins = 0
	p2_round_wins = 0

## res://.env 파일을 한 줄씩 읽어서 KEY=VALUE 형식을 파싱한다 (# 시작 줄은 주석으로 무시)
func _load_env() -> void:
	var path := "res://.env"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("=", true, 1)
		if parts.size() != 2:
			continue
		var key := parts[0].strip_edges()
		var value := parts[1].strip_edges()
		if key == "ANTHROPIC_API_KEY":
			anthropic_api_key = value

## user://settings.cfg에 저장된 값(조작키/그래픽/오디오)을 한 번에 불러와 적용한다.
## 파일이 없으면(한 번도 설정을 안 바꿈) project.godot·기본값 그대로 둔다
func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for action in DEFAULT_KEYBINDS.keys():
		if config.has_section_key("keybinds", action):
			_apply_keybind(action, config.get_value("keybinds", action))
	set_fullscreen(config.get_value("graphics", "fullscreen", is_fullscreen))
	set_resolution(config.get_value("graphics", "resolution_index", resolution_index))
	set_master_volume(config.get_value("audio", "master_volume", master_volume))

## user://settings.cfg의 한 항목을 갱신한다. 매번 새로 열고 닫아서 다른 항목을 덮어쓰지 않는다
func _save_setting(section: String, key: String, value) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # 파일이 없어도(첫 저장) 그냥 빈 ConfigFile로 계속 진행
	config.set_value(section, key, value)
	config.save(SETTINGS_PATH)

## action에 걸려있던 키 입력을 전부 지우고 물리 키코드 하나로 새로 등록한다
func _apply_keybind(action: String, physical_keycode: int) -> void:
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, event)

## ui/Settings.gd에서 키를 재배정할 때 호출한다. InputMap에 바로 반영하고 파일에도 저장해서 다음 실행에도 유지시킨다
func rebind_action(action: String, physical_keycode: int) -> void:
	_apply_keybind(action, physical_keycode)
	_save_setting("keybinds", action, physical_keycode)

## 모든 조작키를 project.godot 기본값으로 되돌리고 저장 파일도 그 값으로 덮어쓴다
func reset_keybindings() -> void:
	for action in DEFAULT_KEYBINDS.keys():
		var keycode: int = DEFAULT_KEYBINDS[action]
		_apply_keybind(action, keycode)
		_save_setting("keybinds", action, keycode)

## ui/Settings.gd의 전체화면 체크박스가 호출한다. 즉시 적용하고 저장한다
func set_fullscreen(enabled: bool) -> void:
	is_fullscreen = enabled
	get_window().mode = Window.MODE_FULLSCREEN if enabled else Window.MODE_WINDOWED
	_save_setting("graphics", "fullscreen", enabled)

## ui/Settings.gd의 해상도 드롭다운이 호출한다. 전체화면 중에는 창 크기를 바꿔도 의미가 없어서 창모드일 때만 실제로 적용한다
func set_resolution(index: int) -> void:
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	if not is_fullscreen:
		get_window().size = RESOLUTIONS[resolution_index]
	_save_setting("graphics", "resolution_index", resolution_index)

## ui/Settings.gd의 마스터 볼륨 슬라이더가 호출한다(0.0~1.0). 엔진의 Master 버스 자체를 조절하기 때문에
## 지금은 재생 중인 소리가 없어도, 나중에 효과음·배경음악이 추가되면 바로 이 값이 적용된다
func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	var bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(master_volume))
	_save_setting("audio", "master_volume", master_volume)
