# 빌런 파이터즈 (villain) — Godot 프로젝트 규칙

사이드뷰 대전 격투 게임 "빌런 파이터즈"의 Godot 프로젝트입니다. 기획 문서(캐릭터 로스터·맵·전투 시스템)는 다음 아티팩트에 정리되어 있습니다: https://claude.ai/code/artifact/661e48af-d8db-49c9-bc68-a9294790becb

전역 규칙(한국어 응답, 초보자 눈높이 설명, 안전 규칙 등)은 그대로 유지하되, 코드 스타일은 이 문서가 우선합니다 — 전역 CLAUDE.md는 Unity/C# 기준이지만 이 프로젝트는 **Godot/GDScript**로 개발합니다.

## 프로젝트 정보

- 엔진: Godot 4.6, GDScript
- 렌더러: Forward Plus, 3D 물리엔진 Jolt (프로젝트 기본값 — 실제 게임은 2D)
- 장르: 사이드뷰 대전 격투, 바운스어택류(타격 후 넉백을 다시 잡아채는) 콤보 중심
- 전투 원칙: 피격 경직(히트스턴) 최소화 지향, 지형·벽을 활용하는 스테이지 기믹

## 확정된 아키텍처 방향

기획 문서의 "캐릭터 시스템 프레임워크" 절에서 정한 방향을 실제로 구현한 결과입니다. **캐릭터 전용 `.gd` 스크립트는 만들지 않습니다** — 모든 캐릭터 씬은 `characters/Fighter.gd`를 루트 스크립트로 쓰고, 스탯 리소스(`.tres`)와 스킬 노드 조합만으로 차이를 만듭니다.

- `characters/Fighter.gd`: 모든 캐릭터의 공용 베이스(`CharacterBody2D`). 이동/점프/중력, HP(`take_damage`/`heal`/`health_changed` 시그널), 스킬 슬롯(`skill_1`/`skill_2`/`skill_ultimate`/`basic_attack` — 자식 노드 이름 `Skill1`/`Skill2`/`SkillUltimate`/`BasicAttack`으로 자동 연결됨), 자유 형식 데이터 저장소 `custom_data`(예: 주정뱅이 술 스택)를 담당
- 버프·디버프(`move_speed_multiplier` 등)는 직접 대입하지 않고 **`fighter.set_modifier(property, id, value)`/`clear_modifier(property, id)`**로 건다. 같은 property에 여러 효과가 동시에 걸려도 서로 안 지우고 곱해져서 적용된다(id별로 따로 저장했다가 곱함). 일정 시간만 유지되는 임시 효과는 `apply_temp_multiplier(property, value, duration)`가 자동으로 id를 발급해서 만료 처리까지 해줌. 술 스택처럼 켰다 껐다 하는 지속 효과는 `"drink_stacks"` 같은 고정 문자열 id로 직접 `set_modifier`/`clear_modifier` 호출 (`DrinkSkill.gd`/`VomitSkill.gd` 참고). **예전에는 `set(property, value)`로 직접 덮어써서 디버프 두 개가 겹치면 나중 게 먼저 걸린 걸 지워버리는 버그가 있었음 — 지금은 해결됨**
- **캐릭터끼리는 몸 충돌을 하지 않는다.** `Fighter._ignore_other_fighters()`가 `_ready()`에서 같은 씬의 다른 Fighter들과 양방향으로 `add_collision_exception_with`를 걸어둔다 — 안 걸면 캐릭터가 **상대 머리 위에 올라서서 발판처럼 밟고 다닐 수 있다**(실제로 나온 문제). 새로 스폰된 쪽이 자기 `_ready()`에서 기존 캐릭터들과 걸어두므로 라운드 리로드·훈련장 캐릭터 교체도 자동으로 처리된다
  - **충돌 레이어를 바꾸지 않은 이유:** 레이어를 건드리면 바닥·벽·발판까지 같이 영향을 받는다. 예외 처리로 빼는 건 몸(`CharacterBody2D`)끼리의 충돌뿐이고, 공격 판정(`Hitbox`/`Hurtbox`)은 Area2D라 그대로 서로를 감지한다 — 헤드리스로 기본공격 데미지·발판 착지가 그대로인 것까지 확인함
  - 대신 두 캐릭터가 같은 자리에 겹쳐 설 수 있게 됐다(스매시브라더스류와 같은 방식). 서로 밀어내는 처리가 필요하면 따로 넣어야 한다
- `skills/Skill.gd`: 모든 스킬의 공용 베이스(`Node`). 쿨타임 카운트다운과 `can_use()`/`use(fighter)`를 여기서 한 번만 구현. 새 스킬은 이 클래스를 상속해서 `_execute(fighter)`만 오버라이드
- `combat/Hitbox.gd` / `combat/Hurtbox.gd`: 실제 데미지 판정. `Hurtbox`는 Fighter의 자식 Area2D로 피격을 받아 `take_damage()`를 부르고, `Hitbox`는 공격 판정 Area2D로 `Hurtbox`와 겹치면 데미지를 준다 (자기 자신은 무시)
- `skills/MeleeAttack.gd`: 기본공격 공용 스킬 — 캐릭터 앞에 히트박스를 잠깐 켰다 끈다. `damage`/`range`만 캐릭터마다 다르게 지정해서 재사용 (사탕찌르기, 키보드 휘두르기, 술병깨기, 팻말 때리기 전부 이걸 씀)
- `combat/SkillClashManager.gd`: 두 Fighter가 같은 스킬 슬롯을 `match_window`(0.15초) 안에 함께 쓰면 "동시 사용"으로 보고 화면을 멈추고 `ui/SkillClashPopup.tscn`(연타 미니게임)을 띄운다. 이긴 쪽만 실제 효과가 나가고 진 쪽은 `Skill.cancel_use()`로 쿨타임만 소모된 채 취소된다. `Stage.gd`가 `_ready()`에서 심어두고 Fighter는 `"skill_clash_manager"` 그룹으로 찾는다(훈련장처럼 매니저가 없는 씬은 클래시 없이 바로 발동). **`skill_1`/`skill_2`/`궁극기`만 이 클래시를 탄다 — `Fighter.use_basic_attack()`은 일부러 클래시 매니저를 거치지 않고 항상 바로 나간다.** 기본공격은 스킬보다 훨씬 자주(쿨타임 1초) 나가는 잽이라, 여기까지 클래시에 걸리면 마주칠 때마다 화면이 멈추고 연타 게임이 뜨는 꼴이 된다
- **주의(실제로 겪은 버그):** `get_tree().create_timer(t).timeout.connect(func(): 어떤노드.뭔가 = 값)`처럼 다른 노드를 건드리는 콜백을 예약할 때, 그 노드가 타이머가 끝나기 전에 사라지면(대전 도중 나가기·다시하기 등으로 씬이 통째로 정리되는 경우) `ERROR: Lambda capture ... was freed`가 나면서 사라진 노드를 건드리려다 에러가 난다. `get_tree().create_timer()`는 SceneTree에 속해서 관련 노드보다 오래 살아남기 때문. 해결책은 `is_instance_valid()` 체크가 아니라 **그 노드(또는 관련 스킬 노드)의 자식으로 `Timer` 노드를 만들어서 씀** — 부모가 사라지면 자식 Timer도 같이 사라져서 콜백 자체가 아예 실행되지 않는다(`Fighter._after()`, `FirePlate.gd`, `Projectile.gd` 참고). `await get_tree().create_timer(t).timeout`처럼 하나만 기다리고 끝내는 짧은 대기(`MeleeAttack`의 히트박스 on/off 등)는 이 문제가 잘 안 생겨서 그대로 둬도 됨
- **주의(실제로 겪은 버그):** `Skill`은 `Node`를 상속해서 `Node2D`가 아니다. 그래서 `Hitbox`(Area2D)를 Skill 노드의 자식으로 둔 경우 `hitbox.position = ...`(부모 상대 좌표)을 쓰면 부모 트랜스폼 체인이 끊겨서 항상 `(0,0)` 기준으로 배치된다 — 겉으로는 에러 없이 조용히 공격이 안 맞는 버그가 된다. 이런 히트박스는 반드시 `hitbox.global_position = fighter.global_position + Vector2(range * fighter.facing, 0)`처럼 **global_position으로 직접 배치**할 것 (`MeleeAttack.gd` 참고). 반대로 `Projectile`/`FirePlate`처럼 맵(Node2D)에 직접 `add_child`하는 경우는 이 문제가 없음
- 이동을 잠깐 가로채는 스킬(돌진 등)은 `Fighter.movement_override`에 자기 자신을 등록하고 `get_move_velocity_x()`/`after_physics(fighter, delta)`를 구현 (`skills/DashSkill.gd` 참고)
- `Fighter.is_feared`/`apply_fear(duration)`: 공포 상태(지하철 아저씨 `skills/FearSkill.gd`)면 이동은 되지만 `use_skill_1/2/ultimate/basic_attack`이 전부 무시된다("무서워서 반격을 못 하는" 느낌). `set_tint`로 색조도 같이 걸어서 눈으로 구분됨
- `combat/Hitbox.gd`의 `pull_to_source`/`pull_strength`: true면 고정된 `knockback` 대신, 맞는 순간 공격자 쪽 방향을 계산해서 끌어당긴다(청소기 흡입 — `skills/VacuumSkill.gd`)
- `skills/AoeAttack.gd`: `MeleeAttack`(전방 사각형)과 별개로, 캐릭터 자신을 중심으로 한 원형 범위 공격 공용 스킬. `damage`/`radius`에 더해 `slow_multiplier`/`slow_duration`을 주면 맞은 상대에게 `apply_temp_multiplier`로 둔화 디버프도 건다(층간소음 청년 기타연주, 재사용 가능)
- **주정뱅이 술 스택 밸런스(2026-09-01 조정):** `DrinkSkill.max_stacks`는 **3**(예전 5). 술 쿨타임이 3초라 풀스택까지 6초. 토하기는 **날아가는 투사체가 아니라 입에서 한 번에 뻗는 가로 기둥**이라(아이작 혈사포 느낌) 길이를 직접 지정한다 — `base_range=40`(0스택, 캐릭터 한 칸 폭)에서 `range_per_stack=310`씩 늘어 **3스택이면 970px**, 두께는 `base_height=14`에서 `height_per_stack=4`씩 늘어 3스택에 26px. 970px는 가로맵 벽 안쪽 폭(920px)보다 길어서 **풀스택이면 벽에 딱 붙어 쏴도 반대편 벽까지 닿는다**(헤드리스 검증: 왼쪽 벽에 붙어 발사 → 기둥 끝이 정확히 오른쪽 벽 안쪽 면 x=460에서 끊김)
- `skills/VomitBeam.gd` + `skills/VomitBeam.tscn`: 토하기 기둥. `Hitbox`를 상속하고 `ScreamCone`과 같은 방식으로 **맵에 직접 붙여 `global_position`으로 입 위치에 놓는다**(Skill은 Node라 좌표가 없음). 길이·두께는 스택에 따라 달라지므로 `VomitSkill`이 계산해서 `setup(방향, 길이, 두께, 데미지, 시전자)`로 넘기고, 기둥이 유지되는 시간·뻗는 연출·넉백은 씬이 들고 있다. 그림(`sprite/주정뱅이/토프로토.png`)은 투명 여백을 뺀 영역만 `region_rect = Rect2(15, 42, 783, 159)`로 잘라 쓰고 `centered = false`로 왼쪽 끝을 입에 맞춘 뒤 길이만큼 늘린다 — 왼쪽을 볼 때는 `scale.x`를 음수로 줘서 뒤집는다(판정 사각형은 음수 스케일을 안 쓰고 `_facing`을 곱한 위치에 직접 놓는다). `stop_at_wall`이 켜져 있으면 레이캐스트로 벽까지 거리를 재서 기둥을 끊는데, **캐릭터는 뚫고 지나가야 하므로 `fighters` 그룹 전체를 레이캐스트에서 제외**한다. BB탄은 계속 공용 `Projectile.tscn`(흰 사각형)을 쓴다
- **주의(실제로 겪은 버그):** `Projectile`이 **쏜 사람 본인의 Hurtbox/CharacterBody2D에도 반응해서 발사 즉시 사라지던** 문제. 총구는 캐릭터 앞 30px에 잡히는데, 판정이 커지거나(토사물 36px 폭) 투사체가 느리면(0스택 토하기 100px/s) 첫 물리 프레임에 아직 시전자 몸(반지름 20)과 겹쳐 있어서 그대로 `queue_free()`가 됐다. BB탄은 판정이 작고(반지름 5) 빨라서(500px/s) 우연히 안 걸렸을 뿐. `_on_area_entered`/`_on_body_entered` 둘 다 `source_fighter`면 무시하도록 고침. **투사체 판정을 키우거나 느리게 만들 때 재발 주의**
- `AIController`가 원거리 캐릭터인지 판단할 때 `skill_2`의 `projectile_scene`뿐 아니라 **`beam_scene`도 함께 본다** — 토하기가 투사체에서 기둥으로 바뀌면서 프로퍼티 이름이 달라졌는데, 이걸 안 고치면 주정뱅이가 갑자기 근접 캐릭터처럼 달려든다

- **주의(실제로 겪은 버그):** GDScript에서 **해제된 객체는 `== null` 비교가 `true`로 나온다**(`is_instance_valid()`만 false). 그래서 `if source_fighter != null and not is_instance_valid(source_fighter)` 같은 방어 코드는 **절대 발동하지 않는다** — 앞 조건에서 걸러져 버림. 훈련장에서 캐릭터를 바꾸면(`maps/TrainingGround.gd:96`이 `_fighter.queue_free()`) 시전자만 사라지고 맵에 붙은 기둥·투사체는 남는데, 그 상태로 상대가 판정에 닿으면 해제된 객체를 `Hurtbox.take_hit()`의 `Fighter` 타입 인자로 넘기게 돼서 타입 에러가 났다. `Hitbox`는 `source_fighter`를 setter가 달린 프로퍼티로 바꿔 **주인이 있었는지를 `_has_source` 불리언으로 따로 기억**하게 해서 고쳤다 — 지하철 열차처럼 주인이 원래 없는(null) 히트박스는 계속 정상 동작해야 하므로 무작정 `is_instance_valid`로만 막으면 안 된다
- **주의(실제로 겪은 버그):** `Projectile`의 수명 타이머를 `_ready()`에서 만들고 있어서, `VomitSkill`이 `add_child` **다음 줄**에서 `projectile.lifetime`을 넣어도 이미 기본값 1.5초로 타이머가 만들어진 뒤였다 — 스택별 사거리(`lifetime_per_stack`)가 한동안 **아무 효과도 없었고**, 실측 사거리가 계산값의 5배로 나왔다. 위에 적힌 `add_child` → `_ready()` 동기 실행 함정과 같은 건이다. 타이머 생성을 `setup()`으로 옮겨서 고침(`skills/Projectile.gd._start_lifetime_timer()`). BB탄은 `lifetime`을 안 건드리고 기본값을 쓰므로 영향 없음. (토하기는 그 뒤 기둥 방식으로 바뀌어 `Projectile`을 더 이상 쓰지 않지만, 수정 자체는 남겨둔다)
- `skills/ScreamConeUltimate.gd` + `skills/ScreamCone.tscn`: 주정뱅이 궁극기 "괴성". 입 앞에서 정면으로 퍼지는 **부채꼴** 판정을 맵에 띄워서 데미지+넉백을 주고, 맞은 상대에게 점프력 디버프(`jump_multiplier`/`debuff_duration`)를 건다 — 예전 `JumpDebuffUltimate`(판정 없이 디버프만)를 대체함. `ScreamCone`은 `Hitbox`를 상속하고, **화면에 보이는 빨간 부채꼴(`RangeFill`/`RangeOutline`)을 판정 폴리곤(`Collision`)과 똑같은 점 배열로 그려서** 보이는 범위 = 맞는 범위가 되게 한다. 안쪽을 퍼져나가는 검은 음파는 `wave_texture`에 스프라이트를 넣으면 그걸 쓰고, 비어 있으면 코드로 그린 검은 호가 대신 나간다(겹 수 `wave_count`, 간격 `wave_interval`, 속도 `wave_travel_time`). 음파는 부모 Node2D의 `scale`을 키우는 방식이라 앞으로 나가는 것과 부채꼴로 벌어지는 것이 한 번에 된다.
  **값이 사는 곳이 갈려 있다:** 데미지·입 위치·디버프처럼 캐릭터마다 다를 값은 캐릭터 씬의 `SkillUltimate` 노드,
  부채꼴 길이(`cone_range`)·각도(`half_angle_deg`)·연출은 전부 `ScreamCone.tscn` 루트. 한 값은 반드시 한 군데에만 둔다 —
  처음엔 길이·각도를 양쪽에 두고 스킬이 씬 값을 덮어썼는데, `ScreamCone.tscn`에서 아무리 고쳐도 게임에선 안 먹는 함정이 돼서 스킬 쪽을 지웠다
- `Fighter.vault_jump: bool`: true인 캐릭터(지하철 아저씨)는 기본공격이 없는 대신, 점프할 때 `_play_vault_effect()`가 회전 트윈으로 "개찰구를 뛰어넘는" 연출을 보여준다
- **주의(실제로 겪은 버그):** `add_child(node)`로 노드를 트리에 붙이면 `_ready()`가 **그 자리에서 동기적으로** 실행된다 — `add_child()` 호출 다음 줄에서 그 노드의 export 변수를 세팅해도, `_ready()`는 이미 그 전에(즉 기본값으로) 끝나버린 뒤다. `_ready()` 안에서 `wait_time = lifetime` 처럼 export 값을 캐싱하면 호출자가 나중에 설정한 값이 아니라 기본값이 캐싱되는 버그가 생김(고양이 아주머니 `skills/CatPet.gd`에서 실제로 겪음). 해결책: 그런 캐싱은 `_ready()`가 아니라 **첫 `_physics_process`/`_process` 호출 시점**(`_initialized` 플래그로 한 번만 실행)으로 미룰 것 — 그때는 호출자의 프로퍼티 설정이 이미 끝나 있음이 보장됨

## 조작 / AI

- `controllers/PlayerController.gd`: 이동/점프/공격/스킬 입력을 읽어서 부모 Fighter를 조작. `player_index`(1 또는 2)에 따라 `p1_*`/`p2_*` 액션을 읽으므로 P1/P2 모두 사람이 조작할 수 있다
- `controllers/AIController.gd`: 목표 Fighter와의 거리를 보고 접근/거리유지/후퇴/기본공격/스킬 사용을 스스로 결정하는 단순 AI. Fighter 입장에서 플레이어가 조작하는지 AI가 조작하는지 구분이 없음(둘 다 `fighter.move()`, `fighter.use_skill_1()` 등 같은 공용 메서드만 호출)
  - `skill_2`가 투사체 스킬(`projectile_scene` 프로퍼티를 가짐 — BBGunSkill/VomitSkill)이면 원거리 캐릭터로 판단해서 `ranged_distance`(기본 180px)를 유지하며 견제. 캐릭터마다 분기하지 않고 스킬 구성만 보고 판단하는 방식이라 새 캐릭터가 원거리 스킬을 skill_2에 넣기만 하면 자동으로 이 행동을 함
  - 쓸 수 있는 스킬이 하나도 없을 때(`_all_skills_on_cooldown`) 가끔 확률적으로 한 발짝 물러나서 쿨타임을 버는 "후퇴" 상태가 있음. 바닥에 있을 때 낮은 확률로 그냥 점프도 함(움직임이 자연스러워 보이도록)
  - **주의(실제로 겪은 버그):** 뒤로 빠지거나 거리를 벌릴 때 `fighter.move(-dir)`을 쓰는데, `Fighter.move()`는 이동 방향으로 `facing`도 같이 바꾼다 — 그래서 후퇴 중엔 상대를 등지게 되고, 그 상태에서 투사체 스킬을 쓰면 반대 방향으로 나가버려 절대 안 맞는 버그가 있었다. 후퇴 이동을 시킨 직후 `fighter.facing`을 상대 쪽으로 다시 강제해서 고침
- **조작키 확정(2026-08-30)** — `project.godot`의 InputMap에 `p1_*`/`p2_*` 액션으로 등록되어 있음. 같은 키보드를 둘이 나눠 쓰는 로컬 대전 기준:

| 조작 | P1 | P2 | 액션 이름 |
|---|---|---|---|
| 이동 | A / D | ← / → | `p1_left`·`p1_right` / `p2_left`·`p2_right` |
| 점프 | W | ↑ | `p1_jump` / `p2_jump` |
| 기본공격 | F | L | `p1_basic_attack` / `p2_basic_attack` |
| 스킬1 | G | K | `p1_skill_1` / `p2_skill_1` |
| 스킬2 | H | J | `p1_skill_2` / `p2_skill_2` |
| 궁극기 | R | P | `p1_ultimate` / `p2_ultimate` |
| 플랫폼 아래로 내려가기 | S 누른 채 W | ↓ 누른 채 ↑ | `p1_down`+`p1_jump` / `p2_down`+`p2_jump` |

  - 이전의 임시 배정(방향키 이동 + Z 기본공격 + 숫자키 1/2/3)은 폐기됨. 액션 이름도 `basic_attack`/`skill_3` → `p1_basic_attack`/`p1_ultimate` 식으로 바뀜
  - "P2는 항상 AI라 2P 키가 필요 없다"던 이전 결론도 이 결정으로 뒤집힘 — 키는 다 등록해뒀지만, `Stage.gd`는 아직 P2에 `ClaudeAIController`를 붙이므로 **실제 2P 사람 조작을 켜려면 `_spawn_fighter(..., is_ai)` 인자를 false로 넘기는 분기(모드 선택)가 추가로 필요**하다
  - **이단 점프(구현 완료, 2026-09-03):** 점프 키를 공중에서 한 번 더 누르면 다시 뛴다. 조작키는 그대로(W / ↑)고 `Fighter.jump()`가 `is_on_floor()`인지 보고 지상 점프와 공중 점프를 알아서 나눈다. `Fighter.max_air_jumps`(기본 1)·`Fighter.air_jump_velocity`(기본 -420)는 `gravity`/`jump_velocity`와 같이 **static var**라 훈련장에서 바로 바꿔볼 수 있다
    - 공중 점프는 지금까지의 낙하 속도를 무시하고 `velocity.y`를 새로 덮어쓴다 — 떨어지는 중에 눌러도 제대로 뜬다
    - 남은 횟수(`_air_jumps_left`)는 `apply_physics()`의 `move_and_slide()` **뒤에** `is_on_floor()`를 보고 다시 채운다(앞에서 채우면 이번 프레임의 착지가 아직 반영되지 않아 한 프레임 늦는다)
    - 높이: 지상 점프 71.1px, 이단까지 이어 뛰면 **165.4px**(실측). 지하철 승강장의 의자 발판을 "지상 점프로는 절대 못 닿고 이단 점프로만 닿는" 145px에 둔 근거다. **전 맵 공통 변경이라 링아웃형 맵(학교 옥상)이 그만큼 관대해졌다** — 밸런스 확인 필요
  - **플랫폼 아래로 내려가기(구현 완료, 2026-09-03):** 아래키를 누른 채 점프하면 `PlayerController._drop_through_platform()` → `Fighter.drop_through_platform()`이 발밑 발판을 통과해 아래층으로 내려간다. 통과 가능한 발판 위가 아니면(진짜 지면이거나 공중) 그냥 평범한 점프가 나간다 — 입력이 씹힌 것처럼 느껴지지 않게
    - **충돌 레이어를 통째로 끄지 않고 `add_collision_exception_with(발판)`으로 그 발판 하나만 예외 처리한다.** 레이어를 끄면 같은 레이어인 진짜 지면·벽까지 통과해서 맵 밖으로 떨어진다. 예외는 `Fighter.DROP_THROUGH_DURATION`(0.35초) 뒤 자식 Timer(`_after`)로 되돌린다
    - 발밑 발판은 직전 `move_and_slide()`가 남긴 충돌 목록(`get_slide_collision`)에서 **법선이 위를 향하는 면**만 골라, 그 도형에 `is_shape_owner_one_way_collision_enabled()`가 켜져 있는지로 판별한다(`Fighter._get_one_way_floor()`)

## 캐릭터 몸(스프라이트 조립)

`characters/BodyRig.tscn` — 러프 스프라이트 조각(머리/몸/손/발)을 Sprite2D로 조립해둔 공용 몸. 캐릭터 씬의 `Visual` 자리에 인스턴스로 넣는다(현재 6명 전원 적용 — 임시 사각형 Polygon2D를 쓰는 캐릭터는 없다). 이름이 `Visual`이라 피격 시 빨개지는 연출(`Fighter._flash_hit`)이나 궁극기 연출이 그대로 동작한다.

- **파일 배치 규칙:** 여러 캐릭터가 함께 쓰는 파츠는 `sprite/body/`(몸통·손·발), 캐릭터 전용 파츠는 `sprite/<캐릭터>/몸/`에 둔다(주정뱅이는 몸·발·머리를 전용으로 쓰고 손만 공용)
  - 층간소음·고양이 아주머니·지하철 아저씨는 `sprite/층간소/`·`sprite/캣/`·`sprite/지하철빌/` 바로 아래에 `발.png`/`손.png`를 두고 리그에서 각자 참조한다(`몸/` 하위 폴더를 안 씀 — 폴더 구조가 캐릭터마다 갈려 있으니 새 파츠를 찾을 땐 두 군데 다 볼 것). **이 세 명의 `손.png`는 지금 `sprite/body/손.png`와 바이트까지 같은 복사본**이라 화면상 차이가 없다 — 나중에 캐릭터 색으로 칠하면 리그가 이미 각자 파일을 보고 있으므로 그대로 반영된다
  - 발은 캐릭터 색 신발로 각자 다르다(층간소음 빨강 / 고양이 아주머니 자홍 / 지하철 아저씨 파랑). 캔버스가 공용 `발.png`와 같은 179x101이라 `BodyRig`의 기본 배율을 그대로 쓰고 텍스처만 덮어쓴다
- **인게임 머리는 옆모습, 선택창 초상화는 정면 — 그림이 두 장씩이다.** 전투가 사이드뷰라 리그의 `Head`에는 옆모습을 넣고(층간소음은 `층간소음측면.png`), 정면 그림은 `GameState.PORTRAITS`에만 등록한다(층간소음 청년은 `층간소음머리.png`). 정면 그림을 리그에 잘못 넣으면 옆으로 걸어가는데 얼굴만 정면을 보는 꼴이 된다
  - **초상화는 배경이 투명해야 한다.** `CharacterSelect`가 캐릭터 색 타일(`CHARACTER_COLORS`) 위에 그림을 겹쳐 얹기 때문에, 흰 배경이 남아 있으면 색이 안 비치고 흰 사각형으로 보인다. `sprite/body/지하철정면.png`이 흰 배경이라 테두리에서부터 플러드 필로 배경만 깎아 `sprite/지하철빌/지하철빌런정면.png`로 저장해 쓰고 있다(머리카락도 흰색이라 '흰 픽셀 전부 지우기'로는 안 된다 — 반드시 테두리에서 번져 나가는 방식으로). 원본은 그대로 남겨뒀다
  - 초상화는 6명 전원 등록 완료. 고양이 아주머니(`sprite/body/캣맘정면.png`)은 받은 그림이 이미 배경 투명이라 그대로 등록했다
- `BodyRig.tscn`의 `Head`에는 텍스처가 비어 있다 — 머리는 캐릭터마다 다르므로 각자 상속 씬에서 지정한다
- **캐릭터별 머리는 씬 상속으로 만든다.** `BodyRig.tscn`을 상속한 씬을 캐릭터 폴더에 두고 `Head`의 텍스처/위치/크기만 덮어쓴다(예: `characters/akpeulleo/AkpeulleoRig.tscn`). 이러면 몸/손/발 위치를 `BodyRig.tscn`에서 한 번만 고쳐도 전 캐릭터에 반영되고, 에디터에서 미리보기도 제대로 된다. 현재 6명 전원 적용됨 — 주정뱅이(`JujeongbaengiRig`)·악플러(`AkpeulleoRig`)·촉법소년(`ChokbeopsonyeonRig`)·층간소음(`FloorNoiseRig`)·고양이 아주머니(`CatMomRig`)·지하철 아저씨(`SubwayVillainRig`).
  - **새 캐릭터 리그를 만들 땐 배율을 눈대중으로 잡지 말고 기존 캐릭터에 맞춘다.** 기준값은 화면에 보이는 그림(투명 여백을 뺀 실제 영역) 크기로 **몸 약 33x30px, 머리 약 55x55px**이고, 머리의 보이는 중심이 리그 원점 기준 약 `(-2, -32.8)`에 오게 위치를 잡는다. PNG마다 여백이 달라서 캔버스 크기로 계산하면 어긋난다 — `Image.get_used_rect()`로 실제 그림 영역을 재서 배율을 역산할 것
- 조각 위치는 **에디터에서 `BodyRig.tscn`을 직접 열어** 옮긴다. 캐릭터 씬 쪽에서 `Visual`을 펼쳐 만지면 그 캐릭터만의 덮어쓰기가 생기니 주의
- `characters/BodyRig.gd`: 애니메이션 파일 없이 **코드로 걷기 동작**을 만든다. 부모 Fighter의 속도를 보고 **두 발이 반 바퀴 어긋난 채로 계속 앞뒤를 오가게** 한다(`foot_stride`만큼 — 앞발/뒷발이 번갈아 바뀌는 교차 걸음). 앞으로 나가는 동안에만 발끝을 `foot_swing_deg`만큼 들고, 뒤로 밀리는 동안엔 바닥을 딛는 것처럼 눕힌다, 한 걸음마다 몸/머리/손을 위로 살짝 들썩이게 하며(`body_bob`), 손은 발과 반대로 앞뒤로 흔든다(`hand_swing` — 왼발이 나갈 때 오른손이 앞으로). 두 발을 서로 반대로 회전시키는 방식은 어색하다는 피드백을 받아 폐기함. 왼쪽으로 갈 때는 리그 전체의 `scale.x` 부호를 뒤집어 좌우 반전한다(크기는 안 건드리고 부호만 — 궁극기 연출이 `Visual.scale`을 만지기 때문). 각 조각의 제자리 값은 `_ready()`에서 씬에 저장된 위치를 그대로 기억하므로, **에디터에서 위치를 옮겨도 애니메이션 코드는 고칠 필요가 없다**
- 공중에 떠 있는 동안(`is_on_floor()`가 false) 두 발이 함께 `jump_foot_deg`(60도)만큼 들리고, 착지하면 원래 각도로 돌아온다
- **손에 드는 무기는 `HandRHold` 노드의 자식으로 단다.** 이 노드는 `Head`보다 **앞** 순서라(더 먼저 그려져서) 무기가 머리 뒤로 넘어가면 머리에 가려진다 — 상속 씬에서 `Head`를 덮어쓸 때 `index="6"`인 이유. 오른손(`HandR`)의 위치·회전을 코드가 매 프레임 복사해주는 배율 1짜리 빈 Node2D라서, 무기 스프라이트의 좌표/크기를 그대로 잡을 수 있다(HandR의 자식으로 달면 손 스프라이트의 0.11 배율까지 물려받아 번거롭다). 주정뱅이 소주병이 이 방식(`characters/jujeongbaengi/JujeongbaengiRig.tscn`)
- **기본공격 모션**: `Fighter.use_basic_attack()`이 실제로 공격을 발동시킨 순간 `Visual.play_attack_swing()`을 호출한다(그 메서드가 있는 비주얼만 — 아직 임시 사각형인 캐릭터는 그냥 넘어감). 오른손이 **머리 뒤쪽 위까지 크게 넘어갔다가**(`attack_raise_offset`/`attack_raise_deg`) 앞쪽 아래로 내려찍고(`attack_slam_offset`/`attack_swing_deg`) 돌아온다. 손이 회전만 하는 게 아니라 위치까지 같이 움직여야 동작이 커 보인다는 피드백을 받아 그렇게 바꿈. 전체 `attack_duration`(0.4초) 중 40~62% 구간이 실제로 내려찍는 구간
- **기본공격 중 손에 든 물건은 손 회전을 그대로 따라간다** — 술병이 손과 같이 한 바퀴 돌아간다. 한때 "휘두르는 동안 병목이 아래를 본다"는 이유로 공격 중에만 각도를 고정하는 `attack_hold_deg`를 넣었다가, **원래 동작이 더 낫다는 피드백을 받아 되돌렸다.** 다시 건드리지 말 것 — 되돌린 뒤 `8755e71`(마시기 모션 넣기 전 커밋)의 공격 관련 코드와 완전히 일치함을 확인했다
- **두 손으로 잡는 기본공격(`attack_two_handed`, 기본 false)**: 켜면 기본공격 예비동작에서 **왼손이 오른손 옆(`attack_grip_offset`)으로 붙었다가 내려찍고 나면 다시 풀린다.** 평소에는 한 손으로 무기를 들고 다니다가 때릴 때만 두 손으로 잡는 연출(악플러 키보드)용. 무기는 오른손(`HandRHold`)에 매달려 있으므로 왼손은 위치·회전만 따라가면 같이 잡은 것처럼 보인다. 붙는 타이밍은 예비동작의 앞 60% 안에 끝나서 **때리는 순간에는 이미 두 손으로 잡고 있다**. 왼손 회전도 `_apply_pose`에서 매 프레임 0으로 되돌린 뒤 덮어쓰는 방식(오른손·머리와 동일) — 안 그러면 공격이 끝나도 왼손이 돌아간 채 남는다
- 악플러 키보드는 `AkpeulleoRig.tscn`의 `HandRHold/Keyboard`. 주정뱅이 소주병과 같은 방식이다. 원본이 2172x724(그림 2083x649)라 `scale 0.0221`로 화면에서 약 46x14px. 배트처럼 손 바깥으로 뻗도록 **숫자패드 쪽 끝을 쥐게** `position (-19, -8)`에 둔다(그림 중심이 손보다 뒤에 온다)
- **악플러 기본공격은 도끼질이 아니라 야구배트 스윙이다.** 공용 `BodyRig` 기본값(머리 위로 넘겼다 내려찍기)을 쓰지 않고 `AkpeulleoRig.tscn`에서 덮어쓴다: `attack_raise_deg 35` / `attack_swing_deg 85`(총 120도 스윙) / `attack_raise_offset (-24, -6)`(뒤로 당기되 거의 안 올림) / `attack_slam_offset (24, 6)`(앞으로 밀어냄) / `attack_duration 0.45`. 각도를 더 키우면 키보드가 얼굴을 가로질러서 지저분해진다 — 실제로 45/120으로 해봤다가 낮춤. 주정뱅이는 공용 기본값(100/130/0.40)을 그대로 쓰므로 영향 없음
- **주의(실제로 겪음): 손에 든 물건의 위치 오프셋은 그림 반길이보다 작아야 한다.** `HandRHold` 자식의 `position`은 "손에서 물건 중심까지의 거리"이고, 무기는 그 손을 축으로 회전한다. 키보드를 `(-42, -19)`(길이 46)에 두면 그림 반길이(2083 x 0.0221 / 2 = 23)의 두 배라 **손에 안 잡힌 상태**가 되고, 휘두르는 순간 반지름 46짜리 원을 그리며 몸에서 완전히 떨어져 날아간다. 지금은 키보드 축(45도) 방향으로 20만큼 떨어뜨려 숫자패드 쪽 끝을 쥐게 해뒀다(스윙 내내 손과 최대 19.8px — 헤드리스로 검증). 위치를 다시 잡을 때 이 한계를 넘지 말 것
- `attack_swing_arc`(기본 0): 후려치는 구간에서 손이 직선이 아니라 **이동 방향의 아래쪽으로 부풀며 호를 그린다.** 아래로 훑어서 위로 올려치는 스윙(악플러 26)에 쓴다. 0이면 예전처럼 직선이라 주정뱅이는 영향 없음. 악플러 최종값은 `raise 25 / swing 70 / raise_offset (-24, 4) / slam_offset (26, -12) / arc 26` — 뒤·아래에서 시작해 아래를 훑고 앞·위로 올려친다
- **회전 각도와 물건 오프셋은 서로 얽혀 있다.** 오프셋이 클수록 같은 회전각이 물건을 훨씬 크게 휘두른다 — 오프셋 46일 때 총 120도를 줬더니 키보드가 화면 밖으로 날아갔다. 오프셋을 바꾸면 `attack_raise_deg`/`attack_swing_deg`도 같이 다시 봐야 한다
- **주의:** `attack_duration`을 바꾸면 `BasicAttack.windup`도 같이 맞춰야 한다. 실제로 후려치는 구간은 전체의 40~62%라, 0.40초면 windup 0.16 / 0.45초면 0.18이다. 안 맞추면 예비동작 중에 판정이 나가서 보이는 것보다 먼저 맞는다
- **술 마시기 모션(주정뱅이 스킬1)**: `DrinkSkill`이 발동하면 `Visual.play_drink_motion()`을 호출한다(기본공격과 같은 방식 — 그 메서드가 없는 비주얼은 그냥 넘어감). 고개가 `drink_head_tilt_deg`(-22도, 음수가 얼굴이 위를 보는 방향)만큼 뒤로 젖혀지고, 오른손이 `drink_hand_offset`(-16, -34)만큼 얼굴 쪽으로 올라가면서 `drink_hand_deg`(-116도)만큼 돌아 술병 목이 입을 향한다. 다 올린 뒤에는 머리와 병이 **같은 `gulp` 값으로 함께** 위아래로 들썩여서(`drink_head_bob` 2.5px, `drink_gulp_count` 3회) 병이 입에서 떨어져 보이지 않는다. 전체 `drink_duration`(1.1초) 중 0~25%가 올리기, 25~75%가 마시기, 75~100%가 내리기
- 마시기 모션은 `_pose_attack_hand()`와 같은 자리에서, **공격 다음에** 덮어쓴다(둘이 겹치면 마시기가 이김). 머리 회전은 걷기 코드가 건드리지 않으므로 손 회전과 똑같이 `_apply_pose`에서 매 프레임 0으로 되돌린 뒤 마시기가 덮어쓰는 방식 — 안 그러면 동작이 끝나도 고개가 젖혀진 채로 남는다
- 술병(`JujeongbaengiRig.tscn`의 `HandRHold/Bottle`)의 제자리는 `position (6.868347, -10.263336)` / `rotation -2.708751`(-155도) — 병목을 아래로 내려 든, 이미 "붓는" 자세다. **한 번 (5,12)/-34도(병목을 위로 든 자세)로 바꿨다가 되돌렸으니 다시 건드리지 말 것.** 소주병 원본은 뚜껑이 위인 세로 그림이라, 회전 r일 때 병목 방향은 `(sin r, -cos r)`으로 계산한다
- 제자리 각도가 이미 붓는 자세라 **마실 때 병을 추가로 돌리지 않는다**(`drink_hand_deg` 0) — 각도는 그대로 두고 위치만 입으로 올린다. 실측: 제자리 뚜껑 끝 (25, 11) → 다 올리면 (15, -15)로 입 위치 (15, -14)에 닿는다. 올라가는 길은 직선이 아니라 `drink_hand_arc`(12px)만큼 바깥으로 부풀어 호를 그린다(이동 방향의 수직으로 `sin(reach * PI)`만큼 — 출발·도착에선 0이라 튀지 않는다)
- 히트박스는 이 내리치는 순간에 맞춰야 해서 `MeleeAttack`에 `windup`(예비동작 대기시간)을 추가했다. 기본 0이라 다른 캐릭터는 그대로고, 주정뱅이만 0.16초로 맞춰둠
- 흔들림 세기·걸음 빠르기는 전부 `@export`라 인스펙터에서 조절 가능: `foot_swing_deg`(22도) / `foot_stride`(8px) / `body_bob`(2px) / `hand_swing`(5px) / `step_speed`(9) / `blend_speed`(8) / `jump_foot_deg`(60도) / `jump_blend_speed`(12)
- **아직 안 된 것:** 공격 모션

### 그림 파일을 교체할 때 (실제로 겪은 함정)

- **에디터 밖에서 PNG를 덮어써도 Godot이 다시 임포트하지 않는다.** `.godot/imported/`에 예전 텍스처가 캐시된 채로 남아서, 파일은 바뀌었는데 게임에는 **옛 그림이 그대로 나온다**(크기·유효영역까지 옛 값으로 보고된다). 새 배율을 옛 그림에 적용해 버리는 꼴이라 조용히 크기가 어긋난다. 해결: 해당 `.png.import` 파일을 지우고 `godot --headless --editor --path <프로젝트> --quit`로 한 번 돌려서 강제 재임포트할 것
- **그림을 바꾸면 배율(`scale`)과 위치(`position`)를 다시 계산해야 한다.** 원본 크기와 투명 여백이 달라지므로, 화면에서 차지하던 크기를 유지하려면 `유효영역(get_used_rect) x scale`이 예전과 같아지도록 배율을 다시 잡고, `centered` 스프라이트는 **유효영역 중심과 텍스처 중심의 차이**만큼 position도 보정해야 제자리에 온다
  - 예: 지하철 아저씨 머리를 새 그림으로 교체(2026-09-06). 옛 그림 1376x1143(유효 1136x953)·`scale (0.0528, 0.0577)` → 화면 59.98x54.99. 새 그림 762x651(유효 698x597)이라 `scale (0.085932, 0.092107)` / `position (-1.48, -33.63)`로 다시 잡아 화면 크기를 그대로 유지했다
- **캐릭터 그림을 새로 받으면 배경이 흰색으로 막혀 있는 경우가 많다.** 그대로 넣으면 캐릭터 주변에 흰 사각형이 생긴다. 지울 때는 "흰색이면 다 지우기"가 아니라 **바깥 테두리에서 번져 들어가는 방식(flood fill)**으로 지워야 한다 — 지하철 아저씨·층간소음 청년처럼 **흰 머리카락**이 있는 캐릭터는 단순 색상 제거로 머리카락까지 날아간다(검은 외곽선에 막혀서 flood fill은 안전하다)

## 스킬 로고 (쿨타임 HUD)

각 스킬 노드의 `Skill.icon`(`@export var icon: Texture2D`)에 그림을 넣으면 `ui/SkillCooldownIcon.gd`가 HUD 슬롯에 그 로고를 깔고 쿨타임만큼 아래에서 위로 차오르게 그린다. 비워두면 로고 대신 캐릭터 색 사각형이 같은 방식으로 차오른다 — **로고가 없어도 게임은 정상 동작하므로 그려진 것부터 하나씩 넣으면 된다.**

- 등록 현황: 주정뱅이 3개(`sprite/주정뱅이/스킬로고/1번·2번·궁극기.png`), 촉법소년 2개(`sprite/축법소년/스킬로고/잼민이G스킬.png`=스킬1 자전거 돌진, `잼민이H스킬.png`=스킬2 BB탄). **촉법소년 궁극기와 나머지 4명은 아직 없음**
- 파일 이름의 G/H는 P1 기준 조작키다(G=스킬1, H=스킬2). 어느 슬롯에 넣을 로고인지 이름으로 알 수 있다
- **로고는 투명 여백을 잘라서 넣어야 한다.** `SkillCooldownIcon._fit_bar()`는 텍스처 **원본 크기 전체**를 슬롯(안쪽 약 40px)에 비율 맞춰 집어넣는다 — 여백이 크면 그림이 그만큼 작아지고, 여백이 한쪽으로 치우쳐 있으면 로고가 슬롯 구석으로 몰린다. 차오르는 물높이도 그림이 아니라 여백 기준이 돼서 어긋난다
  - 기존 주정뱅이 로고들은 유효영역이 원본의 79~98%라 그대로 써도 됐지만, 받은 `잼민이H스킬-Photoroom.png`(1339x1439)는 총이 **가로 56% / 세로 44%**만 차지하고 오른쪽 아래로 치우쳐 있었다(그대로 넣으면 40px 슬롯 안에서 총이 21x17px로 구석에 박힌다). 유효영역 `Rect2(382, 445, 748, 627)`만 잘라 `잼민이H스킬.png`로 저장해 그걸 쓴다 — **Photoroom 원본은 지우지 않고 남겨뒀다**(지하철 아저씨 정면 초상화와 같은 처리)
  - `잼민이G스킬.png`는 93% x 75%라 기존 로고들과 비슷해서 자르지 않고 원본을 그대로 쓴다

## 스킬 범위 미리보기 (에디터 전용)

`characters/SkillRangePreview.gd` — 캐릭터 씬을 열었을 때 **토하기 기둥과 괴성 부채꼴이 몸의 어디에서 어떤 크기로 나가는지 몸과 같이 보여주는 `@tool` 노드**. 주정뱅이 씬의 마지막 자식으로 붙어 있다.

- 모양을 새로 그리지 않고 **실제 효과 씬(`VomitBeam.tscn`/`ScreamCone.tscn`)을 그대로 띄운다** — 그래서 에디터에 보이는 것이 곧 게임에서 나오는 모양이다. 이를 위해 두 스크립트에 `@tool`과 `build_preview()`(판정·타이머 없이 도형만 만드는 진입점)를 추가했다
- 붙이는 자식들은 **`owner`를 지정하지 않아서 `.tscn`에 저장되지 않는다.** 게임 실행 중에는 `Engine.is_editor_hint()`가 false라 `_ready()`가 바로 빠져나가며 자기 자신을 숨기고 `_process`도 끈다 — 떠도는 Area2D가 생기지 않는다(헤드리스로 검증: 자식 0개, 히트박스 0개)
- `_process`가 형제 스킬 노드(`Skill2`/`SkillUltimate`)의 `mouth_offset`·사거리 값을 스냅샷으로 들고 있다가 **바뀌면 그 자리에서 다시 만든다.** 그래서 인스펙터에서 숫자를 고치면 화면이 같이 움직인다. 효과 씬 쪽 값(색·두께 등)을 고쳤을 때는 `Refresh` 체크박스를 눌러 다시 읽는다
- `Preview Stacks`로 술 스택별 기둥 길이를 미리 볼 수 있다(마시기 스킬의 `max_stacks`로 자동으로 잘린다)
- **주의:** `VomitBeam`/`ScreamCone`을 `@tool`로 만들었으므로 이 스크립트들은 에디터에서도 `_ready()`가 돈다. 시간·물리에 의존하는 코드(`create_tween`, 레이캐스트)는 전부 `setup()` 안에만 두고 `build_preview()`에서는 부르지 않는다 — 이 경계를 넘으면 에디터에서 에러가 난다

## 훈련장 (값 조정용)

`maps/TrainingGround.tscn` — 평평한 바닥 하나에 캐릭터 하나만 세워두고 **중력·점프력·이동속도를 슬라이더로 실시간으로 바꿔보는 방**. 아직 이 수치들이 확정되지 않아서 만든 개발용 화면이다.

- 배경에 가로 100px / 세로 50px 눈금선을 그려서 이동 거리와 점프 높이를 눈으로 잴 수 있다(500px마다 진한 선)
- 점프할 때마다 **최고 높이 / 체공 시간 / 수평 이동 거리**를 자동으로 재서 패널에 표시한다 (기본값 중력 900·점프력 -450 기준: 약 112px, 1.0초). 모든 캐릭터는 `Fighter.max_jumps`(기본 2)만큼 공중에서 더 점프할 수 있다 — 더블 점프
- 조절 패널은 게임 UI가 아니라 개발 도구라서 `.tscn`에 배치하지 않고 `TrainingGround.gd`에서 코드로 만든다
- **중요:** 이 화면에서 값을 바꾸려고 `Fighter.GRAVITY`/`JUMP_VELOCITY` 상수를 `static var Fighter.gravity`/`Fighter.jump_velocity`로 바꿨다. 모든 Fighter가 공유하는 값이고, 훈련장에서 바꾼 값은 **게임을 끌 때까지 유지**돼서 그대로 로컬 대전에 들어가 시험해볼 수 있다. 값이 마음에 들면 `Fighter.gd`의 `DEFAULT_GRAVITY`/`DEFAULT_JUMP_VELOCITY`에 옮겨 적어야 영구 반영된다
- 이동속도는 캐릭터별 스탯(`stats/*.tres`의 `move_speed`)이라 훈련장에서는 배수(`move_speed_multiplier`)로만 조절한다 — 확정되면 각 `.tres`를 고칠 것

## 궁극기 컷인 연출

`ui/UltimateCutIn.tscn` — 궁을 쓰면 카메라가 시전자에게 빨려들어갔다가 컷인을 보여주고 돌아온 뒤 실제 궁이 나간다. `Stage.gd`와 `maps/TrainingGround.gd`가 `_ready()`에서 자동으로 심고, `Fighter`는 `ultimate_cutin` 그룹으로 찾아 쓴다(연출 노드가 없는 씬이면 궁이 그냥 즉시 발동).

**기획 확정 사항** (임의로 바꾸지 말 것):
- **기본 전체 1.5초** — 줌인 0.25 / 컷인 1.0 / 복귀 0.25. 전부 `@export`라 인스펙터에서 조절 가능
  - **컷인 장면이 `cutin_duration`(초)을 들고 있으면 그 길이가 우선한다**(2026-09-08 추가). 장면마다 필요한 길이가 달라서 넣은 예외로, `UltimateCutIn`이 `_hold`에 그 값을 담아 쓰고 `ramp_time`도 거기에 맞춘다. 잼민이 컷인이 2.4초라 전체 2.9초가 된다 — 나머지 캐릭터는 `cutin_duration`이 없으므로 예전 그대로 1.5초
- **연출 중 시간 정지** (`get_tree().paused`). 컷인 노드만 `process_mode = ALWAYS`라 계속 돈다
- **스킵 없음**
- **확정타 아님** — 궁은 "연출이 시작될 때 시전자가 있던 자리에서, 그때 바라보던 방향"으로 나간다. 상대도 멈춰 있지만 자동 조준이 아니라서 빗나갈 수 있다
- 흐름: `Fighter.use_ultimate()`이 쿨타임을 확인하고 연출을 재생 → 연출이 끝나면 `Fighter.fire_ultimate_now()`가 실제 스킬을 발동(쿨타임도 이때 시작)
- 컷인 장면은 `CharacterStats.ultimate_cutin_scene`(PackedScene)에 지정한다. 비어 있으면 캐릭터 이름만 뜨는 임시 화면
- **컷인은 그림을 여러 장 그리지 않고 파츠(머리/몸/손)를 코드로 흔들어서 만든다** — `ui/cutin/CutInAnimation.gd`. 자식 중 `Head`/`Body`/`HandL`/`HandR` 이름의 Sprite2D를 찾아 떨림을 점점 키우고(`shake_max`/`shake_speed`), 화면을 서서히 당기고(`zoom_in`), 얼굴을 붉게 물들인다(`red_tint`). 주정뱅이 컷인은 `ui/cutin/JujeongbaengiCutIn.tscn`
- 악플러 컷인은 `ui/cutin/AkpeulleoCutIn.tscn` + 전용 스크립트 `AkpeulleoCutIn.gd`(주정뱅이가 쓰는 공용 `CutInAnimation.gd`와 별개). 화면을 좌우로 나눠서:
  - **왼쪽**: 악플러 정면 얼굴(`악플러정면머리.png`)과 그 아래 몸(`악플러몸통.png`). 낄낄대듯 고개를 좌우로 기울이며 위로 들썩이고(`head_bob`), 어깨는 그 `body_bob_ratio`(0.35)만큼만 따라 움직인다. 끝으로 갈수록 얼굴이 다가온다(`head_zoom`)
  - **인물 양옆 손**(`TypeHandL`/`TypeHandR`): 반 박자 엇갈려 번갈아 내려찍어 타자 치는 것처럼 보이게 하고, 가장 깊이 눌린 순간(`press > 0.6`)에만 `TapMarkL`/`TapMarkR` 효과선이 번쩍인다. 계속 켜두면 효과선처럼 안 보이고 그냥 붙어있는 그림이 된다
  - **모니터 빛**(`MonitorLight`): 모니터를 그리지 않고 **빛만으로** 화면 밖 아래에 모니터가 있다는 걸 표현한다. `CanvasItemMaterial.blend_mode = 1`(더하기)라야 "비춘다"는 느낌이 난다
  - **키보드**(`Keyboard`): 손 아래에 깔려 화면 아래로 잘려나간다. 어두운 방이라 `modulate`를 0.15까지 낮춰야 더하기 블렌드로 얹히는 모니터 빛을 받아 "어둠 속에서 빛만 반사되는 키보드"로 보인다 — 밝게 두면 회색 판으로 뜬다. `MonitorLight`보다 **앞**(먼저 그려지는 자리)에 둬야 빛을 받는다
  - **오른쪽**: 댓글 5줄이 옆에서 밀려들어오며 하나씩 실시간으로 쌓인다. 문구는 `Comments/Comment0~4`의 `Text` 노드에서 고친다
- **한때 왼쪽 아래에 "어두운 방에서 타자 치는 악플러" 장면(책상·모니터·의자 + 위아래로 움직이는 손)을 넣었다가 뺐다.** 얼굴 하나로 크게 가는 게 낫다는 피드백 — 되살릴 일 있으면 git 이력에 있다
- **모니터 빛은 화면 밖 아래를 꼭짓점으로 하는 부채꼴 5겹이다.** 꼭짓점 `(-285, 560)`은 보이는 영역(y<=324) 아래라, 화면 밖에 모니터가 있고 거기서 빛이 위로 퍼져 얼굴을 비추는 것으로 읽힌다. Polygon2D에는 그라디언트가 없으므로 **반지름과 벌어진 각을 같이 줄이면서 5겹을 겹쳐** 꼭짓점·가운데가 밝고 위·바깥으로 갈수록 사라지는 falloff를 흉내낸다
- **주의(실제로 겪음): 더하기 블렌드로 빛을 만들 때 하드한 도형은 빛이 아니라 "판때기"로 보인다.** 두 번 갈아엎었다 — (1) 넓은 노란 **사각형** + 굵은 막대 3개: 배경에 밝은 직사각형과 올리브색 막대가 그대로 보임, (2) **타원** 반사광 + 3겹 빛줄기: 줄기가 여전히 선으로 보여서 전부 제거. 결론은 **한 겹으로 진하게 칠하지 말고, 크기를 줄여가며 여러 겹을 옅게 겹칠 것**
- `ui/cutin/blur.gdshader`: 텍스처를 주변 9군데에서 뽑아 3x3 가중평균하는 흐림 셰이더. 어떤 스프라이트에도 재사용 가능. `blur_amount`는 **원본 텍스처 픽셀** 기준이라 크게 확대해 쓰는 그림일수록 값을 키워야 보이고, **0이면 원본 그대로 통과**한다. 방 장면이 있을 땐 얼굴이 배경이라 22를 줬지만, 지금은 얼굴이 주인공이라 0(또렷)으로 두었다
- 컷인 진행 속도는 `ramp_time`에 맞춘다 — `UltimateCutIn._spawn_cutin()`이 자기 `hold_time`(1.0초)을 넣어주므로, 댓글 5줄이 그 안에 다 뜨도록 `comment_start`/`comment_end` 비율로 나눠 배치한다

- 촉법소년 컷인은 `ui/cutin/ChokbeopsonyeonCutIn.tscn` + `ChokbeopsonyeonCutIn.gd`, **전체 2.4초**(`cutin_duration`). **파츠를 흔드는 다른 컷인과 달리 러프 그림 3장을 순서대로 넘기는 플립북**이고, 배경 3장이 완전히 같은 그림이라 넘어가도 이어져 보인다. 그 위에 움직이는 것만 따로 얹는 구조다. 원본은 사용자가 그린 `.paint`(윈도우 그림판 HEIF) 3장이고, PNG로 변환해 `sprite/축법소년/궁극기컷인/1·2·3번프레임.png`(1619x915)로 넣었다
  - **1번(0~26%, 0.62초)**: BB탄 3발. 총알 스프라이트(`Pellets/Pellet0~2`, `총알.png`)가 총구에서 실제로 날아가고 한 발마다 화면이 반동으로 밀린다. 총구 위치 `muzzle`(517, 151)은 **그림의 총구 픽셀 (1440, 642)을 배율 0.82로 옮긴 값**이다 — 그림을 갈아끼우면 이 값도 다시 재야 한다 **처음엔 1.26초였는데 총을 너무 오래 쏘는 느낌이라 반으로 줄였다(2026-09-08).** 2·3번 장면 길이는 그대로 둬서 전체가 3.0초 -> 2.4초가 됐다. 세 발은 `shot_spread`(0.8) 비율 안에서 쏜다 — 이 값을 1에 가깝게 키우면 마지막 총알이 화면 밖으로 나가기 전에 장면이 넘어가서 공중에서 사라져 보인다
  - **2번(26~64%, 0.91초)**: 엄마 대사가 먼저 툭 떠오르고, `exclaim_at`(31% = 대사 뜨고 0.12초 뒤)에 **느낌표가 곧바로 이어서 튀어나온다**. **대사는 그림이 아니라 `ShoutText`(Label)다**(2026-09-08 교체) — 원래 2번 그림에 손글씨로 그려져 있던 걸 지우고 Label로 바꿔서 문구를 인스펙터에서 바로 고칠 수 있게 했다. 지울 때는 하늘 영역에서 "테두리에 안 닿는 작은 덩어리"만 골라 지워서 나무·울타리·구름은 건드리지 않았다. 느낌표만 그림째 떼어내 `느낌표.png`(40x93)로 남겼고, 대사와 겹치지 않게 위치를 (250, -52)로 내렸다. 느낌표가 뜨는 순간 화면이 한 번 당겨졌다 돌아온다(`notice_punch`)
  - **폰트: `fonts/Jua-Regular.ttf`(배달의민족 주아체)** — 2026-09-08에 프로젝트 첫 폰트로 추가했다. Google Fonts에 "Jua"로 올라와 있는 우아한형제들 배포본이고 **SIL OFL 1.1**이라 상업 이용 가능하다(`fonts/OFL.txt` 동봉 — OFL은 라이선스 원문을 같이 배포하도록 요구한다). 지금은 이 대사(`ShoutText`)에만 `theme_override_fonts/font`로 걸려 있고, **나머지 화면은 여전히 Godot 기본 폰트**다. 전체에 적용하려면 `project.godot`의 `gui/theme/custom_font`에 이 폰트를 지정하면 된다
  - **`Frame2`·`ShoutText`·`ShoutMark`·`Exclaim`은 씬에서 `visible`을 켜둔 채로 저장한다** — 에디터를 열면 2번 장면 위에 대사와 느낌표가 같이 보여서 위치·크기를 눈으로 잡을 수 있다. 게임에서는 `_reset()`이 1번 프레임만 남기고 전부 숨기므로 영향이 없다(메인 메뉴 등장 프레임과 같은 방식). **일부러 `visible = false`로 저장하지 말 것.** 대사가 떠오를 때 쓰는 피벗은 `_ready()`에서 상자 크기의 절반으로 다시 잡으므로, 상자를 키워도 가운데를 축으로 커진다
  - **`ShoutMark`(빨간 말줄 두 획)** — 원래 2번 그림에 대사와 같이 그려져 있던 빨간 사선 두 개다. 손글씨를 지울 때 같이 지웠다가, "소리가 저쪽(집)에서 온다"는 표시가 필요해서 원본 `.paint`에서 다시 떼어내 `말줄.png`(65x112)로 넣었다. 검은 손글씨가 딸려오지 않도록 **"얼마나 빨간가"로 알파를 잡아** 뽑았다(빨강이 아닌 픽셀은 자동으로 투명). 대사와 같은 박자로 같이 떠오른다
  - **3번(64~100%, 0.86초)**: 여기만 통짜 그림이 아니라 **`3번배경.png`(캐릭터 없는 배경) + `Runner`(인게임 리그 `ChokbeopsonyeonRig.tscn` 인스턴스)** 로 나뉜다. 리그를 그대로 넣었으므로 **팔·다리가 `BodyRig`의 걷기 코드로 실제로 움직인다** — 컷인 전용 파츠를 따로 만들 필요가 없다. 잼민이가 왼쪽으로 `run_distance`(1100px) 달려 화면 밖으로 사라지고, 지나간 자리마다 먼지(`Dust/Dust0~2`)가 남아 퍼진다. 화면도 살짝 따라가며(`run_drift`) 당겨진다(`run_zoom`)
  - **리그를 Fighter 없이 걷게 하려고 `BodyRig.manual_speed_ratio`를 새로 넣었다**(기본 -1 = 안 씀). `BodyRig`는 원래 부모 Fighter의 속도를 보고 걸음을 돌리는데, 컷인에는 Fighter가 없어서 가만히 서 있었다. 0~1 값을 넣으면 그 속도로 걷는 것으로 치고, **Fighter가 있으면 이 값은 무시되므로 인게임 동작은 그대로다.** 컷인 씬에서는 1.0으로 켜뒀다
  - **리그 배치값 근거**: 파츠 실측(몸 28.5x25.6 / 발 19.2x8.9 / 손 14.8x14.0, 머리는 55x55 기준)으로 리그의 보이는 세로 범위가 y -60.1 ~ +31.7(=91.8px)이다. 3번프레임에서 잼민이가 차지하던 크기(503px x 0.82 = 412px)에 맞추려고 **배율 4.5**, 발바닥이 원래 서 있던 땅(로컬 y 374)에 오도록 **위치 (255, 231)**. `scale.x`를 음수로 줘서 왼쪽을 보게 한다 — `BodyRig._face_moving_direction()`은 Fighter가 없으면 그냥 넘어가므로 이 부호가 유지된다
  - **`scale.x`가 음수라 회전이 화면에서 좌우 반대로 보인다.** 달릴 때 앞으로 숙이는 `run_lean_deg`가 **양수**인 이유다. 기울기가 반대로 보이면 부호만 뒤집으면 된다
  - 달릴 때는 `set_action_face(true)`로 머리를 `달리는 축법소년 표정.png`으로 바꾼다(리그에 이미 `action_head_texture`로 연결돼 있음)
  - **`3번배경.png`은 3번프레임에서 캐릭터를 지운 게 아니라, `sprite/축법소년/궁극기배경.png`(사용자가 그린 캐릭터 없는 놀이터)에 1번프레임의 하늘을 깐 것이다.** 캐릭터를 지우고 그 자리를 자동으로 메우는 건 **세 번 시도해서 다 실패했다** — 뒤가 철망·벽돌·수풀 무늬라 가로 보간은 뿌옇게 번지고, 같은 줄에서 무늬를 찾아 붙이는 방식은 엉뚱한 데를 긁어왔다. 배경판은 가로를 프레임 폭에 맞춰 1.054배 키우고 y를 123px 올려 얹었다(`scale = 1619/1536`). 레이아웃이 프레임과 미세하게 다르지만(사물 크기가 약 81%) 같은 놀이터로 읽힌다
  - **3번프레임.png은 이제 씬이 안 쓴다** — 원본 러프로만 남겨뒀다. 프레임과 레이아웃이 딱 맞는 배경판을 새로 그리면 `3번배경.png`만 갈아끼우면 된다
  - **교훈: 컷인에 캐릭터를 움직여 넣어야 하면 러프 그림을 오려내지 말고 `characters/<캐릭터>/<캐릭터>Rig.tscn`을 먼저 볼 것.** 머리·몸·손·발이 이미 파츠로 나뉘어 있고 걷기 코드까지 붙어 있다. 실제로 이번에 러프에서 캐릭터를 오려 붙였다가(`달리는잼민이.png`) 팔다리를 못 움직여서 리그로 갈아엎었다
  - **스프라이트 배율 0.82는 흔들 여유를 남기려고 일부러 화면보다 크게 잡은 값이다.** 1619x915 x 0.82 = 1327x750으로 화면(1280x720)보다 가로 47px·세로 30px 크다 — 반동(최대 ~10px)·드리프트(26px)·확대(6%)로 밀려도 가장자리에 검은 여백이 안 드러난다. 배율을 0.79 밑으로 내리면 흔들 때 여백이 보인다
  - **받은 3장은 하늘 상태가 서로 달랐다(1·3번은 안 칠한 흰 여백, 2번만 하늘색+해+구름).** 그대로 넘기면 흰색↔하늘색이 깜빡여서, 프레임1의 흰 여백을 위쪽 테두리에서 flood fill로 잡아 **프레임2의 하늘을 그 자리에 깔아 세 장을 통일**했다. 이때 프레임2 하늘에만 있는 "밥먹어라~" 글씨·빨간 말줄·느낌표(x 880~1305 / y 160~420)는 민 하늘색으로 지운 뒤 깔아서, 2번 장면에서만 뜨도록 했다. 원본 `.paint` 3장은 `C:\게임러프스케치\`에 그대로 있다
  - 나중에 그림을 다시 그려서 교체할 땐 **세 장 다 하늘까지 칠해서 주면** 위 합성 없이 그냥 넣으면 된다
- **괴성은 컷인에서 지르지 않는다.** 컷인은 참는 구간(예비동작)이고, 실제로 지르는 건 화면 복귀 후 인게임 궁극기 — 그래야 판정이 나가는 순간이 살아난다

## 게임 플로우 / 씬 전환

`GameState.gd`(프로젝트 루트, 오토로드 싱글턴)가 화면 사이에서 선택값을 들고 다닙니다.

**첫 화면 구성(2026-09-01 개편):** 게임을 켜면 `ui/TitleScreen.tscn`(게임 제목 + "아무 키나 누르세요")이 뜨고, 아무 키나 누르면 `ui/MainMenu.tscn`으로 넘어간다. 메인 메뉴는 **왼쪽에 버튼 4개(스토리 모드 / 대전 모드 / 조작 방법 / 설정), 오른쪽에 캐릭터 일러스트**가 숨쉬듯 흔들리는 구성이다.

- **스토리/대전 모드는 바로 들어가지 않고 확인 창을 한 번 거친다** (`ui/ConfirmPopup.tscn` + `ConfirmPopup.gd`). 이 창은 "무엇을 할지"를 모르고 `confirmed`/`cancelled` 시그널만 내보낸다 — 실제 동작은 부르는 쪽이 `_ask(문구, 실행할_함수)`로 넘긴 `Callable`에 담겨 있다가 확인을 눌렀을 때 실행된다. 그래서 다른 화면에서도 그대로 재사용할 수 있다
- 확인 창의 두 가지 자잘한 처리: ① 열 때 직전 포커스를 기억해뒀다가 **취소하면 원래 버튼으로 포커스를 되돌린다**(안 그러면 방향키 조작이 끊긴다), ② ESC를 먹은 뒤 `set_input_as_handled()`를 부른다(**안 부르면 뒤쪽 메인 메뉴의 ESC까지 같이 발동해서 타이틀로 튕긴다**)
- **주의:** `.tscn`은 노드가 전부 나온 뒤에 `[connection]`이 와야 한다. 파일 끝에 노드를 그냥 덧붙이면 connection 뒤에 놓여서 깨진다
- 메인 메뉴 배경은 `sprite/메인메뉴/배경프로토.png`(1672x941, 정확히 16:9라 잘리지 않는다)를 `TextureRect`(`stretch_mode = 6` KEEP_ASPECT_COVERED)로 깐다. 그 위에 **어둡게 덮는 두 겹**이 있다: 화면 전체를 살짝 누르는 `Scrim`(검정 45%)과, 왼쪽만 진하게 눌러주는 `LeftFade`(가로 그라디언트, 왼쪽 94% -> 오른쪽 0%). **배경 그림이 밝고 간판 글씨가 많아서 이게 없으면 버튼 글씨가 완전히 묻힌다** — 한 겹(50%)만으로는 부족해서 왼쪽을 따로 더 눌렀다
- 배경 세 겹은 전부 `mouse_filter = 2`(IGNORE)다. Control 계열 기본값이 STOP이라 그냥 두면 화면을 덮은 배경이 클릭을 삼킨다(타이틀 화면에서 실제로 겪음 — 아래 항목 참고)
- **메인 메뉴 일러스트는 파츠 분리 애니메이션이다** (`ui/MenuIllust.tscn` + `MenuIllust.gd`). 포토샵에서 나눈 6장(몸통/아래쪽옷/머리/머리띠 3조각)을 각각 따로 움직인다 — 몸통은 두 발 사이를 축으로 세로로만 늘었다 줄고(숨쉬기), 머리는 목을 축으로 갸웃, 머리띠 3조각은 **시간차를 두고** 흔들려 물결처럼 이어진다
- **등장 연출(3프레임)은 뺐다(2026-09-08).** 한때 골목에서 걸어나오듯 `EntranceFrame1`(팔 내린 주정꾼) -> `EntranceFrame2`(소주 든 주정꾼) -> `Illust` 순으로 그림 3장을 0.3초씩 바꿔 보여줬는데, 연출이 하찮다는 피드백을 받아 **메뉴가 뜨는 순간부터 바로 파츠 숨쉬기만 돌게** 되돌렸다. `MainMenu`의 `entrance_frame_time`·`_show_entrance_step()`·`_process()`, `MenuIllust.restart_breathing()`, 씬의 `EntranceFrame1/2` 노드를 전부 지웠다. 되살릴 일 있으면 `3a92276` 커밋에 있다
  - 쓰던 그림 두 장(`sprite/메인메뉴/일러스트/팔내리고있는주정꾼.png`·`앞에소주든주정꾼.png`)은 지우지 않고 남겨뒀다 — 지금은 아무 씬도 참조하지 않는다
  - **주의(실제로 겪음): 씬을 막 불러온 첫 프레임은 delta가 크게 튄다.** 연출을 시간 누적으로 진행하면 로딩 렉에 앞부분이 통째로 밀린다 — 다시 이런 연출을 넣는다면 `minf(delta, 0.05)`처럼 상한을 둘 것
- **파츠는 반드시 원본 캔버스 크기 그대로 내보낸다.** 포토샵 `File > Export > Layers to Files`에서 File Type을 **PNG-24**로 바꿔야 `Transparency` / `Trim Layers` 옵션이 나타나고, **`Trim Layers`를 꺼야** 모든 장이 같은 크기(1230x1278)로 나온다. 그러면 각 `Sprite2D`를 `centered = false` + `position = -축좌표`로 두는 것만으로 원본과 픽셀 단위로 맞고, 그 Sprite2D를 감싼 Node2D(=축)를 돌리면 원하는 지점을 중심으로 회전한다. 트리밍하면 파츠마다 위치를 손으로 맞춰야 한다
- 파일 이름의 번호는 **위 레이어일수록 작다**(`_0000_`이 맨 앞 레이어). 그래서 씬에는 **번호 역순**으로 쌓아야 원본 순서가 된다
- **뒤에 깔 몸통은 "원본에서 파츠 자리를 지운 그림"이어야 한다.** 원본을 그대로 깔면 위의 머리를 움직일 때 밑에 원래 머리가 비쳐 두 개로 보인다. 그런데 **그냥 지우기만 하면 파츠가 비켜났을 때 검은 구멍이 드러난다**(실제로 겪음 — 띠가 흔들리자 어깨에 검은 홈이 생겼다).
  해결은 두 단계다: ① 바깥 배경에서 출발해 몸이 아닌 곳만 통과하는 flood fill로 **"띠 뒤가 원래 배경이던 자리"를 구분해 비우고**, ② 몸에 둘러싸인 나머지 자리만 테두리 색을 BFS로 번지게 해 **메운다**. ①을 빼먹고 전부 메우면 배경 위에 떠 있던 띠 자리까지 칠해져서 빨간 얼룩이 남는다. 이 처리는 코드로 했고 결과물이 `주정꾼잘생긴버전_0005_몸통.png`다
- `ui/breath.gdshader`: 한 장짜리 그림에서 특정 타원 범위만 부풀리는 셰이더. 파츠를 나누기 전에 쓰던 방식이라 지금 메인 메뉴는 안 쓰지만, **파츠 분리가 안 된 다른 캐릭터 일러스트에는 그대로 쓸 수 있다**
- **일러스트는 Control이 아니라 `Sprite2D`다.** Control은 앵커 레이아웃이 매 프레임 `position`을 되돌려놔서 코드로 흔들면 서로 싸운다. Node2D 계열은 레이아웃을 안 받으므로 좌표를 그대로 쓸 수 있다
- 일러스트를 안 넣어두면 `GameState.PORTRAITS[fallback_character]`(기본 주정뱅이)로 자동으로 채워지고, **어떤 크기의 그림이든 `illust_height`(560px)에 맞춰 배율이 자동 계산**된다 — 나중에 제대로 된 일러스트가 오면 `MainMenu` 인스펙터의 `Illustration`에 넣기만 하면 된다
- **주의(실제로 겪은 버그): 화면을 덮는 배경이 마우스 클릭을 삼킨다.** `Control` 계열은 `mouse_filter` 기본값이 `STOP`이라, 전체 화면을 덮은 `ColorRect`/`TextureRect` 배경이 클릭을 먼저 먹고 `_unhandled_input`까지 이벤트가 안 온다. 타이틀 화면에서 "아무 키나 누르세요"가 키보드만 먹고 마우스는 안 먹던 원인이 이거였다. 배경·컨테이너에 `mouse_filter = 2`(IGNORE)를 주면 통과한다. **단, 버튼이 있는 화면에서 버튼 자신에게 이걸 주면 클릭을 못 받는다** — 배경 레이어에만 줄 것
- `ui/HowToPlay.tscn`(조작 방법)은 키를 고정 문자열로 적어두지 않고 **`InputMap`에서 읽어온다** — 설정에서 키를 재배정하면 표시도 같이 바뀐다. 읽기 전용이고, 바꾸는 건 설정 > 조작 탭
- **`ui/ModeSelect.tscn`은 이 개편으로 안 쓰이게 됐다.** 모드 분기 로직은 `MainMenu.gd`로, 훈련장 입구는 `HowToPlay.gd`로 옮겼다. 파일은 남겨뒀으니 필요 없으면 지워도 된다

**로컬 대전(PvP) 흐름:** `ui/TitleScreen.tscn`(아무 키) → `ui/MainMenu.tscn`("대전 모드" 선택) → `ui/RoomSettings.tscn`(선취 라운드 수 1~40, 시간제한 무제한/1~5분 설정 → `GameState.rounds_to_win`/`time_limit_seconds`) → `ui/CharacterSelect.tscn`(P1→P2 순서로 캐릭터 선택, `GameState.p1_character_path`/`p2_character_path`에 저장) → `ui/MapSelect.tscn`(맵 선택 시 바로 그 맵 씬으로 전환) → 선택한 맵(`Stage.gd` 상속).

**스토리 모드 흐름:** `ui/TitleScreen.tscn` → `ui/MainMenu.tscn`("스토리 모드" 선택 — `rounds_to_win=2`, `time_limit_seconds=120` 고정, `story_index=0`으로 초기화) → `ui/StoryIntro.tscn`(P1 캐릭터만 고름 — P2는 `GameState.STORY_OPPONENTS[story_index]`로 자동 지정, 맵도 `GameState.STORY_MAPS[story_index]`로 에피소드별로 정해짐) → 맵(`Stage.gd`) → (P1 승리 시) `ui/ReformCutscene.tscn`(방금 이긴 빌런 전용 반성 대사 표시, "개과천선" — 캐릭터별 대사는 `ReformCutscene.REFORM_LINES` 딕셔너리) → 다음 상대로 자동 진행, 전원 격파 시 `ui/StoryClear.tscn`. P1이 지면 스토리 진행 없이 일반 결과 화면(다시하기/메인 메뉴로)만 뜬다

**훈련장 흐름:** `ui/TitleScreen.tscn` → `ui/MainMenu.tscn`("조작 방법") → `ui/HowToPlay.tscn`("훈련장에서 해보기") → `maps/TrainingGround.tscn`. 캐릭터 선택·맵 선택 화면을 거치지 않고 바로 들어가고, 캐릭터는 훈련장 안의 드롭다운으로 바꾼다(바꾸면 그 자리에서 다시 스폰). 상대·라운드·시간제한·HUD가 없어서 `Stage.gd`를 상속하지 않는 독립 씬이다

- 캐릭터·맵 후보 목록은 `GameState.CHARACTERS`/`GameState.MAPS` 딕셔너리 하나로 관리 — 캐릭터나 맵을 추가하면 이 딕셔너리에 한 줄만 추가하면 선택 화면에 자동으로 나타남
- 모든 화면에 ESC(`ui_cancel`)로 한 단계 뒤로 나가는 탈출구가 있음: 모드 선택→메인 메뉴, 방 설정→모드 선택, 캐릭터 선택→방 설정, 맵 선택→캐릭터 선택, 스토리 인트로→모드 선택, 대전 중→메인 메뉴. 버튼으로도 동일하게 나갈 수 있음
- **라운드제:** `Stage._process()`가 KO(HP 0) 또는 시간 초과(`GameState.time_limit_seconds`>0이고 다 됐을 때 — 그 순간 HP 높은 쪽이 라운드 승, 동률이면 무승부)를 감지하면 `_end_round(p1_won, is_draw)`를 부른다. 라운드 승수는 `GameState.p1_round_wins`/`p2_round_wins`에 누적되고, 둘 중 하나가 `rounds_to_win`에 도달하지 못했으면 `MatchResult.show_round_result()`로 점수 배너만 잠깐 보여준 뒤 `get_tree().reload_current_scene()`으로 같은 맵에서 다음 라운드를 새로 시작한다(HP/위치는 씬 리로드로 초기화되고, 라운드 승수는 `GameState`가 오토로드라 그대로 유지됨). 도달했으면 최종 결과(`MatchResult.show_result()`/`show_draw()`) 또는 스토리 모드 승리 시 `ReformCutscene`으로 분기
- `CombatHUD`는 화면 중앙 상단에 **남은 시간 박스**(`TimerFrame` > `TimerBox` > `TimerLabel`)와 그 아래 라운드 점수(`RoundLabel`, `P1승 : P2승`)를 표시. `Stage`가 `combat_hud.update_round_info(p1_wins, p2_wins, time_left)`로 매 프레임 갱신한다. 시간 값은 방 설정에서 고른 `GameState.time_limit_seconds`를 `Stage`가 깎아 내려주는 것이라 HUD는 표시만 한다 — **시간 제한 없음(0)이면 `TimerFrame` 자체가 숨겨지고**, 10초 이하로 남으면 숫자가 빨개진다
- `maps/Stage.gd`는 이제 캐릭터를 씬에 미리 박아두지 않고, `_ready()`에서 `GameState`가 가리키는 캐릭터 씬을 `PlayerSpawn1`/`PlayerSpawn2`에 동적으로 생성한다. P1에는 항상 `PlayerController`를 붙이고, P2는 `GameState.game_mode`를 봐서 스토리 모드면 `ClaudeAIController`(정해진 상대를 AI가 조작), 로컬 대전(pvp)이면 `PlayerController`(사람이 직접 조작)를 붙인다. 새 맵은 바닥·벽(or 링아웃용 빈 공간)·`PlayerSpawn1`/`PlayerSpawn2`·`Camera2D`(스크립트: `maps/CameraRig.gd`)·`CombatHUD` 인스턴스만 배치하면 나머지는 `Stage.gd`가 처리
- 승패: `Stage._process()`가 매 프레임 양쪽 Fighter의 `current_hp`를 직접 확인해서 판정한다(HP 0 또는 `ring_out()`). **`died` 시그널에 바로 반응하지 않는 이유:** 시그널에 반응하면 같은 프레임에 양쪽이 동시에 쓰러져도 먼저 처리된 시그널 쪽이 임의로 승자가 되는 버그가 있었음 — 지금은 그 프레임의 데미지가 전부 반영된 뒤 한 번에 판정해서 양쪽 다 0이면 무승부(`MatchResult.show_draw()`)로 처리. 링아웃은 `Stage.ring_out_y`보다 아래로 떨어지면 발동 — 벽이 있는 맵(편의점 앞/PC방/아파트 단지 놀이터)은 사실상 발동 안 되고, 벽이 없는 학교 옥상·지하철 승강장에서만 의미가 있음
- 히트 이펙트: 맞으면 `Fighter._flash_hit()`가 캐릭터를 잠깐 빨갛게 물들이고, `combat/Hitbox.gd`가 실제로 맞았을 때 `combat/HitSpark.tscn`을 스폰
- 상태별 색조는 `Fighter.set_tint(id, color, duration)`/`clear_tint(id)`로 건다. 여러 개가 동시에 걸려도(도발+열등감 오라 등) 서로 안 지우고 스택처럼 쌓였다가, 하나가 풀리면 그 밑에 깔려있던 색으로 돌아간다(전부 없으면 원래 색) — `set_modifier`/`clear_modifier`와 같은 발상. 스킬 9종 전부 이 방식으로 캐릭터별 이펙트가 붙어있음: 촉법소년 돌진 잔상(`DashSkill`)·BB탄 총구 섬광(`BBGunSkill`)·궁극기 초록 반짝임(`HealSkill`), 악플러 도발 대상 노란빛(`TauntSkill`)·열등감 붉은 오라(`RageBuffSkill`)·궁극기 어두운 디버프(`WeakenAuraUltimate`), 주정뱅이 스택 비례 빨개짐(`DrinkSkill`)·초록 토사물(`VomitSkill`)·궁극기 빨간 부채꼴+보라 디버프(`ScreamConeUltimate`)
- 넉백: `MeleeAttack`/`Projectile`이 각자 `Hitbox.knockback`을 설정해서 맞은 캐릭터의 `velocity`에 즉시 더한다(`Fighter.take_damage`). 바운스어택류 콤보의 기반 — 아직 스킬 하나하나에 맞는 세밀한 값 조정은 안 되어 있음(전부 임시값)
- 대전 시작 시 `ui/RoundStart.tscn`이 "3, 2, 1, FIGHT!" 카운트다운을 보여주는 동안 양쪽 컨트롤러가 멈춘다(`PlayerController`/`AIController`의 `is_active`). **주의:** 그냥 멈추기만 하면(`set_physics_process(false)`) 멈추기 직전 프레임의 관성(velocity.x)이 남아서 계속 미끄러지는 버그가 났었음 — `is_active=false`일 때도 물리 처리(`apply_physics`)는 계속하되 `fighter.move(0.0)`으로 수평 속도를 매 프레임 0으로 고정해야 함

## 맵 기믹

- `maps/PassingTrain.gd` (`maps/SubwayTrack.tscn`): 제자리에서 켜졌다 꺼지는 **판정만 있는** 열차. 경고 → 판정 ON → OFF 순서로 깜빡이며, 열차가 실제로 움직이지는 않는다. `maps/SubwayTrack.tscn`은 아직 폴리곤 열차를 쓴다 — 필요하면 `Metro!.png`로 갈아끼울 수 있다
- `maps/SubwayTrain.gd` + `maps/SubwayTrain.tscn` (`maps/SubwayPlatform.tscn`의 `DecoSubwayTrain` 노드): 선로를 실제로 미끄러져 가로지르는 열차. 시간·세기 조절은 전부 인스펙터에서 한다 — `interval`(도착에서 다음 도착까지 **30초**) / `first_delay`(첫 열차까지 12초) / `warning_duration`(도착 몇 초 전부터 음악·경고등, **5초**) / `speed`(950px/s) / `damage`(12) / `hit_interval`(0.35초) / `knockback_push`(420) / `knockback_lift`(260) / `travel_x`(±1200) / `alternate_direction` / `arrival_music`
  - **`interval`은 "도착에서 다음 도착까지"다.** 열차가 출발하는 순간 `_timer = interval`로 다시 채우기 때문에 지나가는 시간까지 그 안에 포함된다 — 30으로 두면 정확히 30초마다 한 대씩 온다(헤드리스 실측: 0.6s / 30.6s / 60.6s). 예전처럼 "열차가 나간 뒤부터 세는" 방식이 아니다
  - **`arrival_music`은 아직 비어 있다.** 옛날 지하철 도착 음악 파일을 넣으면 도착 5초 전부터 재생되고 열차가 지나가면 멈춘다. 비어 있으면 `music.play()`를 건너뛰고 경고등만 깜빡인다
  - **부딪히면 계속 밀린다.** `Hitbox.repeat_interval`(아래 참고)로 겹쳐 있는 동안 0.35초마다 다시 때리고, 넉백은 `Vector2(knockback_push * 진행방향, -knockback_lift)`라 **열차가 가는 쪽으로 밀리면서 위로 튕긴다**. 판정이 열차 전체(지붕까지)를 덮고 있어서 지붕에 올라타도 그냥 튕겨 나간다(기획 확정 4·5)
  - 열차 그림은 운전실이 **왼쪽**에 있어서 `_apply_direction()`이 `body.scale.x = -_direction`으로 **부호를 뒤집어서** 진행 방향을 보게 한다(`+_direction`이면 뒤로 달리는 것처럼 보인다). 판정 사각형은 좌우 대칭이라 음수 스케일의 영향을 받지 않는다
  - **AI(`AIController.gd`)가 이 기믹을 피한다(2026-09-04 구현):** `SubwayTrain.is_dangerous()`가 경고등 켜짐(WARNING) 또는 실제로 지나가는 중(RUNNING)이면 true를 돌려준다. `_ready()`에서 `add_to_group("ai_danger_zone")`으로 자신을 등록해두면 `AIController._try_dodge_hazard()`가 매 프레임 이 그룹을 훑어서 위험을 감지하고, `"ai_safe_spot"` 그룹의 `maps/AISafeSpot.gd`(빈 Marker2D에 붙이기만 하면 됨) 중 가장 가까운 곳으로 걸어가 이단 점프로 올라탄 뒤 위험이 끝날 때까지 버틴다. `SubwayPlatform.tscn`의 의자 발판(`BenchLeft`/`BenchRight`) 바로 위에 `AISafeSpotLeft`/`AISafeSpotRight`(y=155, 발판 윗면 높이)를 놓아뒀다. **캐릭터 이름이나 맵 이름으로 분기하지 않고 두 그룹만으로 판단하는 범용 시스템**이라, 다른 맵에 새 기믹을 추가할 때도 위험 판정 노드에 `is_dangerous()`만 만들어 그룹에 등록하고 대피 지점에 `AISafeSpot.gd`만 놓으면 자동으로 적용된다(피할 곳이 없는 기믹이면 `ai_safe_spot`을 안 놓으면 그만 — `_try_dodge_hazard()`가 그냥 false를 돌려주고 평소처럼 싸운다). 헤드리스로 전체 열차 주기(경고 5초 → 통과)를 실측해서 AI가 경고 시작 직후 발판으로 올라가 끝날 때까지 안 맞고 버티는 것을 확인했다
- **`combat/Hitbox.gd`의 `repeat_interval`(기본 0):** 0보다 크면 겹쳐 있는 동안 그 간격마다 계속 다시 때린다(`_process`가 `get_overlapping_areas()`를 훑으며 대상별 쿨타임을 관리 — `HazardPlatform.gd`와 같은 방식). 0이면 예전처럼 처음 겹친 순간 한 번만. **스킬 히트박스는 전부 0을 쓰므로 기존 동작은 그대로다.** 판정을 껐다 켤 때는 `clear_repeat_state()`로 쿨타임을 비운다

### `maps/Playground.tscn` (놀이터) — 미끄럼틀 / 스프링 시소 / 낙하 화분

2026-09-07 기획 그림대로 새로 그렸다. 시소 2종과 화분은 스프라이트를 붙였고,
미끄럼틀·지붕·바닥은 아직 `Polygon2D` 도형이다.
예전 `Playground.tscn`(가운데 낙뎀 구역 하나만 있던 버전)을 통째로 대체했으므로,
`maps/HazardPlatform.gd`는 이제 아무 씬도 안 쓰는 고아 스크립트다.

| 요소 | 좌표 |
|---|---|
| 바닥 윗면 | y = 280 (`Ground`는 y=300에 1440x40), 좌우 벽 x=±720 → 이동 범위 ±680 |
| 미끄럼틀 위 발판 | 윗면 y = 160 (`SlideDeck`, x -700~-510, **원웨이**) |
| 미끄럼틀 경사면 | (-510,160) → (-403,280), 수평 기준 **48.3°** |
| 미끄럼틀 지붕 | 삼각형 (-605,55)-(-713,163)-(-497,163) |
| 스프링 시소 좌석 윗면 | y = 226 (x = 400 / 560, `SpringRide.tscn` 인스턴스 2개, **원웨이**) |
| 모래사장 | 지면 위 x ±260 (`SandVisual` 그림 y 280~296 / `SandPit` 판정 y 256~296) |
| 화분 생성 | `PotSpawner`가 y=-360에서 x ±680 범위로 무작위 낙하 |
| 카메라 | `min_y` -80 / `max_y` 20 |

- **카메라를 기본값(`max_y` 250)으로 두면 화면 아래 흙이 330px(46%)나 보인다.** 이 맵은 바닥 밑에
  아무것도 없고 화분이 위에서 떨어지며 트램폴린으로 높이 튀어오르므로, 위쪽 공간이 훨씬 중요하다.
  `max_y`를 **20**까지 낮춰 지면을 화면 620/720 위치로 내렸다(아래 흙 100px).
  `min_y`는 -80이라 트램폴린으로 높이 튀어오르면 카메라가 그만큼 따라 올라간다

- **지붕 밑은 화분 안전지대다.** 지붕 삼각형과 똑같은 모양의 `RoofShelter`(Area2D, `pot_shelter` 그룹)가 있고,
  화분이 여기 닿으면 그 자리에서 깨진다 — "보이는 지붕 = 막아주는 범위"라 눈으로 판단한 대로 안전하다.
  판정을 그룹으로 뺐으므로 다른 맵에서도 `pot_shelter` 그룹 Area2D만 놓으면 같은 효과가 난다
- **스프링 좌석과 미끄럼틀 발판은 둘 다 원웨이여야 한다.** 좌석(226~244)이 꽉 찬 충돌이면
  캐릭터(220~280)와 겹쳐서 **옆으로 걸어 지나갈 수가 없다** — 스프링 시소 두 대가 통행을 막는 벽이 된다.
  원웨이로 바꾸고 점프 부스트 판정도 좌석 위(176~216)로 좁혀서, 밑으로 지나가는 캐릭터는 부스트를 안 받게 했다
- **미끄럼틀은 반대로 막는 게 맞다.** 48.3° 경사는 Godot이 "벽"으로 보므로 아래턱(x≈-403)에서 지상 이동이 막힌다.
  그래서 구조물을 왼쪽 벽 쪽으로 붙여서, 막히는 구역이 "집 아래 공간"이 되게 했다 —
  그 공간은 발판(원웨이)을 통해 이단 점프로 오갈 수 있다

- **발판 높이(바닥에서 120px)는 이단 점프 여유를 보고 정했다.** 처음엔 135px(윗면 145)로 뒀는데,
  당시 이단 점프 최대치(165px)에 너무 붙어서 두 번째 점프를 정점에서 정확히 눌러야만 올라갈 수 있었다.
  15px 낮춰 여유 45px를 만들었다
- **주의: `1834b5f`(넉백 시스템)에서 `DEFAULT_GRAVITY`가 900 → 1150으로 바뀌면서 점프 높이가 전부 줄었다.**
  실측 평지 1단 71 → **56.3px**, 이단 165 → **129.2px**, 스프링 278 → **219px**.
  놀이터 발판(필요 120px)은 여유가 45 → **9px**로 줄어 아슬아슬하게 올라가고,
  **지하철 승강장 벤치(필요 145px)는 아예 못 올라간다** — 열차를 피할 유일한 수단이라 사실상 맵이 깨진 상태다.
  중력을 되돌리지 않는다면 `DEFAULT_AIR_JUMP_VELOCITY`를 -420 → **약 -507**로 올리면
  이단 점프가 다시 165px가 되어 두 맵 모두 원래 설계대로 돌아온다
- **경사면은 `floor_max_angle`(기본 45°)보다 가파르게 잡아야 미끄러진다.** 48.3°라 Godot이 이 면을
  "바닥"이 아니라 "벽"으로 보고, 캐릭터가 붙어서 아래로 흘러내린다 — 그게 곧 미끄럼틀이다.
  45°보다 완만하면 그냥 걸어 다니는 비탈이 된다
- **주의(실제로 겪은 함정): 경사면 폴리곤의 평평한 윗변이 노출되면 거기가 "서 있을 수 있는 턱"이 된다.**
  처음엔 경사면 윗변(x -160~-138)이 발판 바깥으로 삐져나와 있어서, 미끄러지라고 올려둔 캐릭터가
  그 턱에 그냥 서 버렸다. 지금은 윗변을 x -175~-155로 옮겨 **발판(x ~-155)에 완전히 가려지게** 해뒀다
- **놀이터 스프라이트 배치**(전부 배경 제거 후 `region_rect`로 여백을 잘라 씀):
  `기린시소.png`는 왼쪽(x=400), `파란시소.png`는 오른쪽(x=560), `화분.png`는 `FallingPot.tscn`.
  시소는 **안장 윗면이 좌석 충돌(y=226)에, 받침 바닥이 지면(y=280)에** 오도록 배율을 잡았다
  (기린 0.09 / 파란 0.078261 — 각 그림의 "안장→받침" 픽셀 거리가 54px이 되는 값).
  화분은 테라코타 몸통 폭이 충돌 상자(36px)와 맞도록 0.055385
  - **주의: 시소 원본 두 장은 투명 배경이 아니라 체크무늬가 그려져 있었다**(모서리 알파 1.0).
    "밝고 무채색"(min>0.82, 최대-최소<0.06)인 픽셀만 바깥에서 flood fill로 지웠다 —
    캐릭터의 크림색 얼굴은 채도가 있어서 안 지워진다. 원본은 스크래치패드에 백업해둠
  - 스프링 눌림 연출은 `Visual` 노드를 **지면(y=280) 기준으로** 세로 압축한다.
    스프라이트가 `centered = false`라 노드 자체를 지면에 두지 않으면 위로 줄어들어 어색해진다
- `maps/SpringJumpPad.gd`: **트램폴린** — 좌석에 닿는 순간 점프 버튼과 무관하게 위로 튕겨 올라간다.
  `bounce_velocity`(700, 최소 튕김) / `bounce_restitution`(1.15, 떨어진 속도에 곱함) /
  `max_bounce_velocity`(1100, 상한)로 조절한다. 실측: 그냥 올라서면 **219px**, 높은 데서 떨어지면 **362px**
  - 착지 순간에는 `velocity.y`가 이미 0이라 낙하 속도를 알 수 없다. 그래서 캐릭터별로 **직전 프레임의
    낙하 속도(`_prev_fall`)를 기억해뒀다가** "세게 떨어질수록 높이 튕김"을 계산한다
  - 판정을 좌석 바로 위(y 176~216)에만 두어서, 좌석 밑(지면 y 220~280)으로 지나가는 캐릭터는 반응하지 않는다
  - `area_entered/exited` 신호 대신 매 프레임 `get_overlapping_areas()`를 훑는다(`HazardPlatform`과 같은 방식) —
    라운드 리셋·순간이동으로 신호가 안 오는 경우가 있기 때문
  - **예전에는 `set_modifier("jump_multiplier", ...)`로 점프력을 2배 만드는 방식이었다.** 트램폴린으로 바뀌면서
    폐기 — 닿으면 바로 튕기므로 좌석 위에 가만히 서 있을 수가 없어 배수를 걸어둘 이유가 없어졌다
- `maps/FallingPot.gd` + `FallingPot.tscn`: `Hitbox`를 상속한 낙하 화분(데미지 10, 주인 없는 판정).
  맞히거나 바닥(`floor_y` 262)에 닿으면 몸통을 숨기고 파편을 0.25초 보여준 뒤 사라진다
  - **주의(실제로 겪은 버그): `area_entered` 콜백 안에서 `monitoring = false`를 하면
    "Function blocked during in/out signal" 에러가 난다.** `set_deferred("monitoring", false)`로 미뤄야 한다
  - 화분은 Area2D라 발판·좌석을 그냥 통과한다(바닥 높이에서만 깨진다). 발판 위에서도 맞는다는 뜻이라
    지금은 이대로 두었다 — 발판에 걸리게 하려면 별도 판정이 필요하다
- `maps/PotSpawner.gd`: `interval_min/max`(1.2~2.8초)·`first_delay`(3초)·`spawn_half_width`(420)·
  `max_alive`(6)로 빈도와 범위를 조절한다. 데미지는 화분 쪽(`FallingPot.tscn`)에 있다
- `maps/SandPit.gd`: 맵 한가운데 깔린 **모래사장** — 안에 서 있는 동안 이동속도가 `slow_multiplier`(0.6)배로 느려진다.
  `set_modifier("move_speed_multiplier", 노드 instance_id, 배수)`로 걸었다가 벗어나면 `clear_modifier`로 푼다 —
  고정 배수를 직접 대입하지 않으므로 도발·기타연주 같은 다른 둔화와 겹쳐도 서로 안 지운다
  - **판정을 발치 높이(y 256~296)에만 뒀다.** 지면에 선 캐릭터의 Hurtbox는 y 220~280이라 24px이 겹쳐 걸리고,
    점프하면(1단 56.3px) 바로 판정을 벗어난다 — **걸어서 느리게 건너느냐, 점프로 뛰어넘느냐**의 선택이 되도록 의도한 것이다.
    모래 위에서 공중에 뜬 동안에는 느려지지 않는다
  - 폭을 ±260으로 잡은 이유: 왼쪽 미끄럼틀 아래턱(x -403)과 오른쪽 스프링 시소(좌석 x 354~606)를 안 건드리고,
    `PlayerSpawn1`(x -300, 캡슐 반지름 20이라 -320~-280)이 **모래 밖에서 시작**하도록 20px 여유를 둔 값이다.
    폭을 넓힐 때 이 세 가지를 같이 확인할 것
  - 겹침 판정은 `area_entered` 신호가 아니라 매 프레임 `get_overlapping_areas()`를 훑는 방식(`SpringJumpPad`와 동일) —
    라운드 리셋·순간이동으로 신호가 안 오는 경우가 있기 때문

### `maps/SubwayPlatform.tscn` 구조 (2026-09-03 기획 확정본)

**승강장 바닥이 없다 — 플레이어는 선로 바닥에서 싸운다.** 기획 그림에서 승강장 폴리곤에 X 표시가 와서 통째로 지웠고, 올라갈 수 있는 발판은 **의자 2개뿐**이다.

| 요소 | 좌표 |
|---|---|
| 선로 바닥(서 있는 곳) | y = 300 (`Ground`는 y=320에 1120x40) |
| 좌우 터널 벽 | x = ±560 (40x900) → 실제 이동 범위 x -520~520 |
| 의자 발판 윗면 | y = 155 (`BenchLeft`/`BenchRight`, x=±280, 220폭, 원웨이) |
| 열차 | y 195~300 (`DecoSubwayTrain`이 y=247.5) |
| 역 이름 표시 | 중심 (0, 25), 띠 y -4~61 |
| 벽 타일 | x -1000~1000 / y -320~320 |
| 카메라 | `min_y` 80 / `max_y` 190 (바닥이 화면 아래쪽이라 위로 붙임) |

- **의자 높이(바닥에서 145px)는 이단 점프 전용이다.** 지상 점프는 71.1px뿐이라 절대 못 닿고, 이단 점프(실측 165.4px)로만 올라간다 — "넉백으로 거리가 벌어졌을 때 이단 점프로 의자에 올라간다"는 기획 확정 5를 숫자로 강제한 것
- **의자에 올라서면 열차에 안 맞는다.** 의자에 선 캐릭터는 y 95~155를 차지하고 열차 지붕은 195라 **40px 여유**가 있다. 이 여유가 이 맵의 유일한 피난 수단이므로, 의자 높이나 열차 크기를 건드릴 때 반드시 같이 계산할 것
- **의자는 트리에서 열차보다 먼저 나온다 = 열차가 의자 앞을 지나간다.** 기획 확정 3의 "건너편에 있는 의자처럼 표현"을 깊이감으로 살린 것 — 의자 그림은 y 108.6~221.9라 다리 끝이 열차와 겹치는데, 열차가 그 위를 덮고 지나가면 "건너편 승강장 의자"로 읽힌다. 순서를 바꾸면 의자가 열차 위에 얹힌 것처럼 보인다
- 의자는 이제 공중에 떠 있으므로 **다리 끝을 바닥에 맞추던 제약이 없어졌다.** 배율을 0.153846 → 0.190147로 키워 폭 220으로 넓혔다(착지가 쉬워짐)
- 링아웃은 없다 — 바닥이 벽 사이를 꽉 채우고 있어서 떨어질 곳이 없다. 맵 이름도 `GameState.MAPS`에서 "지하철 승강장 (열차)"로 바꿨다

### 지하철역 스프라이트 배치 (`sprite/맵/지하철역/`)

전부 `region_rect`로 **투명 여백을 잘라낸 뒤** 배치했다(여백까지 쓰면 위치 계산이 전부 어긋난다). 아래 숫자는 헤드리스로 실측해 맞춘 값이다.

| 그림 | 잘라 쓰는 영역(region_rect) | 배율 | 월드 배치 |
|---|---|---|---|
| `Metro!.png` (열차) | `Rect2(36, 221, 2101, 250)` | 0.42 | 882.4 x 105, 그림 y 195~300 |
| `지하철선로.png` (선로) | `Rect2(14, 287, 2143, 177)` | 0.541297 | 1160 x 95.8, 윗면 y=300. 스테이지 안쪽 1장은 `Track`(미리보기 포함), 바깥 2장은 `DecoBackground` |
| `등받이.png` (의자 발판) | `Rect2(144, 245, 1157, 596)` | 0.190147 | 220 x 113.3, 의자마다 `position (-110, -56.4)`·`centered=false` |
| `역이름.png` (역 표시) | `Rect2(88, 184, 2015, 325)` | 0.496278 | 1000 x 161.3, 중심 (0, 25) |
| `지하철벽타일.png` (벽 타일) | `Rect2(44, 40, 1446, 926)` | 0.345781 | 500 x 320.2짜리 8장(4열 x 2행) |

- **`Metro! - 복사본.png`는 `Metro!.png`와 md5까지 같은 완전 중복 파일**이다. 쓰지 않는다
- **벽 타일은 반복(texture_repeat) 대신 스프라이트를 여러 장 깔았다.** 원본 바깥쪽에 반투명 비네트가 있어서 그냥 타일링하면 이음매마다 어두운 띠가 생긴다 — `region_rect`로 비네트를 잘라내고 8장을 이어 붙이면 이음매가 타일 사이 검은 줄눈처럼 보인다
- **`역이름.png`의 좌우로 뻗은 띠는 그림 폭(1000)까지밖에 안 간다.** 벽 전체로 이어지도록 같은 색 `Color(0.2431, 0.2431, 0.5569)` 띠(`SignBand`, y 0~57)와 검은 테두리(`SignBandOutline`, y -4~61)를 벽 전체 폭으로 깔고 그 위에 그림을 얹었다. 그림 안 띠의 세로 위치와 정확히 맞춰둔 값이라 그림 위치를 옮기면 이 두 폴리곤도 같이 옮겨야 한다
- `Track`(선로 안쪽 1장)만 `Deco` 접두사가 없는 이유: 미리보기에서 바닥 선이 보이려면 스테이지 폭만큼의 선로가 필요하고, 화면 밖까지 이어지는 나머지 2장은 미리보기 바운딩 박스만 키우기 때문이다
- **아직 안 들어간 기획:** ① 열차 위에서 전투(지금은 확정 4대로 지붕에 올라가도 튕겨 나간다) ② 두 번째 열차에 지하철 빌런 무리가 쏟아져 나오는 연출 — 둘 다 "넣고 싶은 것"으로만 받아둔 상태

- **발판은 반드시 `one_way_collision = true`로 둘 것(실제로 겪은 버그).** 캐릭터 캡슐이 60px 높이인데 지상 점프가 71px밖에 안 되니, 지상 점프로 올라갈 수 있는 발판의 **밑 공간은 34px**밖에 안 남는다 — "밑으로 지나다닐 수 있으면서 뛰어올라갈 수도 있는 높이"는 이 게임에 존재하지 않는다. 꽉 찬 충돌로 두면 발판 밑에 선 캐릭터가 발판과 바닥 사이에 껴서 y=250이 아니라 y≈266으로 눌린다. 원웨이면 위에서만 착지 판정이 걸려 밑은 자유롭게 지나다니고 아래에서 점프하면 뚫고 올라간다
  - `maps/NoisyApartment.tscn`의 `UpperPlatform`에도 같은 버그가 있었다(발판 225~245, 밑 공간 35px). 함께 원웨이로 고침
  - 반대로 `maps/TrashRoom.tscn`의 쓰레기 더미들은 바닥에 붙어 있는(밑 공간이 아예 없는) 장애물이라 **원웨이로 바꾸면 안 된다** — 통과해서 지나다닐 수 있게 되면 장애물 역할이 없어진다
- **`Deco`로 시작하는 노드 이름은 "맵 선택 미리보기에서 빼라"는 뜻이다.** `ui/MapPreview.gd`는 맵 씬의 `Polygon2D`와 `Sprite2D`를 전부 모아 바운딩 박스에 맞춰 축소해 그리는데, 배경 벽·선로처럼 화면 밖까지 크게 깔아둔 장식(`SubwayPlatform`의 `DecoBackground`는 1800x860)이 섞이면 실제 스테이지가 미리보기 안에서 점처럼 작아진다. 그래서 `Camera2D`/`CanvasLayer`와 함께 이름이 `Deco`로 시작하는 가지를 통째로 건너뛴다 — 새 맵에 배경 장식을 넣을 때도 이 이름 규칙을 지킬 것
  - `MapPreview`는 원래 `Polygon2D`만 그렸는데, 지하철 승강장의 벤치가 폴리곤에서 스프라이트로 바뀌면서 미리보기에 아무것도 안 남는 문제가 생겨 **`Sprite2D`도 같이 그리도록 확장했다**(`_sprite_entry()`가 `region_enabled`/`centered`/`scale`을 반영해 사각형을 계산하고 `draw_texture_rect_region()`으로 그린다). 앞으로 다른 맵도 스프라이트로 갈아끼울 때 미리보기가 저절로 따라온다

## GDScript 코드 스타일

### 명명 규칙

| 대상 | 규칙 | 예시 |
| --- | --- | --- |
| 클래스명 / 파일명 | PascalCase, 파일명은 class_name과 동일하게 | `CharacterStats.gd` 안에 `class_name CharacterStats` |
| 함수 / 변수 | snake_case | `move_speed`, `take_damage()` |
| 상수 / enum 값 | ALL_CAPS_SNAKE_CASE | `MAX_HP`, `STATE_STUNNED` |
| 시그널 | 과거형 snake_case (일어난 일을 알림) | `health_changed`, `skill_used` |
| private 관례 | 언더스코어 접두사 (GDScript엔 진짜 private이 없어 관례로만 구분) | `_internal_cooldown` |

### 파일 구조

- `class_name`과 `extends` 선언은 파일 맨 위, `class_name`이 없다면 `extends`만
- `export`/`@export` 변수 → 그 외 멤버 변수 → `_ready()` 등 생명주기 함수 → 커스텀 함수 순으로 배치
- 씬(`.tscn`)과 스크립트(`.gd`)는 같은 폴더에 짝지어 배치 (예: `characters/jujeongbaengi/Jujeongbaengi.tscn`, `characters/jujeongbaengi/Jujeongbaengi.gd`)

### 주석 — 한국어 필수

- `public`으로 노출되는 함수/변수 위에는 GDScript 독스트링(`## 설명`) 한 줄로 한국어 설명
- 복잡한 로직(예: 술 스택에 따른 사거리 계산)에만 한 줄 한국어 설명. 자명한 코드에는 주석 금지

### 폴더 구조 (제안)

```
res://
  GameState.gd    # 오토로드 싱글턴 — 캐릭터/맵/모드/라운드 선택값 전달
  characters/     # Fighter.gd(공용 베이스) + 캐릭터별 씬 (chokbeopsonyeon/, akpeulleo/, jujeongbaengi/, catmom/, subwayvillain/, floornoise/ — 6종)
  skills/         # Skill.gd(공용 베이스) + 실제 스킬 컴포넌트, 투사체
  combat/         # Hitbox/Hurtbox/HitSpark (전투 판정 + 히트 이펙트)
  controllers/    # PlayerController / AIController
  stats/          # CharacterStats 리소스(.tres)
  maps/           # Stage.gd(공용 베이스) + CameraRig.gd + 스테이지 씬 9종
  ui/             # MainMenu/ModeSelect/RoomSettings/CharacterSelect/MapSelect/StoryIntro/ReformCutscene/StoryClear/MatchResult, HP바·쿨타임 HUD
```

## 참고

- 기획 오픈 이슈(히트스턴 예외, 승리 조건 HP vs 링아웃 등)는 아티팩트 문서의 "다음에 정할 것" 표를 확인. 확정 전까지는 구현 시 임시값으로 처리하고 주석/TODO로 표시
- **엔진 버전은 4.6으로 통일한다.** 4.7로 프로젝트를 열면 `project.godot`의 `config/features`가 `"4.7"`로 다시 쓰이고, 4.6으로 연 커밋과 **매번 머지 충돌이 난다**(실제로 겪음 — 바로 옆 줄인 `run/main_scene`까지 같이 충돌로 딸려 들어왔다). 반드시 4.6.x로 열 것
- Godot 실행 파일(PC마다 다름): 이 PC는 `D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe`, 다른 PC는 `D:\10인준완\Godot\engine\` 아래. 헤드리스로 씬을 실행해서 런타임 에러를 확인할 수 있음 — 예: `<위 경로> --headless --path "<프로젝트 경로>" "res://maps/ConvenienceStore.tscn" --quit-after 120`. 코드를 수정한 뒤에는 이렇게 실행해서 에러 콘솔이 깨끗한지 확인하고 보고할 것. (경로가 없으면 `Godot*4.6*win64_console.exe`를 찾을 것 — 4.7을 쓰면 위의 충돌이 난다)
- **주의:** 새 `class_name` 스크립트를 추가한 직후에는 먼저 `<위 경로> --headless --path "D:/10인준완/Godot/villain" --editor --quit-after 5`로 한 번 실행해서 전역 클래스 캐시를 갱신해야 함. 안 그러면 방금 만든 클래스를 참조하는 다른 스크립트가 "Could not find type" 에러로 로드 실패함
- 자동 입력 시뮬레이션이 필요한 테스트는 `extends SceneTree` + `--script` 방식이 아니라, `extends Node` 스크립트를 임시 `.tscn`으로 감싸서 `--headless --path ... <임시 씬> --quit-after N`로 실행할 것 — `--script` 모드는 오토로드(`GameState` 등)가 초기화되지 않아 컴파일 에러가 남
- **주의:** 헤드리스 모드는 프레임 제한이 없어서 60fps보다 훨씬 빠르게 돈다(실측 약 145fps). 쿨타임·버프 지속시간처럼 시간 기반 로직을 테스트할 때 `--quit-after N`의 N을 "60fps 기준 초"로 계산하면 실제로는 그보다 훨씬 짧은 시간만 흐른다 — 프레임 수 대신 `Time.get_ticks_msec()`로 실제 경과 시간을 재면서 대기하거나, `--fixed-fps 60`을 같이 붙여서 프레임당 델타를 고정시킬 것
