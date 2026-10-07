class_name BarracksUltimate
extends Skill

## 황근출 해병 궁극기(R, 2026-10-02) — 화면이 잠깐 어두워졌다 밝아지면 두 캐릭터가 **내무반**(`군대 집.webp`)으로 끌려가
## `duration`초 동안 거기서 싸운 뒤 원래 맵의 원래 자리로 돌아온다.
## 내무반은 맵 위 멀리(`arena_offset`)에 그때그때 만들어 붙이고(바닥·벽 충돌 + 배경 그림), 그동안 원래 맵의 그림은 숨긴다.
## 카메라는 `CameraRig.enter_arena()`/`leave_arena()`로 내무반 그림 밖이 안 보이게 묶는다

@export var background: Texture2D = preload("res://sprite/황근출 해병/궁극기/군대 집.webp")
## 내무반에 머무는 시간(초)
@export var duration: float = 15.0
## 배경 그림 배율 — 0.75면 1536x1024 그림이 1152x768이 된다(벽 사이 ≈ 1110). 작을수록 카메라가 당겨져 캐릭터가 크게 보인다
@export var image_scale: float = 0.75
## 그림에서 발이 닿는 높이(그림 픽셀) — 마룻바닥(630~1024)의 가운데쯤
@export var floor_image_y: float = 790.0
## 그림에서 천장 높이(그림 픽셀) — 형광등 아래쪽 끝쯤. 이 위로는 못 올라간다(머리가 여기 닿음)
@export var ceiling_image_y: float = 85.0
## 원래 맵 원점에서 내무반 그림 가운데까지 — 위로 멀리 둬서 원래 맵(낙사 구조 높이·기믹)과 안 겹치게
@export var arena_offset: Vector2 = Vector2(0, -6000)
## 그림 좌우 끝에서 벽 안쪽 면까지(px)
@export var wall_inset: float = 20.0
## 들어갈 때 두 캐릭터가 가운데서 떨어져 서는 거리(px)
@export var spawn_spread: float = 300.0
## 어두워지는/밝아지는 시간(초)
@export var fade_time: float = 0.25
## 내무반에서 카메라가 가장 가까이 당기는 배율 — 방 전체가 보이는 배율의 몇 배까지(1이면 안 당김)
@export var arena_close_zoom: float = 1.2
## 내무반에서 카메라가 두 캐릭터 가운데보다 이만큼(px) 위를 본다 — 바닥만 꽉 차지 않고 위(창문·천장)가 보이게
@export var arena_look_up: float = 120.0
## 내무반에 있는 동안 스킬2 자리에 끼울 시전자의 자식 스킬 노드 이름(없으면 안 바꿈)
@export var arena_skill_2_name: String = "BarracksSkill2"

@export_group("옷 벗기")
## 궁을 쓰면 먼저 웃통을 벗어 던진다 — 벗은 몸 그림·배율·제자리(맨몸 리그 `HwanggeunchulRig.tscn`의 Body 값)
@export var bare_body_texture: Texture2D
@export var bare_body_scale: Vector2 = Vector2(0.0262, 0.0299)
@export var bare_body_position: Vector2 = Vector2(0.72, 1.46)
@export var bare_body_turn_textures: Array[Texture2D] = []
## 벗어 던지고 암전이 시작되기까지(초) — 그동안 다른 행동 못 함
@export var strip_time: float = 0.6
## 던진 옷이 날아가는 거리(위, 뒤)와 도는 양(라디안), 사라지는 시간(초)
@export var shirt_throw: Vector2 = Vector2(-70, -110)
@export var shirt_spin: float = 5.0
@export var shirt_life: float = 0.9
## 내무반에서 돌아올 때 다시 옷을 입을지
@export var redress_on_return: bool = true

@export_group("나타나기")
## 원래 맵이 깨져 떨어진 뒤 까만 화면에서 내무반 배경이 다 나타나는 시간(초)
@export var reveal_bg_time: float = 0.7
## 두 캐릭터가 나타나기 시작하는 때(배경 시작 기준, 초)와 다 나타나는 데 걸리는 시간(초)
@export var reveal_fighter_delay: float = 0.4
@export var reveal_fighter_time: float = 0.5

const SCREEN_SHATTER := preload("res://combat/ScreenShatter.gd")
const FOREGROUND := preload("res://maps/BarracksForeground.gd")
const WINDOWS := preload("res://maps/BarracksWindows.gd")

var _arena: Node2D
var _bg: Sprite2D
## 앞 층(침대·관물대 뒷모습, maps/BarracksForeground.gd)
var _fg: Node2D
## 화면 깨지기 연출(진입 중에만 있음)
var _shatter = null   # 타입 안 붙임 — ScreenShatter는 class_name이 없어 CanvasLayer로 받으면 start()를 못 찾는다
var _fade: ColorRect
## 숨긴 원래 맵 그림들(돌아올 때 다시 켬)
var _hidden: Array = []
## 내무반 동안 멈춰 둔 원래 맵 노드 → 원래 process_mode
var _frozen: Dictionary = {}
## CameraRig가 아닌 평범한 Camera2D(훈련장)를 내무반으로 옮겼을 때 되돌릴 값
var _plain_cam_saved: Dictionary = {}
## 끌려가기 전 자리 {Fighter: Vector2}
var _return_pos: Dictionary = {}

var _caster: Fighter
## 벗기 전 몸통(돌아올 때 다시 입힘)
var _saved_outfit: Dictionary = {}
## 내무반 동안 빼 둔 원래 스킬2
var _saved_skill_2: Skill = null
var _swapped_skill_2: bool = false

## 궁이 도는 동안(쓴 순간 ~ 원래 맵으로 돌아올 때)인지
var _running: bool = false

## 도는 동안엔 다시 못 쓴다 — 쿨이 0인 훈련장에서 내무반 안에서 또 누르면 컷인만 다시 나오고 꼬였다
func can_use() -> bool:
	return super() and not _running

func _execute(fighter: Fighter) -> void:
	if _running or is_instance_valid(_arena) or is_instance_valid(_shatter):
		return
	var host: Node = DomainClash.running_enemy(get_tree(), fighter)
	if host != null:
		_fight_for_domain(host, fighter)
		return
	_begin(fighter)

## **남의 영역 안에서 궁을 눌렀다** — 영역을 걸고 한 판 붙는다(`DomainClash`).
## 이기면 그 영역을 깨고 내 영역이 전개되고, 지면 내 궁만 날아간다(쿨타임은 이미 `Skill.use`가 먹였다)
func _fight_for_domain(host: Node, fighter: Fighter) -> void:
	var won: bool = await DomainClash.fight(host, fighter)
	if not won:
		return
	if is_instance_valid(host):
		host.break_domain()
	if is_instance_valid(fighter):
		_begin(fighter)

## 영역 주인
func domain_owner() -> Fighter:
	return _caster

## **영역 싸움에서 져서 영역이 깨진다** — 나오는 연출(화면 깨짐) 없이 바로 걷어낸다.
## 곧바로 이긴 쪽의 궁 연출이 이어지기 때문이다
func break_domain() -> void:
	if _running:
		_leave(false)

## 실제로 내무반을 펴는 곳 — 영역 싸움을 거치든 안 거치든 여기로 모인다
func _begin(fighter: Fighter) -> void:
	_running = true
	add_to_group(DomainClash.GROUP)
	_caster = fighter
	_seal_opponents(true)
	var delay: float = strip_time if bare_body_texture != null and _strip(fighter) else 0.0
	_lock_fighters(delay + 2.5)
	Timers.after(self, delay, func(): _break_screen(fighter, func(reveal: bool): _enter(fighter, reveal)))

## 지금 화면이 금 가며 깨져 떨어진다 → 까매지면 then(true). 화면을 못 찍으면(헤드리스 등) 그냥 암전 후 then(false).
## 내무반에 들어갈 때와 나올 때 둘 다 쓴다
func _break_screen(fighter: Fighter, then: Callable) -> void:
	var map: Node = fighter.get_parent()
	if map == null:
		return
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_fade_to_black(map, then.bind(false))
		return
	_shatter = SCREEN_SHATTER.new()
	map.add_child(_shatter)
	_shatter.shattered.connect(then.bind(true))
	_shatter.start(ImageTexture.create_from_image(img), fighter.get_global_transform_with_canvas().origin)
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.5)

## 깨지는 연출 ~ 다시 나타날 때까지 둘 다 무적·행동 불가(깨지는 화면 뒤에서 맞거나 스킬이 나가지 않게)
func _lock_fighters(time: float) -> void:
	for f in _fighters():
		f.start_busy(time)
		f.grant_invincibility(time)

## 웃통 벗기 — 입고 있던 몸통 그림을 떼어 뒤쪽 위로 빙글빙글 던지고, 몸은 맨몸으로 갈아입힌다. 벗었으면 true
func _strip(fighter: Fighter) -> bool:
	var visual := fighter.get_node_or_null("Visual")
	var body := fighter.get_node_or_null("Visual/Body") as Sprite2D
	if visual == null or body == null or not visual.has_method("set_body_outfit"):
		return false
	_saved_outfit = visual.get_body_outfit()
	var map: Node = fighter.get_parent()
	if map:
		var shirt := Sprite2D.new()
		shirt.texture = body.texture
		map.add_child(shirt)
		shirt.global_transform = body.global_transform
		shirt.z_index = 5
		var dir: float = signf(fighter.facing) if not is_zero_approx(fighter.facing) else 1.0
		var end_pos: Vector2 = shirt.global_position + Vector2(shirt_throw.x * dir, shirt_throw.y)
		var tw := shirt.create_tween().set_parallel(true)
		tw.tween_property(shirt, "global_position:x", end_pos.x, shirt_life)
		tw.tween_property(shirt, "global_position:y", end_pos.y, shirt_life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(shirt, "rotation", shirt.rotation - shirt_spin * dir, shirt_life)
		tw.tween_property(shirt, "modulate:a", 0.0, shirt_life * 0.4).set_delay(shirt_life * 0.6)
		tw.chain().tween_callback(shirt.queue_free)
	visual.set_body_outfit({"texture": bare_body_texture, "scale": bare_body_scale, "position": bare_body_position, "turn": bare_body_turn_textures})
	if visual.has_method("play_squash"):
		visual.play_squash(Vector2(1.12, 0.9))
	return true

## 내무반으로 옮긴다. reveal이면 까만 화면에서 배경이 서서히 나타나고 두 캐릭터가 양쪽에서 서서히 나타난다(아니면 암전 풀기)
func _enter(fighter: Fighter, reveal: bool) -> void:
	var map: Node = fighter.get_parent()
	if map == null:
		return
	_build_arena(map)
	_hide_map(map)
	var fighters: Array = _fighters()
	fighters.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var feet_y: float = _floor_y()
	_return_pos.clear()
	for i in fighters.size():
		var f: Fighter = fighters[i]
		_return_pos[f] = f.global_position
		var side: float = -1.0 if i == 0 else 1.0
		_place(f, Vector2(_arena.global_position.x + side * spawn_spread, feet_y - 30.0))
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("enter_arena"):
		cam.enter_arena(_arena_rect(), Vector2(_arena.global_position.x, feet_y - 150.0), arena_close_zoom, arena_look_up)
	else:
		_enter_plain_camera(Vector2(_arena.global_position.x, feet_y - 150.0))
	_set_eye_glow(true)
	_swap_skill_2(true)
	var shown_after: float = fade_time
	if reveal:
		shown_after = _reveal(map, fighters)
	else:
		_fade_from_black()
	Timers.after(self, shown_after + duration, func(): _start_leave(fighter))

## 깨진 화면(검정)을 걷고, 맵 뒤에 검은 판을 깐 채 내무반 배경 → 두 캐릭터 순으로 투명도를 올린다. 다 나타날 때까지 걸리는 시간을 돌려준다
func _reveal(map: Node, fighters: Array) -> float:
	var backdrop := CanvasLayer.new()
	backdrop.layer = -100
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(black)
	map.add_child(backdrop)
	_bg.modulate.a = 0.0
	if is_instance_valid(_fg):
		_fg.modulate.a = 0.0
	for f in fighters:
		f.modulate.a = 0.0
	if is_instance_valid(_shatter):
		_shatter.queue_free()
	_shatter = null
	var tw := _bg.create_tween()
	tw.tween_property(_bg, "modulate:a", 1.0, reveal_bg_time)
	if is_instance_valid(_fg):
		_fg.create_tween().tween_property(_fg, "modulate:a", 1.0, reveal_bg_time)
	tw.tween_callback(backdrop.queue_free)
	for f in fighters:
		var ft := (f as Node).create_tween()
		ft.tween_interval(reveal_fighter_delay)
		ft.tween_property(f, "modulate:a", 1.0, reveal_fighter_time)
	return maxf(reveal_bg_time, reveal_fighter_delay + reveal_fighter_time)

## 시간이 다 됐다 — 내무반 화면이 깨져 떨어지고 원래 맵으로 돌아간다
func _start_leave(fighter: Fighter) -> void:
	if not is_instance_valid(fighter):
		fighter = _caster
	_lock_fighters(2.5)
	if is_instance_valid(fighter):
		_break_screen(fighter, _leave)
	else:
		_leave(false)

## 원래 맵으로 돌려놓는다. reveal이면 깨진 화면(검정)에서 원래 맵이 서서히 밝아지고 두 캐릭터가 서서히 나타난다(아니면 암전 풀기)
func _leave(reveal: bool) -> void:
	_running = false
	remove_from_group(DomainClash.GROUP)
	# 화면이 까만 동안 다시 옷을 입는다
	if redress_on_return and not _saved_outfit.is_empty() and is_instance_valid(_caster):
		var visual := _caster.get_node_or_null("Visual")
		if visual and visual.has_method("set_body_outfit"):
			visual.set_body_outfit(_saved_outfit)
	_saved_outfit = {}
	_set_eye_glow(false)
	_seal_opponents(false)
	_swap_skill_2(false)
	for f in _return_pos:
		if is_instance_valid(f):
			_place(f, _return_pos[f])
	var look: Vector2 = Vector2.ZERO
	for f in _return_pos:
		if is_instance_valid(f):
			look += _return_pos[f] / float(_return_pos.size())
	_return_pos.clear()
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()
	for n in _frozen:
		if is_instance_valid(n):
			n.process_mode = _frozen[n]
	_frozen.clear()
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("leave_arena"):
		cam.leave_arena(look)
	else:
		_leave_plain_camera()
	if is_instance_valid(_arena):
		_arena.queue_free()
	_arena = null
	if reveal:
		_reveal_map()
	else:
		_fade_from_black()

## 돌아올 때 — 맨 위에 깐 까만 판을 서서히 걷어 원래 맵을 드러내고(투명도가 올라가는 것처럼), 두 캐릭터는 조금 늦게 나타난다
func _reveal_map() -> void:
	var map: Node = _caster.get_parent() if is_instance_valid(_caster) else get_tree().current_scene
	_ensure_fade(map)
	_fade.color.a = 1.0
	if is_instance_valid(_shatter):
		_shatter.queue_free()
	_shatter = null
	var fighters: Array = _fighters()
	for f in fighters:
		f.modulate.a = 0.0
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 0.0, reveal_bg_time)
	for f in fighters:
		var ft := (f as Node).create_tween()
		ft.tween_interval(reveal_fighter_delay)
		ft.tween_property(f, "modulate:a", 1.0, reveal_fighter_time)

## 내무반 동안만 스킬2를 내무반 전용 기술로 바꾼다 — 들어갈 땐 바로 쓸 수 있게 쿨을 비우고, 나올 땐 하던 동작을 멈춘다
func _swap_skill_2(on: bool) -> void:
	if not is_instance_valid(_caster):
		_swapped_skill_2 = false
		return
	var arena_skill := _caster.get_node_or_null(arena_skill_2_name) as Skill
	if arena_skill == null:
		return
	if on and not _swapped_skill_2:
		arena_skill.cooldown_left = 0.0
		_saved_skill_2 = _caster.swap_skill_2(arena_skill)
		_swapped_skill_2 = true
	elif not on and _swapped_skill_2:
		if arena_skill.has_method("abort"):
			arena_skill.abort()
		_caster.swap_skill_2(_saved_skill_2)
		_saved_skill_2 = null
		_swapped_skill_2 = false

## 궁이 도는 동안(옷 벗기부터 돌아올 때까지) 상대는 궁극기를 못 쓴다
func _seal_opponents(on: bool) -> void:
	for f in _fighters():
		if f == _caster:
			continue
		if on:
			# ⚠️ **영역 궁은 안 막는다** — 갇힌 쪽이 영역 싸움을 걸 수 있어야 한다(2026-10-07)
			if DomainClash.is_domain(f.skill_ultimate):
				continue
			f.seal_ultimate(&"barracks")
		else:
			f.unseal_ultimate(&"barracks")

func _fighters() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("fighters"):
		if n is Fighter:
			out.append(n)
	return out

## 순간이동 — 날아가던 중이면 끝내고 속도를 지운다
func _place(f: Fighter, pos: Vector2) -> void:
	f.cancel_finisher_flight()
	f.global_position = pos
	f.velocity = Vector2.ZERO
	f.reset_physics_interpolation()

## 배경 그림 + 바닥·좌우 벽 충돌
func _build_arena(map: Node) -> void:
	_arena = Node2D.new()
	_arena.name = "BarracksArena"
	_arena.position = arena_offset
	map.add_child(_arena)
	var bg := Sprite2D.new()
	bg.texture = background
	bg.scale = Vector2(image_scale, image_scale)
	bg.z_index = -50
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_arena.add_child(bg)
	# 창문·창밖 풍경은 배경의 자식 — 배경 그림 좌표·배율·나타나는 투명도를 그대로 따라간다
	bg.add_child(WINDOWS.new())
	_bg = bg
	_fg = FOREGROUND.new()
	_fg.name = "Foreground"
	# 앞 층 크기·자리는 배율 0.75 기준 값이라 방 크기에 맞춰 같이 줄인다
	_fg.size_scale = image_scale / 0.75
	_arena.add_child(_fg)
	var half: Vector2 = background.get_size() * image_scale * 0.5
	var floor_local: float = (floor_image_y - background.get_size().y * 0.5) * image_scale
	_add_block("Ground", Vector2(0, floor_local + 100.0), Vector2(half.x * 2.0 + 400.0, 200.0))
	var wall_h: float = half.y * 6.0
	_add_block("LeftWall", Vector2(-half.x + wall_inset - 50.0, floor_local - wall_h * 0.5), Vector2(100, wall_h))
	_add_block("RightWall", Vector2(half.x - wall_inset + 50.0, floor_local - wall_h * 0.5), Vector2(100, wall_h))
	var ceiling_local: float = (ceiling_image_y - background.get_size().y * 0.5) * image_scale
	_add_block("Ceiling", Vector2(0, ceiling_local - 100.0), Vector2(half.x * 2.0 + 400.0, 200.0))

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

## 원래 맵 그림을 숨긴다 — 캐릭터·내무반은 빼고. 내무반이 화면을 다 덮지만 조명(CanvasModulate)·앞 층 장식이 위에 남아서
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
		# 숨기기만 하면 맵 기믹(지하철 열차 등)이 뒤에서 계속 돌아 카메라를 흔들고 소리를 낸다 — 내무반 동안은 통째로 멈춘다.
		# 카메라는 내무반을 비춰야 하므로 빼고, 멈춘 물리 바디는 충돌에서도 빠졌다가 돌아올 때 복귀한다
		if c.is_in_group("game_camera") or c is Camera2D:
			continue
		_frozen[c] = c.process_mode
		c.process_mode = Node.PROCESS_MODE_DISABLED

## CameraRig가 없는 맵(훈련장의 평범한 Camera2D) — 방 전체가 보이게 배율·한계선을 직접 맞춰 내무반으로 옮긴다
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

func _floor_y() -> float:
	return _arena.global_position.y + (floor_image_y - background.get_size().y * 0.5) * image_scale

func _arena_rect() -> Rect2:
	var size: Vector2 = background.get_size() * image_scale
	return Rect2(_arena.global_position - size * 0.5, size)

func _fade_to_black(map: Node, then: Callable) -> void:
	_ensure_fade(map)
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 1.0, fade_time)
	tw.tween_callback(then)

## 화면 전체를 덮는 까만 판(맨 위 층) — 없으면 투명하게 만든다
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

## 내무반에 있는 동안 황근출 눈에서 노란 빛 — 리그 머리의 `EyeGlow`(없으면 아무 일도 안 함)
func _set_eye_glow(on: bool) -> void:
	if not is_instance_valid(_caster):
		return
	var glow := _caster.get_node_or_null("Visual/Head/EyeGlow")
	if glow and glow.has_method("set_active"):
		glow.set_active(on)
