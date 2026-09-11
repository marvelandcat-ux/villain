class_name EpisodeSelect
extends Control

## 스토리 모드에서 어떤 상대(에피소드)와 싸울지 고르는 화면.
## 사용자가 그려준 스케치(원 노드들을 선으로 잇고, 다음 도전 자리에 깃발)를 그대로 따라
## 그리드 대신 "지도 경로"로 배치한다 — 원형 노드를 화면 비율 좌표(NODE_POSITIONS)로 놓고
## Line2D 한 줄로 순서대로 이어서 길처럼 보이게 한다.
## 1번 에피소드만 처음부터 열려 있고, 하나를 깨야(GameState.mark_story_cleared) 다음이 열린다.
## 이미 깬 에피소드는 계속 다시 골라 재도전할 수 있다.

@onready var path_area: Control = $PathArea
@onready var status_label: Label = $StatusLabel

## 노드 중심 위치(PathArea 크기 대비 비율 0~1). 좌우로 가면서 위아래로 살짝 굽이치는 경로.
## 상대가 6명보다 늘면 이 배열도 늘려야 한다 — 모자라면 마지막 값을 재사용한다
const NODE_POSITIONS: Array[Vector2] = [
	Vector2(0.10, 0.55),
	Vector2(0.26, 0.28),
	Vector2(0.42, 0.62),
	Vector2(0.58, 0.30),
	Vector2(0.74, 0.60),
	Vector2(0.90, 0.32),
]
const NODE_SIZE := 120.0
const FLAG_SIZE := Vector2(70.0, 70.0)

var _tiles: Array[Button] = []
var _connector: Line2D
var _flag_anchor: Control
var _flag_bob: Control

func _ready() -> void:
	# 스토리 모드를 거치지 않고 이 화면으로 바로 들어온 경우(예: 디버그) 대비 — 크기가 안 맞으면 새로 초기화
	if GameState.story_cleared.size() != GameState.STORY_OPPONENTS.size():
		GameState.reset_story_progress()
	if GameState.is_story_complete():
		status_label.text = "모든 에피소드를 클리어했습니다! 다시 도전해보세요"

	_connector = Line2D.new()
	_connector.width = 6.0
	_connector.default_color = Color(1, 1, 1, 0.35)
	path_area.add_child(_connector)

	for i in GameState.STORY_OPPONENTS.size():
		var tile := _make_tile(i)
		path_area.add_child(tile)
		_tiles.append(tile)

	_flag_anchor = Control.new()
	_flag_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flag_anchor.size = FLAG_SIZE
	path_area.add_child(_flag_anchor)
	_flag_bob = _make_flag_visual()
	_flag_anchor.add_child(_flag_bob)

	var tween := create_tween().set_loops()
	tween.tween_property(_flag_bob, "position:y", -8.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_flag_bob, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 해상도를 설정에서 바꿔도(1280x720/1920x1080/2560x1440) 다시 배치되도록 크기 변경에 맞춰 재계산
	path_area.resized.connect(_layout)
	_layout.call_deferred()

## 노드·연결선·깃발을 PathArea의 현재 크기에 맞춰 다시 배치한다
func _layout() -> void:
	var area_size: Vector2 = path_area.size
	if area_size.x <= 1.0 or area_size.y <= 1.0:
		return
	var next_index: int = _next_episode_index()
	var points: PackedVector2Array = []
	for i in _tiles.size():
		var frac: Vector2 = NODE_POSITIONS[min(i, NODE_POSITIONS.size() - 1)]
		var center: Vector2 = Vector2(frac.x * area_size.x, frac.y * area_size.y)
		_tiles[i].position = center - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
		points.append(center)
		if i == next_index:
			_flag_anchor.position = center - Vector2(FLAG_SIZE.x * 0.5, NODE_SIZE * 0.5 + FLAG_SIZE.y)
	_connector.points = points
	_flag_anchor.visible = next_index >= 0

## 다음에 도전해야 할 자리(깃발이 뜨는 곳) — 열려 있는데 아직 못 깬 에피소드 중 가장 앞. 전부 깼으면 -1
func _next_episode_index() -> int:
	for i in GameState.STORY_OPPONENTS.size():
		if GameState.is_episode_unlocked(i) and not GameState.story_cleared[i]:
			return i
	return -1

func _make_tile(index: int) -> Button:
	var character_name: String = _find_character_name(GameState.STORY_OPPONENTS[index])
	var unlocked: bool = GameState.is_episode_unlocked(index)
	var cleared: bool = GameState.story_cleared[index]
	var color: Color = GameState.CHARACTER_COLORS.get(character_name, GameState.DEFAULT_COLOR) if unlocked else Color(0.16, 0.16, 0.18)

	var button := Button.new()
	button.clip_text = false
	button.disabled = not unlocked
	button.size = Vector2(NODE_SIZE, NODE_SIZE)
	button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	_apply_tile_style(button, color)
	if unlocked:
		button.pressed.connect(_on_episode_picked.bind(index))

	var episode_label := Label.new()
	episode_label.text = "EP %d" % (index + 1)
	episode_label.anchor_right = 1.0
	episode_label.offset_top = -22.0
	episode_label.offset_bottom = -4.0
	episode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	episode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	episode_label.add_theme_font_size_override("font_size", 12)
	episode_label.add_theme_constant_override("outline_size", 4)
	episode_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	button.add_child(episode_label)

	var name_label := Label.new()
	name_label.text = (character_name + ("\n✔" if cleared else "")) if unlocked else "잠김"
	name_label.anchor_right = 1.0
	name_label.anchor_bottom = 1.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	button.add_child(name_label)

	return button

## 깃발 모양(깃대 + 삼각 깃발)을 코드로 그린다 — 아직 전용 그림이 없어서 도형으로 대신함
func _make_flag_visual() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = FLAG_SIZE

	var pole := ColorRect.new()
	pole.color = Color(0.9, 0.9, 0.9)
	pole.position = Vector2(FLAG_SIZE.x * 0.5 - 2.0, 18.0)
	pole.size = Vector2(4.0, FLAG_SIZE.y - 18.0)
	root.add_child(pole)

	var banner := Polygon2D.new()
	banner.color = Color(0.95, 0.25, 0.25)
	var pole_x: float = FLAG_SIZE.x * 0.5
	banner.polygon = PackedVector2Array([
		Vector2(pole_x, 14.0),
		Vector2(pole_x, 40.0),
		Vector2(pole_x + 32.0, 27.0),
	])
	root.add_child(banner)

	return root

## 캐릭터 씬 경로로 GameState.CHARACTERS에 등록된 표시 이름을 역으로 찾는다
func _find_character_name(path: String) -> String:
	for character_name in GameState.CHARACTERS.keys():
		if GameState.CHARACTERS[character_name] == path:
			return character_name
	return "?"

func _apply_tile_style(button: Button, color: Color) -> void:
	var radius: int = int(NODE_SIZE / 2.0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var is_highlighted: bool = state == "hover" or state == "pressed" or state == "focus"
		var style := StyleBoxFlat.new()
		style.bg_color = color * (1.15 if is_highlighted else 1.0)
		var border_width: int = 6 if is_highlighted else 3
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width
		style.border_color = Color(1, 1, 1) if is_highlighted else Color(1, 1, 1, 0.5)
		style.corner_radius_top_left = radius
		style.corner_radius_top_right = radius
		style.corner_radius_bottom_left = radius
		style.corner_radius_bottom_right = radius
		button.add_theme_stylebox_override(state, style)

## 주인공(GameState.PROTAGONIST_NAME)이 고정이라 P1을 고를 필요가 없어졌다 — CharacterSelect를
## 거치지 않고 바로 P1/P2/맵을 확정해서 그 맵으로 넘어간다 (예전엔 여기서 CharacterSelect.tscn으로 보내
## 플레이어가 P1을 직접 고르게 했었다)
func _on_episode_picked(index: int) -> void:
	GameState.story_index = index
	GameState.p1_character_path = GameState.CHARACTERS[GameState.PROTAGONIST_NAME]
	GameState.p2_character_path = GameState.STORY_OPPONENTS[index]
	GameState.selected_map_path = GameState.STORY_MAPS[index]
	GameState.reset_round_wins()
	get_tree().change_scene_to_file(GameState.selected_map_path)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
