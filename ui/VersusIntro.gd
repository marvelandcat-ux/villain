class_name VersusIntro
extends CanvasLayer

## 스토리 모드에서 대전에 들어가기 전 "주인공 VS 적" 매치업을 보여주는 화면.
## Stage.gd가 _ready() 맨 앞에서(캐릭터를 스폰하기도 전에) 이 씬을 띄우고 finished를 기다린 뒤
## 나머지(스폰 → 3,2,1,FIGHT 카운트다운)를 진행한다. 아직 Fighter가 없는 시점이라
## GameState.p1_character_path/p2_character_path 값만으로 이름·색·초상화를 채운다

signal finished

const BOX_SIZE := Vector2(320, 240)
const SLIDE_DISTANCE := 420.0
const SLIDE_TIME := 0.35
const HOLD_TIME := 1.1
const FADE_TIME := 0.3

@onready var _root: Control = $Root
@onready var _p1_side: Control = $Root/P1Side
@onready var _p2_side: Control = $Root/P2Side
@onready var _p1_box: ColorRect = $Root/P1Side/P1Box
@onready var _p2_box: ColorRect = $Root/P2Side/P2Box
@onready var _p1_image: TextureRect = $Root/P1Side/P1Box/P1Image
@onready var _p2_image: TextureRect = $Root/P2Side/P2Box/P2Image
@onready var _p1_name_label: Label = $Root/P1Side/P1NameLabel
@onready var _p2_name_label: Label = $Root/P2Side/P2NameLabel
@onready var _vs_label: Label = $Root/VsLabel

func _ready() -> void:
	_fill_side(_p1_box, _p1_image, _p1_name_label, GameState.p1_character_path)
	_fill_side(_p2_box, _p2_image, _p2_name_label, GameState.p2_character_path)
	_play_intro()

func _fill_side(box: ColorRect, image: TextureRect, name_label: Label, character_path: String) -> void:
	var character_name: String = _find_character_name(character_path)
	box.color = GameState.CHARACTER_COLORS.get(character_name, GameState.DEFAULT_COLOR)
	name_label.text = character_name
	if GameState.has_portrait(character_name):
		image.texture = GameState.portrait_texture(character_name)
		box.clip_contents = true
		GameState.frame_portrait(image, character_name, BOX_SIZE)
	else:
		image.texture = null

## 캐릭터 씬 경로로 등록된 표시 이름을 역으로 찾는다.
## **대전 로스터(CHARACTERS)뿐 아니라 훈련장 전용 캐릭터까지 봐야 한다** —
## 스토리 주인공(경찰)이 `TRAINING_ONLY_CHARACTERS`에 있어서, 예전엔 여기서 못 찾고
## 이름이 "?"로, 상자 색이 회색(DEFAULT_COLOR)으로 떴다(2026-09-14 발견)
func _find_character_name(path: String) -> String:
	var roster: Dictionary = GameState.training_characters()
	for character_name in roster.keys():
		if roster[character_name] == path:
			return character_name
	return "?"

## 양옆에서 미끄러져 들어온 뒤 VS가 팡 튀어나오고, 잠깐 멈췄다가 전체가 페이드아웃된다
func _play_intro() -> void:
	var p1_target_x: float = _p1_side.position.x
	var p2_target_x: float = _p2_side.position.x
	_p1_side.position.x -= SLIDE_DISTANCE
	_p2_side.position.x += SLIDE_DISTANCE
	_vs_label.scale = Vector2.ZERO

	var slide_tween := create_tween()
	slide_tween.set_parallel(true)
	slide_tween.tween_property(_p1_side, "position:x", p1_target_x, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slide_tween.tween_property(_p2_side, "position:x", p2_target_x, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await slide_tween.finished

	var vs_tween := create_tween()
	vs_tween.tween_property(_vs_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await vs_tween.finished

	await get_tree().create_timer(HOLD_TIME).timeout

	var fade_tween := create_tween()
	fade_tween.tween_property(_root, "modulate:a", 0.0, FADE_TIME)
	await fade_tween.finished

	finished.emit()
	queue_free()
