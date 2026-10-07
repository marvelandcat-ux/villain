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
@export var background: Texture2D = preload("res://sprite/층간소음/궁극기맵/층간소음궁배경.png")
## **바닥·벽 자리를 눈으로 맞추는 씬**(`maps/FloorDomainLayout.tscn`).
## 그 씬에서 선을 끌어다 놓으면 아래 숫자 칸 대신 **그 자리**를 쓴다 — 숫자를 외울 필요가 없다.
## 비워 두면 아래 숫자 칸을 그대로 쓴다
@export var layout_scene: PackedScene = preload("res://maps/FloorDomainLayout.tscn")
## **영역에 들어가기 전에 차례로 나오는 연출들.**
## 1장 현관문 두드리기 → 2장 문 열고 빼꼼 → 3장 문 쾅. 앞 장면이 끝나야 다음 장면이 뜨고,
## 다 끝나면 암전 뒤 집으로 넘어간다. 비워 두면 연출 없이 바로 넘어간다
@export var intro_scenes: Array[PackedScene] = [
	preload("res://ui/FloorDomainIntro.tscn"),
	preload("res://ui/FloorDomainPeek.tscn"),
	preload("res://ui/FloorDomainSlam.tscn"),
]
## 방보다 앞에 올릴 것 — 예전 책장 레이어. **지금은 비워 둔다**(새 배경에는 가구가 없다).
## 가구를 다시 넣고 싶으면 여기에 그림을 물리면 방보다 앞·덜 흐리게 깔린다
@export var layer_shelf: Texture2D = null
## 책장보다 앞에 올릴 것 — 예전 소파 레이어. 마찬가지로 비워 둔다
@export var layer_sofa: Texture2D = null
## **캐릭터보다 앞**에 깔 띠(위층 바닥 옆면). 비워 두면(기본) 안 쓴다 —
## 켜면 캐릭터 발이 바닥 턱 뒤로 들어가 더 깊어 보이지만, 발이 가려져서 쿵쿵이 잘 안 보인다
@export var layer_front: Texture2D = null
## **뒤쪽일수록 어둡게** 한다 — 멀리 있는 것이 어두워야 앞뒤가 갈린다(1이면 원래 밝기).
## 뒤에서부터 방 → 책장 → 소파 → 캐릭터 순으로 밝아진다
@export_range(0.3, 1.0, 0.01) var room_shade: float = 0.82
@export_range(0.3, 1.0, 0.01) var shelf_shade: float = 0.9
@export_range(0.3, 1.0, 0.01) var sofa_shade: float = 0.97
## **뒤쪽일수록 흐리게** 한다(px) — 지하철 맵 먼 배경과 같은 셰이더다. 0이면 또렷하게 그대로 둔다.
## 명암만으로는 티가 잘 안 나서 같이 쓴다(2026-10-04 사용자 요청)
@export_range(0.0, 8.0, 0.1) var room_blur: float = 0.5
@export_range(0.0, 8.0, 0.1) var shelf_blur: float = 0.8
@export_range(0.0, 8.0, 0.1) var sofa_blur: float = 0.3
## 영역에 머무는 시간(초)
@export var duration: float = 12.0
## 배경 그림 배율 — 1942x809 그림이 0.55면 1068x445가 된다(화면 비율과 거의 같아 꽉 찬다)
@export var image_scale: float = 0.45
## 그림에서 **위층 바닥 윗면**(엄마 발이 닿는 높이, 그림 픽셀). 그림을 훑어 잰 값이다
@export var upper_floor_image_y: float = 331.0
## 그림에서 **위층 바닥(슬래브) 아랫면** = 아래층 천장(그림 픽셀).
## 이걸 따로 두지 않으면 바닥 덩어리가 제멋대로 두꺼워져 아래층 머리 위를 잡아먹는다
@export var upper_slab_bottom_image_y: float = 413.0
## 그림에서 **아래층 바닥 윗면**(상대 발이 닿는 높이, 그림 픽셀)
@export var lower_floor_image_y: float = 743.0
## 그림에서 위층 천장 높이(그림 픽셀) — 엄마가 이 위로는 못 뜬다
@export var ceiling_image_y: float = 14.0
## 원래 맵 원점에서 영역 가운데까지 — 위로 멀리 둬서 원래 맵 지형과 안 겹치게 한다
@export var arena_offset: Vector2 = Vector2(0, -7000)
## 그림 좌우 끝에서 벽 안쪽 면까지(px)
@export var wall_inset: float = 24.0
## 들어갈 때 두 사람이 가운데에서 좌우로 떨어져 서는 거리(px)
@export var spawn_spread: float = 160.0
## **기본 궁극기 컷인 상자를 띄우지 않는다** — 이 궁은 초인종·문 쾅 연출이 곧 컷인이다
@export var skip_cutin: bool = true
## **궁을 쓴 순간 → 현관문 앞으로 넘어가는 전환.** 다른 캐릭터는 컷인이 그 몫을 하는데
## 이 궁은 컷인을 안 써서 화면이 뚝 끊겼다(2026-10-04 지적).
## 쓰는 사람 쪽으로 카메라가 당겨지면서 어두워졌다가 현관문 앞에서 밝아진다
@export var enter_zoom: float = 1.45
@export var enter_zoom_time: float = 0.45
## 들어가는 연출이 도는 동안 두 사람이 굳어 있는 시간(초)
@export var intro_lock: float = 7.0
## 어두워지는/밝아지는 시간(초)
@export var fade_time: float = 0.22
## **나올 때 화면이 쨍그랑 깨지게 할지**(황근출 내무반과 같은 연출). 들어갈 때는 안 쓴다 —
## 궁극기 연출(초인종·문 쾅) 뒤에 바로 집으로 넘어오기 때문이다(2026-10-04 사용자 결정)
@export var shatter_on_leave: bool = true
## 깨진 뒤 원래 맵이 다시 드러나는 시간(초)과, 두 캐릭터가 조금 늦게 나타나는 시점·시간(초)
@export var reveal_map_time: float = 0.6
@export var reveal_fighter_delay: float = 0.3
@export var reveal_fighter_time: float = 0.45
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
## 걷는 중에 나가는 충격파는 이 비율만큼 좁다.
## 처음엔 절반(0.5)이었는데 그래도 넓다고 해서 한 번 더 반으로 줄였다(2026-10-04)
@export_range(0.1, 1.0, 0.05) var walk_width_ratio: float = 0.25
## 걷기 충격파가 **보는 방향으로 더 나가는 거리(px)** — 디딘 발보다 살짝 앞에서 터진다.
## 뒤에 남은 발자리에서 터지면 앞으로 가는 느낌이 안 난다(2026-10-04 사용자 요청)
@export var walk_shock_forward: float = 7.0
## 걸을 때 한 걸음 간격(초)과 그 피해
@export var walk_interval: float = 0.34
@export var walk_damage: int = 2
## 뛰어서 착지할 때의 피해
@export var land_damage: int = 4
## 아이가 쿵쿵 디딜 때의 피해(2번 스킬이 영역 안에서는 이걸로 바뀐다)
@export var kid_damage: int = 5
## 걷기 충격파의 화면 흔들림 비율(1이면 점프·아이와 같은 세기)
@export_range(0.0, 1.0, 0.05) var walk_shake_ratio: float = 0.5
## **훈련장처럼 흔들림 기능이 없는 카메라**를 직접 흔들 때의 기준 폭(px).
## 대전 맵 카메라의 흔들림 폭(12px)과 맞춰 뒀다
@export var plain_shake_px: float = 12.0
## 충격파가 터질 때 화면이 흔들리는 정도(걷기는 이 값의 절반).
## 카메라는 이 값 x 12px만큼 흔들리므로 0.18쯤이면 2px — 영역처럼 화면이 당겨진 곳에선 티가 안 난다.
## 0.5면 6px이라 "쿵" 하고 울리는 게 보인다(2026-10-04 지적)
@export var shake: float = 0.5
## 맞은 쪽이 밀려나는 힘 — **세로는 0에 가깝게.** 띄우면 다음 충격파가 전부 빗나간다
@export var knockback: Vector2 = Vector2(0, -20)
## 캐릭터 원점에서 발바닥까지(px) — 충격파가 시작하는 높이
@export var foot_offset: float = 30.0
## **발밑(위층 바닥)에 같이 띄우는 쿵 효과.** 아래층으로 내려가는 물결만 있으면
## 정작 위층에서 밟는 느낌이 없다(2026-10-04 지적). 2번 스킬이 쓰는 그 효과를 그대로 쓴다
@export var step_wave_scene: PackedScene = preload("res://skills/StompWave.tscn")
## 그 고리가 퍼지는 반지름(px). 걷기는 좁아진 비율만큼 작아진다
@export var step_wave_radius: float = 70.0

const SHOCK := preload("res://combat/DomainShock.gd")
const SCREEN_SHATTER := preload("res://combat/ScreenShatter.gd")
const FAR_BLUR := preload("res://maps/far_blur.gdshader")

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
## 평범한 카메라를 흔드는 중인 트윈(겹치면 끊고 새로 시작한다)
var _shake_tween: Tween = null
## 맞춤 씬에서 읽어 둔 자리(그림 픽셀). 비어 있으면 조정 칸 숫자를 쓴다
var _layout: Dictionary = {}
## 화면 깨지기 연출(나가는 중에만 있음) — 타입 안 붙임(ScreenShatter는 class_name이 없다)
var _shatter = null
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

## 실제로 영역을 펴는 곳 — 영역 싸움을 거치든 안 거치든 여기로 모인다
func _begin(fighter: Fighter) -> void:
	var map: Node = fighter.get_parent()
	if map == null:
		return
	_running = true
	_caster = fighter
	add_to_group(DomainClash.GROUP)
	# 연출이 도는 동안 둘 다 굳어 있는다 — 뒤에서 치고받으면 연출이 무색해진다
	_lock_fighters(maxf(intro_lock, 0.5))
	# 쓰는 사람에게 카메라가 확 당겨지면서 어두워진다 → 다 어두워지면 현관문 앞이 뜬다
	_zoom_on_caster(fighter)
	_fade_to_black(map, func(): _play_intro(fighter, 0, null))

## 연출을 한 장씩 차례로 튼다. `prev`는 바로 앞 장면(새 장면을 올린 **뒤에** 치운다 —
## 먼저 치우면 그 한 프레임 동안 맵이 비쳐서 깜빡인다)
func _play_intro(fighter: Fighter, index: int, prev: Node) -> void:
	if not is_instance_valid(fighter):
		return
	var map: Node = fighter.get_parent()
	if map == null:
		return
	var scene: PackedScene = null
	if index < intro_scenes.size():
		scene = intro_scenes[index]
	if scene == null:
		if is_instance_valid(prev):
			prev.queue_free()
		_fade_to_black(map, func(): _enter(fighter))
		return
	var node: Node = scene.instantiate()
	map.add_child(node)
	if is_instance_valid(prev):
		prev.queue_free()
	elif index == 0:
		# 첫 장면이 올라왔으니 깔아 둔 어둠을 걷는다
		_fade_from_black()
	if node.has_signal("finished"):
		node.finished.connect(func(): _play_intro(fighter, index + 1, node))
	if node.has_method("play"):
		node.play()

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
	# 설 자리는 맞춤 씬(`FloorDomainLayout`)의 `MomSpawn`·`FoeSpawn` 선을 따른다.
	# 선을 안 넣어 뒀으면 예전처럼 가운데에서 좌우로 벌려 세운다
	var mom_x: float = _arena.global_position.x - spawn_spread
	var foe_x: float = _arena.global_position.x + spawn_spread
	if _layout.has("MomSpawn"):
		mom_x = _arena.global_position.x + _image_to_local_x(_layout["MomSpawn"])
	if _layout.has("FoeSpawn"):
		foe_x = _arena.global_position.x + _image_to_local_x(_layout["FoeSpawn"])
	var shift: float = 0.0
	for f in _fighters():
		_return_pos[f] = f.global_position
		if f == fighter:
			_place(f, Vector2(mom_x, _upper_y() - 20.0))
		else:
			# 상대가 여럿이면 조금씩 옆으로 비켜 세운다(보통은 한 명)
			_place(f, Vector2(foe_x + shift, _lower_y() - 20.0))
			shift += 70.0
	var cam: Node = get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("enter_arena"):
		cam.enter_arena(_arena_rect(), _arena.global_position, arena_close_zoom, 0.0)
	else:
		# 훈련장처럼 평범한 Camera2D만 있는 맵 — 직접 옮겨 준다. 안 하면 카메라가 원래 맵에 남아
		# 멀리 떨어진 영역이 화면에 안 보인다(2026-10-04 훈련장에서 아무것도 안 나오던 원인)
		_enter_plain_camera(_arena.global_position)
	_set_domain_jump(true)
	# 연출 동안 걸어 둔 잠금·무적을 여기서 푼다 — 집에 들어왔는데도 한동안 안 맞으면
	# 영역 초반 쿵쿵이 통째로 헛방이 된다(2026-10-04)
	_unlock_fighters()
	_fade_from_black()
	_left = duration
	_walk_left = 0.0
	_was_floor = true
	Timers.after(self, duration, func(): _start_leave())

## **시간이 다 됐다** — 영역이 쨍그랑 깨져 떨어지고 원래 맵으로 돌아간다
func _start_leave() -> void:
	if not _running:
		return
	_lock_fighters(2.0)
	if shatter_on_leave and is_instance_valid(_caster):
		_break_screen(_caster, func(reveal): _leave(reveal))
	else:
		_leave(false)

## 지금 화면이 금 가며 깨져 떨어진다 → 까매지면 then(true). 화면을 못 찍으면(헤드리스 등) 그냥 암전 후 then(false)
func _break_screen(fighter: Fighter, then: Callable) -> void:
	var map: Node = fighter.get_parent()
	if map == null:
		_leave(false)
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

## 궁을 쓴 사람 쪽으로 카메라를 확 당긴다 — 넘어가기 직전의 "숨 고르기"다.
## 그 기능이 없는 카메라(훈련장)면 그냥 넘어간다
func _zoom_on_caster(fighter: Fighter) -> void:
	if enter_zoom <= 1.001 or enter_zoom_time <= 0.0:
		return
	var cam: Camera2D = fighter.get_viewport().get_camera_2d()
	if cam and cam.has_method("focus_on"):
		cam.focus_on(fighter, enter_zoom, enter_zoom_time)

## 연출 동안 걸어 둔 행동 잠금과 무적을 그 자리에서 푼다
func _unlock_fighters() -> void:
	for f in _fighters():
		if not is_instance_valid(f):
			continue
		if f.has_method("end_busy"):
			f.end_busy()
		# grant_invincibility(0.0)은 0초 타이머 에러가 나므로 깃발을 바로 내린다
		f.is_invincible = false

## 깨지는 연출 ~ 다시 나타날 때까지 둘 다 무적·행동 불가(깨지는 화면 뒤에서 맞거나 스킬이 나가지 않게)
func _lock_fighters(time: float) -> void:
	for f in _fighters():
		if is_instance_valid(f):
			f.start_busy(time)
			f.grant_invincibility(time)

## 원래 맵으로 돌려놓는다. reveal이면 깨진 화면(검정)에서 원래 맵이 서서히 드러난다
func _leave(reveal: bool = false) -> void:
	if not _running:
		return
	_running = false
	remove_from_group(DomainClash.GROUP)
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
	if reveal:
		_reveal_map()
	else:
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
			# 걷기 — 디딘 발보다 살짝 앞쪽에서 좁게. 한 발씩 번갈아 나간다
			var at: Vector2 = _foot_at(_left_foot) + Vector2(walk_shock_forward * _caster.facing, 0.0)
			_shock(walk_damage, walk_width_ratio, at)
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
	# ⚠️ **값은 맵에 붙이기 전에 다 넣는다.** 붙이는 순간 `_ready()`가 돌면서 폭(scale)을 잡는데,
	# 뒤에 넣으면 그림은 기본 폭 그대로이고 판정만 좁아져서 "보이는데 안 맞는" 상태가 된다(2026-10-04)
	fx.depth = maxf(_lower_y() - at.y - shock_drop, 20.0)
	fx.spread_deg = shock_spread_deg
	fx.width_ratio = ratio
	fx.damage = _caster.compute_damage(dmg)
	fx.knockback = knockback
	fx.caster = _caster
	_arena.add_child(fx)
	fx.global_position = at + Vector2(0.0, shock_drop)
	_spawn_step_wave(at, ratio)
	_shake_camera(shake * (1.0 if ratio >= 0.99 else walk_shake_ratio))

## 화면을 흔든다. 대전 맵 카메라(`CameraRig`)는 흔들림 기능이 있지만,
## **훈련장은 평범한 Camera2D라 그 기능이 없어서** 거기선 아무 일도 안 일어났다(2026-10-04 지적).
## 그런 카메라는 여기서 직접 흔들어 준다
func _shake_camera(amount: float) -> void:
	if amount <= 0.0 or not is_instance_valid(_caster):
		return
	var cam: Camera2D = _caster.get_viewport().get_camera_2d()
	if cam == null:
		return
	if cam.has_method("add_trauma"):
		cam.add_trauma(amount)
		return
	_plain_shake(cam, amount * plain_shake_px)

## 평범한 Camera2D를 직접 흔든다 — 흔들던 중이면 그걸 끊고 새로 흔든다
func _plain_shake(cam: Camera2D, strength: float) -> void:
	if is_instance_valid(_shake_tween):
		_shake_tween.kill()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_shake_tween = cam.create_tween()
	var steps: int = 4
	for i in range(steps):
		var size: float = strength * (1.0 - float(i) / float(steps))
		_shake_tween.tween_property(cam, "offset",
			Vector2(rng.randf_range(-size, size), rng.randf_range(-size, size)), 0.04)
	_shake_tween.tween_property(cam, "offset", Vector2.ZERO, 0.05)

## 발밑에 쿵 효과(고리 + 먼지)를 띄운다 — 위층을 밟는 느낌을 내는 쪽이다
func _spawn_step_wave(at: Vector2, ratio: float) -> void:
	if step_wave_scene == null or _arena == null:
		return
	var wave := step_wave_scene.instantiate() as Node2D
	if wave == null:
		return
	_arena.add_child(wave)
	wave.global_position = at
	if "max_radius" in wave:
		wave.max_radius = step_wave_radius * ratio

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
	_read_layout()
	_arena = Node2D.new()
	_arena.name = "FloorDomainArena"
	_arena.position = arena_offset
	map.add_child(_arena)
	# 뒤에서부터 방 → 책장 → 소파 → (캐릭터) → 앞 띠 순으로 쌓는다.
	# 뒤로 갈수록 어둡게 깔아서 앞뒤 거리가 느껴지게 한다(2026-10-04 사용자 요청)
	_bg = _add_layer(background, -50, room_shade, room_blur)
	_add_layer(layer_shelf, -40, shelf_shade, shelf_blur)
	_add_layer(layer_sofa, -30, sofa_shade, sofa_blur)
	_add_layer(layer_front, 10, 1.0, 0.0)
	var half: Vector2 = background.get_size() * image_scale * 0.5
	var upper: float = _image_to_local(_row("UpperFloor", upper_floor_image_y))
	var lower: float = _image_to_local(_row("LowerFloor", lower_floor_image_y))
	var ceiling: float = _image_to_local(_row("Ceiling", ceiling_image_y))
	# 위층 바닥 = 아래층 천장. 그림에 그려진 슬래브 두께 그대로 깐다
	var slab_bottom: float = _image_to_local(_row("SlabBottom", upper_slab_bottom_image_y))
	var slab: float = maxf(slab_bottom - upper, 8.0)
	_add_block("UpperFloor", Vector2(0, upper + slab * 0.5), Vector2(half.x * 2.0 + 400.0, slab))
	_add_block("LowerFloor", Vector2(0, lower + 100.0), Vector2(half.x * 2.0 + 400.0, 200.0))
	_add_block("Ceiling", Vector2(0, ceiling - 100.0), Vector2(half.x * 2.0 + 400.0, 200.0))
	var wall_h: float = (lower - ceiling) + 600.0
	var wall_y: float = (lower + ceiling) * 0.5
	var left: float = -half.x + wall_inset
	var right: float = half.x - wall_inset
	if _layout.has("LeftWall"):
		left = _image_to_local_x(_layout["LeftWall"])
	if _layout.has("RightWall"):
		right = _image_to_local_x(_layout["RightWall"])
	_add_block("LeftWall", Vector2(left - 50.0, wall_y), Vector2(100, wall_h))
	_add_block("RightWall", Vector2(right + 50.0, wall_y), Vector2(100, wall_h))

## 배경 층 하나를 깐다 — 그림이 비어 있으면 아무것도 안 만든다.
## 흐림이 걸린 층은 **CanvasGroup**에 넣는다 — 한 장으로 합쳐 그린 뒤 흐려야 이음매가 따로 번지지 않는다
func _add_layer(tex: Texture2D, z: int, shade: float, blur: float) -> Sprite2D:
	if tex == null:
		return null
	var layer := Sprite2D.new()
	layer.texture = tex
	layer.scale = Vector2(image_scale, image_scale)
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tint := Color(shade, shade, shade, 1.0)
	if blur > 0.01:
		var group := CanvasGroup.new()
		group.z_index = z
		group.modulate = tint
		var mat := ShaderMaterial.new()
		mat.shader = FAR_BLUR
		mat.set_shader_parameter("blur_px", blur)
		mat.set_shader_parameter("dim", 0.0)
		group.material = mat
		_arena.add_child(group)
		group.add_child(layer)
	else:
		layer.z_index = z
		layer.modulate = tint
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

## 깨진 조각이 다 떨어진 뒤 — 맨 위에 깐 까만 판을 걷어 원래 맵을 드러내고, 두 캐릭터는 조금 늦게 나타난다
func _reveal_map() -> void:
	var map: Node = _caster.get_parent() if is_instance_valid(_caster) else get_tree().current_scene
	if map == null:
		return
	_ensure_fade(map)
	_fade.color.a = 1.0
	if is_instance_valid(_shatter):
		_shatter.queue_free()
	_shatter = null
	var fighters: Array = _fighters()
	for f in fighters:
		f.modulate.a = 0.0
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 0.0, reveal_map_time)
	for f in fighters:
		var ft := (f as Node).create_tween()
		ft.tween_interval(reveal_fighter_delay)
		ft.tween_property(f, "modulate:a", 1.0, reveal_fighter_time)

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

## 맞춤 씬에서 바닥·벽 자리를 읽어 둔다. 씬이 없거나 조각이 빠져 있으면 그 칸만 숫자 값을 쓴다
func _read_layout() -> void:
	_layout.clear()
	if layout_scene == null:
		return
	var root: Node = layout_scene.instantiate()
	if root == null:
		return
	for part_name in ["Ceiling", "UpperFloor", "SlabBottom", "LowerFloor"]:
		var part := root.find_child(part_name, true, false) as Node2D
		if part:
			_layout[part_name] = part.position.y
	for part_name in ["LeftWall", "RightWall", "MomSpawn", "FoeSpawn"]:
		var wall := root.find_child(part_name, true, false) as Node2D
		if wall:
			_layout[part_name] = wall.position.x
	root.free()

## 맞춤 씬에 그 선이 있으면 그 자리, 없으면 조정 칸 숫자
func _row(part_name: String, fallback: float) -> float:
	return float(_layout[part_name]) if _layout.has(part_name) else fallback

## 그림 픽셀 **가로** 자리를 영역 안 좌표로
func _image_to_local_x(image_x: float) -> float:
	return (image_x - background.get_size().x * 0.5) * image_scale

## 그림 픽셀 높이를 영역 안 좌표로 바꾼다
func _image_to_local(image_y: float) -> float:
	return (image_y - background.get_size().y * 0.5) * image_scale

func _upper_y() -> float:
	return _arena.global_position.y + _image_to_local(_row("UpperFloor", upper_floor_image_y))

func _lower_y() -> float:
	return _arena.global_position.y + _image_to_local(_row("LowerFloor", lower_floor_image_y))

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
		# 연출 장면들이 layer 60이라 그보다 위에 깔아야 가릴 수 있다
		layer.layer = 70
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
