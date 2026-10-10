@tool
extends Node2D

## `HerePolice`가 시키는 대로 **몸 돌린 자취**만 그리는 노드.
## 값은 전부 부모가 들고 있다 — 여기선 "어디에 깔릴지"만 맡는다(몸통보다 앞 순서라 인물 뒤에 깔린다)

func _draw() -> void:
	var boss: Node = get_parent()
	if boss != null and boss.has_method("draw_trail"):
		boss.draw_trail(self)
