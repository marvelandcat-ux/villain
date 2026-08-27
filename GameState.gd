extends Node

## 게임 전역 상태 오토로드 — 캐릭터/맵 선택 화면과 실제 대전 씬 사이에서 선택값을 들고 다닌다.

## 선택 가능한 캐릭터 (표시 이름 -> 씬 경로)
const CHARACTERS := {
	"잼민이": "res://characters/jaemini/Jaemini.tscn",
	"악플러": "res://characters/akpeulleo/Akpeulleo.tscn",
	"주정뱅이": "res://characters/jujeongbaengi/Jujeongbaengi.tscn",
	"예수천국 불신지옥": "res://characters/yesucheonguk/Yesucheonguk.tscn",
	"캣맘": "res://characters/catmom/CatMom.tscn",
	"지하철빌런": "res://characters/subwayvillain/SubwayVillain.tscn",
	"층간피해빌런": "res://characters/floornoise/FloorNoise.tscn",
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
	"res://characters/yesucheonguk/Yesucheonguk.tscn",
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

## 새 대전을 시작하기 전에 라운드 스코어를 초기화한다
func reset_round_wins() -> void:
	p1_round_wins = 0
	p2_round_wins = 0
