extends Node

## 게임 전역 상태 오토로드 — 캐릭터/맵 선택 화면과 실제 대전 씬 사이에서 선택값을 들고 다닌다.

## 선택 가능한 캐릭터 (표시 이름 -> 씬 경로)
const CHARACTERS := {
	"촉법소년": "res://characters/chokbeopsonyeon/Chokbeopsonyeon.tscn",
	"악플러": "res://characters/akpeulleo/Akpeulleo.tscn",
	"주정뱅이": "res://characters/jujeongbaengi/Jujeongbaengi.tscn",
	"고양이 아주머니": "res://characters/catmom/CatMom.tscn",
	"지하철 아저씨": "res://characters/subwayvillain/SubwayVillain.tscn",
	"층간소음 청년": "res://characters/floornoise/FloorNoise.tscn",
	"주인공": "res://characters/gymbro/GymBro.tscn",  # 폴더·씬 이름은 예전 이름(헬스장 죽돌이=GymBro) 그대로다 — 표시 이름만 바꿈. 기본공격·스킬1(LivingShadowSkill)·스킬2(BackSuplexSkill)는 구현됨, 궁극기만 아직 빈 Skill.gd 기본값(오픈 이슈)
}

## 스토리 모드의 주인공(2026-09-10 확정, 표시 이름은 그날 안에 "헬스장 죽돌이"→"주인공"으로 다시 바뀜) —
## 다른 6명은 스토리에서 맞서 싸우는 "빌런" 상대(STORY_OPPONENTS)고, 이 캐릭터만 플레이어가 조작하는 주인공이다.
## 그래서 로컬 대전(PvP)의 캐릭터 선택에서는 빠진다(CharacterSelect.gd가 이 이름을 걸러낸다) — 대신
## 스토리 모드에서는 고를 필요 없이 항상 이 캐릭터로 시작한다(EpisodeSelect.gd가 에피소드를 고르는 순간
## 바로 이 캐릭터를 P1으로 확정한다). 훈련장은 로스터 전체를 다 테스트해봐야 하는 개발 도구라 이 제외 대상에서 예외다
const PROTAGONIST_NAME := "주인공"

## 아직 캐릭터별 초상화가 없어서, 구분이 되도록 캐릭터마다 고정 색을 하나씩 지정해둔다.
## CharacterSelect(선택 화면)와 FighterPanel(대전 중 HUD)이 같이 쓴다. 목록에 없는 캐릭터는 DEFAULT_COLOR로 표시된다
const CHARACTER_COLORS := {
	"촉법소년": Color(0.95, 0.85, 0.2),
	"악플러": Color(0.85, 0.25, 0.25),
	"주정뱅이": Color(0.8, 0.5, 0.2),
	"고양이 아주머니": Color(0.9, 0.55, 0.7),
	"지하철 아저씨": Color(0.3, 0.65, 0.55),
	"층간소음 청년": Color(0.3, 0.5, 0.85),
	"주인공": Color(0.55, 0.6, 0.65),
}
const DEFAULT_COLOR := Color(0.35, 0.35, 0.4)

## 정면 초상화 그림이 있는 캐릭터만 등록 — CharacterSelect가 이 목록에 있으면 이미지로,
## 없으면(아직 그림이 없는 캐릭터) 위 CHARACTER_COLORS 색상 타일로 대신 보여준다
const PORTRAITS := {
	"촉법소년": "res://sprite/축법소년/축법소년 정면.png",
	"주정뱅이": "res://sprite/주정뱅이/몸/주정뱅이얼굴정면.png",
	"악플러": "res://sprite/악플러/몸/악플러정면머리.png",
	"층간소음 청년": "res://sprite/층간소음/층간소음정면샷.png",
	"지하철 아저씨": "res://sprite/지하철빌/지하철빌런정면.png",
	"고양이 아주머니": "res://sprite/캣/고양이아줌마정면.png",
}

## 초상화 프레이밍(크기·위치) 편집 씬 — 에디터에서 열어 각 캐릭터 Portrait를 조절한다.
## 게임은 이 씬에서 초상화 텍스처·배율·위치를 그대로 읽어 쓰므로 "에디터에서 보이는 대로" 게임에 나온다
const PORTRAIT_FRAMES_PATH := "res://ui/PortraitFrames.tscn"
## PortraitFrames.tscn의 프레임 한 칸 크기(px). Portrait를 드래그한 거리를 이 크기 대비 비율로 환산할 때 기준으로 쓴다
const PORTRAIT_FRAME_SIZE := Vector2(200, 180)

## 선택 가능한 맵 (표시 이름 -> 씬 경로)
const MAPS := {
	"편의점 앞": "res://maps/ConvenienceStore.tscn",
	"PC방": "res://maps/PcBang.tscn",
	"학교 옥상 (링아웃)": "res://maps/SchoolRooftop.tscn",
	"지하철 승강장 (열차)": "res://maps/SubwayPlatform.tscn",
	"아파트 단지 놀이터": "res://maps/ApartmentPlayground.tscn",
	"악플러의 방(쓰레기집)": "res://maps/TrashRoom.tscn",
	"층간소음 아파트": "res://maps/NoisyApartment.tscn",
	"놀이터": "res://maps/Playground.tscn",
	"지하철 선로": "res://maps/SubwayTrack.tscn",
	"공사현장 (내리찍기)": "res://maps/CollapsingApartment.tscn",
}

## 스토리 모드에서 순서대로 맞서는 상대 목록 (캐릭터 씬 경로) — 로스터 등록 순서 그대로 사용
const STORY_OPPONENTS: Array = [
	"res://characters/chokbeopsonyeon/Chokbeopsonyeon.tscn",
	"res://characters/akpeulleo/Akpeulleo.tscn",
	"res://characters/jujeongbaengi/Jujeongbaengi.tscn",
	"res://characters/catmom/CatMom.tscn",
	"res://characters/subwayvillain/SubwayVillain.tscn",
	"res://characters/floornoise/FloorNoise.tscn",
]
## 스토리 모드에서 에피소드별로 쓰는 맵 (STORY_OPPONENTS와 같은 순서). 캐릭터 테마에 맞춰 임의로 배정함(2026-09-11) — 확정 기획 아님, 나중에 바뀔 수 있음
const STORY_MAPS: Array = [
	"res://maps/Playground.tscn", # 촉법소년 — 놀이터
	"res://maps/TrashRoom.tscn", # 악플러 — 자기 방(쓰레기집)
	"res://maps/ConvenienceStore.tscn", # 주정뱅이 — 편의점 앞
	"res://maps/SchoolRooftop.tscn", # 고양이 아주머니 — 학교 옥상(길고양이가 잘 다니는 곳)
	"res://maps/SubwayPlatform.tscn", # 지하철 아저씨 — 지하철 승강장
	"res://maps/NoisyApartment.tscn", # 층간소음 청년 — 층간소음 아파트
]

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
## 스토리 모드에서 지금 몇 번째 상대인지 (STORY_OPPONENTS 인덱스) — EpisodeSelect에서 고르면 여기에 저장된다
var story_index: int = 0
## 스토리 모드에서 각 상대(STORY_OPPONENTS와 같은 순서)를 깼는지 여부. reset_story_progress()로 초기화
var story_cleared: Array = []

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

## PortraitFrames.tscn에서 읽어둔 캐릭터별 초상화 텍스처와, 프레임 대비 얼굴 네모의
## 중심·크기 비율(둘 다 Vector2). _ready에서 채운다
var _portrait_texture: Dictionary = {}
var _portrait_rect_center: Dictionary = {}
var _portrait_rect_size: Dictionary = {}

func _ready() -> void:
	_load_env()
	_load_settings()
	_load_portrait_frames()

## 새 대전을 시작하기 전에 라운드 스코어를 초기화한다
func reset_round_wins() -> void:
	p1_round_wins = 0
	p2_round_wins = 0

## 스토리 모드를 처음부터 새로 시작할 때 호출 — 모든 에피소드를 안 깬 상태로 되돌린다
func reset_story_progress() -> void:
	story_cleared.clear()
	for i in STORY_OPPONENTS.size():
		story_cleared.append(false)

## index번째 에피소드가 지금 고를 수 있는 상태인지 — 1번(0)은 항상 열려있고,
## 그 다음부터는 바로 앞 에피소드를 깨야 열린다
func is_episode_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	# TODO(임시): 프로토타입 영상 촬영용으로 2번(악플러/지하철 승강장) 에피소드를 처음부터 열어둠 — 촬영 끝나면 지울 것
	if index == 1:
		return true
	return index - 1 < story_cleared.size() and story_cleared[index - 1]

## index번째 상대를 이겼다고 기록한다 (다음 에피소드가 열리는 조건)
func mark_story_cleared(index: int) -> void:
	if index >= 0 and index < story_cleared.size():
		story_cleared[index] = true

## 스토리 모드의 모든 상대를 다 깼는지
func is_story_complete() -> bool:
	return story_cleared.size() == STORY_OPPONENTS.size() and not story_cleared.has(false)

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
	event.physical_keycode = physical_keycode as Key
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

## PortraitFrames.tscn을 인스턴스해서 각 캐릭터 프레임 안 "Portrait" 노드의 텍스처와,
## 그 노드가 프레임(200x180) 안에서 차지하는 네모(위치+크기)를 읽어둔다.
## 에디터에서 핸들로 리사이즈하든 Scale을 바꾸든 둘 다 반영되도록, 노드의 실제 네모
## (offset으로 계산한 rect)에 scale까지 곱해서 "보이는 크기"로 환산한다.
## 트리에 넣지 않아도 읽히도록 계산이 필요한 size 대신 씬에 저장된 offset 값을 직접 쓴다
func _load_portrait_frames() -> void:
	var packed: PackedScene = load(PORTRAIT_FRAMES_PATH)
	if packed == null:
		return
	var frames := packed.instantiate()
	for frame in frames.get_children():
		if not (frame is Control):
			continue
		var portrait := frame.get_node_or_null("Portrait")
		if portrait == null or not (portrait is TextureRect):
			continue
		var rect_pos := Vector2(portrait.offset_left, portrait.offset_top)
		var rect_size := Vector2(portrait.offset_right, portrait.offset_bottom) - rect_pos
		var eff_size: Vector2 = rect_size * portrait.scale.x  # 핸들 리사이즈 + Scale 둘 다 반영
		var eff_center: Vector2 = rect_pos + rect_size * 0.5  # scale은 프레임 중심 기준이라 중심은 유지로 근사
		_portrait_texture[frame.name] = portrait.texture
		_portrait_rect_center[frame.name] = eff_center / PORTRAIT_FRAME_SIZE
		_portrait_rect_size[frame.name] = eff_size / PORTRAIT_FRAME_SIZE
	frames.free()

## 이 캐릭터의 초상화 그림이 편집 씬에 등록돼 있는지
func has_portrait(character_name: String) -> bool:
	return _portrait_texture.has(character_name) and _portrait_texture[character_name] != null

## 이 캐릭터의 초상화 텍스처 (없으면 null)
func portrait_texture(character_name: String) -> Texture2D:
	return _portrait_texture.get(character_name, null)

## 초상화 TextureRect를 box_size 상자 안에서 캐릭터별로 프레이밍한다.
## image는 상자를 꽉 채우는 앵커(anchor_right=1, anchor_bottom=1)에 놓여 있다고 가정한다.
## 편집 씬(PortraitFrames.tscn)에서 얼굴 네모가 프레임 안에서 차지한 위치·크기 비율을
## 이 상자 크기에 그대로 옮겨, 그 네모 안에 그림을 가운데 맞춰 넣는다(보이는 대로 게임에 나온다)
func frame_portrait(image: TextureRect, character_name: String, box_size: Vector2) -> void:
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.scale = Vector2.ONE
	var center_frac: Vector2 = _portrait_rect_center.get(character_name, Vector2(0.5, 0.5))
	var size_frac: Vector2 = _portrait_rect_size.get(character_name, Vector2.ONE)
	var rect_size: Vector2 = size_frac * box_size
	var rect_pos: Vector2 = center_frac * box_size - rect_size * 0.5
	# anchor_left/top=0, anchor_right/bottom=1 기준: 왼쪽·위는 그대로, 오른쪽·아래는 상자 끝에서의 안쪽 여백
	image.offset_left = rect_pos.x
	image.offset_top = rect_pos.y
	image.offset_right = rect_pos.x + rect_size.x - box_size.x
	image.offset_bottom = rect_pos.y + rect_size.y - box_size.y
