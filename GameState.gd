extends Node

## 게임 전역 상태 오토로드 — 캐릭터/맵 선택 화면과 실제 대전 씬 사이에서 선택값을 들고 다닌다.

## 선택 가능한 캐릭터 (표시 이름 -> 씬 경로)
const CHARACTERS := {
	"금쪽이": "res://characters/chokbeopsonyeon/Chokbeopsonyeon.tscn",
	"악플러": "res://characters/akpeulleo/Akpeulleo.tscn",
	"주정뱅이": "res://characters/jujeongbaengi/Jujeongbaengi.tscn",
	"고양이 아주머니": "res://characters/catmom/CatMom.tscn",
	"지하철 아저씨": "res://characters/subwayvillain/SubwayVillain.tscn",
	"층간소음 빌런": "res://characters/floornoise/FloorNoise.tscn",
	"일진": "res://characters/iljin/Iljin.tscn",
}

## **대전 선택 화면에는 안 띄우고 훈련장에서만 고를 수 있는 캐릭터**(2026-09-13 사용자 결정).
## 스토리에서만 쓰는데 스킬 3칸이 아직 빈 껍데기라, 대전 로스터에 올리면 고른 사람이 손해를 본다.
## 스킬을 다 만들면 위 CHARACTERS로 옮기고 여기서 지우면 된다
const TRAINING_ONLY_CHARACTERS := {
	"주인공": "res://characters/police/Police.tscn",
}

## **숨겨진 캐릭터** — 캐릭터 선택창에서 **캐릭터마다 정해진 커맨드**를 치면 그 캐릭터 칸이 아래에 뜬다
## (어떤 키를 치는지는 CharacterSelect.gd의 SECRET_CODES. 황근출은 aaddssww, 인베이전은 한글로 "인베이전").
## 타이틀 구경 모드·도감 같은 CHARACTERS 전용 목록엔 안 나온다
const HIDDEN_CHARACTERS := {
	"황근출 해병": "res://characters/hwanggeunchul/Hwanggeunchul.tscn",
	"인베이전": "res://characters/invasion/Invasion.tscn",
}

## 훈련장 드롭다운에 쓰는 전체 목록 = 대전 로스터 + 훈련장 전용 + 숨겨진 캐릭터.
## Dictionary는 넣은 순서를 지키므로 드롭다운 순서와 인덱스가 항상 같다
func training_characters() -> Dictionary:
	var all: Dictionary = CHARACTERS.duplicate()
	all.merge(TRAINING_ONLY_CHARACTERS)
	all.merge(HIDDEN_CHARACTERS)
	return all

## 표시 이름으로 캐릭터 씬 경로를 찾는다(로스터·훈련장 전용·숨겨진 캐릭터 전부). 없으면 빈 문자열
func character_path(character_name: String) -> String:
	return str(training_characters().get(character_name, ""))

## 아직 캐릭터별 초상화가 없어서, 구분이 되도록 캐릭터마다 고정 색을 하나씩 지정해둔다.
## CharacterSelect(선택 화면)와 FighterPanel(대전 중 HUD)이 같이 쓴다. 목록에 없는 캐릭터는 DEFAULT_COLOR로 표시된다
const CHARACTER_COLORS := {
	"금쪽이": Color(0.95, 0.85, 0.2),
	"악플러": Color(0.85, 0.25, 0.25),
	"주정뱅이": Color(0.8, 0.5, 0.2),
	"고양이 아주머니": Color(0.9, 0.55, 0.7),
	"지하철 아저씨": Color(0.3, 0.65, 0.55),
	"층간소음 빌런": Color(0.3, 0.5, 0.85),
	"일진": Color(0.25, 0.3, 0.5),
	"주인공": Color(0.2, 0.35, 0.7),   # 스토리 주인공(경찰) — 대전 로스터엔 없고 훈련장에서만 고른다
	"황근출 해병": Color(0.4, 0.45, 0.35),   # 숨겨진 캐릭터
	"인베이전": Color(0.45, 0.12, 0.14),   # 숨겨진 캐릭터 — 돌갑옷의 붉은 균열 색
}
const DEFAULT_COLOR := Color(0.35, 0.35, 0.4)

## 정면 초상화 그림이 있는 캐릭터만 등록 — CharacterSelect가 이 목록에 있으면 이미지로,
## 없으면(아직 그림이 없는 캐릭터) 위 CHARACTER_COLORS 색상 타일로 대신 보여준다
const PORTRAITS := {
	"금쪽이": "res://sprite/축법소년/축법소년 정면.png",
	"주정뱅이": "res://sprite/주정뱅이/몸/주정뱅이얼굴정면.png",
	"악플러": "res://sprite/악플러/몸/악플러정면머리.png",
	"층간소음 빌런": "res://sprite/층간소음/층간소음정면.png",
	"지하철 아저씨": "res://sprite/지하철빌/지하철빌런정면.png",
	"고양이 아주머니": "res://sprite/고양이 아줌마/고양이아줌마정면.png",
	"일진": "res://sprite/일진/정면일진.png",
	"황근출 해병": "res://sprite/황근출 해병/환근출 해병 정면.png",
	"인베이전": "res://sprite/인베이전/인베이전얼굴.png",
}

## 실제 대전에서 쓰는 몸(BodyRig) 씬 — 캐릭터 선택창의 큰 미리보기 칸에 "인게임 캐릭터 전신"으로 띄운다.
## Fighter 없이 이 씬만 인스턴스하면 BodyRig.gd가 부모를 Fighter로 못 찾아 조용히 idle(숨쉬기)만 돈다 —
## 그 자체가 딱 미리보기로 쓰기 좋은 정지 동작이라 별도 처리가 필요 없다. 6명 전원 등록되어 있다
const CHARACTER_RIGS := {
	"금쪽이": "res://characters/chokbeopsonyeon/ChokbeopsonyeonRig.tscn",
	"악플러": "res://characters/akpeulleo/AkpeulleoRig.tscn",
	"주정뱅이": "res://characters/jujeongbaengi/JujeongbaengiRig.tscn",
	"고양이 아주머니": "res://characters/catmom/CatMomRig.tscn",
	"지하철 아저씨": "res://characters/subwayvillain/SubwayVillainRig.tscn",
	"층간소음 빌런": "res://characters/floornoise/FloorNoiseRig.tscn",
	"일진": "res://characters/iljin/IljinRig.tscn",
	"황근출 해병": "res://characters/hwanggeunchul/HwanggeunchulUniformRig.tscn",
	"인베이전": "res://characters/invasion/InvasionRig.tscn",
}

## 초상화 프레이밍(크기·위치) 편집 씬 — 에디터에서 열어 각 캐릭터 Portrait를 조절한다.
## 게임은 이 씬에서 초상화 텍스처·배율·위치를 그대로 읽어 쓰므로 "에디터에서 보이는 대로" 게임에 나온다
const PORTRAIT_FRAMES_PATH := "res://ui/PortraitFrames.tscn"
## PortraitFrames.tscn의 프레임 한 칸 크기(px). Portrait를 드래그한 거리를 이 크기 대비 비율로 환산할 때 기준으로 쓴다
const PORTRAIT_FRAME_SIZE := Vector2(200, 180)

## 선택 가능한 맵 (표시 이름 -> 씬 경로)
## **2026-09-25: 최종 맵을 다섯으로 줄였다**(사용자 결정) — 지하철역 / 놀이터 / 악플러의 집 / 헬스장 / 번화가.
## 2026-09-26에 헬스장·번화가도 배경 그림으로 만들어 다섯 개가 다 고를 수 있게 됐다.
##
## **여기엔 실제로 고를 수 있는 맵만 둔다.** MapSelect가 이 경로를 그대로 불러서 미리보기를 띄우기 때문에
## 빈 경로를 섞으면 맵 선택 화면이 깨진다. 아직 없는 맵은 아래 DEX_MAPS에만 있다.
##
## 목록에서 뺀 맵들(편의점 앞·PC방·학교 옥상·아파트 단지 놀이터·층간소음 아파트·지하철 선로·공사현장)은
## **씬 파일은 maps/에 그대로 남아 있다** — 되살리려면 여기에 다시 적기만 하면 된다
const MAPS := {
	"지하철역": "res://maps/SubwayPlatform.tscn",
	"놀이터": "res://maps/Playground.tscn",
	"악플러의 집": "res://maps/TrashRoom.tscn",
	"헬스장": "res://maps/Gym.tscn",
	"번화가": "res://maps/Downtown.tscn",
}

## 도감 맵 탭에 보여줄 목록 — 만들 예정인 맵까지 넣은 최종 5종이다.
## 경로가 비어 있으면 아직 안 만든 맵이라는 뜻이다(STORY_EPISODES의 빈 scene과 같은 규칙).
## 다 만들면 그 줄의 경로를 채우고 위 MAPS에도 같이 옮겨 적으면 된다
const DEX_MAPS := {
	"지하철역": "res://maps/SubwayPlatform.tscn",
	"놀이터": "res://maps/Playground.tscn",
	"악플러의 집": "res://maps/TrashRoom.tscn",
	"헬스장": "res://maps/Gym.tscn",
	"번화가": "res://maps/Downtown.tscn",
}


## 스토리 에피소드 목록 — **일시정지 화면의 스토리 목록이 이 순서 그대로 쓴다.**
## `scene`이 비어 있으면 아직 안 만든 자리(고를 수 없음)다. 새 이야기를 만들면 그 줄의 scene만 채우면 된다.
## **한 번도 클리어하지 않은 에피소드는 목록에서 이름 대신 자물쇠로 보인다**(사용자 지정, 2026-09-15)
const STORY_EPISODES := [
	{"id": "ep1", "name": "EP.1-첫 임무", "scene": "res://ui/story/StoryScene1.tscn"},
	{"id": "ep2", "name": "에피소드 2", "scene": ""},
	{"id": "ep3", "name": "에피소드 3", "scene": ""},
	{"id": "ep4", "name": "에피소드 4", "scene": ""},
	{"id": "ep5", "name": "에피소드 5", "scene": ""},
	{"id": "ep6", "name": "에피소드 6", "scene": ""},
]

## 도감 맵 상세 화면에 뜨는 맵 설명. 아직 안 쓴 맵은 여기 없으면 "아직 설명을 적지 않은 맵입니다"가 뜬다.
## 조작법이 아니라 **그 맵에서 무슨 일이 벌어지는지**를 적는다
const MAP_DESCRIPTIONS := {
	"지하철역": "가만히 서 있으면 안 되는 승강장. 30초쯤마다 열차가 들이닥치는데, 경고등이 깜빡이기 시작하면 5초 안에 양쪽 벤치 위로 올라가야 한다. 늦으면 가드도 소용없이 깔린 채로 반대편까지 실려 간다. 안전한 자리가 벤치 두 개뿐이라 싸움이 저절로 그 위로 몰린다.",
	"놀이터": "구름 발판 꼭대기에 왕관이 놓여 있다. 주운 쪽은 발이 빨라지고 주먹도 매워지지만 한 대만 맞아도 머리에서 튕겨 나가니, 훔치고 달아나고 다시 빼앗는 싸움이 된다. 정자 양옆 모래밭은 걸어서 지나면 발이 푹푹 빠지고(왕만 멀쩡하다), 한가운데 그네는 쉬지 않고 오가다 닿는 쪽을 팅 하고 튕겨낸다. 스프링 시소는 밟는 순간 솟구친다.",
	"악플러의 집": "쓰레기가 발목까지 쌓인 방. 12초쯤마다 형광등이 두어 번 깜빡이더니 방이 통째로 어두워진다. 안 보일 뿐 판정은 그대로라 깜깜한 채로 계속 맞는다. 그동안 빛이라고는 책상 모니터뿐이다. 발판이 세 단으로 걸쳐 있어서 위아래로 도망칠 길은 많은 편.",
	"헬스장": "밤늦은 헬스장 1층. 기구는 전부 배경이고 실제로는 아무 장치도 없는 맨바닥이다. 올라설 발판도 피할 구석도 없어서 처음부터 끝까지 정면으로 붙어야 한다. 맵이 도와주지 않는 만큼 실력 차가 그대로 드러난다.",
	"번화가": "쓰레기봉투가 산처럼 쌓인 24시 상가 앞 거리. 여기도 장치 없는 평지라 맵이 싸움에 끼어들 일이 없다. 배경만 시끄럽고 승부는 가장 단순해지는 곳.",
}

var p1_character_path: String = CHARACTERS.values()[0]
var p2_character_path: String = CHARACTERS.values()[1]
var selected_map_path: String = MAPS.values()[0]

## "story" 또는 "pvp". story면 Stage가 P2를 AI로 붙이고 HUD가 P2 조작키를 숨긴다
var game_mode: String = "pvp"
## **스토리 전투에서 이겼을 때 이어서 갈 장면**(2026-09-13). 스토리 장면(StoryFadeScene)이 대전으로 넘길 때
## 자기 `battle_win_scene`을 여기에 담아 두고, `Stage`가 최종 승리 판정에서 이 경로로 넘어간다.
## 비어 있으면 예전처럼 결과창(재시도/메뉴)에서 멈춘다 — 일반 대전은 이 값이 늘 비어 있다
var story_next_scene: String = ""
## **지금 진행 중인 스토리 에피소드 id.** 일시정지 화면 오른쪽 위에 이 에피소드 이름이 뜨고,
## 마지막 장면에 닿으면 이 id가 클리어로 기록된다. 대전 모드면 빈 문자열
var current_story_id: String = ""
## 한 번이라도 끝까지 본 에피소드 id들 (user://settings.cfg의 [story] cleared에 저장)
var story_cleared: PackedStringArray = PackedStringArray()

## --- 스토리 전투 난이도(2026-10-01) ---
## **이야기 장면(`StoryFadeScene`)이 정하고 `Stage`가 소환할 때 적용한다.** 에피소드마다 다른 값을 줄 수 있게
## 상수가 아니라 여기에 담아 넘긴다. 전부 1.0이면 평소 대전과 똑같다(대전 모드는 아예 안 읽는다).
## 스토리 상대(AI)의 최대 체력 배수 — 2.0이면 체력이 두 배라 싸움이 길어진다
var story_enemy_hp_scale: float = 1.0
## 스토리 상대(AI)가 **주는** 피해 배수 — 0.5면 반만 아프다
var story_enemy_damage_scale: float = 1.0
## 스토리 상대 AI의 솜씨. 1.0 = 평소 대전 AI 그대로, 0.0 = 아주 둔함(반응 느리고 거의 안 막는다)
var story_ai_skill: float = 1.0
## 이 라운드 수를 먼저 따내면 최종 승리 (예: 2 = 3판2선승제)
var rounds_to_win: int = 2
## 한 라운드 제한 시간(초). 0이면 시간 제한 없음.
## 기본 2분 — 방 설정에서 고르면 그 값으로 덮어쓴다
var time_limit_seconds: int = 120
var p1_round_wins: int = 0
var p2_round_wins: int = 0

## 모든 스킬 쿨타임에 곱하는 전역 배율(RoomSettings에서 설정). 1.0 = 원래 쿨타임, 0.5 = 절반, 2.0 = 두 배
var cooldown_multiplier: float = 1.0
## 꺼두면 스킬 클래시(연타 미니게임)를 벌이지 않고 양쪽 다 그대로 발동한다(RoomSettings에서 설정)
var clash_minigame_enabled: bool = true
## 꺼두면 아래 키를 눌러도 방어(Fighter.can_guard())가 아예 안 켜진다(RoomSettings에서 설정)
var guard_enabled: bool = true
## 꺼두면 방향키 두 번을 눌러도 대시(Fighter.can_dash())가 아예 안 나간다(RoomSettings에서 설정)
var dash_enabled: bool = true
## 꺼두면 **궁극기 컷인 연출**을 건너뛰고 바로 궁이 나간다(RoomSettings에서 설정, 2026-10-05).
## 자기 연출을 가진 궁(층간소음 영역전개)은 이 값과 상관없이 제 연출을 그대로 보여준다
var ultimate_cutin_enabled: bool = true
## 꺼두면 **라운드 승패 띠**(평행사변형 배너)를 건너뛴다(RoomSettings에서 설정, 2026-10-05).
## 최종 결과 화면은 그대로 뜬다 — 그건 연출이 아니라 결과 보고다
var result_cutscene_enabled: bool = true
## 켜면 대전 모드(pvp)의 P2를 컴퓨터(규칙 기반 AIController)가 조종한다(RoomSettings "상대" 줄, 2026-09-27).
## 스토리 모드는 이 값과 상관없이 항상 P2가 AI(ClaudeAIController)다
var vs_ai: bool = false

## .env 파일에서 불러온 Claude API 키. ClaudeAIController가 P2 AI 판단에 사용한다.
## .env는 git에 커밋하지 않는 로컬 파일이라(.env.example 참고) 파일이 없으면 빈 문자열로 남는다
var anthropic_api_key: String = ""

## 재배정 가능한 조작키 액션과 project.godot에 원래 박혀있던 기본 물리 키코드.
## ui/Settings.gd의 키 목록·초기화 버튼이 이 딕셔너리를 그대로 사용한다
const DEFAULT_KEYBINDS := {
	"p1_left": KEY_A, "p1_right": KEY_D, "p1_jump": KEY_W, "p1_down": KEY_S,
	"p1_basic_attack": KEY_F, "p1_skill_1": KEY_G, "p1_skill_2": KEY_H, "p1_ultimate": KEY_R,
	"p1_map_skill": KEY_E,
	"p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_jump": KEY_UP, "p2_down": KEY_DOWN,
	"p2_basic_attack": KEY_L, "p2_skill_1": KEY_SEMICOLON, "p2_skill_2": KEY_APOSTROPHE,
	"p2_ultimate": KEY_BRACKETRIGHT, "p2_map_skill": KEY_BRACKETLEFT,
}
const SETTINGS_PATH := "user://settings.cfg"
## **기본 조작 배치가 바뀔 때마다 1씩 올린다.** 저장 파일에 적힌 번호가 이보다 낮으면
## 저장해 둔 키를 버리고 새 기본값으로 갈아엎는다 — 안 그러면 예전에 한 번이라도 설정을 만진
## 사람은 새 배치(맵 전용 키 추가 등)를 영영 못 본다.
## 2: 2026-09-30 사용자 지정 배치 — 기본공격/스킬1/스킬2 자리 교체(P1 G/H/F, P2 '/;/L),
##    P2 궁극기 ], 맵 전용 스킬을 아래 키에서 떼어내 전용 키로(P1 E / P2 [)
## 3: 2026-09-30 — 기본공격을 이동키 바로 옆으로(P1 F / P2 L), 스킬1·2를 그 오른쪽으로 차례로
const KEYBIND_VERSION := 3
## RoomSettings의 "현재 설정 저장"이 방 설정 프리셋을 저장할 때 쓰는 section 이름(SETTINGS_PATH 안)
const ROOM_PRESET_SECTION := "room_presets"

## 창 모드에서 고를 수 있는 해상도 (전부 16:9라 검은 여백 없이 꽉 채워짐)
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const DEFAULT_MASTER_VOLUME := 1.0
## 볼륨은 **세 갈래**다(2026-09-27) — 전체 / 음악 / 효과음.
## 엔진 버스는 Master 하나뿐이라, 시작할 때 Music·Sfx 버스를 만들어 Master 밑에 달아준다.
## 소리를 내는 노드는 자기 bus를 "Music"이나 "Sfx"로 지정하면 그 슬라이더를 따른다
const AUDIO_BUSES := ["Music", "Sfx"]
const DEFAULT_MUSIC_VOLUME := 1.0
const DEFAULT_SFX_VOLUME := 1.0

## (임시) **내보낸 빌드에서는 소리를 전부 끈다.** 아직 효과음·배경음악이 정리 전이라
## 발표·제출용 빌드에서 아무 소리도 안 나게 하려는 것이다. **에디터에서는 그대로 들린다** —
## 작업하면서는 소리를 확인할 수 있어야 하니까. 소리를 다 넣고 나면 이 값을 false로 바꾸면 된다.
##
## 볼륨 값(master_volume)은 그대로 두고 **Master 버스만 음소거**한다 — 나중에 켰을 때
## 사용자가 맞춰 둔 볼륨이 그대로 살아 있다
const MUTE_IN_BUILD := true

var is_fullscreen: bool = false
## 기본 1920x1080(RESOLUTIONS 1번, 2026-09-28 사용자 요청) — 설정을 한 번도 안 바꾼 새 PC에서 처음 켜면 이 크기
var resolution_index: int = 1
var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
## 대사를 넘기는 법("스페이스 또는 클릭")을 **한 번이라도 본 적 있는지**.
## 처음 하는 사람에게만 알려주고 그 뒤로는 화면을 깨끗하게 두려는 것이다(2026-09-16 멘토 피드백).
## 세션이 아니라 저장 파일(user://settings.cfg)에 남긴다 — 껐다 켤 때마다 다시 배우라고 할 이유가 없고,
## 새 PC에서 처음 켠 심사위원은 반드시 보게 된다
var dialogue_hint_seen: bool = false
## 튜토리얼에 한 번이라도 들어가 봤는지(2026-10-01). false면 타이틀 다음에 메인 메뉴 대신 튜토리얼로 간다.
## 들어가는 순간 저장한다 — 중간에 ESC로 나가도 다음부턴 안 뜬다. 다시 보려면 메뉴 > 훈련장 > 튜토리얼 다시
var tutorial_seen: bool = false

## PortraitFrames.tscn에서 읽어둔 캐릭터별 초상화 텍스처와, 프레임 대비 얼굴 네모의
## 중심·크기 비율(둘 다 Vector2). _ready에서 채운다
var _portrait_texture: Dictionary = {}
var _portrait_rect_center: Dictionary = {}
var _portrait_rect_size: Dictionary = {}

func _ready() -> void:
	_load_env()
	_ensure_audio_buses()
	_load_settings()
	_apply_build_mute()
	_load_portrait_frames()

## 새 대전을 시작하기 전에 라운드 스코어를 초기화한다
func reset_round_wins() -> void:
	p1_round_wins = 0
	p2_round_wins = 0

## 스토리 에피소드 하나를 시작한다 — 모드·진행도를 맞추고 그 에피소드의 첫 장면으로 넘어간다.
## scene이 비어 있는(아직 안 만든) 에피소드면 아무 일도 안 하고 false를 돌려준다
func start_story(episode_id: String) -> bool:
	var episode: Dictionary = story_episode(episode_id)
	var scene: String = episode.get("scene", "")
	if scene == "" or not ResourceLoader.exists(scene):
		return false
	game_mode = "story"
	current_story_id = episode_id
	story_next_scene = ""   # 지난 판에서 남은 값이 있으면 지운다 (장면이 다시 채워준다)
	reset_round_wins()
	get_tree().change_scene_to_file(scene)
	return true

## id로 에피소드 한 줄을 찾는다. 없으면 빈 Dictionary
func story_episode(episode_id: String) -> Dictionary:
	for episode in STORY_EPISODES:
		if episode["id"] == episode_id:
			return episode
	return {}

## 지금 진행 중인 에피소드 이름 (대전 모드거나 못 찾으면 빈 문자열)
func current_story_name() -> String:
	return story_episode(current_story_id).get("name", "")

## 한 번이라도 끝까지 봤는지 — 일시정지 화면 목록이 자물쇠를 걸지 말지 결정하는 기준
func is_story_cleared(episode_id: String) -> bool:
	return episode_id in story_cleared

## 에피소드를 클리어로 기록하고 바로 저장한다. 이미 기록돼 있으면 아무 일도 안 한다
func mark_story_cleared(episode_id: String) -> void:
	if episode_id == "" or is_story_cleared(episode_id):
		return
	story_cleared.append(episode_id)
	_save_setting("story", "cleared", story_cleared)

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
		# 처음 켠 PC(저장 파일 없음)도 기본 해상도를 창에 적용한다 — 안 하면 프로젝트 창 크기 그대로 뜬다
		_apply_window_size()
		return
	var saved_version: int = int(config.get_value("keybinds", "version", 1))
	if saved_version < KEYBIND_VERSION:
		# 기본 배치가 바뀌었다 — 저장해 둔 조작키를 통째로 새 기본값으로 되돌린다
		reset_keybindings()
		_save_setting("keybinds", "version", KEYBIND_VERSION)
		config.load(SETTINGS_PATH)
	for action in DEFAULT_KEYBINDS.keys():
		if config.has_section_key("keybinds", action):
			# 예전 저장 파일: 물리 키코드 숫자 하나 / 지금: [키코드, 좌우위치]
			var saved = config.get_value("keybinds", action)
			if saved is Array and saved.size() >= 2:
				_apply_keybind(action, int(saved[0]), int(saved[1]))
			else:
				_apply_keybind(action, int(saved))
	set_fullscreen(config.get_value("graphics", "fullscreen", is_fullscreen))
	set_resolution(config.get_value("graphics", "resolution_index", resolution_index))
	set_master_volume(config.get_value("audio", "master_volume", master_volume))
	set_music_volume(config.get_value("audio", "music_volume", music_volume))
	set_sfx_volume(config.get_value("audio", "sfx_volume", sfx_volume))
	dialogue_hint_seen = config.get_value("progress", "dialogue_hint_seen", dialogue_hint_seen)
	tutorial_seen = config.get_value("progress", "tutorial_seen", tutorial_seen)
	story_cleared = config.get_value("story", "cleared", PackedStringArray())

## user://settings.cfg의 한 항목을 갱신한다. 매번 새로 열고 닫아서 다른 항목을 덮어쓰지 않는다
func _save_setting(section: String, key: String, value) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # 파일이 없어도(첫 저장) 그냥 빈 ConfigFile로 계속 진행
	config.set_value(section, key, value)
	config.save(SETTINGS_PATH)

## RoomSettings에서 "현재 설정 저장"으로 만든 방 설정 프리셋 하나를 이름으로 저장한다(같은 이름이면 덮어쓴다).
## 다른 설정들과 같은 user://settings.cfg에 같이 저장되므로 게임을 다시 켜도 남아있는다
func save_room_preset(preset_name: String, data: Dictionary) -> void:
	_save_setting(ROOM_PRESET_SECTION, preset_name, data)

## 저장된 방 설정 프리셋을 전부 읽어온다 -> {이름: 저장된 값 Dictionary}. 하나도 없으면 빈 Dictionary
func load_room_presets() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return {}
	var result: Dictionary = {}
	for preset_name in config.get_section_keys(ROOM_PRESET_SECTION):
		result[preset_name] = config.get_value(ROOM_PRESET_SECTION, preset_name, {})
	return result

## action에 걸려있던 키 입력을 전부 지우고 물리 키코드 하나로 새로 등록한다.
##
## `location`은 **왼쪽/오른쪽이 따로 있는 키**(Shift·Ctrl·Alt·Win)에서 어느 쪽인지다
## (`KEY_LOCATION_LEFT`/`RIGHT`, 0이면 양쪽 다 먹는다). 키보드 화면에서 오른쪽 Shift에
## 올려놨는데 왼쪽 Shift로도 눌리던 문제 때문에 넣었다(2026-09-29) — 키코드는 둘이 같아서
## 구분할 수 있는 건 이 값뿐이다
func _apply_keybind(action: String, physical_keycode: int, location: int = 0) -> void:
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode as Key
	event.location = location as KeyLocation
	InputMap.action_add_event(action, event)

## ui/KeyboardMap.gd에서 키를 재배정할 때 호출한다. InputMap에 바로 반영하고 파일에도 저장해서 다음 실행에도 유지시킨다
func rebind_action(action: String, physical_keycode: int, location: int = 0) -> void:
	_apply_keybind(action, physical_keycode, location)
	# 위치까지 같이 저장한다. **예전 저장 파일은 숫자 하나뿐**이라 읽을 때 둘 다 받아준다
	_save_setting("keybinds", action, [physical_keycode, location])

## 모든 조작키를 project.godot 기본값으로 되돌리고 저장 파일도 그 값으로 덮어쓴다
func reset_keybindings() -> void:
	_save_setting("keybinds", "version", KEYBIND_VERSION)
	for action in DEFAULT_KEYBINDS.keys():
		var keycode: int = DEFAULT_KEYBINDS[action]
		_apply_keybind(action, keycode)
		_save_setting("keybinds", action, [keycode, 0])

## ui/Settings.gd의 전체화면 체크박스가 호출한다. 즉시 적용하고 저장한다.
## **창 모드로 돌아올 때는 저장해 둔 해상도를 다시 적용한다** — 안 그러면 전체화면 크기 그대로 남는다
func set_fullscreen(enabled: bool) -> void:
	is_fullscreen = enabled
	get_window().mode = Window.MODE_FULLSCREEN if enabled else Window.MODE_WINDOWED
	if not enabled:
		_apply_window_size()
	_save_setting("graphics", "fullscreen", enabled)

## ui/Settings.gd의 해상도 드롭다운이 호출한다. 전체화면 중에는 창 크기를 바꿔도 의미가 없어서 창모드일 때만 실제로 적용한다
func set_resolution(index: int) -> void:
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	if not is_fullscreen:
		_apply_window_size()
	_save_setting("graphics", "resolution_index", resolution_index)

## 지금 고른 해상도를 창에 실제로 적용하고 화면 가운데로 옮긴다.
##
## **모니터보다 큰 해상도는 고르지 못하게 한 칸씩 내려간다** — 1920x1080 모니터에서 2560x1440을 고르면
## 창의 절반이 화면 밖으로 나가 제목표시줄까지 안 보이게 된다.
##
## **에디터에서 실행하면 크기가 안 바뀔 수 있다.** Godot 4.4부터 게임 창을 에디터 안에 끼워서(Embed)
## 띄우는 게 기본이라, 그 창은 에디터가 크기를 쥐고 있어서 코드로 바꿔도 안 먹는다.
## 에디터 Game 탭의 "Embed Game on Play"를 끄거나, **내보낸 빌드에서 확인하면 정상 동작한다**
##
## **모니터와 같은 크기(1920x1080 모니터에서 1920x1080)는 테두리 없는 창으로 화면을 꽉 채운다**(2026-09-28).
## 예전엔 작업표시줄을 뺀 영역(usable, 1080 모니터면 세로 ~1040)과 비교해서 1920x1080을 골라도
## "안 들어간다"며 1280x720으로 내려갔다. 이제 모니터 전체 크기와 비교하고, 작업표시줄 영역을 넘는 크기면
## 제목표시줄을 떼고(borderless) 모니터에 딱 맞춰 띄운다
func _apply_window_size() -> void:
	var window := get_window()
	var screen: int = window.current_screen
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var full := Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))
	var target: Vector2i = RESOLUTIONS[0]
	# 모니터에 안 들어가면 들어가는 것 중 가장 큰 걸로 내려간다
	for i in range(resolution_index, -1, -1):
		if RESOLUTIONS[i].x <= full.size.x and RESOLUTIONS[i].y <= full.size.y:
			target = RESOLUTIONS[i]
			break
	var fills_screen: bool = target.x > usable.size.x or target.y > usable.size.y
	window.borderless = fills_screen
	window.size = target
	if fills_screen:
		window.position = full.position + Vector2i(Vector2(full.size - target) * 0.5)
	else:
		window.position = usable.position + Vector2i(Vector2(usable.size - target) * 0.5)

## 대사 넘기는 법을 방금 처음 봤다고 기록한다 (ContinueIndicator가 첫 입력에서 부른다).
## 이미 본 적 있으면 아무 일도 안 한다 — 누를 때마다 파일을 다시 쓸 이유가 없다
func mark_dialogue_hint_seen() -> void:
	if dialogue_hint_seen:
		return
	dialogue_hint_seen = true
	_save_setting("progress", "dialogue_hint_seen", true)

## 튜토리얼을 봤다고 기록한다 (Tutorial.gd가 들어올 때 부른다)
func mark_tutorial_seen() -> void:
	if tutorial_seen:
		return
	tutorial_seen = true
	_save_setting("progress", "tutorial_seen", true)

## 지금 소리가 꺼져 있어야 하는 상태인지 (내보낸 빌드 + MUTE_IN_BUILD).
## `OS.has_feature("editor")`는 에디터에서 실행할 때만 true라 빌드와 구분된다
func is_audio_muted() -> bool:
	return MUTE_IN_BUILD and not OS.has_feature("editor")

## Music·Sfx 버스를 만들어 Master 밑에 단다. 이미 있으면(버스 레이아웃 파일을 나중에 만들면) 그냥 넘어간다
func _ensure_audio_buses() -> void:
	for bus_name in AUDIO_BUSES:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var index: int = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")

## 버스 하나의 볼륨을 0~1로 맞춘다. **0이면 db가 -inf라 완전히 무음**이 된다
func _set_bus_volume(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(volume))

## Master 버스 음소거를 지금 상태에 맞춘다
func _apply_build_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), is_audio_muted())

## ui/Settings.gd의 마스터 볼륨 슬라이더가 호출한다(0.0~1.0). 엔진의 Master 버스 자체를 조절하기 때문에
## 지금은 재생 중인 소리가 없어도, 나중에 효과음·배경음악이 추가되면 바로 이 값이 적용된다
func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	var bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(master_volume))
	_apply_build_mute()   # 볼륨을 만져도 빌드에서는 계속 꺼진 채로 둔다
	_save_setting("audio", "master_volume", master_volume)

## 배경음악 볼륨 (Music 버스). 전체 볼륨과 곱해져서 들린다 — Music이 Master 밑에 달려 있기 때문
func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	_set_bus_volume("Music", music_volume)
	_save_setting("audio", "music_volume", music_volume)

## 효과음 볼륨 (Sfx 버스)
func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	_set_bus_volume("Sfx", sfx_volume)
	_save_setting("audio", "sfx_volume", sfx_volume)

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

## PortraitFrames.tscn에서 잡아 둔 **얼굴 네모의 중심·크기 비율**(0~1). 도감 칸처럼 TextureRect가
## 아니라 직접 그리는 곳에서 같은 프레이밍을 쓰려고 열어 둔다 — 안 잡아 둔 캐릭터는 한가운데·꽉 참
func portrait_frame_center(character_name: String) -> Vector2:
	return _portrait_rect_center.get(character_name, Vector2(0.5, 0.5))

func portrait_frame_size(character_name: String) -> Vector2:
	return _portrait_rect_size.get(character_name, Vector2.ONE)

## 이 캐릭터의 인게임 몸(BodyRig) 씬이 등록돼 있는지
func has_character_rig(character_name: String) -> bool:
	return CHARACTER_RIGS.has(character_name)

## 인게임 몸(BodyRig) 씬 (없으면 null) — 호출하는 쪽이 instantiate()해서 쓴다
func character_rig_scene(character_name: String) -> PackedScene:
	if not CHARACTER_RIGS.has(character_name):
		return null
	return load(CHARACTER_RIGS[character_name])

## p1_character_path/p2_character_path처럼 저장된 씬 경로로 CHARACTERS에서 표시 이름을 역으로 찾는다.
## 못 찾으면 빈 문자열
func character_name_for_path(scene_path: String) -> String:
	var roster: Dictionary = training_characters()
	for character_name in roster:
		if roster[character_name] == scene_path:
			return character_name
	return ""

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
