class_name HazardPlatform
extends Area2D

## 밟으면 소량의 데미지를 입는 놀이터 낙뎀 플랫폼 — 캐릭터별로 쿨타임을 둬서 매 프레임 연속으로 틱되는 걸 막는다 (촉법소년 상징 맵)
@export var damage: int = 4
@export var tick_interval: float = 1.0

var _cooldowns: Dictionary = {}

func _process(delta: float) -> void:
	for area in get_overlapping_areas():
		if area is Hurtbox:
			# Hurtbox 주인이 Fighter가 아닐 수 있다(일진 패거리) — as로 받아 아니면 건너뛴다
			var f := area.fighter as Fighter
			if f == null:
				continue
			var left: float = _cooldowns.get(f, 0.0) - delta
			if left <= 0.0:
				f.take_map_damage(damage)
				left = tick_interval
			_cooldowns[f] = left
