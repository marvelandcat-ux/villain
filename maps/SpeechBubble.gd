@tool
extends Node2D
## 머리 위에 뜨는 말풍선. say()로 대사를 띄우면 꼬리 끝(노드 원점)에서 "팝" 하고 커졌다 살짝
## 줄며 자리잡고(그 뒤로도 숨쉬듯 미세하게), 글자가 한 글자씩 타이핑된다(삑 소리 + 물결).
## 그림은 전부 _draw()로 직접 그린다(스프라이트 안 씀): 글자에 맞춘 흰 타원 + 캐릭터를 향한 꼬리 + 검은 윤곽선.
##  - 타원 크기는 글자 상자에서 바로 계산(pad_x/pad_y 여유)
##  - 꼬리는 타원 아래에서 캐릭터 머리(원점) 쪽으로 뻗는 삼각 꼬리 — 윤곽선이 하나로 이어져 틈이 없음
## @tool이라 에디터에서 preview_text로 미리보기된다. 소리·타이핑·숨쉬기는 게임에서만.

const MIX_RATE := 22050.0
const FONT_PATH := "res://font/강한육군 Bold.ttf"
const TIP := Vector2.ZERO  # 꼬리 끝 = 팝이 커지는 기준점(노드 원점 = 캐릭터 머리)

## 글자 크기
@export var font_size: int = 26:
	set(v):
		font_size = v
		_refresh_preview()
## 타원 가로 여유(글자 상자 양옆에 더하는 px)
@export var pad_x: float = 60.0:
	set(v):
		pad_x = v
		_refresh_preview()
## 타원 세로 여유(글자 상자 위아래에 더하는 px)
@export var pad_y: float = 36.0:
	set(v):
		pad_y = v
		_refresh_preview()
## 타원 중심이 꼬리 끝(원점=해병 머리) 기준 어디에 뜨는지 — 오른쪽 위
@export var bubble_center: Vector2 = Vector2(150.0, -145.0):
	set(v):
		bubble_center = v
		_refresh_preview()
## 꼬리 끝이 원점(캐릭터 머리)까지 얼마나 가는지 0~1 (1이면 머리까지 닿음)
@export_range(0.0, 1.0, 0.01) var tail_reach: float = 1.0:
	set(v):
		tail_reach = v
		_refresh_preview()
## 꼬리 입구 벌어짐(라디안, 클수록 꼬리 밑동이 넓음)
@export var tail_spread: float = 0.10:
	set(v):
		tail_spread = v
		_refresh_preview()
## 윤곽선 두께(px)
@export var outline_width: float = 5.0:
	set(v):
		outline_width = v
		_refresh_preview()
## 에디터 미리보기에 쓸 샘플 대사(게임엔 영향 없음)
@export var preview_text: String = "신병 지금 부터 신병 훈련을 시작한다":
	set(v):
		preview_text = v
		_refresh_preview()

## 글자 하나가 나오는 간격(초, 작을수록 빠름)
@export var type_interval: float = 0.045

const FILL_COLOR := Color(1, 1, 1, 1)
const LINE_COLOR := Color(0.12, 0.12, 0.14, 1)
const POP_TIME := 0.30     # 등장 시간
const CLOSE_TIME := 0.18   # 사라짐 시간
const PULSE_SPEED := 3.2   # 숨쉬기 속도
const PULSE_AMP := 0.03    # 숨쉬기 폭
const HINT_BLINK := 6.0    # 계속(▼) 깜빡임 속도

## --- 대사 안에 넣는 작은 아이콘(쿨타임 파이·패링 X) ---
## 쿨 파이(CooldownPies)와 같은 모양·색을 코드로 그려 텍스처로 만든다(그림 파일 없음). 대사에는 `icon(종류)`가 돌려주는
## `[img]` 태그를 끼워 쓴다. [img]는 경로로 텍스처를 찾으므로 메모리 텍스처에 가짜 경로를 붙여 둔다(take_over_path)
const ICON_SIZE := 28          # 대사 안에서 보이는 크기(px)
const ICON_RES := 48           # 텍스처 해상도 — 보이는 크기보다 크게 잡아 줄여 그리면 선명하다
const ICON_SUBSAMPLE := 3      # 한 픽셀을 이만큼 x 이만큼으로 쪼개 평균(가장자리 부드럽게)
const ICON_PIE_RATIO := 0.7    # 파이 아이콘이 차오른 정도(쿨타임 중인 모습)
const ICON_PATH_FMT := "res://__bubble_icon_%s.tres"
const ICON_BACK := Color(0.16, 0.18, 0.26, 0.92)
const ICON_COLORS := {
	"guard": Color(0.55, 0.85, 1.0),   # 방어 — 하늘색
	"dash": Color(0.7, 1.0, 0.2),      # 대시 — 라임
	"parry": Color(1.0, 0.2, 0.2),     # 패링(기본공격 잠금) — 빨강 X
}
## 글자 수를 셀 때 아이콘 하나를 대신하는 글자(RichTextLabel이 이미지를 글자 하나로 세므로 맞춰 준다)
const ICON_STAND_IN := "가"

var _font: Font
var rt: RichTextLabel
var _text_size := Vector2(120, 34)  # 마지막으로 잰 글자 상자 크기
var _scale := 0.0          # 팝 진행도 0~1
var _draw_scale := 0.0     # 실제 그릴 때 스케일(팝 x 숨쉬기)
var _pulse_t := 0.0
var _type_t := 0.0
var _shown := 0            # 지금까지 드러난 글자 수
var _dialogue := ""        # 화면에 보이는 글자만(타이핑 수·블립용, BBCode 제외)
var _talking := false
var _hint_enabled := false  # 타이핑이 끝난 뒤 "계속(▼)" 표시를 켤지
var _hint_wait := 0.0       # 타이핑이 끝난 뒤 안 넘기고 기다린 시간(초)
var _press_hint_delay := -1.0  # 0 이상이면 이 초 뒤 "스페이스를 누르세요"를 띄움(음수면 안 띄움)
var _pop_tween: Tween
var _bbcode_re: RegEx
var _icon_re: RegEx
var _icon_textures: Dictionary = {}   # 종류 -> ImageTexture(처음 쓸 때 한 번만 만든다)
var _players: Array[AudioStreamPlayer] = []
var _blip: AudioStreamWAV
var _idx := 0


func _ready() -> void:
	z_index = 20
	if Engine.is_editor_hint():
		_refresh_preview()
		return
	_build_text()
	_blip = _make_blip()
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.stream = _blip
		add_child(p)
		_players.append(p)


## --- 에디터 미리보기 ---
func _refresh_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_clear_generated()
	_build_text()
	_text_size = _measure(preview_text)
	rt.text = _wrap(preview_text)
	rt.visible_characters = -1
	_layout_text()
	_draw_scale = 1.0
	_apply_text_scale()
	queue_redraw()


func _clear_generated() -> void:
	var old := get_node_or_null("TextPivot")
	if old:
		old.free()
	rt = null


func _build_text() -> void:
	var pivot := Node2D.new()
	pivot.name = "TextPivot"
	pivot.position = TIP
	pivot.scale = Vector2.ZERO
	add_child(pivot)

	rt = RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.scroll_active = false
	rt.clip_contents = false
	rt.fit_content = false
	rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := _get_font()
	if font:
		rt.add_theme_font_override("normal_font", font)
		rt.add_theme_font_override("bold_font", font)
		rt.add_theme_font_override("italics_font", font)
		rt.add_theme_font_override("bold_italics_font", font)
		rt.add_theme_font_override("mono_font", font)
	# 모든 글꼴 슬롯 크기를 맞춘다 — 안 그러면 [b]/[i] 강조 글자가 기본 크기(16px)로 작아진다
	rt.add_theme_font_size_override("normal_font_size", font_size)
	rt.add_theme_font_size_override("bold_font_size", font_size)
	rt.add_theme_font_size_override("italics_font_size", font_size)
	rt.add_theme_font_size_override("bold_italics_font_size", font_size)
	rt.add_theme_font_size_override("mono_font_size", font_size)
	rt.add_theme_color_override("default_color", LINE_COLOR)
	rt.visible_characters = 0
	pivot.add_child(rt)


func _get_font() -> Font:
	if _font == null:
		_font = load(FONT_PATH)
	return _font


## 글자 상자 크기(폰트로 바로 계산 — 한 프레임 대기 불필요, 에디터·게임 동일)
func _measure(plain: String) -> Vector2:
	var font := _get_font()
	if font:
		var w: float = font.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		return Vector2(w, font.get_height(font_size))
	return Vector2(plain.length() * font_size * 0.95, font_size * 1.3)


func _wrap(s: String) -> String:
	return "[center][wave amp=18.0 freq=4.0]%s[/wave][/center]" % s


## 글자를 타원 중심(bubble_center)에 가운데 정렬
func _layout_text() -> void:
	if rt == null:
		return
	rt.size = _text_size + Vector2(8, 8)
	rt.position = bubble_center - rt.size * 0.5


# --- 타원·꼬리 모양 계산(스케일 1 기준, 로컬 좌표) ---
func _ellipse(c: Vector2, hw: float, hh: float, a: float) -> Vector2:
	return c + Vector2(cos(a) * hw, sin(a) * hh)


func _draw() -> void:
	if _draw_scale <= 0.02:
		return
	var s := _draw_scale
	var c := bubble_center
	var hw: float = _text_size.x * 0.5 + pad_x
	var hh: float = _text_size.y * 0.5 + pad_y
	# 꼬리 끝(원점 쪽) + 입구 두 점
	var tip := c.lerp(TIP, tail_reach)
	var base_a := atan2(tip.y - c.y, tip.x - c.x)
	var ea := _ellipse(c, hw, hh, base_a - tail_spread)
	var eb := _ellipse(c, hw, hh, base_a + tail_spread)

	# 채우기: 타원 본체 + 꼬리 삼각형
	var body := PackedVector2Array()
	var n := 64
	for i in n:
		body.append(_ellipse(c, hw, hh, TAU * float(i) / float(n)) * s)
	draw_colored_polygon(body, FILL_COLOR)
	draw_colored_polygon(PackedVector2Array([ea * s, eb * s, tip * s]), FILL_COLOR)

	# 윤곽선: 입구(짧은 호)는 빼고 긴 호를 돈 뒤 꼬리로 닫음 → 이음새 없음
	var outline := PackedVector2Array()
	var span := TAU - 2.0 * tail_spread
	var seg := 64
	for i in seg + 1:
		var a: float = (base_a + tail_spread) + span * float(i) / float(seg)
		outline.append(_ellipse(c, hw, hh, a) * s)
	outline.append(tip * s)
	outline.append(outline[0])
	draw_polyline(outline, LINE_COLOR, maxf(outline_width * s, 1.0), true)

	# 계속 표시: 타이핑이 끝났고 hint가 켜져 있으면 글자 아래에 깜빡이는 ▼
	if _hint_enabled and _dialogue != "" and _shown >= _dialogue.length():
		var cy := c.y + (_text_size.y * 0.5 + hh) * 0.5   # 글자 아래~타원 바닥 사이
		var tri := PackedVector2Array([
			Vector2(c.x - 7.0, cy) * s,
			Vector2(c.x + 7.0, cy) * s,
			Vector2(c.x, cy + 8.0) * s,
		])
		var col := LINE_COLOR
		col.a = 0.2 + 0.8 * (0.5 + 0.5 * sin(_pulse_t * HINT_BLINK))
		draw_colored_polygon(tri, col)
		# press_hint_delay가 정해진 줄에서만, 그 초 뒤 ▼ 아래에 "스페이스를 누르세요"
		if _press_hint_delay >= 0.0 and _hint_wait >= _press_hint_delay:
			_draw_press_hint(c, hh, s)


## 말풍선 바닥 아래에 흰 알약 + "스페이스를 누르세요"(배경 어디서든 읽히게)
func _draw_press_hint(c: Vector2, hh: float, s: float) -> void:
	var font := _get_font()
	if font == null:
		return
	# 팝으로 커지거나 닫히며 줄어드는 중엔 글자 크기가 0이 돼 draw_string이 에러를 낸다 — 그 구간은 안 그린다
	if int(15 * s) < 1:
		return
	var msg := "스페이스를 누르세요"
	var fs := 15
	var tw: float = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var th: float = font.get_height(fs)
	var top := c.y + hh + 10.0                     # 말풍선 바닥 아래
	var box := Rect2(c.x - tw * 0.5 - 9.0, top, tw + 18.0, th + 8.0)
	var sbox := Rect2(box.position * s, box.size * s)
	draw_rect(sbox, Color(1, 1, 1, 0.9))
	draw_rect(sbox, LINE_COLOR, false, maxf(1.5 * s, 1.0))
	var base := Vector2(c.x - tw * 0.5, top + 4.0 + font.get_ascent(fs))   # 베이스라인(상자 안 가운데쯤)
	draw_string(font, base * s, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * s), LINE_COLOR)


## 대사를 띄운다(이미 떠 있으면 새 대사로 바꿔 다시 타이핑).
## text에 BBCode([color] 등)가 있어도 됨 — 타이핑 수·블립은 보이는 글자 기준으로 센다.
## hint=true면 타이핑이 끝난 뒤 말풍선 안쪽 아래에 깜빡이는 ▼(계속)를 그린다.
## press_hint_delay가 0 이상이면 타이핑이 끝나고 그 초 뒤 "스페이스를 누르세요"까지 띄운다(음수면 안 띄움).
func say(text: String, hint: bool = false, press_hint_delay: float = -1.0) -> void:
	if rt == null:
		_build_text()
	_dialogue = _strip_bbcode(text)
	_shown = 0
	_type_t = 0.0
	_talking = true
	_hint_enabled = hint
	_hint_wait = 0.0
	_press_hint_delay = press_hint_delay
	rt.visible_characters = 0
	rt.text = _wrap(text)
	_text_size = _measure(_dialogue)
	_layout_text()
	if _scale < 0.99:
		_pop(1.0, POP_TIME, Tween.TRANS_BACK)
	else:
		queue_redraw()


## 아직 글자가 다 안 나왔으면 true
func is_typing() -> bool:
	return _talking and rt != null and _shown < _dialogue.length()


## 타이핑을 즉시 끝내 글자를 전부 보여준다(스페이스로 건너뛸 때)
func finish_typing() -> void:
	if rt == null:
		return
	_shown = _dialogue.length()
	rt.visible_characters = -1
	queue_redraw()


## BBCode 태그([color] 등)를 떼어 화면에 보이는 글자만 남긴다. 아이콘([img])은 글자 하나로 센다
func _strip_bbcode(s: String) -> String:
	if _bbcode_re == null:
		_bbcode_re = RegEx.new()
		_bbcode_re.compile("\\[[^\\]]*\\]")
		_icon_re = RegEx.new()
		_icon_re.compile("\\[img[^\\]]*\\][^\\[]*\\[/img\\]")
	return _bbcode_re.sub(_icon_re.sub(s, ICON_STAND_IN, true), "", true)


## 대사에 끼울 아이콘 태그를 돌려준다. 종류: "guard"(방어 파이) / "dash"(대시 파이) / "parry"(패링 X)
func icon(kind: String) -> String:
	if not _icon_textures.has(kind):
		var tex := _make_icon(kind)
		tex.take_over_path(ICON_PATH_FMT % kind)   # [img]가 이 경로로 찾아 온다
		_icon_textures[kind] = tex
	return "[img=%dx%d]%s[/img]" % [ICON_SIZE, ICON_SIZE, ICON_PATH_FMT % kind]


## 아이콘 한 장을 그린다. 좌표는 쿨 파이와 같은 단위(반지름 8) — 가장자리 윤곽선까지 들어가게 -11~11을 텍스처에 편다
func _make_icon(kind: String) -> ImageTexture:
	var img := Image.create(ICON_RES, ICON_RES, false, Image.FORMAT_RGBA8)
	var sub: int = ICON_SUBSAMPLE
	var samples: float = float(sub * sub)
	for py in ICON_RES:
		for px in ICON_RES:
			var r := 0.0
			var g := 0.0
			var b := 0.0
			var a := 0.0
			for sy in sub:
				for sx in sub:
					var u: float = (float(px) + (float(sx) + 0.5) / float(sub)) / float(ICON_RES) * 22.0 - 11.0
					var v: float = (float(py) + (float(sy) + 0.5) / float(sub)) / float(ICON_RES) * 22.0 - 11.0
					var c: Color = _icon_sample(kind, Vector2(u, v))
					r += c.r * c.a
					g += c.g * c.a
					b += c.b * c.a
					a += c.a
			if a > 0.0:
				img.set_pixel(px, py, Color(r / a, g / a, b / a, a / samples))
	return ImageTexture.create_from_image(img)


## 아이콘 한 점의 색(단위 좌표 p). 투명이면 alpha 0
func _icon_sample(kind: String, p: Vector2) -> Color:
	var fill: Color = ICON_COLORS.get(kind, Color.WHITE)
	if kind == "parry":
		# X: 대각선 막대 둘의 합집합. 안쪽은 빨강, 바깥 1.4는 어두운 윤곽선
		var d: float = minf(_arm_distance(p, 1.0), _arm_distance(p, -1.0))
		if d <= 0.0:
			return fill
		if d <= 1.4:
			return LINE_COLOR
		return Color(0, 0, 0, 0)
	var dist: float = p.length()
	if dist > 9.4:
		return Color(0, 0, 0, 0)
	if dist > 8.0:
		return LINE_COLOR
	# 12시 방향에서 시계 방향으로 ICON_PIE_RATIO만큼은 색, 나머지는 어두운 바탕
	var ang: float = fposmod(atan2(p.x, -p.y), TAU)
	return fill if ang / TAU <= ICON_PIE_RATIO else ICON_BACK


## X의 막대 하나(대각선 방향 dir = 1 또는 -1)까지의 부호 있는 거리(안쪽이 음수). 쿨 파이 X와 같은 길이 8.5, 반 굵기 3.0
func _arm_distance(p: Vector2, dir: float) -> float:
	var along: float = (p.x + dir * p.y) * 0.70710678
	var across: float = (p.y * dir - p.x) * 0.70710678
	return maxf(absf(along) - 8.5, absf(across) - 3.0)


## 말풍선을 꼬리 끝으로 쏙 집어넣어 닫는다.
func close() -> void:
	_talking = false
	_pop(0.0, CLOSE_TIME, Tween.TRANS_CUBIC)


func _pop(target: float, time: float, trans: Tween.TransitionType) -> void:
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.set_trans(trans).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_method(_set_pop, _scale, target, time)


func _set_pop(s: float) -> void:
	_scale = s
	_update_scale()


## 그릴 스케일 = 팝 진행도 x 숨쉬기 — 글자 피벗과 _draw가 같은 값으로 커진다
func _update_scale() -> void:
	var pulse := 1.0
	if _scale > 0.99:
		pulse = 1.0 + sin(_pulse_t * PULSE_SPEED) * PULSE_AMP
	_draw_scale = _scale * pulse
	_apply_text_scale()
	queue_redraw()


func _apply_text_scale() -> void:
	var pivot := get_node_or_null("TextPivot") as Node2D
	if pivot:
		pivot.scale = Vector2(_draw_scale, _draw_scale)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_pulse_t += delta
	if _scale > 0.001:
		_update_scale()
	# 다 커진 뒤 한 글자씩 드러내며 글자마다 블립(공백/줄바꿈은 소리 없이)
	if _talking and _scale > 0.9 and rt and _shown < _dialogue.length():
		_type_t += delta
		while _type_t >= type_interval and _shown < _dialogue.length():
			_type_t -= type_interval
			_shown += 1
			rt.visible_characters = _shown
			var ch := _dialogue[_shown - 1]
			if ch != " " and ch != "\n":
				_play_blip()
	# 타이핑이 끝난 뒤 안 넘기고 기다린 시간을 센다("스페이스를 누르세요" 안내용)
	if _hint_enabled and _dialogue != "" and _shown >= _dialogue.length():
		_hint_wait += delta
	else:
		_hint_wait = 0.0


func _play_blip() -> void:
	if _players.is_empty():
		return
	var p := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.play()


## 언더테일식 짧은 사각파 블립을 코드로 합성(외부 음원 파일 없음)
func _make_blip() -> AudioStreamWAV:
	var dur := 0.055
	var n := int(dur * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / MIX_RATE
		var p := float(i) / float(n)
		var sq := 1.0 if sin(TAU * 480.0 * t) > 0.0 else -1.0
		var v: float = clampf(sq * pow(1.0 - p, 2.0) * 0.22, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(MIX_RATE)
	w.stereo = false
	w.data = data
	return w
