class_name CameraRig
extends Camera2D

## 두 파이터의 중간 지점을 부드럽게 따라가는 카메라.
## 맵에 LeftWall/RightWall이 있으면 그 바깥면을 카메라 한계선으로 잡아, 벽 너머(배경 끝, 빈 공간)가
## 화면에 들어오지 않게 한다
@export var follow_speed: float = 4.0
@export var min_y: float = 100.0
@export var max_y: float = 250.0
## 켜면 화면 아래로 보이는 흙(지면 아래) 두께를 **배율과 상관없이** ground_margin_px로 고정한다.
## 끄면(기본) 예전처럼 min_y/max_y만 본다 — 이 스크립트를 쓰는 다른 맵들은 그대로다.
## 넓은 맵(놀이터)은 캐릭터가 멀어지면 화면을 0.65배까지 물리는데, max_y가 고정값이면
## 물릴수록 화면 반 높이가 월드에서 길어져서 아래 흙이 100px에서 190px까지 두꺼워진다
@export var lock_ground_to_bottom: bool = false
## 지면 윗면 y (lock_ground_to_bottom일 때만 쓴다)
@export var ground_y: float = 280.0
## 지면 아래로 화면에 남겨둘 흙 두께(화면 px, lock_ground_to_bottom일 때만 쓴다)
@export var ground_margin_px: float = 56.0
## 벽 바깥이 안 보이도록 카메라 이동 범위를 제한할지. 벽이 없는 링아웃형 맵에서는 꺼도 된다
@export var clamp_to_walls: bool = true
## 한계선을 벽 바깥면에서 더 안쪽으로 당기고 싶을 때 쓰는 여유 폭(px)
@export var wall_margin: float = 0.0
## 1.0이면 벽 사이가 화면에 딱 맞아서(= 벽 밖이 절대 안 보이는 최소 배율) 카메라가 좌우로 전혀 안 움직인다.
## 1보다 키우면 그만큼 더 확대되는 대신 좌우로 따라다닐 여유가 생긴다 (1.1이면 벽 사이 폭의 약 9%)
@export_range(1.0, 2.0, 0.01) var extra_zoom: float = 1.0
## 두 캐릭터 사이가 벌어지면 화면을 물리고, 붙으면 당길지.
## 단 물러날 수 있는 한계는 "벽 밖이 안 보이는 배율"까지다 (_min_zoom)
@export var dynamic_zoom: bool = true
## 두 캐릭터 바깥으로 남겨둘 여유(px). 캐릭터가 화면 가장자리에 딱 붙지 않게 한다
@export var zoom_margin: Vector2 = Vector2(240.0, 170.0)
## 붙어 있을 때 기본 배율의 몇 배까지 당길지. 1.0(기본)이면 당기지 않고 멀어질 때 물러나기만 한다.
## 벽 사이가 화면보다 좁아서 애초에 물러날 여지가 없는 맵(지하철 승강장)에서만 1보다 크게 줘서
## "붙으면 당겼다가 멀어지면 원위치"로 만든다 — 넓은 맵에서 이 값을 올리면 지면이 화면 밖으로 밀려난다
@export_range(1.0, 3.0, 0.05) var max_close_zoom: float = 1.0
## 배율이 목표값을 따라가는 속도 (클수록 빠르다)
@export var zoom_speed: float = 3.0
## 흔들림이 초당 이만큼 잦아든다 (클수록 빨리 멈춘다)
@export var shake_decay: float = 3.0
## 흔들림이 최대(trauma 1.0)일 때 화면이 흔들리는 폭(px)
@export var shake_max_offset: float = 12.0

## **화면 픽셀이 게임 기준(1280x720)보다 몇 배 큰지** — 시야를 뷰포트 픽셀로 계산하므로, 기준보다 큰 뷰포트에 그릴 땐
## 이 배율만큼 당겨야 같은 구도가 된다. 평소 대전은 창 늘이기(canvas_items)가 알아서 해 줘서 1. 타이틀 뒤 게임(창 해상도로 그림)만 바꾼다
static var view_scale: float = 1.0
## 모든 배율에 더 곱하는 당김 — 타이틀 뒤 싸움을 실제 대전보다 가까이 찍을 때(1.5). 평소 1.
## static이라 쓰는 쪽(TitleScreen)이 끝날 때 반드시 1로 되돌릴 것
static var zoom_boost: float = 1.0

## 현재 흔들림 세기 0~1 — 타격이 들어오면 데미지에 비례해 쌓이고, 매 프레임 감쇠한다
var _trauma: float = 0.0
## --- 잠깐 다가가기(focus_on) ---
var _focus_target: Node2D = null
var _focus_left: float = 0.0
var _focus_total: float = 0.0
var _focus_blend: float = 0.12
var _focus_zoom_mul: float = 1.0
var _focus_base_zoom: float = 1.0
## 씬에 저장돼 있던 원래 배율
var _authored_zoom: float = 1.0
## **흐르기(팬)** — 0보다 크면 캐릭터를 따라가지 않고 맵 왼쪽 끝에서 오른쪽 끝까지 이 시간(초) 동안 천천히 흐른다.
## 타이틀 뒤 싸움 장면이 쓴다(start_pan). 평소 대전은 0이라 예전처럼 따라간다
var pan_time: float = 0.0
var _pan_t: float = 0.0
## 흐르기를 전체 거리의 몇 %에서 끝낼지(1이면 오른쪽 끝까지)
var _pan_end: float = 1.0
## 흐를 거리가 이보다 짧은 좁은 맵이면 흐르지 않고 가운데서 _pan_hold초 보여 주고 끝낸다
var _pan_min_range: float = 120.0
var _pan_hold: float = 8.0
var _pan_static: bool = false
## 흐르는 동안의 카메라 높이 — 바닥선이 화면 맨 아래 근처(_pan_bottom_px)에 오고 나머지는 전부 위쪽이 보이게(start_pan이 정한다)
var _pan_y: float = 0.0
## 흐를 때 바닥선 아래로 남겨 둘 두께(게임 기준 화면 px)
var _pan_bottom_px: float = 36.0
## 벽 한계선이 없는 맵에서 흐를 때 기준으로 삼는 처음 x
var _pan_origin_x: float = 0.0

## 가장 많이 물러날 수 있는 배율. 이보다 작아지면(= 더 넓게 보면) 벽 밖이 화면에 들어온다.
## 벽 사이가 화면보다 넓은 맵(놀이터)에서는 1.0보다 작아지고, 좁은 맵에서는 1.0보다 커진다
var _min_zoom: float = 1.0
## 두 캐릭터가 붙어 있을 때 가장 많이 당기는 배율
var _max_zoom: float = 1.0
## 다른 장소(황근출 궁극기 내무반)로 잠깐 옮겨 찍는 중인지 — 그동안은 벽 한계선 재계산을 안 한다
var _arena_active: bool = false
## 내무반 동안 위로 더 비추는 양(px)
var _arena_look_up: float = 0.0
## 장소 옮기기 전 값(돌아올 때 되돌림)
var _arena_saved: Dictionary = {}

func _ready() -> void:
	# 타격 판정(Hitbox)이 찾아서 흔들 수 있도록 그룹에 등록한다
	add_to_group("game_camera")
	_authored_zoom = zoom.x * view_scale * zoom_boost
	zoom = Vector2(_authored_zoom, _authored_zoom)
	_min_zoom = _authored_zoom
	_max_zoom = _authored_zoom * max_close_zoom
	if not clamp_to_walls:
		return
	_apply_wall_limits()
	# 창 크기가 바뀌면 보이는 폭도 바뀌므로(stretch aspect가 expand라서) 그때마다 다시 계산한다
	get_viewport().size_changed.connect(_apply_wall_limits)

func _process(delta: float) -> void:
	if pan_time > 0.0:
		_update_pan(delta)
		_apply_shake(delta)
		return
	# 한 대상에게 바짝 다가가는 중이면 평소 추적 대신 그쪽을 본다
	if _update_focus(delta):
		_apply_shake(delta)
		return
	var fighters := get_tree().get_nodes_in_group("fighters")
	if fighters.size() >= 2:
		var a: Vector2 = fighters[0].global_position
		var b: Vector2 = fighters[1].global_position
		global_position = global_position.lerp(_follow_aim(a, b), follow_speed * delta)
		_update_zoom(a, b, delta)
	_apply_shake(delta)

## 두 캐릭터를 따라갈 때 카메라가 향하는 자리 — 가운데에서 위로 올려 보는 만큼 빼고 높이 한계 안으로
func _follow_aim(a: Vector2, b: Vector2) -> Vector2:
	var mid: Vector2 = (a + b) / 2.0
	mid.y -= _arena_look_up
	mid.y = clampf(mid.y, min_y, _lowest_center_y())
	return mid

## 따라갈 자리로 **곧바로** 옮긴다 — 캐릭터가 순간이동했을 때(헬스장 층 넘나들기) 화면이 주욱 끌려가지 않게.
## 고정 카메라(follow_speed 0)는 원래 안 움직이니 건드리지 않는다
func snap_to_fighters() -> void:
	if follow_speed <= 0.0:
		return
	var fighters := get_tree().get_nodes_in_group("fighters")
	if fighters.size() >= 2:
		global_position = _follow_aim(fighters[0].global_position, fighters[1].global_position)

## **잠깐 한 대상에게 바짝 다가간다.** 궁 마무리처럼 한 순간을 크게 보여줄 때 쓴다.
## `duration`은 **실제 시간**이다 — 같이 쓰는 슬로우모션(Engine.time_scale)에 끌려 늘어나면
## 연출이 하염없이 길어진다. 들어가고 나오는 건 `blend`초에 걸쳐 부드럽게 섞인다
func focus_on(target: Node2D, zoom_mul: float = 1.6, duration: float = 0.45, blend: float = 0.12) -> void:
	if target == null or not is_instance_valid(target):
		return
	_focus_target = target
	_focus_zoom_mul = maxf(zoom_mul, 0.1)
	_focus_total = maxf(duration, 0.05)
	_focus_left = _focus_total
	_focus_blend = clampf(blend, 0.01, _focus_total * 0.5)
	_focus_base_zoom = zoom.x

## 다가가기를 진행한다. 지금 다가가는 중이면 true(그 프레임은 평소 추적을 건너뛴다)
func _update_focus(delta: float) -> bool:
	if _focus_left <= 0.0:
		return false
	# 실제 시간으로 센다 — 느려진 배속에 안 끌려간다
	_focus_left -= delta / maxf(Engine.time_scale, 0.01)
	if not is_instance_valid(_focus_target):
		_focus_left = 0.0
		return false
	var elapsed: float = _focus_total - _focus_left
	# 들어갈 때·나올 때만 섞고 가운데는 1.0으로 머문다
	var w: float = minf(elapsed / _focus_blend, minf(_focus_left / _focus_blend, 1.0))
	w = clampf(w, 0.0, 1.0)
	w = w * w * (3.0 - 2.0 * w)
	var aim: Vector2 = _focus_target.global_position
	aim.y = clampf(aim.y, min_y, _lowest_center_y())
	global_position = global_position.lerp(aim, clampf(follow_speed * 2.0 * delta, 0.0, 1.0))
	var want: float = lerpf(_focus_base_zoom, _focus_base_zoom * _focus_zoom_mul, w)
	zoom = Vector2(want, want)
	return _focus_left > 0.0

## 흐르기를 시작한다 — 지금 배율 그대로, 맵 왼쪽 끝에서 전체 거리의 end_ratio까지 duration초 동안.
## 흐를 거리가 min_range보다 짧은 좁은 맵이면 가운데 멈춘 채 hold초 보여 주고 끝낸다
func start_pan(duration: float, end_ratio: float = 1.0, min_range: float = 120.0, hold: float = 8.0) -> void:
	_pan_end = clampf(end_ratio, 0.0, 1.0)
	_pan_min_range = min_range
	_pan_hold = hold
	_pan_origin_x = global_position.x
	var span: Vector2 = _pan_span()
	_pan_static = span.y - span.x < _pan_min_range
	_pan_y = _pan_center_y()
	pan_time = maxf(_pan_hold if _pan_static else duration, 0.01)
	_pan_t = 0.0
	_update_pan(0.0)
	reset_smoothing()

## 흐를 때 카메라 중심 높이 — 맵 바닥(`Ground`) 윗면이 화면 맨 아래에서 _pan_bottom_px 위에 오게 해서
## 땅은 조금만, 위쪽(발판·배경)은 화면 높이만큼 다 보이게 한다(2026-09-28 사용자 요청 "땅이 너무 많이 보인다").
## 바닥을 못 찾으면 싸울 때와 같은 가장 아래 높이
func _pan_center_y() -> float:
	var ground: float = _ground_top()
	if is_nan(ground):
		return _lowest_center_y()
	var half_h: float = get_viewport_rect().size.y * 0.5 / maxf(zoom.y, 0.01)
	return ground + _pan_bottom_px * view_scale / maxf(zoom.y, 0.01) - half_h

## 맵의 `Ground`(바닥 StaticBody2D) 직사각형 충돌 윗면 y. 없으면 NAN
func _ground_top() -> float:
	var map: Node = get_parent()
	var ground: Node = map.get_node_or_null("Ground") if map else null
	if ground == null:
		return NAN
	for c in ground.get_children():
		var cs := c as CollisionShape2D
		if cs and cs.shape is RectangleShape2D:
			var size: Vector2 = (cs.shape as RectangleShape2D).size * cs.global_transform.get_scale().abs()
			return cs.global_position.y - size.y * 0.5
	return NAN

## 흐를 수 있는 카메라 중심 x 범위 (왼쪽, 오른쪽) — 화면 왼쪽 끝이 limit_left에 붙은 자리 ~ 오른쪽 끝이 limit_right에 붙은 자리.
## 벽 한계선이 없는 맵이면 처음 자리 기준 좌우 400px
func _pan_span() -> Vector2:
	var half_w: float = get_viewport_rect().size.x * 0.5 / maxf(zoom.x, 0.01)
	var left: float = _pan_origin_x - 400.0
	var right: float = _pan_origin_x + 400.0
	if limit_left > -1000000 and limit_right < 1000000:
		left = float(limit_left) + half_w
		right = float(limit_right) - half_w
	if right < left:
		left = (left + right) * 0.5
		right = left
	return Vector2(left, right)

## 흐르기가 오른쪽 끝에 닿았는지
func pan_finished() -> bool:
	return pan_time > 0.0 and _pan_t >= pan_time

## 흐르기 한 프레임 — 왼쪽 끝에서 전체 거리의 _pan_end까지. 좁은 맵이면 가운데 멈춰 있다.
## 높이는 싸울 때 카메라가 내려가는 가장 아래(바닥이 보이는 자리)
func _update_pan(delta: float) -> void:
	_pan_t = minf(_pan_t + delta, pan_time)
	var span: Vector2 = _pan_span()
	var x: float = (span.x + span.y) * 0.5
	if not _pan_static:
		var k: float = _pan_t / pan_time
		# 출발할 때만 살짝 느리게 — 도착 전에 다음 화면으로 넘어가므로 끝은 감속하지 않는다
		k = 1.0 - cos(k * PI * 0.5)
		x = lerpf(span.x, lerpf(span.x, span.y, _pan_end), k)
	global_position = Vector2(x, _pan_y)

## 카메라 중심이 내려갈 수 있는 가장 아래 y.
## lock_ground_to_bottom이면 "지면이 화면 아래에서 ground_margin_px 위에 오는 위치"를 **지금 배율로** 계산한다 —
## 배율이 작을수록(멀리 볼수록) 화면 반 높이가 월드에서 길어지므로 중심을 그만큼 더 올려야 한다.
## max_y는 여전히 넘지 않는다(가까이 당겼을 때 계산값이 max_y보다 아래로 가도 max_y에서 멈춤)
func _lowest_center_y() -> float:
	if not lock_ground_to_bottom:
		return max_y
	var half_h: float = get_viewport_rect().size.y * 0.5
	var y: float = ground_y - (half_h - ground_margin_px * view_scale) / maxf(zoom.y, 0.01)
	return clampf(y, min_y, max_y)

## 두 캐릭터가 다 들어오는 배율을 구해서 부드럽게 따라간다.
## _min_zoom(벽 밖이 안 보이는 한계 배율)보다 더 물러나지는 않는다 — 더 넓게 보면 벽 너머가 드러난다.
## 벽 사이가 화면보다 좁은 맵은 한계 배율이 1보다 커서 "붙었을 때 당겼다가 원래대로 돌아오는" 모양이 되고,
## 넓은 맵(놀이터)은 한계 배율이 1보다 작아서 실제로 뒤로 물러난다.
## 세로 간격(점프)도 같이 보므로 한쪽이 높이 뛰어도 프레임 밖으로 나가지 않는다
func _update_zoom(a: Vector2, b: Vector2, delta: float) -> void:
	if not dynamic_zoom:
		return
	var view: Vector2 = get_viewport_rect().size
	var needed: Vector2 = (a - b).abs() + zoom_margin * 2.0
	var fit: float = minf(view.x / maxf(needed.x, 1.0), view.y / maxf(needed.y, 1.0)) * zoom_boost
	var target: float = clampf(fit, _min_zoom, _max_zoom)
	var next: float = lerpf(zoom.x, target, clampf(zoom_speed * delta, 0.0, 1.0))
	zoom = Vector2(next, next)

## 타격 세기(trauma)를 더한다 — Hitbox가 명중 시 데미지에 비례해서 호출한다
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

## 계속되는 떨림(열차가 지나갈 때 등) — **이번 프레임에 유지할 세기(0~1)** 를 준다.
## `add_trauma`는 "한 방 맞았다"는 순간 충격이라, 매 프레임 조금씩 부어도 감쇠(초당 shake_decay=3)가
## 훨씬 커서 하나도 안 쌓인다. 지속되는 진동은 이 함수로 "바닥값"을 깔아줘야 한다
func set_rumble(amount: float) -> void:
	_trauma = maxf(_trauma, clampf(amount, 0.0, 1.0))

## 화면(offset)을 랜덤으로 흔들고 trauma를 서서히 줄인다. trauma가 0이면 offset을 원위치로 되돌린다
func _apply_shake(delta: float) -> void:
	if _trauma <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		return
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_max_offset * _trauma

## 좌우 벽의 바깥면을 찾아 카메라 한계선(limit_left/right)으로 설정한다.
## 벽 사이 폭이 화면 폭보다 좁으면 한계선만으로는 화면이 벽 밖을 물게 되므로,
## 벽 사이가 화면에 딱 맞을 만큼만 확대(zoom)해서 그 문제를 없앤다
func _apply_wall_limits() -> void:
	if _arena_active:
		return
	var left: float = _wall_edge("LeftWall", -1.0)
	var right: float = _wall_edge("RightWall", 1.0)
	if is_nan(left) or is_nan(right):
		return
	left += wall_margin
	right -= wall_margin
	var span: float = right - left
	if span <= 0.0:
		return
	var view_width: float = get_viewport_rect().size.x
	# 벽 사이가 화면에 꽉 차는 배율 = 벽 밖이 드러나기 직전, 즉 가장 많이 물러날 수 있는 한계
	_min_zoom = view_width / span * extra_zoom * zoom_boost
	# 당기는 상한은 씬에 저장된 배율과 한계 배율 중 큰 쪽을 기준으로 잡는다
	_max_zoom = maxf(_authored_zoom, _min_zoom) * max_close_zoom
	var clamped: float = clampf(zoom.x, _min_zoom, _max_zoom)
	zoom = Vector2(clamped, clamped)
	limit_left = int(floorf(left))
	limit_right = int(ceilf(right))

## 벽 StaticBody2D의 바깥쪽 면 x좌표를 돌려준다.
## dir이 -1이면 왼쪽 벽의 왼쪽 면, 1이면 오른쪽 벽의 오른쪽 면. 벽이 없으면 NAN
func _wall_edge(node_name: String, dir: float) -> float:
	var parent := get_parent()
	if parent == null:
		return NAN
	var wall := parent.get_node_or_null(node_name) as Node2D
	if wall == null:
		return NAN
	var half_width: float = 0.0
	for child in wall.get_children():
		var collision := child as CollisionShape2D
		if collision == null:
			continue
		var rect := collision.shape as RectangleShape2D
		if rect == null:
			continue
		half_width = maxf(half_width, rect.size.x * 0.5 * absf(collision.global_scale.x))
	return wall.global_position.x + dir * half_width

## 다른 장소로 잠깐 옮겨 찍는다(황근출 궁극기 내무반) — `area`(월드 좌표) 밖이 화면에 안 보이게 한계선·최소 배율을 바꾸고,
## 이전 값은 기억해 뒀다가 `leave_arena()`가 되돌린다. 옮긴 순간 따라가지 않고 바로 그 자리로 붙는다
## close_zoom > 0이면 가장 가까이 당기는 배율을 "방 전체가 보이는 배율 x close_zoom"으로 묶는다(작은 방에서 너무 붙지 않게)
## look_up: 두 캐릭터 가운데보다 이만큼(px) 위를 비춘다(내무반 동안만, leave_arena가 0으로)
func enter_arena(area: Rect2, look_at: Vector2, close_zoom: float = 0.0, look_up: float = 0.0) -> void:
	if not _arena_active:
		_arena_saved = {
			"limits": [limit_left, limit_top, limit_right, limit_bottom],
			"min_y": min_y, "max_y": max_y, "lock": lock_ground_to_bottom,
			"min_zoom": _min_zoom, "max_zoom": _max_zoom,
			"pos": global_position, "zoom": zoom,
		}
	_arena_active = true
	_arena_look_up = look_up
	limit_left = int(floorf(area.position.x))
	limit_top = int(floorf(area.position.y))
	limit_right = int(ceilf(area.end.x))
	limit_bottom = int(ceilf(area.end.y))
	min_y = area.position.y
	max_y = area.end.y
	lock_ground_to_bottom = false
	var view: Vector2 = get_viewport_rect().size
	_min_zoom = maxf(view.x / area.size.x, view.y / area.size.y) * zoom_boost
	_max_zoom = maxf(_authored_zoom, _min_zoom) * max_close_zoom
	if close_zoom > 0.0:
		_max_zoom = _min_zoom * maxf(close_zoom, 1.0)
	var z: float = clampf(zoom.x, _min_zoom, _max_zoom)
	zoom = Vector2(z, z)
	global_position = look_at
	reset_smoothing()

## enter_arena() 전 상태로 되돌리고 `look_at`으로 바로 붙는다
func leave_arena(look_at: Vector2) -> void:
	if not _arena_active:
		return
	_arena_active = false
	_arena_look_up = 0.0
	var l: Array = _arena_saved["limits"]
	limit_left = l[0]
	limit_top = l[1]
	limit_right = l[2]
	limit_bottom = l[3]
	min_y = _arena_saved["min_y"]
	max_y = _arena_saved["max_y"]
	lock_ground_to_bottom = _arena_saved["lock"]
	_min_zoom = _arena_saved["min_zoom"]
	_max_zoom = _arena_saved["max_zoom"]
	var z: float = clampf(zoom.x, _min_zoom, _max_zoom)
	zoom = Vector2(z, z)
	global_position = Vector2(look_at.x, clampf(look_at.y, min_y, _lowest_center_y()))
	reset_smoothing()
	if clamp_to_walls:
		_apply_wall_limits()
