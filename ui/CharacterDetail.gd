@tool
extends Control

## 도감 2단계 — 캐릭터 상세 설명 창.
## 화면을 왼쪽부터 네 구역으로 나눈다 (러프 확정안):
##   ① 좌상단  캐릭터 이름 (뒤에 도형 없이 글자만)
##   ② 좌측    스킬 목록 평행사변형 4칸 — 기본공격 / 1번 / 2번 / 궁극기 순서 고정
##   ③ 중앙    고른 스킬의 상자 — 스킬명 / 시연 영상 / 설명
##   ④ 우측    큰 평행사변형 — 인게임 모습, 아래 탭으로 일러스트 전환
##
## 자리 값은 전부 씬(CharacterDex.tscn)에 놓인 노드 위치를 따라간다. 코드가 자리를 잡는 건
## 평행사변형 칸들뿐인데, 그것도 SkillList/Showcase 상자 **안쪽**에서만 나눈다.
## 그래서 인스펙터에서 상자만 끌어 옮기면 통째로 따라 움직인다

const SLOT_ORDER: Array[String] = ["BasicAttack", "Skill1", "Skill2", "SkillUltimate"]
## 각 칸에 붙는 키 뱃지 — 1P 기준 (project.godot의 p1_* 액션과 같다)
const SLOT_KEYS: Array[String] = ["F", "G", "H", "R"]
## 칸에 적히는 분류 이름. 스킬명이 비어 있으면 이게 대신 뜬다
const SLOT_LABELS: Array[String] = ["기본 공격", "1번 스킬", "2번 스킬", "궁극기"]

@export_group("스킬 칸")
## 메인 메뉴 항목과 같은 사선 그림 (sprite/UI/메뉴사선_임시.png)
@export var slant_texture: Texture2D
## 흰 테두리 셰이더 (ui/outline.gdshader). 항목마다 복제해서 따로 켠다
@export var outline_material: ShaderMaterial
## 칸 사이 세로 간격(px)
@export var slot_gap: float = 16.0
## 칸 하나의 높이(px). 0이면 상자 높이를 네 칸으로 똑같이 나눠 쓴다
@export var slot_height: float = 54.0
## **고른** 칸이 오른쪽으로 튀어나오는 거리(px)
@export var slot_slide: float = 46.0
## 커서만 올라간 칸이 튀어나오는 거리(px) — 고른 칸보다 짧아야 뭘 골랐는지 구분된다
@export var slot_slide_hover: float = 16.0
## 튀어나오고 들어가는 빠르기
@export var slot_slide_speed: float = 12.0
## 평소 색 / 고른 색 — 메인메뉴·일시정지 메뉴와 같은 팔레트
@export var slot_color: Color = Color(0.09, 0.07, 0.13, 0.82)
@export var slot_color_focus: Color = Color(0.72, 0.18, 0.28, 0.95)
@export var slot_text_color: Color = Color(0.86, 0.82, 0.92, 1.0)
@export var slot_text_color_focus: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var slot_font_size: int = 20
@export var slot_outline_width: float = 2.0
## 방향키를 꾹 누르고 있을 때 **첫 반복까지 기다리는 시간**(초)
@export var key_repeat_delay: float = 0.35
## 그 뒤 한 칸씩 넘어가는 간격(초)
@export var key_repeat_interval: float = 0.08

@export_group("오른쪽 그림")
## 큰 평행사변형의 기울기(px)
@export var showcase_lean: float = 60.0
@export var showcase_color: Color = Color(0.13, 0.11, 0.18, 0.9)
## 큰 평행사변형 안에서 그림이 차지하는 자리 (칸 크기 대비 0~1 비율).
## 기본 COVER로 두면 세로로 긴 전신샷이 잘려 발이 날아간다 — 비율 유지 FIT으로 넣는다
@export var showcase_frame: Rect2 = Rect2(0.08, 0.02, 0.84, 0.79)

@onready var _name_label: Label = $NameLabel
@onready var _slot_root: Control = $SkillList
@onready var _skill_title: Label = $SkillBox/SkillTitle
@onready var _skill_desc: Label = $SkillBox/SkillDesc
@onready var _demo_image: TextureRect = $SkillBox/DemoFrame/DemoImage
@onready var _demo_video: VideoStreamPlayer = $SkillBox/DemoFrame/DemoVideo
@onready var _demo_hint: Label = $SkillBox/DemoFrame/DemoHint
@onready var _showcase_root: Control = $Showcase
@onready var _view_tabs: Control = $ViewTabs

## 칸 버튼들 — 각각 Slide(움직이는 부분) > Shape(사선 그림) + Text(글자) 를 가진다.
## 메인 메뉴와 같은 구조라, 클릭 판정(Button)은 제자리에 있고 보이는 부분만 밀려 나온다
var _slots: Array[Button] = []
## 지금 보고 있는 캐릭터의 스킬 정보 — [{name, description, cooldown, video, image}, ...] 4칸
var _skills: Array = []
## 고른 칸 번호. **-1 = 아직 아무것도 안 고름** (상세창을 막 열었을 때의 상태)
var _slot_index: int = -1
## 마우스가 올라간 칸 번호 (-1 = 없음). 고른 칸과 별개로 칸이 튀어나온다
var _hovered_index: int = -1
## 꾹 누르고 있는 방향(+1 아래 / -1 위)과, 다음 이동까지 남은 시간
var _held_step: int = 0
var _repeat_left: float = 0.0
## 오른쪽 그림의 두 장 — 인게임 모습 / 일러스트
var _showcase_tile: FanTile = null
var _ingame_texture: Texture2D = null
var _illust_texture: Texture2D = null
var _view: String = "ingame"

func _ready() -> void:
	# 상자 크기가 바뀌면(창 크기 변경 등) 칸을 다시 깐다
	if not _slot_root.resized.is_connected(_build_slots):
		_slot_root.resized.connect(_build_slots)
	if not _showcase_root.resized.is_connected(_build_showcase):
		_showcase_root.resized.connect(_build_showcase)
	_build_slots()
	_build_showcase()
	if Engine.is_editor_hint():
		return
	for button in _view_tabs.get_children():
		if button is Button:
			button.focus_mode = Control.FOCUS_NONE
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			# flat이면 스타일박스가 통째로 무시된다 — 고른 탭을 칠하려면 꺼야 한다
			button.flat = false
			if not button.pressed.is_connected(_on_view_tab_pressed):
				button.pressed.connect(_on_view_tab_pressed.bind(button.name))

## 도감 목록에서 칸을 확정했을 때 호출된다. 캐릭터 씬을 열어 스킬 네 개를 읽어 온다
func open(character_name: String, scene_path: String) -> void:
	_name_label.text = character_name
	_read_character(scene_path)
	# 들어오면 커서가 맨 위 기본 공격 칸에 가 있다
	_slot_index = 0
	_hovered_index = -1
	_held_step = 0
	_view = "ingame"
	_refresh_slots()
	_refresh_showcase()
	_show_skill(0)
	visible = true

func close() -> void:
	visible = false
	# 안 보이는 창에서 영상이 계속 돌면 낭비다
	if is_instance_valid(_demo_video) and _demo_video.is_playing():
		_demo_video.stop()

## 캐릭터 씬을 **트리에 넣지 않고** 만들어서 스킬 노드의 값만 읽고 바로 버린다.
## 트리에 안 넣으면 _ready가 돌지 않으므로 전투 로직은 아무것도 시작되지 않는다
func _read_character(scene_path: String) -> void:
	_skills.clear()
	_ingame_texture = null
	_illust_texture = null

	var packed: PackedScene = load(scene_path)
	if packed == null:
		return
	var fighter: Node = packed.instantiate()

	var stats = fighter.get("stats")
	if stats != null:
		_ingame_texture = stats.get("dex_ingame_texture")
		_illust_texture = stats.get("dex_illust_texture")
	# 인게임 모습을 아직 안 넣었으면 선택 화면 초상화라도 보여준다 (빈 칸보다 낫다)
	if _ingame_texture == null and GameState.has_portrait(_name_label.text):
		_ingame_texture = GameState.portrait_texture(_name_label.text)

	for i in range(SLOT_ORDER.size()):
		var node: Node = fighter.get_node_or_null(SLOT_ORDER[i])
		var entry: Dictionary = {
			"name": SLOT_LABELS[i], "description": "", "cooldown": 0.0,
			"video": null, "image": null,
		}
		if node != null:
			var given: String = str(node.get("skill_name"))
			if given != "":
				entry["name"] = given
			entry["description"] = str(node.get("description"))
			entry["cooldown"] = float(node.get("cooldown"))
			entry["video"] = node.get("demo_video")
			entry["image"] = node.get("demo_image")
		_skills.append(entry)

	fighter.free()

## 에디터에서 값이 바뀌었는지 보는 도장 — 바뀐 프레임에만 다시 그린다
var _editor_stamp: String = ""

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		_animate_slots(delta)
		_update_key_repeat(delta)
		return
	var stamp: String = "%s|%s|%s|%s|%s" % [_slot_root.size, _showcase_root.size,
		slot_gap, slot_slide, slot_font_size] + "|%s|%s" % [showcase_lean, showcase_frame]
	if stamp == _editor_stamp:
		return
	_editor_stamp = stamp
	_build_slots()
	_build_showcase()

# --------------------------------- 스킬 칸 ---------------------------------

## SkillList 상자 안을 네 칸으로 나눈다. 칸 하나하나가 메인 메뉴 항목과 똑같은 구조다:
##   Button(판정, 제자리) > Slide(보이는 부분, 골라지면 오른쪽으로 밀림) > Shape(사선 그림) + Text(글자)
## 판정까지 같이 움직이면 커서에서 도망가며 들어갔다 나왔다 덜덜 떨리므로 Button은 고정한다
func _build_slots() -> void:
	for child in _slot_root.get_children():
		_slot_root.remove_child(child)
		child.queue_free()
	_slots.clear()

	var count: int = SLOT_ORDER.size()
	var box: Vector2 = _slot_root.size
	if box.x <= 0.0 or box.y <= 0.0:
		return
	var height: float = slot_height
	if height <= 0.0:
		height = (box.y - slot_gap * float(count - 1)) / float(count)
	height = maxf(height, 20.0)
	# 튀어나온 만큼 오른쪽으로 삐져나가므로, 폭에서 미리 빼 둔다
	var width: float = maxf(box.x - maxf(slot_slide, slot_slide_hover), 40.0)

	for i in range(count):
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.position = Vector2(0.0, (height + slot_gap) * float(i))
		button.size = Vector2(width, height)

		var slide := Control.new()
		slide.name = "Slide"
		slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slide.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.add_child(slide)

		var shape := TextureRect.new()
		shape.name = "Shape"
		shape.texture = slant_texture
		# KEEP_SIZE면 원본 540x84가 최소 크기로 박혀서 칸이 안 줄어든다 — IGNORE_SIZE로 풀어 준다
		shape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape.modulate = slot_color
		shape.set_anchors_preset(Control.PRESET_FULL_RECT)
		# 항목마다 테두리를 따로 켜야 하므로 머티리얼을 복제한다 (같이 쓰면 네 칸이 한꺼번에 켜진다)
		if outline_material:
			var mat: ShaderMaterial = outline_material.duplicate()
			mat.set_shader_parameter("line_color", Color(1, 1, 1))
			mat.set_shader_parameter("line_width", slot_outline_width)
			mat.set_shader_parameter("line_alpha", 0.0)
			shape.material = mat
		slide.add_child(shape)

		var text := Label.new()
		text.name = "Text"
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_font_size_override("font_size", slot_font_size)
		text.add_theme_color_override("font_color", slot_text_color)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.set_anchors_preset(Control.PRESET_FULL_RECT)
		slide.add_child(text)

		_slot_root.add_child(button)
		button.pressed.connect(_show_skill.bind(i))
		button.mouse_entered.connect(_on_slot_hovered.bind(i))
		button.mouse_exited.connect(_on_slot_unhovered.bind(i))
		_slots.append(button)
	_refresh_slots()

func _on_slot_hovered(index: int) -> void:
	_hovered_index = index

func _on_slot_unhovered(index: int) -> void:
	if _hovered_index == index:
		_hovered_index = -1

## 칸에 적히는 글자만 새로 넣는다. 색·튀어나오기는 _animate_slots가 매 프레임 따라간다
func _refresh_slots() -> void:
	for i in range(_slots.size()):
		var label: String = SLOT_LABELS[i]
		if i < _skills.size():
			label = str(_skills[i]["name"])
		var text: Label = _slots[i].get_node_or_null("Slide/Text")
		if text:
			text.text = "%s  %s" % [SLOT_KEYS[i], label]

## 골라졌거나 커서가 올라간 칸만 앞으로 나오고 색이 진해진다 (메인 메뉴와 같은 연출).
## 튀어나온 정도를 그대로 흰 테두리 진하기로 쓴다 — 같이 나타났다 같이 사라진다
func _animate_slots(delta: float) -> void:
	var t: float = clampf(delta * slot_slide_speed, 0.0, 1.0)
	for i in range(_slots.size()):
		var slide: Control = _slots[i].get_node_or_null("Slide")
		if slide == null:
			continue
		var picked: bool = i == _slot_index
		var on: bool = picked or i == _hovered_index
		# 고른 칸은 끝까지, 커서만 올라간 칸은 살짝만 — 뭘 골랐는지가 한눈에 구분된다
		var goal_x: float = slot_slide if picked else (slot_slide_hover if on else 0.0)
		slide.position.x = lerpf(slide.position.x, goal_x, t)
		var shape: TextureRect = slide.get_node_or_null("Shape")
		var goal_color: Color = slot_color
		if picked:
			goal_color = slot_color_focus
		elif on:
			goal_color = slot_color.lerp(slot_color_focus, 0.5)
		if shape:
			shape.modulate = shape.modulate.lerp(goal_color, t)
			if shape.material:
				var line: float = clampf(slide.position.x / maxf(slot_slide, 0.001), 0.0, 1.0)
				# 커서만 올라간 칸은 흐린 테두리로 끝난다 (고른 칸만 또렷하게)
				shape.material.set_shader_parameter("line_alpha", line)
		var text: Label = slide.get_node_or_null("Text")
		if text:
			var goal: Color = slot_text_color_focus if on else slot_text_color
			text.add_theme_color_override("font_color",
				text.get_theme_color("font_color").lerp(goal, t))

# --------------------------------- 스킬 상자 ---------------------------------

## 아직 아무 스킬도 안 고른 상태 — 오른쪽 상자를 비우고 무엇을 하라는지만 적어 둔다
func _clear_skill() -> void:
	_slot_index = -1
	_skill_title.text = ""
	_skill_desc.text = "왼쪽에서 스킬을 고르면 여기에 설명이 나옵니다."
	if _demo_video.is_playing():
		_demo_video.stop()
	_demo_video.visible = false
	_demo_image.visible = false
	_demo_hint.visible = false

func _show_skill(index: int) -> void:
	_slot_index = clampi(index, 0, SLOT_ORDER.size() - 1)
	_refresh_slots()
	if _slot_index >= _skills.size():
		return
	var entry: Dictionary = _skills[_slot_index]

	var title: String = str(entry["name"])
	var cooldown: float = float(entry["cooldown"])
	# 기본 공격은 쿨타임이 사실상 없는 셈이라 굳이 안 적는다
	if cooldown >= 1.0:
		title += "   쿨타임 %.0f초" % cooldown
	_skill_title.text = title

	var desc: String = str(entry["description"])
	_skill_desc.text = desc if desc != "" else "설명 준비 중"
	_play_demo(entry)

## 영상이 있으면 영상, 없으면 정지 그림, 둘 다 없으면 안내 문구.
## 영상은 도감을 열어 둔 내내 반복 재생한다
func _play_demo(entry: Dictionary) -> void:
	if _demo_video.is_playing():
		_demo_video.stop()
	var video: VideoStream = entry["video"]
	var image: Texture2D = entry["image"]

	_demo_video.visible = video != null
	_demo_image.visible = video == null and image != null
	_demo_hint.visible = video == null and image == null

	if video != null:
		_demo_video.stream = video
		_demo_video.loop = true
		_demo_video.play()
	elif image != null:
		_demo_image.texture = image

# --------------------------------- 오른쪽 그림 ---------------------------------

## Showcase 상자를 꽉 채우는 큰 평행사변형 한 장
func _build_showcase() -> void:
	for child in _showcase_root.get_children():
		_showcase_root.remove_child(child)
		child.queue_free()
	_showcase_tile = null

	var box: Vector2 = _showcase_root.size
	if box.x <= 0.0 or box.y <= 0.0:
		return
	var tile := FanTile.new()
	tile.lean = showcase_lean
	tile.fill_color = showcase_color
	tile.backdrop_color = showcase_color
	tile.size = box
	# 보여주기만 하는 칸이라 눌러도 아무 일 없다
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.portrait_frame = showcase_frame
	_showcase_root.add_child(tile)
	tile.focus_mode = Control.FOCUS_NONE
	_showcase_tile = tile
	_refresh_showcase()

func _refresh_showcase() -> void:
	if _showcase_tile == null:
		return
	var texture: Texture2D = _illust_texture if _view == "illust" else _ingame_texture
	_showcase_tile.portrait_texture = texture
	# 그림이 없는 쪽 탭을 골랐을 때 빈 칸이 아니라 안내가 뜨게 한다
	_showcase_tile.display_text = "" if texture != null else "그림 준비 중"
	_showcase_tile.display_font_size = 20

	for button in _view_tabs.get_children():
		if not (button is Button):
			continue
		var picked: bool = button.name == ("Illust" if _view == "illust" else "Ingame")
		button.add_theme_color_override("font_color",
			slot_text_color_focus if picked else slot_text_color)
		# 고른 쪽만 강조색으로 칠해서, 지금 뭘 보고 있는지 색으로 바로 보이게 한다
		var box := StyleBoxFlat.new()
		box.bg_color = slot_color_focus if picked else Color(0, 0, 0, 0)
		box.corner_radius_top_left = 5
		box.corner_radius_top_right = 5
		box.corner_radius_bottom_left = 5
		box.corner_radius_bottom_right = 5
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, box)
		button.modulate = Color(1, 1, 1)

func _on_view_tab_pressed(which: String) -> void:
	_view = "illust" if which == "Illust" else "ingame"
	_refresh_showcase()

# --------------------------------- 조작 ---------------------------------

## 상세창이 떠 있는 동안은 위/아래로 스킬 칸을 옮긴다.
## 좌우와 취소는 도감(CharacterDex)이 받아서 목록으로 되돌리므로 여기서 건드리지 않는다
## 위/아래를 꾹 누르고 있으면 촤르륵 넘어간다 — 처음 한 번, 잠깐 쉬고, 그 뒤로 빠르게 반복.
## 메인 메뉴·도감 목록과 같은 방식이다 (칸 포커스를 꺼 뒀으니 반복도 직접 돌려야 한다)
func _update_key_repeat(delta: float) -> void:
	if not visible:
		_held_step = 0
		return
	var step: int = 0
	if Input.is_action_pressed("ui_down"):
		step = 1
	elif Input.is_action_pressed("ui_up"):
		step = -1

	if step == 0:
		_held_step = 0
		return
	if step != _held_step:
		# 방금 누른 방향 — 한 칸 옮기고 첫 반복까지 쉰다
		_held_step = step
		_repeat_left = key_repeat_delay
		_move_slot(step)
		return
	_repeat_left -= delta
	if _repeat_left <= 0.0:
		_repeat_left = key_repeat_interval
		_move_slot(step)

## 위아래로 한 칸. 끝에서 멈추지 않고 반대쪽으로 돌아간다
func _move_slot(step: int) -> void:
	_show_skill(posmod(_slot_index + step, SLOT_ORDER.size()))

func _unhandled_input(event: InputEvent) -> void:
	if not visible or Engine.is_editor_hint():
		return
	# 위/아래는 _update_key_repeat가 맡는다 — 여기서 또 처리하면 한 번에 두 칸씩 뛴다.
	# 다만 도감 목록 쪽으로 새어 나가지 않게 먹어 두기만 한다
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
