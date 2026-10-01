extends Node2D

## 방어·대시 쿨타임을 캐릭터 등 뒤(바라보는 방향 반대편)에 작은 원형 파이로 보여준다.
## 쿨이 도는 동안만 보이고, 다시 쓸 수 있게 될수록 12시 방향부터 시계 방향으로 차오른다
## (HUD 스킬 아이콘처럼 "차오르면 준비 완료"). 다 차면 살짝 커졌다가 사라진다.
## **슬롯:** 먼저 쿨이 시작된 것이 1번 슬롯(맨 위), 그 사이에 시작된 것은 아래 2번 슬롯에 쌓인다.
## 위의 것이 끝나면 아래 것이 위로 미끄러져 올라간다.
## Fighter의 자식으로 붙는다 — Fighter 루트는 좌우로 안 뒤집히므로(뒤집히는 건 Visual) facing을 보고 직접 반대편에 놓는다.
## 그림 파일 없이 코드로 그린다. 부채꼴은 draw_primitive 삼각형으로 — 다각형 하나로 그리면
## 비율이 0 근처일 때 "triangulation failed"가 쏟아진다(CLAUDE.md 참고)

## 1번 슬롯 원의 중심(캐릭터 원점 기준). x는 등 쪽으로 떨어진 거리라 양수로 둔다 — 바라보는 방향의 반대편에 놓이게
## facing 부호를 곱해 쓴다. y는 가슴 높이
@export var offset: Vector2 = Vector2(42, -22)
## 슬롯 사이 세로 간격(px). 다음 슬롯은 이만큼 아래
@export var slot_spacing: float = 19.0
## 방향을 바꿀 때 반대편으로 옮겨 가는 빠르기(클수록 빠름). 0이면 바로 건너뛴다
@export var side_follow_speed: float = 18.0
## 슬롯이 비어 위로 올라갈 때의 빠르기
@export var slot_follow_speed: float = 14.0
## 반지름(px)
@export var radius: float = 8.0
## 바탕(아직 안 찬 부분) 색
@export var back_color: Color = Color(0.1, 0.12, 0.18, 0.55)
## 방어 파이 색 — 보호막과 같은 하늘색
@export var guard_color: Color = Color(0.55, 0.85, 1.0, 0.95)
## 대시 파이 색 — 라임
@export var dash_color: Color = Color(0.7, 1.0, 0.2, 0.95)
## 테두리 색·굵기 (밝은 배경에서도 보이게)
@export var edge_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var edge_width: float = 1.5
## 다 찼을 때 커졌다 사라지는 시간(초)
@export var ready_pop_time: float = 0.25

## 표시할 쿨타임 하나 — Fighter에서 비율을 읽어 올 메서드 이름과 색
class Pie:
	var method: String
	var color: Color
	var ratio: float = 0.0
	var pop_left: float = 0.0
	var cooling: bool = false
	## 지금 그려지는 슬롯 위치(0 = 1번 슬롯). 목표 슬롯으로 미끄러진다
	var slot_pos: float = 0.0

	func _init(m: String, c: Color) -> void:
		method = m
		color = c

## 모든 파이 / 지금 화면에 떠 있는 파이(쿨이 먼저 시작된 순서 = 슬롯 순서)
var _pies: Array[Pie] = []
var _shown: Array[Pie] = []
## 지금 놓인 쪽(-1 = 왼쪽, 1 = 오른쪽). 방향을 바꾸면 반대편으로 미끄러져 간다
var _side: float = -1.0

func _ready() -> void:
	z_index = 6   # 보호막(5)보다 앞
	visible = false
	_pies = [Pie.new("guard_cooldown_ratio", guard_color), Pie.new("dash_cooldown_ratio", dash_color)]

func _process(delta: float) -> void:
	var fighter := get_parent()
	if fighter == null:
		return
	# 타이틀 구경 모드는 HUD를 다 숨기므로 이것도 숨긴다
	if GameState.game_mode == "attract":
		visible = false
		return
	var target_side: float = -signf(fighter.facing) if fighter.facing != 0.0 else _side
	if not visible or side_follow_speed <= 0.0:
		_side = target_side   # 숨어 있다 나타날 땐 처음부터 등 뒤에
	else:
		_side = lerpf(_side, target_side, 1.0 - exp(-side_follow_speed * delta))

	for pie in _pies:
		if not fighter.has_method(pie.method):
			continue
		var ratio: float = fighter.call(pie.method)
		var cooling: bool = ratio < 1.0
		if cooling:
			if not pie.cooling and not _shown.has(pie):
				# 새로 쿨이 시작됨 — 맨 아래 빈 슬롯에 바로 나타난다
				pie.slot_pos = float(_shown.size())
				_shown.append(pie)
			pie.ratio = ratio
			pie.pop_left = 0.0
		elif pie.cooling:
			pie.ratio = 1.0
			pie.pop_left = ready_pop_time
		pie.cooling = cooling
		if pie.pop_left > 0.0:
			pie.pop_left = maxf(pie.pop_left - delta, 0.0)
	# 다 끝난 파이를 빼고, 남은 것들은 위로 미끄러져 슬롯을 채운다
	_shown = _shown.filter(func(p: Pie) -> bool: return p.cooling or p.pop_left > 0.0)
	var k: float = 1.0 - exp(-slot_follow_speed * delta)
	for i in _shown.size():
		_shown[i].slot_pos = lerpf(_shown[i].slot_pos, float(i), k)
	visible = not _shown.is_empty()
	if visible:
		queue_redraw()

func _draw() -> void:
	for pie in _shown:
		_draw_pie(pie)

func _draw_pie(pie: Pie) -> void:
	var center := Vector2(offset.x * _side, offset.y + pie.slot_pos * slot_spacing)
	var r: float = radius
	var alpha: float = 1.0
	if pie.pop_left > 0.0:
		# 다 찬 순간: 1 -> 1.4배로 커지며 흐려진다
		var t: float = 1.0 - pie.pop_left / maxf(ready_pop_time, 0.001)
		r *= 1.0 + 0.4 * t
		alpha = 1.0 - t
	var back := back_color
	back.a *= alpha
	draw_circle(center, r, back)
	if pie.ratio > 0.001:
		var fill := pie.color
		fill.a *= alpha
		_draw_sector(center, r, pie.ratio, fill)
	var edge := edge_color
	edge.a *= alpha
	draw_arc(center, r, 0.0, TAU, 32, edge, edge_width, true)

## 12시 방향부터 시계 방향으로 ratio만큼의 부채꼴을 삼각형 조각으로 칠한다
func _draw_sector(center: Vector2, r: float, ratio: float, color: Color) -> void:
	var steps: int = maxi(2, int(ceil(32.0 * ratio)))
	var start: float = -PI * 0.5
	var sweep: float = TAU * ratio
	var prev := center + Vector2(cos(start), sin(start)) * r
	for i in range(1, steps + 1):
		var a: float = start + sweep * float(i) / float(steps)
		var p := center + Vector2(cos(a), sin(a)) * r
		draw_primitive(PackedVector2Array([center, prev, p]), PackedColorArray([color, color, color]), PackedVector2Array())
		prev = p
