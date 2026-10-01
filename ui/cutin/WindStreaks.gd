@tool
class_name WindStreaks
extends Node2D

## 열차가 **바람을 가르며** 지나갈 때 같이 흐르는 속도선 — 가로로 길게 늘어난 줄이 진행 방향으로 쭉 흘러간다.
## 그림이 따로 필요 없다. `_draw()`로만 그리고, 보이는 세기는 밖에서 `power`(0~1)로 정한다 —
## 컷인이 열차 진행도에 맞춰 올렸다 내리므로 **여기서는 시간을 세지 않는다**(열차가 없을 때 혼자 흐르면 이상하다)

## 줄 개수
@export var count: int = 28:
	set(v):
		count = v
		_streaks.clear()
		queue_redraw()
## 줄이 흩어지는 범위(px) — 이 노드 자리가 가운데다. 열차보다 위아래로 넉넉해야 바람처럼 보인다
@export var area: Vector2 = Vector2(2600, 660):
	set(v):
		area = v
		_streaks.clear()
		queue_redraw()
## 줄 길이의 최소~최대(px). 길이가 제각각이라야 "그어 놓은 줄"이 아니라 바람으로 보인다
@export var length_range: Vector2 = Vector2(160, 700)
## 줄 굵기의 최소~최대(px)
@export var thickness_range: Vector2 = Vector2(2.0, 8.0)
## 흐르는 빠르기(px/초)와 방향(-1이면 왼쪽으로 — 열차가 가는 쪽과 맞출 것)
@export var speed: float = 3400.0
@export var direction: float = -1.0
## 줄 색 — 알파는 **가장 셀 때(power 1)** 의 값이다
@export var color: Color = Color(1, 1, 1, 0.3)

@export_group("에디터")
## 에디터에서만 쓰는 미리보기 세기(게임에는 영향 없다). 자리·범위를 잡을 때 올려 두면 된다
@export_range(0.0, 1.0, 0.05) var preview: float = 0.0:
	set(v):
		preview = v
		queue_redraw()

## 0~1. 0이면 아무것도 안 그린다. 컷인이 매 프레임 넣어 준다
var power: float = 0.0:
	set(v):
		power = clampf(v, 0.0, 1.0)
		queue_redraw()

## 흐른 시간(초) — 줄을 옮기는 데만 쓴다
var _time: float = 0.0
var _streaks: Array[Dictionary] = []

func _process(delta: float) -> void:
	# 보일 때만 시간을 센다 — 안 보이는 동안 쌓아 두면 다시 켜질 때 줄이 엉뚱한 데서 시작한다
	if (preview if Engine.is_editor_hint() else power) <= 0.001:
		return
	_time += delta
	queue_redraw()

## 컷인이 다시 재생될 때 불러 준다 — 줄 자리를 처음으로 되돌린다
func restart() -> void:
	_time = 0.0
	queue_redraw()

## 줄마다 자리·길이·굵기를 미리 뽑아 둔다. **고정 씨앗**이라 매번 같은 모양이 나온다(연출은 재현되는 편이 낫다)
func _rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261001
	_streaks.clear()
	for i in maxi(count, 0):
		_streaks.append({
			"x": rng.randf_range(-area.x * 0.5, area.x * 0.5),
			"y": rng.randf_range(-area.y * 0.5, area.y * 0.5),
			"len": rng.randf_range(length_range.x, length_range.y),
			"w": rng.randf_range(thickness_range.x, thickness_range.y),
			"a": rng.randf_range(0.4, 1.0),
			"v": rng.randf_range(0.75, 1.4),
		})

func _draw() -> void:
	var p: float = preview if Engine.is_editor_hint() else power
	if p <= 0.001:
		return
	if _streaks.is_empty():
		_rebuild()
	# 줄이 범위를 벗어나면 반대쪽에서 다시 들어온다(wrap). 가장 긴 줄만큼 여유를 더 둬야 끝이 튀지 않는다
	var span: float = area.x + length_range.y * 2.0
	for s in _streaks:
		var x: float = fposmod(s["x"] + _time * speed * s["v"] * direction + span * 0.5, span) - span * 0.5
		# 약할 땐 짧게, 셀 땐 길게 — 바람이 세질수록 늘어나는 느낌
		var half: float = s["len"] * 0.5 * (0.35 + 0.65 * p)
		_draw_streak(Vector2(x, s["y"]), half, s["w"], Color(color.r, color.g, color.b, color.a * s["a"] * p))

## 양 끝이 투명해지는 가로 띠. 그냥 선으로 그으면 끝이 뭉툭해서 바람이 아니라 막대기로 보인다
func _draw_streak(c: Vector2, half: float, w: float, col: Color) -> void:
	var clear := Color(col.r, col.g, col.b, 0.0)
	var h: float = w * 0.5
	draw_primitive(PackedVector2Array([
		Vector2(c.x - half, c.y - h), Vector2(c.x, c.y - h),
		Vector2(c.x, c.y + h), Vector2(c.x - half, c.y + h)]),
		PackedColorArray([clear, col, col, clear]), PackedVector2Array())
	draw_primitive(PackedVector2Array([
		Vector2(c.x, c.y - h), Vector2(c.x + half, c.y - h),
		Vector2(c.x + half, c.y + h), Vector2(c.x, c.y + h)]),
		PackedColorArray([col, clear, clear, col]), PackedVector2Array())
