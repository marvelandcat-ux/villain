extends Node

## 맵 선택 화면 썸네일을 **실제 게임 화면 그대로** 찍어 `ui/map_thumbs/<맵 파일 이름>.png`로 저장한다.
## F6로 이 씬(`tools/MapThumbGen.tscn`)을 띄우면 GameState.MAPS를 하나씩 돌며 찍고 저절로 꺼진다.
## **맵 그림을 바꾸면 다시 돌릴 것.**
##
## 맵은 타이틀 구경 모드("attract")로 띄운다 — HUD·카운트다운이 없다. 캐릭터는 찍기 직전에 숨긴다

const OUT_DIR := "res://ui/map_thumbs"
## 저장 크기(16:9). 썸네일 칸(256x144)의 두 배라 확대돼도 안 뭉개진다
const OUT_SIZE := Vector2i(512, 288)
## 맵을 띄우고 찍기까지 기다리는 시간(실제 초) — 페이드·카메라가 자리를 잡게
const SETTLE_SEC := 1.5

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var old_mode: String = GameState.game_mode
	GameState.game_mode = "attract"
	for map_name in GameState.MAPS:
		var path: String = GameState.MAPS[map_name]
		var map: Node = load(path).instantiate()
		add_child(map)
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < SETTLE_SEC * 1000.0:
			_hide_fighters(map)
			await get_tree().process_frame
		_hide_fighters(map)
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.resize(OUT_SIZE.x, OUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		var out: String = "%s/%s.png" % [OUT_DIR, path.get_file().get_basename()]
		image.save_png(out)
		print(">>> %s -> %s" % [map_name, out])
		map.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	GameState.game_mode = old_mode
	get_tree().quit()

## 캐릭터(와 그 자식들)는 썸네일에 안 나오게 숨기고 멈춘다 — AI끼리 싸우면 맞는 이펙트가 찍힌다
func _hide_fighters(root: Node) -> void:
	for node in root.find_children("*", "Fighter", true, false):
		node.visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
