class_name MainMenu
extends Control

## 타이틀 화면 다음에 나오는 메인 메뉴.
## 왼쪽에 모드 버튼 4개(스토리 모드 / 대전 모드 / 조작 방법 / 설정),
## 오른쪽에 캐릭터 일러스트(ui/MenuIllust.tscn)가 파츠별로 따로 움직인다.
##
## 일러스트를 움직이는 건 각 일러스트 씬(MenuIllust / JaemminIllust)이 하고,
## 위치·크기는 씬에 저장된 값을 그대로 쓴다.
##
## 이름이 "Illust"로 시작하는 자식이 여러 개면 illust_swap_seconds마다 한 장씩 번갈아 보여준다 —
## **트리에 놓인 순서가 곧 보여주는 순서**라, 순서를 바꾸려면 씬 트리에서 노드를 위아래로 옮기면 된다.
## 이름이 "Background"로 시작하는 자식도 같은 방식으로 모아서 **순서대로 짝을 지어** 같이 바꾼다
## (0번 일러스트 <-> 0번 배경). 배경 수가 모자라면 그 일러스트는 배경을 안 바꾼다.
## 바뀔 때는 툭 끊기지 않게 illust_fade_seconds 동안 서로 겹치며 페이드된다.
## 일러스트는 Control이 아니라 Node2D다 — Control은 앵커 레이아웃이 매 프레임 position을 되돌려놔서
## 코드로 움직이면 서로 싸운다.

## 일러스트를 코드로 자동 배치할지. **꺼두는 게 기본**이다 — 끄면 씬에 저장된 위치·크기를 그대로 써서
## 에디터에서 보이는 그대로가 게임 화면이 된다(눈으로 끌어다 맞출 수 있다).
## 새 일러스트를 넣어 크기가 완전히 다를 때만 잠깐 켜서 자동으로 맞춘 뒤, 나온 값을 저장하고 다시 끈다
@export var auto_place_illustration: bool = false
## 자동 배치를 켰을 때: 그림 원본 크기에 상관없이 화면에서 이 높이(px)가 되도록 배율을 맞춘다
@export var illust_height: float = 620.0
## 자동 배치를 켰을 때: 화면에서 일러스트의 한가운데가 놓일 자리
@export var illust_center: Vector2 = Vector2(950, 380)

@export_group("사선 메뉴")
## 커서를 올리거나 포커스가 오면 앞(오른쪽)으로 나오는 거리(px)
@export var menu_slide: float = 30.0
## 나오고 들어가는 빠르기. 클수록 빠릿하다
@export var menu_slide_speed: float = 12.0
## 평소 도형 색 — 다크 네이비(#252A34)
@export var menu_color: Color = Color(0.14509805, 0.16470589, 0.20392157, 0.82)
## 골라져 있을 때 도형 색의 기본값(아래 menu_accent_colors가 비었을 때만 쓰는 예비값)
@export var menu_color_focus: Color = Color(1.0, 0.18039216, 0.38823530, 0.95)
## 평소 / 골라져 있을 때 글자 색 — 라이트 그레이(#EAEAEA) / 흰색
@export var menu_text_color: Color = Color(0.91764706, 0.91764706, 0.91764706, 1.0)
@export var menu_text_color_focus: Color = Color(1.0, 1.0, 1.0, 1.0)
## 골라졌을 때 도형 둘레에 그려지는 선 두께 (ui/outline.gdshader — 사각형이 아니라 그림 모양을 따라간다)
@export var menu_outline_width: float = 2.0
## **항목마다 돌아가며 쓰는 포인트 색 2개** — 시안(#08D9D6) / 핑크(#FF2E63)를 섞어서 배치한다.
## i번째 항목은 이 목록의 (i % 크기)번째 색을 "골라졌을 때 도형 색"으로, 그 다음(i+1) 색을
## "테두리 색"으로 써서 두 색이 항목마다 자리를 바꿔가며 나온다 — 메뉴 전체가 한 색으로만
## 반짝이지 않고 시안/핑크가 번갈아 섞여 보이게 하려고 이렇게 나눴다
@export var menu_accent_colors: Array[Color] = [
	Color(0.03137255, 0.85098040, 0.83921570, 0.95),   # 시안 #08D9D6
	Color(1.0, 0.18039216, 0.38823530, 0.95),           # 핑크 #FF2E63
]

@export_group("화면 전환")
## 타이틀에서 어두워진 채로 넘어오므로, 켜질 때 검은 판이 걷히는 시간(초).
## 타이틀 쪽 enter_fade보다 살짝 길게 잡아서 "까매졌다 화앗" 하고 열리는 느낌을 준다
@export var enter_fade: float = 1.1

@export_group("일러스트 번갈아 보여주기")
## 일러스트 한 장을 보여주는 시간(초). 0이면 안 바꾸고 맨 앞 한 장만 계속 보여준다
@export var illust_swap_seconds: float = 10.0
## 다음 장으로 넘어갈 때 겹치며 바뀌는 시간(초). 0이면 툭 하고 바로 바뀐다
@export var illust_fade_seconds: float = 0.9
## 배경 위에 깔리는 어두운 판(`Scrim`)의 진하기. 왼쪽 메뉴 글씨가 배경에 묻히지 않게 하는 용도다
@export_range(0.0, 1.0, 0.01) var scrim_alpha: float = 0.45
## **여기 적은 일러스트는 아예 안 보여준다** (노드 이름). 씬에는 그대로 두고 순환에서만 뺀다 —
## 아직 손볼 데가 남은 일러스트를 지우지 않고 잠깐 감출 때 쓴다. 짝이 되는 배경도 같이 빠진다
@export var hidden_illusts: Array[String] = ["IllustCatMom"]
## **이 일러스트들일 때는 어두운 판을 걷는다** (노드 이름). 배경 자체가 이미 어두워서
## 덧씌우면 아무것도 안 보이는 경우에 쓴다 — 악플러(쓰레기방)가 그렇다
@export var no_scrim_illusts: Array[String] = ["IllustAkpeulleo"]
## (임시) **S를 누르면 다음 일러스트로 바로 넘긴다.** 새로 넣은 일러스트를 확인할 때 쓰는 것이라
## 정식 출시 전에는 꺼야 한다
@export var debug_illust_key: bool = true

@onready var _illust: MenuIllust = $Illust
@onready var _confirm: ConfirmPopup = $ConfirmPopup
## 화면 전체를 덮는 검은 판 — 켜질 때 이게 걷히면서 화면이 열린다
@onready var _screen_fade: ColorRect = $Fade
## 배경 위 어두운 판 — 일러스트마다 진하기가 다를 수 있어서 매 프레임 맞춰준다
@onready var _scrim: ColorRect = $Scrim
## 사선 메뉴 항목들 (트리 순서 = 위에서 아래 순서)
var _menu_items: Array[Button] = []
## 항목별로 정해진 "골라졌을 때 도형 색" — menu_accent_colors를 돌려가며 _build_menu()에서 채운다
var _focus_colors: Dictionary = {}
## 지금 커서가 올라가 있는 항목 (없으면 null)
var _hovered: Button = null
## 마지막으로 쓴 입력이 마우스인지. 마우스면 "커서가 올라간 것"만, 키보드면 "포커스"를 따라 튀어나온다.
## 처음엔 키보드 쪽으로 둬서 화면이 열릴 때 첫 항목이 골라져 보이게 한다
var _mouse_mode: bool = false

## 번갈아 보여줄 일러스트들과 그 짝이 되는 배경들 (트리 순서대로)
var _illusts: Array[Node2D] = []
var _backgrounds: Array[Node2D] = []
var _illust_index: int = 0
var _illust_time: float = 0.0
## 지금 페이드 중인지, 얼마나 진행됐는지, 어디로 넘어가는 중인지
var _fading: bool = false
var _fade_time: float = 0.0
var _next_index: int = 0
## 켜진 뒤 얼마나 지났는지 (검은 판을 걷는 데 쓴다)
var _enter_time: float = 0.0

## 확인 창에서 "확인"을 눌렀을 때 실행할 함수. 취소하면 버려진다
var _pending: Callable = Callable()

## 지금 떠 있는 설정 팝업 (없으면 null) — 메인 메뉴 위에 덮어 씌우는 방식이라 scene 전환을 안 한다
var _settings_popup: Settings = null
## 설정 팝업을 열기 전 포커스를 갖고 있던 컨트롤. 닫히면 여기로 되돌린다
var _settings_return_focus: Control = null

func _ready() -> void:
	if auto_place_illustration:
		_place_illustration()
	_collect_illustrations()
	_build_menu()
	_screen_fade.color.a = 1.0
	_confirm.confirmed.connect(_on_confirmed)
	_confirm.cancelled.connect(func(): _pending = Callable())
	# 키보드/패드로 바로 위아래 이동이 되도록 첫 항목에 포커스를 준다
	if not _menu_items.is_empty():
		_menu_items[0].grab_focus()

## 사선 메뉴 항목을 모아 눌렀을 때 할 일을 연결한다.
## 마우스를 올리면 그 항목으로 포커스를 넘겨서, **마우스든 방향키든 "골라진 것"이 하나로 통일**된다 —
## 연출은 포커스만 보고 돌아가므로 둘이 따로 놀 일이 없다
func _build_menu() -> void:
	var actions := {
		"StoryItem": _on_story_pressed,
		"VersusItem": _on_versus_pressed,
		"TrainingItem": _on_training_pressed,
		"GuideItem": _on_guide_pressed,
		"SettingsItem": _on_settings_pressed,
	}
	var index: int = 0
	for item_name in actions:
		var button: Button = $Menu.get_node_or_null(item_name)
		if button == null:
			continue
		button.pressed.connect(actions[item_name])
		button.mouse_entered.connect(_on_item_hovered.bind(button))
		button.mouse_exited.connect(_on_item_unhovered.bind(button))
		# 골라졌을 때 도형 색과 테두리 색을 서로 다른 포인트 색으로 배정한다 —
		# 이웃한 색을 쓰므로(i번째 도형 / i+1번째 테두리) 항목마다 시안/핑크가 자리를 바꿔가며 섞인다
		var focus_color: Color = _accent_color(index)
		_focus_colors[button] = focus_color
		# 항목마다 테두리를 따로 켜야 하므로 머티리얼을 복제한다 (같이 쓰면 5개가 한꺼번에 켜진다)
		var shape: TextureRect = button.get_node_or_null("Slide/Shape")
		if shape and shape.material:
			shape.material = shape.material.duplicate()
			shape.material.set_shader_parameter("line_color", _accent_color(index + 1))
			shape.material.set_shader_parameter("line_width", menu_outline_width)
			shape.material.set_shader_parameter("line_alpha", 0.0)
		_menu_items.append(button)
		index += 1
	_link_menu_focus()

## menu_accent_colors를 순환하며 index번째 포인트 색을 돌려준다. 비어 있으면 menu_color_focus로 대신한다
func _accent_color(index: int) -> Color:
	if menu_accent_colors.is_empty():
		return menu_color_focus
	return menu_accent_colors[index % menu_accent_colors.size()]

## 위/아래 방향키가 끝에서 멈추지 않고 반대쪽으로 돌아가게 잇는다.
## 맨 위에서 위를 누르면 맨 아래로, 맨 아래에서 아래를 누르면 맨 위로 — 눌러둔 채로 두면 계속 돈다
func _link_menu_focus() -> void:
	var count: int = _menu_items.size()
	if count < 2:
		return
	for i in range(count):
		var item: Button = _menu_items[i]
		item.focus_neighbor_top = item.get_path_to(_menu_items[(i - 1 + count) % count])
		item.focus_neighbor_bottom = item.get_path_to(_menu_items[(i + 1) % count])
		# Tab 이동도 같은 순서로 돌게
		item.focus_previous = item.focus_neighbor_top
		item.focus_next = item.focus_neighbor_bottom

## 커서가 항목에 올라오면 포커스도 같이 옮긴다 (마우스로 짚은 게 곧 선택된 것)
func _on_item_hovered(button: Button) -> void:
	_hovered = button
	_mouse_mode = true
	button.grab_focus()

## 커서가 항목에서 벗어나면 그 자리에서 도로 들어간다.
## 포커스는 그대로 두므로 방향키를 누르면 여기서부터 이어서 움직인다
func _on_item_unhovered(button: Button) -> void:
	if _hovered == button:
		_hovered = null

## 지금 튀어나와 있어야 할 항목. 마우스를 쓰는 중이면 커서가 올라간 것,
## 방향키를 쓰는 중이면 포커스가 있는 것 (둘을 섞으면 "마우스는 3번, 포커스는 1번"으로 갈린다)
func _active_menu_item() -> Button:
	if _mouse_mode:
		return _hovered
	for button in _menu_items:
		if button.has_focus():
			return button
	return null

## 골라진 항목만 앞으로 나오고 색이 진해진다.
## **움직이는 건 보이는 부분(Slide)뿐이고 클릭 판정(Button)은 제자리에 있다** —
## 판정까지 같이 움직이면 커서에서 도망가면서 들어갔다 나왔다 덜덜 떨린다
func _animate_menu(delta: float) -> void:
	# 방향키를 누른 순간부터는 마우스가 아니라 포커스를 따라간다
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
			var focus_color: Color = _focus_colors.get(button, menu_color_focus)
			shape.modulate = shape.modulate.lerp(focus_color if focused else menu_color, t)
			if shape.material:
				# 슬라이드가 얼마나 나왔는지를 그대로 선 진하기로 쓴다 (같이 나타났다 같이 사라진다).
				# 머티리얼에서 되읽지 않는 이유: get_shader_parameter는 값이 없으면 null을 준다
				var line: float = clampf(slide.position.x / maxf(menu_slide, 0.001), 0.0, 1.0)
				shape.material.set_shader_parameter("line_alpha", line)
		var text: Label = slide.get_node_or_null("Text")
		if text:
			var target: Color = menu_text_color_focus if focused else menu_text_color
			text.add_theme_color_override("font_color", text.get_theme_color("font_color").lerp(target, t))

## 이름이 "Illust"/"Background"로 시작하는 자식을 트리 순서대로 모으고, 첫 짝만 남기고 숨긴다.
## "Fx"로 시작하는 효과판은 여기서 안 모은다 — 트리 순서가 아니라 이름으로 짝짓는다(_pair_effect 참고)
func _collect_illustrations() -> void:
	# 먼저 트리 순서대로 다 모은 뒤(일러스트 i번 <-> 배경 i번이 짝),
	# hidden_illusts에 든 것만 **짝째로** 빼낸다. 한쪽만 빼면 그 뒤 번호가 밀려 짝이 어긋난다
	var all_illusts: Array[Node2D] = []
	var all_backgrounds: Array[Node2D] = []
	for child in get_children():
		if child is Node2D and child.name.begins_with("Illust"):
			all_illusts.append(child)
		elif child is Node2D and child.name.begins_with("Background"):
			all_backgrounds.append(child)
	for i in range(all_illusts.size()):
		var illust: Node2D = all_illusts[i]
		var background: Node2D = all_backgrounds[i] if i < all_backgrounds.size() else null
		if illust.name in hidden_illusts:
			illust.visible = false
			if background:
				background.visible = false
			continue
		_illusts.append(illust)
		_backgrounds.append(background)
	for i in range(_illusts.size()):
		if i == 0:
			_show_pair(i, 1.0)
		else:
			_hide_pair(i)
	_illust_index = 0
	_illust_time = 0.0
	_fading = false
	if not _illusts.is_empty():
		_scrim.color.a = _scrim_target(0)

## i번째 일러스트와 그 짝 배경 (배경이 모자라면 null).
## `_collect_illustrations`에서 이미 짝을 맞춰 담아 뒀으므로 같은 번호를 그대로 쓴다
func _pair_background(i: int) -> Node2D:
	return _backgrounds[i] if i < _backgrounds.size() else null

## i번째 일러스트와 그 짝 효과판 (없으면 null).
## 배경은 트리 순서(index)로 짝짓지만 **효과판은 이름으로 짝짓는다** —
## 캐릭터 하나에만 붙는 경우가 많아서, index로 맞추려면 빈 노드를 앞에 줄줄이 넣어야 하기 때문이다.
## `IllustSubway` <-> `FxSubway` 처럼 "Illust"를 "Fx"로 바꾼 이름을 찾는다
func _pair_effect(i: int) -> Node2D:
	return get_node_or_null("Fx" + _illusts[i].name.trim_prefix("Illust")) as Node2D

func _show_pair(i: int, alpha: float) -> void:
	_illusts[i].visible = true
	_illusts[i].modulate.a = alpha
	for node in [_pair_background(i), _pair_effect(i)]:
		if node:
			node.visible = true
			node.modulate.a = alpha

func _hide_pair(i: int) -> void:
	_illusts[i].visible = false
	_illusts[i].modulate.a = 1.0
	for node in [_pair_background(i), _pair_effect(i)]:
		if node:
			node.visible = false
			node.modulate.a = 1.0

func _set_pair_alpha(i: int, alpha: float) -> void:
	_illusts[i].modulate.a = alpha
	for node in [_pair_background(i), _pair_effect(i)]:
		if node:
			node.modulate.a = alpha

## i번째 일러스트일 때 어두운 판이 얼마나 진해야 하는지
func _scrim_target(i: int) -> float:
	if i < 0 or i >= _illusts.size():
		return scrim_alpha
	return 0.0 if _illusts[i].name in no_scrim_illusts else scrim_alpha

func _process(delta: float) -> void:
	# 켜질 때: 타이틀에서 넘어온 검은 판이 서서히 걷힌다
	if _screen_fade.color.a > 0.0:
		_enter_time += delta
		_screen_fade.color.a = clampf(1.0 - _enter_time / maxf(enter_fade, 0.001), 0.0, 1.0)

	_animate_menu(delta)

	if _illusts.size() < 2 or illust_swap_seconds <= 0.0:
		return
	if _fading:
		_fade_time += delta
		var t: float = clampf(_fade_time / maxf(illust_fade_seconds, 0.001), 0.0, 1.0)
		# 가는 쪽과 오는 쪽이 겹치며 바뀐다
		_set_pair_alpha(_illust_index, 1.0 - t)
		_set_pair_alpha(_next_index, t)
		# 어두운 판도 같이 넘어간다 — 안 그러면 배경만 바뀌고 어둡기가 툭 끊긴다
		_scrim.color.a = lerpf(_scrim_target(_illust_index), _scrim_target(_next_index), t)
		if t >= 1.0:
			_hide_pair(_illust_index)
			_illust_index = _next_index
			_fading = false
			_illust_time = 0.0
			_scrim.color.a = _scrim_target(_illust_index)
		return

	_illust_time += delta
	if _illust_time < illust_swap_seconds:
		return
	_begin_swap()

## 다음 일러스트로 넘어가기 시작한다 (시간이 다 됐을 때, 그리고 S를 눌렀을 때)
func _begin_swap() -> void:
	if _illusts.size() < 2 or _fading:
		return
	_next_index = (_illust_index + 1) % _illusts.size()
	_fading = true
	_fade_time = 0.0
	_show_pair(_next_index, 0.0)
	# 나타나는 순간부터 동작을 처음부터 돌린다 (그런 함수가 있는 노드만).
	# 효과판도 같이 다시 터뜨려야 등장할 때마다 집중선이 조여든다
	for node in [_illusts[_next_index], _pair_effect(_next_index)]:
		if node and node.has_method("restart"):
			node.restart()

## 파츠들은 원본 캔버스 좌표(왼쪽 위가 0,0)로 그려지므로, 가운데가 illust_center에 오도록 밀어준다.
## auto_place_illustration을 켰을 때만 돈다 — 평소엔 씬에 저장된 위치·크기가 그대로 쓰인다
func _place_illustration() -> void:
	var size: Vector2 = _illust.get_image_size()
	if size.y <= 0.0:
		return
	var factor: float = illust_height / size.y
	_illust.scale = Vector2.ONE * factor
	_illust.position = illust_center - size * factor * 0.5

func _on_story_pressed() -> void:
	_ask("스토리 모드를 플레이하시겠습니까?", _start_story)

func _on_versus_pressed() -> void:
	_ask("대전 모드를 플레이하시겠습니까?", _start_versus)

## 확인 창을 띄우고, 확인을 누르면 action을 실행한다
func _ask(message: String, action: Callable) -> void:
	_pending = action
	_confirm.open(message)

func _on_confirmed() -> void:
	if _pending.is_valid():
		_pending.call()
	_pending = Callable()

## 스토리 모드 — 2026-09-12 새로 짜는 중. 지금은 검은 화면 장면(ui/story/)이 페이드로 이어지는 뼈대만 있다.
## 옛 흐름(에피소드 선택 -> 캐릭터 선택 -> 대전 -> 개과천선 -> 클리어)은 통째로 걷어냈다
func _start_story() -> void:
	# 모드·진행도 초기화와 장면 전환은 GameState.start_story()가 한다 —
	# 일시정지 화면의 스토리 목록에서 고를 때도 같은 함수를 쓰므로 시작 경로가 하나로 모인다
	if not GameState.start_story("ep1"):
		push_warning("MainMenu: ep1 스토리 장면을 못 찾았다")

## 대전 모드 — 방 설정(선취 라운드/시간제한)부터 고른다
func _start_versus() -> void:
	GameState.game_mode = "pvp"
	GameState.story_next_scene = ""   # 일반 대전은 이야기로 이어지지 않는다
	GameState.reset_round_wins()
	get_tree().change_scene_to_file("res://ui/RoomSettings.tscn")

## 훈련장은 되돌릴 게 없어서 확인 창 없이 바로 들어간다 (스토리/대전만 진행도를 건드린다)
func _on_training_pressed() -> void:
	get_tree().change_scene_to_file("res://maps/TrainingGround.tscn")

## 가이드 = 조작 방법 + 도감을 묶은 갈림길 화면(2026-09-30).
## 둘 다 "읽어보는 것"이라 메뉴에서 한 줄씩 차지할 이유가 없었다
func _on_guide_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/Guide.tscn")

## 설정 화면은 씬 전환이 아니라 메인 메뉴 위에 팝업으로 덮어 씌운다 —
## 뒤에 메인 메뉴가 그대로 살아있으므로 Settings.tscn의 반투명 Scrim을 통해 살짝 비쳐 보인다
func _on_settings_pressed() -> void:
	if _settings_popup != null:
		return
	_settings_return_focus = get_viewport().gui_get_focus_owner()
	var settings_scene: PackedScene = load("res://ui/Settings.tscn")
	_settings_popup = settings_scene.instantiate()
	add_child(_settings_popup)
	_settings_popup.closed.connect(_on_settings_closed)
	_set_menu_buttons_visible(false)

func _on_settings_closed() -> void:
	_settings_popup = null
	_set_menu_buttons_visible(true)
	# 닫히면 원래 포커스를 갖고 있던 항목(보통 SettingsItem)으로 되돌려야 방향키 조작이 안 끊긴다
	if is_instance_valid(_settings_return_focus):
		_settings_return_focus.grab_focus()

## 설정 팝업이 떠 있는 동안 사선 메뉴 항목·도감 버튼·제목/힌트 글자를 통째로 숨긴다 —
## Scrim이 클릭은 막아주지만 반투명이라 뒤에 그대로 비치므로, 눈으로도 안 보이게 감춘다
func _set_menu_buttons_visible(is_visible: bool) -> void:
	# **도감·조작 방법 버튼을 따로 안 챙긴다** — 둘 다 사선 메뉴의 `Menu/GuideItem` 한 칸으로
	# 묶여 있어서, 여기서 `Menu`를 숨기면 같이 숨겨진다
	for node_name in ["Menu", "TitleLabel", "HintLabel"]:
		var node: CanvasItem = get_node_or_null(node_name)
		if node:
			node.visible = is_visible

## ESC로 나갈 때도 모드 진입과 똑같이 한 번 물어본다 (실수로 꺼지지 않게).
## 2026-09-28 사용자 요청으로 타이틀로 돌아가는 대신 **게임을 끈다**
func _quit_game() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	# 확인 창/설정 팝업이 떠 있으면 그쪽이 ESC를 먼저 먹는다(둘 다 set_input_as_handled까지 처리) —
	# 여기 있는 검사는 혹시 놓쳤을 때를 대비한 이중 방어다
	if _confirm.visible or _settings_popup != null:
		return
	# (임시) S를 누르면 다음 캐릭터 일러스트로 바로 넘어간다 — 새 일러스트를 확인하려고 10초씩
	# 기다리지 않으려고 넣은 것이다. 정식 기능이 아니므로 나중에 지우거나 debug 플래그로 묶을 것
	if debug_illust_key and event is InputEventKey:
		var key: InputEventKey = event
		var is_s: bool = key.keycode == KEY_S or key.physical_keycode == KEY_S
		if key.pressed and not key.echo and is_s:
			_begin_swap()
			_illust_time = 0.0
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel"):
		_ask("게임을 나가시겠습니까?", _quit_game)
