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

- `characters/Fighter.gd`: 모든 캐릭터의 공용 베이스(`CharacterBody2D`). 이동/점프/중력, HP(`take_damage`/`heal`/`health_changed` 시그널), 스킬 슬롯(`skill_1`/`skill_2`/`skill_ultimate`/`basic_attack` — 자식 노드 이름 `Skill1`/`Skill2`/`SkillUltimate`/`BasicAttack`으로 자동 연결됨), 임시 버프·디버프(`move_speed_multiplier` 등 배수 필드 + `apply_temp_multiplier()`), 자유 형식 데이터 저장소 `custom_data`(예: 주정뱅이 술 스택)를 담당
- `skills/Skill.gd`: 모든 스킬의 공용 베이스(`Node`). 쿨타임 카운트다운과 `can_use()`/`use(fighter)`를 여기서 한 번만 구현. 새 스킬은 이 클래스를 상속해서 `_execute(fighter)`만 오버라이드
- `combat/Hitbox.gd` / `combat/Hurtbox.gd`: 실제 데미지 판정. `Hurtbox`는 Fighter의 자식 Area2D로 피격을 받아 `take_damage()`를 부르고, `Hitbox`는 공격 판정 Area2D로 `Hurtbox`와 겹치면 데미지를 준다 (자기 자신은 무시)
- `skills/MeleeAttack.gd`: 기본공격 공용 스킬 — 캐릭터 앞에 히트박스를 잠깐 켰다 끈다. `damage`/`range`만 캐릭터마다 다르게 지정해서 재사용 (사탕찌르기, 키보드 휘두르기, 술병깨기, 팻말 때리기 전부 이걸 씀)
- 이동을 잠깐 가로채는 스킬(돌진 등)은 `Fighter.movement_override`에 자기 자신을 등록하고 `get_move_velocity_x()`/`after_physics(fighter, delta)`를 구현 (`skills/DashSkill.gd` 참고)
- 궁극기가 없는 캐릭터(예수천국 불신지옥)는 `SkillUltimate` 자리에 `skills/StanceSwitcher.gd`를 넣어서 숫자키 3으로 스탠스(천사/악마)를 전환하고, `skill_1`/`skill_2`가 가리키는 실제 스킬을 바꿔치기하는 방식으로 구현

## 조작 / AI

- `controllers/PlayerController.gd`: 방향키 이동/점프, 스킬 입력을 읽어서 부모 Fighter를 조작
- `controllers/AIController.gd`: 목표 Fighter와의 거리를 보고 접근/기본공격/스킬 사용을 스스로 결정하는 단순 AI. Fighter 입장에서 플레이어가 조작하는지 AI가 조작하는지 구분이 없음(둘 다 `fighter.move()`, `fighter.use_skill_1()` 등 같은 공용 메서드만 호출) — 새 대전 씬을 만들 때 캐릭터 인스턴스 밑에 둘 중 하나를 자식으로 붙이면 됨
- 기본공격은 **Z키**(`basic_attack` 액션), 스킬1/스킬2/궁극기는 숫자키 **1/2/3**(`skill_1`/`skill_2`/`skill_3`) — `project.godot`의 InputMap에 등록되어 있음. 이동/점프 키와 2P 입력 방식은 아직 미정 — 현재는 Godot 기본 UI 액션(방향키 이동, ui_up 점프)으로 임시 대응 중

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
  characters/     # Fighter.gd(공용 베이스) + 캐릭터별 씬 (akpeulleo/, jujeongbaengi/, jaemini/, yesucheonguk/)
  skills/         # Skill.gd(공용 베이스) + 실제 스킬 컴포넌트, 투사체
  combat/         # Hitbox/Hurtbox (전투 판정)
  controllers/    # PlayerController / AIController
  stats/          # CharacterStats 리소스(.tres)
  maps/           # 스테이지 씬
  ui/             # HP바·쿨타임 등 UI
```

## 참고

- 기획 오픈 이슈(히트스턴 예외, 승리 조건 HP vs 링아웃 등)는 아티팩트 문서의 "다음에 정할 것" 표를 확인. 확정 전까지는 구현 시 임시값으로 처리하고 주석/TODO로 표시
