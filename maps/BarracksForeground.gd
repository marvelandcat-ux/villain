extends Node2D

## 황근출 궁 내무반의 앞 층 — 카메라 바로 앞에 놓인 침대·관물대 뒷모습(판정 없음, 2026-10-03).
## 지하철 앞 기둥(`ForegroundPillars`)처럼 카메라보다 빨리 흘러(parallax > 1) 가까이 있는 것으로 읽히고, 어둡게·살짝 흐리게 그린다.
## 줌이 바뀌어도 늘 **화면 아래쪽**에 붙도록 위아래 자리는 매 프레임 카메라 화면 바닥에서 잰다(윗변 = 바닥에서 화면 높이 x `*_show`).
## 캐릭터가 뒤에 들어가면 그 물건만 반투명해진다.
## `BarracksUltimate._build_arena()`가 내무반 노드의 자식으로 만든다 — 좌표(`*_xs`)는 내무반 가운데 기준

@export var bed_texture: Texture2D = preload("res://sprite/황근출 해병/궁극기/막사 침대 뒷모습.webp")
@export var locker_texture: Texture2D = preload("res://sprite/황근출 해병/궁극기/관물대 뒷편.webp")
## 그림에서 실제로 칠해진 영역(원본 픽셀) — 그림을 바꾸면 다시 잴 것
@export var bed_region: Rect2 = Rect2(50, 80, 1436, 870)
@export var locker_region: Rect2 = Rect2(160, 25, 363, 962)
## 물건 가운데 x(카메라가 내무반 가운데일 때 보이는 자리) — 침대+관물대 두 쌍
@export var bed_xs: PackedFloat32Array = PackedFloat32Array([-330.0, 545.0])
@export var locker_xs: PackedFloat32Array = PackedFloat32Array([-645.0, 230.0])
## 물건 높이(월드 px) — 너비는 그림 비율대로
@export var bed_height: float = 300.0
@export var locker_height: float = 360.0
## 화면 바닥에서 물건 윗변까지 = 화면 높이 x 이 값(1/3이면 아래 1/3을 덮음)
@export var bed_show: float = 0.29
@export var locker_show: float = 0.3333
## 카메라 따라 움직이는 비율 — 1보다 크면 더 빨리 흘러 앞에 있는 것처럼
@export var parallax: float = 1.3
## 어둡게 누르는 색 / 흐린 정도(원본 그림 픽셀)
@export var tint: Color = Color(0.5, 0.5, 0.55)
@export_range(0.0, 30.0) var blur_amount: float = 8.0
## 캐릭터가 뒤에 있을 때 투명도 / 바뀌는 빠르기(1/초)
@export var behind_alpha: float = 0.4
@export var fade_speed: float = 6.0
## 그리기 순서 — 캐릭터(0)·이펙트보다 앞
@export var draw_z: int = 60
## 위치(`*_xs`)·높이에 곱하는 배율 — 내무반 배율이 바뀌면 `BarracksUltimate`가 add_child 전에 넣어 준다
var size_scale: float = 1.0

const BLUR_SHADER: Shader = preload("res://maps/foreground_blur.gdshader")

## 물건마다 {sprite, x, height, show, width}
var _items: Array = []

func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = BLUR_SHADER
	mat.set_shader_parameter("blur_amount", blur_amount)
	for x in locker_xs:
		_add_item(locker_texture, locker_region, x * size_scale, locker_height * size_scale, locker_show, mat)
	for x in bed_xs:
		_add_item(bed_texture, bed_region, x * size_scale, bed_height * size_scale, bed_show, mat)
	_place(0.0)

func _add_item(tex: Texture2D, region: Rect2, x: float, height: float, show: float, mat: Material) -> void:
	if tex == null or region.size.y <= 0.0:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = region
	var k: float = height / region.size.y
	s.scale = Vector2(k, k)
	s.modulate = tint
	s.material = mat
	s.z_as_relative = false
	s.z_index = draw_z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(s)
	_items.append({"sprite": s, "x": x, "height": height, "show": show, "width": region.size.x * k, "alpha": 1.0})

func _process(delta: float) -> void:
	_place(delta)

## 카메라 화면을 재서 자리를 다시 잡는다 — 가로는 parallax, 세로는 화면 바닥 기준
func _place(delta: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var center: Vector2 = cam.get_screen_center_position()
	var view: Vector2 = get_viewport_rect().size / cam.zoom
	var bottom: float = center.y + view.y * 0.5
	var shift: float = -(center.x - global_position.x) * (parallax - 1.0)
	var fighters: Array = get_tree().get_nodes_in_group("fighters")
	for item in _items:
		var s: Sprite2D = item["sprite"]
		var top: float = bottom - view.y * float(item["show"])
		var h: float = item["height"]
		var w: float = item["width"]
		s.global_position = Vector2(global_position.x + float(item["x"]) + shift, top + h * 0.5)
		var rect := Rect2(s.global_position - Vector2(w, h) * 0.5, Vector2(w, h))
		var behind: bool = false
		for f in fighters:
			if f is Node2D and rect.intersects(Rect2((f as Node2D).global_position + Vector2(-20.0, -45.0), Vector2(40.0, 75.0))):
				behind = true
				break
		item["alpha"] = move_toward(float(item["alpha"]), behind_alpha if behind else 1.0, delta * fade_speed)
		s.modulate = Color(tint.r, tint.g, tint.b, tint.a * float(item["alpha"]))
