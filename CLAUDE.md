# 빌런 파이터즈 (villain) — Godot 프로젝트 규칙

사이드뷰 대전 격투 게임 "빌런 파이터즈"의 Godot 프로젝트입니다. 기획 문서(캐릭터 로스터·맵·전투 시스템)는 다음 아티팩트에 정리되어 있습니다: https://claude.ai/code/artifact/661e48af-d8db-49c9-bc68-a9294790becb

전역 규칙(한국어 응답, 초보자 눈높이 설명, 안전 규칙 등)은 그대로 유지하되, 코드 스타일은 이 문서가 우선합니다 — 전역 CLAUDE.md는 Unity/C# 기준이지만 이 프로젝트는 **Godot/GDScript**로 개발합니다.

## 프로젝트 정보

- 엔진: Godot 4.7, GDScript
- 렌더러: Forward Plus, 3D 물리엔진 Jolt (프로젝트 기본값 — 실제 게임은 2D)
- 장르: 사이드뷰 대전 격투, 바운스어택류(타격 후 넉백을 다시 잡아채는) 콤보 중심
- 전투 원칙: 피격 경직(히트스턴) 최소화 지향, 지형·벽을 활용하는 스테이지 기믹

## 확정된 아키텍처 방향

기획 문서의 "캐릭터 시스템 프레임워크" 절에서 정한 방향을 실제로 구현한 결과입니다. **캐릭터 전용 `.gd` 스크립트는 만들지 않습니다** — 모든 캐릭터 씬은 `characters/Fighter.gd`를 루트 스크립트로 쓰고, 스탯 리소스(`.tres`)와 스킬 노드 조합만으로 차이를 만듭니다.

- `characters/Fighter.gd`: 모든 캐릭터의 공용 베이스(`CharacterBody2D`). 이동/점프/중력, HP(`take_damage`/`heal`/`health_changed` 시그널), 스킬 슬롯(`skill_1`/`skill_2`/`skill_ultimate`/`basic_attack` — 자식 노드 이름 `Skill1`/`Skill2`/`SkillUltimate`/`BasicAttack`으로 자동 연결됨), 자유 형식 데이터 저장소 `custom_data`(예: 주정뱅이 술 스택)를 담당
- 버프·디버프(`move_speed_multiplier` 등)는 직접 대입하지 않고 **`fighter.set_modifier(property, id, value)`/`clear_modifier(property, id)`**로 건다. 같은 property에 여러 효과가 동시에 걸려도 서로 안 지우고 곱해져서 적용된다(id별로 따로 저장했다가 곱함). 일정 시간만 유지되는 임시 효과는 `apply_temp_multiplier(property, value, duration)`가 자동으로 id를 발급해서 만료 처리까지 해줌. 술 스택처럼 켰다 껐다 하는 지속 효과는 `"drink_stacks"` 같은 고정 문자열 id로 직접 `set_modifier`/`clear_modifier` 호출 (`DrinkSkill.gd`/`VomitSkill.gd` 참고). **예전에는 `set(property, value)`로 직접 덮어써서 디버프 두 개가 겹치면 나중 게 먼저 걸린 걸 지워버리는 버그가 있었음 — 지금은 해결됨**
- `skills/Skill.gd`: 모든 스킬의 공용 베이스(`Node`). 쿨타임 카운트다운과 `can_use()`/`use(fighter)`를 여기서 한 번만 구현. 새 스킬은 이 클래스를 상속해서 `_execute(fighter)`만 오버라이드
- `combat/Hitbox.gd` / `combat/Hurtbox.gd`: 실제 데미지 판정. `Hurtbox`는 Fighter의 자식 Area2D로 피격을 받아 `take_damage()`를 부르고, `Hitbox`는 공격 판정 Area2D로 `Hurtbox`와 겹치면 데미지를 준다 (자기 자신은 무시)
- `skills/MeleeAttack.gd`: 기본공격 공용 스킬 — 캐릭터 앞에 히트박스를 잠깐 켰다 끈다. `damage`/`range`만 캐릭터마다 다르게 지정해서 재사용 (사탕찌르기, 키보드 휘두르기, 술병깨기, 팻말 때리기 전부 이걸 씀)
- **주의(실제로 겪은 버그):** `get_tree().create_timer(t).timeout.connect(func(): 어떤노드.뭔가 = 값)`처럼 다른 노드를 건드리는 콜백을 예약할 때, 그 노드가 타이머가 끝나기 전에 사라지면(대전 도중 나가기·다시하기 등으로 씬이 통째로 정리되는 경우) `ERROR: Lambda capture ... was freed`가 나면서 사라진 노드를 건드리려다 에러가 난다. `get_tree().create_timer()`는 SceneTree에 속해서 관련 노드보다 오래 살아남기 때문. 해결책은 `is_instance_valid()` 체크가 아니라 **그 노드(또는 관련 스킬 노드)의 자식으로 `Timer` 노드를 만들어서 씀** — 부모가 사라지면 자식 Timer도 같이 사라져서 콜백 자체가 아예 실행되지 않는다(`Fighter._after()`, `FirePlate.gd`, `Projectile.gd` 참고). `await get_tree().create_timer(t).timeout`처럼 하나만 기다리고 끝내는 짧은 대기(`MeleeAttack`의 히트박스 on/off 등)는 이 문제가 잘 안 생겨서 그대로 둬도 됨
- **주의(실제로 겪은 버그):** `Skill`은 `Node`를 상속해서 `Node2D`가 아니다. 그래서 `Hitbox`(Area2D)를 Skill 노드의 자식으로 둔 경우 `hitbox.position = ...`(부모 상대 좌표)을 쓰면 부모 트랜스폼 체인이 끊겨서 항상 `(0,0)` 기준으로 배치된다 — 겉으로는 에러 없이 조용히 공격이 안 맞는 버그가 된다. 이런 히트박스는 반드시 `hitbox.global_position = fighter.global_position + Vector2(range * fighter.facing, 0)`처럼 **global_position으로 직접 배치**할 것 (`MeleeAttack.gd` 참고). 반대로 `Projectile`/`FirePlate`처럼 맵(Node2D)에 직접 `add_child`하는 경우는 이 문제가 없음
- 이동을 잠깐 가로채는 스킬(돌진 등)은 `Fighter.movement_override`에 자기 자신을 등록하고 `get_move_velocity_x()`/`after_physics(fighter, delta)`를 구현 (`skills/DashSkill.gd` 참고)
- `Fighter.is_feared`/`apply_fear(duration)`: 공포 상태(지하철빌런 `skills/FearSkill.gd`)면 이동은 되지만 `use_skill_1/2/ultimate/basic_attack`이 전부 무시된다("무서워서 반격을 못 하는" 느낌). `set_tint`로 색조도 같이 걸어서 눈으로 구분됨
- `combat/Hitbox.gd`의 `pull_to_source`/`pull_strength`: true면 고정된 `knockback` 대신, 맞는 순간 공격자 쪽 방향을 계산해서 끌어당긴다(청소기 흡입 — `skills/VacuumSkill.gd`)
- `skills/AoeAttack.gd`: `MeleeAttack`(전방 사각형)과 별개로, 캐릭터 자신을 중심으로 한 원형 범위 공격 공용 스킬. `damage`/`radius`에 더해 `slow_multiplier`/`slow_duration`을 주면 맞은 상대에게 `apply_temp_multiplier`로 둔화 디버프도 건다(층간피해빌런 기타연주, 재사용 가능)
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
- `Fighter.vault_jump: bool`: true인 캐릭터(지하철빌런)는 기본공격이 없는 대신, 점프할 때 `_play_vault_effect()`가 회전 트윈으로 "개찰구를 뛰어넘는" 연출을 보여준다
- **주의(실제로 겪은 버그):** `add_child(node)`로 노드를 트리에 붙이면 `_ready()`가 **그 자리에서 동기적으로** 실행된다 — `add_child()` 호출 다음 줄에서 그 노드의 export 변수를 세팅해도, `_ready()`는 이미 그 전에(즉 기본값으로) 끝나버린 뒤다. `_ready()` 안에서 `wait_time = lifetime` 처럼 export 값을 캐싱하면 호출자가 나중에 설정한 값이 아니라 기본값이 캐싱되는 버그가 생김(캣맘 `skills/CatPet.gd`에서 실제로 겪음). 해결책: 그런 캐싱은 `_ready()`가 아니라 **첫 `_physics_process`/`_process` 호출 시점**(`_initialized` 플래그로 한 번만 실행)으로 미룰 것 — 그때는 호출자의 프로퍼티 설정이 이미 끝나 있음이 보장됨

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
  - **TODO(미구현):** 플랫폼 아래로 내려가기는 키만 잡아두고 동작은 비어 있다(`PlayerController._drop_through_platform()`). 현재 맵 발판에 원웨이 충돌(one_way_collision)이 하나도 없어서, 발판을 원웨이로 바꾼 뒤에 통과 처리를 구현해야 함

## 캐릭터 몸(스프라이트 조립)

`characters/BodyRig.tscn` — 러프 스프라이트 조각(머리/몸/손/발)을 Sprite2D로 조립해둔 공용 몸. 캐릭터 씬의 `Visual` 자리에 인스턴스로 넣는다(현재 주정뱅이만 적용). 이름이 `Visual`이라 피격 시 빨개지는 연출(`Fighter._flash_hit`)이나 궁극기 연출이 그대로 동작한다.

- **파일 배치 규칙:** 여러 캐릭터가 함께 쓰는 파츠는 `sprite/body/`(몸통·손·발), 캐릭터 전용 파츠는 `sprite/<캐릭터>/몸/`에 둔다(주정뱅이는 몸·발·머리를 전용으로 쓰고 손만 공용)
- `BodyRig.tscn`의 `Head`에는 텍스처가 비어 있다 — 머리는 캐릭터마다 다르므로 각자 상속 씬에서 지정한다
- **캐릭터별 머리는 씬 상속으로 만든다.** `BodyRig.tscn`을 상속한 씬을 캐릭터 폴더에 두고 `Head`의 텍스처/위치/크기만 덮어쓴다(예: `characters/akpeulleo/AkpeulleoRig.tscn`). 이러면 몸/손/발 위치를 `BodyRig.tscn`에서 한 번만 고쳐도 전 캐릭터에 반영되고, 에디터에서 미리보기도 제대로 된다. 현재 주정뱅이(BodyRig 자체가 주정뱅이 머리를 들고 있음)·악플러 두 명 적용됨
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
- 점프할 때마다 **최고 높이 / 체공 시간 / 수평 이동 거리**를 자동으로 재서 패널에 표시한다 (기본값 중력 900·점프력 -350 기준: 약 65px, 0.78초)
- 조절 패널은 게임 UI가 아니라 개발 도구라서 `.tscn`에 배치하지 않고 `TrainingGround.gd`에서 코드로 만든다
- **중요:** 이 화면에서 값을 바꾸려고 `Fighter.GRAVITY`/`JUMP_VELOCITY` 상수를 `static var Fighter.gravity`/`Fighter.jump_velocity`로 바꿨다. 모든 Fighter가 공유하는 값이고, 훈련장에서 바꾼 값은 **게임을 끌 때까지 유지**돼서 그대로 로컬 대전에 들어가 시험해볼 수 있다. 값이 마음에 들면 `Fighter.gd`의 `DEFAULT_GRAVITY`/`DEFAULT_JUMP_VELOCITY`에 옮겨 적어야 영구 반영된다
- 이동속도는 캐릭터별 스탯(`stats/*.tres`의 `move_speed`)이라 훈련장에서는 배수(`move_speed_multiplier`)로만 조절한다 — 확정되면 각 `.tres`를 고칠 것

## 궁극기 컷인 연출

`ui/UltimateCutIn.tscn` — 궁을 쓰면 카메라가 시전자에게 빨려들어갔다가 컷인을 보여주고 돌아온 뒤 실제 궁이 나간다. `Stage.gd`와 `maps/TrainingGround.gd`가 `_ready()`에서 자동으로 심고, `Fighter`는 `ultimate_cutin` 그룹으로 찾아 쓴다(연출 노드가 없는 씬이면 궁이 그냥 즉시 발동).

**기획 확정 사항** (임의로 바꾸지 말 것):
- **전체 1.5초** — 줌인 0.25 / 컷인 1.0 / 복귀 0.25. 전부 `@export`라 인스펙터에서 조절 가능
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

- **괴성은 컷인에서 지르지 않는다.** 컷인은 참는 구간(예비동작)이고, 실제로 지르는 건 화면 복귀 후 인게임 궁극기 — 그래야 판정이 나가는 순간이 살아난다

## 게임 플로우 / 씬 전환

`GameState.gd`(프로젝트 루트, 오토로드 싱글턴)가 화면 사이에서 선택값을 들고 다닙니다.

**로컬 대전(PvP) 흐름:** `ui/MainMenu.tscn`(시작) → `ui/ModeSelect.tscn`("로컬 대전" 선택) → `ui/RoomSettings.tscn`(선취 라운드 수 1~40, 시간제한 무제한/1~5분 설정 → `GameState.rounds_to_win`/`time_limit_seconds`) → `ui/CharacterSelect.tscn`(P1→P2 순서로 캐릭터 선택, `GameState.p1_character_path`/`p2_character_path`에 저장) → `ui/MapSelect.tscn`(맵 선택 시 바로 그 맵 씬으로 전환) → 선택한 맵(`Stage.gd` 상속).

**스토리 모드 흐름:** `ui/MainMenu.tscn` → `ui/ModeSelect.tscn`("스토리 모드" 선택 — `rounds_to_win=2`, `time_limit_seconds=120` 고정, `story_index=0`으로 초기화) → `ui/StoryIntro.tscn`(P1 캐릭터만 고름 — P2는 `GameState.STORY_OPPONENTS[story_index]`로 자동 지정, 맵도 `GameState.STORY_MAP_PATH`로 고정) → 맵(`Stage.gd`) → (P1 승리 시) `ui/ReformCutscene.tscn`(방금 이긴 빌런 전용 반성 대사 표시, "개과천선" — 캐릭터별 대사는 `ReformCutscene.REFORM_LINES` 딕셔너리) → 다음 상대로 자동 진행, 전원 격파 시 `ui/StoryClear.tscn`. P1이 지면 스토리 진행 없이 일반 결과 화면(다시하기/메인 메뉴로)만 뜬다

**훈련장 흐름:** `ui/MainMenu.tscn` → `ui/ModeSelect.tscn`("훈련장" 선택) → `maps/TrainingGround.tscn`. 캐릭터 선택·맵 선택 화면을 거치지 않고 바로 들어가고, 캐릭터는 훈련장 안의 드롭다운으로 바꾼다(바꾸면 그 자리에서 다시 스폰). 상대·라운드·시간제한·HUD가 없어서 `Stage.gd`를 상속하지 않는 독립 씬이다

- 캐릭터·맵 후보 목록은 `GameState.CHARACTERS`/`GameState.MAPS` 딕셔너리 하나로 관리 — 캐릭터나 맵을 추가하면 이 딕셔너리에 한 줄만 추가하면 선택 화면에 자동으로 나타남
- 모든 화면에 ESC(`ui_cancel`)로 한 단계 뒤로 나가는 탈출구가 있음: 모드 선택→메인 메뉴, 방 설정→모드 선택, 캐릭터 선택→방 설정, 맵 선택→캐릭터 선택, 스토리 인트로→모드 선택, 대전 중→메인 메뉴. 버튼으로도 동일하게 나갈 수 있음
- **라운드제:** `Stage._process()`가 KO(HP 0) 또는 시간 초과(`GameState.time_limit_seconds`>0이고 다 됐을 때 — 그 순간 HP 높은 쪽이 라운드 승, 동률이면 무승부)를 감지하면 `_end_round(p1_won, is_draw)`를 부른다. 라운드 승수는 `GameState.p1_round_wins`/`p2_round_wins`에 누적되고, 둘 중 하나가 `rounds_to_win`에 도달하지 못했으면 `MatchResult.show_round_result()`로 점수 배너만 잠깐 보여준 뒤 `get_tree().reload_current_scene()`으로 같은 맵에서 다음 라운드를 새로 시작한다(HP/위치는 씬 리로드로 초기화되고, 라운드 승수는 `GameState`가 오토로드라 그대로 유지됨). 도달했으면 최종 결과(`MatchResult.show_result()`/`show_draw()`) 또는 스토리 모드 승리 시 `ReformCutscene`으로 분기
- `CombatHUD`의 `RoundLabel`이 화면 중앙 상단에 라운드 점수(`P1승 : P2승`)와(시간제한이 있으면) 남은 초를 표시. `Stage`가 `combat_hud.update_round_info(p1_wins, p2_wins, time_left)`로 매 프레임 갱신
- `maps/Stage.gd`는 이제 캐릭터를 씬에 미리 박아두지 않고, `_ready()`에서 `GameState`가 가리키는 캐릭터 씬을 `PlayerSpawn1`/`PlayerSpawn2`에 동적으로 생성한다. P1에는 항상 `PlayerController`를 붙이고, P2는 `GameState.game_mode`를 봐서 스토리 모드면 `ClaudeAIController`(정해진 상대를 AI가 조작), 로컬 대전(pvp)이면 `PlayerController`(사람이 직접 조작)를 붙인다. 새 맵은 바닥·벽(or 링아웃용 빈 공간)·`PlayerSpawn1`/`PlayerSpawn2`·`Camera2D`(스크립트: `maps/CameraRig.gd`)·`CombatHUD` 인스턴스만 배치하면 나머지는 `Stage.gd`가 처리
- 승패: `Stage._process()`가 매 프레임 양쪽 Fighter의 `current_hp`를 직접 확인해서 판정한다(HP 0 또는 `ring_out()`). **`died` 시그널에 바로 반응하지 않는 이유:** 시그널에 반응하면 같은 프레임에 양쪽이 동시에 쓰러져도 먼저 처리된 시그널 쪽이 임의로 승자가 되는 버그가 있었음 — 지금은 그 프레임의 데미지가 전부 반영된 뒤 한 번에 판정해서 양쪽 다 0이면 무승부(`MatchResult.show_draw()`)로 처리. 링아웃은 `Stage.ring_out_y`보다 아래로 떨어지면 발동 — 벽이 있는 맵(편의점 앞/PC방/아파트 단지 놀이터)은 사실상 발동 안 되고, 벽이 없는 학교 옥상·지하철 승강장에서만 의미가 있음
- 히트 이펙트: 맞으면 `Fighter._flash_hit()`가 캐릭터를 잠깐 빨갛게 물들이고, `combat/Hitbox.gd`가 실제로 맞았을 때 `combat/HitSpark.tscn`을 스폰
- 상태별 색조는 `Fighter.set_tint(id, color, duration)`/`clear_tint(id)`로 건다. 여러 개가 동시에 걸려도(도발+열등감 오라 등) 서로 안 지우고 스택처럼 쌓였다가, 하나가 풀리면 그 밑에 깔려있던 색으로 돌아간다(전부 없으면 원래 색) — `set_modifier`/`clear_modifier`와 같은 발상. 스킬 9종 전부 이 방식으로 캐릭터별 이펙트가 붙어있음: 잼민이 돌진 잔상(`DashSkill`)·BB탄 총구 섬광(`BBGunSkill`)·궁극기 초록 반짝임(`HealSkill`), 악플러 도발 대상 노란빛(`TauntSkill`)·열등감 붉은 오라(`RageBuffSkill`)·궁극기 어두운 디버프(`WeakenAuraUltimate`), 주정뱅이 스택 비례 빨개짐(`DrinkSkill`)·초록 토사물(`VomitSkill`)·궁극기 빨간 부채꼴+보라 디버프(`ScreamConeUltimate`)
- 넉백: `MeleeAttack`/`Projectile`이 각자 `Hitbox.knockback`을 설정해서 맞은 캐릭터의 `velocity`에 즉시 더한다(`Fighter.take_damage`). 바운스어택류 콤보의 기반 — 아직 스킬 하나하나에 맞는 세밀한 값 조정은 안 되어 있음(전부 임시값)
- 대전 시작 시 `ui/RoundStart.tscn`이 "3, 2, 1, FIGHT!" 카운트다운을 보여주는 동안 양쪽 컨트롤러가 멈춘다(`PlayerController`/`AIController`의 `is_active`). **주의:** 그냥 멈추기만 하면(`set_physics_process(false)`) 멈추기 직전 프레임의 관성(velocity.x)이 남아서 계속 미끄러지는 버그가 났었음 — `is_active=false`일 때도 물리 처리(`apply_physics`)는 계속하되 `fighter.move(0.0)`으로 수평 속도를 매 프레임 0으로 고정해야 함

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
- 씬(`.tscn`)과 스크립트(`.gd`)는 같은 폴더에 짝지어 배치 (예: `characters/jaemini/Jaemini.tscn`, `characters/jaemini/Jaemini.gd`)

### 주석 — 한국어 필수

- `public`으로 노출되는 함수/변수 위에는 GDScript 독스트링(`## 설명`) 한 줄로 한국어 설명
- 복잡한 로직(예: 술 스택에 따른 사거리 계산)에만 한 줄 한국어 설명. 자명한 코드에는 주석 금지

### 폴더 구조 (제안)

```
res://
  GameState.gd    # 오토로드 싱글턴 — 캐릭터/맵/모드/라운드 선택값 전달
  characters/     # Fighter.gd(공용 베이스) + 캐릭터별 씬 (jaemini/, akpeulleo/, jujeongbaengi/, catmom/, subwayvillain/, floornoise/ — 6종)
  skills/         # Skill.gd(공용 베이스) + 실제 스킬 컴포넌트, 투사체
  combat/         # Hitbox/Hurtbox/HitSpark (전투 판정 + 히트 이펙트)
  controllers/    # PlayerController / AIController
  stats/          # CharacterStats 리소스(.tres)
  maps/           # Stage.gd(공용 베이스) + CameraRig.gd + 스테이지 씬 9종
  ui/             # MainMenu/ModeSelect/RoomSettings/CharacterSelect/MapSelect/StoryIntro/ReformCutscene/StoryClear/MatchResult, HP바·쿨타임 HUD
```

## 참고

- 기획 오픈 이슈(히트스턴 예외, 승리 조건 HP vs 링아웃 등)는 아티팩트 문서의 "다음에 정할 것" 표를 확인. 확정 전까지는 구현 시 임시값으로 처리하고 주석/TODO로 표시
- Godot 실행 파일: `C:\Users\kint4\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`. 헤드리스로 씬을 실행해서 런타임 에러를 확인할 수 있음 — 예: `<위 경로> --headless --path "C:/workspace/villain" "res://maps/ConvenienceStore.tscn" --quit-after 120`. 코드를 수정한 뒤에는 이렇게 실행해서 에러 콘솔이 깨끗한지 확인하고 보고할 것
- **주의:** 새 `class_name` 스크립트를 추가한 직후에는 먼저 `<위 경로> --headless --path "C:/workspace/villain" --editor --quit-after 5`로 한 번 실행해서 전역 클래스 캐시를 갱신해야 함. 안 그러면 방금 만든 클래스를 참조하는 다른 스크립트가 "Could not find type" 에러로 로드 실패함
- 자동 입력 시뮬레이션이 필요한 테스트는 `extends SceneTree` + `--script` 방식이 아니라, `extends Node` 스크립트를 임시 `.tscn`으로 감싸서 `--headless --path ... <임시 씬> --quit-after N`로 실행할 것 — `--script` 모드는 오토로드(`GameState` 등)가 초기화되지 않아 컴파일 에러가 남
- **주의:** 헤드리스 모드는 프레임 제한이 없어서 60fps보다 훨씬 빠르게 돈다(실측 약 145fps). 쿨타임·버프 지속시간처럼 시간 기반 로직을 테스트할 때 `--quit-after N`의 N을 "60fps 기준 초"로 계산하면 실제로는 그보다 훨씬 짧은 시간만 흐른다 — 프레임 수 대신 `Time.get_ticks_msec()`로 실제 경과 시간을 재면서 대기하거나, `--fixed-fps 60`을 같이 붙여서 프레임당 델타를 고정시킬 것
