class_name RageBuffSkill
extends Skill

## 열등감 느끼기 — 사용하면 일정 시간 자신의 기본공격 공격속도가 50% 빨라진다.
## 기획 문서에 발동 조건이 미정이었던 오픈 이슈를 액티브 사용식으로 임의 확정한 것 (악플러 스킬2)
@export var attack_speed_multiplier: float = 1.5
@export var duration: float = 5.0
## 버프가 도는 동안 화난 얼굴(리그의 action_head_texture)로 바꿀지.
## 그림이 없는 캐릭터는 리그 쪽에서 그냥 넘어가므로 켜둬도 영향이 없다
@export var rage_face: bool = true

## 화난 얼굴을 원래대로 되돌리기까지 남은 시간(초)
var _face_left: float = 0.0
## 얼굴을 바꿔둔 몸(BodyRig) — 시간이 다 되면 여기에 되돌려달라고 한다
var _rig: Node2D

func _execute(fighter: Fighter) -> void:
	fighter.apply_temp_multiplier("attack_speed_multiplier", attack_speed_multiplier, duration)
	# 열받아서 씩씩거리는 동안 붉으락푸르락한 오라
	fighter.set_tint("rage", Color(1.0, 0.55, 0.35), duration)
	var visual: Node2D = fighter.get_node_or_null("Visual")
	if visual == null:
		return
	# 버프가 도는 내내 화난 얼굴이 "기본 얼굴"이 된다 — 그 사이에 맞으면 피격 표정이
	# 잠깐 덮었다가, 그게 끝나면 원래 얼굴이 아니라 이 화난 얼굴로 돌아온다
	if rage_face and visual.has_method("set_action_face"):
		_rig = visual
		_rig.set_action_face(true)
		_face_left = duration
	var tween := fighter.create_tween()
	tween.set_loops(3)
	tween.tween_property(visual, "scale", Vector2(1.12, 1.12), 0.15)
	tween.tween_property(visual, "scale", Vector2(1, 1), 0.15)

## 버프 시간이 다 되면 원래 얼굴로 돌려놓는다.
## SceneTree 타이머가 아니라 이 노드의 _process로 세는 이유 — 라운드 리로드나 대전 도중 나가기로
## 씬이 정리되면 이 노드도 같이 사라져서, 이미 없어진 리그를 건드릴 일이 아예 생기지 않는다
func _process(delta: float) -> void:
	super._process(delta)   # 쿨타임 감소
	if _face_left <= 0.0:
		return
	_face_left = maxf(_face_left - delta, 0.0)
	if is_zero_approx(_face_left):
		_restore_face()

func _restore_face() -> void:
	if _rig and is_instance_valid(_rig) and _rig.has_method("set_action_face"):
		_rig.set_action_face(false)
	_rig = null
	_face_left = 0.0

func _exit_tree() -> void:
	_restore_face()
