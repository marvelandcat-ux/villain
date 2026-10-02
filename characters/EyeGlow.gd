@tool
extends Node2D

## 눈에서 빛이 나는 연출(황근출 궁 내무반, 2026-10-02) — 리그의 `Head` 스프라이트 자식으로 달고 노드 위치를 눈 자리에 둔다.
## 좌표·크기는 머리 그림 픽셀 단위(Head 배율을 물려받음). 가산 혼합 + 조명 무시라 어두운 맵에서도 빛난다.
## 평소엔 꺼져 있고 `set_active(true)`로 켠다. 머리 그림이 처음 것(기본 얼굴)일 때만 보인다(머리를 돌리는 동안은 숨음)

## 빛 가운데(눈동자)와 번진 빛 크기(머리 그림 픽셀)
@export var core_radius: float = 22.0
@export var glow_radius: float = 90.0
## 가로로 길쭉한 정도(1이면 동그라미)
@export var stretch_x: float = 1.6
@export var core_color: Color = Color(1.0, 0.98, 0.7, 1.0)
@export var glow_color: Color = Color(1.0, 0.8, 0.1, 0.55)
## 깜빡이듯 일렁이는 속도(초당 횟수)와 세기(0~1)
@export var pulse_speed: float = 2.5
@export var pulse_amount: float = 0.25
## 켜지고 꺼지는 데 걸리는 시간(초)
@export var fade_time: float = 0.3

@export_group("에디터")
## 에디터에서 켠 모습을 미리 본다(게임에는 영향 없음)
@export var preview: bool = false:
	set(v):
		preview = v
		queue_redraw()

## 번진 빛을 몇 겹으로 칠할지
const LAYERS: int = 6
const SEGMENTS: int = 24

var _base_texture: Texture2D
var _on: bool = false
var _level: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	var head := get_parent() as Sprite2D
	if head:
		_base_texture = head.texture
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

## 눈빛을 켜고 끈다(서서히)
func set_active(on: bool) -> void:
	_on = on

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var target: float = 1.0 if _on else 0.0
	_level = move_toward(_level, target, delta / maxf(fade_time, 0.01))
	if _level > 0.0 or target > 0.0:
		queue_redraw()

func _draw() -> void:
	var level: float = 1.0 if Engine.is_editor_hint() and preview else _level
	if level <= 0.0:
		return
	if not Engine.is_editor_hint():
		var head := get_parent() as Sprite2D
		if head and _base_texture and head.texture != _base_texture:
			return
	var pulse: float = 1.0 - pulse_amount * 0.5 + pulse_amount * 0.5 * sin(_time * TAU * pulse_speed)
	for i in LAYERS:
		var t: float = float(i) / float(LAYERS - 1)
		var r: float = lerpf(glow_radius, core_radius * 1.5, t) * pulse
		var c: Color = glow_color
		c.a *= level * (0.25 + 0.75 * t) / float(LAYERS) * 2.0
		_draw_oval(r, c)
	var core: Color = core_color
	core.a *= level
	_draw_oval(core_radius, core)

func _draw_oval(r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for k in SEGMENTS:
		var a: float = TAU * k / SEGMENTS
		pts.append(Vector2(cos(a) * r * stretch_x, sin(a) * r))
	draw_colored_polygon(pts, c)
