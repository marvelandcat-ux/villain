extends Node2D

## 튜토리얼 맵(2026-10-01) — 군 시험장 풀밭. 처음 켠 사람은 타이틀 다음에 여기로 온다(GameState.tutorial_seen).
## 배경: 하늘 < 랜덤 구름 < 산 < 숲 < 건물·막사·국기 < 땅. 교관(황근출)이 말풍선으로 조작을 가르친다.
##
## 진행은 `_lines`(대사 한 줄 = Dictionary) 순서대로다(2026-10-07에 번호 상수에서 바꿈):
##  - `gate`  : 스페이스가 아니라 **이 행동을 해야** 다음 줄로 넘어가는 줄(move/jump/parkour/guard/dash)
##  - `phase` : 스페이스를 누르면 말풍선이 닫히고 **이 실습이 시작**되는 줄(hit/parry/skill1/skill2/ult/fight). 실습이 끝나면 다음 줄
##  - `goal`  : 그동안 화면 아래 흰 알약에 띄우는 목표 문장
## 그 외 줄은 스페이스로 넘어간다. 키 이름은 설정에서 바꾼 키를 그대로 읽어 적는다(`_key()`)

## 훈련 더미 stats는 샌드백용이라 move_speed가 0 — 조작용으로 복제해 이 속도를 넣는다
@export var player_move_speed: float = 411.75
## 이 아래로 떨어지면 스폰 자리로 되돌린다
@export var fall_limit_y: float = 900.0
## 태양은 맵 가운데(월드 x=0)에 걸려 있는 느낌 — 카메라가 맵 끝까지 가면 화면에서 이만큼(UV) 어긋난다. 작을수록 미묘
@export var sun_parallax: float = 0.1
## 어긋남을 재는 기준 반폭(월드 px, 벽 간격의 절반)
@export var sun_map_half_width: float = 1200.0
## 입장 연출 시작 x(맨 왼쪽 벽 -1200에서 100px 안쪽). 여기서 투명하게 나타나 걸어온다
@export var intro_start_x: float = -1100.0
## 이 거리(px)만큼 걸어오는 동안 투명도가 0 → 100%로 차오른다
@export var intro_fade_distance: float = 500.0

## 교관(해병)과 이 거리(px) 안에 들어오면 훈련 안내가 시작된다
@export var instructor_trigger_range: float = 500.0

var _fighter: Fighter
var _sun_mat: ShaderMaterial
var _sun_base: Vector2 = Vector2(0.5, -1.0)
## 입장 연출(왼쪽에서 걸어오며 페이드인) 진행 중이면 true — 그동안은 조작을 막고 직접 걷게 한다
var _intro_active: bool = false
## 걸어와서 멈출 목표 x(스폰 자리)
var _intro_target_x: float = 0.0
## 교관 머리 위 말풍선(씬에 InstructorBubble로 배치 — 에디터에서 위치·크기 조절 가능, say()는 덕타이핑)
@onready var _bubble = $InstructorBubble

## 훈련 안내 진행 단계
enum Step { NONE, TALK, DONE }
var _step: int = Step.NONE
## 교관 대사 목록 — _ready에서 `_line()`으로 채운다
var _lines: Array[Dictionary] = []
var _line_idx: int = -1

## 스페이스로 넘어가는 줄에서 안 넘기고 이만큼(초) 기다리면 "스페이스를 누르세요"를 띄운다(첫 줄은 바로)
const PRESS_HINT_DELAY := 4.0

## 움직이기 줄은 말이 끝나고 이 초만큼 지난 뒤 움직여야 넘어간다(읽기도 전에 넘어가지 않게)
const MOVE_GATE_DELAY := 2.0
## 움직이기 줄에서 말이 끝난 뒤 흐른 시간(초)
var _move_wait: float = 0.0

## 땅 윗면 월드 y (발판 윗면 높이·솟는 자리 기준)
@export var ground_top_y: float = 393.0
## 1·2단 발판 윗면이 땅 윗면에서 이만큼 위(px). 1단=땅에서 1점프(그림 한 장이 딱 땅에 닿는 높이),
## 2단=1단에서 더블점프로 겨우 닿게(1단과의 차이 190px, 더블점프 최대 ≈216px)
@export var platform1_rise: float = 55.0
@export var platform2_rise: float = 245.0
## 두 발판의 x (플레이어 왼쪽 = 음수, 위로 갈수록 더 왼쪽인 계단식). 두 발판 폭이 안 겹치게 띄울 것
@export var platform1_x: float = -150.0
@export var platform2_x: float = -360.0
## 나무 발판 상판(서는 면)의 화면 폭 목표 — 이미지는 이 폭에 맞춰 줄인다
@export var platform_plank_width: float = 190.0

# 나무 발판 그림(sprite/맵/튜토리얼/). 둘은 캔버스가 같아도 상판 위치·폭이 달라 따로 잰 값을 쓴다.
const PLATFORM_TEX_1 := "res://sprite/맵/튜토리얼/나무 폴랫폼.png"
const PLATFORM_TEX_2 := "res://sprite/맵/튜토리얼/나무 폴랫폼2.png"
## [상판 윗면 y, 상판 왼끝 x, 상판 오른끝 x, 그림 맨아랫변 y] — PowerShell로 알파 측정(그림을 바꾸면 다시 잴 것)
const PLATFORM_GEO_1 := [204.0, 51.0, 1723.0, 738.0]
const PLATFORM_GEO_2 := [18.0, 110.0, 1667.0, 868.0]
## 발판이 땅 밑에 숨는 깊이(땅 윗면 아래 이만큼) — 솟기 전·가라앉은 뒤 자리
const PLATFORM_HIDE_DEPTH := 8.0
## 충돌 상자를 땅 밑으로 이만큼 더 깊이 박는다(땅과 틈 없이 이어지게)
const PLATFORM_COLL_BURY := 40.0

var _parkour_active: bool = false
var _parkour_done: bool = false
var _platform1: StaticBody2D
var _platform2: StaticBody2D
## 발판2 꼭대기에 한 번이라도 올라섰나(그 뒤 왼쪽으로 떨어져 땅에 닿으면 발판이 사라진다)
var _reached_p2: bool = false

## 교관이 기본공격하는 간격(초) / 이 거리(px)까지 다가가 공격 / 이 거리(px) 안이면 공격을 낸다
const PARRY_ATTACK_INTERVAL := 2.5
const PARRY_FOLLOW_GAP := 52.0
const PARRY_ATTACK_RANGE := 85.0
## 처음 공격까지 기다리는 시간(초) / 패링에 성공한 뒤 X 아이콘을 보여 주는 시간(초)
const PARRY_FIRST_DELAY := 1.0
const PARRY_SUCCESS_WAIT := 1.6
## 시범 중 플레이어 체력이 이 비율 아래로 떨어지면 가득 채워 준다(튜토리얼에서 KO는 없다)
const PARRY_SAFE_HP_RATIO := 0.35

var _parry_active: bool = false
## 패링에 성공해 X 아이콘을 보여 준 뒤 원래 자리로 걸어 돌아가는 중
var _parry_returning: bool = false
var _parry_succeeded: bool = false
var _parry_timer: float = 0.0
var _parry_wait: float = 0.0
## 이 줄이 뜬 뒤 대시 쿨이 끝나 있는 걸 확인했나(이전 대시의 쿨 때문에 바로 넘어가지 않게)
var _dash_armed: bool = false

## 스킬 실습 중엔 쿨타임을 이 초로 깎는다 — 헛쏘면 금방 다시 쏠 수 있게(테이저건 원래 쿨 20초)
const SKILL_RETRY_COOLDOWN := 1.5
## 스킬을 쏜 뒤 이 초 안에 교관이 맞아야 "스킬로 맞힌 것"으로 친다(주먹으로 때린 걸 스킬 성공으로 안 치게)
const SKILL_HIT_WINDOW := 2.5
## 궁을 쓴 뒤 다음 대사까지 기다리는 시간(초) — 경봉을 뽑는 모션을 보여 준다
const ULT_FINISH_WAIT := 1.0
## 지금 진행 중인 스킬 실습("skill1"/"skill2"/"ult", 없으면 "")
var _skill_phase: String = ""
## 이번 실습에서 스킬을 쏜 뒤 흐른 시간(초). 음수면 아직 안 쐈다
var _skill_fired_for: float = -1.0
var _skill_was_ready: bool = false

## 똥자루(임시 캐릭터, 약한 AI)와의 마지막 싸움. 이기면 마지막 줄, 지면(플레이어 체력 0) 둘 다 체력을 채우고 다시 싸운다
const FIGHT_SCENE := "res://characters/ddongjaru/Ddongjaru.tscn"
## 똥자루가 플레이어에게서 이만큼(px) 떨어진 곳에 나타난다(교관 반대쪽)
const FIGHT_SPAWN_GAP := 300.0
## 똥자루 공격력 배수 / AI 솜씨(0~1, 스토리 EP.1과 같은 약한 값)
const FIGHT_DAMAGE_SCALE := 0.5
const FIGHT_AI_SKILL := 0.35
## 이긴 뒤 똥자루가 사라지고 마지막 대사가 나오기까지(초)
const FIGHT_WIN_WAIT := 1.2
var _fight_active: bool = false
var _enemy: Fighter
var _enemy_start_x: float = 0.0
var _player_start_x: float = 0.0
## 싸움 중 화면 위 체력바(신병 / 이등병 똥자루)
var _fight_hud: CanvasLayer
var _fight_bars: Array[ProgressBar] = []
## 교관(진짜 황근출 Fighter — 안 죽고, 3타 콤보로 날아가면 원래 자리로 돌아온다)
var _instructor: Fighter
var _instructor_home: Vector2 = Vector2.ZERO
## 교관 때리기 시연 진행 중
var _hit_active: bool = false
## 이번 시연에서 교관이 한 번이라도 날아갔나 / 날아갔다가 걸어 돌아오는 중인가
var _instr_launched: bool = false
var _instr_returning: bool = false
## 화면 아래 목표 알림(흰 알약)과 그 글자
var _goal_panel: Panel
var _goal_label: Label

## 강조(빨간색 굵게). 기본 글꼴이 이미 Bold라 굵기 차이는 거의 없고 빨간색으로 튄다
const EM_COLOR := "e22020"
func _em(s: String) -> String:
	return "[color=#%s][b]%s[/b][/color]" % [EM_COLOR, s]

## 초 단위 숫자를 대사용 글자로("3.0" -> "3초", "2.5" -> "2.5초")
func _sec_text(sec: float) -> String:
	if is_equal_approx(sec, roundf(sec)):
		return "%d초" % int(roundf(sec))
	return "%s초" % String.num(sec, 1)

## P1 조작키 이름 — 설정에서 바꾼 키를 그대로 읽는다("left" → A). 키가 안 걸려 있으면 "?"
func _key(action: String) -> String:
	for ev in InputMap.action_get_events("p1_" + action):
		if ev is InputEventKey:
			var code: Key = ev.keycode
			# 설정은 물리 키로 저장된다 — 지금 키보드 배열의 글자로 바꾼다(헤드리스 등 지원 안 하면 물리 키 이름 그대로)
			if code == KEY_NONE and DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode)
			if code == KEY_NONE:
				code = ev.physical_keycode
			return OS.get_keycode_string(code)
	return "?"

## 강조된 키 이름(대사용)
func _k(action: String) -> String:
	return _em(_key(action))

## 대사 한 줄. gate = 이 행동을 해야 넘어감 / phase = 스페이스 뒤 시작할 실습 / goal = 알약 문구
func _line(text: String, extra: Dictionary = {}) -> Dictionary:
	var d := {"text": text}
	d.merge(extra)
	return d

func _ready() -> void:
	GameState.mark_tutorial_seen()
	_spawn_player()
	_spawn_instructor()
	_build_goal_prompt()
	_lines = _build_lines()
	var rays := $Sunlight/Rays as ColorRect
	if rays and rays.material is ShaderMaterial:
		_sun_mat = rays.material
		_sun_base = _sun_mat.get_shader_parameter("sun_pos")

## 교관 대사 전부. 순서가 곧 진행 순서다 — 줄을 끼우거나 빼도 번호를 고칠 필요가 없다
func _build_lines() -> Array[Dictionary]:
	var L := _key("left")
	var R := _key("right")
	var guard_sec := _sec_text(_fighter.effective_guard_duration())
	var guard_cd := _sec_text(Fighter.guard_cooldown)
	var lock_sec := _sec_text(Fighter.blocked_attack_lock)
	var dash_cd := _sec_text(_fighter.effective_dash_cooldown())
	var lines: Array[Dictionary] = [
		# --- 이동 / 점프 ---
		_line("%s! 지금부터 %s을 시작한다. 대사는 %s로 넘긴다" % [_em("신병"), _em("훈련"), _em("스페이스")]),
		_line("%s %s 로 움직일 수 있다. %s 실시!" % [_k("left"), _k("right"), _em("움직인다")],
			{"gate": "move", "goal": "%s / %s 키로 움직이세요" % [L, R]}),
		_line("좋다 %s" % _em("신병")),
		_line("%s로 %s를 한다. 공중에서 한 번 더 누르면 %s이다. 뛰어 봐라!" % [_k("jump"), _em("점프"), _em("더블 점프")],
			{"gate": "jump", "goal": "%s 키로 점프하세요" % _key("jump")}),
		_line("하지만 너무 높이 점프하면 %s할 때 %s이 있다. 조심하도록 해라!" % [_em("착지"), _em("경직")]),
		_line("자 이제! 네가 %s이 아니란 걸 %s! 저 발판 %s까지 올라갔다가 %s으로 내려와라!" % [_em("폐급"), _em("증명해라"), _em("꼭대기"), _em("왼쪽")],
			{"gate": "parkour", "goal": "발판 꼭대기에 올라갔다가 왼쪽 땅으로 내려오세요"}),
		# --- 기본 공격 ---
		_line("기본 공격은 %s키다" % _k("basic_attack")),
		_line("기본 공격을 %s 치면 %s이 돈다. (너무 %s 하지 말라는 뜻)" % [_em("헛"), _em("쿨타임"), _em("연타")]),
		_line("한 번 %s 최대 %s까지 쿨타임 없이 이어서 때릴 수 있다" % [_em("맞추면"), _em("2번")]),
		_line("%s를 맞추면 적은 날아가며 %s 및 %s한다. 콤보를 잘 써 봐라" % [_em("3번째"), _em("넉백"), _em("기절")]),
		_line("말로는 모르겠지? %s! %s를 %s 맞춰서 나를 날려 보내라!" % [_em("나를 쳐 봐라"), _k("basic_attack"), _em("3번 연속")],
			{"phase": "hit", "goal": "%s 키를 3번 연속 맞춰 교관을 날려 보내세요" % _key("basic_attack")}),
		_line("기본 공격 수준을 보아하니 평소에 %s 했겠군 %s" % [_em("게임만"), _em("신병")]),
		# --- 방어 / 패링 ---
		_line("이제 %s와 %s을 알려주지" % [_em("방어"), _em("패링")]),
		_line("방어는 %s키다. 누른 순간부터 %s 동안 %s이 켜지고, 맵에서 나오는 %s 말고는 %s를 막는다" % [_k("down"), _em(guard_sec), _em("보호막"), _em("기믹 피해"), _em("모든 피해")]),
		_line("방어 중엔 %s. 그리고 %s %s가 있다 — 방어 %s 로 네 %s에 표시된다" % [_em("움직이지도 때리지도 못한다"), _em("쿨타임"), _em(guard_cd), _bubble.icon("guard"), _em("뒤쪽")]),
		_line("한번 %s 봐라!" % _em("눌러"),
			{"gate": "guard", "goal": "%s 키를 눌러 방어하세요" % _key("down")}),
		_line("좋다. 이제 %s이다" % _em("패링")),
		_line("방어 중에 상대의 기본 공격을 %s 피해를 받지 않고, 때린 상대는 %s 동안 %s" % [_em("막아내면"), _em(lock_sec), _em("기본 공격을 못 쓰게 된다")]),
		_line("막힌 쪽 %s에는 빨간 %s 가 뜬다. X가 사라질 때까지 그놈은 주먹을 못 쓴다" % [_em("뒤쪽"), _bubble.icon("parry")]),
		_line("내가 %s을 할 테니 때리는 %s에 맞춰 %s! 너의 %s을 보여줘라 알겠나!?" % [_em("기본 공격"), _em("순간"), _k("down"), _em("패링")],
			{"phase": "parry", "goal": "교관이 때리는 순간에 맞춰 %s 키로 막으세요" % _key("down")}),
		_line("좋다 %s" % _em("신병")),
		# --- 대시 ---
		_line("이제 %s다. %s 또는 %s를 %s 눌러라" % [_em("대시"), _k("left"), _k("right"), _em("빠르게 2번 연속")],
			{"gate": "dash", "goal": "%s %s 또는 %s %s 로 대시하세요" % [L, L, R, R]}),
		_line("대시도 %s %s가 있으니 %s하도록! 대시 %s 로 뒤쪽에 표시된다" % [_em("쿨타임"), _em(dash_cd), _em("주의"), _bubble.icon("dash")]),
		# --- 스킬 / 궁극기 ---
		_line("이제 %s이다. 캐릭터마다 %s 둘, %s 하나가 있다" % [_em("스킬"), _em("스킬"), _em("궁극기")]),
		_line("%s는 %s이다. 네 %s으로 나를 쏴 봐라!" % [_k("skill_1"), _em("1번 스킬"), _em("테이저건")],
			{"phase": "skill1", "goal": "%s 키로 테이저건을 쏴서 교관을 맞히세요" % _key("skill_1")}),
		_line("%s는 %s이다. %s을 던져 봐라!" % [_k("skill_2"), _em("2번 스킬"), _em("돌")],
			{"phase": "skill2", "goal": "%s 키로 돌을 던져 교관을 맞히세요" % _key("skill_2")}),
		_line("스킬은 %s이 길다. 대전에선 화면 위 %s이 다시 차오르면 쓸 수 있다" % [_em("쿨타임"), _em("스킬 칸")]),
		_line("%s은 %s다. 대전에선 쓰는 순간 %s이 나온다. 써 봐라!" % [_k("ultimate"), _em("궁극기"), _em("컷인 연출")],
			{"phase": "ult", "goal": "%s 키로 궁극기를 쓰세요" % _key("ultimate")}),
		_line("%s을 든 동안은 기본 공격이 %s 세진다. 맵마다 %s로 쓰는 %s도 있으니 맵 설명을 잘 봐라" % [_em("경관봉"), _em("두 배로"), _k("map_skill"), _em("맵 전용 스킬")]),
		# --- 마지막 테스트 ---
		_line("이제 %s를 할 거다 %s!" % [_em("마지막 테스트"), _em("신병")]),
		_line("이등병 키자.. 아니;; %s와 싸워서 %s 악!" % [_em("이등병 똥자루"), _em("이겨라")],
			{"phase": "fight", "goal": "이등병 똥자루를 쓰러뜨리세요"}),
		_line("좋다. 이 정도면 이제 %s은 끝난 것 같다. 캐릭터·맵 설명은 메뉴의 %s에서 볼 수 있다" % [_em("훈련"), _em("가이드")]),
	]
	return lines

func _process(delta: float) -> void:
	if not (_fighter and is_instance_valid(_fighter)):
		return
	var camera: Camera2D = $Camera2D
	# 카메라는 항상 플레이어에 고정(교관 쪽으로 묶거나 보간하면 갑자기 순간이동처럼 튄다)
	camera.global_position.x = _fighter.global_position.x
	# 맵 가운데(x=0)에 박힌 태양이 카메라가 움직이는 만큼 화면에서 반대로 미묘하게 밀린다
	if _sun_mat:
		var shift := clampf(camera.global_position.x / sun_map_half_width, -1.0, 1.0) * sun_parallax
		_sun_mat.set_shader_parameter("sun_pos", Vector2(_sun_base.x - shift, _sun_base.y))
	if _fighter.global_position.y > fall_limit_y:
		_fighter.global_position = $PlayerSpawn.global_position
		_fighter.velocity = Vector2.ZERO
	_update_tutorial(delta)
	_update_gates(delta)
	_update_parkour(delta)
	_update_parry_phase(delta)
	_update_skill_phase(delta)
	_update_fight()

## 교관 가까이(기본 500px) 오면 대사를 시작한다. 이후 진행은 스페이스바로(_advance).
func _update_tutorial(_delta: float) -> void:
	if _intro_active or _bubble == null or _step != Step.NONE:
		return
	if _instructor and is_instance_valid(_instructor) and _fighter.global_position.distance_to(_instructor.global_position) <= instructor_trigger_range:
		_step = Step.TALK
		_line_idx = 0
		_say_current()

## 지금 줄의 gate / phase / goal (없으면 "")
func _gate(idx: int = _line_idx) -> String:
	return str(_lines[idx].get("gate", "")) if idx >= 0 and idx < _lines.size() else ""

func _phase(idx: int = _line_idx) -> String:
	return str(_lines[idx].get("phase", "")) if idx >= 0 and idx < _lines.size() else ""

func _goal(idx: int = _line_idx) -> String:
	return str(_lines[idx].get("goal", "")) if idx >= 0 and idx < _lines.size() else ""

## 지금 줄을 말풍선에 띄운다. 스페이스로 넘어가는 줄은 ▼과 "스페이스를 누르세요"(첫 줄은 바로, 그 뒤론 한참 안 넘길 때)를 켠다.
## 행동으로 넘어가는 줄(gate)은 둘 다 끄고 대신 목표 알약을 띄운다(글자가 다 나온 뒤 — `_update_gates`).
func _say_current() -> void:
	var gate := _gate()
	var press_delay := -1.0 if gate != "" else (0.0 if _line_idx == 0 else PRESS_HINT_DELAY)
	_bubble.say(_lines[_line_idx]["text"], gate == "", press_delay)
	_move_wait = 0.0
	_dash_armed = false
	_show_goal("")
	# 파쿠르 줄을 띄우는 순간 발판이 솟는다
	if gate == "parkour":
		_start_parkour()

## 스페이스바: 타이핑 중이면 즉시 다 띄운다. 행동으로 넘어가는 줄은 스페이스로 안 넘어간다.
## 실습(phase)이 붙은 줄은 스페이스에 말풍선이 닫히고 실습이 시작된다 — 실습이 끝나야 다음 줄
func _advance() -> void:
	if _step != Step.TALK or _bubble == null:
		return
	if _bubble.is_typing():
		_bubble.finish_typing()
		return
	if _gate() != "":
		return
	match _phase():
		"hit":
			_start_hit_phase()
		"parry":
			_start_parry_phase()
		"skill1", "skill2", "ult":
			_start_skill_phase(_phase())
		"fight":
			_start_fight()
		_:
			_go_next_line()

## 실습을 시작할 때 공통 — 말풍선을 치우고 목표 알약을 띄운다
func _begin_phase() -> void:
	if _bubble:
		_bubble.close()
	_show_goal(_goal())

## 다음 줄로 넘어간다(마지막 줄을 넘기면 튜토리얼 끝 → 메인 메뉴).
func _go_next_line() -> void:
	_show_goal("")
	_line_idx += 1
	if _line_idx >= _lines.size():
		_step = Step.DONE
		get_tree().change_scene_to_file("res://ui/MainMenu.tscn")
		return
	_say_current()

## 행동으로 넘어가는 줄들(gate) — 글자가 다 나온 뒤부터 목표 알약을 띄우고 행동을 기다린다
func _update_gates(delta: float) -> void:
	if _step != Step.TALK or _bubble == null:
		return
	var gate := _gate()
	if gate == "" or gate == "parkour":
		return
	if _bubble.is_typing():
		_move_wait = 0.0
		_dash_armed = false
		return
	_show_goal(_goal())
	match gate:
		"move":
			# 읽기도 전에 넘어가지 않게 말이 끝나고 잠시 기다린다
			_move_wait += delta
			if _move_wait >= MOVE_GATE_DELAY and (Input.is_action_pressed("p1_left") or Input.is_action_pressed("p1_right")):
				_go_next_line()
		"jump":
			if not _fighter.is_on_floor():
				_go_next_line()
		"guard":
			if _fighter.is_guarding:
				_go_next_line()
		"dash":
			# 이전 대시의 쿨 때문에 바로 넘어가지 않게, 쿨이 비어 있는 걸 본 뒤 새로 쿨이 돌기 시작하면 대시한 것
			var ratio: float = _fighter.dash_cooldown_ratio()
			if not _dash_armed:
				_dash_armed = ratio >= 1.0
			elif ratio < 1.0:
				_go_next_line()

# --- 파쿠르 발판 ---

## 파쿠르 줄을 띄우면: 나무 발판 1·2단이 땅에서 먼지와 함께 솟아오른다.
func _start_parkour() -> void:
	if _parkour_active or _parkour_done:
		return
	_parkour_active = true
	_reached_p2 = false
	_platform1 = _make_platform(platform1_x, platform1_rise, PLATFORM_TEX_1, PLATFORM_GEO_1)
	_platform2 = _make_platform(platform2_x, platform2_rise, PLATFORM_TEX_2, PLATFORM_GEO_2)
	_raise_platform(_platform1, 0.0)
	_raise_platform(_platform2, 0.18)

## 나무 발판 하나를 만들어 맵에 붙인다. 위·아래·옆이 다 막히는 통짜 벽이고, 땅까지 이어진다.
## rise = 상판 윗면이 땅 윗면에서 얼마나 위인가(px). 바디 원점 = 상판 윗면(서는 면).
## 그림 한 장 높이로 rise를 못 채우면 같은 그림을 아래로 여러 장 쌓는다(맨 아래 장은 땅 밑으로 들어가 땅 그림이 덮는다).
## geo = [상판 윗면 y(px), 상판 왼끝 x, 상판 오른끝 x, 그림 맨아랫변 y] — 그림마다 달라 따로 받는다.
func _make_platform(x: float, rise: float, tex_path: String, geo: Array) -> StaticBody2D:
	var plank_top: float = geo[0]
	var art_h_px: float = geo[3] - geo[0]                      # 상판 윗면 ~ 그림 맨아래
	var plank_w_px: float = geo[2] - geo[1]
	var tex_scale: float = platform_plank_width / plank_w_px   # 상판이 목표 폭이 되게 그림을 줄인다
	var piece_h: float = art_h_px * tex_scale                  # 한 장이 차지하는 화면 높이
	var tex: Texture2D = load(tex_path)
	var body := StaticBody2D.new()
	body.position = Vector2(x, ground_top_y - rise)
	var count: int = maxi(1, ceili(rise / piece_h - 0.001))
	var center_x_px: float = (geo[1] + geo[2]) * 0.5
	for i in count:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		# 위쪽 투명 여백을 잘라 상판 윗면부터 시작 → 쌓아도 틈 없이 이어진다
		spr.region_enabled = true
		spr.region_rect = Rect2(0.0, plank_top, tex.get_width(), art_h_px)
		spr.scale = Vector2(tex_scale, tex_scale)
		spr.position = Vector2(-center_x_px * tex_scale, float(i) * piece_h)
		body.add_child(spr)
	# 충돌: 상판 윗면부터 땅 밑까지 꽉 찬 상자(원웨이 아님 — 밑에서 점프해도 못 지나감)
	var coll_h: float = rise + PLATFORM_COLL_BURY
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(platform_plank_width * 0.96, coll_h)
	col.shape = shape
	col.position = Vector2(0.0, coll_h * 0.5)   # 상자 윗면 = 원점(상판 윗면)
	body.add_child(col)
	add_child(body)
	# 땅 그림보다 먼저 그려서 아래쪽을 땅이 덮게 한다 → 땅에 박힌 것처럼 이어지고, 솟고 가라앉을 때 땅속에서 나온다
	move_child(body, $Ground.get_index())
	return body

## 발판을 땅 밑에서 최종 높이까지 솟아오르게 한다(올라오는 순간 먼지)
func _raise_platform(body: StaticBody2D, delay: float) -> void:
	var final_y: float = body.position.y
	body.position.y = ground_top_y + PLATFORM_HIDE_DEPTH   # 땅 밑에 숨겨 시작(땅 그림이 덮는다)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(_spawn_dust.bind(Vector2(body.position.x, ground_top_y), 1.8))
	tw.tween_property(body, "position:y", final_y, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 파쿠르 진행 확인: 발판2에 올라선 뒤, 왼쪽으로 떨어져 땅에 닿으면 발판이 사라진다.
## 꼭대기에 올라서면 목표 문구도 "왼쪽으로 내려오세요"로 바뀐다
func _update_parkour(_delta: float) -> void:
	if not _parkour_active:
		return
	if not _reached_p2:
		if _bubble and not _bubble.is_typing():
			_show_goal(_goal())
		if _standing_on(_platform2):
			_reached_p2 = true
			_show_goal("좋다! 이제 왼쪽 땅으로 내려오세요")
		return
	# 발판2를 밟은 뒤 → 발판2 왼쪽 땅에 내려서면(발판 왼쪽 끝보다 더 왼쪽의 진짜 땅) 발판이 사라진다
	if _fighter.is_on_floor() and not _standing_on(_platform1) and not _standing_on(_platform2):
		if _fighter.global_position.x <= platform2_x - platform_plank_width * 0.5:
			_finish_parkour()

## 플레이어가 지금 이 바디 위에 서 있나(바닥 충돌 상대로 확인 — 발 위치를 추정하지 않는다)
func _standing_on(body: Node) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if not _fighter.is_on_floor():
		return false
	for i in _fighter.get_slide_collision_count():
		var c := _fighter.get_slide_collision(i)
		if c and c.get_collider() == body:
			return true
	return false

## 발판이 흔들리다 땅속으로 가라앉아 사라지고, 잠시 뒤 다음 대사로 이어진다
func _finish_parkour() -> void:
	_parkour_active = false
	_parkour_done = true
	_show_goal("")
	_sink_platform(_platform1)
	_sink_platform(_platform2)
	# 가라앉는 연출이 끝날 즈음 다음 대사("기본 공격은 F키다")로 넘어간다
	Timers.after(self, 0.9, _go_next_line)

func _sink_platform(body: StaticBody2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	# 가라앉는 동안엔 밟지 못하게 충돌을 끈다(플레이어는 땅으로 떨어진다)
	for child in body.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	var base_x: float = body.position.x
	var tw := create_tween()
	# 좌우로 흔들
	for off in [8.0, -8.0, 6.0, -6.0, 3.0, -3.0, 0.0]:
		tw.tween_property(body, "position:x", base_x + off, 0.05)
	# 땅속으로 쑥 + 먼지
	tw.tween_callback(_spawn_dust.bind(Vector2(base_x, ground_top_y), 1.6))
	tw.tween_property(body, "position:y", ground_top_y + PLATFORM_HIDE_DEPTH, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(body.queue_free)

## 먼지 한 뭉치를 맵에 붙인다(순수 장식)
func _spawn_dust(pos: Vector2, power: float) -> void:
	var dust := LandDust.new()
	add_child(dust)
	dust.global_position = pos
	dust.setup(power)
	dust.z_index = 2   # 배경에 안 가리게(기본 LandDust는 -1이라 숲 뒤로 숨는다)

# --- 교관(황근출) ---

## 진짜 황근출 Fighter를 교관 자리에 세운다. 컨트롤러 없이 가만히 서서 대사만 하고,
## 실습 구간 전까진 무적이라 안 맞는다. 때리면 3타 콤보로 날아갔다 원래 자리로 돌아온다.
func _spawn_instructor() -> void:
	var scene: PackedScene = load("res://characters/hwanggeunchul/Hwanggeunchul.tscn")
	_instructor = scene.instantiate()
	# 안 죽게 체력을 아주 크게 (튜토리얼엔 KO 로직이 없지만 체력바가 비지 않게도)
	var stats: CharacterStats = _instructor.stats.duplicate()
	stats.max_hp = 100000
	_instructor.stats = stats
	add_child(_instructor)
	_instructor.z_index = 2   # 나무 발판(z1)보다 앞에 그려지게
	_instructor_home = $InstructorSpawn.global_position
	_instructor.global_position = _instructor_home
	_instructor.facing = -1.0          # 플레이어(왼쪽)를 본다
	_instructor.immovable = true       # 플레이어가 밀어도 안 밀린다(플레이어만 밀려남)
	_set_instructor_hittable(false)    # 실습 구간 전엔 때려도 아무 반응이 없다
	var rig := _instructor.get_node_or_null("Visual")
	if rig:
		rig.idle_gestures = false       # 가만히 있을 때 몸짓 안 함
	if _instructor.has_signal("damaged"):
		_instructor.damaged.connect(_on_instructor_damaged)

## 교관을 매 물리 프레임 직접 굴린다(컨트롤러가 없으니 apply_physics를 여기서 부른다).
## 평소엔 제자리, 맞아 날아가는 중엔 그대로 두고, 멈추면 원래 자리로 걸어 돌아온다.
func _drive_instructor(delta: float) -> void:
	if _instructor == null or not is_instance_valid(_instructor):
		return
	if _instructor.is_finisher_flying():
		_instr_launched = true
		_instructor.apply_physics(delta)
		return
	# 날아갔다 멈췄으면 원래 자리로 걸어 돌아간다(그동안 때려도 반응 없음)
	if _instr_launched and not _instr_returning:
		_instr_returning = true
		_set_instructor_hittable(false)
	if _instr_returning:
		var dir: float = signf(_instructor_home.x - _instructor.global_position.x)
		if absf(_instructor.global_position.x - _instructor_home.x) <= 8.0:
			_instructor.global_position.x = _instructor_home.x
			_instructor.move(0.0)
			_instructor.facing = -1.0
			_instr_returning = false
			_instr_launched = false
			_instructor.apply_physics(delta)
			_on_instructor_home()
			return
		# 돌아오는 길에 플레이어가 서 있으면 밀어낸다 — 교관은 immovable이라 Fighter가 알아서 플레이어만 민다
		_instructor.move(dir)
		_instructor.apply_physics(delta)
		return
	# 패링 시범: 플레이어에게 다가가 기본공격
	if _parry_active:
		_drive_parry(delta)
		return
	# 평소: 제자리
	_instructor.move(0.0)
	_instructor.apply_physics(delta)

## 교관을 때릴 수 있게/없게 한다. 끄면 피격 판정(Hurtbox)이 아예 안 닿아서 스파크·데미지 숫자·화면 흔들림·
## 플레이어 콤보 진행이 전혀 없다(그냥 허공을 친 것). 신호 처리 중에도 불리므로 set_deferred로 바꾼다
func _set_instructor_hittable(on: bool) -> void:
	if _instructor == null or not is_instance_valid(_instructor):
		return
	var hurtbox := _instructor.get_node_or_null("Hurtbox") as Area2D
	if hurtbox:
		hurtbox.set_deferred("monitorable", on)
	_instructor.is_invincible = not on   # 판정 말고 직접 피해를 주는 경로도 막는다

## 교관이 원래 자리로 돌아왔다 → 때리기 시연 또는 패링 시범을 끝낸다.
## 스킬 실습 중에 주먹 3타로 날려 보냈으면 돌아온 뒤 다시 맞을 수 있게만 한다(실습은 계속)
func _on_instructor_home() -> void:
	if _hit_active:
		_finish_hit_phase()
	elif _parry_returning:
		_finish_parry_phase()
	elif _skill_phase != "":
		_set_instructor_hittable(true)

## 교관이 맞았다 — 스킬 실습 중이고 방금 스킬을 쐈으면 그 스킬로 맞힌 것으로 친다
func _on_instructor_damaged(_amount: int, _knockback: Vector2) -> void:
	if (_skill_phase == "skill1" or _skill_phase == "skill2") and _skill_fired_for >= 0.0 and _skill_fired_for <= SKILL_HIT_WINDOW:
		_finish_skill_phase()

# --- 교관 때리기 시연 ---

## "나를 쳐 봐라"를 넘긴 순간: 말풍선을 치우고 교관을 때릴 수 있게 한다
func _start_hit_phase() -> void:
	if _hit_active:
		return
	_hit_active = true
	_begin_phase()
	_set_instructor_hittable(true)

## 교관이 날아갔다 돌아온 뒤: 다시 때려도 반응 없게 돌리고 다음 대사로 넘어간다
func _finish_hit_phase() -> void:
	_hit_active = false
	_set_instructor_hittable(false)
	_go_next_line()

# --- 패링 시범 ---

## "너의 패링을 보여줘라"를 넘긴 순간: 말풍선을 치우고 교관이 플레이어에게 다가와 2.5초마다 기본공격을 한다.
## 플레이어가 방어로 막으면 성공 — 교관 등 뒤에 패링 X 아이콘이 뜨고, 잠시 뒤 원래 자리로 돌아가 다음 대사로 넘어간다.
## 못 막으면 실제로 맞는다(데미지·넉백). 체력은 바닥나지 않게 채워 준다
func _start_parry_phase() -> void:
	if _parry_active or _parry_returning:
		return
	_parry_active = true
	_parry_succeeded = false
	_parry_timer = PARRY_FIRST_DELAY
	_begin_phase()

## 시범 중 교관: 플레이어 쪽을 보고, 너무 멀면 다가가고, 사거리 안이면 PARRY_ATTACK_INTERVAL초마다 기본공격을 낸다.
## 공격이 방어에 막혀 잠기면(is_basic_attack_locked) 패링 성공
func _drive_parry(delta: float) -> void:
	var dx: float = _fighter.global_position.x - _instructor.global_position.x
	if dx != 0.0:
		_instructor.facing = signf(dx)
	if _parry_succeeded:
		# X 아이콘이 보이도록 잠시 서 있다가 돌아간다
		_instructor.move(0.0)
		_parry_wait -= delta
		if _parry_wait <= 0.0:
			_parry_active = false
			_parry_returning = true
			_instr_returning = true
		_instructor.apply_physics(delta)
		return
	_instructor.move(signf(dx) if absf(dx) > PARRY_FOLLOW_GAP else 0.0)
	_parry_timer -= delta
	if _parry_timer <= 0.0 and absf(dx) <= PARRY_ATTACK_RANGE:
		_instructor.use_basic_attack()
		_parry_timer = PARRY_ATTACK_INTERVAL
	if _instructor.is_basic_attack_locked():
		_parry_succeeded = true
		_parry_wait = PARRY_SUCCESS_WAIT
		_show_goal("패링 성공! 교관 뒤의 빨간 X를 보세요")
	_instructor.apply_physics(delta)

## 시범 중 플레이어는 죽지 않게 — 체력이 바닥에 가까우면 가득 채운다
func _keep_player_alive() -> void:
	if _fighter == null or not is_instance_valid(_fighter):
		return
	var floor_hp: int = int(_fighter.stats.max_hp * PARRY_SAFE_HP_RATIO)
	if _fighter.current_hp < floor_hp:
		_fighter.current_hp = _fighter.stats.max_hp

## 패링 시범 진행(매 프레임): 시범 중엔 플레이어 체력을 지킨다
func _update_parry_phase(_delta: float) -> void:
	if _parry_active:
		_keep_player_alive()

## 교관이 원래 자리로 돌아왔다 → 패링 시범을 끝내고 다음 대사("좋다 신병")로 넘어간다
func _finish_parry_phase() -> void:
	_parry_returning = false
	_go_next_line()

# --- 스킬 / 궁극기 실습 ---

## 실습할 스킬 노드("skill1"/"skill2"/"ult")
func _phase_skill(phase: String) -> Skill:
	match phase:
		"skill1":
			return _fighter.skill_1
		"skill2":
			return _fighter.skill_2
		"ult":
			return _fighter.skill_ultimate
	return null

## 스킬 줄을 넘긴 순간: 말풍선을 치우고, 쿨을 비워 바로 쓸 수 있게 하고(궁은 시작부터 쿨이 돌고 있다), 교관을 맞을 수 있게 한다
func _start_skill_phase(phase: String) -> void:
	if _skill_phase != "":
		return
	var skill := _phase_skill(phase)
	if skill == null:
		# 이 캐릭터에 그 스킬이 없으면 실습을 건너뛴다
		_go_next_line()
		return
	_skill_phase = phase
	_skill_fired_for = -1.0
	skill.cooldown_left = 0.0
	_skill_was_ready = true
	_begin_phase()
	_set_instructor_hittable(phase != "ult")

## 실습 진행(매 프레임): 쿨이 "비어 있다 → 돈다"로 바뀌면 쐈다고 본다.
## 스킬1·2는 헛쏘면 쿨을 짧게 깎아 금방 다시 쏘게 하고, 교관이 맞으면(`_on_instructor_damaged`) 끝.
## 궁은 쓰기만 하면 잠시 뒤 끝(경봉을 뽑는 모션을 보여 준다)
func _update_skill_phase(delta: float) -> void:
	if _skill_phase == "":
		return
	var skill := _phase_skill(_skill_phase)
	if skill == null:
		_finish_skill_phase()
		return
	var is_ready: bool = skill.cooldown_left <= 0.0
	if _skill_was_ready and not is_ready:
		_skill_fired_for = 0.0
	_skill_was_ready = is_ready
	if _skill_fired_for >= 0.0:
		_skill_fired_for += delta
	if _skill_phase == "ult":
		if _skill_fired_for >= ULT_FINISH_WAIT:
			_finish_skill_phase()
		return
	if not is_ready:
		skill.cooldown_left = minf(skill.cooldown_left, SKILL_RETRY_COOLDOWN)
	# 쏜 지 한참 지나도 안 맞았으면 "다시"를 알려 준다
	if _skill_fired_for > SKILL_HIT_WINDOW:
		_show_goal("빗나갔다! 교관을 보고 다시 쏘세요")

func _finish_skill_phase() -> void:
	if _skill_phase == "":
		return
	_skill_phase = ""
	_skill_fired_for = -1.0
	_set_instructor_hittable(false)
	_go_next_line()

# --- 마지막 테스트: 이등병 똥자루와 싸움 ---

## "싸워서 이겨라"를 넘긴 순간: 말풍선을 치우고 플레이어 옆(교관 반대쪽)에 똥자루가 먼지와 함께 나타나 싸움을 건다
func _start_fight() -> void:
	if _fight_active:
		return
	_fight_active = true
	_begin_phase()
	var side: float = -signf(_instructor_home.x - _fighter.global_position.x)
	if side == 0.0:
		side = -1.0
	var x: float = _fighter.global_position.x + side * FIGHT_SPAWN_GAP
	if absf(x) > 1100.0:
		x = _fighter.global_position.x - side * FIGHT_SPAWN_GAP
	_player_start_x = _fighter.global_position.x
	_enemy_start_x = x
	_enemy = load(FIGHT_SCENE).instantiate()
	# add_child 전에 stats를 바꿔 끼워야 _ready()가 새 값으로 시작한다(stats는 공유 Resource라 복제)
	var stats: CharacterStats = _enemy.stats.duplicate()
	stats.attack_multiplier *= FIGHT_DAMAGE_SCALE
	_enemy.stats = stats
	add_child(_enemy)
	_enemy.z_index = 2
	_enemy.global_position = Vector2(x, $PlayerSpawn.global_position.y)
	_enemy.facing = signf(_fighter.global_position.x - x)
	var rig := _enemy.get_node_or_null("Visual")
	if rig:
		rig.idle_gestures = false
	var ai := AIController.new()
	ai.target = _fighter   # 안 정하면 가장 가까운 Fighter(교관)를 상대로 잡을 수 있다
	ai.knows_follow_ups = false
	ai.reaction_time = lerpf(0.45, ai.reaction_time, FIGHT_AI_SKILL)
	ai.guard_react_chance = lerpf(0.10, ai.guard_react_chance, FIGHT_AI_SKILL)
	ai.dodge_react_chance = lerpf(0.15, ai.dodge_react_chance, FIGHT_AI_SKILL)
	ai.bait_chance = 0.0
	ai.dash_approach_distance = lerpf(520.0, ai.dash_approach_distance, FIGHT_AI_SKILL)
	_enemy.add_child(ai)
	_spawn_dust(Vector2(x, ground_top_y), 2.0)
	_fighter.heal(_fighter.stats.max_hp, false)
	_set_instructor_bystander(true)
	_build_fight_hud()

## 싸움 진행(매 프레임): 체력바를 갱신하고, 똥자루가 쓰러지면 승리 / 플레이어가 쓰러지면 둘 다 채우고 다시
func _update_fight() -> void:
	if not _fight_active or _enemy == null or not is_instance_valid(_enemy):
		return
	_update_fight_hud()
	if _enemy.current_hp <= 0:
		_win_fight()
	elif _fighter.current_hp <= 0:
		_restart_fight()

## 졌다: 둘 다 체력을 가득 채우고 처음 자리로 돌려 다시 싸운다
func _restart_fight() -> void:
	for f in [_fighter, _enemy]:
		f.cancel_finisher_flight()
		f.heal(f.stats.max_hp, false)
		f.velocity = Vector2.ZERO
	_fighter.global_position.x = _player_start_x
	_enemy.global_position.x = _enemy_start_x
	_enemy.facing = signf(_fighter.global_position.x - _enemy_start_x)
	_spawn_dust(Vector2(_enemy_start_x, ground_top_y), 1.6)
	_show_goal("쓰러졌다! 체력을 채웠으니 다시 싸우세요")

## 이겼다: 똥자루의 AI를 떼고 먼지와 함께 사라지게 한 뒤 마지막 대사로
func _win_fight() -> void:
	_fight_active = false
	_show_goal("")
	for child in _enemy.get_children():
		if child is AIController:
			child.queue_free()
	_enemy.move(0.0)
	_fighter.heal(_fighter.stats.max_hp, false)
	var enemy := _enemy
	var tw := create_tween()
	tw.tween_interval(FIGHT_WIN_WAIT * 0.5)
	tw.tween_callback(func(): _spawn_dust(Vector2(enemy.global_position.x, ground_top_y), 1.8))
	tw.tween_property(enemy, "modulate:a", 0.0, FIGHT_WIN_WAIT * 0.5)
	tw.tween_callback(enemy.queue_free)
	tw.tween_callback(_end_fight)

func _end_fight() -> void:
	_enemy = null
	_set_instructor_bystander(false)
	if _fight_hud and is_instance_valid(_fight_hud):
		_fight_hud.queue_free()
	_fight_bars.clear()
	_go_next_line()

## 싸우는 동안 교관을 구경꾼으로: 몸을 뚫고 지나가고(밀어내기 없음) 맞지도 않는다
func _set_instructor_bystander(on: bool) -> void:
	if _instructor == null or not is_instance_valid(_instructor):
		return
	_instructor.pass_through_fighters = on
	_instructor.immovable = not on
	_set_instructor_hittable(false)

## 화면 위 체력바 두 개(왼쪽 신병 / 오른쪽 이등병 똥자루)
func _build_fight_hud() -> void:
	_fight_hud = CanvasLayer.new()
	_fight_hud.layer = 50
	add_child(_fight_hud)
	_fight_bars.clear()
	var font: Font = load("res://font/강한육군 Bold.ttf")
	var names := ["신병", "이등병 똥자루"]
	var colors := [Color(0.25, 0.75, 0.35), Color(0.85, 0.25, 0.2)]
	for i in 2:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.size = Vector2(420, 26)
		bar.position = Vector2(40.0 if i == 0 else 1280.0 - 40.0 - 420.0, 52.0)
		bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if i == 0 else ProgressBar.FILL_END_TO_BEGIN
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.1, 0.12, 0.85)
		bg.set_border_width_all(3)
		bg.border_color = Color(0.05, 0.05, 0.06)
		bg.set_corner_radius_all(6)
		var fill := StyleBoxFlat.new()
		fill.bg_color = colors[i]
		fill.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		_fight_hud.add_child(bar)
		var label := Label.new()
		label.text = names[i]
		if font:
			label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.06))
		label.add_theme_constant_override("outline_size", 6)
		label.size = Vector2(420, 30)
		label.position = bar.position + Vector2(0, -34)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		_fight_hud.add_child(label)
		_fight_bars.append(bar)
	_update_fight_hud()

func _update_fight_hud() -> void:
	if _fight_bars.size() < 2:
		return
	var fs := [_fighter, _enemy]
	for i in 2:
		_fight_bars[i].max_value = fs[i].stats.max_hp
		_fight_bars[i].value = maxi(fs[i].current_hp, 0)

# --- 목표 알림(흰 알약) ---

## 화면 아래 가운데 목표 문구. 빈 문자열이면 숨긴다. 글자 폭에 맞춰 알약 폭이 늘어난다
func _show_goal(text: String) -> void:
	if _goal_panel == null or not is_instance_valid(_goal_panel):
		return
	if text == "":
		_goal_panel.visible = false
		return
	if _goal_label.text != text or not _goal_panel.visible:
		_goal_label.text = text
		var font: Font = _goal_label.get_theme_font("font")
		var fs: int = _goal_label.get_theme_font_size("font_size")
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 48.0
		_goal_panel.size = Vector2(w, 54)
		_goal_panel.position = Vector2(-w * 0.5, -150)
		_goal_panel.visible = true

## 목표 알약(흰 알약 + 글자)을 화면 아래 가운데에 만든다(처음엔 숨김)
func _build_goal_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.92)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.12, 0.12, 0.14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.size = Vector2(320, 54)
	panel.position = Vector2(-160, -150)
	panel.visible = false
	layer.add_child(panel)
	var label := Label.new()
	var font: Font = load("res://font/강한육군 Bold.ttf")
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.14))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(label)
	_goal_panel = panel
	_goal_label = label

func _spawn_player() -> void:
	# 기본공격 3타 콤보가 필요해 경찰(주인공)로 플레이한다
	var scene: PackedScene = load("res://characters/police/Police.tscn")
	_fighter = scene.instantiate()
	# add_child 전에 stats를 바꿔 끼워야 _ready()가 새 값으로 시작한다
	var stats: CharacterStats = _fighter.stats.duplicate()
	stats.move_speed = player_move_speed
	_fighter.stats = stats
	add_child(_fighter)
	_fighter.z_index = 2   # 나무 발판(z1)보다 앞에 그려지게
	# 입장 연출: 왼쪽 끝에서 투명하게 시작해 스폰 자리까지 걸어오며 나타난다. 컨트롤러는 도착 후에 붙인다
	_intro_target_x = $PlayerSpawn.position.x
	_fighter.global_position = Vector2(intro_start_x, $PlayerSpawn.global_position.y)
	var visual := _fighter.get_node_or_null("Visual") as CanvasItem
	if visual:
		visual.modulate.a = 0.0
	_intro_active = true
	$Camera2D.global_position.x = _fighter.global_position.x

## 연출 동안은 컨트롤러 없이 직접 오른쪽으로 걷게 하고(apply_physics는 컨트롤러가 없으니 여기서 호출),
## 걸어온 거리에 비례해 투명도를 올린다. 목표 x에 닿으면 멈추고 조작을 넘긴다
func _physics_process(delta: float) -> void:
	# 교관은 컨트롤러가 없으니 매 물리 프레임 직접 굴린다(입장 연출 중에도)
	_drive_instructor(delta)
	if not _intro_active:
		return
	if not (_fighter and is_instance_valid(_fighter)):
		return
	_fighter.move(1.0)
	_fighter.apply_physics(delta)
	var visual := _fighter.get_node_or_null("Visual") as CanvasItem
	if visual:
		var progress := (_fighter.global_position.x - intro_start_x) / maxf(intro_fade_distance, 1.0)
		visual.modulate.a = clampf(progress, 0.0, 1.0)
	if _fighter.global_position.x >= _intro_target_x:
		_end_intro()

## 입장 연출을 끝내고 플레이어 조작을 시작한다
func _end_intro() -> void:
	_intro_active = false
	_fighter.global_position.x = _intro_target_x
	_fighter.velocity.x = 0.0
	_fighter.move(0.0)
	var visual := _fighter.get_node_or_null("Visual") as CanvasItem
	if visual:
		visual.modulate.a = 1.0
	var controller := PlayerController.new()
	controller.player_index = 1
	_fighter.add_child(controller)

## ESC = 일시정지 메뉴(대전과 같은 것). 스페이스바 = 교관 대사 넘기기
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if get_tree().paused:
			return
		var menu: Node = load("res://ui/PauseMenu.tscn").instantiate()
		menu.show_story_list = false
		menu.show_title = false
		add_child(menu)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_advance()
