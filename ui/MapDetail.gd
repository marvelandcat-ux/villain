@tool
class_name MapDetail
extends Control

## 도감 맵 상세 — **위에 큰 평행사변형(맵 외형), 아래에 네모(맵 설명)** 두 칸짜리 화면이다
## (2026-09-26 러프 그대로). 맵 칸을 누르면 목록이 숨고 이 화면이 뜬다.
##
## 맵 그림은 캐릭터 도감 칸과 같은 방식으로 만든다 — 맵 선택 화면이 쓰는 `MapPreview`를
## 작은 화면(SubViewport)에 한 번 그려서 그림으로 떠온 뒤, 칸 비율로 잘라 평행사변형에 넣는다.
## **평행사변형에 MapPreview 노드를 그냥 얹으면 네모 모서리가 칸 밖으로 삐져나오기 때문**이다.

const MAP_PREVIEW := preload("res://ui/MapPreview.gd")

@export_group("맵 이름")
## 왼쪽 위 뒤로가기 화살표 옆에 뜨는 맵 이름 자리 — 캐릭터 상세의 이름표와 같은 자리다
@export var title_rect: Rect2 = Rect2(77.0, 4.0, 504.0, 76.0):
	set(value):
		title_rect = value
		_relayout()
@export var title_font_size: int = 52
@export var title_color: Color = Color(0.96, 0.93, 0.98, 1.0)

@export_group("맵 외형 칸")
## 평행사변형이 놓이는 자리와 크기 (화면 좌표)
@export var art_rect: Rect2 = Rect2(120.0, 104.0, 1040.0, 356.0):
	set(value):
		art_rect = value
		_relayout()
## 기울기(px) — 도감 목록 칸과 같은 느낌으로 맞춘다
@export var art_lean: float = 96.0:
	set(value):
		art_lean = value
		_relayout()
## 그림이 아직 안 떠졌을 때 비치는 바탕색
@export var art_fill: Color = Color(0.16, 0.14, 0.2, 1.0):
	set(value):
		art_fill = value
		_relayout()
## 칸 테두리 색·두께
@export var art_outline_color: Color = Color(0.62, 0.58, 0.72, 0.85)
@export var art_outline_width: float = 2.0
## 칸보다 몇 배 크게 떠올지
@export_range(1.0, 3.0, 0.1) var art_oversample: float = 1.4
## 칸 비율로 자를 때 세로로 어느 쪽을 남길지. 0=위쪽, 0.5=가운데, 1=아래쪽
@export_range(0.0, 1.0, 0.05) var art_crop_anchor: float = 1.0

@export_group("설명 칸")
@export var desc_rect: Rect2 = Rect2(120.0, 492.0, 1040.0, 186.0):
	set(value):
		desc_rect = value
		_relayout()
@export var desc_fill: Color = Color(0.13, 0.11, 0.17, 0.85)
@export var desc_border: Color = Color(0.62, 0.58, 0.72, 0.85)
@export var desc_border_width: int = 2
@export var desc_padding: float = 22.0:
	set(value):
		desc_padding = value
		_relayout()
## 설명 칸 맨 윗줄에 늘 붙는 고정 문구 (맵 이름은 왼쪽 위로 올라갔다)
@export var desc_header_text: String = "상세설명"
## 설명 칸 머리글 글자 크기 / 설명 글자 크기
@export var name_font_size: int = 30
@export var body_font_size: int = 20
@export var name_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var body_color: Color = Color(0.86, 0.82, 0.92, 1.0)
## 아직 설명을 안 쓴 맵에 대신 띄우는 글
@export var empty_text: String = "아직 설명을 적지 않은 맵입니다."

## 지금 보여주는 맵 이름
var _key: String = ""
## 맵 이름 -> 떠 둔 그림
var _art_cache: Dictionary = {}

## 칸 두 개는 **코드로 만든다** — 씬에 미리 놓아두려면 FanTile 스크립트를 ext_resource로 물려야 하는데,
## 도감 씬은 목록 칸도 전부 코드로 만들고 있어서 방식을 맞췄다
var _title_label: Label = null
var _art: FanTile = null
var _panel: Panel = null
var _name_label: Label = null
var _body_label: Label = null

func _ready() -> void:
	_build_nodes()
	_relayout()
	if not Engine.is_editor_hint():
		visible = false

func _build_nodes() -> void:
	if _art != null and is_instance_valid(_art):
		return
	# 에디터에서 스크립트가 다시 로드되면 예전에 만든 칸이 남아 있을 수 있다 — 전부 지우고 새로 만든다
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title_label)
	_art = FanTile.new()
	_art.name = "Art"
	add_child(_art)
	_panel = Panel.new()
	_panel.name = "Desc"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_name_label)
	_body_label = Label.new()
	_body_label.name = "Body"
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_body_label)

## 맵 하나를 펼친다. path가 비어 있으면(아직 안 만든 맵) 그림 없이 이름과 설명만 나온다
func open(key: String, path: String) -> void:
	_key = key
	visible = true
	_relayout()
	_title_label.text = key
	_name_label.text = desc_header_text
	var desc: String = str(GameState.MAP_DESCRIPTIONS.get(key, ""))
	_body_label.text = desc if desc != "" else empty_text
	_art.portrait_texture = null
	if path != "":
		_load_art(key, path)

func close() -> void:
	visible = false
	_key = ""

## 칸 두 개의 자리·모양을 지금 설정값대로 맞춘다 (에디터에서 값만 바꿔도 바로 보이게)
func _relayout() -> void:
	if not is_node_ready() or _art == null or not is_instance_valid(_art):
		return
	if _title_label:
		_title_label.position = title_rect.position
		_title_label.size = title_rect.size
		_title_label.add_theme_font_size_override("font_size", title_font_size)
		_title_label.add_theme_color_override("font_color", title_color)
	if _art:
		_art.position = art_rect.position
		_art.size = art_rect.size
		_art.lean = art_lean
		_art.fill_color = art_fill
		_art.backdrop_color = art_fill
		_art.name_band_ratio = 0.0
		_art.name_text = ""
		_art.display_text = ""
		_art.plain_outline = true
		_art.plain_outline_color = art_outline_color
		_art.plain_outline_width = art_outline_width
		_art.portrait_frame = Rect2(0.0, 0.0, 1.0, 1.0)
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art.focus_mode = Control.FOCUS_NONE
		_art.disabled = true
	if _panel:
		_panel.position = desc_rect.position
		_panel.size = desc_rect.size
		var style := StyleBoxFlat.new()
		style.bg_color = desc_fill
		style.border_color = desc_border
		style.border_width_left = desc_border_width
		style.border_width_top = desc_border_width
		style.border_width_right = desc_border_width
		style.border_width_bottom = desc_border_width
		_panel.add_theme_stylebox_override("panel", style)
	if _name_label:
		_name_label.position = Vector2(desc_padding, desc_padding * 0.4)
		_name_label.size = Vector2(desc_rect.size.x - desc_padding * 2.0, float(name_font_size) + 10.0)
		_name_label.add_theme_font_size_override("font_size", name_font_size)
		_name_label.add_theme_color_override("font_color", name_color)
	if _body_label:
		var top: float = desc_padding * 0.4 + float(name_font_size) + 14.0
		_body_label.position = Vector2(desc_padding, top)
		_body_label.size = Vector2(desc_rect.size.x - desc_padding * 2.0, desc_rect.size.y - top - desc_padding * 0.5)
		_body_label.add_theme_font_size_override("font_size", body_font_size)
		_body_label.add_theme_color_override("font_color", body_color)
		_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

## 맵 그림을 떠서 칸에 넣는다. 한 번 뜬 그림은 들고 있다가 다시 쓴다
func _load_art(key: String, path: String) -> void:
	if _art_cache.has(key):
		_art.portrait_texture = _art_cache[key]
		return
	var tex: Texture2D = await _render_art(path)
	# 뜨는 동안 다른 맵으로 넘어갔거나 화면을 닫았으면 버린다
	if tex == null or _key != key or not is_instance_valid(_art):
		return
	_art_cache[key] = tex
	_art.portrait_texture = tex

## 맵을 여백 없이 그린 뒤 칸 비율로 잘라 그림 한 장을 만든다 (CharacterDex의 칸 그림과 같은 방식)
func _render_art(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	# 찍어 둔 게임 화면 사진이 있으면 그걸 칸 비율로 자르기만 한다(스케치보다 정확하다)
	var photo: Texture2D = MAP_PREVIEW.snapshot_texture(path)
	if photo:
		var shot_image: Image = photo.get_image()
		return ImageTexture.create_from_image(shot_image.get_region(_crop_rect(shot_image.get_size())))
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var preview: Control = MAP_PREVIEW.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(preview)
	add_child(viewport)
	# 맵이 실제로 차지하는 비율을 먼저 재고, 그 비율대로 다시 그려야 여백 없이 꽉 찬다
	preview.size = Vector2(256, 256)
	viewport.size = Vector2i(256, 256)
	preview.set_map(path)
	var bbox: Vector2 = preview._bbox_max - preview._bbox_min
	var shot: Vector2i = _shot_size(bbox)
	viewport.size = shot
	preview.size = Vector2(shot)
	preview.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image() if is_instance_valid(viewport) else null
	if is_instance_valid(viewport):
		viewport.queue_free()
	if image == null:
		return null
	return ImageTexture.create_from_image(image.get_region(_crop_rect(image.get_size())))

func _shot_size(bbox: Vector2) -> Vector2i:
	var aspect: float = bbox.x / bbox.y if bbox.y > 0.0 else 1.0
	var tile_aspect: float = art_rect.size.x / art_rect.size.y if art_rect.size.y > 0.0 else 1.0
	var target_w: float = art_rect.size.x * art_oversample
	var target_h: float = target_w / maxf(aspect, 0.01)
	if aspect > tile_aspect:
		target_h = art_rect.size.y * art_oversample
		target_w = target_h * aspect
	return Vector2i(maxi(int(target_w), 64), maxi(int(target_h), 64))

func _crop_rect(shot: Vector2i) -> Rect2i:
	var tile_aspect: float = art_rect.size.x / art_rect.size.y if art_rect.size.y > 0.0 else 1.0
	var w: int = shot.x
	var h: int = int(round(float(shot.x) / tile_aspect))
	if h > shot.y:
		h = shot.y
		w = int(round(float(shot.y) * tile_aspect))
	var x: int = int(round(float(shot.x - w) * 0.5))
	var y: int = int(round(float(shot.y - h) * clampf(art_crop_anchor, 0.0, 1.0)))
	return Rect2i(x, y, w, h)
