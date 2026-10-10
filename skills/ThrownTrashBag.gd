extends ThrownStone

## 번화가 맵 스킬로 던지는 쓰레기 봉투(2026-10-08). 돌(`ThrownStone`)과 같고 두 가지만 다르다:
## - `set_bag_size()`로 **스택만큼 커진다**(그림 + 판정 같이)
## - 원웨이 발판·전선은 **뚫고 지나간다**(포물선이라 아래에서 발판을 스치면 허공에서 사라져 보였다)

## 그림과 판정을 mult배로 키운다 — add_child 뒤, launch 전에 부를 것
func set_bag_size(mult: float) -> void:
	var visual: Node2D = get_node_or_null("Visual")
	if visual:
		visual.scale *= mult
	for child in get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D:
			# 씬의 도형은 모든 봉투가 같이 쓰므로 새로 만들어 바꾼다
			var circle := CircleShape2D.new()
			circle.radius = child.shape.radius * mult
			child.shape = circle

func _on_body_entered(body: Node2D) -> void:
	if PhysicsQuery.is_one_way_only(body):
		return
	super._on_body_entered(body)
