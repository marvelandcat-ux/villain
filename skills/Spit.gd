class_name Spit
extends Projectile

## 일진의 친구가 뱉는 침. 공용 `Projectile`과 뼈대는 같고 세 가지가 다르다:
##
## 1. **관통한다** — 맞아도 안 사라지고 사거리 끝까지 날아간다(`Projectile`은 맞는 순간 사라진다)
## 2. **패거리(자기 편)의 몸은 그냥 통과한다** — 패거리는 길을 막는 StaticBody2D라,
##    안 뚫게 두면 오른쪽에 선 여자친구가 침을 전부 막아버린다. 벽·바닥에는 예전처럼 막힌다
## 3. **히트스캔급으로 빠르다** — 그래서 판정을 진행 방향으로 길게 늘여준다(아래 참고)

## 판정 사각형의 기본 크기(px). 실제 가로는 "한 프레임에 가는 거리"와 견줘 **더 큰 쪽**을 쓴다
@export var hit_box_size: Vector2 = Vector2(26.0, 18.0)
## 한 프레임 이동거리에 곱하는 여유. 1보다 커야 프레임과 프레임 사이에 틈이 안 생긴다
@export var sweep_margin: float = 1.3

## 날아가는 방향(단위 벡터). `aim()`으로 넣어주면 비스듬히도 날아간다
var _aim: Vector2 = Vector2.RIGHT

## 날아갈 방향을 2D로 지정한다 — **`setup()` 다음에 부를 것**(setup이 rotation을 수평으로 덮어쓴다).
## 안 부르면 예전처럼 수평으로만 간다
func aim(dir: Vector2) -> void:
	if dir.length() < 0.001:
		return
	_aim = dir.normalized()
	rotation = _aim.angle()
	# 넉백도 날아가는 쪽으로 — 위로 겨눴으면 위로 밀어 올린다
	knockback = Vector2(_aim.x, _aim.y).normalized() * knockback.length()

## 발사할 때 속도에 맞춰 판정 길이를 잡아준다.
## **이게 없으면 빠를수록 안 맞는다** — Area2D 판정은 매 물리 프레임에 "지금 겹쳐 있나"만 보기 때문에,
## 3600px/초면 한 프레임에 60px를 뛰어서 폭 40px짜리 상대를 통째로 건너뛰고 지나가 버린다
func setup(direction: float, speed: float, projectile_damage: int, shooter: Fighter) -> void:
	super.setup(direction, speed, projectile_damage, shooter)
	_fit_hit_box(speed)

func _fit_hit_box(speed: float) -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var step: float = absf(speed) / 60.0 * sweep_margin
	# **씬의 도형을 고치지 않고 새로 만들어 끼운다** — .tscn의 sub_resource는 인스턴스끼리 공유돼서,
	# 그걸 직접 고치면 이미 날아가고 있는 다른 침의 판정까지 같이 바뀐다
	var rect := RectangleShape2D.new()
	rect.size = Vector2(maxf(hit_box_size.x, step), hit_box_size.y)
	shape_node.shape = rect

## **비스듬히도 날아가야 해서 이동을 직접 한다** — `Projectile._physics_process`는 `position.x`만 더해서
## 수평으로만 갈 수 있다. 속도선(늘이기)·잔상은 부모 것을 그대로 쓴다
func _physics_process(delta: float) -> void:
	position += _aim * absf(_velocity_x) * delta
	_apply_stretch()
	_update_trail(delta)

## 맞아도 사라지지 않는다(관통).
## **`super`를 부르면 안 된다** — `Projectile._on_area_entered`가 맞는 순간 queue_free()를 부른다.
## 두 단계 위(`Hitbox`)를 직접 부를 방법이 없어서, 거기서 하던 "데미지 한 번 주기"만 그대로 한다
func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)

func _on_body_entered(body: Node2D) -> void:
	# 그룹으로 거른다 — 클래스 이름을 직접 쓰면 skills 폴더가 캐릭터 폴더를 알아야 한다
	if body.is_in_group("iljin_crew"):
		return
	super._on_body_entered(body)
