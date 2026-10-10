extends Node2D

## 화면 전체 색보정 한 장(2026-10-08, 사용자 결정 — 맵 전체 셰이더는 "후처리 한 장" 방식).
## `Stage._add_screen_grade()`가 라운드마다 만들어 붙인다. 카메라가 비추는 범위를 매 프레임 덮는 사각형에
## `ScreenGrade.gdshader`를 입힌 것이라, 맵·캐릭터·이펙트는 물들고 **HUD·컷인(CanvasLayer)은 안 물든다**.
## - z 3000: 레터박스(4000) 아래, 맵의 모든 것 위. `top_level`이라 부모 자리와 상관없이 카메라 중심을 따라간다
## - 스타일은 `ScreenGradeStyle`(.tres, `maps/grade/`) — `apply_style()`로 갈아 끼울 수 있다(연출 중 바꾸기 등)
## - 끄기: `GameState.screen_effects_enabled`(설정 파일에 저장). 꺼지면 안 그린다
## ⚠️ 가운데(캐릭터)는 또렷하게 — 흐림·색수차처럼 읽기 힘들어지는 효과는 넣지 않는다

const SHADER: Shader = preload("res://maps/ScreenGrade.gdshader")
const DEFAULT_STYLE: Resource = preload("res://maps/grade/Default.tres")
## 새 class_name을 바로 쓰면 캐시 전엔 파싱 에러라 preload로 든다
const STYLE_SCRIPT: Script = preload("res://maps/ScreenGradeStyle.gd")
## 카메라 범위보다 이만큼 크게 덮는다 — 흔들림(offset)으로 한 프레임 어긋나도 가장자리가 안 비친다
const OVERSIZE: float = 1.08

## 지금 쓰는 스타일(ScreenGradeStyle)
var style: Resource = null
## 전체 세기 0~1 — 셰이더 COLOR.a로 간다. 연출에서 서서히 켜고 끌 때 쓴다
var strength: float = 1.0:
	set(v):
		strength = clampf(v, 0.0, 1.0)
		modulate.a = strength

var _mat: ShaderMaterial
var _half: Vector2 = Vector2(640.0, 360.0) * OVERSIZE

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 3000
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	apply_style(style if style != null else DEFAULT_STYLE)
	modulate.a = strength
	# ⚠️ Godot은 한 프레임에 화면을 **처음 읽는 곳에서 딱 한 번만** 복사한다. 흐림(`far_blur`) CanvasGroup의
	# 자식이 전부 화면 밖으로 잘리면 그 그룹이 맨 뒤(z -29)에서 복사를 써 버려, 여기서 그 낡은 화면(하늘+건물)을
	# 덮어 그렸다 → 전선·전봇대·쓰레기통·캐릭터가 통째로 사라짐(2026-10-09). 바로 앞에서 새로 복사하게 강제한다
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	copy.show_behind_parent = true
	add_child(copy)

## 스타일의 칸 값을 이름 그대로 셰이더에 넘긴다
func apply_style(new_style: Resource) -> void:
	style = new_style if new_style != null else DEFAULT_STYLE
	for key in STYLE_SCRIPT.PARAMS:
		var value = style.get(key)
		if value != null:
			_mat.set_shader_parameter(key, value)

func _process(_delta: float) -> void:
	var on: bool = GameState.screen_effects_enabled
	if visible != on:
		visible = on
	if not on:
		return
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var half: Vector2 = get_viewport_rect().size / cam.zoom * (0.5 * OVERSIZE)
	global_position = cam.get_screen_center_position()
	# 카메라가 기울면(카운터 히트 줌) 같이 기운다 — 안 그러면 기운 화면 모서리가 덮이지 않는다
	global_rotation = 0.0 if cam.ignore_rotation else cam.global_rotation
	if half.distance_squared_to(_half) > 0.25:
		_half = half
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-_half, _half * 2.0), Color.WHITE)
