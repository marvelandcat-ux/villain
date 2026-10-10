class_name PauseMenu
extends CanvasLayer

## 대전 중 ESC로 여는 일시정지 화면 (2026-09-15 사용자 러프대로 전면 개편).
##
## **왼쪽**: 큰 "일시정지" 상자 + 사선 메뉴 4개(계속하기 / 다시하기 / 설정 / 메인메뉴로).
## **오른쪽**: 위 상자에 지금 진행 중인 스토리 이름, 그 아래 스토리 목록.
## 색감·사선 도형·튀어나오는 연출은 **메인 메뉴(ui/MainMenu.gd)와 같은 값**을 쓴다 — 같은 게임의 같은 메뉴로 보이게.
## 오른쪽 스토리 칸은 사선이 **왼쪽 끝**에 오도록 같은 그림을 `flip_h`로 뒤집어 쓴다(메뉴와 마주 보는 모양).
##
## - **아직 한 번도 클리어하지 못한 에피소드는 이름 대신 자물쇠(`ui/LockIcon.gd`)가 걸린다**(사용자 지정).
##   클리어 기록은 `GameState.story_cleared`(user://settings.cfg에 저장)이고, 스토리 마지막 장면
##   (`StoryFadeScene.clears_story`)에 닿으면 기록된다
## - **한 번 깬 에피소드는 눌러서 다시 할 수 있다**(2026-10-10 사용자 요청). 자물쇠가 걸린 칸은 못 누른다.
##   잘못 누를 수 있으니 바로 넘어가지 않고 `ConfirmPopup`으로 한 번 묻는다 —
##   누르는 순간 하던 장면이 날아가기 때문에 되돌릴 길이 없다
## - **스토리 모드가 아니면 오른쪽 전체가 숨는다**(`GameState.game_mode`) — 일반 대전에선 왼쪽 메뉴만 나온다
## - **대전 중에는 오른쪽 에피소드 목록과 왼쪽 "일시정지" 제목을 감춘다**
##   (`show_story_list` / `show_title` = false, 2026-09-15 사용자 요청) — 싸우다 멈춘 사람에게
##   다른 에피소드 목록까지 보여줄 이유가 없고, 제목도 화면을 좁게 만들어서 뺐다.
##   띄우는 쪽(`maps/Stage.gd`, `ui/PauseButton.gd`)이 add_child 하기 전에 이 값들을 꺼 준다
##
## 게임을 멈추는 것(`get_tree().paused`)도 이 스크립트가 직접 하고, 그래서 이 노드는
## `process_mode = ALWAYS`로 둔다 — 멈춘 동안에도 입력을 받아야 닫을 수 있다(궁극기 컷인과 같은 방식).

## 사선 도형 그림 — 메인 메뉴 항목과 **같은 그림 한 장을 재사용한다**(따로 뽑으면 사선 각도·두께가 어긋난다)
const SLANT_TEXTURE := preload("res://sprite/UI/메뉴사선_임시.png")
const LOCK_ICON := preload("res://ui/LockIcon.gd")
const SETTINGS_SCENE := "res://ui/Settings.tscn"
## 깬 에피소드를 다시 할 때 "정말…?"을 묻는 창 (메인 메뉴가 쓰는 것과 같은 것)
const CONFIRM_SCENE := "res://ui/ConfirmPopup.tscn"
## 흰 테두리 셰이더 — **왼쪽 메뉴 항목이 쓰는 그것과 같은 것**이라 선 두께·느낌이 저절로 맞는다
const OUTLINE_SHADER := preload("res://ui/outline.gdshader")

## 왼쪽 큰 "일시정지" 제목을 보여줄지. **대전 중에는 꺼서 메뉴만 남긴다**
@export var show_title: bool = true

@export_group("사선 메뉴")
## 커서를 올리거나 포커스가 오면 앞(오른쪽)으로 나오는 거리(px)
@export var menu_slide: float = 30.0
## 나오고 들어가는 빠르기. 클수록 빠릿하다
@export var menu_slide_speed: float = 12.0
## 평소 도형 색 / 골라져 있을 때 도형 색 (메인 메뉴와 같은 값)
@export var menu_color: Color = Color(0.09, 0.07, 0.13, 0.82)
@export var menu_color_focus: Color = Color(0.72, 0.18, 0.28, 0.95)
## 평소 / 골라져 있을 때 글자 색
@export var menu_text_color: Color = Color(0.86, 0.82, 0.92, 1.0)
@export var menu_text_color_focus: Color = Color(1.0, 1.0, 1.0, 1.0)
## 골라졌을 때 도형 둘레에 그려지는 선 색·두께 (ui/outline.gdshader)
@export var menu_outline_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var menu_outline_width: float = 2.0

@export_group("스토리 목록")
## 오른쪽 에피소드 목록을 보여줄지. **대전 중에는 꺼서 "진행 중인 스토리"만 남긴다**
@export var show_story_list: bool = true
## 칸 하나의 크기(px)와 칸 사이 간격(px)
@export var story_row_size: Vector2 = Vector2(620.0, 68.0)
@export var story_row_gap: float = 14.0
## 글자가 사선을 피해 들어갈 왼쪽 여백(px) — 사선이 왼쪽 끝 40px을 먹는다
@export var story_text_left: float = 58.0
## 지금 진행 중인 에피소드 칸 색 (나머지는 menu_color, 잠긴 칸은 아래 색)
@export var story_color_current: Color = Color(0.72, 0.18, 0.28, 0.95)
## 잠긴(한 번도 클리어 못 한) 칸 색 — 더 묽게 해서 "아직 못 여는 칸"으로 보이게
@export var story_color_locked: Color = Color(0.09, 0.07, 0.13, 0.5)
## 칸 글자 크기
@export var story_font_size: int = 24
## 깬 칸에 커서를 올렸을 때 **얼마나 커지는지**(1.06 = 6% 크게)와 테두리가 켜지는 속도.
## 커지는 건 안쪽(그림·글자)뿐이고 **클릭 판정은 제자리**다 — 판정까지 커지면 경계에서 덜덜 떤다
@export var story_hover_scale: float = 1.06
@export var story_hover_speed: float = 14.0

@export_group("등장 연출")
## 항목 하나가 제자리로 들어오는 시간(초)
@export var intro_time: float = 0.28
## **항목끼리 차례로 늦어지는 간격(초) — "촤르륵" 느낌을 정하는 값이다.**
## 0으로 두면 전부 한꺼번에 튀어나오고, 키우면 한 장씩 넘기듯 느려진다
@export var intro_stagger: float = 0.06
## 들어오기 전에 옆으로 밀려 있는 거리(px). 왼쪽 메뉴는 왼쪽에서, 오른쪽 목록은 오른쪽에서 들어온다
@export var intro_offset: float = 110.0
## 제목·진행 중 상자가 나타나는 시간(초) — 메뉴보다 먼저 떠 있어야 화면이 비어 보이지 않는다
@export var intro_header_time: float = 0.22

@onready var _menu: Control = $Menu
@onready var _title: Control = $TitleBox
@onready var _story_panel: Control = $StoryPanel
@onready var _current_name: Label = $StoryPanel/CurrentBox/CurrentName
@onready var _story_list: Control = $StoryPanel/StoryList

## 사선 메뉴 항목들 (트리 순서 = 위에서 아래 순서)
var _menu_items: Array[Button] = []
## 지금 커서가 올라가 있는 항목 (없으면 null)
var _hovered: Button = null
## 마지막으로 쓴 입력이 마우스인지. 처음엔 키보드 쪽으로 둬서 열릴 때 첫 항목이 골라져 보이게 한다
var _mouse_mode: bool = false
## 위에 얹혀 열려 있는 설정 화면 (없으면 null).
## **Control이 아니라 Settings로 타입을 잡아야 한다** — Control에는 `closed` 시그널이 없어서 파싱 에러가 난다
var _settings: Settings = null
## 누를 수 있는(= 이미 깬) 스토리 칸들. 커서가 올라오면 살짝 커지고 흰 테두리가 켜진다
var _story_rows: Array[Button] = []
## 지금 커서가 올라가 있는 스토리 칸 (없으면 null)
var _story_hovered: Button = null
## 위에 얹혀 열려 있는 "정말 다시 하시겠습니까?" 창 (없으면 null)
var _confirm: Node = null
## 그 창에서 확인을 누르면 시작할 에피소드 id
var _replay_id: String = ""

## 등장 연출: 차례로 들어올 것들. {node, rest_x(제자리 x), order(몇 번째로 들어올지), from(어느 쪽에서)}
var _intro_items: Array[Dictionary] = []
## 화면이 열린 뒤 흐른 시간(초). 다 끝나면 연출 계산을 아예 멈춘다
var _intro_t: float = 0.0
var _intro_done: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_menu()
	_title.visible = show_title
	_build_story_panel()
	_setup_intro()
	if not _menu_items.is_empty():
		_menu_items[0].grab_focus()

## 차례로 들어올 것들을 모으고, 첫 프레임부터 밀려 있도록 그 자리에 미리 놔둔다.
## **왼쪽 메뉴는 왼쪽에서, 오른쪽 스토리 칸은 오른쪽에서** 들어와 가운데로 모이는 모양이 된다.
## 순서는 **왼쪽 -> 오른쪽을 번갈아 세지 않고 각자 위에서 아래로** 센다 — 양쪽이 동시에 촤르륵 내려온다
func _setup_intro() -> void:
	for i in range(_menu_items.size()):
		_register_intro(_menu_items[i], i, -1.0)
	if _story_panel.visible:
		var rows: Array[Node] = _story_list.get_children()
		for i in range(rows.size()):
			_register_intro(rows[i] as Control, i, 1.0)
	_apply_intro(0.0)   # 첫 프레임에 제자리로 한 번 번쩍이지 않게 미리 밀어 둔다

## 한 노드를 등장 목록에 넣는다. from: -1 = 왼쪽에서 들어옴 / +1 = 오른쪽에서 들어옴
func _register_intro(node: Control, order: int, from: float) -> void:
	if node == null:
		return
	_intro_items.append({"node": node, "rest_x": node.position.x, "order": order, "from": from})

## 등장 연출을 지금 시각(t초)에 맞춰 그린다.
## **움직이는 건 항목(Button)·칸(Control) 자신이고, 그 안의 Slide는 안 건드린다** —
## Slide는 "골라진 항목이 튀어나오는" 연출이 이미 매 프레임 쓰고 있어서 둘이 겹치면 서로 덮어쓴다
func _apply_intro(t: float) -> void:
	var finished: bool = true
	for entry in _intro_items:
		var node: Control = entry["node"]
		if not is_instance_valid(node):
			continue
		var start: float = float(entry["order"]) * intro_stagger
		var progress: float = clampf((t - start) / maxf(intro_time, 0.001), 0.0, 1.0)
		if progress < 1.0:
			finished = false
		# 처음엔 빠르게 밀려왔다가 제자리에서 부드럽게 멎는다(ease out cubic) — 툭 서는 것보다 "촤르륵"에 가깝다
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)
		node.position.x = float(entry["rest_x"]) + float(entry["from"]) * intro_offset * (1.0 - eased)
		node.modulate.a = eased
	# 제목과 진행 중 상자는 밀려오지 않고 그 자리에서 나타나기만 한다(글자가 옆으로 흐르면 읽기 어렵다)
	var header: float = clampf(t / maxf(intro_header_time, 0.001), 0.0, 1.0)
	if show_title:
		_title.modulate.a = header
	_story_panel.modulate.a = header
	if finished and header >= 1.0:
		_intro_done = true

## 사선 메뉴 항목을 모아 눌렀을 때 할 일을 연결한다 (MainMenu._build_menu와 같은 방식).
## 마우스를 올리면 그 항목으로 포커스를 넘겨서 **마우스든 방향키든 "골라진 것"이 하나로 통일**된다
func _build_menu() -> void:
	var actions := {
		"ResumeItem": _on_resume_pressed,
		"RetryItem": _on_retry_pressed,
		"SettingsItem": _on_settings_pressed,
		"MenuItem": _on_menu_pressed,
	}
	for item_name in actions:
		var button: Button = _menu.get_node_or_null(item_name)
		if button == null:
			continue
		button.pressed.connect(actions[item_name])
		button.mouse_entered.connect(_on_item_hovered.bind(button))
		button.mouse_exited.connect(_on_item_unhovered.bind(button))
		# 항목마다 테두리를 따로 켜야 하므로 머티리얼을 복제한다 (같이 쓰면 4개가 한꺼번에 켜진다)
		var shape: TextureRect = button.get_node_or_null("Slide/Shape")
		if shape and shape.material:
			shape.material = shape.material.duplicate()
			shape.material.set_shader_parameter("line_color", menu_outline_color)
			shape.material.set_shader_parameter("line_width", menu_outline_width)
			shape.material.set_shader_parameter("line_alpha", 0.0)
		_menu_items.append(button)
	_link_menu_focus()

## 위/아래 방향키가 끝에서 멈추지 않고 반대쪽으로 돌아가게 잇는다
func _link_menu_focus() -> void:
	var count: int = _menu_items.size()
	if count < 2:
		return
	for i in range(count):
		var item: Button = _menu_items[i]
		item.focus_neighbor_top = item.get_path_to(_menu_items[(i - 1 + count) % count])
		item.focus_neighbor_bottom = item.get_path_to(_menu_items[(i + 1) % count])
		item.focus_previous = item.focus_neighbor_top
		item.focus_next = item.focus_neighbor_bottom

func _on_item_hovered(button: Button) -> void:
	_hovered = button
	_mouse_mode = true
	button.grab_focus()

func _on_item_unhovered(button: Button) -> void:
	if _hovered == button:
		_hovered = null

## 지금 튀어나와 있어야 할 항목. 마우스를 쓰는 중이면 커서가 올라간 것, 방향키를 쓰는 중이면 포커스가 있는 것
func _active_menu_item() -> Button:
	if _mouse_mode:
		return _hovered
	for button in _menu_items:
		if button.has_focus():
			return button
	return null

## 골라진 항목만 앞으로 나오고 색이 진해진다.
## **움직이는 건 보이는 부분(Slide)뿐이고 클릭 판정(Button)은 제자리에 있다** — 판정까지 움직이면 호버가 덜덜 떨린다
func _process(delta: float) -> void:
	if _settings != null:
		return   # 설정이 위에 열려 있는 동안은 뒤에서 혼자 움직이지 않게
	if not _intro_done:
		_intro_t += delta
		_apply_intro(_intro_t)
	if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
		_mouse_mode = false
	var active: Button = _active_menu_item()
	var t: float = clampf(delta * menu_slide_speed, 0.0, 1.0)
	for button in _menu_items:
		var slide: Control = button.get_node_or_null("Slide")
		if slide == null:
			continue
		var focused: bool = button == active
		slide.position.x = lerpf(slide.position.x, menu_slide if focused else 0.0, t)
		var shape: TextureRect = slide.get_node_or_null("Shape")
		if shape:
			shape.modulate = shape.modulate.lerp(menu_color_focus if focused else menu_color, t)
			if shape.material:
				# 슬라이드가 얼마나 나왔는지를 그대로 선 진하기로 쓴다 (같이 나타났다 같이 사라진다)
				var line: float = clampf(slide.position.x / maxf(menu_slide, 0.001), 0.0, 1.0)
				shape.material.set_shader_parameter("line_alpha", line)
		var text: Label = slide.get_node_or_null("Text")
		if text:
			var target: Color = menu_text_color_focus if focused else menu_text_color
			text.add_theme_color_override("font_color", text.get_theme_color("font_color").lerp(target, t))
	_animate_story_rows(delta)

## 깬 스토리 칸 — 커서가 올라간 것만 **살짝 커지고 흰 테두리가 켜진다**(2026-10-10 사용자:
## "다른 버튼 누르듯이"). 왼쪽 메뉴와 같은 테두리 셰이더를 쓰므로 선 느낌이 같다
func _animate_story_rows(delta: float) -> void:
	if _story_rows.is_empty():
		return
	var t: float = clampf(delta * story_hover_speed, 0.0, 1.0)
	for row in _story_rows:
		if not is_instance_valid(row):
			continue
		var inner: Control = row.get_node_or_null("Inner")
		if inner == null:
			continue
		# 확인 창이 떠 있는 동안은 전부 가라앉혀 둔다 — 그 뒤에서 혼자 빛나면 눈에 거슬린다
		var on: bool = _confirm == null and row == _story_hovered
		var want: float = story_hover_scale if on else 1.0
		inner.scale = inner.scale.lerp(Vector2(want, want), t)
		var shape: TextureRect = inner.get_node_or_null("Shape")
		if shape == null or shape.material == null:
			continue
		# 얼마나 커졌는지를 그대로 선 진하기로 쓴다 — 왼쪽 메뉴가 슬라이드 거리를 쓰는 것과 같은 방식
		var grown: float = clampf((inner.scale.x - 1.0) / maxf(story_hover_scale - 1.0, 0.001), 0.0, 1.0)
		shape.material.set_shader_parameter("line_alpha", grown)

## 오른쪽 전체 — 진행 중인 스토리 이름과 목록. 스토리 모드가 아니면 통째로 숨긴다
func _build_story_panel() -> void:
	if GameState.game_mode != "story":
		_story_panel.visible = false
		return
	var current: String = GameState.current_story_name()
	_current_name.text = current if current != "" else "진행 중인 스토리 없음"
	_story_list.visible = show_story_list
	if show_story_list:
		_build_story_list()

## `GameState.STORY_EPISODES` 순서 그대로 칸을 만든다.
## **에피소드를 추가·삭제해도 여기는 안 고쳐도 된다** — 그 목록 한 줄만 고치면 칸이 따라 생긴다
func _build_story_list() -> void:
	_story_rows.clear()
	for child in _story_list.get_children():
		child.queue_free()
	var y: float = 0.0
	for episode in GameState.STORY_EPISODES:
		var id: String = episode["id"]
		var is_current: bool = id == GameState.current_story_id
		# 진행 중인 에피소드는 아직 못 깼어도 자물쇠를 안 건다 — 이름이 이미 위 상자에 떠 있어서 가릴 이유가 없다
		var is_locked: bool = not is_current and not GameState.is_story_cleared(id)
		# **깬 에피소드만 누를 수 있다** — 자물쇠가 걸린 칸은 예전처럼 보여주기만 하는 Control이다.
		# 누를 수 있는 칸은 Button이라야 마우스·키보드가 모두 먹는다
		var can_replay: bool = not is_locked and GameState.is_story_cleared(id) \
			and GameState.story_episode(id).get("scene", "") != ""
		var row: Control
		if can_replay:
			var button := Button.new()
			button.flat = true
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(_on_story_row_pressed.bind(id, episode["name"]))
			# 왼쪽 메뉴와 같은 방식으로 커서를 받는다 — 좌표를 직접 재면 CanvasLayer 변환에
			# 걸려서 안 맞는다(2026-10-10 실측)
			button.mouse_entered.connect(_on_story_row_hovered.bind(button))
			button.mouse_exited.connect(_on_story_row_unhovered.bind(button))
			row = button
		else:
			row = Control.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.position = Vector2(0.0, y)
		row.size = story_row_size
		_story_list.add_child(row)

		# **커지는 건 이 안쪽뿐**이다. 가운데를 축으로 삼아야 양옆이 고르게 부푼다
		var inner := Control.new()
		inner.name = "Inner"
		inner.size = story_row_size
		inner.pivot_offset = story_row_size * 0.5
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(inner)

		var shape := TextureRect.new()
		shape.name = "Shape"   # _animate_story_rows가 이 이름으로 찾는다
		shape.texture = SLANT_TEXTURE
		# 사선을 **왼쪽 끝**으로 보낸다 — 왼쪽 메뉴와 마주 보는 모양(사용자 러프)
		shape.flip_h = true
		shape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shape.stretch_mode = TextureRect.STRETCH_SCALE
		shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape.size = story_row_size
		# 흰 그림에 색을 입히는 방식이라 색은 전부 modulate로 정한다(메인 메뉴와 같다)
		shape.modulate = story_color_current if is_current else (story_color_locked if is_locked else menu_color)
		if can_replay:
			# 누를 수 있는 칸에만 흰 테두리를 단다 — 꺼 둔 채로 붙이고 커서가 올라오면 켠다.
			# **칸마다 복제**해야 한 칸을 비출 때 나머지가 같이 빛나지 않는다
			var outline := ShaderMaterial.new()
			outline.shader = OUTLINE_SHADER
			outline.set_shader_parameter("line_color", menu_outline_color)
			outline.set_shader_parameter("line_width", menu_outline_width)
			outline.set_shader_parameter("line_alpha", 0.0)
			shape.material = outline
		inner.add_child(shape)

		if is_locked:
			# **이름 대신 자물쇠** — 클리어 전에는 어떤 이야기인지 안 보여준다(사용자 지정)
			var lock: Control = LOCK_ICON.new()
			lock.size = Vector2(story_row_size.y * 0.5, story_row_size.y * 0.5)
			lock.position = Vector2(story_text_left, (story_row_size.y - lock.size.y) * 0.5)
			inner.add_child(lock)
		else:
			var text := Label.new()
			text.text = episode["name"]
			text.position = Vector2(story_text_left, 0.0)
			text.size = Vector2(story_row_size.x - story_text_left - 20.0, story_row_size.y)
			text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			text.mouse_filter = Control.MOUSE_FILTER_IGNORE
			text.add_theme_font_size_override("font_size", story_font_size)
			text.add_theme_color_override("font_color", menu_text_color_focus if is_current else menu_text_color)
			inner.add_child(text)
		if can_replay:
			_story_rows.append(row)
		y += story_row_size.y + story_row_gap

func _on_story_row_hovered(row: Button) -> void:
	_story_hovered = row

func _on_story_row_unhovered(row: Button) -> void:
	if _story_hovered == row:
		_story_hovered = null

## 깬 에피소드 칸을 눌렀다 — **바로 넘어가지 않고 한 번 묻는다**(잘못 눌렀을 수 있다).
## 확인을 누르면 하던 장면은 버리고 그 에피소드를 처음부터 시작한다
func _on_story_row_pressed(id: String, name: String) -> void:
	if _confirm != null:
		return   # 이미 묻는 중
	var scene: PackedScene = load(CONFIRM_SCENE)
	if scene == null:
		push_warning("PauseMenu: 확인 창을 못 찾았다 — %s" % CONFIRM_SCENE)
		return
	_replay_id = id
	_confirm = scene.instantiate()
	# 게임이 멈춰 있어도(`paused = true`) 열리고 눌려야 한다 — 설정 창과 같은 이유
	_confirm.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_confirm)
	_confirm.confirmed.connect(_on_replay_confirmed)
	_confirm.cancelled.connect(_on_replay_cancelled)
	_confirm.open("정말 %s%s 다시 하시겠습니까?" % [name, _object_particle(name)])

## 이름 끝 글자의 **받침 유무**로 "을/를"을 고른다 — "첫 임무를", "악플러를"처럼 읽히게
func _object_particle(text: String) -> String:
	if text.is_empty():
		return "을(를)"
	var code: int = text.unicode_at(text.length() - 1)
	if code < 0xAC00 or code > 0xD7A3:
		return "을(를)"   # 한글이 아니면(숫자·영문) 고를 수가 없다
	return "을" if (code - 0xAC00) % 28 != 0 else "를"

func _on_replay_confirmed() -> void:
	var id: String = _replay_id
	_clear_confirm()
	get_tree().paused = false
	if not GameState.start_story(id):
		push_warning("PauseMenu: 에피소드 장면을 못 찾았다 — %s" % id)
		return
	queue_free()

func _on_replay_cancelled() -> void:
	_clear_confirm()

## 창을 치운다 — `ConfirmPopup`은 스스로 숨기만 하고 지워지지 않아서,
## 안 치우면 취소할 때마다 숨은 창이 하나씩 쌓인다
func _clear_confirm() -> void:
	_replay_id = ""
	if is_instance_valid(_confirm):
		_confirm.queue_free()
	_confirm = null

func _unhandled_input(event: InputEvent) -> void:
	if _confirm != null:
		return   # 확인 창이 열려 있으면 ESC는 그쪽이 받는다
	if _settings != null:
		return   # 설정이 열려 있으면 ESC는 설정이 받는다 (여기서도 받으면 둘이 한꺼번에 닫힌다)
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	queue_free()

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

## 설정은 **화면을 바꾸지 않고 이 위에 얹어서 연다** — 대전 중이라 장면을 바꾸면 하던 판이 날아간다.
## Settings는 **언제나** 자기만 닫고 `closed`를 보내므로 따로 켜 줄 스위치가 없다
## (2026-09-16 머지 전에는 `overlay_mode = true`를 줬는데, 지금 Settings는 늘 팝업이라 그 스위치를 없앴다).
## **Settings의 열기/닫기 연출은 `_process`로 도는데 여기는 `paused = true`다** —
## 이 PauseMenu가 `PROCESS_MODE_ALWAYS`라 자식으로 붙는 Settings가 그걸 물려받아 정상 동작한다
func _on_settings_pressed() -> void:
	if _settings != null:
		return
	var scene: PackedScene = load(SETTINGS_SCENE)
	if scene == null:
		push_warning("PauseMenu: 설정 화면을 못 찾았다 — %s" % SETTINGS_SCENE)
		return
	_settings = scene.instantiate()
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)   # 맨 마지막 자식 = 맨 위에 그려짐

func _on_settings_closed() -> void:
	_settings = null
	# 설정에 갔던 포커스를 메뉴로 돌려준다 (안 하면 방향키 조작이 끊긴다 — ConfirmPopup과 같은 처리)
	if not _menu_items.is_empty():
		_menu_items[0].grab_focus()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
