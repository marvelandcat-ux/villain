extends SceneTree

## 공부용 예제 — Fighter.set_modifier/clear_modifier가 왜 필요한지 직접 비교해보는 스크립트.
##
## 실행 방법 (프로젝트 루트에서):
##   <Godot 실행 파일> --headless --path . --script res://tools/study_examples/ModifierStackDemo.gd
##
## CLAUDE.md에 적힌 실제 버그 스토리를 재현한다:
## "예전에는 set(property, value)로 직접 덮어써서 디버프 두 개가 겹치면
##  나중 게 먼저 걸린 걸 지워버리는 버그가 있었음 — 지금은 해결됨"
##
## 실제 코드(characters/Fighter.gd의 set_modifier/clear_modifier)는 이동속도·공격력 등
## 여러 property에 훨씬 복잡하게 쓰이지만, 핵심 아이디어만 뽑아 이 파일 하나로 압축했다.


## --- 1) 문제가 있던 옛날 방식: 그냥 곱해서 직접 대입 ---
class NaiveFighter:
	var move_speed: float = 200.0

	## 나중에 건 효과가 이전에 걸려있던 효과를 통째로 지워버린다
	func apply_slow(multiplier: float) -> void:
		move_speed = 200.0 * multiplier


## --- 2) 지금 프로젝트가 쓰는 방식 (set_modifier를 단순화한 버전) ---
class SafeFighter:
	var base_move_speed: float = 200.0
	## property 이름 -> {id -> 배율} 로 따로 저장해뒀다가, 값을 읽을 때 전부 곱한다
	var _modifiers: Dictionary = {}

	func set_modifier(property: String, id, value: float) -> void:
		if not _modifiers.has(property):
			_modifiers[property] = {}
		_modifiers[property][id] = value

	func clear_modifier(property: String, id) -> void:
		if _modifiers.has(property):
			_modifiers[property].erase(id)

	## 실제 값은 이 함수를 거쳐서만 읽는다 — base 값에 걸려있는 배율을 전부 곱해서 최종값을 만든다
	func get_move_speed() -> float:
		var result := base_move_speed
		if _modifiers.has("move_speed_multiplier"):
			for id in _modifiers["move_speed_multiplier"]:
				result *= _modifiers["move_speed_multiplier"][id]
		return result


func _init() -> void:
	print("=== 1. 옛날 방식 (직접 대입) — 디버프 두 개가 겹치면? ===")
	var naive := NaiveFighter.new()
	print("기본 이동속도: ", naive.move_speed)
	naive.apply_slow(0.5)  # 모래사장 둔화 (0.5배)
	print("모래사장 밟음 -> ", naive.move_speed, " (기대: 100)")
	naive.apply_slow(0.7)  # 도발 디버프 (0.7배) — 모래사장 효과가 곱해져야 하는데 그냥 덮어써진다
	print("도발까지 당함 -> ", naive.move_speed, " (기대: 두 효과가 곱해진 70, 실제로는 140 -> 버그!)")
	naive.apply_slow(0.5)  # 도발이 풀려서 모래사장 효과만 다시 걸었다고 가정하면
	print("도발 풀림, 모래사장만 다시 -> ", naive.move_speed, " (원래 곱해져 있어야 할 다른 효과가 다 날아감)\n")

	print("=== 2. 지금 방식 (id별로 저장한 뒤 곱셈) — 서로 안 지움 ===")
	var safe := SafeFighter.new()
	print("기본 이동속도: ", safe.get_move_speed())
	safe.set_modifier("move_speed_multiplier", "sand_pit", 0.5)
	print("모래사장 밟음 -> ", safe.get_move_speed(), " (기대: 100)")
	safe.set_modifier("move_speed_multiplier", "taunt", 0.7)
	print("도발까지 당함 -> ", safe.get_move_speed(), " (기대: 100 * 0.7 = 70)")
	safe.clear_modifier("move_speed_multiplier", "taunt")
	print("도발만 풀림 -> ", safe.get_move_speed(), " (기대: 모래사장 효과 100은 그대로 남음)")
	safe.clear_modifier("move_speed_multiplier", "sand_pit")
	print("모래사장에서도 나감 -> ", safe.get_move_speed(), " (기대: 원래 속도 200)\n")

	print("핵심: '누가 걸었는지(id)'를 기억해두면, 나중에 그 효과만 골라서 뗄 수 있다.")
	print("이게 characters/Fighter.gd의 set_modifier/clear_modifier가 하는 일이다.")
	quit()
