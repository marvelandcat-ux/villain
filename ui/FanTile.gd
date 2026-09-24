@tool
class_name FanTile
extends Button

## 캐릭터 선택 목록 칸. 기본은 평범한 사각형 빈 칸이라 에디터에서 다른 Control처럼 자유롭게
## 끌어다 옮기고 크기를 바꿀 수 있다(위치·크기 = position/size, 표준 리사이즈 손잡이 그대로 동작).
## 사다리꼴처럼 비스듬한 모양을 주고 싶을 때만 corners를 4개 채우면 된다 — 그러면 사각형 대신
## 그 네 꼭짓점 모양으로 그려지고 클릭 판정도 그 모양을 따른다(안 채웠으면 그냥 사각형).
## @tool이라 에디터에서도 그대로 그려진다 — CharacterSelect.tscn의 ThumbRow 밑에 칸마다
## 별개의 노드로 놓여 있고, corners/fill_color/portrait_texture를 인스펙터에서 직접 조절할 수 있다

## ⚠️ CharacterSelect.tscn의 칸들은 가운데 랜덤(삼각형) 칸을 기준으로 왼쪽 사슬(flip_h=true,
## 촉법소년-악플러-주정뱅이)과 오른쪽 사슬(flip_h=false, 고양이 아주머니-층간소음 청년-지하철 아저씨)로
## 갈라져 있고, 인접한 칸끼리는 바운딩 박스를 lean만큼(기본 50px) 겹쳐서 배치해야 사다리꼴의 대각선
## 변이 정확히 맞물려 "붙어" 보인다(겹치는 바운딩 박스 영역 안에서도 실제로 칠해지는 폴리곤끼리는
## 겹치지 않는다 — 대각선 변을 공유할 뿐). 새 캐릭터 칸을 추가할 때:
## 1) 왼쪽 사슬 끝에 붙일 때: flip_h=true로 두고 offset_right = 지금 가장 왼쪽 칸의 offset_left + lean,
##    offset_left = offset_right - 새_칸_너비
## 2) 오른쪽 사슬 끝에 붙일 때: flip_h=false(기본값)로 두고 offset_left = 지금 가장 오른쪽 칸의
##    offset_right - lean, offset_right = offset_left + 새_칸_너비
## 3) 캐릭터가 하나 늘 때마다 왼쪽/오른쪽에 번갈아 붙여서 균형을 맞춘다(다음 캐릭터는 왼쪽부터 시작)
## 4) 다 붙인 뒤 ThumbRow의 custom_minimum_size.x를 "가장 왼쪽 칸의 offset_left ~ 가장 오른쪽 칸의
##    offset_right" 전체 폭으로 갱신한다

## 이 칸의 네 꼭짓점(왼쪽 위 -> 오른쪽 위 -> 오른쪽 아래 -> 왼쪽 아래, 이 노드의 로컬 좌표계 기준) —
## 비워두면(기본값) 이 노드의 크기(size)와 lean으로 계산한 평행사변형이 대신 그려진다.
## 삼각형으로 만들고 싶으면 뒤쪽 두 점을 같은 좌표로 두면 된다
@export var corners: PackedVector2Array = PackedVector2Array():
	set(value):
		corners = value
		queue_redraw()

## corners를 안 채운 빈 칸일 때 기본으로 쓰는 평행사변형의 기울기(px) — 위쪽 변이 이만큼 오른쪽으로
## 밀린 모양이 된다(왼쪽 변이 "/"처럼 눕는다). 0이면 그냥 사각형. size가 바뀌어도 이 값 그대로라
## 칸을 리사이즈해도 기울기 자체는 유지된다
@export var lean: float = 50.0:
	set(value):
		lean = value
		queue_redraw()

## true면 평행사변형을 좌우로 뒤집는다(위쪽이 왼쪽으로 밀려서 "\"처럼 눕는다). corners를 직접
## 채웠으면 이 값은 무시된다 — 빈 칸 기본 모양에만 영향을 준다
@export var flip_h: bool = false:
	set(value):
		flip_h = value
		queue_redraw()

## **지금 고른 칸인지.** 켜면 커서가 없어도 흰 테두리로 강조된다.
## 도감처럼 "목록에서 하나를 골라 둔 상태"가 계속 보여야 하는 화면에서 쓴다 —
## hover/focus만으로는 마우스를 치우는 순간 뭘 골랐는지 알 수 없다(2026-09-16)
@export var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

@export var fill_color: Color = Color(0.35, 0.35, 0.4):
	set(value):
		fill_color = value
		queue_redraw()

## 있으면 칸 안을 이 그림으로 채운다. 칸의 기울어진 변에 맞춰 그림을 늘리지 않고, 칸을 감싸는
## 평범한 사각형 기준으로 가운데를 크롭해 넣는다(그래서 비스듬한 모양이 그림 위의 "창문"처럼만 작동한다)
## 초상화 **뒤에** 깔리는 바탕색. 초상화 PNG는 머리 주변이 투명해서, 이게 없으면 뒤가 뻥 뚫려 보인다.
## 기본값은 투명이라 이 값을 안 주면 예전과 똑같이 그려진다(캐릭터 선택창은 안 건드려도 된다)
@export var backdrop_color: Color = Color(0, 0, 0, 0):
	set(value):
		backdrop_color = value
		queue_redraw()

@export var portrait_texture: Texture2D = null:
	set(value):
		portrait_texture = value
		queue_redraw()

## 초상화가 없을 때 가운데에 크게 보여줄 글자(예: "?", "주인공")
@export var display_text: String = "":
	set(value):
		display_text = value
		queue_redraw()
@export var display_font_size: int = 14:
	set(value):
		display_font_size = value
		queue_redraw()
## 초상화가 있을 때 아래쪽에 작게 거는 이름
@export var name_text: String = "":
	set(value):
		name_text = value
		queue_redraw()
## 이름을 올릴 **아래쪽 띠**의 높이 (칸 높이 대비 비율). 0이면 띠 없이 글자만 얹는다.
## 도감처럼 이름을 꼭 읽어야 하는 화면에서 쓴다 — 그림 위에 글자만 얹으면 배경에 묻힌다
@export_range(0.0, 0.6, 0.01) var name_band_ratio: float = 0.0:
	set(value):
		name_band_ratio = value
		queue_redraw()
@export var name_band_color: Color = Color(0.09, 0.07, 0.13, 0.9):
	set(value):
		name_band_color = value
		queue_redraw()
@export var name_font_size: int = 12:
	set(value):
		name_font_size = value
		queue_redraw()

## 초상화를 칸 안 **어디에 얼마나 크게** 놓을지 (칸 크기 대비 0~1 비율).
## 크기가 0이면 예전 방식대로 칸을 꽉 채우게 가운데를 잘라 쓴다(캐릭터 선택창이 그 방식이다).
## 값을 주면 **그림 전체를 비율 유지한 채** 그 네모 안에 넣는다 — 캐릭터마다 원본 크기가 제각각이라
## 그냥 채우면 얼굴 크기가 다 다르게 보여서, `PortraitFrames.tscn`에 잡아 둔 값을 여기로 넘겨 맞춘다
@export var portrait_frame: Rect2 = Rect2():
	set(value):
		portrait_frame = value
		queue_redraw()

## 이 칸이 어떤 캐릭터를 나타내는지(GameState.CHARACTERS의 키). 빈 문자열이면 "?" 랜덤 칸으로 취급한다.
## CharacterSelect.gd는 이 값을 보고 클릭 시그널을 연결한다 — 씬에 칸을 추가/복제해도 이 값만
## 맞는 캐릭터 이름으로 채워주면 자동으로 동작한다
## 골라짐/커서 올림에 따라 붙는 **흰 강조 테두리를 아예 쓰지 않는다**.
## 켜면 아래 plain_* 값으로 도형 윤곽만 일정하게 그린다
@export var plain_outline: bool = false:
	set(value):
		plain_outline = value
		queue_redraw()
## plain_outline일 때 쓰는 테두리 색/두께
@export var plain_outline_color: Color = Color(0.62, 0.58, 0.72, 0.85):
	set(value):
		plain_outline_color = value
		queue_redraw()
@export var plain_outline_width: float = 2.0:
	set(value):
		plain_outline_width = value
		queue_redraw()

@export var character_key: String = ""

func _ready() -> void:
	flat = true
	# UV가 0~1을 벗어날 때 그림이 반복되지 않게 — 초상화를 칸 안 네모에 넣을 때 필요하다
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	focus_mode = Control.FOCUS_ALL
	# Button 기본 포커스 테두리는 칸 모양(폴리곤)이 아니라 사각형 bounding box를 따라 그려져서,
	# 평행사변형 옆으로 흰 테두리가 튀어나와 보인다. 그 자리는 _draw()의 draw_polyline이 대신 맡으므로 꺼둔다
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if not Engine.is_editor_hint():
		for sig in [mouse_entered, mouse_exited, focus_entered, focus_exited, button_down, button_up]:
			sig.connect(queue_redraw)
	resized.connect(queue_redraw)

## corners를 4개 안 채웠으면(빈 칸 기본 상태) 지금 크기(size)와 lean으로 계산한 평행사변형을 대신 돌려준다.
## size 기준으로 매번 다시 계산하므로, 에디터에서 손잡이로 리사이즈해도 기울어진 모양 그대로 따라간다
func _effective_corners() -> PackedVector2Array:
	if corners.size() == 4:
		return corners
	var l: float = clampf(lean, 0.0, size.x / 2.0)
	if flip_h:
		return PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(size.x - l, 0.0),
			Vector2(size.x, size.y),
			Vector2(l, size.y),
		])
	return PackedVector2Array([
		Vector2(l, 0.0),
		Vector2(size.x, 0.0),
		Vector2(size.x - l, size.y),
		Vector2(0.0, size.y),
	])

func _draw() -> void:
	var pts := _effective_corners()
	if backdrop_color.a > 0.0:
		draw_colored_polygon(pts, backdrop_color)
	if portrait_texture:
		draw_polygon(pts, [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE], _portrait_uvs(pts), portrait_texture)
	else:
		draw_colored_polygon(pts, fill_color * (0.8 if button_pressed else 1.0))

	var highlighted: bool = not plain_outline and (selected or has_focus() or is_hovered())
	var outline_color: Color = Color(1, 1, 1) if highlighted else Color(0.55, 0.55, 0.6)
	var outline_width: float = 4.0 if highlighted else 1.5
	if plain_outline:
		outline_color = plain_outline_color
		outline_width = plain_outline_width
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, outline_color, outline_width, true)

	var font: Font = get_theme_default_font()
	if display_text != "":
		var text_size := font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_CENTER, -1, display_font_size)
		var pos: Vector2 = _centroid(pts) - text_size / 2.0 + Vector2(0, text_size.y * 0.35)
		draw_string_outline(font, pos, display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, display_font_size, 4, Color(0, 0, 0))
		draw_string(font, pos, display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, display_font_size, Color(1, 1, 1))
	if name_text != "":
		var band_top: float = 1.0 - name_band_ratio
		if name_band_ratio > 0.0:
			# 칸 모양을 그대로 따라가는 띠 — 위 두 점을 아래쪽으로 내려서 사각형을 만든다
			draw_colored_polygon(PackedVector2Array([
				pts[0].lerp(pts[3], band_top), pts[1].lerp(pts[2], band_top), pts[2], pts[3],
			]), name_band_color)
		var bottom_center: Vector2 = (pts[2] + pts[3]) / 2.0
		var top_center: Vector2 = (pts[0] + pts[1]) / 2.0
		# 띠가 있으면 그 한가운데에, 없으면 예전처럼 아래쪽에 살짝 걸친다
		var place: float = 1.0 - name_band_ratio * 0.5 if name_band_ratio > 0.0 else 0.82
		var name_pos: Vector2 = top_center.lerp(bottom_center, place) + Vector2(0.0, name_font_size * 0.36)
		var nsize := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, name_font_size)
		var pos: Vector2 = name_pos - Vector2(nsize.x / 2.0, 0)
		draw_string_outline(font, pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_font_size, 4, Color(0, 0, 0))
		draw_string(font, pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_font_size, Color(1, 1, 1))

## 지금 칸 모양의 꼭짓점(사다리꼴/사각형) — 선택 파동 효과(SelectionRipple)가 이 모양을 따라 퍼지게 넘겨준다
func ripple_corners() -> PackedVector2Array:
	return _effective_corners()

## 칸 모양(사각형이든 corners로 준 비스듬한 모양이든) 안인지로 직접 클릭 판정한다.
## 기본 Button은 무조건 사각형(get_rect) 판정이라, corners로 비스듬하게 만든 칸은 이게 없으면
## 옆 칸과 겹쳐진 네모 판정 때문에 클릭이 엉뚱한 칸으로 간다
func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _effective_corners())

func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / pts.size()

## 칸의 기울어진 변에 맞춰 그림 자체를 늘리지 않는다 — 대신 "빈칸(모양 틀)을 먼저 만들고
## 그 뒤에 평범한 네모 그림을 넣어서 틀 밖으로 나가는 부분만 잘라내는" 것처럼 보이게 한다.
## 그러려면 UV를 칸의 실제 꼭짓점이 아니라, 그 꼭짓점들을 감싸는 축 정렬 사각형(bounding box)
## 기준으로 계산해야 한다 — 칸 자체의 기울기는 UV 계산에 아예 관여하지 않는다
func _portrait_uvs(pts: PackedVector2Array) -> PackedVector2Array:
	var tex_size: Vector2 = portrait_texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])

	var min_pos: Vector2 = pts[0]
	var max_pos: Vector2 = pts[0]
	for p in pts:
		min_pos = min_pos.min(p)
		max_pos = max_pos.max(p)
	var box_size: Vector2 = (max_pos - min_pos).max(Vector2(1.0, 1.0))

	if portrait_frame.size.x > 0.0 and portrait_frame.size.y > 0.0:
		# **그림 전체를 비율 유지한 채** 칸 안의 네모(portrait_frame)에 넣는다.
		# 네모 밖은 UV가 0~1을 벗어나는데, texture_repeat를 꺼 두면 가장자리 픽셀이 늘어난다 —
		# 초상화는 가장자리가 투명이라 결과적으로 아무것도 안 그려진다
		var slot_pos: Vector2 = min_pos + portrait_frame.position * box_size
		var slot_size: Vector2 = portrait_frame.size * box_size
		var fit: float = minf(slot_size.x / tex_size.x, slot_size.y / tex_size.y)
		var drawn: Vector2 = tex_size * fit
		var drawn_pos: Vector2 = slot_pos + (slot_size - drawn) * 0.5
		var framed := PackedVector2Array()
		for p in pts:
			framed.append((p - drawn_pos) / drawn)
		return framed

	# 이 사각형 비율에 맞춰 텍스처 가운데를 잘라낸다(COVERED 방식 — 빈 배경이 안 비친다)
	var box_aspect: float = box_size.x / box_size.y
	var tex_aspect: float = tex_size.x / tex_size.y
	var crop_size: Vector2
	if tex_aspect > box_aspect:
		crop_size = Vector2(tex_size.y * box_aspect, tex_size.y)
	else:
		crop_size = Vector2(tex_size.x, tex_size.x / box_aspect)
	var crop_pos: Vector2 = tex_size * 0.5 - crop_size * 0.5

	# 각 꼭짓점을 "칸 모양 안에서 어디"가 아니라 "이 사각형 안에서 어디"로 재서 UV로 옮긴다.
	# 그래야 그림은 사각형 그대로 안 늘어나고, 칸 모양이 창문처럼 그 위를 오려낸다
	var uvs := PackedVector2Array()
	for p in pts:
		var box_frac: Vector2 = (p - min_pos) / box_size
		uvs.append((crop_pos + box_frac * crop_size) / tex_size)
	return uvs
