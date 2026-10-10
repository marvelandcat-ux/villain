extends CanvasLayer

## 씬 전환 전용 오토로드 — 화면을 홀로그램 타일(HologramWipe)로 덮은 채로 change_scene_to_file을 하고,
## 새 씬이 자리잡으면 타일을 걷어내 보여준다.
##
## 오토로드는 SceneTree 루트의 자식이라, change_scene_to_file로 "현재 씬"이 통째로 바뀌어도
## 이 CanvasLayer(와 그 안의 타일)는 그대로 남는다 — 그래서 씬이 바뀌는 순간이 타일 뒤에 가려지고,
## 다음 씬이 시작할 때 타일이 걷히며 드러나는 진짜 "전환 연출"이 된다(HologramWipe 혼자서는
## 자신이 속한 씬이 통째로 사라지면 같이 사라지므로 이 역할을 할 수 없다).
##
## 쓰는 쪽은 get_tree().change_scene_to_file(path) 대신 이것만 부르면 된다(await 필요 없음):
##   SceneTransition.go_to_scene("res://maps/Playground.tscn")

## 다른 CanvasLayer(HUD 등)보다 위에 그려지도록 큰 값을 준다
@export var layer_order: int = 100

var _wipe: HologramWipe = null
## 지금 덮여 있는 게 cover()로 직접 덮은 것인지. **go_to_scene이 쓰는 타일과 구분하려고 둔다** —
## 이게 없으면, 맵 선택에서 넘어오느라 go_to_scene이 아직 타일을 걷는 중일 때
## Stage가 부른 uncover()가 같은 타일을 한 번 더 걷어내며 서로 엉킨다
var _manual_cover: bool = false

func _ready() -> void:
	layer = layer_order

## 씬은 그대로 두고 **화면만 덮는다**. 스토리 VS 화면처럼 "장면은 안 바꾸는데 화면은 가려야 하는"
## 경우에 쓴다 — 덮은 뒤엔 반드시 uncover()를 불러 줘야 걷힌다.
## 이미 덮여 있거나 전환 중이면 아무것도 안 한다
func cover() -> void:
	if _wipe != null:
		return
	_wipe = HologramWipe.new()
	_manual_cover = true
	add_child(_wipe)
	await _wipe.covered

## cover()로 덮어 둔 화면을 걷어낸다. **덮어 둔 게 없으면 그냥 돌아간다** —
## 부르는 쪽(Stage)이 스토리 모드인지 아닌지 따지지 않아도 되게 하려는 것이다
func uncover() -> void:
	if _wipe == null or not _manual_cover:
		return
	_manual_cover = false
	var wipe: HologramWipe = _wipe
	wipe.start_uncover()
	await wipe.uncovered
	wipe.queue_free()
	_wipe = null

## 화면을 덮고 -> 씬을 바꾸고 -> 새 씬이 자리잡으면 다시 걷어낸다.
## 이미 전환 중이면 무시한다(버튼 연타로 두 번 겹쳐 불리는 것을 막는다)
func go_to_scene(path: String) -> void:
	if _wipe != null:
		return
	_wipe = HologramWipe.new()
	add_child(_wipe)
	await _wipe.covered
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame  # 새 씬이 트리에 완전히 자리잡을 시간을 한 프레임 준다
	_wipe.start_uncover()
	await _wipe.uncovered
	_wipe.queue_free()
	_wipe = null

## --- 검은 화면 전환(2026-10-08, 맵 선택 "빨려 들어가기") ---
## 부르는 쪽이 이미 화면을 **검게 만든 채로** 넘어온다(맵 선택이 확대하며 어둡게 함). 여기선 검은 막으로 바로 덮고 →
## 씬을 바꾸고 → 새 씬이 자리잡으면 `fade_time`초 동안 **서서히 밝아진다**(로딩 대신). 홀로그램 타일과 겹치면 무시한다
var _black: ColorRect = null

func go_to_scene_from_black(path: String, fade_time: float = 1.0) -> void:
	if _wipe != null or _black != null:
		return
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_black)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame  # 새 씬이 트리에 완전히 자리잡을 시간을 한 프레임 준다
	var tween := create_tween()
	tween.tween_property(_black, "color:a", 0.0, maxf(fade_time, 0.05)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_black.queue_free()
	_black = null

## 화면을 **까맣게 덮은 뒤** 씬을 바꾸고, 새 씬이 자리잡으면 막을 치운다
## (2026-10-10 사용자 — 스토리 전투를 이기면 화면이 까매졌다가 다음 장면으로 넘어간다).
##
## ⚠️ 위 `go_to_scene_from_black`과 **방향이 반대다**. 그쪽은 이미 검은 채로 와서 밝아지고,
## 이쪽은 밝은 화면을 검게 덮고 넘어간다. 넘어간 뒤 **여기서 밝히지 않는 이유**는
## 다음 장면(`StoryFadeScene`)이 스스로 검게 시작해 제 `fade_in_time`으로 밝아지기 때문이다 —
## 여기서도 밝히면 두 겹이 따로 놀아 한 번 번쩍인다
func go_to_scene_through_black(path: String, fade_time: float = 0.6) -> void:
	if _wipe != null or _black != null:
		return
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_black)
	var tween := create_tween()
	tween.tween_property(_black, "color:a", 1.0, maxf(fade_time, 0.05)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame   # 새 씬이 트리에 자리잡을 틈을 한 프레임 준다
	_black.queue_free()
	_black = null
