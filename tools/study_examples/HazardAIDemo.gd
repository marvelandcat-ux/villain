extends SceneTree

## 포트폴리오 예제 — 그룹(태그)만 보고 위험을 피하는 AI (controllers/AIController.gd의 _try_dodge_hazard).
##
## 실행 방법 (프로젝트 루트에서):
##   <Godot 실행 파일> --headless --path . --script res://tools/study_examples/HazardAIDemo.gd
##
## AI는 "지하철 맵이면 이렇게 피해라"처럼 맵·기믹 이름으로 분기하지 않는다. 대신
## - "ai_danger_zone" 그룹: is_dangerous()가 true면 위험
## - "ai_safe_spot" 그룹: 피할 수 있는 자리
## 두 그룹만 본다. 그래서 새 기믹을 만들 때 is_dangerous() 하나만 구현하면 AI 코드는 안 고쳐도 된다.
## (실제 AI는 걸어가서 이단 점프로 발판에 올라타는 것까지 하지만, 여기서는 "어디로 갈지" 판단만 뽑았다)


## 지하철 열차 (maps/SubwayTrain.gd 단순화) — 경고 중이거나 달리는 중이면 위험
class SubwayTrain extends Node2D:
	var state := "WAITING"

	func _ready() -> void:
		add_to_group("ai_danger_zone")

	func is_dangerous() -> bool:
		return state != "WAITING"


## 가상의 새 기믹 — AI 코드를 한 줄도 안 고치고 추가한다
class FallingRocks extends Node2D:
	var shaking := false

	func _ready() -> void:
		add_to_group("ai_danger_zone")

	func is_dangerous() -> bool:
		return shaking


## 피신 지점 (maps/AISafeSpot.gd와 동일) — 맵에 놓기만 하면 된다
class SafeSpot extends Marker2D:
	func _ready() -> void:
		add_to_group("ai_safe_spot")


## AI 판단 부분만 뽑은 것
class SimpleAI:
	var tree: SceneTree
	var x := 0.0

	func hazard_active() -> bool:
		for hazard in tree.get_nodes_in_group("ai_danger_zone"):
			if hazard.has_method("is_dangerous") and hazard.is_dangerous():
				return true
		return false

	func nearest_safe_spot() -> Node2D:
		var nearest: Node2D = null
		var nearest_dist := INF
		for spot in tree.get_nodes_in_group("ai_safe_spot"):
			var d := absf(spot.global_position.x - x)
			if d < nearest_dist:
				nearest = spot
				nearest_dist = d
		return nearest

	## 실제 _try_dodge_hazard처럼: 피할 이유도, 피할 곳도 있을 때만 피한다. 아니면 평소대로 싸운다
	func decide() -> String:
		if not hazard_active():
			return "평소대로 싸운다"
		var spot := nearest_safe_spot()
		if spot == null:
			return "위험하지만 피할 곳이 없다 -> 평소대로 싸운다"
		return "위험! x=%.0f 발판으로 피신한다" % spot.global_position.x


func _initialize() -> void:
	var train := SubwayTrain.new()
	root.add_child(train)
	var left_spot := SafeSpot.new()
	left_spot.position = Vector2(-280, 155)
	root.add_child(left_spot)
	var right_spot := SafeSpot.new()
	right_spot.position = Vector2(280, 155)
	root.add_child(right_spot)

	var ai := SimpleAI.new()
	ai.tree = self
	ai.x = 100.0

	print("=== AI 위치 x=100, 피신 발판은 x=-280 / x=280 ===\n")
	print("1. 열차 대기 중      -> ", ai.decide())
	train.state = "WARNING"
	print("2. 열차 경고등 켜짐  -> ", ai.decide())
	ai.x = -200.0
	print("3. (AI가 x=-200에 있으면) -> ", ai.decide())
	train.state = "WAITING"
	print("4. 열차 지나감       -> ", ai.decide())

	print("\n=== 새 기믹 '떨어지는 돌' 추가 — AI 코드는 그대로 ===")
	var rocks := FallingRocks.new()
	root.add_child(rocks)
	print("5. 돌 가만히 있음    -> ", ai.decide())
	rocks.shaking = true
	print("6. 돌이 흔들림       -> ", ai.decide())

	print("\n=== 피신 발판이 없는 맵 ===")
	for spot in [left_spot, right_spot]:
		root.remove_child(spot)
		spot.free()
	print("7. 돌이 흔들림       -> ", ai.decide())

	print("\n핵심: AI는 '무엇이' 위험한지 모른다. '위험한가?'만 묻는다.")
	print("그래서 기믹이 늘어나도 AI 코드는 한 줄도 안 바뀐다 (실제로 열차 1종이지만 새 기믹도 바로 된다).")
	quit()
