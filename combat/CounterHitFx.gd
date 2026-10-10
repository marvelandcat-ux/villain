extends Node2D

## 카운터 히트 연출(2026-10-10 사용자 결정) — 맞는 순간 **화면이 잠깐 멈추고**, 캐릭터 뒤 배경이 **살짝 흐려지고**,
## 맞은 쪽 머리 위에 **"COUNTER"** 가 뜬다. 판정·경직은 `Hitbox._try_hit()`/`Fighter.add_counter_stun()`이 하고 여기는 보여주기만.
##
## 씬에 하나만 둔다(`Hitbox._play_counter_fx`가 이름으로 찾아 쓰고 없으면 만든다). 연달아 터지면 처음부터 다시.
## - 슬로: `Engine.time_scale`을 SLOW_SCALE(0.4)로 → **실제 시간**(Time.get_ticks_usec)으로 FREEZE_TIME(1초) 뒤 되돌린다.
##   다른 연출이 이미 느리게 해 뒀으면(KO 슬로·단소 반격·내무반 슬램) 건드리지 않는다
## - 흐림: ScreenGrade처럼 카메라 화면을 덮는 사각형(z BLUR_Z) + `CounterHitBlur.gdshader`.
##   캐릭터(fighters 그룹)는 그동안 z를 FOCUS_Z로 올려 흐림 **위**에 그린다 — 끝나면 원래 z로 되돌린다
## - 글자: CanvasLayer라 카메라 배율과 상관없이 같은 크기. 구경 모드(attract)에선 아무것도 안 띄운다

const SHADER: Shader = preload("res://combat/CounterHitBlur.gdshader")
const FONT: Font = preload("res://fonts/Jua-Regular.ttf")

## 노드 이름 — 씬에 하나만 두려고 이 이름으로 찾는다
const NODE_NAME := "CounterHitFx"
## 느려지는 시간(실제 초) — 이 연출 전체 길이이기도 하다(줌·원근·흐림이 이 안에 끝난다).
## 2026-10-10 사용자: "시간이 0.4만큼 느려지고 1초 뒤에 끝" — 예전엔 0.15초 동안 거의 멈췄다(0.0001배)
const FREEZE_TIME := 1.0
## 흐림이 차오르는 / 유지 / 빠지는 시간(실제 초) — 2026-10-10 사용자 요청으로 2배(0.04/0.2/0.25 → 0.08/0.4/0.5)
const BLUR_IN := 0.08
const BLUR_HOLD := 0.4
const BLUR_OUT := 0.5
## 흐림 판의 z — ScreenGrade(3000) 아래, 맵의 거의 모든 것 위
const BLUR_Z := 2000
## 흐림 동안 캐릭터를 올려 둘 z (흐림 판 바로 위). 숫자 팝업·스파크도 Hitbox가 이 위로 올린다
const FOCUS_Z := 2001
## 느려지는 배속(0.4 = 0.4배 속도)
const SLOW_SCALE := 0.4
## 히트스톱 배속(Hitbox와 같은 값) — 이 값이면 "남의 슬로"가 아니라 잠깐 멈춤이라 이어받는다
const TIME_STOP := 0.0001

## "COUNTER" 글자
const TEXT := "COUNTER"
const TEXT_SIZE := 52
const TEXT_COLOR := Color(1.0, 0.25, 0.16)
const TEXT_OUTLINE := 12
## 맞은 쪽 발밑(원점)에서 글자 가운데까지 — 머리(+30 발끝 기준 허트박스 꼭대기) 위
const TEXT_OFFSET := Vector2(0.0, -95.0)
## 글자가 떠 있는 전체 시간 / 처음 튀어나오는 시간 / 끝에 사라지는 시간(실제 초)
const TEXT_TIME := 0.8
const TEXT_POP := 0.09
const TEXT_FADE := 0.25
## 사라지는 동안 위로 떠오르는 높이(화면 px)
const TEXT_RISE := 18.0
## 화면 가장자리에서 이만큼은 안쪽에 둔다(글자가 잘리지 않게)
const TEXT_MARGIN := 16.0
## 카메라 범위보다 이만큼 크게 덮는다(ScreenGrade와 같은 이유 — 흔들림으로 가장자리가 비치지 않게)
const OVERSIZE := 1.08
## 줌 — 맞은 쪽에게 당겨 붙는다(2026-10-10 사용자 요청). 배율 / 전체 시간·들어가고 나오는 시간(실제 초, 흐림과 비슷하게 끝난다) /
## 대상 쪽으로 옮겨 가는 빠르기(실제 시간)
const ZOOM_MUL := 1.35
const ZOOM_TIME := 1.0
const ZOOM_BLEND := 0.14
## 원근 — 줌하는 동안 **카메라가 옆으로 돌아 보는 것처럼** 화면을 사다리꼴로 휜다(`CounterHitWarp.gdshader`, 길티기어 카운터).
## 화면을 빙 돌리는(roll) 게 아니라 세로축 둘레로 도는(yaw) 모양 — 2026-10-10 사용자: "x 말고 z로, 3D처럼".
## 돈 각도(도) / 원근 세기(작을수록 세다) / 그리는 z(색보정 3000 위, 레터박스 4000 아래 — 캐릭터까지 같이 휜다).
## 방향은 때린 쪽 → 맞은 쪽 부호. 각도를 키우면 확대(fit)가 커져 화면 가장자리가 더 잘린다
const WARP_DEG := 10.0
const WARP_DEPTH := 2.2
const WARP_Z := 3500
const WARP_SHADER: Shader = preload("res://combat/CounterHitWarp.gdshader")
const ZOOM_TRACK := 18.0

var _mat: ShaderMaterial
var _half: Vector2 = Vector2(640.0, 360.0) * OVERSIZE
var _layer: CanvasLayer
var _label: Label
var _label_base: Vector2 = Vector2.ZERO
## 글자를 띄울 월드 자리(맞은 쪽 머리 위) — 카메라가 움직여도 매 프레임 여기에 다시 맞춘다
var _text_world: Vector2 = Vector2.ZERO
## 이번 연출이 시작된 실제 시각(마이크로초)
var _start_us: int = 0
var _running: bool = false
## 내가 지금 시간을 멈춰 두었는지 — 되돌릴 때 남의 슬로를 건드리지 않게
var _freezing: bool = false
## 올려 둔 캐릭터의 원래 z {Fighter: [z_index, z_as_relative]}
var _focused: Dictionary = {}
## 원근 판(내 형제 노드)과 그 사각형·재질 / 도는 방향(+1·-1)
var _warp: Node2D = null
var _warp_rect: ColorRect = null
var _warp_mat: ShaderMaterial = null
var _warp_dir: float = 1.0
var _warp_target: Node2D = null

func _ready() -> void:
	name = NODE_NAME
	# 시간이 멈춰도(배속 ~0)·트리가 멈춰도 실제 시간으로 돌아야 멈춤을 풀 수 있다
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	z_as_relative = false
	z_index = BLUR_Z
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	visible = false
	modulate.a = 0.0
	# ⚠️ ScreenGrade와 같은 함정 — 바로 앞에서 화면을 새로 복사하게 강제한다(흐림 CanvasGroup이 낡은 복사를 남길 수 있다)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	copy.show_behind_parent = true
	add_child(copy)
	_layer = CanvasLayer.new()
	_layer.layer = 3
	add_child(_layer)
	_label = Label.new()
	_label.text = TEXT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", TEXT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", TEXT_OUTLINE)
	_label.visible = false
	_layer.add_child(_label)
	set_process(false)

## 카운터 히트 한 번 — victim은 맞은 몸(글자를 그 머리 위에 띄운다), attacker는 때린 몸(기울이는 방향을 정한다, 없어도 된다)
func play(victim: Node2D, attacker: Node2D = null) -> void:
	if GameState.game_mode == "attract":
		return
	_start_us = Time.get_ticks_usec()
	_running = true
	_start_freeze()
	_focus_fighters()
	_show_text(victim.global_position + TEXT_OFFSET)
	_zoom_in(victim, attacker)
	_build_warp()
	_follow_camera()
	visible = GameState.screen_effects_enabled
	set_process(true)

func _process(_delta: float) -> void:
	if not _running:
		return
	var t: float = float(Time.get_ticks_usec() - _start_us) / 1000000.0
	_update_freeze(t)
	_update_blur(t)
	_update_text(t)
	_update_warp(t)
	_follow_camera()
	if t >= maxf(maxf(BLUR_IN + BLUR_HOLD + BLUR_OUT, TEXT_TIME), maxf(FREEZE_TIME, ZOOM_TIME)):
		_finish()

## --- 줌 ---

## 맞은 쪽에게 당겨 붙는다 — 카메라(`CameraRig.focus_on`)가 실제 시간으로 들어갔다 나온다. 원근 방향(_warp_dir)도 여기서 정한다:
## 맞은 쪽이 때린 쪽보다 오른쪽이면 +, 왼쪽이면 -. 때린 쪽을 모르면 맞은 쪽이 보는 반대
func _zoom_in(victim: Node2D, attacker: Node2D) -> void:
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	var dir: float = 0.0
	if attacker != null and is_instance_valid(attacker):
		dir = signf(victim.global_position.x - attacker.global_position.x)
	if is_zero_approx(dir) and "facing" in victim:
		dir = -signf(float(victim.facing))
	if is_zero_approx(dir):
		dir = 1.0
	_warp_dir = dir
	_warp_target = victim
	if cam == null or not cam.has_method("focus_on"):
		return
	cam.focus_on(victim, ZOOM_MUL, ZOOM_TIME, ZOOM_BLEND, 0.0, ZOOM_TRACK)

## 원근 판을 만든다 — **내 자식이 아니라 형제로** 둔다. 나는 modulate 알파로 흐림 세기를 조절하고
## 끝나면 visible을 끄는데, 자식이면 그게 그대로 물려 원근까지 흐려지고 꺼진다
func _build_warp() -> void:
	if _warp != null and is_instance_valid(_warp):
		return
	_warp = Node2D.new()
	_warp.name = "CounterHitWarp"
	_warp.z_as_relative = false
	_warp.z_index = WARP_Z
	_warp.process_mode = Node.PROCESS_MODE_ALWAYS
	_warp.visible = false
	# ScreenGrade와 같은 함정 — 바로 앞에서 화면을 새로 복사하게 강제한다(색보정·캐릭터까지 다 그려진 화면)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_warp.add_child(copy)
	_warp_rect = ColorRect.new()
	_warp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warp_mat = ShaderMaterial.new()
	_warp_mat.shader = WARP_SHADER
	_warp_rect.material = _warp_mat
	_warp.add_child(_warp_rect)
	get_parent().add_child.call_deferred(_warp)

## 원근 판을 카메라 화면에 맞추고 각도를 넣는다. 각도는 줌과 같은 곡선(들어가며 커지고 나오며 0)
func _update_warp(t: float) -> void:
	if _warp == null or not is_instance_valid(_warp) or not _warp.is_inside_tree():
		return
	var k: float = minf(t / ZOOM_BLEND, (ZOOM_TIME - t) / ZOOM_BLEND)
	k = clampf(k, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var yaw: float = deg_to_rad(WARP_DEG) * k * _warp_dir
	var cam: Camera2D = get_viewport().get_camera_2d()
	var on: bool = GameState.screen_effects_enabled and absf(yaw) > 0.0005 and cam != null
	_warp.visible = on
	if not on:
		return
	var view: Vector2 = get_viewport_rect().size
	var half: Vector2 = view / cam.zoom * (0.5 * OVERSIZE)
	_warp.global_position = cam.get_screen_center_position()
	_warp_rect.position = -half
	_warp_rect.size = half * 2.0
	var aspect: float = view.x / maxf(view.y, 1.0)
	_warp_mat.set_shader_parameter("yaw", yaw)
	_warp_mat.set_shader_parameter("depth", WARP_DEPTH)
	_warp_mat.set_shader_parameter("aspect", aspect)
	# 맞은 사람(몸 가운데) 화면 자리 — 원근으로 휘어도 이 점은 안 움직이게 한다(안 그러면 확대에 밀려 체력바 밑으로 내려갔다)
	var pivot := Vector2.ZERO
	if _warp_target != null and is_instance_valid(_warp_target):
		var sp: Vector2 = get_viewport().get_canvas_transform() * (_warp_target.global_position + Vector2(0.0, -30.0))
		pivot = (sp / view - Vector2(0.5, 0.5)) * 2.0
		pivot.x *= aspect
	var fs: Array = _warp_fit_shift(yaw, aspect, pivot)
	_warp_mat.set_shader_parameter("fit", fs[0])
	_warp_mat.set_shader_parameter("shift", fs[1])

## 셰이더와 같은 원근 식(화면 좌표 s → 원본 좌표). 가로는 aspect배 단위
func _warp_project(s: Vector2, yaw: float) -> Vector2:
	var c: float = cos(yaw)
	var sn: float = sin(yaw)
	var px: float = s.x * WARP_DEPTH / (WARP_DEPTH * c - s.x * sn)
	return Vector2(px, s.y * (WARP_DEPTH + px * sn) / WARP_DEPTH)

## 확대(fit)와 밀기(shift)를 같이 구한다 — 맞은 사람 자리(pivot)는 **제자리에** 남기고, 네 모서리는 원본 화면 안에서만 읽게.
## 원근 식이 직선이 아니라 몇 번 되풀이해 맞춘다. 돌려주는 값: [fit, shift]
func _warp_fit_shift(yaw: float, aspect: float, pivot: Vector2) -> Array:
	var fit: float = 1.0
	var shift := Vector2.ZERO
	for i in 6:
		shift = _warp_project(pivot * fit, yaw) - pivot
		var worst: float = 0.0
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var p: Vector2 = _warp_project(Vector2(sx * aspect, sy) * fit, yaw) - shift
				worst = maxf(worst, maxf(absf(p.x) / aspect, absf(p.y)))
		if worst <= 0.0001:
			break
		fit = minf(fit / worst, 1.0)
	shift = _warp_project(pivot * fit, yaw) - pivot
	return [fit, shift]

## --- 멈춤 ---

func _start_freeze() -> void:
	# 다른 연출이 느리게 해 둔 중이면(KO 슬로 등) 그쪽을 존중한다. 히트스톱(거의 0)과 앞 카운터의 슬로(내 값)는 이어받는다
	var ts: float = Engine.time_scale
	if ts < 0.99 and not _is_my_slow(ts) and ts > TIME_STOP * 2.0:
		_freezing = false
		return
	Engine.time_scale = SLOW_SCALE
	_freezing = true

## 지금 배속이 내가 건 슬로인가
func _is_my_slow(ts: float) -> bool:
	return absf(ts - SLOW_SCALE) < 0.001

func _update_freeze(t: float) -> void:
	if not _freezing:
		return
	if t < FREEZE_TIME:
		var ts: float = Engine.time_scale
		# 히트스톱 타이머가 끝나 1로 되돌렸으면 다시 느리게. 히트스톱(거의 0) 중이면 그대로 둔다.
		# 그 밖의 값(KO 슬로 등)이 들어왔으면 손을 뗀다
		if ts >= 0.99:
			Engine.time_scale = SLOW_SCALE
		elif not _is_my_slow(ts) and ts > TIME_STOP * 2.0:
			_freezing = false
		return
	_release_freeze()

func _release_freeze() -> void:
	if _freezing and _is_my_slow(Engine.time_scale):
		Engine.time_scale = 1.0
	_freezing = false

## --- 흐림 + 캐릭터 띄우기 ---

func _update_blur(t: float) -> void:
	var s: float
	if t < BLUR_IN:
		s = t / BLUR_IN
	elif t < BLUR_IN + BLUR_HOLD:
		s = 1.0
	else:
		s = 1.0 - (t - BLUR_IN - BLUR_HOLD) / BLUR_OUT
	modulate.a = clampf(s, 0.0, 1.0)
	if modulate.a <= 0.0:
		_unfocus_fighters()

## 캐릭터를 흐림 판 위로 올린다. 이미 올려 둔 캐릭터는 원래 값을 덮어쓰지 않는다
func _focus_fighters() -> void:
	for f in get_tree().get_nodes_in_group("fighters"):
		if not (f is CanvasItem) or not is_instance_valid(f) or _focused.has(f):
			continue
		_focused[f] = [f.z_index, f.z_as_relative]
		f.z_as_relative = false
		f.z_index = FOCUS_Z

## 원래 z로 되돌린다. 그 사이 다른 스크립트가 z를 바꿨으면(우리 값이 아니면) 그쪽을 존중한다
func _unfocus_fighters() -> void:
	for f in _focused:
		if not is_instance_valid(f):
			continue
		if f.z_index == FOCUS_Z and not f.z_as_relative:
			f.z_index = _focused[f][0]
			f.z_as_relative = _focused[f][1]
	_focused.clear()

## ScreenGrade와 같은 방식 — 카메라가 비추는 범위를 덮는 사각형을 카메라 중심에 둔다
func _follow_camera() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var half: Vector2 = get_viewport_rect().size / cam.zoom * (0.5 * OVERSIZE)
	global_position = cam.get_screen_center_position()
	# 카메라가 기울면(카운터 히트 줌) 같이 기운다 — 안 그러면 기운 화면 모서리가 덮이지 않는다
	global_rotation = 0.0 if cam.ignore_rotation else cam.global_rotation
	if half.distance_squared_to(_half) > 0.25:
		_half = half
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-_half, _half * 2.0), Color.WHITE)

## --- 글자 ---

## world_pos(월드 좌표)를 화면 좌표로 바꿔 그 자리에 글자를 띄운다. 화면 밖으로 안 나가게 가장자리에서 자른다
func _show_text(world_pos: Vector2) -> void:
	_label.reset_size()
	var size: Vector2 = _label.get_combined_minimum_size()
	_label.size = size
	_label.pivot_offset = size * 0.5
	_text_world = world_pos
	_place_text()
	_label.modulate.a = 1.0
	_label.scale = Vector2.ONE * 1.6
	_label.visible = true

## 글자 자리를 다시 잡는다 — **매 프레임**. 카메라가 줌·기울기로 움직이니 처음 화면 자리에 두면 맞은 쪽에서 떨어져 보였다
func _place_text() -> void:
	var size: Vector2 = _label.size
	var screen: Vector2 = get_viewport().get_canvas_transform() * _text_world
	var view: Vector2 = get_viewport_rect().size
	screen.x = clampf(screen.x, size.x * 0.5 + TEXT_MARGIN, view.x - size.x * 0.5 - TEXT_MARGIN)
	screen.y = clampf(screen.y, size.y * 0.5 + TEXT_MARGIN, view.y - size.y * 0.5 - TEXT_MARGIN)
	_label_base = screen - size * 0.5
	_label.position = _label_base

## 크게 튀어나왔다가(TEXT_POP) 제 크기로 → 끝에 위로 떠오르며 사라진다
func _update_text(t: float) -> void:
	if not _label.visible:
		return
	_place_text()
	if t < TEXT_POP:
		var k: float = t / TEXT_POP
		_label.scale = Vector2.ONE * lerpf(1.6, 1.0, 1.0 - (1.0 - k) * (1.0 - k))
	else:
		_label.scale = Vector2.ONE
	var fade_from: float = TEXT_TIME - TEXT_FADE
	if t > fade_from:
		var f: float = clampf((t - fade_from) / TEXT_FADE, 0.0, 1.0)
		_label.modulate.a = 1.0 - f
		_label.position = _label_base - Vector2(0.0, TEXT_RISE * f)
	if t >= TEXT_TIME:
		_label.visible = false

func _finish() -> void:
	_running = false
	if _warp != null and is_instance_valid(_warp):
		_warp.visible = false
	_release_freeze()
	_unfocus_fighters()
	modulate.a = 0.0
	visible = false
	_label.visible = false
	set_process(false)

func _exit_tree() -> void:
	# 연출 도중 라운드가 바뀌거나 나가도 시간이 멈춘 채·캐릭터가 위로 뜬 채 남지 않게
	_release_freeze()
	_unfocus_fighters()
	if _warp != null and is_instance_valid(_warp):
		_warp.queue_free()
