extends Node

## 게임 전역 상태 오토로드 — 캐릭터/맵 선택 화면과 실제 대전 씬 사이에서 선택값을 들고 다닌다.

## 선택 가능한 캐릭터 (표시 이름 -> 씬 경로). 기획 문서에 실제 컨셉이 있는 4명만 등록
const CHARACTERS := {
	"잼민이": "res://characters/jaemini/Jaemini.tscn",
	"악플러": "res://characters/akpeulleo/Akpeulleo.tscn",
	"주정뱅이": "res://characters/jujeongbaengi/Jujeongbaengi.tscn",
	"예수천국 불신지옥": "res://characters/yesucheonguk/Yesucheonguk.tscn",
}

## 선택 가능한 맵 (표시 이름 -> 씬 경로)
const MAPS := {
	"편의점 앞": "res://maps/ConvenienceStore.tscn",
	"PC방": "res://maps/PcBang.tscn",
	"학교 옥상 (링아웃)": "res://maps/SchoolRooftop.tscn",
	"지하철 승강장 (링아웃)": "res://maps/SubwayPlatform.tscn",
	"아파트 단지 놀이터": "res://maps/ApartmentPlayground.tscn",
}

var p1_character_path: String = CHARACTERS.values()[0]
var p2_character_path: String = CHARACTERS.values()[1]
var selected_map_path: String = MAPS.values()[0]

## .env 파일에서 불러온 Claude API 키. ClaudeAIController가 P2 AI 판단에 사용한다.
## .env는 git에 커밋하지 않는 로컬 파일이라(.env.example 참고) 파일이 없으면 빈 문자열로 남는다
var anthropic_api_key: String = ""

func _ready() -> void:
	_load_env()

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
