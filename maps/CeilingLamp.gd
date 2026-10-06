@tool
class_name CeilingLamp
extends Node2D

## 천장에 붙은 형광등 하나(악플러의 집) — 원점 = 천장 아랫면, 등 그림의 윗면이 여기에 붙는다.
## 등은 `조명.png`(Sprite2D), 아래로 퍼지는 빛은 ColorRect에 `CeilingLight.gdshader`(가산 합성)를 씌워 만든다.
## 둘 다 내부 자식이라 씬에 저장되지 않는다.
## 방 전체는 `Blackout`(CanvasModulate)이 은은하게 어둡게 깔고, 이 등의 **원뿔 모양 Light2D**(`_glow`)가 아래를 실제로 밝힌다(맵·캐릭터 모두).
## 그 빛은 `Blackout.light_level()`을 따라 같이 깜빡이고 암전 때 꺼진다 — 암전 중엔 스스로 빛나는 것(모니터·엄마 눈)만 보인다.

const LIGHT_SHADER := preload("res://maps/CeilingLight.gdshader")
## `조명.png`(2172x724)에서 실제로 보이는 영역 — 그림을 바꾸면 다시 잴 것
const LAMP_OPAQUE := Rect2(43, 305, 2085, 151)

@export var lamp_texture: Texture2D = preload("res://sprite/맵/악플러집/조명.png"):
	set(v):
		lamp_texture = v
		_refresh()
## 등 그림 배율(보이는 가로 = 2085 x 배율)
@export var lamp_scale: float = 0.1:
	set(v):
		lamp_scale = v
		_refresh()
## 빛 원뿔의 길이(등 아래부터 바닥 쪽으로, px)와 바닥 쪽 폭(px)
@export var light_length: float = 790.0:
	set(v):
		light_length = v
		_refresh()
@export var light_width: float = 560.0:
	set(v):
		light_width = v
		_refresh()
@export var light_color: Color = Color(1.0, 0.95, 0.82):
	set(v):
		light_color = v
		_refresh()
@export_range(0.0, 2.0) var light_strength: float = 0.35:
	set(v):
		light_strength = v
		_refresh()
## 등 아래를 실제로 밝히는 빛(Light2D)의 세기·색 — 방 어둠(Blackout 색) 위에 더해진다
@export var glow_energy: float = 0.9:
	set(v):
		glow_energy = v
		_refresh()
@export var glow_color: Color = Color(1.0, 0.93, 0.78):
	set(v):
		glow_color = v
		_refresh()
## 지글거림 박자를 전등마다 다르게
@export var flicker_seed: float = 0.0:
	set(v):
		flicker_seed = v
		_refresh()

var _lamp: Sprite2D = null
var _beam: ColorRect = null
var _glow: PointLight2D = null
var _blackout: Node = null

func _ready() -> void:
	_lamp = Sprite2D.new()
	_lamp.name = "Lamp"
	# 등 자체는 방 어둠(CanvasModulate)을 안 받게 하고, 켜짐·꺼짐 밝기는 _process에서 직접 준다
	var lamp_mat := CanvasItemMaterial.new()
	lamp_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_lamp.material = lamp_mat
	add_child(_lamp, false, Node.INTERNAL_MODE_FRONT)
	_beam = ColorRect.new()
	_beam.name = "Beam"
	_beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 맵 그림(z -10)보다 앞, 대시 잔상(z -2)·먼지보다 뒤
	_beam.z_index = 1
	_beam.material = ShaderMaterial.new()
	_beam.material.shader = LIGHT_SHADER
	add_child(_beam, false, Node.INTERNAL_MODE_FRONT)
	_glow = PointLight2D.new()
	_glow.name = "Glow"
	_glow.texture = _cone()
	add_child(_glow, false, Node.INTERNAL_MODE_FRONT)
	if not Engine.is_editor_hint():
		_blackout = get_tree().get_first_node_in_group("blackout")
	_refresh()

## 등 그림·빛 원뿔 크기·셰이더 값을 export에 맞춘다
func _refresh() -> void:
	if _lamp == null or _beam == null:
		return
	_lamp.texture = lamp_texture
	_lamp.scale = Vector2(lamp_scale, lamp_scale)
	var tex_center := Vector2(2172, 724) * 0.5
	if lamp_texture:
		tex_center = lamp_texture.get_size() * 0.5
	# 보이는 영역의 윗면 가운데가 원점에 오게
	var top_mid := Vector2(LAMP_OPAQUE.get_center().x, LAMP_OPAQUE.position.y)
	_lamp.position = (tex_center - top_mid) * lamp_scale
	var lamp_w: float = LAMP_OPAQUE.size.x * lamp_scale
	var lamp_h: float = LAMP_OPAQUE.size.y * lamp_scale
	_beam.position = Vector2(-light_width * 0.5, lamp_h - 3.0)
	_beam.size = Vector2(light_width, light_length)
	var mat := _beam.material as ShaderMaterial
	mat.set_shader_parameter("light_color", light_color)
	mat.set_shader_parameter("strength", light_strength)
	mat.set_shader_parameter("top_width", clampf(lamp_w * 0.9 / light_width, 0.0, 1.0))
	mat.set_shader_parameter("aspect", light_width / maxf(light_length, 1.0))
	mat.set_shader_parameter("seed", flicker_seed)
	# 원뿔 빛: 그림 위쪽 가운데(꼭짓점 쪽)가 등에 오게 — 텍스처 가운데가 노드 위치라 길이 절반만큼 내린다
	var tex_size: Vector2 = _glow.texture.get_size()
	var k: float = light_length / tex_size.y
	_glow.texture_scale = k
	_glow.position = Vector2(0.0, lamp_h + light_length * 0.5 - 6.0)
	# 텍스처 가로세로 비가 고정이라 가로 폭은 light_width에 맞춰 늘린다
	_glow.scale = Vector2(light_width / maxf(tex_size.x * k, 1.0), 1.0)
	_glow.color = glow_color
	_glow.energy = glow_energy

## 방 조명이 깜빡이거나 꺼지면 등 빛도 같이 — 어두운 쪽으로 갈수록 더 빨리 꺼지게 제곱
func _process(_delta: float) -> void:
	if _glow == null or _lamp == null:
		return
	var level: float = 1.0
	if _blackout != null and is_instance_valid(_blackout) and _blackout.has_method("light_level"):
		level = _blackout.light_level()
	_glow.energy = glow_energy * level * level
	_glow.enabled = _glow.energy > 0.01
	# 등은 켜져 있으면 하얗게, 꺼지면 어둡게(암전 때 방 밝기 정도)
	var b: float = lerpf(0.06, 1.0, level)
	_lamp.modulate = Color(b, b, b)

## 원뿔 빛 그림(흰색, 알파로 세기) — 위쪽 가운데가 등, 아래로 넓어지며 옅어진다. 등 바로 밑은 둥글게 더 밝다
func _cone() -> Texture2D:
	const W := 128
	const H := 256
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var v: float = float(y) / (H - 1)
		var half_w: float = lerpf(0.2, 0.5, v)
		var soft: float = 0.22 * maxf(v, 0.2)
		var down: float = pow(1.0 - v, 1.1)
		for x in W:
			var u: float = absf((float(x) + 0.5) / W - 0.5)
			var side: float = 1.0 - smoothstep(half_w - soft, half_w, u)
			var hot: float = exp(-(u * u * 18.0 + v * v * 30.0)) * 0.6
			var a: float = clampf(side * down + hot, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
