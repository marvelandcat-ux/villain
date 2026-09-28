class_name TitleScreen
extends Control

## 게임을 켜면 가장 먼저 나오는 타이틀 화면. 아무 키나 누르면 메인 메뉴로 넘어간다.
## 게임 이름은 로고 그림(`TitleLogo` — sprite/타이틀/타이틀.png, 하양·빛·무지개 연출은 ui/TitleLogo.gd)과 메인 메뉴에 있다
##
## 소리·화면 전환 흐름:
##  1. 켜지면 검은 화면이 걷히면서(enter_fade) 타이틀 브금이 반복 재생된다
##  2. 아무 키나 누르면 클릭 소리가 나고, 화면이 어두워지며(exit_fade) 브금도 같이 잦아든다
##  3. 다 어두워지면 메인 메뉴로 넘어간다
##
## **뒤에서 실제 게임이 돌아간다(구경 모드, 2026-09-28 사용자 요청)** — 켤 때마다 GameState.MAPS에서 맵 하나,
## CHARACTERS에서 캐릭터 둘을 랜덤으로 뽑아 AI끼리 싸우게 한다(`Stage`가 game_mode "attract"면 HUD·카운트다운·결과 화면 없이 돈다).
## 카메라는 싸움을 따라가지 않고 **맵 왼쪽 끝에서 전체 거리의 pan_end(3/4)까지 pan_time초 동안 흐르고**(`CameraRig.start_pan`),
## 거기 닿으면 어두워졌다가 새 랜덤 조합으로 바꿔 다시 왼쪽부터 흐른다 — **넘어가는 기준은 항상 카메라가 왼쪽에서 오른쪽으로 흐른 것**(사용자 결정, 제자리 대기 없음)(2026-09-28 사용자 요청 — 쓰러져도 계속 흐른다,
## 체력 0이 돼도 캐릭터는 계속 움직이고 싸운다). 게임 장면은 `ArenaViewport`(SubViewport) 안에
## 띄우고 `Arena`(TextureRect)로 화면에 깐다 — 맵의 카메라가 제목 글자까지 움직이지 않게 따로 떼어 둔 것이다.
## 뷰포트는 **창 해상도 그대로** 그려 선명하다(2026-09-28 사용자 요청 — 1280x720으로 그려 늘렸더니 흐렸다).
## `CameraRig`가 시야를 뷰포트 픽셀로 잡으므로 `CameraRig.view_scale`(창 높이 / 720)로 그만큼 당겨 구도를 맞추고,
## `arena_zoom`(`CameraRig.zoom_boost`)으로 실제 대전보다 더 가까이 찍는다. 둘 다 static이라 타이틀을 떠날 때 1로 되돌린다.
## AI는 타이틀에서만 약하게(`ai_*`). 제목은 로고 그림 `TitleLogo`
##
## **브금 반복은 코드에서 켠다** — mp3는 임포트 설정에 loop 옵션이 있지만, 그 설정에 기대지 않고
## `AudioStreamMP3.loop`을 _ready()에서 직접 true로 둔다(임포트 설정을 다시 만져도 안 풀린다).

## "아무 키나 누르세요"가 1초에 몇 번 깜빡일지
@export var blink_speed: float = 1.4

@export_group("화면 전환")
## 켜질 때 검은 화면이 걷히는 시간(초)
@export var enter_fade: float = 0.9
## 키를 누른 뒤 어두워지며 메인 메뉴로 넘어가기까지의 시간(초).
## 클릭 소리가 2.2초짜리라 1.4초면 앞부분이 충분히 들리고, 나머지는 어두워지며 자연스럽게 잘린다
@export var exit_fade: float = 1.4
## 어두워지는 동안 브금이 잦아드는 정도 (1이면 완전히 무음까지)
@export_range(0.0, 1.0, 0.05) var bgm_fade_out: float = 1.0

@export_group("뒤에서 싸우는 장면")
## 끄면 예전처럼 단색 배경만 나온다
@export var show_arena: bool = true
## 카메라가 왼쪽 끝에서 pan_end까지 흐르는 시간(초) — 닿으면 다음 조합
@export var pan_time: float = 10.0
## 전체 거리의 몇 %까지 흐른 뒤 다음 조합으로 넘어갈지(사용자 결정 3/4 — 끝까지 가면 맵만 오래 보여서)
@export_range(0.1, 1.0, 0.05) var pan_end: float = 0.75
## 흐를 거리가 이보다 짧으면 흐르지 않고 제자리에서 hold_time초 보여 준다 — 사용자 결정으로 0(항상 흐른다)
@export var pan_min_range: float = 0.0
@export var hold_time: float = 8.0
## 새 판에서 두 AI를 세울 때 서로 떨어뜨릴 최소 거리(px)
@export var min_spawn_gap: float = 140.0
## 카메라를 못 찾는 등 흐르기가 안 끝날 때를 대비한 안전 한도(초)
@export var round_max_time: float = 40.0
## 조합을 바꿀 때 어두워졌다 밝아지는 시간(초, 한쪽)
@export var swap_fade: float = 0.45
## 게임 장면 위에 평소 깔아 두는 어둠(0~1) — 제목 글자가 읽히게
@export_range(0.0, 1.0, 0.05) var arena_dim: float = 0.25
## 실제 대전보다 몇 배 가까이 찍을지
@export_range(1.0, 3.0, 0.05) var arena_zoom: float = 1.5

@export_group("타이틀 AI 난이도 (실제 대전 AI는 그대로)")
## 상대 공격을 알아채는 데 걸리는 시간(초) — 클수록 약하다(대전 AI 0.09)
@export var ai_reaction_time: float = 0.25
## 공격을 읽었을 때 방어할 확률(대전 AI 0.6)
@export_range(0.0, 1.0, 0.05) var ai_guard_chance: float = 0.25
## 방어를 못 하면 피할 확률(대전 AI 0.75)
@export_range(0.0, 1.0, 0.05) var ai_dodge_chance: float = 0.35
## 스킬 조건이 맞을 때 실제로 쓸 확률(대전 AI 0.6)
@export_range(0.0, 1.0, 0.05) var ai_skill_chance: float = 0.8

@onready var _prompt: Label = $Center/VBox/PromptLabel
@onready var _fade: ColorRect = $Fade
@onready var _bgm: AudioStreamPlayer = $Bgm
@onready var _click: AudioStreamPlayer = $Click
@onready var _viewport: SubViewport = $ArenaViewport
@onready var _arena_view: TextureRect = $Arena
@onready var _shade: ColorRect = $Shade

var _time: float = 0.0
## 씬을 넘기는 중이면 입력을 두 번 받지 않도록 잠근다
var _leaving: bool = false
## 나가는 연출이 얼마나 진행됐는지(초)
var _leave_time: float = 0.0
## 브금이 원래 크기(dB) — 잦아들 때 여기서부터 내려간다
var _bgm_volume: float = 0.0
## 지금 뒤에서 돌고 있는 맵(Stage)
var _arena: Node = null
var _arena_time: float = 0.0
## 그 판의 게임 카메라(CameraRig) — 흐르기를 시키고 끝났는지 본다
var _arena_cam: Camera2D = null
## 조합 바꾸기 진행: 0 = 평소, 1 = 어두워지는 중, 2 = 밝아지는 중
var _swap_stage: int = 0
var _swap_t: float = 0.0

func _ready() -> void:
	# 뒤 게임에서 멈추는 연출이 끼어들어도 타이틀(깜빡임·입력·판 교체)은 계속 돈다
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	_fade.color.a = 1.0
	if _bgm.stream is AudioStreamMP3:
		_bgm.stream.loop = true
	_bgm_volume = _bgm.volume_db
	_bgm.play()
	_shade.color.a = arena_dim
	_arena_view.texture = _viewport.get_texture()
	get_window().size_changed.connect(_fit_viewport)
	if show_arena:
		_start_arena()

## 타이틀이 사라질 때(메뉴로 넘어가거나 창을 닫을 때) 브금을 멈춘다 — 재생 중인 채로 꺼지면
## "resources still in use"·"ObjectDB instances were leaked" 경고가 났다
## 타이틀에서 창 닫기(X)로 끌 때도 브금을 먼저 멈춘다(재생 중인 채로 꺼지면 종료 경고가 난다)
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_bgm.stop()
		_click.stop()

func _exit_tree() -> void:
	_bgm.stop()
	_click.stop()
	# 카메라 공용 배율을 원래대로 — 안 되돌리면 실제 대전 카메라까지 당겨진다
	CameraRig.view_scale = 1.0
	CameraRig.zoom_boost = 1.0

## 맵 하나·캐릭터 둘을 랜덤으로 뽑아 AI끼리 싸우는 맵을 뒤에 띄운다
func _start_arena() -> void:
	if is_instance_valid(_arena):
		_arena.queue_free()
	# 혹시 게임을 멈추는 연출이 끼어들었어도 새 판은 멈춘 채 시작하지 않게
	get_tree().paused = false
	var maps: Array = GameState.MAPS.values()
	var chars: Array = GameState.CHARACTERS.values()
	chars.shuffle()
	GameState.game_mode = "attract"
	GameState.selected_map_path = maps.pick_random()
	GameState.p1_character_path = chars[0]
	GameState.p2_character_path = chars[1 % chars.size()]
	_fit_viewport()
	CameraRig.zoom_boost = arena_zoom
	_arena = load(GameState.selected_map_path).instantiate()
	_viewport.add_child(_arena)
	_soften_ai()
	# "지금 카메라"(get_camera_2d)를 묻지 말고 흐르기 기능이 있는 게임 카메라를 직접 찾는다 —
	# 놀이터는 지우는 중인 왕관 컷인 안에도 카메라가 있어서 그게 잡히면 흐르기가 시작되지 않았다
	_arena_cam = null
	for c in _arena.find_children("*", "Camera2D", true, false):
		if c.has_method("start_pan"):
			_arena_cam = c
			break
	if _arena_cam != null:
		_arena_cam.start_pan(pan_time, pan_end, pan_min_range, hold_time)
		_place_fighters_in_view()
	_arena_time = 0.0

## 뒤 게임을 창 해상도로 그리고, 카메라에 기준(720)보다 몇 배 큰지 알린다(카메라가 만들어지기 전에 불러야 한다)
func _fit_viewport() -> void:
	var win: Vector2i = get_window().size
	if win.x <= 0 or win.y <= 0:
		return
	_viewport.size = win
	CameraRig.view_scale = win.y / 720.0

## 새 판의 두 AI를 **카메라가 처음 보는 화면 안의 밟을 수 있는 곳**(바닥·의자·구름 같은 발판) 중 랜덤한 자리에 세운다
## (2026-09-28 사용자 요청 — 스폰 마커 자리에서 시작하면 화면 밖에서 싸우고 있을 때가 많았다).
## 맵의 StaticBody2D 직사각형 충돌 윗면을 모아(벽·기둥처럼 좁고 긴 건 뺀다) 화면 안에 캐릭터가 머리까지 들어오는 곳만 고르고,
## 둘이 겹치지 않게 min_spawn_gap 넘게 떨어뜨린다. 고를 곳이 없으면 원래 스폰 자리 그대로
func _place_fighters_in_view() -> void:
	var half: Vector2 = Vector2(_viewport.size) * 0.5 / _arena_cam.zoom
	var view := Rect2(_arena_cam.global_position - half, half * 2.0)
	var spots: Array = []
	for body in _arena.find_children("*", "StaticBody2D", true, false):
		for c in body.get_children():
			var cs := c as CollisionShape2D
			if cs == null or cs.disabled or not (cs.shape is RectangleShape2D):
				continue
			var t: Transform2D = cs.global_transform
			if absf(t.get_rotation()) > 0.05:
				continue
			var size: Vector2 = (cs.shape as RectangleShape2D).size * t.get_scale().abs()
			# 벽·기둥(좁고 긴 것)은 밟을 곳이 아니다
			if size.x < 60.0 or size.y > size.x * 2.0:
				continue
			var top: float = t.origin.y - size.y * 0.5
			var left: float = maxf(t.origin.x - size.x * 0.5 + 20.0, view.position.x + 40.0)
			var right: float = minf(t.origin.x + size.x * 0.5 - 20.0, view.end.x - 40.0)
			# 발(윗면)부터 머리(약 100px 위)까지 화면에 들어오는 곳만
			if right <= left or top > view.end.y - 10.0 or top - 100.0 < view.position.y:
				continue
			spots.append(Vector3(left, right, top))
	if spots.is_empty():
		return
	var placed: Array = []
	for f in get_tree().get_nodes_in_group("fighters"):
		if not _arena.is_ancestor_of(f):
			continue
		var pos := Vector2.ZERO
		for attempt in 12:
			var s: Vector3 = spots.pick_random()
			# 캐릭터 원점은 발끝보다 30px 위(허트박스·스쿼시 기준과 같다)
			pos = Vector2(randf_range(s.x, s.y), s.z - 31.0)
			var far_enough: bool = true
			for p in placed:
				if p.distance_to(pos) < min_spawn_gap:
					far_enough = false
			if far_enough:
				break
		placed.append(pos)
		f.global_position = pos
		f.velocity = Vector2.ZERO

## 방금 띄운 판의 AI 둘을 약하게 한다(Stage가 add_child 안에서 바로 캐릭터·AI를 만들어 둔다)
func _soften_ai() -> void:
	for f in get_tree().get_nodes_in_group("fighters"):
		if not _arena.is_ancestor_of(f):
			continue
		for c in f.get_children():
			if c is AIController:
				c.reaction_time = ai_reaction_time
				c.guard_react_chance = ai_guard_chance
				c.dodge_react_chance = ai_dodge_chance
				c.skill_commit_chance = ai_skill_chance
				c.bait_chance = 0.0
				# 스킬 보여주기 위주(평타 거의 안 침·붙어 싸우지 않음·이단 점프와 대시 많이)
				c.showcase = true

## 카메라가 오른쪽 끝에 닿으면(또는 안전 한도) 어두워졌다가 새 조합으로 바꾸고 다시 밝아진다
func _update_arena(delta: float) -> void:
	if not is_instance_valid(_arena):
		return
	_arena_time += delta
	if _swap_stage == 0:
		var panned: bool = is_instance_valid(_arena_cam) and _arena_cam.pan_finished()
		if panned or _arena_time >= round_max_time:
			_swap_stage = 1
			_swap_t = 0.0
		return
	_swap_t += delta
	var k: float = clampf(_swap_t / maxf(swap_fade, 0.001), 0.0, 1.0)
	if _swap_stage == 1:
		_shade.color.a = lerpf(arena_dim, 1.0, k)
		if k >= 1.0:
			_start_arena()
			_swap_stage = 2
			_swap_t = 0.0
	else:
		_shade.color.a = lerpf(1.0, arena_dim, k)
		if k >= 1.0:
			_swap_stage = 0

func _process(delta: float) -> void:
	_time += delta
	# 0.35~1.0 사이를 오가게 해서 완전히 사라지지는 않고 은은하게 깜빡인다
	_prompt.modulate.a = 0.675 + 0.325 * sin(_time * blink_speed * TAU)
	_update_arena(delta)

	if not _leaving:
		# 켜질 때: 검은 판이 서서히 걷힌다
		_fade.color.a = clampf(1.0 - _time / maxf(enter_fade, 0.001), 0.0, 1.0)
		return

	_leave_time += delta
	var t: float = clampf(_leave_time / maxf(exit_fade, 0.001), 0.0, 1.0)
	_fade.color.a = t
	# 브금은 소리 크기를 dB로 내린다. 0배는 -inf라 -60dB에서 끊는다
	var level: float = 1.0 - bgm_fade_out * t
	_bgm.volume_db = _bgm_volume + (linear_to_db(level) if level > 0.001 else -60.0)
	if t >= 1.0:
		# 구경 모드 표시를 지운다 — 메뉴에서 모드를 고르면 다시 정해지지만, 남아 있으면 헷갈린다
		GameState.game_mode = "pvp"
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		_leaving = true
		_leave_time = 0.0
		_click.play()
