@tool
class_name KeyboardMap
extends Control

## 키 배정 화면 — **키보드를 그대로 그려 놓고, 키를 끌어다 다른 키에 놓으면 그 조작이 옮겨간다.**
## (2026-09-29 신규) 설정 > 조작 탭이 쓰던 "칸을 누르고 새 키를 입력" 방식을 대신한다.
##
## 색이 곧 주인이다 — 아무도 안 쓰는 키는 **회색**, 1P가 쓰는 키는 **파랑**, 2P가 쓰는 키는 **빨강**.
## 키 위에는 조작 이름(점프·방어 …)이 같이 적힌다.
##
## 그리는 방식은 버튼 노드를 60개 놓는 대신 **한 장의 Control에 직접 그린다**(`_draw`).
## 키마다 노드를 만들면 씬이 지저분해지고, 끌어다 놓는 동안 노드 사이로 마우스가 새어나가서
## "지금 어느 키 위인지"를 판단하기가 오히려 까다로워진다.
##
## 풀배열이다 — 방향키 뭉치 오른쪽에 숫자패드까지 있다(2026-10-01 추가).

## 키 배정이 바뀌었을 때(끌어놓기·되돌리기) 알린다. 설정 화면이 다른 표시를 갱신하는 데 쓴다
signal binding_changed

## 한국어가 들어간 글자를 직접 그리므로 글꼴이 필요하다 — 기본 글꼴에는 한글이 없다
const FONT := preload("res://fonts/Jua-Regular.ttf")

## 손으로 그린 키캡 그림(`use_keycap_sprite`를 켜면 정사각형 한 칸짜리 키에만 쓴다).
## **2026-09-29 한 번 켜봤다가 껐다** — 사용자가 그냥 네모가 낫다고 했다.
## 긴 키(Tab·Shift·Space)는 그림을 늘리면 테두리가 가로로만 두꺼워져서 어차피 같이 못 쓴다
const KEYCAP := preload("res://sprite/키보드키/키보드키.png")
## 그림에서 실제로 그려진 부분(알파 bbox) — 캔버스 여백을 빼야 키 칸에 꽉 찬다
const KEYCAP_REGION := Rect2(269, 250, 743, 729)
## 키캡 가운데(면)의 밝기. 원하는 색으로 보이게 하려면 색을 이 값으로 나눠서 곱해야 한다 —
## `modulate`는 곱셈이라 그냥 파랑을 곱하면 원래 회색만큼 어두워진다
const KEYCAP_FACE := 0.424

## 이 화면에서 바꿀 수 있는 조작. **순서가 곧 설명 순서**다
const ACTIONS := ["left", "right", "jump", "down", "basic_attack", "skill_1", "skill_2", "ultimate", "map_skill"]

## 키 위에 적을 이름. 좌우는 한 쌍이라 둘 다 "좌우이동"이다.
## 아래 키는 발판 내려가기(한 번) 전용이다 — 방어는 기본공격+스킬1 동시 누르기(2026-10-08). 맵 전용 스킬은 자기 키가 따로 있다
const ACTION_LABELS := {
	"left": "좌우이동",
	"right": "좌우이동",
	"jump": "점프",
	"down": "내려가기",
	"basic_attack": "기본공격",
	"skill_1": "스킬1",
	"skill_2": "스킬2",
	"ultimate": "궁극기",
	"map_skill": "맵 전용",
}

## 키 한 칸(1u)의 크기와 키 사이 틈(px). 한 줄은 15u, 방향키까지 18.5u, 숫자패드까지 넣으면 23u다
@export var unit: float = 52.0:
	set(value):
		unit = value
		_build_keys()
		queue_redraw()
@export var gap: float = 6.0:
	set(value):
		gap = value
		_build_keys()
		queue_redraw()
## 키 한 칸의 **가로/세로 비율**. 1이면 정사각형인데 그러면 키보드가 세로로 뚱뚱해 보인다 —
## 진짜 키보드 키캡도 가로가 조금 더 길다
@export var key_aspect: float = 1.2:
	set(value):
		key_aspect = value
		_build_keys()
		queue_redraw()

## **읽기 전용** — 켜면 끌어다 놓기를 막고 보여주기만 한다(조작 방법 화면에서 쓴다)
@export var read_only: bool = false:
	set(value):
		read_only = value
		if is_node_ready():
			mouse_filter = Control.MOUSE_FILTER_IGNORE if read_only else Control.MOUSE_FILTER_STOP

## 정사각형 키를 손그림 키캡으로 그릴지. **기본은 꺼짐**(네모)
@export var use_keycap_sprite: bool = false:
	set(value):
		use_keycap_sprite = value
		queue_redraw()

@export_group("색")
## 아무 조작도 안 걸린 키
@export var key_color: Color = Color(0.16, 0.16, 0.18, 1.0)
@export var key_outline: Color = Color(0.35, 0.35, 0.40, 1.0)
## 1P가 쓰는 키 / 2P가 쓰는 키
@export var p1_color: Color = Color(0.11, 0.53, 0.90, 1.0)
@export var p2_color: Color = Color(0.90, 0.22, 0.21, 1.0)
## 끌고 있는 키를 놓을 수 있는 자리에 마우스를 올렸을 때 덧칠하는 테두리
@export var drop_color: Color = Color(1.0, 0.93, 0.45, 1.0)
@export var text_color: Color = Color(0.92, 0.92, 0.95, 1.0)

## 키 이름(Esc·A·Space …) 글자 크기와, 그 아래 적히는 조작 이름 글자 크기
@export var key_font_size: int = 15
@export var label_font_size: int = 12

## 한 칸: [표시할 이름, 키코드, 폭(u), 좌우위치]. 폭이 없으면 1u, 위치가 없으면 0(양쪽 다).
## **위치는 Shift·Ctrl·Alt·Win처럼 같은 키코드가 양쪽에 있는 키에만 준다** —
## 안 주면 오른쪽 Shift에 올려놔도 왼쪽 Shift로 눌린다(키코드가 같아서 구분이 안 된다).
## `null`은 그 자리를 비운다(폭만 차지) — F1 앞 틈처럼
const LAYOUT := [
	[["Esc", KEY_ESCAPE], [null, 0, 1.0],
	 ["F1", KEY_F1], ["F2", KEY_F2], ["F3", KEY_F3], ["F4", KEY_F4], [null, 0, 0.5],
	 ["F5", KEY_F5], ["F6", KEY_F6], ["F7", KEY_F7], ["F8", KEY_F8], [null, 0, 0.5],
	 ["F9", KEY_F9], ["F10", KEY_F10], ["F11", KEY_F11], ["F12", KEY_F12]],
	[["`", KEY_QUOTELEFT], ["1", KEY_1], ["2", KEY_2], ["3", KEY_3], ["4", KEY_4], ["5", KEY_5],
	 ["6", KEY_6], ["7", KEY_7], ["8", KEY_8], ["9", KEY_9], ["0", KEY_0],
	 ["-", KEY_MINUS], ["=", KEY_EQUAL], ["Back", KEY_BACKSPACE, 2.0]],
	[["Tab", KEY_TAB, 1.5], ["Q", KEY_Q], ["W", KEY_W], ["E", KEY_E], ["R", KEY_R], ["T", KEY_T],
	 ["Y", KEY_Y], ["U", KEY_U], ["I", KEY_I], ["O", KEY_O], ["P", KEY_P],
	 ["[", KEY_BRACKETLEFT], ["]", KEY_BRACKETRIGHT], ["\\", KEY_BACKSLASH, 1.5]],
	[["Caps", KEY_CAPSLOCK, 1.75], ["A", KEY_A], ["S", KEY_S], ["D", KEY_D], ["F", KEY_F], ["G", KEY_G],
	 ["H", KEY_H], ["J", KEY_J], ["K", KEY_K], ["L", KEY_L],
	 [";", KEY_SEMICOLON], ["'", KEY_APOSTROPHE], ["Enter", KEY_ENTER, 2.25]],
	[["Shift", KEY_SHIFT, 2.25, KEY_LOCATION_LEFT], ["Z", KEY_Z], ["X", KEY_X], ["C", KEY_C],
	 ["V", KEY_V], ["B", KEY_B], ["N", KEY_N], ["M", KEY_M],
	 [",", KEY_COMMA], [".", KEY_PERIOD], ["/", KEY_SLASH],
	 ["Shift", KEY_SHIFT, 2.75, KEY_LOCATION_RIGHT]],
	[["Ctrl", KEY_CTRL, 1.25, KEY_LOCATION_LEFT], ["Win", KEY_META, 1.25, KEY_LOCATION_LEFT],
	 ["Alt", KEY_ALT, 1.25, KEY_LOCATION_LEFT],
	 ["Space", KEY_SPACE, 6.25], ["Alt", KEY_ALT, 1.25, KEY_LOCATION_RIGHT],
	 ["Win", KEY_META, 1.25, KEY_LOCATION_RIGHT],
	 ["Menu", KEY_MENU, 1.25], ["Ctrl", KEY_CTRL, 1.25, KEY_LOCATION_RIGHT]],
]

## 방향키 위 편집 뭉치 — 진짜 텐키리스처럼 3칸씩 세 줄. [이름, 키코드, x(u), 줄 번호]
const EXTRAS := [
	["PrtSc", KEY_PRINT, 15.5, 0], ["ScrLk", KEY_SCROLLLOCK, 16.5, 0], ["Pause", KEY_PAUSE, 17.5, 0],
	["Ins", KEY_INSERT, 15.5, 1], ["Home", KEY_HOME, 16.5, 1], ["PgUp", KEY_PAGEUP, 17.5, 1],
	["Del", KEY_DELETE, 15.5, 2], ["End", KEY_END, 16.5, 2], ["PgDn", KEY_PAGEDOWN, 17.5, 2],
]

## 방향키 뭉치 — 본체(15u) 오른쪽에 반 칸 띄우고 붙인다. [이름, 키코드, x(u), 줄 번호]
const ARROWS := [
	["▲", KEY_UP, 16.5, 4],
	["◀", KEY_LEFT, 15.5, 5],
	["▼", KEY_DOWN, 16.5, 5],
	["▶", KEY_RIGHT, 17.5, 5],
]

## 숫자패드 — 편집 뭉치 오른쪽에 반 칸 띄운다. [이름, 키코드, x(u), 줄 번호, 폭(u), 높이(줄)]
## +와 숫자패드 Enter는 두 줄짜리, 0은 두 칸짜리. 키코드는 KEY_KP_* — 위쪽 숫자줄(KEY_1 …)과 따로 배정된다
const NUMPAD := [
	["Num", KEY_NUMLOCK, 19.0, 1, 1, 1], ["/", KEY_KP_DIVIDE, 20.0, 1, 1, 1],
	["*", KEY_KP_MULTIPLY, 21.0, 1, 1, 1], ["-", KEY_KP_SUBTRACT, 22.0, 1, 1, 1],
	["7", KEY_KP_7, 19.0, 2, 1, 1], ["8", KEY_KP_8, 20.0, 2, 1, 1], ["9", KEY_KP_9, 21.0, 2, 1, 1],
	["+", KEY_KP_ADD, 22.0, 2, 1, 2],
	["4", KEY_KP_4, 19.0, 3, 1, 1], ["5", KEY_KP_5, 20.0, 3, 1, 1], ["6", KEY_KP_6, 21.0, 3, 1, 1],
	["1", KEY_KP_1, 19.0, 4, 1, 1], ["2", KEY_KP_2, 20.0, 4, 1, 1], ["3", KEY_KP_3, 21.0, 4, 1, 1],
	["Enter", KEY_KP_ENTER, 22.0, 4, 1, 2],
	["0", KEY_KP_0, 19.0, 5, 2, 1], [".", KEY_KP_PERIOD, 21.0, 5, 1, 1],
]

## 키보드 전체 폭(u) — 숫자패드 오른쪽 끝
const TOTAL_WIDTH_U := 23.0

## 그려 둔 키들 — {"rect": Rect2, "code": 키코드, "name": 표시 이름}
var _keys: Array = []
## 키코드 -> 그 키에 걸린 액션 이름들(["p1_jump", ...]). 매번 InputMap에서 다시 만든다
var _bindings: Dictionary = {}

## 지금 끌고 있는 액션(빈 문자열이면 안 끌고 있음)과 집어 올린 키코드
var _drag_action: String = ""
## 집어 올린 키("키코드:좌우위치")
var _drag_from: String = ""
## 키의 어느 지점을 집었는지(키 왼쪽 위 기준). 딱지가 **집은 그대로** 손에 붙어 따라오게 한다 —
## 딱지 한가운데를 커서에 붙이면 눈에 보이는 자리와 실제로 바뀌는 자리가 어긋난다
var _drag_grab: Vector2 = Vector2.ZERO
## 끄는 동안 버튼이 실제로 눌려 있는 걸 봤는지 (위 감시가 헛돌지 않게 하는 빗장)
var _drag_held: bool = false
var _mouse_pos: Vector2 = Vector2.ZERO
## 마우스가 올라가 있는 키의 번호(-1이면 없음)
var _hover: int = -1

func _ready() -> void:
	# 읽기 전용이면 마우스를 아예 안 받는다 — 뒤에 있는 버튼이 가려지지도 않는다
	mouse_filter = Control.MOUSE_FILTER_IGNORE if read_only else Control.MOUSE_FILTER_STOP
	set_process(false)   # 끌고 있을 때만 돈다(놓기를 놓치지 않으려는 감시)
	_build_keys()
	refresh()

## 키 자리를 계산해 `_keys`에 채운다. 크기(unit·gap)가 바뀌면 다시 부른다
func _build_keys() -> void:
	_keys.clear()
	var uw: float = unit * key_aspect
	for r in range(LAYOUT.size()):
		var x: float = 0.0
		for entry in LAYOUT[r]:
			var w: float = float(entry[2]) if entry.size() > 2 else 1.0
			if entry[0] != null:
				_keys.append({
					"rect": Rect2(x, float(r) * (unit + gap), w * uw + (w - 1.0) * gap, unit),
					"code": int(entry[1]),
					"loc": int(entry[3]) if entry.size() > 3 else 0,
					"name": str(entry[0]),
				})
			x += w * (uw + gap)
	for a in ARROWS + EXTRAS:
		_keys.append({
			"rect": Rect2(float(a[2]) * (uw + gap), float(a[3]) * (unit + gap), uw, unit),
			"code": int(a[1]),
			"loc": 0,
			"name": str(a[0]),
		})
	for n in NUMPAD:
		var w: float = float(n[4])
		var h: float = float(n[5])
		_keys.append({
			"rect": Rect2(float(n[2]) * (uw + gap), float(n[3]) * (unit + gap),
				w * uw + (w - 1.0) * gap, h * unit + (h - 1.0) * gap),
			"code": int(n[1]),
			"loc": 0,
			"name": str(n[0]),
		})
	custom_minimum_size = Vector2(TOTAL_WIDTH_U * (uw + gap) - gap, LAYOUT.size() * (unit + gap) - gap)

## InputMap에 지금 들어 있는 배정을 읽어 색을 다시 칠한다.
## **게임이 실제로 쓰는 값이 곧 화면이다** — 이 화면은 따로 사본을 들고 있지 않는다
func refresh() -> void:
	_bindings.clear()
	for action in _all_actions():
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key_event := event as InputEventKey
				var id: String = _bind_id(key_event.physical_keycode, key_event.location)
				if not _bindings.has(id):
					_bindings[id] = []
				_bindings[id].append(action)
	queue_redraw()

## 배정을 세는 열쇠. **키코드만으로는 안 된다** — 양쪽 Shift는 키코드가 같아서
## 한쪽에 올려놓으면 반대쪽에도 똑같이 칠해졌다(2026-09-29)
func _bind_id(code: int, location: int) -> String:
	return "%d:%d" % [code, location]

## 화면에 그려 둔 키 한 칸의 열쇠
func _key_id(key: Dictionary) -> String:
	return _bind_id(int(key["code"]), int(key.get("loc", 0)))

## p1_/p2_ 를 붙인 액션 이름 16개
func _all_actions() -> Array:
	var out: Array = []
	for prefix in ["p1_", "p2_"]:
		for a in ACTIONS:
			out.append(str(prefix) + str(a))
	return out

# ---------------------------------------------------------------- 그리기

func _draw() -> void:
	if _keys.is_empty():
		_build_keys()
	for i in range(_keys.size()):
		_draw_key(i)
	if _drag_action != "":
		_draw_ghost()

func _draw_key(index: int) -> void:
	var key: Dictionary = _keys[index]
	var rect: Rect2 = key["rect"]
	var actions: Array = _bindings.get(_key_id(key), [])
	# 끌고 있는 중에는 **집어 온 자리를 비어 있는 것처럼** 보여준다 — 손에 들고 있으니까
	if _drag_action != "" and _key_id(key) == _drag_from:
		actions = actions.filter(func(a): return a != _drag_action)

	var face: Color = _color_for(actions)
	# 한 칸짜리 키는 그림으로, 옆으로 긴 키는 네모로 그린다
	if use_keycap_sprite and rect.size.x <= unit * key_aspect + 1.0 and rect.size.y <= unit + 1.0:
		draw_texture_rect_region(KEYCAP, rect, KEYCAP_REGION,
			Color(face.r / KEYCAP_FACE, face.g / KEYCAP_FACE, face.b / KEYCAP_FACE, 1.0))
	else:
		var box := StyleBoxFlat.new()
		box.bg_color = face
		box.set_border_width_all(2)
		box.border_color = key_outline
		box.draw(get_canvas_item(), rect)
	if index == _hover:
		draw_rect(rect, drop_color if _drag_action != "" else Color(1, 1, 1, 0.75), false, 3.0)

	# 키 이름은 위쪽에, 조작 이름은 아래쪽에 적는다
	var has_label: bool = not actions.is_empty()
	var name_y: float = rect.position.y + (rect.size.y * 0.42 if has_label else rect.size.y * 0.62)
	draw_string(FONT, Vector2(rect.position.x, name_y), str(key["name"]),
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, key_font_size, text_color)
	if has_label:
		var y: float = rect.position.y + rect.size.y * 0.72
		for a in actions:
			var line: String = str(ACTION_LABELS.get(str(a).substr(3), a))
			draw_string(FONT, Vector2(rect.position.x, y), line,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, _fit_size(line, rect.size.x - 4.0),
				Color(1, 1, 1, 0.95))
			y += label_font_size + 1.0

## 조작 이름이 키 폭을 넘으면 글자를 줄여서 넣는다 — "방어 / 맵 전용"처럼 긴 이름이
## 한 칸짜리 키에서 잘려 나가면 무슨 조작인지 알 수가 없다
func _fit_size(text: String, max_width: float) -> int:
	var size: int = label_font_size
	while size > 7 and FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		size -= 1
	return size

## 한 키에 걸린 조작들로 칠할 색을 정한다. 1P·2P가 같은 키를 쓰면 1P 색으로 둔다(그런 배정은 막지 않는다)
func _color_for(actions: Array) -> Color:
	if actions.is_empty():
		return key_color
	for a in actions:
		if str(a).begins_with("p1_"):
			return p1_color
	return p2_color

## 끌고 있는 동안 손에 들려 따라오는 딱지. **키 한 칸과 같은 크기**다 —
## 놓는 자리는 커서 한 점이 아니라 이 딱지가 덮은 자리로 정해지므로,
## 딱지가 키보다 크면 "보이는 자리"와 "바뀌는 자리"가 어긋난다
func _ghost_rect() -> Rect2:
	return Rect2(_mouse_pos - _drag_grab, Vector2(unit * key_aspect, unit))

func _draw_ghost() -> void:
	var label: String = str(ACTION_LABELS.get(_drag_action.substr(3), _drag_action))
	var rect := _ghost_rect()
	var box := StyleBoxFlat.new()
	box.bg_color = p1_color if _drag_action.begins_with("p1_") else p2_color
	box.bg_color.a = 0.92
	box.set_border_width_all(2)
	box.border_color = drop_color
	box.draw(get_canvas_item(), rect)
	draw_string(FONT, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.62), label,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, _fit_size(label, rect.size.x - 4.0) + 1,
		Color(1, 1, 1, 1))

# ---------------------------------------------------------------- 끌어다 놓기

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion:
		_mouse_pos = (event as InputEventMouseMotion).position
		var hover := _drop_target() if _drag_action != "" else _key_at(_mouse_pos)
		if hover != _hover or _drag_action != "":
			_hover = hover
			queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_mouse_pos = mb.position
	if mb.pressed:
		_start_drag(_key_at(mb.position))
	else:
		_drop(_drop_target())

## 키를 든 채로 키보드 **밖에서** 손을 떼는 경우 — `_gui_input`은 이 칸 안에서만 오므로
## 여기서 한 번 더 받는다. 안 받으면 딱지가 마우스에 붙은 채로 남는다.
##
## ⚠️ **여기서 `get_local_mouse_position()`을 쓰면 안 된다**(2026-09-29 버그).
## 창이 1920x1080인데 게임 기준 화면은 1280x720이라 둘의 좌표가 1.5배 어긋나서,
## 놓을 때마다 오른쪽 아래로 밀린 엉뚱한 키에 놓이거나 키 바깥이라 아무 일도 안 일어났다.
## **이벤트가 들고 있는 자리를 이 칸 기준으로 바꿔 쓴다** — 이 값은 화면 배율이 이미 반영돼 있다
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _drag_action == "":
		return
	if event is InputEventMouseMotion:
		_mouse_pos = _local_of(event as InputEventMouse)
		_hover = _drop_target()
		queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_mouse_pos = _local_of(mb)
			_drop(_drop_target())
			get_viewport().set_input_as_handled()

## 화면(뷰포트) 좌표로 온 마우스 이벤트를 이 칸 안의 좌표로 옮긴다
func _local_of(event: InputEventMouse) -> Vector2:
	return get_global_transform().affine_inverse() * event.position

## 그 점 위에 있는 키의 번호. 없으면 -1.
## **키 사이 틈에 놓아도 가장 가까운 키로 붙여준다**(반 칸 거리까지) —
## 틈은 5px뿐이라 정확히 그 위에서 손을 떼는 건 사용자 잘못이 아니다
func _key_at(point: Vector2) -> int:
	var best: int = -1
	var best_dist: float = unit * 0.5
	for i in range(_keys.size()):
		var rect: Rect2 = _keys[i]["rect"]
		if rect.has_point(point):
			return i
		var d: float = point.distance_to(point.clamp(rect.position, rect.end))
		if d < best_dist:
			best_dist = d
			best = i
	return best

## **지금 딱지를 내려놓으면 들어갈 키.**
## 1순위는 **커서가 들어가 있는 키**다(사용자 요청 2026-09-29 — "커서가 그 키 사각형 안이면 그 키").
## 커서가 키 사이 틈이나 키보드 밖이면 그때만 딱지가 가장 많이 덮은 키로 정한다
func _drop_target() -> int:
	for i in range(_keys.size()):
		if (_keys[i]["rect"] as Rect2).has_point(_mouse_pos):
			return i
	var ghost: Rect2 = _ghost_rect()
	var best: int = -1
	var best_area: float = 0.0
	for i in range(_keys.size()):
		var overlap: Rect2 = ghost.intersection(_keys[i]["rect"])
		var area: float = overlap.size.x * overlap.size.y
		if area > best_area:
			best_area = area
			best = i
	if best >= 0:
		return best
	return _key_at(ghost.get_center())

## 키를 집어 든다. 아무 조작도 안 걸린 키면 아무 일도 없다.
## 한 키에 둘이 걸려 있으면(1P·2P가 같은 키) 1P 쪽을 먼저 집는다
func _start_drag(index: int) -> void:
	if read_only or index < 0:
		return
	var actions: Array = _bindings.get(_key_id(_keys[index]), [])
	if actions.is_empty():
		return
	_drag_action = str(actions[0])
	_drag_from = _key_id(_keys[index])
	_drag_held = false
	set_process(true)
	# 넓은 키(Space 등)를 집어도 딱지는 한 칸짜리라, 손잡이를 딱지 안으로 눌러 넣는다
	var rect: Rect2 = _keys[index]["rect"]
	_drag_grab = (_mouse_pos - rect.position).clamp(Vector2.ZERO, Vector2(unit * key_aspect, unit))
	_hover = index
	queue_redraw()

## 끌던 것을 놓는다. 키 위가 아니면 그냥 제자리로 돌아간다(아무것도 안 바뀜).
## **놓는 자리에 다른 조작이 있으면 서로 자리를 바꾼다** — 덮어써서 한쪽이 키를 잃어버리면
## 그 조작은 아예 못 쓰게 되고, 사용자가 뭘 잃었는지도 모른다
func _drop(index: int) -> void:
	if _drag_action == "":
		return
	var action := _drag_action
	var from_id := _drag_from
	_drag_action = ""
	set_process(false)
	if index < 0:
		queue_redraw()
		return
	var to_id: String = _key_id(_keys[index])
	if to_id == from_id:
		queue_redraw()
		return
	# 자리를 바꾸기 전에 목적지에 있던 조작들을 적어둔다
	var displaced: Array = (_bindings.get(to_id, []) as Array).duplicate()
	var from_parts: PackedStringArray = from_id.split(":")
	GameState.rebind_action(action, int(_keys[index]["code"]), int(_keys[index].get("loc", 0)))
	for other in displaced:
		GameState.rebind_action(str(other), int(from_parts[0]), int(from_parts[1]))
	refresh()
	binding_changed.emit()

## **손을 뗐는데 그 신호가 안 왔으면 여기서 대신 놓는다.**
## 놓기는 `_gui_input`(칸 안)과 `_input`(칸 밖)에서 받지만, 창 밖에서 떼거나 다른 창이
## 그 순간 입력을 가져가면 둘 다 안 올 수 있다 — 그러면 딱지가 손에 붙은 채로 남아
## "놓았는데 안 바뀌는" 상태가 된다. 버튼이 떨어져 있으면 마지막으로 알던 자리에 그대로 넣는다
func _process(_delta: float) -> void:
	if _drag_action == "":
		set_process(false)
		return
	# 버튼을 쥐고 있는 걸 한 번이라도 본 뒤에만 판단한다 — 누른 바로 그 프레임에는
	# 아직 눌림 상태가 안 올라와 있을 수 있어서, 그걸 "뗐다"로 읽으면 집자마자 놓아버린다
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_drag_held = true
		# **손을 뗀 자리를 놓치지 않으려면 커서를 직접 봐야 한다.** 이벤트만 믿으면
		# 놓기 신호가 늦거나 안 와서, 커서가 그 키를 벗어날 때까지 확정이 안 됐다(2026-09-29 신고)
		_mouse_pos = get_local_mouse_position()
		var target: int = _drop_target()
		if target != _hover:
			_hover = target
			queue_redraw()
	elif _drag_held:
		_drop(_drop_target())

## 설정 화면의 리셋 단추가 부른다 — 전부 기본 키로 되돌린다
func reset_all() -> void:
	_drag_action = ""
	GameState.reset_keybindings()
	refresh()
	binding_changed.emit()
