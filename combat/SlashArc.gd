class_name SlashArc
extends Node2D

## 칼로 그은 자리에 남는 **초승달 참격 자국** — 경찰 경관봉 난무("검사처럼 촤좍")에 쓴다.
## 그림이 따로 없다. `_draw()`로 가운데가 두껍고 양 끝이 가늘어지는 초승달을 그리고,
## `life`초 동안 바깥으로 살짝 퍼지면서 사라진다.
##
## **맵에 붙여 제자리에 남긴다**(JumpWind와 같은 방식) — 휘두른 자리에 자국이 남아야
## 손이 지나간 길이 보인다. 리그에 붙이면 캐릭터를 따라다녀서 자국이 아니라 장식이 된다

## 초승달 반지름(px)과 가운데 두께(px)
@export var radius: float = 44.0
@export var thickness: float = 15.0
## 초승달이 벌어지는 각도(도) — 180에 가까울수록 한 바퀴 그은 느낌
@export var sweep_deg: float = 168.0
## 남아 있는 시간(초). 짧아야 "번쩍"이 된다
@export var life: float = 0.14
## 자국 색과 가장자리에 덧그리는 색(살짝 푸른 쇳빛)
@export var color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var edge_color: Color = Color(0.62, 0.84, 1.0, 0.8)
## 사라지는 동안 반지름이 커지는 비율
@export var grow: float = 1.3

var _t: float = 0.0

func _ready() -> void:
	# 맵 조명(CanvasModulate)에 눌리면 어두운 맵에서 자국이 안 보인다
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat

## 벤 방향(라디안)으로 돌려 놓고 크기를 정한다. 바라보는 쪽 반전은 부르는 쪽이 각도에 담아 준다
func setup(angle: float, size_mult: float = 1.0) -> void:
	rotation = angle
	scale = Vector2.ONE * size_mult

func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k: float = clampf(_t / maxf(life, 0.001), 0.0, 1.0)
	var r: float = radius * lerpf(1.0, grow, k)
	# 두께는 줄고 투명해진다 — 그어진 선이 가늘어지며 사라지는 느낌
	var th: float = thickness * (1.0 - k * 0.75)
	var fade: float = 1.0 - k * k
	var half: float = deg_to_rad(sweep_deg) * 0.5
	var steps: int = 22
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var ang: float = lerpf(-half, half, t)
		var dir := Vector2(cos(ang), sin(ang))
		# 가운데가 제일 두껍고 양 끝은 뾰족하다 — 이래야 칼자국처럼 보인다
		var w: float = th * sin(PI * t)
		outer.append(dir * (r + w * 0.5))
		inner.append(dir * (r - w * 0.5))
	var poly := PackedVector2Array()
	for p in outer:
		poly.append(p)
	for i in range(inner.size() - 1, -1, -1):
		poly.append(inner[i])
	draw_colored_polygon(poly, Color(edge_color, edge_color.a * fade))
	# 안쪽에 더 밝은 심지를 한 겹 — 가장자리는 쇳빛, 가운데는 흰빛이 된다
	var core := PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var ang: float = lerpf(-half, half, t)
		var dir := Vector2(cos(ang), sin(ang))
		core.append(dir * (r + th * sin(PI * t) * 0.16))
	for i in range(steps, -1, -1):
		var t: float = float(i) / float(steps)
		var ang: float = lerpf(-half, half, t)
		var dir := Vector2(cos(ang), sin(ang))
		core.append(dir * (r - th * sin(PI * t) * 0.16))
	draw_colored_polygon(core, Color(color, color.a * fade))
