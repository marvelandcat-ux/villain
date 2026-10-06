@tool
class_name CharacterDex
extends Control

## 에디터에서도 실제 목록·그림을 보려고 스크립트를 직접 읽어 둔다.
## 오토로드 **인스턴스**(GameState)는 에디터에 없지만, 스크립트 안의 const는 이렇게 꺼낼 수 있다
const GAME_STATE := preload("res://GameState.gd")
## 맵 칸에 실제 맵 모양을 그릴 때 쓰는 스크립트 — **맵 선택 화면이 쓰는 것과 같은 것**이라
## 두 화면의 맵 그림이 저절로 똑같이 나온다. class_name 대신 preload로 가져온다(에디터 캐시 함정)
const MAP_PREVIEW := preload("res://ui/MapPreview.gd")

## 도감 — **한 화면에서 캐릭터/맵을 넘겨 보고, 칸을 고르면 상세로 들어간다.**
##
## (2026-09-16 개편) 예전엔 위쪽 탭 버튼 + 격자 + 상세가 한 화면에 다 있는 프로토였다.
## 사용자 러프대로 메인 메뉴·일시정지와 **같은 사선 언어**로 다시 짰다:
##  - 왼쪽 위 둥근 제목 상자 "도감"
##  - 그 아래 왼쪽에 **사선 탭 두 개**(캐릭터 / 맵) — 메인 메뉴 항목과 **같은 그림·같은 색·같은 연출**이다.
##    고른 탭은 앞(오른쪽)으로 튀어나오고 강조색으로 바뀐다
##  - 오른쪽에 **맞물린 평행사변형 칸**(`FanTile`)이 두 줄. 캐릭터 선택창과 같은 모양이라 형제로 보인다
##  - 지금 고른 칸은 `FanTile.selected`로 **흰 테두리**가 계속 남는다 — 커서를 치워도 뭘 골랐는지 보인다
##
## **맵/캐릭터를 고르는 화면을 따로 두지 않는다.** 그 화면은 자기 내용이 없이 다음 메뉴로 가는
## 버튼 두 개뿐이라, 탭으로 합치고 단계를 하나 줄였다(2026-09-16 사용자와 합의).
##
## **자리는 전부 에디터에서 끌어서 잡는다**(2026-09-16 사용자 요청 — 코드로 만든 건 집을 수가 없다):
##  - 탭 두 개는 씬에 진짜 노드(`Tabs/CharacterTab`, `Tabs/MapTab`)로 박혀 있다. 개수가 안 변해서 가능하다.
##    **그 노드를 끌면 그대로 자리가 된다** — 스크립트는 색·튀어나오기만 입힌다.
##    (2026-09-16) 세로로 쌓았다가 **가로로 나란히** 놓는 배치로 바꿨다. 그래서 고른 탭은 옆이 아니라
##    **위로** 튀어나온다 — 방향은 `tab_slide_offset`으로 정한다
##  - 칸은 개수가 로스터를 따라 변해서 코드로 만들지만, **`Tiles` 노드 상자를 꽉 채우도록** 깔린다.
##    그래서 그 노드를 **끌면 자리가, 크기 손잡이로 늘리면 칸 크기가** 같이 바뀐다.
##    칸 하나하나의 크기를 직접 정하고 싶으면 `fit_tiles_to_box`를 끄고 `tile_size`를 쓰면 된다
##
## **@tool이라 에디터에서도 그려진다.** 코드로 만드는 UI는 게임을 켜 봐야 자리를 알 수 있어서
## 숫자만 보고 맞춰야 하는데, 그러면 손이 너무 많이 간다. 인스펙터에서 값을 바꾸면 **화면이 바로 따라온다**.
## 다만 **에디터에는 오토로드(`GameState`)가 없어서** 진짜 캐릭터 목록을 못 읽는다 —
## 그래서 에디터에서는 개수만 맞춘 **가짜 칸**을 그린다. 자리를 잡는 게 목적이니 그걸로 충분하다.

## 사선 도형 그림 — 메인 메뉴 항목과 **같은 그림 한 장을 재사용한다**(따로 뽑으면 각도·두께가 어긋난다)
@export var slant_texture: Texture2D
## 골라졌을 때 도형 둘레에 선을 그리는 재질 (ui/outline.gdshader) — 메인 메뉴와 같은 것
@export var outline_material: ShaderMaterial

@export_group("사선 탭")
## 골라졌을 때 튀어나오는 **방향과 거리**(px). 가로로 나란히 둔 탭이라 위로 띄운다 —
## 세로로 쌓는 배치로 되돌리면 `(30, 0)`처럼 가로로 바꾸면 된다
## (0, 0)이면 안 움직이고 **색만 바뀐다**(2026-09-16 사용자 선택). 움직임을 주고 싶으면 값을 넣으면 된다
@export var tab_slide_offset: Vector2 = Vector2.ZERO
## 따라붙는 빠르기 — 메인 메뉴와 같은 값
@export var tab_slide_speed: float = 12.0
## 평소 / 골라졌을 때 도형 색 (메인 메뉴·일시정지와 **같은 값**)
@export var menu_color: Color = Color(0.09, 0.07, 0.13, 0.82)
@export var menu_color_focus: Color = Color(0.72, 0.18, 0.28, 0.95)
## **커서를 올렸을 때** 색. 고른 것보다는 옅고 평소보다는 밝아서, 눌리는 곳이라는 게 바로 보인다
@export var menu_color_hover: Color = Color(0.36, 0.13, 0.2, 0.9)
## 커서를 올렸을 때 나오는 거리 — 고른 탭(tab_slide_offset)의 몇 배인지
@export_range(0.0, 1.0, 0.05) var hover_slide_ratio: float = 0.45
## 평소 / 골라졌을 때 글자 색
@export var menu_text_color: Color = Color(0.86, 0.82, 0.92, 1.0)
@export var menu_text_color_focus: Color = Color(1.0, 1.0, 1.0, 1.0)
## 골라졌을 때 둘레에 그려지는 선 색·두께 (ui/outline.gdshader — 사각형이 아니라 사선 모양을 따라간다)
@export var menu_outline_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var menu_outline_width: float = 2.0

@export_group("칸")
## 켜면 **씬의 `Tiles` 노드 상자에 칸을 꽉 채운다** — 그 노드를 끌면 자리가, 손잡이로 늘리면
## 칸 크기가 같이 바뀐다. 끄면 아래 `tile_size`를 그대로 쓴다
@export var fit_tiles_to_box: bool = true
## 칸 하나의 크기. **`fit_tiles_to_box`가 켜져 있으면 무시된다**(상자에서 계산한다)
@export var tile_size: Vector2 = Vector2(178.0, 158.0)
## 기울기(px). 기울기만큼 겹쳐 놓아야 대각선 변이 맞물린다
@export var tile_lean: float = 46.0
## 칸 사이 가로 간격(px). 0이면 대각선 변이 딱 맞물리고, 키우면 사이가 벌어진다
@export var tile_gap: float = 26.0
## 줄 사이 세로 간격
@export var tile_row_gap: float = 34.0
## 아랫줄을 **가운데 정렬한 자리에서 추가로** 오른쪽으로 밀어내는 거리(px).
## 줄 가운데 맞춤은 코드가 알아서 하므로 0이면 두 줄의 가운데가 딱 맞는다.
## 러프처럼 계단식으로 어긋나게 두고 싶을 때만 값을 준다
@export var tile_row_offset: float = 0.0
## 한 줄에 몇 칸까지 놓는지.
## 캐릭터는 한 줄에 다 놓고(전신 세로 칸), **맵은 5종이라 3칸 + 2칸 두 줄**이다(2026-09-25 사용자 지정)
@export var tiles_per_row: int = 8
@export var tiles_per_row_map: int = 3
## 도감 맵 칸 그림을 칸 비율로 자를 때 **세로로 어느 쪽을 남길지**. 0=위쪽, 0.5=가운데, 1=아래쪽.
## 기본 1 — 지하철역의 열차나 각 맵의 바닥이 아래쪽에 있어서, 잘려도 되는 하늘·천장 쪽을 자른다
@export_range(0.0, 1.0, 0.05) var map_art_crop_anchor: float = 1.0
## 칸보다 몇 배 크게 떠올지 (클수록 선명하지만 메모리를 더 쓴다)
@export_range(1.0, 3.0, 0.1) var map_art_oversample: float = 1.6
## **에디터에서만 쓰는 미리보기 탭.** 게임에는 아무 영향이 없다 —
## 에디터는 항상 캐릭터 탭만 그려서 맵 칸 정렬을 눈으로 보며 고칠 수가 없었다.
## "맵"으로 두면 에디터 화면이 맵 칸으로 바뀌어서 간격·줄 수를 보면서 맞출 수 있다
@export_enum("캐릭터", "맵") var editor_preview_tab: int = 0

@export_group("칸 안")
## 칸 아래 **이름 띠**의 높이 (칸 높이 대비). 이름을 읽어야 하는 화면이라 띠를 깔고 그 위에 쓴다
## 칸에 얼굴 초상화 대신 **전신샷**을 넣는다 (sprite/도감/전신/<캐릭터이름>.png).
## 전신샷은 전원을 같은 배율·같은 발 위치로 렌더해 같은 크기로 잘라 둔 것이라,
## 캐릭터별 보정 없이 그대로 넣어도 키 차이가 그대로 산다
@export var use_fullbody: bool = true
## **캐릭터별** 자리 보정 {캐릭터이름: Rect2}. 여기 값이 있으면 그 캐릭터만 이걸 쓰고,
## 없으면 공통값(portrait_area)을 쓴다. 에디터에서 초록 네모를 끌면 자동으로 채워진다
@export var portrait_overrides: Dictionary = {}
@export_dir var fullbody_dir: String = "res://sprite/도감/전신"

@export_range(0.0, 0.6, 0.01) var name_band_ratio: float = 0.2
@export var name_band_color: Color = Color(0.09, 0.07, 0.13, 0.92)
@export var name_font_size: int = 17
## 커서를 올린 칸이 커지는 배율 (1.06 = 6% 크게)
@export var tile_hover_scale: float = 1.14
## 그 크기로 따라붙는 빠르기. 클수록 빠릿하다
@export var tile_hover_speed: float = 14.0
## 뒤로가기(◀) 화살표에 커서를 올렸을 때 커지는 배율
@export var back_hover_scale: float = 1.18

@export_group("방향키")
## 꾹 누르고 있을 때 **첫 반복까지 기다리는 시간**(초)
@export var key_repeat_delay: float = 0.35
## 그 뒤 한 칸씩 넘어가는 간격(초)
@export var key_repeat_interval: float = 0.08
## 초상화를 칸 안 어디에 놓을지 (칸 크기 대비). 캐릭터마다 원본 크기가 달라서 그냥 채우면
## 얼굴 크기가 제각각인데, **`PortraitFrames.tscn`에 잡아 둔 값**을 여기에 곱해서 맞춘다.
## 그 씬에서 한 번 맞추면 도감·캐릭터 선택창·전투 HUD가 전부 같이 맞는다
@export var portrait_area: Rect2 = Rect2(0.06, 0.02, 0.88, 0.78)
## 칸 바탕색. **초상화 뒤에도 이 색이 깔린다** — 초상화 PNG는 머리 주변이 투명해서
## 안 깔면 칸마다 뒤가 뚫려 보인다. 캐릭터마다 색을 다르게 하지 않고 **하나로 통일**한다(사용자 지정)
@export var tile_color: Color = Color(0.16, 0.13, 0.22, 0.92)

## "character" 또는 "map"
var _mode: String = "character"
var _tabs: Dictionary = {}          # {mode: Button}
var _tab_rest_pos: Dictionary = {}  # {mode: 씬에 놓인 자리} — 튀어나온 거리를 되돌릴 기준
var _tiles: Array[FanTile] = []
## 전신샷 캐시 {캐릭터이름: Texture2D 또는 null}
var _fullbody_cache: Dictionary = {}
## 맵 이름 -> 한 번 그려서 떠 둔 맵 그림. 탭을 오갈 때마다 다시 그리지 않으려고 들고 있는다
var _map_art_cache: Dictionary = {}
var _selected_key: String = ""
## 흰 커서가 지금 어디에 있는지 — "tabs"(캐릭터/맵 탭) 또는 "tiles"(칸).
## 도감에 들어오면 탭에서 시작한다. 아래 방향키로 칸으로 내려가고, 윗줄에서 위를 누르면 다시 탭으로
var _focus_area: String = "tabs"
## 지금 커서가 올라간 칸 — 바뀔 때만 맨 앞으로 올려서 커진 부분이 옆 칸에 안 가리게 한다
var _hovered_tile: FanTile = null
## 꾹 누르고 있는 방향과, 다음 이동까지 남은 시간
var _held_step: int = 0
var _repeat_left: float = 0.0

@onready var _tab_root: Control = $Tabs
@onready var _tile_root: Control = $Tiles
@onready var _detail: Control = $Detail
## 맵 상세 화면 (위 평행사변형에 맵 외형, 아래 네모에 설명)
@onready var _map_detail: Control = $MapDetail
## 에디터에서 캐릭터 자리를 눈으로 잡는 초록 네모. 게임에서는 숨긴다
@onready var _guide: Control = $PortraitGuide
@onready var _back_button: Button = $BackButton

## 에디터에서 값이 바뀌었는지 보는 도장 — 바뀐 프레임에만 다시 그린다
var _editor_stamp: String = ""
## 칸의 **모양·개수**가 바뀌었는지. 자리 보정만 바뀐 경우는 아니라고 본다 —
## 그때까지 네모를 다시 맞추면 끌고 있는 네모가 손에서 튕겨 나간다
var _shape_stamp: String = ""

func _ready() -> void:
	_build_tabs()
	# 상자 크기가 바뀌면(창 크기 변경 등) 칸을 다시 깐다
	if not _tile_root.resized.is_connected(_build_tiles):
		_tile_root.resized.connect(_build_tiles)
	if _back_button and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_back_button.pressed.connect(_on_back_pressed)
		# 가운데를 기준으로 커지게 — 안 그러면 왼쪽 위 모서리에 붙어서 오른아래로만 자란다
		_back_button.pivot_offset = _back_button.size * 0.5
		_back_button.mouse_entered.connect(_on_back_hover.bind(true))
		_back_button.mouse_exited.connect(_on_back_hover.bind(false))
	if _guide:
		# 편집용이라 게임에서는 통째로 숨긴다
		_guide.visible = Engine.is_editor_hint()
	if not Engine.is_editor_hint():
		# 상세 화면을 편집하려고 에디터에서 배경을 꺼 두는 일이 잦다.
		# 그게 씬에 저장돼도 게임에서는 배경이 반드시 나오도록 여기서 되살린다
		# "도감" 제목도 같은 이유로 여기 넣었다(2026-09-16) — 눈 아이콘으로 꺼 둔 채 저장돼서
		# **에디터에서는 보이는데 실행하면 안 보이는** 일이 실제로 있었다
		for background in ["Background", "BackgroundImage", "Scrim", "TitlePanel/TitleLabel"]:
			var node: Node = get_node_or_null(background)
			if node is CanvasItem:
				node.visible = true
	_focus_area = "tabs"
	_set_mode("character")

## 에디터에서 자리 값이 바뀌면 다시 그린다. 매 프레임 문자열 하나 비교라 부담이 없다
func _refresh_editor() -> void:
	# 에디터에서 보고 있는 탭을 미리보기 설정대로 맞춘다 (게임에서는 탭 버튼이 정한다)
	_mode = "map" if editor_preview_tab == 1 else "character"
	# 탭은 씬 노드라 여기서 다시 만들 필요가 없다 — 칸 배치에 관계된 값만 본다
	# 인스펙터에서 만지는 값은 **빠짐없이** 여기 들어가야 한다 —
	# 빠진 값은 에디터에서 아무리 바꿔도 화면이 그대로라 "안 먹는다"고 보인다
	var stamp: String = "%s|%s|%s|%s|%s|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		_tile_root.size, tile_size, tile_lean, tile_row_gap, tile_row_offset,
		_columns(), fit_tiles_to_box, _mode, tile_gap,
		"|portrait|" + str(portrait_area) + str(portrait_overrides), name_band_ratio, name_band_color, name_font_size,
		tile_color, use_fullbody, fullbody_dir]
	if stamp == _editor_stamp:
		return
	_editor_stamp = stamp
	_build_tiles()
	# 초록 편집 네모는 캐릭터 전신샷 자리를 잡는 도구라 맵 탭에서는 띄우지 않는다
	if _mode == "character":
		_place_guides(_tile_shape_changed(stamp))
	# 에디터에서는 **자리를 절대 건드리지 않는다** — 색만 입힌다.
	# 예전엔 여기서 position까지 다시 잡는 바람에, 탭을 끌어다 옮겨도 다음 프레임에 원래 자리로
	# 돌아가 버렸다(옮겨지지도 줄어들지도 않는 것처럼 보였다). 튀어나오기는 게임에서만 하면 된다
	for key in _tabs.keys():
		var button: Button = _tabs[key]
		var on: bool = key == _mode
		var shape: TextureRect = button.get_node_or_null("Shape") as TextureRect
		if shape:
			shape.modulate = menu_color_focus if on else menu_color
			if shape.material is ShaderMaterial:
				(shape.material as ShaderMaterial).set_shader_parameter("line_alpha", 1.0 if on else 0.0)

## 씬에 박아 둔 탭 노드를 찾아 신호만 연결한다. **자리·크기는 씬에 놓인 그대로 쓴다** —
## 에디터에서 끌어다 옮긴 값이 곧 게임 화면이 되도록
func _build_tabs() -> void:
	for pair in [["character", "CharacterTab"], ["map", "MapTab"]]:
		var button: Button = _tab_root.get_node_or_null(pair[1]) as Button
		if button == null:
			push_warning("CharacterDex: 탭 노드를 못 찾았다 — %s" % pair[1])
			continue
		if not Engine.is_editor_hint():
			# **에디터에서 눈 아이콘으로 꺼 둔 채 저장돼도 게임에서는 반드시 보이게 한다**(2026-09-16).
			# 배경·제목과 같은 사고가 탭에서도 났다 — 탭이 통째로 안 떠서 캐릭터/맵 전환이 불가능했다.
			# 도형·글자까지 따로 꺼져 있었으므로 자식도 같이 켠다
			button.visible = true
			for child in button.get_children():
				if child is CanvasItem:
					(child as CanvasItem).visible = true
		button.focus_mode = Control.FOCUS_NONE   # 칸 쪽 방향키 이동을 뺏지 않게
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var shape: TextureRect = button.get_node_or_null("Shape") as TextureRect
		if shape and shape.material is ShaderMaterial:
			# 재질은 탭마다 따로 복제한다 — 하나를 같이 쓰면 한 탭만 켜도 둘 다 켜진다
			shape.material = shape.material.duplicate()
			shape.material.set_shader_parameter("line_color", menu_outline_color)
			shape.material.set_shader_parameter("line_width", menu_outline_width)
		if not button.pressed.is_connected(_set_mode):
			button.pressed.connect(_set_mode.bind(pair[0]))
		_tabs[pair[0]] = button
		_tab_rest_pos[pair[0]] = button.position

## 탭을 바꾼다 — 칸 목록을 다시 만들고 첫 칸을 골라 둔다
func _set_mode(mode: String) -> void:
	_mode = mode
	_focus_area = "tabs"
	_close_detail()
	_build_tiles()

## 지금 탭에서 한 줄에 놓을 칸 수
func _columns() -> int:
	return maxi(tiles_per_row if _mode == "character" else tiles_per_row_map, 1)

## 지금 탭에 맞는 목록.
## 캐릭터는 **대전 로스터(CHARACTERS) 그대로** — 훈련장에서만 고를 수 있는 캐릭터(주인공)는
## 애초에 이 목록에 없어서 도감에도 안 나온다.
## 맵은 **DEX_MAPS**(아직 안 만든 맵까지 포함한 최종 5종)를 쓴다 — 고를 수 있는 맵만 담은 MAPS와 다르다
func _entries() -> Array:
	# 에디터에는 오토로드 인스턴스가 없어서 preload한 스크립트의 const를 읽는다
	if Engine.is_editor_hint():
		return GAME_STATE.DEX_MAPS.keys() if _mode == "map" else GAME_STATE.CHARACTERS.keys()
	return GameState.DEX_MAPS.keys() if _mode == "map" else GameState.CHARACTERS.keys()

## 오른쪽 사선 칸들. 한 줄에 tiles_per_row개씩, 아랫줄은 오른쪽으로 밀어 계단식으로 놓는다.
## **기울기(tile_lean)만큼 겹쳐서** 놓아야 옆 칸과 대각선 변이 맞물린다
func _build_tiles() -> void:
	# **추적 목록이 아니라 자식 전부를 지운다.** 에디터에서 스크립트가 다시 로드되면 _tiles 배열만
	# 비워지고 예전에 만든 칸은 그대로 남아서, 새 칸이 그 위에 겹쳐 쌓인다(크기를 바꿔도 안 변해 보인다).
	# remove_child까지 해야 같은 프레임에 트리에서 빠진다 — queue_free만 하면 한 프레임 더 남는다
	for child in _tile_root.get_children():
		_tile_root.remove_child(child)
		child.queue_free()
	_tiles.clear()
	var keys: Array = _entries()
	var box: Vector2 = _tile_size_for(keys.size())
	var pitch: float = box.x - tile_lean + tile_gap
	var columns: int = _columns()
	# **줄마다 가운데 정렬** — 그 줄에 놓인 칸 수만큼만 폭을 차지하므로, 남는 자리를 반씩 나눠 갖는다.
	# 맵 탭(3칸 + 2칸)은 아랫줄이 윗줄 정가운데에 오고, 캐릭터 탭(7칸/8칸 자리)도 가운데로 모인다
	var row_count: int = maxi(ceili(float(keys.size()) / float(columns)), 1)
	var row_start: Array = []
	for r in range(row_count):
		var in_row: int = mini(keys.size() - r * columns, columns)
		var span: float = pitch * float(in_row - 1) + box.x
		row_start.append((_tile_root.size.x - span) * 0.5 + tile_row_offset * float(r))
	for i in range(keys.size()):
		var key: String = keys[i]
		var row: int = i / columns
		var column: int = i % columns
		var tile := FanTile.new()
		tile.size = box
		tile.lean = tile_lean
		tile.fill_color = tile_color
		tile.backdrop_color = tile_color
		tile.name_band_ratio = name_band_ratio
		tile.name_band_color = name_band_color
		tile.name_font_size = name_font_size
		tile.name_text = key
		# Tiles 노드 안쪽 좌표다 — 전체를 옮기려면 그 노드를 끌면 된다
		tile.position = Vector2(
			row_start[row] + pitch * float(column),
			(box.y + tile_row_gap) * float(row))
		var art: Texture2D = _tile_art(key)
		if _mode == "character" and art != null:
			tile.portrait_texture = art
			# 전신샷은 이미 전원이 같은 틀로 잘려 있어서 캐릭터별 보정을 곱하면 오히려 어긋난다
			tile.portrait_frame = _area_for(key) if _fullbody(key) != null else _portrait_frame_for(key)
		else:
			# 초상화가 없는 캐릭터·맵은 이름만 — 빈 칸으로 두면 뭔지 알 수 없다
			tile.display_text = key
			tile.display_font_size = 18
			tile.name_text = ""
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.pressed.connect(_on_tile_pressed.bind(key))
		_tile_root.add_child(tile)
		# **포커스를 안 받게 한다** — 칸이 포커스를 가지면 Godot 기본 포커스 이동이 방향키를 먹어서
		# 아래 _unhandled_input의 좌우 이동과 싸운다. 고른 표시는 selected가 따로 해 준다.
		# add_child 뒤에 꺼야 한다 — FanTile._ready가 FOCUS_ALL로 켜기 때문
		tile.focus_mode = Control.FOCUS_NONE
		# 가운데를 축으로 커지게 — 안 잡아 주면 왼쪽 위를 축으로 커져서 자리가 밀린다
		tile.pivot_offset = tile.size * 0.5
		_tiles.append(tile)
	if not keys.is_empty():
		_select(keys[0])
	# 맵 칸은 이름만 있는 빈 칸이라, 맵 선택 화면과 같은 그림을 떠서 채워 넣는다.
	# await가 들어 있어 바로 안 끝나므로 기다리지 않고 시작만 시킨다(칸은 먼저 뜨고 그림이 곧 붙는다)
	if _mode == "map" and not Engine.is_editor_hint():
		_fill_map_art(box)

func _tile_shape_changed(stamp: String) -> bool:
	var shape: String = stamp.split("|portrait|")[0]
	if shape == _shape_stamp:
		return false
	_shape_stamp = shape
	return true

## 이 캐릭터의 전신샷이 칸 안 어디에 놓일지 — 따로 잡아 둔 게 있으면 그것, 없으면 공통값
func _area_for(key: String) -> Rect2:
	return portrait_overrides.get(key, portrait_area)

## 초록 네모들을 **각자 맡은 칸 위에** 놓는다. 칸은 코드가 만드는 노드라 에디터에서 집을 수
## 없어서, 같은 자리에 겹쳐 놓은 이 네모를 대신 집는 방식이다.
## 네모 이름 = 캐릭터 이름이라, 씬에서 이름만 맞춰 복제하면 새 캐릭터도 바로 잡을 수 있다
func _place_guides(force: bool = false) -> void:
	if _guide == null or not Engine.is_editor_hint() or _tiles.is_empty():
		return
	_guide.position = _tile_root.position
	_guide.size = _tile_root.size
	var keys: Array = _entries()
	for i in range(mini(keys.size(), _tiles.size())):
		var rect: Control = _guide.get_node_or_null(NodePath(str(keys[i])))
		if rect == null:
			continue
		var tile: FanTile = _tiles[i]
		# 평소엔 사용자가 끌어 둔 자리를 그대로 둔다. 칸 크기 자체가 바뀌었을 때만(force)
		# 지금 비율대로 다시 맞춘다 — 안 그러면 칸만 커지고 네모는 그대로라 자리가 틀어진다
		if force:
			var area: Rect2 = _area_for(str(keys[i]))
			rect.position = tile.position + area.position * tile.size
			rect.size = area.size * tile.size

## 네모를 읽어 캐릭터별 보정에 넣는다. 실제로 달라졌을 때만 넣는다 —
## 매 프레임 넣으면 칸을 끝없이 다시 만들게 된다
func _read_guides() -> void:
	if _guide == null or not Engine.is_editor_hint() or _tiles.is_empty():
		return
	var keys: Array = _entries()
	for i in range(mini(keys.size(), _tiles.size())):
		var key: String = str(keys[i])
		var rect: Control = _guide.get_node_or_null(NodePath(key))
		if rect == null:
			continue
		var tile: FanTile = _tiles[i]
		if tile.size.x <= 0.0 or tile.size.y <= 0.0:
			continue
		var local: Vector2 = rect.position - tile.position
		var wanted := Rect2(local / tile.size, rect.size / tile.size)
		var now: Rect2 = _area_for(key)
		if wanted.position.distance_to(now.position) < 0.002 				and wanted.size.distance_to(now.size) < 0.002:
			continue
		portrait_overrides[key] = wanted

## 칸에 넣을 그림 — 전신샷이 있으면 그것, 없으면 예전 얼굴 초상화
## 맵 칸에 실제 맵 모양을 그려 넣는다.
## **칸이 평행사변형이라 MapPreview 노드를 자식으로 그냥 얹을 수 없다** — 네모난 모서리가 칸 밖으로
## 삐져나온다. 그래서 작은 화면(SubViewport)에 한 번 그려 그림으로 떠온 뒤 칸의 초상화 자리에 넣는다
func _fill_map_art(box: Vector2) -> void:
	var keys: Array = _entries()
	for i in range(keys.size()):
		var key: String = str(keys[i])
		var tex: Texture2D = _map_art_cache.get(key)
		if tex == null:
			tex = await _render_map_art(key, box)
		# 그리는 동안 탭을 바꿨거나 칸을 다시 만들었으면 그만둔다
		if _mode != "map" or i >= _tiles.size() or not is_instance_valid(_tiles[i]):
			return
		if tex == null:
			continue
		var tile: FanTile = _tiles[i]
		tile.portrait_texture = tex
		# 이미 칸 비율로 잘라서 가져왔으므로 칸 전체에 그대로 펴 넣으면 딱 맞는다(빈 띠가 안 생긴다)
		tile.portrait_frame = Rect2(0.0, 0.0, 1.0, 1.0)
		tile.display_text = ""
		tile.name_text = key

## 맵 하나를 SubViewport에 그려서 그림으로 떠온다.
##
## **두 단계로 나눈다.** 먼저 맵이 실제로 차지하는 비율 그대로 크게 그려서 여백 없이 꽉 찬 그림을 얻고,
## 그 다음 칸 비율에 맞게 잘라낸다. MapPreview는 자기 크기 안에 맵을 통째로 넣느라 위아래(또는 좌우)에
## 빈 띠를 남기는데, 그 띠째로 칸에 넣으면 맵이 작게 보였다.
##
## 세로로 자를 때는 `map_art_crop_anchor`를 따른다 — 기본 1.0이라 **아래쪽을 남기고 위를 자른다**.
## 지하철역은 열차가, 다른 맵은 바닥이 아래쪽에 있어서 위를 자르는 게 안전하다(2026-09-26 사용자 지정).
## 아직 안 만든 맵(경로가 빈 칸)은 null
func _render_map_art(key: String, box: Vector2) -> Texture2D:
	var path: String = str(GameState.DEX_MAPS.get(key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var preview: Control = MAP_PREVIEW.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(preview)
	add_child(viewport)
	# 1) 맵이 차지하는 비율을 먼저 재고, 그 비율대로 화면을 잡아 다시 그린다
	preview.size = Vector2(256, 256)
	viewport.size = Vector2i(256, 256)
	preview.set_map(path)
	var bbox: Vector2 = preview._bbox_max - preview._bbox_min
	var shot: Vector2i = _map_shot_size(bbox, box)
	viewport.size = shot
	preview.size = Vector2(shot)
	preview.queue_redraw()
	# 그려진 결과가 실제로 나오려면 한 프레임이 끝나야 한다
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image() if is_instance_valid(viewport) else null
	if is_instance_valid(viewport):
		viewport.queue_free()
	if image == null:
		return null
	# 2) 칸 비율에 맞게 잘라낸다
	image = image.get_region(_map_crop_rect(image.get_size(), box))
	var tex := ImageTexture.create_from_image(image)
	_map_art_cache[key] = tex
	return tex

## 맵을 여백 없이 그릴 화면 크기 — 맵 비율은 그대로 두되, 잘라낸 뒤에도 칸보다 크도록 넉넉히 잡는다
func _map_shot_size(bbox: Vector2, box: Vector2) -> Vector2i:
	var aspect: float = bbox.x / bbox.y if bbox.y > 0.0 else 1.0
	var tile_aspect: float = box.x / box.y if box.y > 0.0 else 1.0
	# 칸보다 납작한 맵이면 가로를, 홀쭉한 맵이면 세로를 기준으로 키운다
	var target_w: float = box.x * map_art_oversample
	var target_h: float = target_w / maxf(aspect, 0.01)
	if aspect > tile_aspect:
		target_h = box.y * map_art_oversample
		target_w = target_h * aspect
	return Vector2i(maxi(int(target_w), 64), maxi(int(target_h), 64))

## 떠온 그림에서 칸 비율만큼 잘라낼 자리. 세로로 자를 땐 map_art_crop_anchor 쪽을 남긴다
func _map_crop_rect(shot: Vector2i, box: Vector2) -> Rect2i:
	var tile_aspect: float = box.x / box.y if box.y > 0.0 else 1.0
	var w: int = shot.x
	var h: int = int(round(float(shot.x) / tile_aspect))
	if h > shot.y:
		h = shot.y
		w = int(round(float(shot.y) * tile_aspect))
	var x: int = int(round(float(shot.x - w) * 0.5))
	var y: int = int(round(float(shot.y - h) * clampf(map_art_crop_anchor, 0.0, 1.0)))
	return Rect2i(x, y, w, h)

func _tile_art(key: String) -> Texture2D:
	var full: Texture2D = _fullbody(key)
	if full != null:
		return full
	# 에디터에는 오토로드(GameState)가 없다 — 부르면 placeholder 오류가 난다
	if Engine.is_editor_hint():
		return null
	return GameState.portrait_texture(key) if GameState.has_portrait(key) else null

## 전신샷을 읽어 온다. 파일이 없는 캐릭터는 null — 그러면 예전 초상화로 넘어간다
func _fullbody(key: String) -> Texture2D:
	if not use_fullbody:
		return null
	if _fullbody_cache.has(key):
		return _fullbody_cache[key]
	var path: String = "%s/%s.png" % [fullbody_dir, key]
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_fullbody_cache[key] = texture
	return texture

## 이 캐릭터의 초상화를 칸 안 어디에 놓을지. `portrait_area`(칸 안에서 쓸 자리)에
## `PortraitFrames.tscn`에서 잡아 둔 캐릭터별 보정을 곱한다 — 안 잡아 둔 캐릭터는 그 자리를 그대로 쓴다
func _portrait_frame_for(key: String) -> Rect2:
	var center: Vector2 = GameState.portrait_frame_center(key)
	var size_frac: Vector2 = GameState.portrait_frame_size(key)
	var size: Vector2 = portrait_area.size * size_frac
	var middle: Vector2 = portrait_area.position + portrait_area.size * center
	return Rect2(middle - size * 0.5, size)

## 칸 하나의 크기를 정한다. 상자 채우기를 켜 뒀으면 `Tiles` 노드 크기에서 역산한다.
##
## 한 줄의 전체 폭은 `칸폭 + (칸폭 - 기울기) * (칸수 - 1)` 이다 — 옆 칸이 기울기만큼 겹치기 때문.
## 이걸 상자 폭과 같다고 놓고 칸폭을 구한다. 아랫줄을 오른쪽으로 미는 만큼(`tile_row_offset`)은
## 미리 빼 둬야 밀린 줄도 상자 안에 들어온다
func _tile_size_for(count: int) -> Vector2:
	if not fit_tiles_to_box or _tile_root == null:
		return tile_size
	var columns: int = maxi(_columns(), 1)
	var rows: int = maxi(ceili(float(count) / float(columns)), 1)
	# **가로 크기는 "한 줄에 몇 칸"(columns)으로만 정한다** — 목록에서 한 명이 빠져도
	# 평행사변형 크기가 변하지 않는다(전에는 실제 인원수로 나눠서 8명 -> 7명이 되자 칸이 넓어졌다).
	# 줄이 덜 찬 만큼 남는 자리는 _build_tiles가 줄을 가운데로 밀어 메운다
	var usable: Vector2 = _tile_root.size - Vector2(0.0, tile_row_gap * float(rows - 1))
	return Vector2(
		maxf((usable.x + (tile_lean - tile_gap) * float(columns - 1)) / float(columns), 40.0),
		maxf(usable.y / float(rows), 40.0))

## 방향키로 고른 칸을 옮긴다. **끝에서 넘어가면 반대쪽 끝으로 돈다** —
## 첫 칸(잼민이)에서 왼쪽을 누르면 마지막 칸(일진)으로, 그 반대도 마찬가지
func _move_selection(step: int) -> void:
	var keys: Array = _entries()
	if keys.is_empty():
		return
	var at: int = keys.find(_selected_key)
	if at < 0:
		at = 0
	_select(keys[posmod(at + step, keys.size())])

## 칸 하나를 골라 둔 상태로 만든다 (흰 테두리가 계속 남는다)
func _select(key: String) -> void:
	_selected_key = key
	var keys: Array = _entries()
	for i in range(_tiles.size()):
		_tiles[i].selected = _focus_area == "tiles" and i < keys.size() and keys[i] == key

## 칸을 누르면 **바로** 상세로 들어간다.
## 전에는 한 번 고르고 다시 눌러야 열렸는데, 마우스를 올리면 칸이 이미 커져서 뭘 누를지 보이므로
## 한 번 더 확인받을 이유가 없었다(2026-10-05 사용자 요청).
## 방향키 조작은 그대로다 — 방향키로 칸을 옮기고 확인키(`ui_accept`)로 연다
func _on_tile_pressed(key: String) -> void:
	_focus_area = "tiles"   # 마우스로 눌러도 커서가 칸으로 내려온다
	_select(key)
	_open_detail(key)

## 상세로 들어간다. 목록 쪽(제목·탭·칸·안내문)은 통째로 숨겨서 상세 화면과 안 겹치게 한다.
## 배경과 뒤로가기 화살표는 그대로 남는다 — 화살표는 상세에서 "목록으로" 역할을 겸한다
func _open_detail(key: String) -> void:
	if Engine.is_editor_hint():
		return
	if _mode == "map":
		# 맵은 아직 안 만든 맵(경로가 빈 칸)이어도 이름·설명은 볼 수 있게 그냥 연다
		_set_list_visible(false)
		_map_detail.open(key, str(GameState.DEX_MAPS.get(key, "")))
		return
	var path: String = str(GameState.CHARACTERS.get(key, ""))
	if path == "":
		return
	_set_list_visible(false)
	if _detail.has_method("open"):
		_detail.open(key, path)
	else:
		_detail.visible = true

func _close_detail() -> void:
	if not Engine.is_editor_hint() and _detail.has_method("close"):
		_detail.close()
	else:
		_detail.visible = false
	if _map_detail and _map_detail.has_method("close"):
		_map_detail.close()
	elif _map_detail:
		_map_detail.visible = false
	_set_list_visible(true)

## 목록 화면을 이루는 노드들을 한꺼번에 켜고 끈다
func _set_list_visible(on: bool) -> void:
	for node_name in ["TitlePanel", "Tabs", "Tiles", "HintLabel"]:
		var node: Node = get_node_or_null(node_name)
		if node is CanvasItem:
			node.visible = on

## 고른 탭은 앞으로 나오고 강조색으로, 나머지는 제자리·평소 색으로 돌아간다.
## 메인 메뉴와 같은 방식이라 같은 속도로 움직인다
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# 초록 네모를 먼저 읽어야, 끌어 놓은 자리가 같은 프레임에 칸에 반영된다
		_read_guides()
		_refresh_editor()
		_place_guides()
		return
	_update_tile_hover(delta)
	_update_key_repeat(delta)
	var t: float = clampf(tab_slide_speed * delta, 0.0, 1.0)
	for key in _tabs.keys():
		var button: Button = _tabs[key]
		var on: bool = key == _mode
		# 고른 탭 > 커서 올린 탭 > 평소 순으로 색과 튀어나온 거리가 정해진다
		var hovered: bool = button.is_hovered()
		var goal_color: Color = menu_color_focus if on else (menu_color_hover if hovered else menu_color)
		var slide: Vector2 = tab_slide_offset if on else (tab_slide_offset * hover_slide_ratio if hovered else Vector2.ZERO)
		button.position = button.position.lerp(_tab_rest_pos[key] + slide, t)
		var shape: TextureRect = button.get_node_or_null("Shape") as TextureRect
		if shape:
			shape.modulate = shape.modulate.lerp(goal_color, t)
			if shape.material is ShaderMaterial:
				# 선은 두께가 아니라 진하기(line_alpha)로 켜고 끈다 — 메인 메뉴와 같은 방식
				var material: ShaderMaterial = shape.material as ShaderMaterial
				var line: float = material.get_shader_parameter("line_alpha")
				var cursor_here: bool = on and _focus_area == "tabs"
				var goal_line: float = 1.0 if cursor_here else (0.55 if hovered else (0.25 if on else 0.0))
				material.set_shader_parameter("line_alpha", lerpf(line, goal_line, t))
		var text: Label = button.get_node_or_null("Text") as Label
		if text:
			var goal: Color = menu_text_color_focus if (on or hovered) else menu_text_color
			text.add_theme_color_override("font_color",
				text.get_theme_color("font_color").lerp(goal, t))

## 커서를 올린 칸을 살짝 키운다. 커진 칸이 옆 칸에 가리지 않게 맨 앞으로 올려 둔다
func _update_tile_hover(delta: float) -> void:
	var t: float = clampf(tile_hover_speed * delta, 0.0, 1.0)
	var top: FanTile = null
	for tile in _tiles:
		if not is_instance_valid(tile):
			continue
		var on: bool = tile.is_hovered() or tile.selected
		if tile.is_hovered():
			top = tile
		tile.pivot_offset = tile.size * 0.5
		tile.scale = tile.scale.lerp(Vector2.ONE * (tile_hover_scale if on else 1.0), t)
	if top != _hovered_tile:
		_hovered_tile = top
		if top:
			top.move_to_front()

## 방향키를 꾹 누르고 있으면 촤르륵 넘어간다 — 처음 한 번, 잠깐 쉬고, 그 뒤로 빠르게 반복.
## **Godot 기본 포커스 이동을 안 쓰기 때문에**(칸 포커스를 꺼 뒀다) 반복도 직접 돌려야 한다
func _update_key_repeat(delta: float) -> void:
	if _detail.visible or (_map_detail and _map_detail.visible):
		_held_step = 0
		return
	var step: int = 0
	if Input.is_action_pressed("ui_right"):
		step = 1
	elif Input.is_action_pressed("ui_left"):
		step = -1
	elif Input.is_action_pressed("ui_down"):
		step = 100
	elif Input.is_action_pressed("ui_up"):
		step = -100
	if step == 0:
		_held_step = 0
		return
	if step != _held_step:
		# 방금 누른 순간 — 한 번 옮기고, 첫 반복까지 한 박자 쉰다
		_held_step = step
		_repeat_left = key_repeat_delay
		_move_cursor(step)
		return
	_repeat_left -= delta
	if _repeat_left <= 0.0:
		_repeat_left = key_repeat_interval
		_move_cursor(step)

## 방향키 하나를 처리한다. 100 / -100은 아래·위를 뜻한다(칸 수와 안 겹치는 값).
##  - 탭에 있을 때: 좌우로 캐릭터 <-> 맵, 아래로 칸으로 내려간다
##  - 칸에 있을 때: 좌우로 한 칸씩(끝에서 반대쪽으로), 아래위로 한 줄씩. **윗줄에서 위를 누르면 탭으로**
func _move_cursor(step: int) -> void:
	if _focus_area == "tabs":
		if step == 100:
			_enter_tiles()
		elif absi(step) == 1:
			_set_mode("map" if _mode == "character" else "character")
		return
	var keys: Array = _entries()
	if keys.is_empty():
		return
	var at: int = maxi(keys.find(_selected_key), 0)
	var columns: int = _columns()
	if step == -100:
		if at < columns:
			_focus_area = "tabs"   # 윗줄에서 위 -> 탭으로 올라간다
			_select(_selected_key)
			return
		_select(keys[at - columns])
		return
	if step == 100:
		_select(keys[mini(at + columns, keys.size() - 1)])
		return
	_move_selection(step)

## 커서를 칸으로 내린다 — 골라 둔 게 없으면 첫 칸(잼민이)부터
func _enter_tiles() -> void:
	_focus_area = "tiles"
	var keys: Array = _entries()
	if not keys.is_empty():
		_select(_selected_key if keys.has(_selected_key) else keys[0])

## 왼쪽 위 ◀ — 상세를 보고 있으면 목록으로, 목록이면 메인 메뉴로. ESC와 같은 동작이다
## 화살표에 커서가 올라가고 내려갈 때 살짝 부풀렸다 되돌린다
func _on_back_hover(entered: bool) -> void:
	if not is_instance_valid(_back_button):
		return
	# 크기가 뒤늦게 잡히는 경우가 있어 들어올 때마다 중심을 다시 잡아준다
	_back_button.pivot_offset = _back_button.size * 0.5
	var goal: Vector2 = Vector2.ONE * (back_hover_scale if entered else 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(_back_button, "scale", goal, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_back_pressed() -> void:
	if _detail.visible or (_map_detail and _map_detail.visible):
		_close_detail()
	else:
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
		return
	if _detail.visible:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _focus_area == "tabs":
			_enter_tiles()
		elif _selected_key != "":
			_open_detail(_selected_key)
