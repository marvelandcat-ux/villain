class_name Crown
extends Area2D

## 놀이터 꼭대기의 왕관. 먼저 닿은 쪽이 "놀이터의 왕"이 된다.
##
## 왕이 되면:
##  - 떨어지는 화분에 데미지를 안 받는다 (maps/FallingPot.gd가 확인)
##  - 모래사장에서 안 느려진다 (maps/SandPit.gd가 확인)
##
## 왕 표시는 Fighter.custom_data에 남긴다 — 맵이 캐릭터를 건드리지 않고 상태만 붙이는 방식이라,
## 라운드가 리셋되면 캐릭터가 새로 생기면서 표시도 같이 사라진다.
## 획득 연출(ui/CrownCutIn.tscn)은 "crown_cutin" 그룹으로 찾아서 재생한다 —
## 궁극기 컷인이 "ultimate_cutin" 그룹을 쓰는 것과 같은 방식이라, 맵에 연출 노드가 없으면 그냥 넘어간다.

## 누군가 왕관을 차지한 순간 (연출을 붙일 자리)
signal crowned(king: Fighter)

## Fighter.custom_data에 왕 표시를 남길 때 쓰는 키
const KING_KEY := "playground_king"

## 왕관을 먹은 뒤에도 왕관이 다시 나타나서 뺏을 수 있는지.
## false면 한 번 정해진 왕이 그 라운드 끝까지 간다
@export var retakeable: bool = false
## retakeable일 때 왕관이 다시 나타나기까지 걸리는 시간(초)
@export var respawn_time: float = 12.0

## 지금 왕관을 쓰고 있는 쪽 (없으면 null)
var _king: Fighter

## 이 캐릭터가 놀이터의 왕인가. 화분·모래 쪽에서 이걸 보고 판단한다
static func is_king(fighter: Fighter) -> bool:
	if fighter == null or not is_instance_valid(fighter):
		return false
	return fighter.custom_data.get(KING_KEY, false)

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if not visible or not (area is Hurtbox):
		return
	var fighter: Fighter = area.fighter
	if fighter == null or not is_instance_valid(fighter) or fighter == _king:
		return
	_give_crown(fighter)

func _give_crown(fighter: Fighter) -> void:
	# 왕은 한 명뿐이라 이전 왕의 표시는 지운다
	if is_instance_valid(_king):
		_king.custom_data.erase(KING_KEY)
	_king = fighter
	fighter.custom_data[KING_KEY] = true
	hide()
	crowned.emit(fighter)

	# 연출 노드가 심어져 있으면 재생한다 (없는 맵에서는 조용히 넘어간다)
	var cutin: Node = get_tree().get_first_node_in_group("crown_cutin")
	if cutin and cutin.has_method("play"):
		cutin.play(fighter)

	if not retakeable:
		return
	# 자식 Timer를 쓴다 — 라운드가 끝나 맵이 먼저 정리되면 이 왕관도 같이 사라져 콜백이 안 돈다
	var timer := Timer.new()
	timer.wait_time = respawn_time
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(func():
		show()
		timer.queue_free()
	)
	timer.start()
