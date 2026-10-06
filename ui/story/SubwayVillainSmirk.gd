class_name SubwayVillainSmirk
extends Control

## **씨익 웃는 얼굴 클로즈업** — 스토리 컷(2026-10-06).
##
## 얼굴로 쭉 다가가다가 **"쉬익" 하는 순간 배경이 한 프레임에 사라지고 얼굴만 남는다.**
## 남은 뒤에는 이빨이 **삐싱** 하고 반짝인다.
##
## ⚠️ **지하철 배경 그림(`_0005_Background.png`)은 안 쓴다.** 그 파일은 잘라낸 배경이 아니라
## **원본 통짜 그림**이라 사람이 통째로 들어 있다 — 그 위에 씨익 웃는 얼굴을 얹으면
## 얼굴이 두 개로 보인다(2026-10-06 실측). 배경이 필요하면 `background_texture`에
## **사람이 없는 그림**을 따로 넣을 것
##
## ⚠️ **씨익 웃는 그림은 앉아 있는 컷(`SubwayVillainIdle`)의 머리와 안 맞는다** —
## 더 크게·오른쪽으로 치우쳐 그려져 있다(실측 bbox: 씨익 (473,79)-(749,375) vs 머리 (419,109)-(639,323)).
## 그래서 머리를 갈아 끼우는 게 아니라 **따로 찍는 컷**이다

const DIR := "res://sprite/storymode/지하철빌런/"
const FACE := "씨익웃는지하철빌런.png"
## 원본 캔버스 크기
const CANVAS := Vector2(1140.0, 1380.0)

@export_group("클로즈업")
## 화면 한가운데에 둘 **원본 그림의 자리**(얼굴 한가운데)
@export var focus: Vector2 = Vector2(606.0, 214.0)
## 시작 배율 -> 끝 배율. **얼굴로 다가가는 느낌**만 주는 정도라 크게 안 벌린다.
## 실측: 얼굴은 원본에서 276x296px이고 화면은 1280x720이라 **2.17이면 얼굴이 세로로 딱 맞는다**
@export var zoom_from: float = 2.55
@export var zoom_to: float = 3.15
## 다가가는 데 걸리는 시간(초). **"쉬익" 하는 순간에 맞춰 끝난다**
@export var push_time: float = 0.75

@export_group("쉬익")
## 배경이 사라지는 시각(초). 이 순간이 "쉬익"이다
@export var whoosh_at: float = 0.75
## 사라지기 **전** 뒤에 깔리는 색(지하철 안을 흉내 낸 어두운 색)
@export var backdrop_before: Color = Color(0.09, 0.11, 0.16, 1.0)
## 사라진 **뒤** 남는 색. 얼굴만 남기려고 거의 검게 둔다
@export var backdrop_after: Color = Color(0.03, 0.03, 0.04, 1.0)
## 사라지는 순간 터지는 흰 번쩍임 세기(0이면 안 번쩍)와 가시는 시간(초)
@export var flash_strength: float = 0.75
@export var flash_time: float = 0.18
## 얼굴이 살짝 튀어나오는 정도(0이면 안 튄다) — "쉬익" 하는 순간 한 번
@export var whoosh_pop: float = 0.06

@export_group("속도선")
## 속도선을 그릴지
@export var streaks_on: bool = true
## 평소 세기(0~1)와 **쉬익 하는 순간** 세기
@export var streaks_idle: float = 0.35
@export var streaks_burst: float = 1.0
## 쉬익 뒤 속도선이 잦아드는 시간(초). 0이면 안 사라진다
@export var streaks_fade: float = 0.45
@export var streaks_color: Color = Color(1, 1, 1, 0.3)

@export_group("이빨 삐싱")
## 이빨 자리(원본 그림 좌표). 실측으로 찾은 자리다
@export var teeth_at: Vector2 = Vector2(600.0, 254.0)
## 반짝임이 지나갈 범위(원본 그림 픽셀) — 이빨 덩어리에 맞춘 크기
@export var teeth_size: Vector2 = Vector2(88.0, 34.0)
## 별(✦) 크기. 0이면 빛줄기만 지나간다
@export var teeth_sparkle: float = 26.0
## **첫 반짝임이 터지는 시각**(초). 배경이 사라진 직후가 제일 세다
@export var glint_at: float = 0.92
## 그 뒤로 몇 초마다 다시 반짝일지(0이면 한 번만)
@export var glint_interval: float = 2.6

@export_group("배경 그림(선택)")
## **사람이 없는** 배경 그림을 넣으면 색 대신 이걸 깔고, 쉬익 할 때 같이 사라진다.
## 비워 두면 위의 `backdrop_before` 색만 깔린다
@export var background_texture: Texture2D = null
## 그 그림을 얼마나 어둡게 깔지
@export var background_dim: float = 0.55

## 뒤에 깔리는 색판
var _backdrop: ColorRect = null
## 배경 그림(넣었을 때만)
var _background: TextureRect = null
## 얼굴이 든 그릇 — 다가가기는 이 노드 하나만 움직인다
var _frame: Node2D = null
var _face: Sprite2D = null
## 이빨 반짝임
var _glint: LensGlint = null
## 속도선
var _streaks: WindStreaks = null
## 흰 번쩍임
var _flash: ColorRect = null
## 흐른 시간(초)
var _time: float = 0.0
## 다음 반짝임까지 남은 시간(초)
var _glint_left: float = 0.0
## 쉬익이 이미 지나갔는지 — 한 번만 터뜨리려고 들고 있는다
var _whooshed: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build()
	resized.connect(_reframe)
	_glint_left = glint_at
	_reframe()

func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = backdrop_before
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	if background_texture != null:
		_background = TextureRect.new()
		_background.name = "Background"
		_background.texture = background_texture
		_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_background.set_anchors_preset(Control.PRESET_FULL_RECT)
		_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background.modulate = Color(background_dim, background_dim, background_dim, 1.0)
		add_child(_background)
	_frame = Node2D.new()
	_frame.name = "Frame"
	add_child(_frame)
	_face = Sprite2D.new()
	_face.name = "Face"
	_face.centered = false
	_face.texture = load(DIR + FACE)
	# 얼굴 한가운데를 축으로 — 튀어나오는 연출이 제자리에서 일어나게
	_face.offset = -focus
	_face.position = focus
	_frame.add_child(_face)
	_build_glint()
	if streaks_on:
		_streaks = WindStreaks.new()
		_streaks.name = "Streaks"
		_streaks.color = streaks_color
		_streaks.power = 0.0
		add_child(_streaks)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

## 이빨 위에 반짝임을 올린다.
##
## ⚠️ **얼굴 스프라이트의 자식으로 단다** — 얼굴이 커지거나 튀어나와도 같이 따라가야 한다.
## 자식 좌표는 `offset` 때문에 밀려 있어서, 원본 그림 좌표에서 축을 빼 줘야 제자리에 온다
func _build_glint() -> void:
	_glint = LensGlint.new()
	_glint.name = "ToothGlint"
	_glint.always_show = true
	_glint.lens_size = teeth_size
	_glint.sparkle_size = teeth_sparkle
	_glint.sparkle_at = Vector2(0.3, -0.45)
	_glint.glint_color = Color(1, 1, 1, 0.95)
	# 스스로 타이머를 돌리지 않게 아주 긴 간격을 주고, 터뜨리는 건 이쪽에서 `blink_now()`로 한다
	_glint.interval_min = 9999.0
	_glint.interval_max = 9999.0
	_glint.position = teeth_at - focus
	_face.add_child(_glint)

func _process(delta: float) -> void:
	_time += delta
	_reframe()
	_update_whoosh(delta)
	_update_glint(delta)

## 다가가는 배율·자리를 다시 잡는다. **매 프레임 통째로 계산한다**(조금씩 더하면 오차가 쌓인다)
func _reframe() -> void:
	if _frame == null:
		return
	var view: Vector2 = size
	if view.x < 1.0 or view.y < 1.0:
		view = Vector2(1280, 720)
	var t: float = clampf(_time / maxf(push_time, 0.05), 0.0, 1.0)
	# 끝에서 부드럽게 멎게 — 등속으로 다가가면 기계가 미는 것처럼 보인다
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var pop: float = 0.0
	if _whooshed and whoosh_pop > 0.0:
		var since: float = _time - whoosh_at
		if since < 0.25:
			pop = whoosh_pop * (1.0 - since / 0.25)
	var k: float = (view.x / CANVAS.x) * (lerpf(zoom_from, zoom_to, eased) + pop)
	_frame.scale = Vector2(k, k)
	_frame.position = view * 0.5 - focus * k
	if _streaks:
		_streaks.position = view * 0.5
		_streaks.area = Vector2(view.x * 2.2, view.y * 1.1)

## 쉬익 — 배경을 한 프레임에 치우고, 번쩍임과 속도선을 터뜨린다
func _update_whoosh(delta: float) -> void:
	if not _whooshed and _time >= whoosh_at:
		_whooshed = true
		if _backdrop:
			_backdrop.color = backdrop_after
		if _background:
			_background.visible = false      # **순식간에** — 서서히 사라지면 "쉬익"이 아니다
		if _flash and flash_strength > 0.0:
			_flash.color = Color(1, 1, 1, flash_strength)
		if _streaks:
			_streaks.restart()
			_streaks.power = streaks_burst
	# 번쩍임은 바로 가신다
	if _flash and _flash.color.a > 0.0:
		_flash.color.a = maxf(_flash.color.a - delta / maxf(flash_time, 0.01), 0.0)
	if _streaks == null:
		return
	if not _whooshed:
		_streaks.power = streaks_idle
	elif streaks_fade > 0.0:
		_streaks.power = maxf(_streaks.power - delta / streaks_fade, 0.0)

## 이빨 삐싱 — 배경이 사라진 직후 한 번, 그 뒤로 `glint_interval`마다
func _update_glint(delta: float) -> void:
	if _glint == null or _glint_left <= 0.0:
		return
	_glint_left -= delta
	if _glint_left > 0.0:
		return
	_glint.blink_now()
	_glint_left = glint_interval if glint_interval > 0.0 else 0.0

## 쉬익까지 끝났는지(대사 타이밍을 맞출 때 물어볼 수 있게 열어 둔다)
func is_done() -> bool:
	return _time >= whoosh_at + flash_time
