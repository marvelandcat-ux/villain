extends Node2D

## 악플러 풍차(회전 난무)에 잘린 투사체의 반쪽 조각.
## 잘린 자리에서 튀어 오르며 돌다가 바닥에 닿으면 그 자리에 라운드 끝까지 남는다.
## Projectile.slice_in_half()가 위/아래 반쪽 두 개를 만들어 맵에 붙인다(캐릭터 자식이면 좌우 반전에 휩쓸린다).

## 떨어지는 중력(px/초²)
const GRAVITY: float = 900.0

var _vel: Vector2 = Vector2.ZERO
## 도는 속도(라디안/초)
var _spin: float = 0.0
## 이 높이(월드 y)에 닿으면 멈춘다
var _ground_y: float = 0.0
## 바닥에 닿아 멈췄는지
var _landed: bool = false
var _sprite: Sprite2D

## tex/region/scale/centered = 원본 투사체 그림 그대로, world_pos = 잘린 자리,
## vel = 튀어 나가는 속도, spin = 도는 속도(라디안/초)
func setup(tex: Texture2D, region_enabled: bool, region: Rect2, sprite_scale: Vector2, centered: bool, world_pos: Vector2, vel: Vector2, spin: float) -> void:
	global_position = world_pos
	_vel = vel
	_spin = spin
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.region_enabled = region_enabled
	_sprite.region_rect = region
	_sprite.scale = sprite_scale
	_sprite.centered = centered
	add_child(_sprite)
	# 아래 바닥을 미리 찾아둔다(못 찾으면 조금 아래를 바닥으로 친다)
	_ground_y = PhysicsQuery.ground_y_below(self, world_pos, 2000.0, world_pos.y + 600.0)

func _physics_process(delta: float) -> void:
	if _landed:
		return
	_vel.y += GRAVITY * delta
	global_position += _vel * delta
	rotation += _spin * delta
	# 바닥에 닿으면 그 자리에 멈춰 라운드 끝까지 남는다
	if global_position.y >= _ground_y:
		global_position.y = _ground_y
		_landed = true
