class_name ReformCutscene
extends Control

## 스토리 모드에서 상대를 꺾은 직후 보여주는 개과천선 컷신 — 방금 이긴 상대별로 다른 반성 대사를 보여준다
@onready var title_label: Label = $VBox/TitleLabel
@onready var body_label: Label = $VBox/BodyLabel

const REFORM_LINES := {
	"res://characters/chokbeopsonyeon/Chokbeopsonyeon.tscn": "\"미안... PC방에서 그렇게 소리 지르고 던진 거, 진상이었네.\"\n촉법소년은 이제 매너 있게 게임하기로 다짐했다.",
	"res://characters/akpeulleo/Akpeulleo.tscn": "\"내가 쓴 댓글이 누군가에게는 진짜 상처였구나...\"\n악플러는 계정을 정리하고 조용히 반성의 시간을 갖기로 했다.",
	"res://characters/jujeongbaengi/Jujeongbaengi.tscn": "\"길바닥에서 이러고 있었다니, 부끄럽다...\"\n주정뱅이는 술을 줄이고 도움을 받기로 결심했다.",
	"res://characters/catmom/CatMom.tscn": "\"동네 분들과 상의 없이 밥자리를 늘린 게 문제였구나...\"\n캣맘은 보호소와 함께 책임감 있게 돌보는 법을 찾기로 했다.",
	"res://characters/subwayvillain/SubwayVillain.tscn": "\"개찰구 뛰어넘고 소란 피운 거, 다른 승객들껜 민폐였네.\"\n지하철빌런은 요금을 내고 조용히 타는 승객이 되기로 했다.",
	"res://characters/floornoise/FloorNoise.tscn": "\"밤늦게 쿵쿵거린 게 아랫집엔 힘든 일이었겠구나...\"\n층간피해빌런은 매트를 깔고 시간대를 지키기로 다짐했다.",
}

func _ready() -> void:
	var defeated_path: String = ""
	if GameState.story_index >= 0 and GameState.story_index < GameState.STORY_OPPONENTS.size():
		defeated_path = GameState.STORY_OPPONENTS[GameState.story_index]
	title_label.text = "%s, 개과천선!" % _find_character_name(defeated_path)
	body_label.text = REFORM_LINES.get(defeated_path, "\"제가 잘못했습니다...\"")

func _find_character_name(path: String) -> String:
	for character_name in GameState.CHARACTERS.keys():
		if GameState.CHARACTERS[character_name] == path:
			return character_name
	return "상대"

func _on_next_pressed() -> void:
	if GameState.is_story_complete():
		get_tree().change_scene_to_file("res://ui/StoryClear.tscn")
		return
	get_tree().change_scene_to_file("res://ui/EpisodeSelect.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_next_pressed()
