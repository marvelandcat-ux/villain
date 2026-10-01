@tool
extends Node2D

## 자세(포즈) 편집용 미리보기 — 궁 중 **방어·돌진 자세를 씬 안에서 직접 끌어다 잡기** 위한 틀.
##
## 이 씬에 놓인 조각의 **이름**을 `BodyRig`가 그대로 찾아 읽어서 게임에 쓴다.
## 읽는 이름은 FootL / FootR / Body / HandL / HandR / Head / Recorder / Danso 여덟 개이고,
## 쓰는 값은 **위치(position)와 각도(rotation)뿐**이다 — 크기(scale)는 게임 쪽 값을 그대로 둔다
## (걷기·머리 돌리기 같은 다른 연출이 크기를 건드리기 때문에, 여기서 바꾸면 서로 싸운다).
## 이름을 바꾸거나 지우면 그 조각은 "안 건드림"이 되어 게임에서 평소 자세 그대로 남는다.
##
## 에디터에서만 도는 일이 두 가지 있다.
##  1. 악기걸이(HandLHold/HandRHold)를 손의 위치·각도에 붙여 둔다 — 게임이 매 프레임 하는 일과 똑같다.
##     그래서 손을 옮기면 악기가 따라가고, 악기만 돌리면 "손 기준 각도"가 바뀐다.
##  2. 땅 선과 가운데 선을 그려 준다 — 발이 땅에 붙었는지, 몸이 가운데에 있는지 눈으로 보려고.
## 둘 다 게임에는 안 나간다(`Engine.is_editor_hint()`로 막는다)

## 발바닥이 닿는 높이(리그 기준 y). 지하철 아저씨는 발이 y 27쯤에 있고 발 그림 아래쪽이 33쯤이다
@export var ground_y: float = 33.0
## **눈으로 보려고 키우는 배율.** 리그는 키가 70px밖에 안 돼서 그냥 두면 에디터에서 깨알만 하다.
## 루트 scale만 키우는 것이라 조각들의 **위치 숫자는 그대로**다 — `BodyRig`는 이 배율을 안 읽는다.
## 더 크게/작게 보고 싶으면 이 값만 바꾸면 된다
@export var preview_scale: float = 8.0:
	set(value):
		preview_scale = maxf(value, 0.1)
		scale = Vector2(preview_scale, preview_scale)
## 캐릭터 뒤에 깔아 주는 배경판 — 검은 리코더처럼 어두운 조각이 에디터 배경에 묻히는 걸 막는다
@export var show_backdrop: bool = true
@export var backdrop_color: Color = Color(0.58, 0.62, 0.70, 1.0)
## 안내선을 그릴지 (에디터에서만 보인다)
@export var show_guides: bool = true
## 안내선 반쪽 너비(px) — 좌우로 이만큼씩 그린다
@export var guide_half_width: float = 90.0
## 땅 선 색과 가운데 선 색
@export var ground_color: Color = Color(0.10, 0.22, 0.34, 0.75)
@export var center_color: Color = Color(0.72, 0.18, 0.30, 0.45)

func _ready() -> void:
	# 열자마자 보기 좋은 크기로 맞춘다(에디터에서만 — 게임엔 이 씬이 아예 안 올라간다)
	if Engine.is_editor_hint():
		scale = Vector2(preview_scale, preview_scale)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	_follow_hand("HandL", "HandLHold")
	_follow_hand("HandR", "HandRHold")
	queue_redraw()

## 악기걸이를 손에 붙인다 — 둘 중 하나가 없으면 조용히 넘어간다
func _follow_hand(hand_name: String, hold_name: String) -> void:
	var hand: Node2D = get_node_or_null(hand_name) as Node2D
	var hold: Node2D = get_node_or_null(hold_name) as Node2D
	if hand == null or hold == null:
		return
	hold.position = hand.position
	hold.rotation = hand.rotation

func _draw() -> void:
	# 에디터 여부를 안 따진다 — 이 씬은 게임 트리에 아예 안 올라간다(`BodyRig.read_pose`가
	# 복제본에서 좌표만 베끼고 바로 버린다). 그래서 그냥 그려도 게임에는 한 점도 안 나온다
	if not show_guides:
		return
	var w: float = guide_half_width
	# 배경판 — 자식(캐릭터)보다 먼저 그려지므로 저절로 뒤에 깔린다
	if show_backdrop:
		draw_rect(Rect2(Vector2(-w, -w * 0.85), Vector2(w * 2.0, w * 0.85 + ground_y + 14.0)), backdrop_color, true)
	# 땅 선 — 발바닥이 여기 닿아야 공중에 떠 보이지 않는다
	draw_line(Vector2(-w, ground_y), Vector2(w, ground_y), ground_color, 1.5)
	# 가운데 선 — 몸 중심(x=0)
	draw_line(Vector2(0.0, -w), Vector2(0.0, ground_y + 8.0), center_color, 1.0)
	# 10px 자눈금 — 눈대중으로 몇 px 옮겼는지 세기 쉽게
	var step: float = 10.0
	var x: float = -w
	while x <= w:
		var tall: bool = is_zero_approx(fmod(absf(x), 50.0))
		draw_line(Vector2(x, ground_y), Vector2(x, ground_y - (6.0 if tall else 3.0)), ground_color, 1.0)
		x += step
