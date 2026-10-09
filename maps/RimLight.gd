extends Node2D

## 캐릭터 조명(위에서 오는 빛) 광원(2026-10-08, 번화가 밤). 이 노드가 있는 맵에서는 캐릭터(리그 `Visual`)의
## **윗가장자리에 빛**이 맺히고 **아랫가장자리는 그늘**지며 파츠 안에도 위아래 명암이 생긴다 — 지붕처럼 위는 밝고 밑은 어둡다.
## 셰이더는 `characters/RimLight.gdshader`, 파츠에 붙이는 건 `BodyRig.set_rim_light()` — 여기선 매 프레임 값만 넣어 준다.
## 기본은 **평행광**(`directional`, 바로 위에서) — 사용자 결정(2026-10-08 "맨 위에서 빛이 온다는 가정").
## `directional`을 끄면 이 노드의 자리가 광원이 되어 캐릭터 위치 따라 빛 받는 쪽이 바뀐다(가로등 느낌).
## ⚠️ 모든 윤곽선에 두르는 게 아니다 — `rim_focus`가 높을수록 빛을 정면으로 받는 가장자리만 밝다

@export_group("빛")
## 켜면 자리와 상관없이 `direction`(캐릭터→광원)에서 오는 평행광
@export var directional: bool = true
@export var direction: Vector2 = Vector2(0.0, -1.0)
## 0이 아니면 이 거리(월드 px)에서 세기가 0이 된다(자리 광원일 때만 뜻이 있다)
@export var falloff_radius: float = 0.0
@export_group("윗가장자리 빛(림)")
@export var rim_color: Color = Color(0.85, 0.92, 1.0)
@export_range(0.0, 2.0) var rim_strength: float = 0.7
## 두께(화면 픽셀)
@export_range(0.5, 8.0) var rim_px: float = 2.0
## 빛을 정면으로 받는 가장자리만(1) ~ 옆면까지 넓게(0)
@export_range(0.0, 1.0) var rim_focus: float = 0.55
@export_group("아랫가장자리 그늘")
@export var shade_color: Color = Color(0.10, 0.08, 0.16)
@export_range(0.0, 1.0) var shade_strength: float = 0.35
@export_range(0.5, 12.0) var shade_px: float = 3.0
@export_group("위아래 명암")
## 파츠 안 그라데이션. 0.1이면 위 끝 +10%, 아래 끝 -10%
@export_range(0.0, 0.5) var gradient_strength: float = 0.10
@export_group("")
## 빛을 받을 그룹들. 소환물 리그도 `Visual`이 있으면 넣을 수 있다
@export var groups: PackedStringArray = ["fighters"]

var _rigs: Array = []

func _process(_delta: float) -> void:
	var seen: Array = []
	for group in groups:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node2D
			if body == null:
				continue
			var rig: Node = body.get_node_or_null("Visual")
			if rig == null or not rig.has_method("set_rim_light"):
				continue
			var to_light: Vector2 = global_position - body.global_position
			var dir: Vector2 = direction.normalized() if directional else to_light.normalized()
			var falloff: float = 1.0
			if not directional and falloff_radius > 0.0:
				falloff = clampf(1.0 - to_light.length() / falloff_radius, 0.0, 1.0)
			rig.set_rim_light({
				"light_dir": dir,
				"rim_color": rim_color,
				"rim_strength": rim_strength * falloff,
				"rim_px": rim_px,
				"rim_focus": rim_focus,
				"shade_color": shade_color,
				"shade_strength": shade_strength * falloff,
				"shade_px": shade_px,
				"gradient_strength": gradient_strength * falloff,
			})
			seen.append(rig)
	_rigs = seen

func _exit_tree() -> void:
	for rig in _rigs:
		if is_instance_valid(rig):
			rig.clear_rim_light()
