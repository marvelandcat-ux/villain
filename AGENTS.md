# 트러블 메이커 (villain) — Godot 프로젝트 규칙

사이드뷰 대전 격투 **"트러블 메이커"**(폴더 `villain`, 빌드 `build/TroubleMaker/`). 기획: https://Codex.ai/code/artifact/661e48af-d8db-49c9-bc68-a9294790becb
전역 규칙(한국어, 초보자 눈높이, 안전) 유지. 코드 스타일은 이 문서 우선 — **Godot 4.7.2 / GDScript**(Unity/C# 규칙 아님).

> 2026-10-04 크게 압축: **규칙·함정·같이 고쳐야 하는 짝만** 남김. 기능 설명·수치는 코드를 볼 것(옛 내용은 git 이력).

## 핵심 아키텍처

- **캐릭터 전용 `.gd` 금지** — 모든 캐릭터 루트는 `characters/Fighter.gd`, 차이는 스탯 `.tres` + 스킬 노드(`BasicAttack`/`Skill1`/`Skill2`/`SkillUltimate`). 빈 `skills/Skill.gd` = 의도된 미구현
- **버프·디버프 직접 대입 금지** → `set_modifier`/`clear_modifier`(id별 곱), 임시 `apply_temp_multiplier`. 색조도 `set_tint`/`clear_tint`. `damage_reduction`은 `set_modifier`로 쓰지 말 것(`damage_taken_multiplier` 사용)
- **공용 헬퍼 — 다시 짜지 말 것:** `PhysicsQuery.raycast_ignoring_fighters`/`ground_y_below`, `Timers.after`(`real_time`)/`self_destruct`, `Fighter.find_fighter_in_box`, `CrashBurst.spawn`(설정은 add_child 전)
- 스킬: `Skill` 상속 후 `_execute(fighter)`만. `_ready()` 오버라이드 시 `super()`. **쿨은 전부 `effective_cooldown()` 경유**. 스킬2 교체 `swap_skill_2()`, 궁 봉인 `seal_ultimate(id)`. 궁 쿨은 컷인 뒤 `fire_ultimate_now()`부터
- 라운드마다 `reload_current_scene()`(승수만 `GameState`)
- **⚠️ 스킬에서 `Visual.scale` 트윈 금지 → `BodyRig.play_squash()`**
- Hitbox/Hurtbox: `source_fighter` 유무는 `_has_source`로(주인 없는 열차 판정도 동작해야 함 — `is_instance_valid`만으로 막지 말 것). `take_hit()`을 직접 부르는 새 노드도 `_has_source` 검사. `Hurtbox.fighter`는 `Node` → `as Fighter`. HP 오브젝트는 `take_damage`/`take_map_damage`/`is_guarding`만 있으면 됨
- **허트박스는 머리 꼭대기까지**(`HurtboxCollision`, 발끝 +30) — **머리 그림을 바꾸면 다시 잴 것**
- **맵 피해는 `take_map_damage()` 한 곳으로**. `ignore_guard`를 밖에서 true로 주지 말 것
- ⚠️ `take_damage`는 넉백을 속도에 **더한다** → 정확한 속도는 받은 뒤 `velocity` 덮어쓰기
- 이동 가로채기 `movement_override`(+`get_move_velocity_x`/`after_physics`/`blocks_jump`), 대시 가로채기 `dash_override`
- 잡기: `can_be_grabbed()` → **`cancel_finisher_flight()` 먼저** → `is_grabbed`로 위치 직접 이동
- **슈퍼아머는 개수로 셈 — add/remove 짝 필수**. `blocks_debuff()`에 섞지 말 것
- 캐릭터끼리 몸 충돌 없음(양방향 `add_collision_exception_with`, 레이어는 안 건드림). **소환물·설치물도 z 0 + 같은 방식**(음수 z면 맵 그림 뒤로 숨음)

### 함정 (실제로 겪음)

- 람다로 노드 건드리는 `create_timer().timeout.connect` → 노드가 먼저 사라지면 에러. **`Timers.after`(노드 자식 Timer)로**
- `Skill`은 `Node`라 좌표 없음 → 자식 Hitbox는 직접 `global_position` 지정
- **`add_child()`는 `_ready()`를 즉시 실행** → 값은 add_child 전에 넣을 것
- 해제된 객체는 `== null`이 true → 주인 유무는 불리언으로
- **`_draw()`에서 0이 될 수 있는 모양은 `draw_primitive`**(`draw_colored_polygon`은 triangulation 에러)
- 안 보이면 **Output 패널 파싱 에러 → 지워진 파일을 가리키는 `ext_resource`** 순으로
- 새 `class_name`을 바로 타입으로 쓰면 파싱 에러 → 무타입 + `preload`
- Area2D 기믹 변수명 금지: `gravity`·`priority`·`monitoring`·`linear_damp`·`angular_damp`
- `.tscn`: `[connection]`은 맨 뒤, 손으로 끼운 노드는 부모 속성 줄 다음. CollisionShape2D는 바디의 **직계 자식**만
- 첫 프레임 delta 튐 → `minf(delta, 0.05)`
- 전체 화면 Control은 `mouse_filter = 2`. `set_input_as_handled()`는 씬 전환·`queue_free()` **전에**
- `duplicate()`는 신호까지 복사 → 판정 복제는 `DUPLICATE_SCRIPTS | DUPLICATE_GROUPS`. **잔상은 복제 후 스크립트를 뗄 것**
- 명중 콜백 안에서 판정 모양 변경은 `set_deferred`
- 셰이더: **`COLOR` 덮어쓸 땐 원래 `COLOR`를 곱할 것**. CanvasGroup 어둡게는 `self_modulate`. Polygon2D는 `vertex_colors`가 있으면 `color` 무시
- 이펙트(먼지·바람·자국)는 **맵에 붙일 것**(캐릭터 자식이면 반전에 뒤집힘). 피격 움찔은 그림만(물리로 띄우면 확정 콤보 깨짐)
- 무언가 사라지면 `git stash list`부터(GitHub Desktop이 치운 적 있음)
- PowerShell 변수는 대소문자 무시. Bash heredoc 속 python의 `\` 줄끝 주의

## 전투

- **📌 평타는 무조건 금쪽이 기준**(30x30 상자, range 40, 파고들기·푸시백 값 공통) — 캐릭터마다 바꾸지 말 것. **📌 3타 준비시간 0.223초 고정**
- `attack_duration`을 바꾸면 `windup`(= x0.4)도. 회전·발차기 타는 리그 `spin_duration`/`kick_duration`을 `finisher_windup`과 같이
- 확정 콤보: **넉백을 키우면 파고들기(`combo_lunge`)도 같이**
- 회전 타격: 루트 `scale.x` 변경은 다음 프레임 `_apply_pose` 첫머리에서 되돌리기, 최소 0.04
- 3타 날아가기 `launch_finisher()`: `FINISHER_*`는 배율 1 기준, `finisher_distance_scale`은 속도 배수(거리 ≈ 제곱). 벽 튕김 속도는 `move_and_slide()` **전에** 기억
- 클래시 `SkillClashManager`: 스킬1·2·궁만. 테스트에서 스킬은 클래시 대기창 뒤에 나감
- 점프·중력은 **static var**(영구는 `DEFAULT_*`). **점프·중력을 바꾸면 맵 발판 높이(놀이터·지하철 의자·공사현장·헬스장) 재확인**
- 착지 즉시 튕기는 기믹은 `cancel_landing_lag()` 필수
- 방어: 디버프 차단은 `blocks_debuff(from_ultimate)` 한 곳(궁만 관통). 막힘 판정은 `Hitbox._try_hit()`에서 한 번만. 가드/대시 off는 `can_guard()`/`can_dash()` 맨 앞
- **발판 내려가기**: 레이어 끄지 말고 발판에 collision exception(바디 전체에 걸림 → 한 바디에 막힘 충돌 섞지 말 것). 올라갈 발판은 `one_way_collision`
- 히트스톱은 꺼져 있음. 켜면 복귀 타이머 `ignore_time_scale = true`. `Engine.time_scale` 바꾼 스킬은 `_exit_tree`에서 복구

## 캐릭터

로스터 `GameState.CHARACTERS` + **`CHARACTER_RIGS` 둘 다**. 훈련장 전용 `TRAINING_ONLY_CHARACTERS`(주인공), 숨김 `HIDDEN_CHARACTERS`. 새 캐릭터 크기 기준 = 악플러 머리(상한 55x55). **새 스킬은 `AIController._want_skill()`에 한 줄**(또는 스킬에 `ai_wants_use`).

> **캐릭터별·맵별·UI 자세한 메모는 `.Codex/rules/*.md`** — 그 파일들을 건드릴 때 자동으로 읽힌다(`paths:`). 새 캐릭터를 만들면 규칙 파일도 하나 추가하고, 스킬 파일 경로를 `paths:`에 넣을 것.

- 오타 파일명은 **그대로 둘 것**(이름을 고치면 참조가 깨짐)

## 몸(BodyRig) — `characters/BodyRig.tscn`/`.gd`

- 캐릭터 씬의 `Visual`(이름 고정). 왼쪽 = `scale.x` 부호만. 캐릭터별 머리는 씬 상속, 조각 위치는 `BodyRig.tscn`을 직접
- **새 리그 배율 눈대중 금지** — 실제 영역 재서 역산(position = 목표중심 - (bbox중심 - 캔버스중심) x 배율). 영역은 `_opaque_rect_of()`(`get_used_rect()`는 알파 1짜리 점에도 늘어남)
- 손 무기는 `HandRHold` 자식(배율 1). `HandR`·`HandRHold`는 형제라 `modulate` 둘 다. `attack_hold_deg` 각도 고정은 되돌린 것 — 건드리지 말 것
- 자세는 `_xxx_target`/`_xxx_blend` + `set_xxx()` + `_pose_xxx()`. **로컬 좌표 자세엔 facing 부호 곱하지 말 것**. 새 자세는 `_face_turn_blocked()`·대치 조건에도
- 머리 돌리기 앵커 = **머리 공의 중심x·y·지름**(알파 1/4 축소 → 높이 22% 열림 연산 → 무게중심·`2sqrt(넓이/pi)`, 프로펠러·턱 제외)
- ⚠️ 머리/몸통 파일명이 비슷 — **덮어쓰기 전 내용 확인**
- 표정 우선순위: 피격 > 토하기/액션 > 취함 > 지침 > 맨정신. `_update_hp_face()`는 `take_damage`/`heal`/`ring_out` 세 곳

### 그림 파일 교체

- **파일은 Godot 파일시스템 창에서 옮길 것**(uid 깨짐). 원본이 `.ctex`에만 있으면 offset 56부터 WebP
- 에디터 밖에서 덮어썼으면 `.import` 삭제 후 `godot --headless --editor --path <프로젝트> --quit`
- 배율은 보이는 영역 x scale이 예전과 같게(`centered`면 position 보정). 경로 바꾸면 낡은 `uid=`도
- 흰 배경 제거는 테두리 flood fill(파츠는 알파 PNG로 요청). 구석 얼룩·가장자리 흰 줄 확인
- 배경이 지글거리면 `.import` `mipmaps/generate=true` + 씬 루트 `texture_filter = 4`

## 조작 / AI

- P1: A/D·W 점프·S 아래·F 평타·G/H 스킬·R 궁·E 맵 스킬 / P2: ←→·↑·↓·L·;·'·]·[. 대시 = 이동키 두 번, 발판 내려가기 = 아래키 두 번(원웨이 발판 위에서만), **방어 = 평타+스킬1 동시**(`GUARD_CHORD_WINDOW` 0.06초 동안 짝을 기다려서 혼자 누른 평타·스킬1은 그만큼 늦게 나감). ⚠️ **기본 배치를 바꾸면 `GameState.KEYBIND_VERSION` 올릴 것**
- ⚠️ `move()`/`dash()`가 `facing`도 바꿈 → 후퇴 직후 되돌릴 것
- AI 발판 길찾기 그룹: `"ai_jump_over"`, `"ai_danger_zone"` → `"ai_safe_spot"`. 기믹 위험 판정은 `can_process()`인 것만

## 맵 / UI

- 새 맵 필수: 바닥·벽(또는 링아웃)·`PlayerSpawn1/2`·`Camera2D`(`CameraRig.gd`)·`CombatHUD`, 목록 `GameState.MAPS`. **`Deco*` 노드는 맵 선택 미리보기 제외**. 맵 스킬은 클래시 안 탐
- `Fade`는 씬의 **맨 마지막 자식**. 기준 해상도 1280x720
- 폰트 주아체는 ⚠️ **기호 글리프가 거의 없음**(`◀ ▶ ● ○ · × ↑ ↓` → 코드로 그릴 것)

## 코드 스타일

- 클래스·파일 PascalCase(파일명 = class_name), 함수·변수 snake_case, 상수 ALL_CAPS, 시그널 과거형, private `_` 접두사
- 순서: `class_name`·`extends` → `@export` → 멤버 → 생명주기 → 커스텀. 씬과 스크립트는 같은 폴더
- 주석은 한국어, public 위 `##` 한 줄 + 복잡한 로직에만
- 폴더: `characters/`(Fighter·BodyRig·캐릭터별) `skills/` `combat/` `controllers/` `stats/` `maps/` `ui/` `tools/`

## 참고

- 기획 미정은 임시값 + TODO
- `invalid UID` 경고 → 씬 uid를 `.import`의 uid로
- **코드 수정 후 헤드리스 확인 안 함(사용자 요청)** — "실행해서 확인해줘"일 때만
- Godot 실행 파일: `Godot*4.7*win64*console*.exe` 검색
- 헤드리스 테스트: 쓰이는 씬을 띄울 것(`--quit-after`만으론 파싱 에러 못 잡음). `extends SceneTree --script` 금지 → `extends Node` 임시 `.tscn`. 시간 기반은 `--fixed-fps 60`. `apply_physics()` 중복 호출 금지, 순간이동 직후 착지 랙 대기
