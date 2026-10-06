class_name CombatHUD
extends CanvasLayer

## 화면 좌/우에 FighterPanel 2개, 가운데 위에 남은 시간 박스와 라운드 스코어를 배치하는 HUD.
## 맵 조립 스크립트(Stage)가 setup()으로 두 Fighter를 연결하고, 매 프레임 update_round_info()로 갱신한다
@onready var _p1_panel: FighterPanel = $P1Panel
@onready var _p2_panel: FighterPanel = $P2Panel
@onready var _round_label: Label = $RoundLabel
@onready var _timer_frame: ColorRect = $TimerFrame
@onready var _timer_label: Label = $TimerFrame/TimerBox/TimerLabel
## 스코어보드(평행사변형 세 칸). 있으면 점수·시간을 이쪽으로 보내고 옛 표시는 숨긴다
@onready var _score_board: ScoreBoard = get_node_or_null("ScoreBoard")

@export_group("선수 판 자리")
## 켜면 두 선수 판(체력·스킬)을 **화면 위쪽 좌·우 구석**으로 올린다.
## 놀이터처럼 아래쪽에 발판·모래밭이 깔린 맵은 평소 자리(아래)에 두면 바닥 기믹을 가린다(2026-10-01 사용자 요청).
## 맵이 직접 정한다 — `Stage.hud_panels_top`이 `set_panels_top()`으로 넣어 준다
@export var panels_top: bool = false
## 위로 올렸을 때 화면 구석에서 띄우는 간격(px, x = 좌우 / y = 위).
## ⚠️ x를 76보다 작게 주면 **왼쪽 위 일시정지 버튼**(자리 22, 크기 54)에 P1 판이 깔린다
@export var panels_top_margin: Vector2 = Vector2(90, 12)
## 아래 자리일 때 씬에 저장된 자리보다 **이만큼 더 내린다**(px). 맵이 정한다 — `Stage.hud_panels_drop`
@export var panels_drop: float = 0.0

## 씬에 저장된 아래 자리의 (offset_top, offset_bottom) — 내리기를 여러 번 불러도 겹쳐 내려가지 않게 기억해 둔다
var _bottom_offsets: Vector2 = Vector2.ZERO

func _ready() -> void:
	_bottom_offsets = Vector2(_p1_panel.offset_top, _p1_panel.offset_bottom)
	_apply_panel_layout()

## 맵이 부른다 — 판을 위 구석으로 올리거나 씬에 저장된 아래 자리로 둔다
func set_panels_top(on: bool) -> void:
	panels_top = on
	_apply_panel_layout()

## 맵이 부른다 — 아래 자리에서 판을 더 내린다
func set_panels_drop(px: float) -> void:
	panels_drop = px
	_apply_panel_layout()

## 판을 위 구석으로 옮기거나, 아래 자리에서 panels_drop만큼 내린다.
## 둘 다 안 쓰면(위 끔·내림 0) 씬에 저장된 아래쪽 자리 그대로라 다른 맵은 이 기능이 생기기 전과 같다
func _apply_panel_layout() -> void:
	if _p1_panel == null or _p2_panel == null:
		return
	if not panels_top:
		for panel in [_p1_panel, _p2_panel]:
			panel.offset_top = _bottom_offsets.x + panels_drop
			panel.offset_bottom = _bottom_offsets.y + panels_drop
		return
	# 판 크기는 씬에 잡아 둔 값을 그대로 쓴다(앵커가 좌/우로 달라도 오른쪽-왼쪽이 곧 너비다)
	var w: float = _p1_panel.offset_right - _p1_panel.offset_left
	var h: float = _p1_panel.offset_bottom - _p1_panel.offset_top
	var mx: float = panels_top_margin.x
	var my: float = panels_top_margin.y
	_p1_panel.anchor_top = 0.0
	_p1_panel.anchor_bottom = 0.0
	_p1_panel.offset_left = mx
	_p1_panel.offset_right = mx + w
	_p1_panel.offset_top = my
	_p1_panel.offset_bottom = my + h
	_p2_panel.anchor_top = 0.0
	_p2_panel.anchor_bottom = 0.0
	_p2_panel.offset_right = -mx
	_p2_panel.offset_left = -mx - w
	_p2_panel.offset_top = my
	_p2_panel.offset_bottom = my + h

func setup(p1: Fighter, p2: Fighter) -> void:
	_p1_panel.bind(p1, false, 1)
	_p2_panel.bind(p2, true, 2)

## 라운드 스코어와(있다면) 남은 시간을 화면 중앙 상단에 표시한다.
## 시간은 GameState.time_limit_seconds(방 설정에서 고른 값)에서 Stage가 깎아 내려주는 값이라
## 여기서는 따로 계산하지 않는다. 시간 제한 없음(0)이면 시간 박스 자체를 숨긴다
func update_round_info(p1_wins: int, p2_wins: int, time_left: float) -> void:
	# 스코어보드를 달아 뒀으면 거기 한 군데에 점수와 시간이 다 들어간다 —
	# 옛 표시(가운데 숫자판 + 라운드 글자)는 숨긴다. 스코어보드를 빼면 예전 모습으로 돌아간다
	if _score_board:
		_score_board.set_score(p1_wins, p2_wins)
		_score_board.set_time(time_left)
		_round_label.visible = false
		_timer_frame.visible = false
		return
	_round_label.text = "%d : %d" % [p1_wins, p2_wins]
	_timer_frame.visible = time_left > 0.0
	if time_left > 0.0:
		_timer_label.text = str(ceili(time_left))
		# 10초 이하로 남으면 숫자가 빨개져서 눈에 띈다
		_timer_label.modulate = Color(1, 0.35, 0.3) if time_left <= 10.0 else Color(1, 1, 1)
