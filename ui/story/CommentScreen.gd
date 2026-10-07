class_name CommentScreen
extends Control

## **동영상 플랫폼 댓글창** — 에피소드 2에서 악플러가 악플을 다는 장면(2026-10-07 사용자 대본).
##
## 그림 파일 없이 **코드로 그린다.** 아직 시안이 없는 화면이라, 그림을 기다리느니 인스펙터에서
## 닉네임·댓글만 고쳐 가며 대본을 맞춰 보는 게 빠르다. 나중에 진짜 그림이 나오면 이 노드를 걷어내면 된다.
##
## 댓글 줄은 **"닉네임|내용"** 꼴이다. `villain_index`번째 줄은 악플러 것으로 보고 붉게 칠한다.
## `type_last`를 켜면 **마지막 줄이 한 글자씩 찍힌다** — "지금 쓰는 중"으로 읽힌다.

## 동영상 제목 칸에 들어갈 글
@export var video_title: String = "[일상] 오늘 하루 브이로그 🎬"
@export var channel_name: String = "평범한채널"
@export var view_text: String = "조회수 12,431회 · 3시간 전"

@export_group("댓글")
## "닉네임|내용" 줄들. 위에서부터 차례로 깔린다
@export var comments: PackedStringArray = PackedStringArray()
## 악플러가 쓴 줄 번호(0부터). -1이면 아무 줄도 특별 취급 안 한다
@export var villain_index: int = -1
## 마지막 줄을 한 글자씩 찍을지 — "지금 막 올라오는 댓글"
@export var type_last: bool = true
## 찍히는 빠르기(글자/초)
@export var chars_per_second: float = 18.0
## 찍기 시작하기 전에 기다리는 시간(초)
@export var type_delay: float = 0.6

@export_group("색")
@export var page_color: Color = Color(0.09, 0.09, 0.11, 1.0)
@export var panel_color: Color = Color(0.14, 0.14, 0.17, 1.0)
@export var video_color: Color = Color(0.03, 0.03, 0.04, 1.0)
@export var text_color: Color = Color(0.88, 0.89, 0.93, 1.0)
@export var dim_color: Color = Color(0.55, 0.57, 0.62, 1.0)
@export var villain_color: Color = Color(1.0, 0.45, 0.42, 1.0)

const FONT_PATH := "res://fonts/NanumGothic-Regular.ttf"

## 마지막 줄 라벨(한 글자씩 찍을 때 쓴다)
var _last_label: RichTextLabel = null
var _last_text: String = ""
var _typed: float = 0.0
var _delay_left: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_delay_left = type_delay
	set_process(type_last and _last_label != null)

func _font() -> Font:
	return load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null

## 네모 하나 — 둥근 모서리까지 해서 "요즘 사이트"처럼 보이게
func _panel(parent: Control, color: Color, radius: int = 10) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(14.0)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box

func _label(parent: Node, text: String, size: int, color: Color) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = false
	rt.fit_content = true
	rt.scroll_active = false
	rt.text = text
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_color_override("default_color", color)
	var font: Font = _font()
	if font:
		rt.add_theme_font_override("normal_font", font)
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rt)
	return rt

func _build() -> void:
	var page := ColorRect.new()
	page.color = page_color
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 110.0
	column.offset_right = -110.0
	column.offset_top = 24.0
	# **대화창 자리를 비워 둔다** — 화면 아래 30%쯤을 대화창이 덮는다
	column.offset_bottom = -265.0
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	# 동영상 자리 — 아직 그림이 없어서 검은 네모로 둔다
	var screen := _panel(column, video_color, 8)
	screen.custom_minimum_size = Vector2(0, 150)
	_label(screen, "▶", 40, Color(0.3, 0.3, 0.34)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_label(column, video_title, 20, text_color)
	_label(column, "%s   ·   %s" % [channel_name, view_text], 14, dim_color)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)
	_label(column, "댓글 %d개" % comments.size(), 15, dim_color)

	for i in comments.size():
		var row: String = comments[i]
		var who: String = ""
		var body: String = row
		var cut: int = row.find("|")
		if cut >= 0:
			who = row.substr(0, cut)
			body = row.substr(cut + 1)
		var bad: bool = i == villain_index
		var box := _panel(column, panel_color if not bad else Color(0.2, 0.11, 0.12), 8)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 2)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(inner)
		_label(inner, who, 14, villain_color if bad else dim_color)
		var text := _label(inner, body, 18, text_color)
		if type_last and i == comments.size() - 1:
			_last_label = text
			_last_text = body
			text.text = ""

func _process(delta: float) -> void:
	if _last_label == null:
		return
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	_typed += delta * maxf(chars_per_second, 1.0)
	var n: int = mini(int(_typed), _last_text.length())
	_last_label.text = _last_text.substr(0, n)
	if n >= _last_text.length():
		set_process(false)
