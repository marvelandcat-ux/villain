class_name FloorDomainUltimate
extends Skill

## **영역전개 — 윗집** (층간소음 빌런 궁극기, 2026-10-04 사용자 설계).
##
## 쓰면 화면이 잠깐 어두워졌다 밝아지면서 두 캐릭터가 **위아래 두 층짜리 집**(`층간소음영역전개.png`)으로
## 끌려간다. **위층은 무조건 층간소음 빌런**, 아래층은 상대다. `duration`초 뒤 원래 맵 원래 자리로 돌아온다.
##
## 위층에는 따로 누를 키가 없다 — **걷고, 뛰고, 아이를 풀어놓는 것**이 그대로 공격이 된다.
## 발이 바닥을 칠 때마다 아래로 부채꼴 충격파(`DomainShock`)가 내려가 아래층을 때린다.
## 걷기 충격파는 폭이 절반이라 얕게 긁고, 착지와 아이 쿵쿵은 넓게 때린다.
##
## 아래층 상대는 위로 못 올라온다(위층 바닥이 곧 천장이다). 그래서 **오래 끌면 안 된다** —
## duration을 길게 주면 일방적으로 두들기기만 하는 시간이 된다

## **맨 뒤 — 방 그림**(벽·문·창문·두 층 바닥). 소파와 책장 자리는 비어 있고 그 둘은 따로 올린다.
## 영역 크기·바닥 높이를 재는 기준도 이 그림이다
@export var background: Texture2D = preload("res://sprite/층간소음/궁극기맵/층간소음영역전개_0003_레이어-0.png")
## 방보다 앞 — 책장
@export var layer_shelf: Texture2D = preload("res://sprite/층간소음/궁극기맵/층간소음영역전개_0002_레이어-3.png")
## 책장보다 앞 — 소파
@export var layer_sofa: Texture2D = preload("res://sprite/층간소음/궁극기맵/층간소음영역전개_0001_레이어-2.png")
## **캐릭터보다 앞**에 깔 띠(위층 바닥 옆면). 비워 두면(기본) 안 쓴다 —
## 켜면 캐릭터 발이 바닥 턱 뒤로 들어가 더 깊어 보이지만, 발이 가려져서 쿵쿵이 잘 안 보인다
@export var layer_front: Texture2D = null
## **뒤쪽일수록 어둡게** 한다 — 멀리 있는 것이 어두워야 앞뒤가 갈린다(1이면 원래 밝기).
## 뒤에서부터 방 → 책장 → 소파 → 캐릭터 순으로 밝아진다
@export_range(0.3, 1.0, 0.01) var room_shade: float = 0.82
@export_range(0.3, 1.0, 0.01) var shelf_shade: float = 0.9
@export_range(0.3, 1.0, 0.01) var sofa_shade: float = 0.97
## 영역에 머무는 시간(초)
@export var duration: float = 12.0
## 배경 그림 배율 — 1942x809 그림이 0.55면 1068x445가 된다(화면 비율과 거의 같아 꽉 찬다)
@export var image_scale: float = 0.45
## 그림에서 **위층 바닥 윗면**(엄마 발이 닿는 높이, 그림 픽셀)
@export var upper_floor_image_y: float = 338.0
## 그림에서 **아래층 바닥 윗면**(상대 발이 닿는 높이, 그림 픽셀)
@export var lower_floor_image_y: float = 752.0
## 그림에서 위층 천장 높이(그림 픽셀) — 엄마가 이 위로는 못 뜬다
@export var ceiling_image_y: float = 14.0
## 원래 맵 원점에서 영역 가운데까지 — 위로 멀리 둬서 원래 맵 지형과 안 겹치게 한다
@export var arena_offset: Vector2 = Vector2(0, -7000)
## 그림 좌우 끝에서 벽 안쪽 면까지(px)
@export var wall_inset: float = 24.0
## 들어갈 때 두 사람이 가운데에서 좌우로 떨어져 서는 거리(px)
@export var spawn_spread: float = 160.0
## 어두워지는/밝아지는 시간(초)
@export var fade_time: float = 0.22
## 영역에서 카메라가 가장 가까이 당기는 배율 — 방 전체가 보이는 배율의 몇 배까지(1이면 안 당김).
## 두 층이 다 보여야 하는 영역이라 1로 묶어 둔다
@export var arena_close_zoom: float = 1.0

@export_group("충격파")
## 아래로 퍼지는 물결이 좌우로 벌어지는 각도(도, 한쪽).
## **보이는 폭이 곧 맞는 폭이다** — 맞는 반폭은 두 층 간격 x sin(이 각도)로 정해진다
@export var shock_spread_deg: float = 48.0
## 충격파가 **발바닥보다 얼마나 아래에서** 시작할지(px). 위층 바닥 두께만큼 내려 두면
## 바닥을 뚫고 나오는 것처럼 보인다 — 0이면 발바닥에서 바로 시작한다
@export var shock_drop: float = 18.0
## 걷는 중에 나가는 충격파는 이 비율만큼 좁다(사용자 설계: 절반)
@export_range(0.1, 1.0, 0.05) var walk_width_ratio: float = 0.5
## 걸을 때 한 걸음 간격(초)과 그 피해
@export var walk_interval: float = 0.34
@export var walk_damage: int = 2
## 뛰어서 착지할 때의 피해
@export var land_damage: int = 4
## 아이가 쿵쿵 디딜 때의 피해(2번 스킬이 영역 안에서는 이걸로 바뀐다)
@export var kid_damage: int = 5
## 충격파가 터질 때 화면이 흔들리는 정도(걷기는 이 값의 절반)
@export var shake: float = 0.18
## 맞은 쪽이 밀려나는 힘 — **세로는 0에 가깝게.** 띄우면 다음 충격파가 전부 빗나간다
@export var knockback: Vector2 = Vector2(0, -20)
## 캐릭터 원점에서 발바닥까지(px) — 충격파가 시작하는 높이
@export var foot_offset: float = 30.0

const SHOCK := preload("res://combat/DomainShock.gd")

## 궁이 도는 동안(쓴 순간 ~ 원래 맵으로 돌아올 때)인지
var _running: bool = false
var _arena: Node2D
var _bg: Sprite2D
var _fade: ColorRect
## 숨긴 원래 맵 그림들(돌아올 때 다시 켬)
var _hidden: Array = []
## 영역 동안 멈춰 둔 원래 맵 노드 → 원래 process_mode
var _frozen: Dictionary = {}
## 끌려가기 전 자리 {Fighter: Vector2}
var _return_pos: Dictionary = {}
var _caster: Fighter
## CameraRig가 아닌 평범한 Camera2D(훈련장)를 영역으로 옮겼을 때 되돌릴 값
var _plain_cam_saved: Dictionary = {}
## 남은 시간(HUD 타이머용)
var _left: float = 0.0
## 다음 걸음까지 남은 시간 / 지난 프레임에 바닥에 있었는지 / 어느 발 차례인지
var _walk_left: float = 0.0
var _was_floor: bool = true
var _left_foot: bool = true

## 도는 동안엔 다시 못 쓴다
func can_use() -> bool:
	return not _running and super.can_use()

## HUD에 남은 시간을 띄운다(지하철 아저씨·경찰 궁과 같은 방식)
func active_ratio() -> float:
	if not _running or duration <= 0.0:
		return -1.0
	return clampf(_left / duration, 0.0, 1.0)

func _execute(fighter: Fighter) -> void:
	if _running or not is_instance_valid(fighter) or background == null:
		return
	var map: Node = fighter.get_parent()
	if map == null:
		return
	_running = true
	_caster = fighter
	_fade_to_black(map, func(): _enter(fighter))

## 영역으로 옮긴다 — 엄마는 위층, 나머지는 아래층
func _enter(fighter: Fighter) -> void:
	if not is_instance_valid(fighter):
		return
	var map: Node = fighter.get_parent()
	if map == null:
		return
	_build_arena(map)
	_hide_map(map)
	_return_pos.clear()
	var side: float = 1.0
	for f in _fighters():
		_return_pos[f] = f.global_position
		if f == fighter:
			_place(f, Vector2(_arena.global_position.x - spawn_spread, _upper_y() - 20.0))
		else:
			_place(f, Vector2(_arena.global_position.x + spawn_spread * side, _lower_y() - 20.0))
			side = -side
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("enter_arena"):
		cam.enter_arena(_arena_rect(), _arena.global_position, arena_close_zoom, 0.0)
	else:
		# 훈련장처럼 평범한 Camera2D만 있는 맵 — 직접 옮겨 준다. 안 하면 카메라가 원래 맵에 남아
		# 멀리 떨어진 영역이 화면에 안 보인다(2026-10-04 훈련장에서 아무것도 안 나오던 원인)
		_enter_plain_camera(_arena.global_position)
	_set_domain_jump(true)
	_fade_from_black()
	_left = duration
	_walk_left = 0.0
	_was_floor = true
	Timers.after(self, duration, func(): _leave())

## 원래 맵으로 돌려놓는다
func _leave() -> void:
	if not _running:
		return
	_running = false
	_left = 0.0
	for f in _return_pos:
		if is_instance_valid(f):
			_place(f, _return_pos[f])
	var look: Vector2 = Vector2.ZERO
	var n: int = maxi(_return_pos.size(), 1)
	for f in _return_pos:
		if is_instance_valid(f):
			look += _return_pos[f] / float(n)
	_return_pos.clear()
	for node in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()
	for node in _frozen:
		if is_instance_valid(node):
			node.process_mode = _frozen[node]
	_frozen.clear()
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("leave_arena"):
		cam.leave_arena(look)
	else:
		_leave_plain_camera()
	_set_domain_jump(false)
	if is_instance_valid(_arena):
		_arena.queue_free()
	_arena = null
	_fade_from_black()

func _process(delta: float) -> void:
	super._process(delta)
	if not _running:
		return
	_left = maxf(_left - delta, 0.0)
	if is_instance_valid(_caster):
		_watch_feet(delta)

## 엄마의 발을 지켜본다 — 걸으면 한 걸음마다, 뛰어 내리면 착지하는 순간 충격파가 나간다
func _watch_feet(delta: float) -> void:
	var on_floor: bool = _caster.is_on_floor()
	if on_floor and not _was_floor:
		# 착지 — 두 발 가운데에서 넓게
		_shock(land_damage, 1.0, _feet_center())
		_walk_left = walk_interval
	elif on_floor and absf(_caster.velocity.x) > 20.0:
		_walk_left -= delta
		if _walk_left <= 0.0:
			# 걷기 — 디딘 발 자리에서 좁게. 한 발씩 번갈아 나간다
			_shock(walk_damage, walk_width_ratio, _foot_at(_left_foot))
			_left_foot = not _left_foot
			_walk_left = walk_interval
	elif on_floor:
		_walk_left = 0.0   # 멈춰 섰으면 다음 걸음은 디디자마자
	_was_floor = on_floor

## 아이가 바닥을 쿵 디뎠다 — 영역 안에서는 아이 충격파도 아래층으로 내려간다.
## 아이 쪽(`RunningKid`)이 자기 발 자리를 들고 불러 준다
func kid_stomp(at: Vector2) -> void:
	if not _running:
		return
	_shock(kid_damage, 1.0, at)

## 지금 영역 안인지 — 아이 쪽이 "쿵 효과를 바꿔야 하는지" 물어볼 때 쓴다
func is_active() -> bool:
	return _running

## 충격파 하나를 발 자리에 띄운다
func _shock(dmg: int, ratio: float, at: Vector2) -> void:
	if _arena == null or not is_instance_valid(_caster):
		return
	var fx := SHOCK.new()
	_arena.add_child(fx)
	fx.global_position = at + Vector2(0.0, shock_drop)
	fx.depth = maxf(_lower_y() - at.y - shock_drop, 20.0)
	fx.spread_deg = shock_spread_deg
	fx.width_ratio = ratio
	fx.damage = _caster.compute_damage(dmg)
	fx.knockback = knockback
	fx.caster = _caster
	var cam: Camera2D = _caster.get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(shake * (1.0 if ratio >= 0.99 else 0.5))

## 두 발 가운데 바닥 자리
func _feet_center() -> Vector2:
	return Vector2(_caster.global_position.x, _caster.global_position.y + foot_offset)

## 왼발/오른발 자리 — 몸(BodyRig)에 발 조각이 있으면 그 자리, 없으면 몸 가운데
func _foot_at(left: bool) -> Vector2:
	var visual: Node = _caster.get_node_or_null("Visual")
	if visual:
		var part_name: String = "FootL" if left else "FootR"
		var foot: Node2D = visual.get_node_or_null(part_name) as Node2D
		if foot:
			return Vector2(foot.global_position.x, _caster.global_position.y + foot_offset)
	return _feet_center()

func _fighters() -> Array:
	var out: Array = []
	for f in get_tree().get_nodes_in_group("fighters"):
		if f is Fighter and is_instance_valid(f):
			out.append(f)
	return out

## 영역 안에서만 쓰는 점프 자세를 켜고 끈다 — 그 기능이 없는 몸이면 그냥 넘어간다
func _set_domain_jump(on: bool) -> void:
	if not is_instance_valid(_caster):
		return
	var visual: Node = _caster.get_node_or_null("Visual")
	if visual and visual.has_method("set_domain_jump"):
		visual.set_domain_jump(on)

## 순간이동 — 날아가던 중이면 끝내고 속도를 지운다
func _place(f: Fighter, pos: Vector2) -> void:
	f.cancel_finisher_flight()
	f.global_position = pos
	f.velocity = Vector2.ZERO
	f.reset_physics_interpolation()

## 배경 그림 + 두 층 바닥·천장·좌우 벽
func _build_arena(map: Node) -> void:
	_arena = Node2D.new()
	_arena.name = "FloorDomainArena"
	_arena.position = arena_offset
	map.add_child(_arena)
	# 뒤에서부터 방 → 책장 → 소파 → (캐릭터) → 앞 띠 순으로 쌓는다.
	# 뒤로 갈수록 어둡게 깔아서 앞뒤 거리가 느껴지게 한다(2026-10-04 사용자 요청)
	_bg = _add_layer(background, -50, room_shade)
	_add_layer(layer_shelf, -40, shelf_shade)
	_add_layer(layer_sofa, -30, sofa_shade)
	_add_layer(layer_front, 10, 1.0)
	var half: Vector2 = background.get_size() * image_scale * 0.5
	var upper: float = _image_to_local(upper_floor_image_y)
	var lower: float = _image_to_local(lower_floor_image_y)
	var ceiling: float = _image_to_local(ceiling_image_y)
	# 위층 바닥 = 아래층 천장. 두 층 간격의 삼분의 일만큼 두껍게 깐다
	var slab: float = maxf((lower - upper) * 0.33, 20.0)
	_add_block("UpperFloor", Vector2(0, upper + slab * 0.5), Vector2(half.x * 2.0 + 400.0, slab))
	_add_block("LowerFloor", Vector2(0, lower + 100.0), Vector2(half.x * 2.0 + 400.0, 200.0))
	_add_block("Ceiling", Vector2(0, ceiling - 100.0), Vector2(half.x * 2.0 + 400.0, 200.0))
	var wall_h: float = (lower - ceiling) + 600.0
	var wall_y: float = (lower + ceiling) * 0.5
	_add_block("LeftWall", Vector2(-half.x + wall_inset - 50.0, wall_y), Vector2(100, wall_h))
	_add_block("RightWall", Vector2(half.x - wall_inset + 50.0, wall_y), Vector2(100, wall_h))

## 배경 층 하나를 깐다 — 그림이 비어 있으면 아무것도 안 만든다
func _add_layer(tex: Texture2D, z: int, shade: float) -> Sprite2D:
	if tex == null:
		return null
	var layer := Sprite2D.new()
	layer.texture = tex
	layer.scale = Vector2(image_scale, image_scale)
	layer.z_index = z
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.modulate = Color(shade, shade, shade, 1.0)
	_arena.add_child(layer)
	return layer

func _add_block(block_name: String, pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = block_name
	body.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	_arena.add_child(body)

## 원래 맵 그림을 숨기고 기믹을 멈춘다 — 캐릭터·영역·카메라는 빼고
func _hide_map(map: Node) -> void:
	_hidden.clear()
	_frozen.clear()
	for c in map.get_children():
		if c == _arena or c.is_in_group("fighters"):
			continue
		var should_hide: bool = c is CanvasItem or (c is CanvasLayer and String(c.name).begins_with("Deco"))
		if not should_hide:
			continue
		if c.visible:
			c.visible = false
			_hidden.append(c)
		if c.is_in_group("game_camera") or c is Camera2D:
			continue
		_frozen[c] = c.process_mode
		c.process_mode = Node.PROCESS_MODE_DISABLED

## CameraRig가 없는 맵(훈련장의 평범한 Camera2D) — 두 층이 다 보이게 배율·한계선을 직접 맞춰 영역으로 옮긴다
func _enter_plain_camera(look: Vector2) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	_plain_cam_saved = {"cam": cam, "pos": cam.global_position, "zoom": cam.zoom,
		"limits": [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]}
	var area: Rect2 = _arena_rect()
	var view: Vector2 = cam.get_viewport_rect().size
	var z: float = maxf(view.x / area.size.x, view.y / area.size.y)
	cam.zoom = Vector2(z, z)
	cam.limit_left = int(floorf(area.position.x))
	cam.limit_top = int(floorf(area.position.y))
	cam.limit_right = int(ceilf(area.end.x))
	cam.limit_bottom = int(ceilf(area.end.y))
	cam.global_position = look
	cam.reset_smoothing()

func _leave_plain_camera() -> void:
	if _plain_cam_saved.is_empty():
		return
	var cam: Camera2D = _plain_cam_saved["cam"]
	if is_instance_valid(cam):
		var l: Array = _plain_cam_saved["limits"]
		cam.limit_left = l[0]
		cam.limit_top = l[1]
		cam.limit_right = l[2]
		cam.limit_bottom = l[3]
		cam.zoom = _plain_cam_saved["zoom"]
		cam.global_position = _plain_cam_saved["pos"]
		cam.reset_smoothing()
	_plain_cam_saved = {}

## 그림 픽셀 높이를 영역 안 좌표로 바꾼다
func _image_to_local(image_y: float) -> float:
	return (image_y - background.get_size().y * 0.5) * image_scale

func _upper_y() -> float:
	return _arena.global_position.y + _image_to_local(upper_floor_image_y)

func _lower_y() -> float:
	return _arena.global_position.y + _image_to_local(lower_floor_image_y)

func _arena_rect() -> Rect2:
	var size: Vector2 = background.get_size() * image_scale
	return Rect2(_arena.global_position - size * 0.5, size)

func _fade_to_black(map: Node, then: Callable) -> void:
	_ensure_fade(map)
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 1.0, fade_time)
	tw.tween_callback(then)

## 화면 전체를 덮는 까만 판(맨 위 층)
func _ensure_fade(map: Node) -> void:
	if not is_instance_valid(_fade):
		var layer := CanvasLayer.new()
		layer.layer = 50
		map.add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0, 0, 0, 0)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_fade)

func _fade_from_black() -> void:
	if not is_instance_valid(_fade):
		return
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 0.0, fade_time)

## 라운드가 끝나는데 아직 영역 안이면 정리하고 나간다
func _exit_tree() -> void:
	if _running:
		_leave()
