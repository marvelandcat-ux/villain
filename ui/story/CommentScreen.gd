class_name CommentScreen
extends Control

## **동영상 플랫폼 댓글창** — 에피소드 2에서 악플러와 **대댓글로 말을 주고받는** 장면
## (2026-10-07 사용자 러프: 맨 위에 악플 하나, 그 아래로 들여쓴 답글이 하나씩 달린다).
##
## 그림 파일 없이 **코드로 그린다.** 아직 시안이 없는 화면이라, 그림을 기다리느니 인스펙터에서
## 닉네임·댓글만 고쳐 가며 대본을 맞춰 보는 게 빠르다. 진짜 그림이 나오면 이 노드를 걷어내면 된다.
##
## **답글은 처음에 숨어 있다가 대화창이 하나씩 띄운다** — 답글 줄마다 `Thread/Reply0`, `Reply1`... 이름이
## 붙어 있어서, 대사 사이에 `@enter Screen/Thread/Reply0 0.35` 를 끼우면 그 줄이 올라온다.
## 그래야 "말할 때마다 댓글이 달린다"가 된다.
##
## 줄 꼴은 **"닉네임|내용"**. `villain_names`에 든 닉네임은 붉게 칠한다.

## 동영상 칸에 들어갈 글
@export var video_title: String = "[일상] 오늘 하루 브이로그"
@export var channel_name: String = "평범한채널"
@export var view_text: String = "조회수 12,431회 · 3시간 전"

@export_group("댓글")
## **맨 위 댓글**(악플러가 단 악플). "닉네임|내용"
@export var root_comment: String = ""
## 그 아래 달리는 **답글들**. 위에서부터 Reply0, Reply1... 이름이 붙는다
@export var replies: PackedStringArray = PackedStringArray()
## 이 닉네임으로 단 글은 붉게 칠한다
@export var villain_names: PackedStringArray = PackedStringArray()
## 답글을 **처음에 숨겨 둘지** — 끄면 전부 보인 채로 시작한다
@export var hide_replies: bool = true
## 맨 위 댓글을 한 글자씩 찍을지 — "지금 막 올라오는 댓글"
@export var type_root: bool = true
@export var chars_per_second: float = 18.0
@export var type_delay: float = 0.5

@export_group("모양")
## 답글이 들여쓰는 폭(px)
@export var reply_indent: float = 56.0
## 프로필 동그라미 지름(px)
@export var avatar_size: float = 44.0
@export var page_color: Color = Color(0.09, 0.09, 0.11, 1.0)
@export var panel_color: Color = Color(0.15, 0.15, 0.18, 1.0)
@export var villain_panel: Color = Color(0.21, 0.11, 0.12, 1.0)
@export var video_color: Color = Color(0.03, 0.03, 0.04, 1.0)
@export var text_color: Color = Color(0.9, 0.91, 0.95, 1.0)
@export var dim_color: Color = Color(0.56, 0.58, 0.63, 1.0)
@export var villain_color: Color = Color(1.0, 0.42, 0.38, 1.0)

const FONT_PATH := "res://fonts/NanumGothic-Regular.ttf"

## 러프 그림에 있던 **동그라미 안 사람 모양** 프로필. 그림 파일을 안 만들려고 직접 그린다
class Avatar:
	extends Control
	var line: Color = Color(0.72, 0.74, 0.8)
	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.5
		var c := Vector2(r, r)
		draw_arc(c, r - 1.0, 0.0, TAU, 32, line, 2.0, true)
		# 머리
		draw_arc(c + Vector2(0.0, -r * 0.22), r * 0.26, 0.0, TAU, 20, line, 2.0, true)
		# 몸통 — 모서리 둥근 네모
		var body := Rect2(c.x - r * 0.28, c.y + r * 0.08, r * 0.56, r * 0.6)
		draw_rect(body, line, false, 2.0)

## 맨 위 댓글 글자(한 글자씩 찍을 때 쓴다)
var _root_label: RichTextLabel = null
var _root_text: String = ""
var _typed: float = 0.0
var _delay_left: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_delay_left = type_delay
	set_process(type_root and _root_label != null)

func _font() -> Font:
	return load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null

func _label(parent: Node, text: String, size_px: int, color: Color) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = false
	rt.fit_content = true
	rt.scroll_active = false
	rt.text = text
	rt.add_theme_font_size_override("normal_font_size", size_px)
	rt.add_theme_color_override("default_color", color)
	var font: Font = _font()
	if font:
		rt.add_theme_font_override("normal_font", font)
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rt)
	return rt

## "닉네임|내용"을 쪼갠다
func _split(row: String) -> Array:
	var cut: int = row.find("|")
	if cut < 0:
		return ["", row]
	return [row.substr(0, cut), row.substr(cut + 1)]

## 댓글 한 줄 — [프로필 동그라미][닉네임 + 내용 상자]. 만든 글자 라벨을 돌려준다
func _row(parent: Node, row_name: String, who: String, body: String, indent: float) -> RichTextLabel:
	var line := HBoxContainer.new()
	line.name = row_name
	line.add_theme_constant_override("separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

	if indent > 0.0:
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(indent, 0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(pad)

	var face := Avatar.new()
	face.custom_minimum_size = Vector2(avatar_size, avatar_size)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bad: bool = who in villain_names
	face.line = villain_color if bad else Color(0.72, 0.74, 0.8)
	line.add_child(face)

	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = villain_panel if bad else panel_color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12.0)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(box)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(inner)
	_label(inner, who, 14, villain_color if bad else dim_color)
	return _label(inner, body, 18, text_color)

func _build() -> void:
	var page := ColorRect.new()
	page.color = page_color
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 90.0
	column.offset_right = -90.0
	column.offset_top = 20.0
	# **대화창 자리를 비워 둔다** — 화면 아래 30%쯤을 대화창이 덮는다
	column.offset_bottom = -255.0
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	# 동영상 자리 — 아직 그림이 없어서 검은 네모로 둔다
	var screen := PanelContainer.new()
	var vs := StyleBoxFlat.new()
	vs.bg_color = video_color
	vs.set_corner_radius_all(8)
	screen.add_theme_stylebox_override("panel", vs)
	screen.custom_minimum_size = Vector2(0, 118)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(screen)
	_label(screen, "▶", 34, Color(0.3, 0.3, 0.34)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_label(column, video_title, 19, text_color)
	_label(column, "%s   ·   %s" % [channel_name, view_text], 13, dim_color)
	_label(column, "댓글 %d개" % (replies.size() + (1 if root_comment != "" else 0)), 14, dim_color)

	var thread := VBoxContainer.new()
	thread.name = "Thread"
	thread.add_theme_constant_override("separation", 7)
	thread.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(thread)

	if root_comment != "":
		var head: Array = _split(root_comment)
		var text := _row(thread, "Root", head[0], head[1], 0.0)
		if type_root:
			_root_label = text
			_root_text = head[1]
			text.text = ""

	for i in replies.size():
		var part: Array = _split(replies[i])
		_row(thread, "Reply%d" % i, part[0], part[1], reply_indent)
		if hide_replies:
			# `@enter Screen/Thread/ReplyN` 이 올려 줄 때까지 숨어 있는다
			var node := thread.get_node("Reply%d" % i) as Control
			node.modulate.a = 0.0
			node.visible = false

func _process(delta: float) -> void:
	if _root_label == null:
		return
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	_typed += delta * maxf(chars_per_second, 1.0)
	var n: int = mini(int(_typed), _root_text.length())
	_root_label.text = _root_text.substr(0, n)
	if n >= _root_text.length():
		set_process(false)
