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

- `characters/Fighter.gd`: 모든 캐릭터의 공용 베이스(`CharacterBody2D`). 이동/점프/중력, HP(`take_damage`/`heal`/`health_changed` 시그널), 스킬 슬롯(`skill_1`/`skill_2`/`skill_ultimate`/`basic_attack` — 자식 노드 이름 `Skill1`/`Skill2`/`SkillUltimate`/`BasicAttack`으로 자동 연결됨), 자유 형식 데이터 저장소 `custom_data`(예: 주정뱅이 다음 공격 강화 `rage_bonus_damage`, 예수천국 흡수 데미지 `guard_absorbed`)를 담당
- 버프·디버프(`move_speed_multiplier` 등)는 직접 대입하지 않고 **`fighter.set_modifier(property, id, value)`/`clear_modifier(property, id)`**로 건다. 같은 property에 여러 효과가 동시에 걸려도 서로 안 지우고 곱해져서 적용된다(id별로 따로 저장했다가 곱함). 일정 시간만 유지되는 임시 효과는 `apply_temp_multiplier(property, value, duration)`가 자동으로 id를 발급해서 만료 처리까지 해줌. 스택처럼 켰다 껐다 하는 지속 효과는 고정 문자열 id로 직접 `set_modifier`/`clear_modifier` 호출. **예전에는 `set(property, value)`로 직접 덮어써서 디버프 두 개가 겹치면 나중 게 먼저 걸린 걸 지워버리는 버그가 있었음 — 지금은 해결됨**
- `skills/Skill.gd`: 모든 스킬의 공용 베이스(`Node`). 쿨타임 카운트다운과 `can_use()`/`use(fighter)`를 여기서 한 번만 구현. 새 스킬은 이 클래스를 상속해서 `_execute(fighter)`만 오버라이드
- `combat/Hitbox.gd` / `combat/Hurtbox.gd`: 실제 데미지 판정. `Hurtbox`는 Fighter의 자식 Area2D로 피격을 받아 `take_damage()`를 부르고, `Hitbox`는 공격 판정 Area2D로 `Hurtbox`와 겹치면 데미지를 준다 (자기 자신은 무시)
- `skills/MeleeAttack.gd`: 기본공격 공용 스킬 — 캐릭터 앞에 히트박스를 잠깐 켰다 끈다. `damage`/`range`만 캐릭터마다 다르게 지정해서 재사용 (사탕찌르기, 키보드 휘두르기, 술병깨기, 팻말 때리기 전부 이걸 씀)
- **주의(실제로 겪은 버그):** `get_tree().create_timer(t).timeout.connect(func(): 어떤노드.뭔가 = 값)`처럼 다른 노드를 건드리는 콜백을 예약할 때, 그 노드가 타이머가 끝나기 전에 사라지면(대전 도중 나가기·다시하기 등으로 씬이 통째로 정리되는 경우) `ERROR: Lambda capture ... was freed`가 나면서 사라진 노드를 건드리려다 에러가 난다. `get_tree().create_timer()`는 SceneTree에 속해서 관련 노드보다 오래 살아남기 때문. 해결책은 `is_instance_valid()` 체크가 아니라 **그 노드(또는 관련 스킬 노드)의 자식으로 `Timer` 노드를 만들어서 씀** — 부모가 사라지면 자식 Timer도 같이 사라져서 콜백 자체가 아예 실행되지 않는다(`Fighter._after()`, `GuardSkill.gd`, `FirePlate.gd`, `Projectile.gd` 참고). `await get_tree().create_timer(t).timeout`처럼 하나만 기다리고 끝내는 짧은 대기(`MeleeAttack`의 히트박스 on/off 등)는 이 문제가 잘 안 생겨서 그대로 둬도 됨
- **주의(실제로 겪은 버그):** `Skill`은 `Node`를 상속해서 `Node2D`가 아니다. 그래서 `Hitbox`(Area2D)를 Skill 노드의 자식으로 둔 경우 `hitbox.position = ...`(부모 상대 좌표)을 쓰면 부모 트랜스폼 체인이 끊겨서 항상 `(0,0)` 기준으로 배치된다 — 겉으로는 에러 없이 조용히 공격이 안 맞는 버그가 된다. 이런 히트박스는 반드시 `hitbox.global_position = fighter.global_position + Vector2(range * fighter.facing, 0)`처럼 **global_position으로 직접 배치**할 것 (`MeleeAttack.gd`, `CounterSlamSkill.gd` 참고). 반대로 `Projectile`/`FirePlate`처럼 맵(Node2D)에 직접 `add_child`하는 경우는 이 문제가 없음
- 이동을 잠깐 가로채는 스킬(돌진 등)은 `Fighter.movement_override`에 자기 자신을 등록하고 `get_move_velocity_x()`/`after_physics(fighter, delta)`를 구현 (`skills/DashSkill.gd` 참고)
- 궁극기가 없는 캐릭터(예수천국 불신지옥)는 `SkillUltimate` 자리에 `skills/StanceSwitcher.gd`를 넣어서 궁극기 키(P1 R / P2 P)로 스탠스(천사/악마)를 전환하고, `skill_1`/`skill_2`가 가리키는 실제 스킬을 바꿔치기하는 방식으로 구현. 전환할 때마다 `Visual.modulate`를 흰색/붉은색으로 바꿔서 지금 어느 스탠스인지 눈으로 구분되게 함
- `Fighter.is_feared`/`apply_fear(duration)`: 공포 상태(지하철빌런 `skills/FearSkill.gd`)면 이동은 되지만 `use_skill_1/2/ultimate/basic_attack`이 전부 무시된다("무서워서 반격을 못 하는" 느낌). `set_tint`로 색조도 같이 걸어서 눈으로 구분됨
- `combat/Hitbox.gd`의 `pull_to_source`/`pull_strength`: true면 고정된 `knockback` 대신, 맞는 순간 공격자 쪽 방향을 계산해서 끌어당긴다(청소기 흡입 — `skills/VacuumSkill.gd`)
- `skills/AoeAttack.gd`: `MeleeAttack`(전방 사각형)과 별개로, 캐릭터 자신을 중심으로 한 원형 범위 공격 공용 스킬. `damage`/`radius`에 더해 `slow_multiplier`/`slow_duration`을 주면 맞은 상대에게 `apply_temp_multiplier`로 둔화 디버프도 건다(층간피해빌런 기타연주, 재사용 가능)
- `Fighter.vault_jump: bool`: true인 캐릭터(지하철빌런)는 기본공격이 없는 대신, 점프할 때 `_play_vault_effect()`가 회전 트윈으로 "개찰구를 뛰어넘는" 연출을 보여준다
- **주의(실제로 겪은 버그):** `add_child(node)`로 노드를 트리에 붙이면 `_ready()`가 **그 자리에서 동기적으로** 실행된다 — `add_child()` 호출 다음 줄에서 그 노드의 export 변수를 세팅해도, `_ready()`는 이미 그 전에(즉 기본값으로) 끝나버린 뒤다. `_ready()` 안에서 `wait_time = lifetime` 처럼 export 값을 캐싱하면 호출자가 나중에 설정한 값이 아니라 기본값이 캐싱되는 버그가 생김(캣맘 `skills/CatPet.gd`에서 실제로 겪음). 해결책: 그런 캐싱은 `_ready()`가 아니라 **첫 `_physics_process`/`_process` 호출 시점**(`_initialized` 플래그로 한 번만 실행)으로 미룰 것 — 그때는 호출자의 프로퍼티 설정이 이미 끝나 있음이 보장됨

## 조작 / AI

- `controllers/PlayerController.gd`: 이동/점프/공격/스킬 입력을 읽어서 부모 Fighter를 조작. `player_index`(1 또는 2)에 따라 `p1_*`/`p2_*` 액션을 읽으므로 P1/P2 모두 사람이 조작할 수 있다
- `controllers/AIController.gd`: 목표 Fighter와의 거리를 보고 접근/거리유지/후퇴/기본공격/스킬 사용을 스스로 결정하는 단순 AI. Fighter 입장에서 플레이어가 조작하는지 AI가 조작하는지 구분이 없음(둘 다 `fighter.move()`, `fighter.use_skill_1()` 등 같은 공용 메서드만 호출)
  - `skill_2`가 투사체 스킬(`projectile_scene` 프로퍼티를 가짐 — 예: BBGunSkill)이면 원거리 캐릭터로 판단해서 `ranged_distance`(기본 180px)를 유지하며 견제. 캐릭터마다 분기하지 않고 스킬 구성만 보고 판단하는 방식이라 새 캐릭터가 원거리 스킬을 skill_2에 넣기만 하면 자동으로 이 행동을 함
  - 쓸 수 있는 스킬이 하나도 없을 때(`_all_skills_on_cooldown`) 가끔 확률적으로 한 발짝 물러나서 쿨타임을 버는 "후퇴" 상태가 있음. 바닥에 있을 때 낮은 확률로 그냥 점프도 함(움직임이 자연스러워 보이도록)
  - **주의(실제로 겪은 버그):** 뒤로 빠지거나 거리를 벌릴 때 `fighter.move(-dir)`을 쓰는데, `Fighter.move()`는 이동 방향으로 `facing`도 같이 바꾼다 — 그래서 후퇴 중엔 상대를 등지게 되고, 그 상태에서 투사체 스킬을 쓰면 반대 방향으로 나가버려 절대 안 맞는 버그가 있었다. 후퇴 이동을 시킨 직후 `fighter.facing`을 상대 쪽으로 다시 강제해서 고침
  - **알려진 한계(TODO):** 주정뱅이 스킬2(`BloodCannonSkill`, 혈사포)는 `projectile_scene`이 없는 판정형 스킬이라 위 `_is_ranged` 판정에 안 걸려서 AI가 근접 캐릭터처럼 바짝 붙어서 싸운다 — 판정 범위 자체가 넓어서(480px) 웬만하면 맞긴 하지만, 원거리 캐릭터처럼 거리를 벌리며 쓰는 견제 플레이는 안 함
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

- 몸/손/발 스프라이트는 캐릭터 공용이고, `Head`의 텍스처만 갈아끼우면 다른 캐릭터를 만들 수 있다
- **캐릭터별 머리는 씬 상속으로 만든다.** `BodyRig.tscn`을 상속한 씬을 캐릭터 폴더에 두고 `Head`의 텍스처/위치/크기만 덮어쓴다(예: `characters/akpeulleo/AkpeulleoRig.tscn`). 이러면 몸/손/발 위치를 `BodyRig.tscn`에서 한 번만 고쳐도 전 캐릭터에 반영되고, 에디터에서 미리보기도 제대로 된다. 현재 주정뱅이(BodyRig 자체가 주정뱅이 머리를 들고 있음)·악플러·예수천국 세 명 적용됨. 예수천국의 `Yeegy.png`는 머리와 몸이 하나로 그려진 흉상이라, `Head`에 통째로 넣고 공용 `Body`는 `visible = false`로 숨긴다(손·발은 그대로 씀)
- 조각 위치는 **에디터에서 `BodyRig.tscn`을 직접 열어** 옮긴다. 캐릭터 씬 쪽에서 `Visual`을 펼쳐 만지면 그 캐릭터만의 덮어쓰기가 생기니 주의
- `characters/BodyRig.gd`: 애니메이션 파일 없이 **코드로 걷기 동작**을 만든다. 부모 Fighter의 속도를 보고 **왼발 한 걸음 → 오른발 한 걸음**을 번갈아 재생하고(걷는 쪽 발만 `foot_swing_deg`만큼 기울었다 돌아오고, 반대쪽 발은 제자리에 붙어 있는다), 한 걸음마다 몸/머리/손을 위로 살짝 들썩이게 한다(`body_bob`). 두 발을 서로 반대로 회전시키는 방식은 어색하다는 피드백을 받아 폐기함. 왼쪽으로 갈 때는 리그 전체의 `scale.x` 부호를 뒤집어 좌우 반전한다(크기는 안 건드리고 부호만 — 궁극기 연출이 `Visual.scale`을 만지기 때문). 각 조각의 제자리 값은 `_ready()`에서 씬에 저장된 위치를 그대로 기억하므로, **에디터에서 위치를 옮겨도 애니메이션 코드는 고칠 필요가 없다**
- 공중에 떠 있는 동안(`is_on_floor()`가 false) 두 발이 함께 `jump_foot_deg`(60도)만큼 들리고, 착지하면 원래 각도로 돌아온다
- 흔들림 세기·걸음 빠르기는 전부 `@export`라 인스펙터에서 조절 가능: `foot_swing_deg`(22도) / `foot_stride`(3px) / `body_bob`(2px) / `step_speed`(9) / `blend_speed`(8) / `jump_foot_deg`(60도) / `jump_blend_speed`(12)
- **아직 안 된 것:** 공격 모션

## 훈련장 (값 조정용)

`maps/TrainingGround.tscn` — 평평한 바닥 하나에 캐릭터 하나만 세워두고 **중력·점프력·이동속도를 슬라이더로 실시간으로 바꿔보는 방**. 아직 이 수치들이 확정되지 않아서 만든 개발용 화면이다.

- 배경에 가로 100px / 세로 50px 눈금선을 그려서 이동 거리와 점프 높이를 눈으로 잴 수 있다(500px마다 진한 선)
- 점프할 때마다 **최고 높이 / 체공 시간 / 수평 이동 거리**를 자동으로 재서 패널에 표시한다 (기본값 중력 900·점프력 -350 기준: 약 65px, 0.78초)
- 조절 패널은 게임 UI가 아니라 개발 도구라서 `.tscn`에 배치하지 않고 `TrainingGround.gd`에서 코드로 만든다
- **중요:** 이 화면에서 값을 바꾸려고 `Fighter.GRAVITY`/`JUMP_VELOCITY` 상수를 `static var Fighter.gravity`/`Fighter.jump_velocity`로 바꿨다. 모든 Fighter가 공유하는 값이고, 훈련장에서 바꾼 값은 **게임을 끌 때까지 유지**돼서 그대로 로컬 대전에 들어가 시험해볼 수 있다. 값이 마음에 들면 `Fighter.gd`의 `DEFAULT_GRAVITY`/`DEFAULT_JUMP_VELOCITY`에 옮겨 적어야 영구 반영된다
- 이동속도는 캐릭터별 스탯(`stats/*.tres`의 `move_speed`)이라 훈련장에서는 배수(`move_speed_multiplier`)로만 조절한다 — 확정되면 각 `.tres`를 고칠 것

## 게임 플로우 / 씬 전환

`GameState.gd`(프로젝트 루트, 오토로드 싱글턴)가 화면 사이에서 선택값을 들고 다닙니다.

**로컬 대전(PvP) 흐름:** `ui/MainMenu.tscn`(시작) → `ui/ModeSelect.tscn`("로컬 대전" 선택) → `ui/RoomSettings.tscn`(선취 라운드 수 1~40, 시간제한 무제한/1~5분 설정 → `GameState.rounds_to_win`/`time_limit_seconds`) → `ui/CharacterSelect.tscn`(P1→P2 순서로 캐릭터 선택, `GameState.p1_character_path`/`p2_character_path`에 저장) → `ui/MapSelect.tscn`(맵 선택 시 바로 그 맵 씬으로 전환) → 선택한 맵(`Stage.gd` 상속).

**스토리 모드 흐름:** `ui/MainMenu.tscn` → `ui/ModeSelect.tscn`("스토리 모드" 선택 — `rounds_to_win=2`, `time_limit_seconds=120` 고정, `story_index=0`으로 초기화) → `ui/CharacterSelect.tscn`(로컬 대전과 같은 화면을 공유 — `GameState.game_mode == "story"`면 P2 미리보기 칸에 `GameState.STORY_OPPONENTS[story_index]` 상대가 미리 공개되어 있고, P1만 고르면 바로 확정되어 맵 선택 화면 없이 `GameState.STORY_MAP_PATH`로 직행) → 맵(`Stage.gd`) → (P1 승리 시) `ui/ReformCutscene.tscn`(방금 이긴 빌런 전용 반성 대사 표시, "개과천선" — 캐릭터별 대사는 `ReformCutscene.REFORM_LINES` 딕셔너리) → 다음 상대로 자동 진행, 전원 격파 시 `ui/StoryClear.tscn`. P1이 지면 스토리 진행 없이 일반 결과 화면(다시하기/메인 메뉴로)만 뜬다

**훈련장 흐름:** `ui/MainMenu.tscn` → `ui/ModeSelect.tscn`("훈련장" 선택) → `maps/TrainingGround.tscn`. 캐릭터 선택·맵 선택 화면을 거치지 않고 바로 들어가고, 캐릭터는 훈련장 안의 드롭다운으로 바꾼다(바꾸면 그 자리에서 다시 스폰). 상대·라운드·시간제한·HUD가 없어서 `Stage.gd`를 상속하지 않는 독립 씬이다

- 캐릭터·맵 후보 목록은 `GameState.CHARACTERS`/`GameState.MAPS` 딕셔너리 하나로 관리 — 캐릭터나 맵을 추가하면 이 딕셔너리에 한 줄만 추가하면 선택 화면에 자동으로 나타남
- 모든 화면에 ESC(`ui_cancel`)로 한 단계 뒤로 나가는 탈출구가 있음: 모드 선택→메인 메뉴, 방 설정→모드 선택, 캐릭터 선택→방 설정, 맵 선택→캐릭터 선택, 스토리 인트로→모드 선택, 대전 중→메인 메뉴. 버튼으로도 동일하게 나갈 수 있음
- **라운드제:** `Stage._process()`가 KO(HP 0) 또는 시간 초과(`GameState.time_limit_seconds`>0이고 다 됐을 때 — 그 순간 HP 높은 쪽이 라운드 승, 동률이면 무승부)를 감지하면 `_end_round(p1_won, is_draw)`를 부른다. 라운드 승수는 `GameState.p1_round_wins`/`p2_round_wins`에 누적되고, 둘 중 하나가 `rounds_to_win`에 도달하지 못했으면 `MatchResult.show_round_result()`로 점수 배너만 잠깐 보여준 뒤 `get_tree().reload_current_scene()`으로 같은 맵에서 다음 라운드를 새로 시작한다(HP/위치는 씬 리로드로 초기화되고, 라운드 승수는 `GameState`가 오토로드라 그대로 유지됨). 도달했으면 최종 결과(`MatchResult.show_result()`/`show_draw()`) 또는 스토리 모드 승리 시 `ReformCutscene`으로 분기
- `CombatHUD`의 `RoundLabel`이 화면 중앙 상단에 라운드 점수(`P1승 : P2승`)와(시간제한이 있으면) 남은 초를 표시. `Stage`가 `combat_hud.update_round_info(p1_wins, p2_wins, time_left)`로 매 프레임 갱신
- `maps/Stage.gd`는 이제 캐릭터를 씬에 미리 박아두지 않고, `_ready()`에서 `GameState`가 가리키는 캐릭터 씬을 `PlayerSpawn1`/`PlayerSpawn2`에 동적으로 생성하고 P1에는 `PlayerController`, P2에는 `AIController`를 자동으로 붙인다. 새 맵은 바닥·벽(or 링아웃용 빈 공간)·`PlayerSpawn1`/`PlayerSpawn2`·`Camera2D`(스크립트: `maps/CameraRig.gd`)·`CombatHUD` 인스턴스만 배치하면 나머지는 `Stage.gd`가 처리
- 승패: `Stage._process()`가 매 프레임 양쪽 Fighter의 `current_hp`를 직접 확인해서 판정한다(HP 0 또는 `ring_out()`). **`died` 시그널에 바로 반응하지 않는 이유:** 시그널에 반응하면 같은 프레임에 양쪽이 동시에 쓰러져도 먼저 처리된 시그널 쪽이 임의로 승자가 되는 버그가 있었음 — 지금은 그 프레임의 데미지가 전부 반영된 뒤 한 번에 판정해서 양쪽 다 0이면 무승부(`MatchResult.show_draw()`)로 처리. 링아웃은 `Stage.ring_out_y`보다 아래로 떨어지면 발동 — 벽이 있는 맵(편의점 앞/PC방/아파트 단지 놀이터)은 사실상 발동 안 되고, 벽이 없는 학교 옥상·지하철 승강장에서만 의미가 있음
- 히트 이펙트: 맞으면 `Fighter._flash_hit()`가 캐릭터를 잠깐 빨갛게 물들이고, `combat/Hitbox.gd`가 실제로 맞았을 때 `combat/HitSpark.tscn`을 스폰
- 상태별 색조는 `Fighter.set_tint(id, color, duration)`/`clear_tint(id)`로 건다. 여러 개가 동시에 걸려도(가드+화상+스탠스 등) 서로 안 지우고 스택처럼 쌓였다가, 하나가 풀리면 그 밑에 깔려있던 색으로 돌아간다(전부 없으면 원래 색) — `set_modifier`/`clear_modifier`와 같은 발상. 스킬 13종 전부 이 방식으로 캐릭터별 이펙트가 붙어있음: 잼민이 돌진 잔상(`DashSkill`)·BB탄 총구 섬광(`BBGunSkill`)·궁극기 초록 반짝임(`HealSkill`), 악플러 도발 대상 노란빛(`TauntSkill`)·열등감 붉은 오라(`RageBuffSkill`)·궁극기 어두운 디버프(`WeakenAuraUltimate`), 주정뱅이 취기 버프 붉은빛(`DrunkenRageSkill`)·혈사포 차지 경고빛과 빔(`BloodCannonSkill`, 초록색 — 스킬1 사용 횟수만큼 길어지고 최대 900px에서 클램프, 쏘면 스택 초기화)·궁극기 보라 디버프(`JumpDebuffUltimate`), 예수천국 화상 주황빛(`IgniteSkill`)·불판 펄스(`FirePlate`)·가드 파란빛(`GuardSkill`)·스탠스 흰/빨강(`StanceSwitcher`)
- 넉백: `MeleeAttack`/`CounterSlamSkill`/`Projectile`이 각자 `Hitbox.knockback`을 설정해서 맞은 캐릭터의 `velocity`에 즉시 더한다(`Fighter.take_damage`). 바운스어택류 콤보의 기반 — 아직 스킬 하나하나에 맞는 세밀한 값 조정은 안 되어 있음(전부 임시값)
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
  characters/     # Fighter.gd(공용 베이스) + 캐릭터별 씬 (jaemini/, akpeulleo/, jujeongbaengi/, yesucheonguk/, catmom/, subwayvillain/, floornoise/ — 7종)
  skills/         # Skill.gd(공용 베이스) + 실제 스킬 컴포넌트, 투사체
  combat/         # Hitbox/Hurtbox/HitSpark (전투 판정 + 히트 이펙트)
  controllers/    # PlayerController / AIController
  stats/          # CharacterStats 리소스(.tres)
  maps/           # Stage.gd(공용 베이스) + CameraRig.gd + 스테이지 씬 9종
  ui/             # MainMenu/ModeSelect/RoomSettings/CharacterSelect/MapSelect/Settings/ReformCutscene/StoryClear/MatchResult, HP바·쿨타임 HUD
```

## 참고

- 기획 오픈 이슈(히트스턴 예외, 승리 조건 HP vs 링아웃 등)는 아티팩트 문서의 "다음에 정할 것" 표를 확인. 확정 전까지는 구현 시 임시값으로 처리하고 주석/TODO로 표시
- Godot 실행 파일: `C:\Users\kint4\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`. 헤드리스로 씬을 실행해서 런타임 에러를 확인할 수 있음 — 예: `<위 경로> --headless --path "C:/workspace/villain" "res://maps/ConvenienceStore.tscn" --quit-after 120`. 코드를 수정한 뒤에는 이렇게 실행해서 에러 콘솔이 깨끗한지 확인하고 보고할 것
- **주의:** 새 `class_name` 스크립트를 추가한 직후에는 먼저 `<위 경로> --headless --path "C:/workspace/villain" --editor --quit-after 5`로 한 번 실행해서 전역 클래스 캐시를 갱신해야 함. 안 그러면 방금 만든 클래스를 참조하는 다른 스크립트가 "Could not find type" 에러로 로드 실패함
- 자동 입력 시뮬레이션이 필요한 테스트는 `extends SceneTree` + `--script` 방식이 아니라, `extends Node` 스크립트를 임시 `.tscn`으로 감싸서 `--headless --path ... <임시 씬> --quit-after N`로 실행할 것 — `--script` 모드는 오토로드(`GameState` 등)가 초기화되지 않아 컴파일 에러가 남
- **주의:** 헤드리스 모드는 프레임 제한이 없어서 60fps보다 훨씬 빠르게 돈다(실측 약 145fps). 쿨타임·버프 지속시간처럼 시간 기반 로직을 테스트할 때 `--quit-after N`의 N을 "60fps 기준 초"로 계산하면 실제로는 그보다 훨씬 짧은 시간만 흐른다 — 프레임 수 대신 `Time.get_ticks_msec()`로 실제 경과 시간을 재면서 대기하거나, `--fixed-fps 60`을 같이 붙여서 프레임당 델타를 고정시킬 것
