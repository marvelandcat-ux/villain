class_name GymWrapGate
extends Node2D

## **층 넘나드는 자리 표시** — 맵 양 끝에 **어두운 통로**를 깔고 **위 화살표**를 띄운다
## (2026-10-07 사용자: "보통 가장자리에 무언가를 놓거나 검은색으로 만들지 않나?").
##
## `GymWrap`은 화면 밖으로 나가면 **반대쪽 반대 층**에서 나오게 해 준다. 그런데 아무 표시가 없으면
## 사람이 갑자기 사라졌다 나타나는 게 **버그처럼 보인다.** 그래서 "여기는 밖으로 나가는 자리고,
## 나가면 올라간다"를 **쓰기 전에** 알려 줘야 한다.
##
## 통로는 **네 군데**다 — 왼쪽/오른쪽 x 1층/2층. 양방향으로 다 통하니까 네 곳 다 표시한다.
##
## ⚠️ **넘어가는 선은 `GymWrap`에게 물어본다**(`edges()`). 여기서 따로 적어 두면 둘이 어긋나서
## "통로까지 걸어갔는데 안 넘어가" 또는 "통로 밖에서 넘어가" 같은 일이 생긴다

## 같이 맞춰 쓸 `GymWrap` 노드(비워 두면 형제 중 `Wrap`을 찾는다)
@export var wrap_path: NodePath = ^"../Wrap"

@export_group("통로")
## 통로 가로 폭(px). 넘어가는 선에서 **맵 안쪽으로** 이만큼이다
@export var gate_width: float = 112.0
## 통로 색 — 벽이 밝아서 거의 검게 둬야 "구멍"으로 읽힌다
@export var gate_color: Color = Color(0.1, 0.11, 0.13, 1.0)
## 폭 중 **진하게 유지할 몫**(나머지는 안쪽으로 가며 사라진다).
## 딱 떨어지는 네모로 두면 벽에 검은 판을 붙인 것처럼 보여서, 안쪽만 흐린다
@export_range(0.0, 1.0, 0.05) var solid_ratio: float = 0.55
## 통로 바깥 테두리 굵기(0이면 안 그린다). 그림체가 굵은 선이라 맞춰 둔다
@export var edge_width: float = 3.0
@export var edge_color: Color = Color(0.07, 0.07, 0.085, 1.0)

@export_group("층 높이")
## 1층 바닥 윗면 / 1층 천장(2층 판 아랫면)
@export var ground_y: float = 621.0
@export var lower_ceiling_y: float = 346.0
## 2층 바닥 윗면 / 2층 천장
@export var upper_y: float = 301.0
@export var upper_ceiling_y: float = 67.0

@export_group("위 화살표")
## 화살표를 그릴지
@export var arrow_on: bool = true
## 화살표 하나의 가로 폭·높이(px)와 선 굵기
@export var arrow_size: Vector2 = Vector2(30.0, 15.0)
@export var arrow_width: float = 4.0
## 몇 개를 쌓을지와 간격(px)
@export var arrow_count: int = 3
@export var arrow_gap: float = 19.0
## 제일 아래 화살표가 바닥에서 뜨는 높이(px)
@export var arrow_lift: float = 52.0
@export var arrow_color: Color = Color(0.85, 0.88, 0.96, 1.0)
## 한 번 훑고 올라가는 데 걸리는 시간(초). 0이면 안 움직이고 다 같이 켜져 있다
@export var arrow_cycle: float = 1.25
## 통로 **가쪽 끝에서** 화살표까지의 거리(px). 진한 쪽에 둬야 또렷하다
@export var arrow_inset: float = 56.0

var _wrap: Node = null
var _time: float = 0.0

func _ready() -> void:
	_wrap = get_node_or_null(wrap_path)
	# ⚠️ **z_index를 건드리지 않는다.** 배경(`DecoBack`)이 CanvasGroup z=0이라 -1을 주면 그 뒤로 숨는다.
	# 씬에서 `Ground` 뒤·`Equipment` 앞에 놓여 있어서, 기본값 그대로가 배경 위·기구와 사람 아래다
	set_process(arrow_on and arrow_cycle > 0.0)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

## 넘어가는 선 (왼쪽, 오른쪽). `GymWrap`이 있으면 그쪽 값을 그대로 쓴다
func _edges() -> Vector2:
	if _wrap and _wrap.has_method("edges"):
		return _wrap.call("edges")
	# 혼자 띄워 봤을 때를 위한 기본값 — 화면이 있으면 화면 끝으로 잡는다
	var cam: Camera2D = get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam == null:
		return Vector2(200.0, 1520.0)
	var half: float = get_viewport().get_visible_rect().size.x * 0.5 / maxf(cam.zoom.x, 0.01)
	return Vector2(cam.global_position.x - half - 20.0, cam.global_position.x + half + 20.0)

func _draw() -> void:
	var side: Vector2 = _edges()
	# [바깥 x, 안쪽으로 가는 방향, 바닥 y, 천장 y]
	for floor_y in [Vector2(ground_y, lower_ceiling_y), Vector2(upper_y, upper_ceiling_y)]:
		_gate(side.x, 1.0, floor_y.x, floor_y.y)
		_gate(side.y, -1.0, floor_y.x, floor_y.y)

## 통로 하나. `dir`은 맵 안쪽 방향(+1 오른쪽 / -1 왼쪽)
func _gate(edge_x: float, dir: float, floor_y: float, ceiling_y: float) -> void:
	var top: float = minf(floor_y, ceiling_y)
	var bottom: float = maxf(floor_y, ceiling_y)
	if bottom - top < 4.0:
		return
	var solid_x: float = edge_x + dir * gate_width * solid_ratio
	var far_x: float = edge_x + dir * gate_width
	draw_rect(Rect2(minf(edge_x, solid_x), top, absf(solid_x - edge_x), bottom - top), gate_color)
	# ⚠️ 흐려지는 쪽은 **꼭짓점 색으로 한 번에** 그린다. 세로로 쪼개 칸마다 투명도를 주면
	# 칸 경계가 줄무늬로 드러난다(2026-10-07 실측)
	var clear := Color(gate_color.r, gate_color.g, gate_color.b, 0.0)
	draw_polygon(
		PackedVector2Array([Vector2(solid_x, top), Vector2(far_x, top),
			Vector2(far_x, bottom), Vector2(solid_x, bottom)]),
		PackedColorArray([gate_color, clear, clear, gate_color]))
	if edge_width > 0.0:
		# 바닥·천장에 닿는 선만 긋는다 — 세로 선을 그으면 통로가 닫힌 문처럼 보인다
		draw_line(Vector2(edge_x, top), Vector2(solid_x, top), edge_color, edge_width)
		draw_line(Vector2(edge_x, bottom), Vector2(solid_x, bottom), edge_color, edge_width)
	if arrow_on:
		_arrows(edge_x + dir * arrow_inset, bottom)

## 위로 훑고 올라가는 화살표 더미
func _arrows(x: float, bottom: float) -> void:
	var half: float = arrow_size.x * 0.5
	for i in arrow_count:
		var y: float = bottom - arrow_lift - arrow_gap * float(i)
		var a: float = 1.0
		if arrow_cycle > 0.0:
			# 아래부터 차례로 밝아졌다 꺼진다 — 그래야 "위로" 가는 게 읽힌다
			var phase: float = fposmod(_time / arrow_cycle - float(i) / float(maxi(arrow_count, 1)), 1.0)
			a = 0.25 + 0.75 * maxf(0.0, 1.0 - phase * 2.2)
		var col := Color(arrow_color.r, arrow_color.g, arrow_color.b, arrow_color.a * a)
		# ^ 모양 두 줄
		draw_line(Vector2(x - half, y), Vector2(x, y - arrow_size.y), col, arrow_width, true)
		draw_line(Vector2(x, y - arrow_size.y), Vector2(x + half, y), col, arrow_width, true)
