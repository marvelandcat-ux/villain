extends Sprite2D

## 캐릭터 **앞에** 그려지는 그림(번화가 전봇대, 2026-10-08). 지하철 앞 기둥(`ForegroundPillars`)처럼
## 캐릭터가 그 뒤에 들어가면 반투명해져서 완전히 가려지지 않는다.
## 시차(parallax)는 안 준다 — 전봇대에 걸린 전선이 밟는 발판이라, 전봇대만 움직이면 전선 끝이 떨어져 보인다

## 그림에서 실제로 보이는 영역(원본 픽셀). 전봇데.png 실측 — 그림을 바꾸면 다시 잴 것
@export var opaque_rect: Rect2 = Rect2(250, 35, 589, 1484)
## 캐릭터 뒤에 있을 때 투명도와 바뀌는 빠르기(초당)
@export var behind_alpha: float = 0.4
@export var fade_speed: float = 6.0
## 판정 여유(월드 px) — 몸이 살짝만 걸쳐도 흐려지게
@export var margin: float = 20.0

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
	modulate.a = move_toward(modulate.a, behind_alpha if behind else 1.0, fade_speed * minf(delta, 0.05))
