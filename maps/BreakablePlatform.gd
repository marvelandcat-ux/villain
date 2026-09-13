class_name BreakablePlatform
extends StaticBody2D

## 부술 수 있는 통과형 발판. 평소엔 다른 원웨이 발판과 똑같이 서 있을 수 있지만,
## break_platform()이 호출되면(GroundPoundSkill 등) 잠깐 사라졌다가 respawn_time 뒤 되돌아온다.
##
## get_tree().create_timer()가 아니라 자식 Timer(RespawnTimer)를 쓰는 이유: 라운드 리로드처럼
## 이 노드가 타이머보다 먼저 사라지는 경우, get_tree() 타이머는 SceneTree에 속해 살아남아서
## 해제된 노드를 건드리려다 에러가 난다(CLAUDE.md에 정리된 함정). 자식 Timer는 부모와 함께
## 사라지므로 콜백 자체가 실행되지 않아 안전하다
@export var respawn_time: float = 4.0

@onready var _visual: Node2D = $Visual
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _respawn_timer: Timer = $RespawnTimer

var _broken: bool = false

func _ready() -> void:
	_respawn_timer.wait_time = respawn_time
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_respawn)

## 부서졌으면 아무 반응 없음(이미 부서진 발판을 또 부술 수는 없다)
func break_platform() -> void:
	if _broken:
		return
	_broken = true
	_visual.visible = false
	# 물리 스텝이 진행 중인 프레임에 곧바로 바꾸면 안전하지 않을 수 있어 한 프레임 미룬다
	_collision.set_deferred("disabled", true)
	_spawn_debris()
	_respawn_timer.start()

func _respawn() -> void:
	_broken = false
	_visual.visible = true
	_collision.disabled = false

## 부서지는 순간 발판 색 그대로 파편이 사방으로 튀는 연출 (DashSkill의 CrashBurst를 그대로 재사용)
func _spawn_debris() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var burst := CrashBurst.new()
	burst.color = _visual.color if _visual is Polygon2D else Color(0.55, 0.5, 0.48)
	burst.shard_count = 12
	burst.radius = 55.0
	parent.add_child(burst)
	burst.global_position = global_position
