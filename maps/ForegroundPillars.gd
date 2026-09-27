@tool
extends Node2D

## 화면 앞을 가로막는 기둥 실루엣 — "싸우는 공간보다 앞에 있는 층"을 보여주는 장식(판정 없음, 2026-09-26).
## 카메라가 움직이면 싸우는 층보다 더 많이 움직여서(parallax) 앞에 있는 것으로 읽힌다.
## 캐릭터가 기둥 뒤로 들어가면 반투명해져 가려지지 않는다.
## 기둥 그림(texture)을 세로로 이어 붙여 그리고, tint로 어둡게·foreground_blur 셰이더로 살짝 흐리게 한다(초점이 안 맞은 앞 물체).
## 그림이 비어 있으면 예전 임시 도형(어두운 실루엣)으로 그린다.
## 조명 무시(unshaded)라 맵 조명·형광등 빛과 상관없이 늘 같은 밝기다

const BLUR_SHADER: Shader = preload("res://maps/foreground_blur.gdshader")

## 기둥 가운데 x 위치들(카메라가 가운데(x = 0)일 때 보이는 자리)
@export var pillar_xs: PackedFloat32Array = PackedFloat32Array([-560.0, 0.0, 560.0])
## 기둥 폭(px) — 그림은 이 폭에 맞춰 비율 그대로 줄인다
@export var pillar_width: float = 120.0
## 기둥이 덮는 세로 범위(px) — 카메라가 어디를 비춰도 끊기지 않게 넉넉히
@export var top_y: float = -700.0
@export var bottom_y: float = 700.0

@export_group("그림")
## 기둥 그림 — 세로로 반복해서 이어 붙인다
@export var texture: Texture2D
## 그림에서 반복할 구간(원본 픽셀). **위·아래 끝을 타일 칸 안쪽(흰 면)에서, 각자 가로줄에서 같은 거리만큼 떨어진 곳**으로 잡아야
## 이어 붙인 자리가 안 보인다. 가로줄 한가운데서 자르면 위아래 줄 두께·위치가 달라 이음매에 줄이 한 줄 더 생긴다(실제로 겪음).
## 기둥.png: 몸통 x 285~602, 가로줄 중심 맨 위 y 약 69 / 맨 아래 y 약 1724(간격 약 81) -> 둘 다 줄에서 19px 아래인 y 88 ~ 1743.
## 캔버스 통째로 붙이면 이음매 칸이 117px로 길어진다. 그림을 바꾸면 다시 잴 것
@export var texture_region: Rect2 = Rect2(285, 88, 318, 1655)
## 그림에 곱하는 색 — 앞 층이라 어둡게 눌러 싸우는 층보다 튀지 않게 한다
@export var tint: Color = Color(0.42, 0.44, 0.52)
## 흐린 정도(원본 그림 픽셀 기준). 0이면 선명
@export_range(0.0, 30.0) var blur_amount: float = 6.0
@export_group("")

## 실루엣 색 (그림이 없을 때)
@export var color: Color = Color(0.05, 0.06, 0.09)
## 안쪽 모서리에 비치는 옅은 빛(기둥의 입체감) 색 — 알파가 세기
@export var rim_color: Color = Color(0.35, 0.42, 0.6, 0.35)
## 가로 이음매(기둥 마감재 줄) 간격(px). 0이면 안 그린다
@export var seam_spacing: float = 140.0
## 가장자리를 흐리게 번지게 하는 폭(px) — 칼같은 경계보다 "초점이 안 맞은 앞 물체"로 보인다
@export var feather: float = 10.0
## 앞에 있는 정도 — 카메라가 1만큼 움직이면 이 층은 이만큼 움직인다(1 = 싸우는 층과 같음, 1보다 크면 앞)
@export var parallax: float = 1.25
## 캐릭터가 기둥 뒤에 있을 때 투명도, 그리고 바뀌는 빠르기(초당)
@export var behind_alpha: float = 0.35
@export var fade_speed: float = 6.0

## 기둥마다 지금 투명도
var _alphas: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	# 크게 줄여 그리므로(약 0.38배) 밉맵을 써야 가로줄이 지글거리지 않는다(놀이터 울타리와 같은 이유)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_apply_material()

## 그림이 있으면 흐림 셰이더, 없으면 조명 무시 재질 — 둘 다 unshaded다
func _apply_material() -> void:
	if texture:
		var sm := material as ShaderMaterial
		if sm == null:
			sm = ShaderMaterial.new()
			sm.shader = BLUR_SHADER
			material = sm
		sm.set_shader_parameter("blur_amount", blur_amount)
	elif not (material is CanvasItemMaterial):
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat

func _process(delta: float) -> void:
	if _alphas.size() != pillar_xs.size():
		_alphas.resize(pillar_xs.size())
		_alphas.fill(1.0)
	if Engine.is_editor_hint():
		position.x = 0.0
		_apply_material()
		queue_redraw()
		return
	# 카메라가 가운데에서 벗어난 만큼 (parallax - 1)배 더 반대로 밀어 앞에 있는 것처럼 보이게 한다
	var cam: Camera2D = get_viewport().get_camera_2d()
	var cam_x: float = cam.get_screen_center_position().x if cam else 0.0
	position.x = -cam_x * (parallax - 1.0)
	# 캐릭터가 기둥 뒤에 들어가 있으면 그 기둥만 흐리게
	var fighters: Array = get_tree().get_nodes_in_group("fighters")
	for i in pillar_xs.size():
		var center: float = pillar_xs[i] + position.x
		var hidden_behind: bool = false
		for f in fighters:
			if f is Node2D and absf(f.global_position.x - center) < pillar_width * 0.5 + 24.0:
				hidden_behind = true
				break
		_alphas[i] = move_toward(_alphas[i], behind_alpha if hidden_behind else 1.0, delta * fade_speed)
	queue_redraw()

func _draw() -> void:
	if texture and texture_region.size.x > 0.0 and texture_region.size.y > 0.0:
		_draw_textured()
		return
	var half: float = pillar_width * 0.5
	var height: float = bottom_y - top_y
	for i in pillar_xs.size():
		var a: float = _alphas[i] if i < _alphas.size() else 1.0
		var x: float = pillar_xs[i]
		var body := Color(color, color.a * a)
		draw_rect(Rect2(x - half, top_y, pillar_width, height), body)
		# 양옆 번짐 — 몸통 색에서 투명으로
		var clear := Color(color, 0.0)
		for side in [-1.0, 1.0]:
			var edge: float = x + half * side
			draw_polygon(
				PackedVector2Array([Vector2(edge, top_y), Vector2(edge + feather * side, top_y), Vector2(edge + feather * side, bottom_y), Vector2(edge, bottom_y)]),
				PackedColorArray([body, clear, clear, body]))
		# 무대 쪽(안쪽) 모서리에 옅은 빛 — 기둥이 둥글게 서 있는 느낌
		var inward: float = -signf(x) if x != 0.0 else 1.0
		var rim_x: float = x + half * inward
		var rim := Color(rim_color, rim_color.a * a)
		var rim_clear := Color(rim_color, 0.0)
		draw_polygon(
			PackedVector2Array([Vector2(rim_x, top_y), Vector2(rim_x - 14.0 * inward, top_y), Vector2(rim_x - 14.0 * inward, bottom_y), Vector2(rim_x, bottom_y)]),
			PackedColorArray([rim, rim_clear, rim_clear, rim]))
		# 가로 이음매
		if seam_spacing > 0.0:
			var seam := Color(0.0, 0.0, 0.0, 0.5 * a)
			var y: float = top_y + seam_spacing
			while y < bottom_y:
				draw_rect(Rect2(x - half, y, pillar_width, 3.0), seam)
				y += seam_spacing

## 기둥 그림을 pillar_width 폭으로 줄여 top_y부터 bottom_y까지 세로로 이어 붙인다 — 마지막 조각은 남은 길이만큼 잘라 그린다
func _draw_textured() -> void:
	var half: float = pillar_width * 0.5
	var ratio: float = pillar_width / texture_region.size.x
	var tile_h: float = texture_region.size.y * ratio
	for i in pillar_xs.size():
		var a: float = _alphas[i] if i < _alphas.size() else 1.0
		var tint_now := Color(tint, tint.a * a)
		var y: float = top_y
		while y < bottom_y:
			var h: float = minf(tile_h, bottom_y - y)
			var src := Rect2(texture_region.position, Vector2(texture_region.size.x, h / ratio))
			draw_texture_rect_region(texture, Rect2(pillar_xs[i] - half, y, pillar_width, h), src, tint_now)
			y += tile_h
