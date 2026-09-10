class_name HazardPlatform
extends Area2D

## 밟으면 소량의 데미지를 입는 놀이터 낙뎀 플랫폼 — 캐릭터별로 쿨타임을 둬서 매 프레임 연속으로 틱되는 걸 막는다 (촉법소년 상징 맵)
@export var damage: int = 4
@export var tick_interval: float = 1.0

var _cooldowns: Dictionary = {}

func _process(delta: float) -> void:
	for area in get_overlapping_areas():
		if area is Hurtbox:
			var f: Fighter = area.fighter
			var left: float = _cooldowns.get(f, 0.0) - delta
			if left <= 0.0:
				f.take_damage(damage, Vector2.ZERO, -1.0, true)   # 맵 기믹이라 방어로 못 막는다
				left = tick_interval
			_cooldowns[f] = left
