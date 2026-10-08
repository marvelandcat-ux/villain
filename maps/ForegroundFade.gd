extends Sprite2D

## 캐릭터 **앞에** 그려지는 그림(번화가 전봇대, 2026-10-08). 지하철 앞 기둥(`ForegroundPillars`)처럼
## 캐릭터가 그 뒤에 들어가면 반투명해져서 완전히 가려지지 않는다.
## **시차(`parallax`, 2026-10-08)**: 1보다 크면 카메라보다 더 움직여 앞에 있는 것처럼 보인다(`ParallaxFollow`와 같은 식).
## 전봇대에 걸린 전선은 밟는 발판이라 판정은 못 움직이지만, `PowerLine`의 `start_anchor`/`end_anchor`로 이 노드를
## 가리키면 **전선 그림 끝만** 같이 따라와 떨어져 보이지 않는다. 세로 시차는 1.0으로 두는 게 안전하다 —
## 세로로 어긋나면 전선 끝에 선 사람이 그림보다 떠 보인다(가로는 거의 수평인 줄이라 티가 안 난다)
## "앞에 있다"는 느낌은 그 밖에 세 가지로 더 낸다:
## - **뒤 건물 벽에 비친 그림자** — 건물 그림의 자식으로 깔고 `clip_children`으로 잘라서 **하늘엔 안 생긴다**
## - **초점 흐림**(`foreground_blur.gdshader`) — 카메라 가까운 물체처럼
## - **어둡게 누르기**(`tint`)

const BLUR_SHADER: Shader = preload("res://maps/foreground_blur.gdshader")

## 그림에서 실제로 보이는 영역(원본 픽셀). 전봇데.png 실측 — 그림을 바꾸면 다시 잴 것
@export var opaque_rect: Rect2 = Rect2(250, 35, 589, 1484)
## 캐릭터 뒤에 있을 때 투명도와 바뀌는 빠르기(초당)
@export var behind_alpha: float = 0.3
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

@export_group("시차")
## 카메라를 따라 움직이는 비율 — 1이면 싸우는 층과 같이, 크면 앞에 있는 것처럼. 번화가 전봇대 (1.1, 1.0)
@export var parallax: Vector2 = Vector2(1.0, 1.0)
## 기준 카메라 중심 — 카메라가 여기 있으면 에디터에 놓인 자리 그대로. 번화가는 시작 카메라 (0, -24)
@export var parallax_reference: Vector2 = Vector2(0.0, -24.0)
@export_group("")

@export_group("바닥까지 늘이기")
## 켜면 그림 밑을 `extend_to_y`(월드 y)까지 기둥 조각으로 이어 그린다 — 2·3층에 세운 전봇대가 공중에 끊겨 보이지 않게(2026-10-08).
## 흐림·반투명·건물 그림자가 조각에도 똑같이 걸린다
@export var extend_to_ground: bool = false
## 기둥 발이 닿을 월드 y(번화가 땅 윗면 286)
@export var extend_to_y: float = 286.0
## 이어 붙일 기둥 조각(원본 픽셀) — 전봇데.png 아래쪽 민무늬 기둥 실측(x 450~572가 기둥, 테두리 여유 포함). **그림을 바꾸면 다시 잴 것**
@export var shaft_rect: Rect2 = Rect2(440, 1345, 144, 170)
## 조각을 그림 밑에 몇 px 겹쳐 시작할지(원본 픽셀) — 그림 맨 아랫줄이 반투명이라 이음새가 비친다
@export var shaft_overlap: float = 3.0
@export_group("")

## 에디터에 놓인 자리 — 시차는 여기서부터 민다
var _rest: Vector2
## 바닥까지 이어 붙인 기둥 조각들(자식 Sprite2D)
var _shaft_pieces: Array[Sprite2D] = []
## 조각들이 차지하는 영역(이 노드 로컬, 원본 픽셀) — 뒤에 들어왔는지 볼 때 같이 본다
var _shaft_local_rect: Rect2 = Rect2()

func _ready() -> void:
	_rest = position
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if blur_amount > 0.0:
		var mat := ShaderMaterial.new()
		mat.shader = BLUR_SHADER
		mat.set_shader_parameter("blur_amount", blur_amount)
		material = mat
	self_modulate = tint
	if extend_to_ground:
		_build_shaft()
	if cast_shadow:
		_make_shadows()

## 그림 밑에서 `extend_to_y`까지 `shaft_rect` 조각을 세로로 쌓는다. 마지막 조각은 남은 길이만큼 자른다
func _build_shaft() -> void:
	if texture == null or shaft_rect.size.y <= 0.0:
		return
	var half: Vector2 = texture.get_size() * 0.5 if centered else Vector2.ZERO
	# 그림에서 보이는 부분의 맨 아래(로컬 원본 픽셀) — 거기서부터 잇는다
	var start_y: float = opaque_rect.end.y - half.y - shaft_overlap
	var sy: float = maxf(absf(global_scale.y), 0.001)
	var need: float = (extend_to_y - global_position.y) / sy - start_y
	if need <= 0.0:
		return
	var x: float = shaft_rect.position.x - half.x
	var y: float = start_y
	while need > 0.5:
		var h: float = minf(shaft_rect.size.y, need)
		var piece := Sprite2D.new()
		piece.name = "Shaft%d" % _shaft_pieces.size()
		piece.texture = texture
		piece.centered = false
		piece.region_enabled = true
		piece.region_rect = Rect2(shaft_rect.position, Vector2(shaft_rect.size.x, h))
		piece.position = Vector2(x, y)
		piece.use_parent_material = true
		piece.self_modulate = self_modulate
		piece.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(piece)
		_shaft_pieces.append(piece)
		y += h
		need -= h
	_shaft_local_rect = Rect2(x, start_y, shaft_rect.size.x, y - start_y)

## 건물마다 그림자 한 벌씩(그림 + 이어 붙인 기둥 조각) — 건물의 자식이라 건물 모양 밖으로는 안 그려진다
func _make_shadows() -> void:
	var sources: Array[Sprite2D] = [self]
	sources.append_array(_shaft_pieces)
	for building in _receivers():
		for src in sources:
			var shadow := Sprite2D.new()
			shadow.name = "Shadow_" + name + ("" if src == self else "_" + String(src.name))
			shadow.texture = src.texture
			shadow.centered = src.centered
			shadow.offset = src.offset
			shadow.flip_h = src.flip_h
			shadow.region_enabled = src.region_enabled
			shadow.region_rect = src.region_rect
			shadow.self_modulate = shadow_color
			shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			building.add_child(shadow)
			shadow.global_transform = Transform2D(src.global_rotation, src.global_scale, 0.0, src.global_position + shadow_offset)
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
	_follow_camera()
	if texture == null:
		return
	var rect: Rect2 = opaque_rect
	if centered:
		rect.position -= texture.get_size() * 0.5
	rect = rect.grow(margin / maxf(absf(global_scale.x), 0.001))
	var shaft: Rect2 = _shaft_local_rect.grow(margin / maxf(absf(global_scale.x), 0.001)) if _shaft_local_rect.has_area() else Rect2()
	var behind: bool = false
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as Node2D
		if fighter == null:
			continue
		# 몸 중심과 머리 두 점을 본다 — 그림 영역과 바닥까지 늘인 기둥 영역 어느 쪽이든
		for probe in [fighter.global_position, fighter.global_position + Vector2(0, -40)]:
			var lp: Vector2 = to_local(probe)
			if rect.has_point(lp) or (shaft.has_area() and shaft.has_point(lp)):
				behind = true
		if behind:
			break
	# self_modulate만 흐리게 한다 — modulate를 쓰면 건물에 깐 그림자까지 같이 흐려질 수 있다
	self_modulate.a = move_toward(self_modulate.a, behind_alpha if behind else 1.0, fade_speed * minf(delta, 0.05))
	for piece in _shaft_pieces:
		piece.self_modulate = self_modulate

## 시차 — 카메라가 기준에서 벗어난 만큼 (1 - parallax) 비율로 민다
func _follow_camera() -> void:
	if parallax == Vector2.ONE:
		return
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var cam_shift: Vector2 = cam.get_screen_center_position() - parallax_reference
	position = _rest + cam_shift * (Vector2.ONE - parallax)

## 지금 시차로 밀린 만큼(월드 px) — 전선(`PowerLine`)이 그림 끝을 붙이는 데 쓴다
func parallax_shift() -> Vector2:
	return position - _rest

