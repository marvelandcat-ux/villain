extends Node

## **(임시) 승패 연출 + 연행 연출만 따로 보는 확인용 씬** — F6으로 이 씬만 띄우면 바로 돈다.
##
## 지금까지는 이 연출을 보려면 **대전을 한 판 끝까지 이겨야** 했다. 한 글자 고치고 또 한 판,
## 또 한 판 하는 게 말이 안 돼서 만든 씬이다(2026-10-08 사용자 요청).
##
## 게임이 하는 것과 **같은 순서**다(`Stage._play_match_ending`):
##   승리 화면 → 와이프 → 패배 화면 → 검게 닫힘 → **연행 장면**
## `info` 꾸러미도 `Stage._match_ending_info()`와 같은 모양이라, 여기서 괜찮으면 게임에서도 그대로 나온다.
##
## **스토리 모드 승리 띠는 이 연출이 아니다** — 그건 `ui/RoundWinBanner.tscn`이고 따로 본다.
##
## 조작: 스페이스/R 다시 · 1 전부 · 2 승패만 · 3 연행만 · W 승패 뒤집기 · Esc 끝
##
## ⚠️ **이 씬은 게임 어디서도 안 쓴다.** 연출을 다 만들면 지워도 된다.

## 무엇까지 보여줄지
enum Part { ALL, ENDING_ONLY, ARREST_ONLY }

const MATCH_ENDING := "res://ui/result/MatchEnding.tscn"
const ARREST := "res://ui/result/ArrestScene.tscn"
## 주인공(경찰)은 `GameState.CHARACTER_RIGS`에 없어서 여기서 직접 잡아 준다
const EXTRA_RIGS := {
	"주인공": "res://characters/police/PoliceRig.tscn",
}

## 이긴 쪽 / 진 쪽 (표시 이름). `GameState.CHARACTER_RIGS`에 있는 이름이면 아무거나 된다
@export var winner_name: String = "주인공"
@export var loser_name: String = "악플러"
## 이긴 쪽이 1P(화면 왼쪽)인지. 끄면 좌우가 바뀐다
@export var winner_is_p1: bool = true
## 어디까지 볼지
@export var part: Part = Part.ALL
## 끝나면 저절로 처음부터 다시 돈다
@export var loop: bool = true
## 다시 돌기 전에 쉬는 시간(초)
@export var loop_gap: float = 0.6
## 화면 구석에 조작키를 띄운다
@export var show_help: bool = true

## 지금 돌고 있는 연출(없으면 쉬는 중)
var _playing: Node = null
## 한 번 돌리기가 진행 중인지 — 중간에 키를 눌러 새로 시작할 때 옛 흐름을 버리려고 센다
var _run_id: int = 0
var _help: Label = null

func _ready() -> void:
	_make_backdrop()
	if show_help:
		_make_help()
	_restart()

## 연출이 검게 시작/끝나므로 뒤는 검정으로 깔아 둔다
func _make_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0.03, 0.03, 0.05)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)

func _make_help() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	_help = Label.new()
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_theme_font_size_override("font_size", 15)
	_help.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	_help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_help.add_theme_constant_override("outline_size", 5)
	_help.position = Vector2(16, 12)
	layer.add_child(_help)
	_refresh_help()

func _refresh_help() -> void:
	if _help == null:
		return
	var what: String = ["전부", "승패만", "연행만"][int(part)]
	_help.text = "%s  |  승 %s(%s)  패 %s\n스페이스·R 다시 · 1 전부 · 2 승패만 · 3 연행만 · W 뒤집기 · Esc 끝" % [
		what, winner_name, "1P" if winner_is_p1 else "2P", loser_name]

## 리그 경로. 로스터에 없으면 주인공 같은 예외 표에서 찾는다
func _rig_of(character_name: String) -> String:
	var path: String = str(GameState.CHARACTER_RIGS.get(character_name, ""))
	if path == "":
		path = str(EXTRA_RIGS.get(character_name, ""))
	if path == "" or not ResourceLoader.exists(path):
		push_warning("EndingStudio: '%s' 리그를 못 찾았다" % character_name)
	return path

## `Stage._match_ending_info()`와 **같은 모양**으로 만든다 — 모양이 다르면 여기서만 잘 나온다
func _info() -> Dictionary:
	return {
		"winner_rig": _rig_of(winner_name),
		"loser_rig": _rig_of(loser_name),
		"winner_is_p1": winner_is_p1,
		"winner_name": winner_name,
		"loser_name": loser_name,
		"winner_p2_color": winner_name == loser_name and not winner_is_p1,
		"loser_p2_color": winner_name == loser_name and winner_is_p1,
		"is_draw": false,
	}

func _restart() -> void:
	_run_id += 1
	if is_instance_valid(_playing):
		_playing.queue_free()
	_playing = null
	_refresh_help()
	_run(_run_id)

## 게임과 같은 순서로 돌린다. `id`가 바뀌었으면 그 사이에 새로 시작한 것이라 조용히 빠진다
func _run(id: int) -> void:
	var info: Dictionary = _info()
	if part != Part.ARREST_ONLY:
		await _play(MATCH_ENDING, info, id)
		if id != _run_id or not is_inside_tree():
			return
	if part != Part.ENDING_ONLY:
		await _play(ARREST, info, id)
		if id != _run_id or not is_inside_tree():
			return
	if not loop:
		return
	await get_tree().create_timer(maxf(loop_gap, 0.05)).timeout
	if id == _run_id and is_inside_tree():
		_run(id)

## 연출 하나를 띄우고 끝날 때까지 기다린다.
## **연행 장면은 끝나도 안 사라진다**(게임에선 그 위에 결과 버튼이 뜬다) — 여기선 직접 치운다
func _play(path: String, info: Dictionary, id: int) -> void:
	if not ResourceLoader.exists(path):
		push_warning("EndingStudio: %s 가 없다" % path)
		return
	var node: Node = (load(path) as PackedScene).instantiate()
	add_child(node)
	_playing = node
	node.play(info)
	await node.finished
	if id != _run_id:
		return
	if is_instance_valid(node):
		node.queue_free()
	_playing = null

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_SPACE, KEY_R:
			_restart()
		KEY_1:
			part = Part.ALL
			_restart()
		KEY_2:
			part = Part.ENDING_ONLY
			_restart()
		KEY_3:
			part = Part.ARREST_ONLY
			_restart()
		KEY_W:
			# 이긴 쪽과 진 쪽을 통째로 맞바꾼다 — 반대 결과가 어떻게 보이는지 바로 본다
			var keep: String = winner_name
			winner_name = loser_name
			loser_name = keep
			winner_is_p1 = not winner_is_p1
			_restart()
		_:
			return
	get_viewport().set_input_as_handled()
