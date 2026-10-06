class_name PhysicsQuery
extends RefCounted

## 레이캐스트 공용 헬퍼 — 캐릭터끼리는 몸으로 서로를 막지 않으므로(Fighter._ignore_other_fighters),
## 맵에 붙는 판정용 레이캐스트(바닥 찾기, 벽까지 거리 재기 등)는 전부 "fighters" 그룹을
## 제외해야 한다. 여러 스킬·이펙트가 각자 이 코드를 따로 들고 있던 것을 한 곳으로 모음
## (GlassShard/LiquorSplash/DashSkill/MouseGrab/VomitBeam이 전부 이 방식을 쓰고 있었다).

## from -> to로 레이캐스트를 쏘되 "fighters" 그룹(모든 캐릭터)은 통과시킨다.
## ctx는 get_tree()/get_world_2d()를 부를 노드(보통 self)를 넘긴다
static func raycast_ignoring_fighters(ctx: Node, from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collide_with_areas = false
	var excludes: Array[RID] = []
	# 소환물(고양이·일진 패거리)도 캐릭터와 같은 레이어라 같이 통과시킨다 — 안 빼면 투사체·토 기둥이 고양이 몸에 막힌다
	for group in ["fighters", "catmom_cats", "iljin_crew"]:
		for f in ctx.get_tree().get_nodes_in_group(group):
			if f is PhysicsBody2D:
				excludes.append(f.get_rid())
	query.exclude = excludes
	return ctx.get_world_2d().direct_space_state.intersect_ray(query)

## from에서 곧장 아래로 probe_distance만큼 레이캐스트해 바닥 윗면 y를 찾는다.
## 못 찾으면(공중 등) fallback_y를 그대로 돌려준다
static func ground_y_below(ctx: Node, from: Vector2, probe_distance: float, fallback_y: float) -> float:
	var hit: Dictionary = raycast_ignoring_fighters(ctx, from, from + Vector2(0.0, probe_distance))
	return fallback_y if hit.is_empty() else hit.position.y
