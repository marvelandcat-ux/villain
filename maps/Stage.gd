class_name Stage
extends Node2D

## 스테이지 좌우 폭 (플레이어 이동 가능 범위)
@export var stage_width: float = 960.0

func _ready() -> void:
	var combat_hud: CombatHUD = get_node_or_null("CombatHUD")
	if combat_hud == null:
		return
	var fighters := get_tree().get_nodes_in_group("fighters")
	if fighters.size() >= 2:
		combat_hud.setup(fighters[0], fighters[1])

## 씬에 배치된 PlayerSpawn 마커들을 이름 순으로 반환한다
func get_player_spawn_points() -> Array[Marker2D]:
	var spawns: Array[Marker2D] = []
	for child in get_children():
		if child is Marker2D and child.name.begins_with("PlayerSpawn"):
			spawns.append(child)
	spawns.sort_custom(func(a, b): return a.name < b.name)
	return spawns
