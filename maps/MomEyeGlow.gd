extends Node2D

## 악플러집 엄마 눈의 노란 십자 눈빛 — 평소엔 안 보이다가 **암전이 시작되자마자** 반짝 켜진다.
## 리그 `Head`의 자식으로 붙는다(`AkpeulleoMom._ready`). 좌표는 머리 그림 픽셀(`eye_pixel`), 그리는 크기는 화면 px.
## 암전 CanvasModulate에 같이 어두워지지 않도록 unshaded + 가산 합성.
## 머리가 옆모습(원래 그림)일 때만 보인다 — 돌아보는 그림들은 눈 자리가 달라서

## 머리 그림(`엄마 머리.png`, 1254x1254)에서 눈동자 가운데 — 그림을 바꾸면 다시 잴 것
@export var eye_pixel: Vector2 = Vector2(950, 745)
@export var glow_color: Color = Color(1.0, 0.88, 0.2)
## 십자 빛줄기 길이(가로·세로, 대각선)와 굵기(화면 px)
@export var ray_length: float = 13.0
@export var diag_length: float = 6.0
@export var ray_width: float = 2.2
## 눈 둘레 둥근 번짐 반지름(화면 px)
@export var halo_radius: float = 6.0
## 켜지는·꺼지는 시간(초)
@export var fade_in: float = 0.1
@export var fade_out: float = 0.35
## 반짝임(길이가 커졌다 작아짐) 빠르기
@export var twinkle_speed: float = 5.0
## 눈 주변을 은은하게 비추는 노란 불빛(PointLight2D) — 암전으로 어두운 방에서 얼굴·몸·근처 벽이 살짝 밝아진다
@export var light_color: Color = Color(1.0, 0.82, 0.3)
@export var light_energy: float = 0.55
## 불빛이 닿는 반지름(화면 px)
@export var light_radius: float = 110.0
## 은은하게 숨 쉬듯 밝아졌다 어두워지는 정도(0 = 일정)
@export var light_pulse: float = 0.15

var _head: Sprite2D = null
var _base_texture: Texture2D = null
var _blackout: Node = null
var _alpha: float = 0.0
var _time: float = 0.0
var _light: PointLight2D = null

func _ready() -> void:
	_head = get_parent() as Sprite2D
	if _head:
		_base_texture = _head.texture
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	_blackout = get_tree().get_first_node_in_group("blackout")
	modulate.a = 0.0
	_light = _make_light()
	add_child(_light)

func _process(delta: float) -> void:
	_time += delta
	var dark: bool = _blackout != null and is_instance_valid(_blackout) and _blackout.get("is_dark") == true
	var target: float = 1.0 if dark else 0.0
	var speed: float = 1.0 / maxf(fade_in if dark else fade_out, 0.01)
	_alpha = move_toward(_alpha, target, speed * delta)
	var on_side_face: bool = _head == null or _head.texture == _base_texture
	modulate.a = _alpha if on_side_face else 0.0
	# 불빛은 머리를 돌릴 때도 켜 둔다(눈 그림만 숨김) — 깜빡이면 어색해서
	_light.energy = light_energy * _alpha * (1.0 + light_pulse * sin(_time * 2.2))
	_light.enabled = _alpha > 0.001
	if _head:
		# 머리 배율을 상쇄해 화면 px로 그린다(좌우 반전은 리그가 알아서)
		var s: Vector2 = _head.scale.abs()
		scale = Vector2(1.0 / maxf(s.x, 0.0001), 1.0 / maxf(s.y, 0.0001))
		var tex_size: Vector2 = _head.texture.get_size() if _head.texture else Vector2(1254, 1254)
		position = eye_pixel - tex_size * 0.5
	if modulate.a > 0.0:
		queue_redraw()

func _draw() -> void:
	var tw: float = 1.0 + 0.25 * sin(_time * twinkle_speed)
	var clear := Color(glow_color.r, glow_color.g, glow_color.b, 0.0)
	# 둥근 번짐
	_draw_halo(halo_radius * (0.9 + 0.1 * tw), clear)
	# 십자(가로·세로) + 짧은 대각선
	for i in 4:
		var dir := Vector2.RIGHT.rotated(i * PI * 0.5)
		_draw_ray(dir, ray_length * tw, ray_width, clear)
		_draw_ray(dir.rotated(PI * 0.25), diag_length * (2.0 - tw), ray_width * 0.7, clear)
	# 가운데 하얀 점
	draw_circle(Vector2.ZERO, ray_width * 0.9, Color(1, 1, 0.9))

## 가운데는 진하고 끝으로 갈수록 투명해지는 가는 마름모 빛줄기
func _draw_ray(dir: Vector2, length: float, width: float, clear: Color) -> void:
	# 길이가 0에 가까워져도 에러가 안 나게 draw_primitive(삼각형 하나)
	var side := dir.orthogonal() * width * 0.5
	draw_primitive(PackedVector2Array([side, dir * length, -side]),
		PackedColorArray([glow_color, clear, glow_color]), PackedVector2Array())

func _draw_halo(radius: float, clear: Color) -> void:
	const SEG := 20
	var mid := Color(glow_color.r, glow_color.g, glow_color.b, 0.55)
	for i in SEG:
		var a := Vector2.RIGHT.rotated(TAU * i / SEG) * radius
		var b := Vector2.RIGHT.rotated(TAU * (i + 1) / SEG) * radius
		draw_primitive(PackedVector2Array([Vector2.ZERO, a, b]), PackedColorArray([mid, clear, clear]), PackedVector2Array())

## 가운데가 밝고 가장자리로 부드럽게 사라지는 둥근 불빛
func _make_light() -> PointLight2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var light := PointLight2D.new()
	light.name = "EyeLight"
	light.texture = tex
	# 이 노드는 머리 배율을 상쇄해 화면 px 기준이라 그대로 반지름/128
	light.texture_scale = light_radius / 128.0
	light.color = light_color
	light.energy = 0.0
	light.enabled = false
	return light
