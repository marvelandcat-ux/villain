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
## 입에서 끝까지 뻗어 나가는 데 걸리는 시간(초). 판정도 같이 뻗는다(2026-10-10 — 예전엔 한 번에 다 생겼다)
@export var extend_time: float = 0.12
## 뻗는 동안 시작 두께(제 두께 대비) — 가늘게 나와서 굵어진다
@export_range(0.05, 1.0, 0.05) var extend_start_thickness: float = 0.35
## 유지되는 동안 두께가 꿀렁이는 폭(제 두께 대비)과 빠르기(라디안/초) — 혈사포처럼 살아 있는 기둥
@export var wobble: float = 0.08
@export var wobble_speed: float = 42.0
## 사라지는 데 걸리는 시간(초). 이 동안 **가운데로 가늘어지며** 옅어진다
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
## 다 뻗었을 때의 값들 — 매 프레임 `_apply_shape()`가 뻗은 정도·두께만 바꿔 다시 놓는다
var _full_length: float = 1.0
var _clipped: float = 1.0
var _height: float = 1.0
var _body := Rect2(0, 0, 1, 1)
var _sx: float = 1.0
var _sy: float = 1.0
var _vis_offset := Vector2.ZERO
## 생긴 뒤 흐른 시간(초). 음수면 아직 안 움직인다(에디터 미리보기)
var _age: float = -1.0

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
	monitoring = true
	monitorable = true
	_age = 0.0
	_apply_shape(0.0, extend_start_thickness)

## 벽에 막히면 그 지점까지의 길이를 돌려준다. 캐릭터는 뚫고 지나가야 하므로 레이캐스트에서 전부 제외한다
func _clip_to_wall(length: float) -> float:
	if not stop_at_wall or Engine.is_editor_hint():
		return length
	var hit: Dictionary = PhysicsQuery.raycast_ignoring_fighters(
		self, global_position, global_position + Vector2(_facing * length, 0.0))
	if hit.is_empty():
		return length
	return maxf(absf(hit.position.x - global_position.x), 1.0)

## 판정 사각형과 그림을 같은 자리에 만든다 — 보이는 기둥 = 맞는 기둥.
## 벽에 막히면 **그림을 눌러 줄이지 않고 잘라낸다** (고정 그림이라 누르면 찌그러진다)
func _build_beam(length: float, height: float, stacks: int, visual_offset: Vector2 = Vector2.ZERO) -> void:
	_full_length = length
	_clipped = _clip_to_wall(length)
	_height = height
	_vis_offset = visual_offset
	_collision.shape = RectangleShape2D.new()

	var texture: Texture2D = _texture_for(stacks)
	_body = _body_rect_for(stacks, texture)
	_visual.texture = texture
	_visual.visible = texture != null
	_visual.centered = false
	_visual.region_enabled = true
	# 몸통 영역(body)이 판정 사각형에 딱 맞는 배율. 왼쪽을 볼 때는 scale.x가 음수라 그림이 뒤집힌다
	_sx = _facing * length / maxf(_body.size.x, 1.0)
	_sy = height / maxf(_body.size.y, 1.0)
	_apply_shape(1.0, 1.0)

## 지금 모양을 놓는다 — reveal = 입에서 얼마나 뻗었나(0~1, 벽에 막힌 길이 기준), thick = 두께 배수(1 = 제 두께).
## 판정은 뻗은 만큼만, 두께는 그대로(꿀렁임은 그림만). 그림은 **세로 한가운데를 축으로** 두꺼워지고 얇아진다 —
## 예전엔 윗변이 고정된 채 늘어나 위에서 아래로 내려오는 것처럼 보였다(2026-10-10 사용자 지적)
func _apply_shape(reveal: float, thick: float) -> void:
	var shown: float = maxf(_clipped * clampf(reveal, 0.0, 1.0), 0.5)
	var rect := _collision.shape as RectangleShape2D
	if rect:
		rect.size = Vector2(shown, _height)
	_collision.position = Vector2(_facing * shown * 0.5, 0.0)

	if _visual.texture == null:
		return
	var sy: float = _sy * maxf(thick, 0.0)
	_visual.scale = Vector2(_sx, sy)
	# centered=false라 position이 그림의 왼쪽 위 모서리 — 몸통 왼쪽 끝이 입에, 세로 한가운데가 입 높이에 오도록 역산한다.
	# visual_offset은 **그림만** 밀어낸다 (판정은 그대로) — x는 바라보는 방향 기준이라 양수가 항상 앞쪽
	_visual.position = Vector2(
		-_body.position.x * _sx + _vis_offset.x * _facing,
		-(_body.position.y + _body.size.y * 0.5) * sy + _vis_offset.y)
	# 뻗은 만큼(그리고 벽에 막힌 만큼)만 보이게 오른쪽을 잘라낸다. 영역 시작을 (0,0)으로 둬야 위 좌표 계산이 그대로 맞는다
	var tex_size: Vector2 = _visual.texture.get_size()
	var cut: float = _body.position.x + _body.size.x * (shown / maxf(_full_length, 0.001))
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

## 에디터 미리보기용 — 판정도 시간도 없이 다 뻗은 기둥 모양만 만든다 (characters/SkillRangePreview.gd가 호출)
func build_preview(direction: float, length: float, height: float, stacks: int = -1, visual_offset: Vector2 = Vector2.ZERO) -> void:
	_facing = signf(direction) if direction != 0.0 else 1.0
	_build_beam(length, height, stacks, visual_offset)

## 뻗기 → 꿀렁이며 유지 → 가운데로 가늘어지며 사라짐. 판정은 유지가 끝나는 순간 꺼진다
func _process(delta: float) -> void:
	super(delta)
	if _age < 0.0 or Engine.is_editor_hint():
		return
	_age += minf(delta, 0.05)
	if _age < extend_time:
		var k: float = _age / maxf(extend_time, 0.001)
		var r: float = 1.0 - pow(1.0 - k, 3.0)
		_apply_shape(r, lerpf(extend_start_thickness, 1.0, r))
		return
	var t: float = _age - extend_time
	if t < active_duration:
		_apply_shape(1.0, 1.0 + wobble * sin(t * wobble_speed))
		return
	if monitoring:
		monitoring = false
		monitorable = false
	var u: float = (t - active_duration) / maxf(fade_duration, 0.001)
	if u >= 1.0:
		queue_free()
		return
	_apply_shape(1.0, 1.0 - u * u)
	_visual.modulate.a = 1.0 - u
