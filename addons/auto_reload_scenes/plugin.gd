@tool
extends EditorPlugin

## 에디터 밖(Claude 등)에서 고친 씬이 **바로** 에디터에 보이게 한다(2026-10-09 사용자 요청).
## Godot은 씬 파일이 밖에서 바뀌면 "디스크 파일이 더 최신" 창을 띄우고 고르게 하는데, 거기서
## "다시 저장"을 누르면 밖에서 고친 내용이 에디터의 옛 내용으로 **덮어써진다**(실제로 겪음).
## 그래서 열린 씬마다 아래 둘을 `CHECK_INTERVAL`초마다 보고, 바뀌었으면 묻지 않고 다시 불러온다.
##   1. 씬 파일(.tscn) 자체
##   2. 그 씬 안 노드가 쓰는 **@tool 스크립트** — 번화가 골목(`DowntownAlley.gd`)처럼 에디터에서도 코드가
##      그림을 만드는 스크립트는, 스크립트만 바뀌어선 이미 만든 그림이 그대로라 씬을 다시 열어야 새로 그려진다
## ⚠️ 다시 불러오면 그 씬에서 **아직 저장 안 한 에디터 변경은 사라진다**(파일 쪽이 이긴다).
## 에디터에서 직접 저장한 건 `scene_saved`로 기록을 갱신해서 자기 저장 때문에 다시 불러오진 않는다

const CHECK_INTERVAL := 1.0

## 파일 경로 → 마지막으로 본 수정 시각
var _seen: Dictionary = {}
var _timer: Timer

func _enter_tree() -> void:
	_timer = Timer.new()
	_timer.wait_time = CHECK_INTERVAL
	_timer.timeout.connect(_check)
	add_child(_timer)
	_timer.start()
	scene_saved.connect(_on_scene_saved)
	resource_saved.connect(_on_resource_saved)

func _exit_tree() -> void:
	if _timer:
		_timer.queue_free()

func _check() -> void:
	for scene_path in EditorInterface.get_open_scenes():
		var changed: bool = _changed(scene_path)
		for script_path in _tool_scripts_of(scene_path):
			if _changed(script_path):
				changed = true
		if changed:
			print("[Auto Reload Scenes] 밖에서 바뀌어 다시 불러옴: ", scene_path)
			EditorInterface.reload_scene_from_path(scene_path)
			_remember(scene_path)

## 처음 보는 파일은 기록만 하고 false — 에디터를 켜자마자 전부 다시 불러오지 않게
func _changed(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var t: int = FileAccess.get_modified_time(path)
	if not _seen.has(path):
		_seen[path] = t
		return false
	if t != int(_seen[path]):
		_seen[path] = t
		return true
	return false

func _remember(path: String) -> void:
	if FileAccess.file_exists(path):
		_seen[path] = FileAccess.get_modified_time(path)

## 지금 편집 중인 씬이면 그 노드들에서 @tool 스크립트를 모은다(다른 탭의 씬은 파일만 본다)
func _tool_scripts_of(scene_path: String) -> Array[String]:
	var out: Array[String] = []
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != scene_path:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var script := node.get_script() as Script
		if script and script.is_tool() and script.resource_path.ends_with(".gd") and not out.has(script.resource_path):
			out.append(script.resource_path)
		stack.append_array(node.get_children())
	return out

func _on_scene_saved(path: String) -> void:
	_remember(path)

func _on_resource_saved(resource: Resource) -> void:
	if resource and resource.resource_path != "":
		_remember(resource.resource_path)
