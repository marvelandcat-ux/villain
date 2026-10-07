extends Sprite2D

## 캐릭터 **앞에** 그려지는 그림(번화가 전봇대, 2026-10-08). 지하철 앞 기둥(`ForegroundPillars`)처럼
## 캐릭터가 그 뒤에 들어가면 반투명해져서 완전히 가려지지 않는다.
## 시차(parallax)는 안 준다 — 전봇대에 걸린 전선이 밟는 발판이라, 전봇대만 움직이면 전선 끝이 떨어져 보인다.
## 대신 "앞에 있다"는 느낌은 세 가지로 낸다:
## - **뒤 건물 벽에 비친 그림자** — 건물 그림의 자식으로 깔고 `clip_children`으로 잘라서 **하늘엔 안 생긴다**
## - **초점 흐림**(`foreground_blur.gdshader`) — 카메라 가까운 물체처럼
## - **어둡게 누르기**(`tint`)

const BLUR_SHADER: Shader = preload("res://maps/foreground_blur.gdshader")

## 그림에서 실제로 보이는 영역(원본 픽셀). 전봇데.png 실측 — 그림을 바꾸면 다시 잴 것
@export var opaque_rect: Rect2 = Rect2(250, 35, 589, 1484)
## 캐릭터 뒤에 있을 때 투명도와 바뀌는 빠르기(초당)
@export var behind_alpha: float = 0.4
@export var fade_speed: float = 6.0
## 판정 여유(월드 px) — 몸이 살짝만 걸쳐도 흐려지게
@export var margin: float = 20.0

@export_group("앞 느낌")
## 흐린 정도(원본 그림 픽셀). 전봇대가 0.3배라 4면 화면에서 약 1px
@export_range(0.0, 30.0) var blur_amount: float = 4.0
## 그림에 곱하는 색 — 1이면 그대로
@export var tint: Color = Color(0.86, 0.86, 0.9)
## 그림자를 깔지
@export var cast_shadow: bool = true
## 그림자가 밀리는 거리(월드 px) — 빛이 왼쪽 위에서 온다
@export var shadow_offset: Vector2 = Vector2(18, 8)
@export var shadow_color: Color = Color(0.05, 0.06, 0.12, 0.28)
## 그림자가 비칠 건물들. 비우면 형제 중 이름이 `Building`으로 시작하는 그림 전부
@export var shadow_receivers: Array[NodePath] = []
@export_group("")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if blur_amount > 0.0:
		var mat := ShaderMaterial.new()
		mat.shader = BLUR_SHADER
		mat.set_shader_parameter("blur_amount", blur_amount)
		material = mat
	self_modulate = tint
	if cast_shadow:
		_make_shadows()

## 건물마다 그림자 한 장씩 — 건물의 자식이라 건물 모양 밖으로는 안 그려진다
func _make_shadows() -> void:
	for building in _receivers():
		var shadow := Sprite2D.new()
		shadow.name = "Shadow_" + name
		shadow.texture = texture
		shadow.centered = centered
		shadow.offset = offset
		shadow.flip_h = flip_h
		shadow.self_modulate = shadow_color
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		building.add_child(shadow)
		shadow.global_transform = Transform2D(global_rotation, global_scale, 0.0, global_position + shadow_offset)
		# 건물에 붙은 투명한 부분 밖(하늘)으로 그림자가 새지 않게 건물 모양으로 자른다
		building.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW

func _receivers() -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	if not shadow_receivers.is_empty():
		for path in shadow_receivers:
			var node := get_node_or_null(path) as CanvasItem
			if node:
				out.append(node)
		return out
	var parent: Node = get_parent()
	if parent == null:
		return out
	for child in parent.get_children():
		if child is Sprite2D and String(child.name).begins_with("Building"):
			out.append(child)
	return out

func _process(delta: float) -> void:
	if texture == null:
		return
	var rect: Rect2 = opaque_rect
	if centered:
		rect.position -= texture.get_size() * 0.5
	rect = rect.grow(margin / maxf(absf(global_scale.x), 0.001))
	var behind: bool = false
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as Node2D
		if fighter == null:
			continue
		# 몸 중심과 머리 두 점을 본다
		if rect.has_point(to_local(fighter.global_position)) \
				or rect.has_point(to_local(fighter.global_position + Vector2(0, -40))):
			behind = true
			break
	# self_modulate만 흐리게 한다 — modulate를 쓰면 건물에 깐 그림자까지 같이 흐려질 수 있다
	self_modulate.a = move_toward(self_modulate.a, behind_alpha if behind else 1.0, fade_speed * minf(delta, 0.05))
