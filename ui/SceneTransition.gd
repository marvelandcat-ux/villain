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

func _ready() -> void:
	layer = layer_order

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
