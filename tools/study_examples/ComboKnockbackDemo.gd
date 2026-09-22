extends SceneTree

## 공부용 예제 — ComboMeleeAttack의 "데미지 비례 넉백" 물리를 직접 계산·검증해보는 스크립트.
##
## 실행 방법 (프로젝트 루트에서):
##   <Godot 실행 파일> --headless --path . --script res://tools/study_examples/ComboKnockbackDemo.gd
##
## CLAUDE.md 설명(촉법소년 콤보 항목):
## "데미지 비례 푸시백으로 바꿨다 — 앞 타 밀리는 거리 = pushback_base(23) + 실제 데미지 x
##  pushback_per_damage(5)px" / "거리에서 첫 속도를 거꾸로 구한다: v = sqrt(2 x HITSTUN_FRICTION x 거리)"
##
## 즉 기획자는 "속도"가 아니라 "몇 px 밀려나는가"로 생각하고 싶어했다. 그래서 코드는
## 목표 거리를 먼저 정해두고, 등가속도 운동 공식을 거꾸로 풀어 필요한 초기 속도를 역산한다.

const HITSTUN_FRICTION := 900.0  # characters/Fighter.gd의 실제 상수와 동일
const PUSHBACK_BASE := 23.0
const PUSHBACK_PER_DAMAGE := 5.0


## "이만큼 밀어내고 싶다"는 거리 목표를 역산해서 초기 속도를 구한다.
## 등가속도 운동 공식 v^2 = 2 * a * s 를 v에 대해 풀면: v = sqrt(2 * a * s)
func velocity_for_distance(distance: float) -> float:
	return sqrt(2.0 * HITSTUN_FRICTION * distance)


## 실제로 그 초기 속도로 마찰을 받으며 미끄러뜨려보고, 정말 원하는 거리만큼 가는지
## 프레임 단위(60fps)로 재현해서 검증한다 — "공식이 맞는지"를 직접 눈으로 확인하는 절차다
func simulate_slide(initial_velocity: float, fps: int = 60) -> float:
	var v := initial_velocity
	var traveled := 0.0
	var dt := 1.0 / fps
	while v > 0.0:
		traveled += v * dt
		v = max(v - HITSTUN_FRICTION * dt, 0.0)
	return traveled


func _init() -> void:
	print("=== 데미지별 목표 넉백 거리 -> 필요한 초기 속도 -> 실제 시뮬레이션 검증 ===\n")
	var damages := [3, 4, 7, 14]  # 1타 / 2타 / 3타 / 공격력 2배 예시 (CLAUDE.md 실측값 참고)
	for damage in damages:
		var target_distance: float = PUSHBACK_BASE + damage * PUSHBACK_PER_DAMAGE
		var v := velocity_for_distance(target_distance)
		var verified := simulate_slide(v)
		print("데미지 %d -> 목표 거리 %.1fpx -> 필요 속도 %.1fpx/s -> 시뮬레이션 결과 %.2fpx" % [damage, target_distance, v, verified])

	print("\n왜 이 공식이 필요한가?")
	print("- 게임 엔진에 실제로 넘길 수 있는 값은 '속도'뿐인데, 기획 의도는 '거리'로 정하고 싶다.")
	print("- 그래서 원하는 거리를 먼저 정하고, 물리 공식을 거꾸로 풀어 필요한 속도를 계산한다.")
	print("- CLAUDE.md의 경고: 경직이 먼저 풀리면 속도가 0이 되어 목표보다 덜 밀리므로,")
	print("  '다 미끄러질 때까지' 경직 시간을 보장해야 한다 (link_stun_margin이 이걸 처리한다).")
	print("\n직접 해볼 것: PUSHBACK_PER_DAMAGE를 8로 바꿔서 다시 실행해보고,")
	print("판정 상자(캐릭터 앞 40px, 75px 이내)를 벗어나지 않으려면 combo_lunge를 얼마나 늘려야 할지 계산해보자.")
	print("\n참고: 목표 거리보다 시뮬레이션 결과가 항상 조금 더 크게 나온다(약 5~7%).")
	print("이건 버그가 아니라 '연속적인 물리 공식'과 '프레임 단위로 뚝뚝 끊어 계산하는 게임 물리'의")
	print("차이 때문이다 — 게임은 매 프레임(1/60초)마다 속도를 깎기 전의 속도로 먼저 이동하므로")
	print("이론값보다 살짝 더 멀리 간다. 실제 게임 개발에서 자주 마주치는 '이론 vs 실측' 오차의 예시다.")
	quit()
