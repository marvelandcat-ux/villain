class_name StoryFadeScene
extends Control

## 스토리 모드의 한 장면 — **들어오는 전환 -> 잠깐 머묾 -> 나가는 전환 -> 다음 장면.**
##
## (2026-09-12) 옛 스토리 모드(에피소드 선택 -> 캐릭터 선택 -> 대전 -> 개과천선 대사 -> 클리어)를 싹 걷어내고
## 새로 짜는 스토리 모드의 뼈대다. 장면마다 이 스크립트를 붙이고 인스펙터에서 시간·전환·다음 장면만 바꿔 쓴다.
## 화면 내용은 씬에 자유롭게 올리면 되고, **맨 마지막 자식 `Fade`(검은 ColorRect)**가 알파로 가렸다 걷었다 한다 —
## 트리 맨 아래라서 다른 걸 아무리 올려도 그 위를 덮는다.
##
## 화면 전환 (2026-09-12 사용자가 고른 추천안):
##  - 들어올 때: 앞 장면이 `out_transition = CROSSFADE`로 넘겨주면, 앞 장면의 마지막 화면(찍어 둔 사진)을 맨 위에 덮고
##    `crossfade_time` 동안 투명하게 해서 **겹쳐 사라지게(크로스페이드)** 한다. 아니면 검은 화면에서 밝아진다(`fade_in_time`)
##  - 나갈 때: BLACK = 검게 덮인 뒤(`fade_out_time`) 넘어감 / CROSSFADE = 지금 화면을 찍어 두고 바로 넘어감
##    — 검은 화면은 "시간이 흘렀다·다른 장면이다"로 읽혀서, 경찰서 도착 -> 안으로 들어가는 이어진 흐름엔 크로스페이드가 맞다
##  - `reveal`: 들어오는 전환이 끝난 뒤 **순서대로** 나타날 노드들(인물 -> 대화창). 아래에서 조금 올라오며 나타난다.
##    배경·인물·대화창이 한꺼번에 뜨는 것보다 이 순서가 비주얼 노벨에서 자연스럽다
## **ESC를 누르면 일시정지 화면(`ui/PauseMenu.tscn`)이 뜬다**(2026-09-15 사용자 요청 — 예전엔 바로 메인 메뉴로 나갔다).
## 같은 이유로 **화면 왼쪽 위에 일시정지 버튼(`ui/PauseButton.tscn`)을 자동으로 붙인다** —
## ESC만 있으면 처음 하는 사람은 멈출 방법을 모른다는 피드백이 있었다(2026-09-15).
## 장면마다 놓을 필요 없이 여기서 한 번에 붙이므로, 새 스토리 장면을 만들어도 저절로 생긴다
## 메인 메뉴로 나가는 길은 그 화면의 "메인메뉴로" 항목에 있다.

enum Transition { BLACK, CROSSFADE }

## 왼쪽 위 일시정지 버튼 (모든 스토리 장면에 자동으로 붙는다)
const PAUSE_BUTTON_SCENE := "res://ui/PauseButton.tscn"
## 오른쪽 아래 "계속 누르세요" 화살표 (대화창이 입력을 기다리는 동안만 깜빡인다)
const CONTINUE_INDICATOR_SCENE := "res://ui/ContinueIndicator.tscn"

## 검은 화면이 걷히는 시간(초) — 앞 장면이 크로스페이드로 넘겨주지 않았을 때
@export var fade_in_time: float = 1.2
## 다 보인 채로 머무는 시간(초). 들어오는 전환이 끝난 뒤부터 센다
@export var hold_time: float = 1.5
## 다시 검게 덮이는 시간(초) — out_transition이 BLACK일 때
@export var fade_out_time: float = 1.2
## 다 끝나면 넘어갈 장면. **비워두면 들어온 채로 멈춰 있는다**(다음 장면이 아직 없는 마지막 장면)
@export_file("*.tscn") var next_scene: String = ""
## 다음 장면이 **대전 맵**일 때 붙일 캐릭터(비워두면 대전 준비를 안 한다). Stage가 GameState를 보고 소환하며,
## `GameState.game_mode == "story"`라 P2는 AI가 조종한다
@export_file("*.tscn") var battle_p1: String = ""
@export_file("*.tscn") var battle_p2: String = ""
## 대전 규칙 — 먼저 몇 라운드를 따면 이기는지, 라운드 제한시간(초, 0이면 무제한)
@export var battle_rounds: int = 2
@export var battle_time_limit: int = 120
## **그 대전에서 이겼을 때 이어서 갈 장면**(2026-09-13). Stage가 최종 승리 판정에서 여기로 넘어간다.
## 비워두면 예전처럼 결과창(재시도/메뉴)에서 멈춘다
@export_file("*.tscn") var battle_win_scene: String = ""
## 대화창(DialogueBox)이나 장소 카드(LocationCard)를 지정하면 그게 끝나야 나간다(hold_time도 지나야 함). 비우면 시간만 본다
@export var dialogue: NodePath
## 다음 장면으로 넘길 때 전환 방식
@export var out_transition: Transition = Transition.BLACK
## 앞 장면이 크로스페이드로 넘겨줬을 때 겹쳐 사라지는 시간(초)
@export var crossfade_time: float = 0.7
## **이 장면에 닿으면 지금 진행 중인 에피소드를 "클리어"로 기록한다**(2026-09-15).
## 이야기의 마지막 장면에만 켜 두면 된다 — 기록은 user://settings.cfg에 남아서
## 다음에 켰을 때 일시정지 화면의 스토리 목록에서 자물쇠가 풀린다.
## 장면 끝이 아니라 **_ready에서** 기록하는 이유: 마지막 장면은 next_scene이 비어 있어서
## "끝났다"는 시점이 따로 없고, 여기까지 왔으면 이미 다 본 것이기 때문이다
@export var clears_story: bool = false
## 들어오는 전환이 끝난 뒤 순서대로 나타날 노드들 (Node2D 또는 Control)
@export var reveal: Array[NodePath] = []
## reveal 노드 하나가 나오기 시작한 뒤 다음 노드가 나오기까지(초)
@export var reveal_gap: float = 0.35
## 하나가 나타나는 데 걸리는 시간(초)
@export var reveal_time: float = 0.3
## 나타날 때 아래에서 올라오는 거리(px)
@export var reveal_rise: float = 18.0
## 화면 왼쪽 위에 일시정지 버튼을 띄울지. 대사 없이 빠르게 지나가는 연출 장면에서 거슬리면 끄면 된다
@export var show_pause_button: bool = true
## 대화창이 입력을 기다릴 때 오른쪽 아래에 깜빡이는 화살표를 띄울지.
## **`dialogue`를 지정한 장면에서만 뜬다** — 대사 없이 지나가는 연출 장면엔 나올 일이 없다
@export var show_continue_indicator: bool = true
## (임시) 테스트용 — **S 키를 누르면 다음 장면으로 바로 건너뛴다.**
## 한 번 껐다가 2026-09-29에 다시 켰다(사용자 요청) — 스토리를 손볼 때마다 앞 장면을 다 보고 있을 수가 없어서다.
## 여기서 기본값을 켜 두면 열두 장면 전부에 한 번에 걸린다. 특정 장면만 빼고 싶으면 그 장면에서 이 값을 끄면 된다.
##
## **연출만 건너뛴다 — 대전은 안 건너뛴다.** 대전까지 넘어가는 건 맵 루트의 `Stage.debug_story_skip_key`인데
## 그건 계속 꺼 둔다(S가 P1 방어 키라서, 켜 두면 싸우다 방어할 때마다 전투가 끝나 버린다).
## 스토리를 다 만들면 이 기능도 같이 지울 것
@export var debug_skip_key: bool = true
## 에디터에선 보이게 두고(배치 조정용) **게임이 시작될 때 숨길** 노드들 — 대화창 명령(@show, @stamp)으로 나중에 나타난다.
## 에디터 눈 아이콘으로 켜고 끈 채 저장해도 게임에선 항상 숨긴 채 시작한다
@export var hide_on_start: Array[NodePath] = []

enum Step { FADE_IN, HOLD, FADE_OUT, DONE }

## 크로스페이드용 — 앞 장면이 넘어가기 직전에 찍어 둔 화면. static이라 장면이 바뀌어도 남는다.
## 오래된 사진(메뉴를 거쳐 온 경우 등)은 쓰지 않도록 찍은 시각도 같이 둔다
static var _carry: Texture2D = null
static var _carry_msec: int = 0

@onready var _fade: ColorRect = $Fade

var _step: int = Step.FADE_IN
var _t: float = 0.0
var _intro_time: float = 0.0
var _overlay: TextureRect = null
var _reveal_items: Array[CanvasItem] = []
var _reveal_pos: Array[Vector2] = []

func _ready() -> void:
	# Fade는 씬 파일에선 투명으로 둔다(에디터에서 장면이 보이게) — 실제 시작 알파는 아래에서 정한다
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if show_pause_button and ResourceLoader.exists(PAUSE_BUTTON_SCENE):
		add_child(load(PAUSE_BUTTON_SCENE).instantiate())
	_add_continue_indicator()
	for path in hide_on_start:
		var hidden_item: CanvasItem = get_node_or_null(path) as CanvasItem
		if hidden_item == null:
			push_warning("StoryFadeScene: hide_on_start 노드를 못 찾았다 — %s" % path)
			continue
		hidden_item.visible = false
	for path in reveal:
		var item: CanvasItem = get_node_or_null(path) as CanvasItem
		if item == null or not (item is Node2D or item is Control):
			push_warning("StoryFadeScene: reveal 노드를 못 찾았거나 위치가 없는 노드다 — %s" % path)
			continue
		var pos: Vector2 = item.get("position")
		_reveal_items.append(item)
		_reveal_pos.append(pos)
		item.visible = true   # 배치하느라 에디터 눈 아이콘으로 꺼 둔 채 저장했어도 게임에선 나타나게
		item.modulate.a = 0.0
		item.set("position", pos + Vector2(0.0, reveal_rise))
	if clears_story:
		GameState.mark_story_cleared(GameState.current_story_id)
	if _carry != null and Time.get_ticks_msec() - _carry_msec < 3000:
		# 앞 장면 마지막 화면을 맨 위(마지막 자식)에 덮는다 — 첫 프레임부터 덮여 있어서 새 장면이 번쩍 보이지 않는다
		_overlay = TextureRect.new()
		_overlay.texture = _carry
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_overlay.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(_overlay)
		_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fade.color.a = 0.0
		_intro_time = crossfade_time
	else:
		_fade.color.a = 1.0
		_intro_time = fade_in_time
	_carry = null

func _process(delta: float) -> void:
	_t += delta
	match _step:
		Step.FADE_IN:
			var k: float = clampf(_t / maxf(_intro_time, 0.001), 0.0, 1.0)
			if _overlay != null:
				_overlay.modulate.a = 1.0 - k * k * (3.0 - 2.0 * k)
			else:
				_fade.color.a = 1.0 - k
			if _t >= _intro_time:
				if _overlay != null:
					_overlay.queue_free()
					_overlay = null
				_start_reveal()
				_go(Step.HOLD)
		Step.HOLD:
			if next_scene == "":
				_go(Step.DONE)   # 다음 장면이 없으면 여기서 끝 — 보이는 채로 멈춘다
			elif _t >= hold_time and _dialogue_done():
				if out_transition == Transition.CROSSFADE:
					_go(Step.DONE)
					_open_next(true)
				else:
					_go(Step.FADE_OUT)
		Step.FADE_OUT:
			_fade.color.a = clampf(_t / maxf(fade_out_time, 0.001), 0.0, 1.0)
			if _t >= fade_out_time:
				_go(Step.DONE)
				_open_next(false)

## reveal 노드들을 순서대로, 아래에서 살짝 올라오며 나타나게
func _start_reveal() -> void:
	for i in _reveal_items.size():
		var item: CanvasItem = _reveal_items[i]
		var delay: float = i * reveal_gap
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(item, "modulate:a", 1.0, reveal_time).set_delay(delay)
		tw.tween_property(item, "position", _reveal_pos[i], reveal_time).set_delay(delay) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## `dialogue`에 지정한 노드가 끝났는지 — DialogueBox(대화창)든 LocationCard(장소 카드)든 is_finished()만 있으면 된다
func _dialogue_done() -> bool:
	if dialogue.is_empty():
		return true
	var node: Node = get_node_or_null(dialogue)
	if node == null or not node.has_method("is_finished"):
		return true
	return bool(node.call("is_finished"))

func _go(step: int) -> void:
	_step = step
	_t = 0.0

func _open_next(crossfade: bool) -> void:
	# 경로가 틀렸으면 조용히 멈추는 대신 이유를 남긴다 (화면이 멈춰 버리면 왜 그런지 알 길이 없다)
	if not ResourceLoader.exists(next_scene):
		push_warning("StoryFadeScene: 다음 장면을 못 찾았다 — %s" % next_scene)
		return
	_setup_battle()
	if crossfade:
		# 지금 화면을 찍어 두면 다음 장면이 _ready에서 맨 위에 덮고 서서히 투명하게 한다
		var img: Image = get_viewport().get_texture().get_image()
		_carry = ImageTexture.create_from_image(img)
		_carry_msec = Time.get_ticks_msec()
	get_tree().change_scene_to_file(next_scene)

## 다음 장면이 대전 맵이면 GameState에 대결 정보를 담아 둔다 (Stage가 이걸 보고 캐릭터를 소환한다).
## **정식 진행과 디버그 건너뛰기(S) 둘 다 여기를 거쳐야 한다** — 예전엔 S로 건너뛰면 이걸 안 거쳐서
## 대전에 엉뚱한 캐릭터(선택 화면 기본값)가 나왔다
func _setup_battle() -> void:
	if battle_p1 == "" or battle_p2 == "":
		return
	GameState.p1_character_path = battle_p1
	GameState.p2_character_path = battle_p2
	GameState.selected_map_path = next_scene
	GameState.rounds_to_win = battle_rounds
	GameState.time_limit_seconds = battle_time_limit
	GameState.story_next_scene = battle_win_scene
	GameState.reset_round_wins()

func _unhandled_input(event: InputEvent) -> void:
	if debug_skip_key and event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and not key.echo and (key.keycode == KEY_S or key.physical_keycode == KEY_S):
			if next_scene != "" and ResourceLoader.exists(next_scene):
				_carry = null
				_setup_battle()
				get_viewport().set_input_as_handled()
				get_tree().change_scene_to_file(next_scene)   # 임시 건너뛰기 — 페이드 없이 바로
			return
	if event.is_action_pressed("ui_cancel"):
		# **ESC는 메인 메뉴로 나가는 게 아니라 일시정지 화면을 띄운다**(2026-09-15 사용자 요청).
		# 메인 메뉴로 나가는 길은 그 화면의 "메인메뉴로" 항목에 그대로 있다 — 실수로 ESC를 눌러
		# 보던 이야기가 통째로 날아가지 않게 한 단계를 둔 것이다.
		# 일시정지 화면이 `get_tree().paused`를 켜면 이 장면은 멈추므로(process_mode 기본값)
		# 페이드·대사 타자도 그 자리에서 멈췄다가 "계속하기"에서 이어진다
		get_viewport().set_input_as_handled()
		add_child(load("res://ui/PauseMenu.tscn").instantiate())

## 오른쪽 아래 "계속 누르세요" 화살표를 붙이고 대화창과 연결한다.
##
## **`Fade`보다 앞에 끼워 넣는다** — 그냥 add_child 하면 트리 맨 뒤라 검은 페이드 위에 그려져서,
## 화면이 어두워지는 동안에도 화살표만 둥둥 떠 있다.
##
## 대화창(`dialogue`)이 없는 장면에는 안 붙인다 — 지켜볼 대상이 없어서 영원히 안 뜬다
func _add_continue_indicator() -> void:
	if not show_continue_indicator or not ResourceLoader.exists(CONTINUE_INDICATOR_SCENE):
		return
	var box: Node = get_node_or_null(dialogue)
	if box == null or not box.has_method("is_waiting_input"):
		return
	var indicator: Node = load(CONTINUE_INDICATOR_SCENE).instantiate()
	add_child(indicator)
	move_child(indicator, _fade.get_index())
	indicator.set_watch_target(box)
