@tool
class_name VomitBeam
extends Hitbox

## 토하기 기둥 — 날아가는 투사체가 아니라 입에서 앞으로 한 번에 뻗는 가로 기둥이다(아이작 혈사포 느낌).
## Hitbox를 상속해서 기둥에 닿은 Hurtbox에게 데미지를 준다.
##
## Skill은 Node라서 좌표를 못 가지므로(부모 트랜스폼 체인이 끊긴다) 이 노드는 스킬의 자식이 아니라
## 맵에 직접 붙이고 global_position으로 입 위치에 놓는다 — ScreamCone과 같은 방식.
##
## 기둥의 길이·두께는 술 스택에 따라 달라지므로 VomitSkill이 계산해서 setup()으로 넘겨준다.
## 여기 있는 값들은 스택과 무관한 연출·판정 설정이다.

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

## 토사물 그림(825x273)에서 투명한 여백을 뺀, 실제로 그림이 그려진 영역.
## 이 영역만 잘라 쓰기 때문에 기둥 길이를 늘려도 앞뒤에 빈 공간이 생기지 않는다
const TEXTURE_REGION := Rect2(15, 42, 783, 159)

var _facing: float = 1.0

@onready var _collision: CollisionShape2D = $Collision
@onready var _visual: Sprite2D = $Visual

## 뻗는 방향(1 또는 -1), 기둥 길이/두께(px), 최종 데미지, 시전자를 지정하고 판정·연출을 시작한다.
## 맵에 add_child로 붙이고 global_position을 입 위치로 잡은 다음에 호출할 것
func setup(direction: float, length: float, height: float, beam_damage: int, spitter: Fighter) -> void:
	_facing = signf(direction) if direction != 0.0 else 1.0
	damage = beam_damage
	source_fighter = spitter
	knockback = Vector2(knockback_force.x * _facing, knockback_force.y)

	_build_beam(_clip_to_wall(length), height)
	_play_burst()
	_run_lifetime()

## 벽에 막히면 그 지점까지로 길이를 줄인다. 캐릭터는 뚫고 지나가야 하므로 레이캐스트에서 전부 제외한다
func _clip_to_wall(length: float) -> float:
	if not stop_at_wall:
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

## 판정 사각형과 그림을 같은 크기로 만든다 — 보이는 기둥 = 맞는 기둥
func _build_beam(length: float, height: float) -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, height)
	_collision.shape = rect
	_collision.position = Vector2(_facing * length * 0.5, 0.0)

	# centered=false라 position이 그림의 시작 모서리가 된다. 왼쪽 끝을 입에 딱 붙이고
	# 세로로는 입 높이가 한가운데 오도록 절반만큼 올린다. 왼쪽을 볼 때는 scale.x가 음수라 반대로 그려진다
	_visual.centered = false
	_visual.region_enabled = true
	_visual.region_rect = TEXTURE_REGION
	_visual.position = Vector2(0.0, -height * 0.5)
	_visual.scale = Vector2(
		_facing * length / TEXTURE_REGION.size.x,
		height / TEXTURE_REGION.size.y)

## 판정은 처음부터 제 크기지만, 그림만 얇은 선에서 제 두께로 벌어지게 해서 "확 뻗는" 느낌을 준다
func _play_burst() -> void:
	var full_scale: Vector2 = _visual.scale
	_visual.scale = Vector2(full_scale.x, full_scale.y * 0.15)
	create_tween().tween_property(_visual, "scale", full_scale, burst_time).set_ease(Tween.EASE_OUT)

## 에디터 미리보기용 — 판정도 타이머도 없이 기둥 모양만 만든다 (characters/SkillRangePreview.gd가 호출)
func build_preview(direction: float, length: float, height: float) -> void:
	_facing = signf(direction) if direction != 0.0 else 1.0
	_build_beam(length, height)

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
