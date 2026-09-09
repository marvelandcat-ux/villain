@tool
class_name VomitBeam
extends Hitbox

## 토하기 기둥 — 날아가는 투사체가 아니라 입에서 앞으로 한 번에 뻗는 가로 기둥이다(아이작 혈사포 느낌).
## Hitbox를 상속해서 기둥에 닿은 Hurtbox에게 데미지를 준다.
##
## Skill은 Node라서 좌표를 못 가지므로(부모 트랜스폼 체인이 끊긴다) 이 노드는 스킬의 자식이 아니라
## 맵에 직접 붙이고 global_position으로 입 위치에 놓는다 — ScreamCone과 같은 방식.
##
## **그림은 술 스택마다 따로 그린 걸 갈아끼운다(2026-09-09 변경).**
## 예전에는 그림 한 장을 스택별 길이에 맞춰 늘렸는데, 0스택이면 783px 그림을 40px로 1/20 찌그러뜨려서
## 무슨 그림인지 알아볼 수가 없었다. 지금은 스택 수를 그대로 stack_textures의 index로 쓴다.
##
## 그림마다 "기둥 몸통이 캔버스 어디에 그려져 있는지"가 다르므로(튀는 방울·반짝임이 사방에 흩어져 있다)
## stack_body_rects에 그 영역을 적어둔다. 그 영역이 판정 사각형과 정확히 겹치게 배치된다 —
## 보이는 기둥 = 맞는 기둥. 영역 밖의 방울들은 장식이라 판정 밖으로 삐져나온다

## 기둥이 다 뻗은 뒤 그대로 유지되는 시간(초)
@export var active_duration: float = 0.3
## 뻗어나오는 데 걸리는 시간(초). 이 동안 얇은 선에서 제 두께로 벌어진다
@export var burst_time: float = 0.07
## 사라지는 데 걸리는 시간(초)
@export var fade_duration: float = 0.15
## 맞은 상대가 밀려나는 힘. x는 정면 방향으로 자동 반전되고, y는 음수가 위쪽
@export var knockback_force: Vector2 = Vector2(200.0, -120.0)
## true면 벽에 막힌 지점에서 기둥이 끊긴다 (벽을 뚫고 그려지지 않게). 캐릭터는 그냥 통과한다
@export var stop_at_wall: bool = true

@export_group("스택별 그림")
## 술 스택 수를 그대로 index로 쓴다 (0스택 = 0번). 비워두면 아래 fallback 그림 한 장을 늘려 쓴다
@export var stack_textures: Array[Texture2D] = []
## 각 그림에서 **기둥 몸통이 차지하는 영역**(텍스처 픽셀). stack_textures와 같은 순서.
## 이 영역이 판정 사각형에 딱 맞게 놓이도록 배율·위치가 계산된다
@export var stack_body_rects: Array[Rect2] = []

## 인스펙터 배열이 비어 있을 때 쓰는 기본값. 씬에 안 걸려 있어도 무지개 기둥이 나오도록 코드에 적어둔다.
## **preload가 아니라 load를 쓴다** — 아직 임포트 안 된 그림이 섞여 있으면 preload는 스크립트 자체를 못 읽게 만든다
const DEFAULT_TEXTURE_PATHS := [
	"res://sprite/주정뱅이/토사물모음/1스택.png",
	"res://sprite/주정뱅이/토사물모음/2스택.png",
	"res://sprite/주정뱅이/토사물모음/3스택.png",
	"res://sprite/주정뱅이/토사물모음/4스택진짜.png",
]
## 위 그림들에서 기둥 몸통이 차지하는 영역 (세로 중앙선을 훑어 실측한 값).
## **그림을 갈아끼우면 이 값도 다시 재야 한다** — 캔버스 크기와 몸통 위치가 그림마다 다르다
const DEFAULT_BODY_RECTS: Array[Rect2] = [
	Rect2(877, 280, 254, 126),
	Rect2(604, 284, 943, 104),
	Rect2(161, 264, 1852, 154),
	Rect2(1, 316, 2133, 137),
]
## 위 경로를 실제로 읽어둔 것 (처음 쓸 때 한 번만 읽는다)
static var _loaded_defaults: Array[Texture2D] = []

var _facing: float = 1.0

@onready var _collision: CollisionShape2D = $Collision
@onready var _visual: Sprite2D = $Visual

## 뻗는 방향(1 또는 -1), 기둥 길이/두께(px), 최종 데미지, 시전자, 술 스택 수를 지정하고 판정·연출을 시작한다.
## 맵에 add_child로 붙이고 global_position을 입 위치로 잡은 다음에 호출할 것
func setup(direction: float, length: float, height: float, beam_damage: int, spitter: Fighter, stacks: int = -1, visual_offset: Vector2 = Vector2.ZERO) -> void:
	_facing = signf(direction) if direction != 0.0 else 1.0
	damage = beam_damage
	source_fighter = spitter
	knockback = Vector2(knockback_force.x * _facing, knockback_force.y)

	_build_beam(length, height, stacks, visual_offset)
	_play_burst()
	_run_lifetime()

## 벽에 막히면 그 지점까지의 길이를 돌려준다. 캐릭터는 뚫고 지나가야 하므로 레이캐스트에서 전부 제외한다
func _clip_to_wall(length: float) -> float:
	if not stop_at_wall or Engine.is_editor_hint():
		return length
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(_facing * length, 0.0))
	query.collide_with_areas = false
	var excludes: Array[RID] = []
	for f in get_tree().get_nodes_in_group("fighters"):
		excludes.append(f.get_rid())
	query.exclude = excludes
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return length
	return maxf(absf(hit.position.x - global_position.x), 1.0)

## 판정 사각형과 그림을 같은 자리에 만든다 — 보이는 기둥 = 맞는 기둥.
## 벽에 막히면 **그림을 눌러 줄이지 않고 잘라낸다** (고정 그림이라 누르면 찌그러진다)
func _build_beam(length: float, height: float, stacks: int, visual_offset: Vector2 = Vector2.ZERO) -> void:
	var clipped: float = _clip_to_wall(length)

	var rect := RectangleShape2D.new()
	rect.size = Vector2(clipped, height)
	_collision.shape = rect
	_collision.position = Vector2(_facing * clipped * 0.5, 0.0)

	var texture: Texture2D = _texture_for(stacks)
	var body: Rect2 = _body_rect_for(stacks, texture)
	_visual.texture = texture
	_visual.visible = texture != null
	if texture == null:
		return

	# centered=false라 position이 그림의 왼쪽 위 모서리가 된다.
	# 몸통 영역(body)의 왼쪽 끝이 입에, 세로 한가운데가 입 높이에 오도록 역산한다.
	# 왼쪽을 볼 때는 scale.x가 음수라 그림이 뒤집혀 그려지는데, 같은 식으로 위치가 맞는다
	var sx: float = _facing * length / maxf(body.size.x, 1.0)
	var sy: float = height / maxf(body.size.y, 1.0)
	_visual.centered = false
	_visual.scale = Vector2(sx, sy)
	# visual_offset은 **그림만** 밀어낸다 (판정은 그대로) — 스택별로 그림 여백이 달라서 미세 조정용이다.
	# x는 바라보는 방향으로 뒤집어서 "앞으로/뒤로"가 항상 같은 뜻이 되게 한다
	_visual.position = Vector2(
		-body.position.x * sx + visual_offset.x * _facing,
		-height * 0.5 - body.position.y * sy + visual_offset.y)

	# 벽에 막힌 만큼 그림을 오른쪽에서 잘라낸다. 영역 시작을 (0,0)으로 둬야 위 좌표 계산이 그대로 맞는다
	_visual.region_enabled = true
	var tex_size: Vector2 = texture.get_size()
	var cut: float = body.position.x + body.size.x * (clipped / maxf(length, 0.001))
	_visual.region_rect = Rect2(0.0, 0.0, minf(cut, tex_size.x), tex_size.y)

## 스택에 맞는 그림. 인스펙터 배열 -> 코드 기본값 순으로 찾는다.
## **못 찾으면 null이다** — 예전에는 옛날 갈색 토 그림으로 되돌아갔는데,
## 뭔가 잘못됐을 때 조용히 엉뚱한 그림이 나와서 원인을 찾기가 더 어려웠다. 차라리 안 보이는 게 낫다
func _texture_for(stacks: int) -> Texture2D:
	if stacks < 0:
		return null
	if stacks < stack_textures.size() and stack_textures[stacks]:
		return stack_textures[stacks]
	var found: Texture2D = _default_texture(stacks)
	if found == null:
		push_warning("VomitBeam: %d스택 그림을 못 찾았다 (임포트 전이거나 경로가 바뀜)" % stacks)
	return found

## 코드에 적어둔 기본 그림.
## **한 장이라도 못 읽으면 캐시하지 않는다** — 임포트 전에 한 번 실패한 걸 캐시해버리면
## 나중에 임포트가 끝나도 계속 실패한 상태로 남는다(갈색 토가 다시 나오던 원인)
func _default_texture(stacks: int) -> Texture2D:
	if _loaded_defaults.size() != DEFAULT_TEXTURE_PATHS.size():
		var loaded: Array[Texture2D] = []
		for path in DEFAULT_TEXTURE_PATHS:
			var tex: Texture2D = load(path) as Texture2D
			if tex == null:
				return null
			loaded.append(tex)
		_loaded_defaults = loaded
	if stacks >= 0 and stacks < _loaded_defaults.size():
		return _loaded_defaults[stacks]
	return null

## 스택에 맞는 몸통 영역. 그림을 어디서 가져왔는지와 짝이 맞아야 하므로 같은 순서로 찾는다
func _body_rect_for(stacks: int, texture: Texture2D) -> Rect2:
	if stacks >= 0:
		if stacks < stack_body_rects.size() and stack_body_rects[stacks].size.x > 0.0:
			return stack_body_rects[stacks]
		if stacks < DEFAULT_BODY_RECTS.size():
			return DEFAULT_BODY_RECTS[stacks]
	if texture == null:
		return Rect2(0.0, 0.0, 1.0, 1.0)
	return Rect2(Vector2.ZERO, texture.get_size())

## 판정은 처음부터 제 크기지만, 그림만 얇은 선에서 제 두께로 벌어지게 해서 "확 뻗는" 느낌을 준다
func _play_burst() -> void:
	var full_scale: Vector2 = _visual.scale
	_visual.scale = Vector2(full_scale.x, full_scale.y * 0.15)
	create_tween().tween_property(_visual, "scale", full_scale, burst_time).set_ease(Tween.EASE_OUT)

## 에디터 미리보기용 — 판정도 타이머도 없이 기둥 모양만 만든다 (characters/SkillRangePreview.gd가 호출)
func build_preview(direction: float, length: float, height: float, stacks: int = -1, visual_offset: Vector2 = Vector2.ZERO) -> void:
	_facing = signf(direction) if direction != 0.0 else 1.0
	_build_beam(length, height, stacks, visual_offset)

func _run_lifetime() -> void:
	monitoring = true
	monitorable = true
	var tween := create_tween()
	tween.tween_interval(active_duration)
	tween.tween_callback(_disable_hitbox)
	tween.tween_property(_visual, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(queue_free)

func _disable_hitbox() -> void:
	monitoring = false
	monitorable = false
