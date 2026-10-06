# 트러블 메이커 (villain) — Godot 프로젝트 규칙

사이드뷰 대전 격투 **"트러블 메이커"**(폴더 `villain`, 빌드 `build/TroubleMaker/`). 기획: https://claude.ai/code/artifact/661e48af-d8db-49c9-bc68-a9294790becb
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

> **캐릭터별·맵별·UI 자세한 메모는 `.claude/rules/*.md`** — 그 파일들을 건드릴 때 자동으로 읽힌다(`paths:`). 새 캐릭터를 만들면 규칙 파일도 하나 추가하고, 스킬 파일 경로를 `paths:`에 넣을 것.

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

- P1: A/D·W 점프·S 방어·F 평타·G/H 스킬·R 궁·E 맵 스킬 / P2: ←→·↑·↓·L·;·'·]·[. 대시 = 이동키 두 번, 발판 내려가기 = 아래+점프. ⚠️ **기본 배치를 바꾸면 `GameState.KEYBIND_VERSION` 올릴 것**
- ⚠️ `move()`/`dash()`가 `facing`도 바꿈 → 후퇴 직후 되돌릴 것
- AI 발판 길찾기 그룹: `"ai_jump_over"`, `"ai_danger_zone"` → `"ai_safe_spot"`. 기믹 위험 판정은 `can_process()`인 것만

## 맵 / UI

- 새 맵 필수: 바닥·벽(또는 링아웃)·`PlayerSpawn1/2`·`Camera2D`(`CameraRig.gd`)·`CombatHUD`, 목록 `GameState.MAPS`. **`Deco*` 노드는 맵 선택 미리보기 제외**. 맵 스킬은 클래시 안 탐
- `Fade`는 씬의 **맨 마지막 자식**. 기준 해상도 1280x720
- 폰트 주아체는 ⚠️ **기호 글리프가 거의 없음**(`◀ ▶ ● ○ · × ↑ ↓` → 코드로 그릴 것)

## 코드 스타일

- ⚠️ **빌더 `tools/build_playground.py`는 지금 돌리면 안 된다**(씬을 손으로 고침). 돌린다면 백업 + 손수정 값을 `PLATFORM_OVERRIDES`·`CROWN_POS`로 옮긴 뒤
- 바닥 y=280, 벽 ±960, 스프링 좌석 y=226, 지붕 y=-82, 중간 구름 y≈-228, 꼭대기 y=-418, 왕관(25, -472). 카메라 `min_y` -300(구름을 올리면 같이). **모든 발판은 원웨이**
- ⚠️ TODO: 점프력 변경 뒤 재실측 안 됨 — 중간→꼭대기 여유 ~3px
- 미끄럼틀 `PavilionLeft/Right`: **왼쪽만 판정**, 바디 넷(한 바디에 몰지 말 것)
- 그네 `Swing.gd`: 튕김 + `apply_hitstun` 필수. 스프링 `SpringJumpPad.gd`: 직전 낙하 속도로 튕김 + `cancel_landing_lag()`
- 왕관 `Crown.gd`: 닿으면 왕(`Crown.is_king()`), 넉백 피해에 떨어뜨림. **승리 조건은 안 건드림**, `pickup_delay` 0 금지. 그림 `진짜왕관.png`는 맵과 `CrownCutIn.tscn` 두 곳
- 모래 `SandPit.gd`: 발치 높이에만 둔화. `모래사장.png`(괄호 없음)는 쓰지 말 것

### 지하철 승강장 `maps/SubwayPlatform.tscn`

- 선로 바닥 y=300, 벽 ±560, 의자 발판 y=155(원웨이). **의자 위 = 열차 피난처**(의자 높이·열차 크기는 같이 계산), 의자는 트리에서 열차보다 먼저
- 열차 `SubwayTrain.gd`: 1~5칸, 그림을 잘라 조립(`SEAM_FRONT`/`SEAM_BACK`/`MIDDLE_DRIFT` — **그림을 바꾸면 재측정**)
- 조명 `CanvasModulate` + 형광등. 빛나는 물체는 unshaded. **가산 색은 CanvasModulate가 곱해지므로 조명을 바꾸면 다시 잡을 것**
- 먼 층 `DecoBackground`(CanvasGroup + `far_blur`), 앞 기둥 `ForegroundPillars.gd`. 역 이름판을 옮기면 `SignBand`·`SignBandOutline`도

### 헬스장 `maps/Gym.tscn` — 운동할지 방해할지

- 2층 발판 + 기구 셋(바벨 컬 = 기본공격력 / 스쿼트 랙 = 점프력 / 런닝머신 = 이동속도). 맵 스킬 `WorkoutSkill`: 운동 중 발 묶임, 맞음·때림·멀어짐 등이면 끊김, 스펙은 쌓는 족족 배수(`custom_data["gym_spec"]`)
- 공격력은 기본공격에만(`compute_basic_damage()`). `GymLayout.gd`는 자식 `_ready()`가 부모보다 먼저라는 것에 기대 스폰을 옮김. `muscle_arm`/`muscle_leg`
- 땅 y=280, 2층 y=100(이단 점프 한계 180px), 벽 ±604. TODO: 기구 그림·배경

#### 운동 자세는 **캐릭터마다 따로** (2026-10-06)

운동 자세 아홉 장(컬 3 / 스쿼트 3 / 달리기 3)은 원래 `characters/gym/Gym*Pose.tscn` **한 벌을 전 캐릭터가 같이 썼다.**
`BodyRig._apply_pose_scene()`은 자세 씬에서 **자리와 각도만** 읽으므로(크기는 `rest_pose`만 읽는다),
같은 자리를 머리 큰 캐릭터에게 먹이면 원판이 얼굴을 덮는다. 그래서 캐릭터마다 한 벌씩 만들었다.

- 자리: `characters/<폴더>/gym/<이름>{Curl,Squat,Run}{칸}Pose.tscn` + 편집 씬 `<이름>{Curl,Squat,Run}Studio.tscn`
  - 열 명 x (자세 9 + 편집 씬 3) = **120개**. 리그마다 그 아홉 장이 `curl_down_pose`... 로 꽂혀 있다
  - 고치는 법: **편집 씬을 F6로 열면** 그 캐릭터가 운동한다 → `1/2/3`으로 한 장 크게 띄우고 → 끌어서 맞추고 → `S`로 그 자세 씬에 저장. 자세 씬을 F6로 열어도 짝인 편집 씬이 열린다(`PosePreview.alone_opens_scene`)
- **만드는 건 `tools/GymPoseGen.tscn`**(F6 또는 헤드리스로 실행). 공용 자세를 베껴 **그림만 그 캐릭터 것으로 갈아 끼운다**(자리·각도는 시작점으로 그대로 둔다)
  - ⚠️ **이미 있는 파일은 절대 안 덮어쓴다.** 캐릭터를 새로 넣고 다시 돌리면 **없는 것만** 생긴다 — 손으로 맞춰 둔 자세를 날리지 않으려고
  - ⚠️ 돌린 뒤 **리그 씬에 아홉 줄을 꽂는 건 따로 해야 한다**(`curl_down_pose = ExtResource(...)` ...). 생성기는 자세 파일만 만든다
  - `GameState.CHARACTER_RIGS`에 없는 리그는 생성기의 `EXTRA_RIGS`에 적는다(지금 주인공/경찰 하나)
- **실측: 리그들의 제자리는 거의 똑같다**(Body (1,1) / HandL (-27,4) / HandR (27,3) / FootL (-8,26) / FootR (14,27) / Head (-4~2,-32~-34)). 전부 `BodyRig.tscn`을 인스턴스해서 **그림과 배율만** 다르기 때문이다 — 그래서 캐릭터별로 손봐야 하는 건 "자리를 처음부터 다시"가 아니라 **그림 크기 차이만큼의 보정**이다
#### ⚠️ 장비(로켓·바퀴)를 낀 채 운동하면 **몸이 분리됐다** — 고침 (2026-10-06)

로켓을 신으면 머리·몸·손이 장비 단계 자리로 옮겨지고 거기에 **뜬 높이 16px**(`rocket_hover_height`)까지 더해진다.
그런데 운동 자세(`Gym*Pose.tscn`)에 적힌 자리는 **땅에 서 있을 때 기준**이라, 그냥 입히면
**자세에 적힌 조각만 땅으로 내려오고 자세에 없는 조각은 뜬 채로 남는다.**
컬은 머리를 `HeadView`(보기용)로 두고 `Head`를 안 건드려서 **머리만 16px 위에 떠 있었다**(실측: 머리 y -48 / 몸 y 3).

- 고친 법: `_gear_offset(part)`를 만들어 **자세를 장비 어긋남 위에 얹는다**(`_apply_pose_scene(..., gear_aware = true)`).
  장비 자리가 적힌 조각(머리·몸·손)은 그 어긋남을, 안 적힌 조각(발)은 **뜬 높이만** 쓴다 — 발까지 떠야 로켓이 따라온다(장비는 왼발 그림의 자식)
- ⚠️ `gear_aware`는 **컬·스쿼트에서만** 켠다. 방어·돌진 자세까지 켜면 엉뚱한 데서 떠오른다
- **장비 전용 자세 한 벌**도 둘 수 있다 — 리그의 `curl_*_pose_gear` / `squat_*_pose_gear`.
  **세 장이 다 채워져 있을 때만** 갈아탄다(한 장만 넣으면 섞여서 더 이상해진다). 비면 평소 자세를 쓴다
  - 편집 씬: `characters/<폴더>/gym/<이름>Rocket{Curl,Squat}Studio.tscn`. `GymCurlStudio.gd`의 `gear_stage`를
    `rocket`으로 두면 **로켓을 신고 떠 있는 채로** 자세를 고칠 수 있고, 저장도 `*_pose_gear` 칸으로 간다
  - **지금은 악플러만 뽑아 뒀다**(2026-10-06 사용자: "악플러로 기준 잡겠다"). 기준이 잡히면
    `tools/GymPoseGen.gd`의 `gear_characters`에 이름을 더해 다시 돌리면 나머지도 생긴다

#### 운동 얼굴 두 장 (2026-10-06)

운동 중 표정은 **힘줄 때 = 올라잇 / 그 외 = 힘든(입 벌린 것)** 두 장이다. 타이밍은 `BodyRig`가 정하므로
(`_curl_rising`이 바뀔 때 `_apply_base_head()`), **리그에 그림 두 장만 꽂으면 악플러와 똑같이 돈다.**

| 리그 export | 들어가는 얼굴 |
|---|---|
| `curl_face_rise` / `squat_face_move` | 올라잇 |
| `curl_face_fall` / `squat_face_rest` / `run_face` | 힘든(입 벌린 것) |

- 꽂은 캐릭터: 악플러·금쪽이·주정뱅이·지하철 아저씨·층간소음 빌런·일진
- **그림이 없어서 못 꽂은 캐릭터: 고양이 아주머니 · 황근출 해병 · 인베이전 · 주인공(경찰).** 그림이 나오면 리그에 두 줄만 더하면 된다
- 얼굴 그림이 평소 머리와 크기가 다르면 `curl_face_match_size`(기본 켬)가 **살색 높이**를 재서 맞춘다
- 바벨을 손 앞에 그릴지는 `curl_bar_in_front`(기본 끔 = 손이 봉 위). **금쪽이만 켜 뒀다**(2026-10-06 요청)

#### 변신 단계(핏줄·황금·바퀴·부스터) 편집 — **이미 캐릭터별이다**

`maps/workout/`의 편집 씬들은 처음부터 캐릭터별로 만들어져 있다. 루트의 **`character`** 를 바꾸면 그 캐릭터 몸으로 바뀌고,
조각을 끌어 놓는 순간 `.tres`에 **그 캐릭터·그 단계 자리로 바로 저장된다**(Ctrl+S 불필요).

| 씬 | 단계 | 저장되는 곳 |
|---|---|---|
| `Curl{Vein1,Vein3,Gold}Studio.tscn` | 핏줄 1·3스택 / 황금 손 | `CurlStage.tres` |
| `Squat{Vein1,Vein3,Gold}Studio.tscn` | 같은 것의 발 | `SquatStage.tres` |
| `Treadmill{Bike,Car,Rocket}Studio.tscn` | 자전거 바퀴 / 스포츠카 바퀴 / 로켓 신발 | `TreadmillGear.tres` |

- **장비 그림도 편집 씬에서 바꾼다**(2026-10-06): `GearL`에 새 그림을 끌어다 놓으면 `.tres`에 저장된다.
  예전엔 **로켓만** 저장돼서(`if stage == "rocket"`) 자전거·스포츠카 바퀴는 바꿔도 다시 열면 옛 그림으로 돌아갔다
  - ⚠️ **자전거·스포츠카 바퀴는 전 캐릭터가 같은 그림 한 장**(`bike_texture`/`car_texture`)이라 한 명한테서 바꾸면 모두 바뀐다.
    로켓 신발만 캐릭터별(`rocket_shoes` 사전)이다 — 자기 신발에 번개를 그린 그림이라서. 어느 쪽인지 **편집 씬 땅선 아래에 적어 둔다**
  - 로켓 신발 그림이 없는 캐릭터(층간소음 빌런·황근출 해병·인베이전·주인공)는 **맨발이 그대로 나온다** — 그림이 나오면 GearL에 끌어다 놓으면 된다
- **캐릭터마다 한 장씩도 뽑아 뒀다**(2026-10-06): `characters/<폴더>/gym/<이름>{Bike,Car,Rocket}Studio.tscn`.
  `character`가 그 캐릭터로 박혀 있을 뿐 원본과 같은 씬이라, **어느 쪽으로 열든 고친 자리는 같은 `.tres`의 그 캐릭터 칸**에 저장된다
  - 만드는 건 `tools/GymPoseGen.tscn`이 같이 한다. ⚠️ 뽑을 때 **프레임을 넘기면 안 된다** — 이 씬들은 `_process`에서
    "조각이 움직였나" 보고 `.tres`에 바로 저장하므로, 한 프레임이라도 돌면 기본값을 덮어써 버린다
  - 핏줄·황금 쪽(`Curl/Squat{Vein1,Vein3,Gold}Studio`)은 아직 원본 한 장뿐이다 — 필요하면 생성기의 `SOURCE_STAGES`에 줄만 더하면 된다
- `character`는 **고르는 목록**이다(`_validate_property`가 힌트를 넣어 준다). 목록은
  `RigReader.names()` = `GameState.CHARACTER_RIGS` + `RigReader.EXTRA_RIGS`(주인공/경찰) **한 곳**에서만 온다
  — 주인공(경찰)은 2026-10-06에 `EXTRA_RIGS`로 더했다(그 전엔 목록에서 빠져 있었다)

- ⚠️ 편집 씬에서 `S`로 저장할 때 `alone_opens_scene`을 **그 편집 씬 자신(`scene_file_path`)**으로 적는다. 예전엔 공용 `GymCurlStudio.tscn`으로 박혀 있어서, 캐릭터별 자세를 저장하면 F6가 엉뚱한 캐릭터로 끌려갔다

### 공사현장 `maps/CollapsingApartment.tscn`

- 부서지는 발판 4층(간격 170 = 이단 점프로만), 맵 스킬 `GroundPoundSkill`. **점프력이 바뀌면 다시 계산**

## 화면 흐름 / UI

- `ui/Disclaimer.tscn` → `TitleScreen` → `MainMenu`(스토리/대전/훈련장/가이드/설정). 대전: `RoomSettings` → `CharacterSelect` → `MapSelect` → 맵
- `GameState.gd`(오토로드)가 화면 사이 값을 들고 다님. ESC = 한 단계 뒤로, 대전·스토리 중엔 `PauseMenu`(`process_mode = ALWAYS`)
- `Fade`(검정 ColorRect)는 씬의 **맨 마지막 자식**
- 폰트 주아체 `fonts/Jua-Regular.ttf` — ⚠️ **기호 글리프가 거의 없다**(`◀ ▶ ● ○ · × ↑ ↓` 두부 → 코드로 그릴 것). 대화창은 나눔고딕
- **타이틀 구경 모드**(`game_mode == "attract"`): 랜덤 맵·AI 둘, HUD·컷인 등 없음. 떠날 때 `game_mode` "pvp" + 배율 복구. 로고는 `tools/make_title_logo.py`(**로고를 바꾸면 다시 돌릴 것**)
- 메인 메뉴: `<이름>Item`(판정 고정) > `Slide`(보이는 것만 이동). `Illust*`와 `Background*`는 index로 짝. 일러스트 파츠는 원본 캔버스 그대로 + `centered = false`, **큰 동작은 자세 그림 교체**
- 설정 > 조작 `ui/KeyboardMap.gd`(키 끌어 놓기 배정): ⚠️ `_input`에서 `get_local_mouse_position()` 금지 → `_local_of(event)`. ⚠️ **`refresh()`는 마지막에 `queue_redraw()`**. 저장 `GameState.rebind_action()` → `user://settings.cfg`. 마우스 확인은 사용자가
- 해상도: 기준 1280x720 + `canvas_items`(배치 숫자는 이 기준)
- 확인 창 `ConfirmPopup`: `_ask(문구, Callable)`, 두 갈래 `open_choice()`
- 방 설정 `RoomSettings`: 라운드·시간·쿨 배율·클래시/가드/대시 토글·상대(`vs_ai`). 버튼 연결은 `_ready()` 코드로
- 도감 `CharacterDex`(⚠️ TODO: 놀이터 설명이 옛 기믹). `FanTile.gd`(@tool) 네 점 모양 버튼
- 초상화: 크기·위치는 `ui/PortraitFrames.tscn`, 전부 `GameState.frame_portrait()` 경유. 스킬 로고 `Skill.icon`(투명 여백 잘라 넣기)

### 대전 진행

- `Stage._process()`가 양쪽 HP를 **한 번에** 판정(동시 KO = 무승부), 시간 초과는 HP 높은 쪽. 링아웃 `ring_out_y`
- 선수 판 위치: 기본 아래, `Stage.hud_panels_top`이면 위(놀이터). ⚠️ `panels_top_margin.x`를 76보다 작게 하면 일시정지 버튼에 깔림
- 지상/공중 조건은 스킬이 스스로 판단
- 카운트다운 중엔 컨트롤러 `is_active` false + `move(0)`(`set_physics_process(false)`는 미끄러짐)
- KO 연출 `Stage._play_knockout`(전 모드): 날려 보내지 않고 마지막 넉백대로 물리로 밀려남(`apply_hitstun`으로 멈춘 컨트롤러의 `move(0)`를 막음) + 화면 0.3배 슬로 2초(실제 시간) + 눈 X, 땅에 멈추면 `_lay_down_when_settled()`가 Visual만 발바닥 축으로 90도 눕힘. 화면 흔들림 없음. 디버그 격자: 대전 중 **G + '**(`maps/DebugGrid.gd`)

### 궁극기 컷인 `ui/UltimateCutIn.tscn`

- 기획 확정: 1.5초(장면 `cutin_duration` 우선), **연출 중 시간 정지**, 스킵 없음, 확정타 아님. `use_ultimate()` → 연출 → `fire_ultimate_now()`
- 장면은 `CharacterStats.ultimate_cutin_scene`, 파츠 흔들기 `ui/cutin/CutInAnimation.gd`. 있는 캐릭터: 주정뱅이·금쪽이·악플러·일진·경찰·지하철. **캐릭터를 움직여 넣을 땐 리그(`<캐릭터>Rig.tscn`)를 쓸 것**
- 지하철 컷인: ⚠️ `Metro!.png` 무늬가 기울어 칸마다 `rotation = -0.0158` + `skew = 0.0158`(그림 바꾸면 재측정), 이동은 x만. 칸 수·틈을 바꾸면 `train_from_x`/`train_to_x`도. 선글라스 반짝은 `LensGlint.always_show`
- 금쪽이 컷인: 원래 머리 복원 → `set_action_face(true)` 순서. 경찰: 얼굴 두 장 크기·위치 같아야 함

### 스토리 모드

- 난이도는 에피소드마다 `StoryFadeScene`의 `battle_enemy_hp_scale`/`battle_enemy_damage_scale`/`battle_ai_skill` → `Stage._apply_story_handicap()`(⚠️ `stats`는 공유 Resource라 **`duplicate()` 후, `add_child` 전에**) / `_tune_story_ai()`
- 에피소드 `GameState.STORY_EPISODES`, 클리어 기록은 `clears_story` 켠 장면의 `_ready()`
- 장면 `ui/story/StoryScene1~11.tscn`, 전부 `StoryFadeScene.gd`. `Fade`는 맨 마지막 자식·알파 0, 장면 루트·대화창 `mouse_filter = 2`. 전환 BLACK/CROSSFADE
  - **스토리→대전:** `battle_*` → `_setup_battle()`(**GameState에 담는 코드는 여기에** — S 건너뛰기가 `_open_next()`를 우회). (임시) `S` 건너뛰기는 방어키와 겹침 → 방어 테스트 땐 `debug_story_skip_key` 끔
- 대화창 `ui/story/DialogueBox.tscn`: `이름|대사`, 명령 줄 `@show/@hide/@enter/@exit/@close/@waitkey/@pause/@stamp`
- **3번·11번 장면은 도장만 다른 같은 구조 — 새 사건은 복사해 문구·도장만 교체**. PSD를 고치면 PNG로도. 게임 글자는 "비비탄"으로 통일

## 튜토리얼 `maps/Tutorial.tscn`(뼈대)

- 배경 `sprite/맵/튜토리얼/`(하늘·구름 `RandomCloudSpawner.gd`·산·숲·막사·국기 `FlagFlutter.gdshader`). 땅 ⚠️ `texture_repeat`는 위아래로도 반복 → `region_rect`를 투명한 윗부분 아래부터. 바닥 y=280, 벽 ±1200
- 훈련 더미를 P1이 조작. **교관 = 황근출(옷 입은 리그만, Fighter 아님)** `Instructor`(scale.x -1)
- **처음 켠 사람만** 타이틀 → 튜토리얼(`GameState.tutorial_seen`). 메뉴 훈련장 버튼 = 훈련장 / 튜토리얼 다시
- 말풍선 `maps/SpeechBubble.gd`(@tool, 전부 `_draw()`): **원점 = 꼬리 끝 = 가리키는 곳**. 교관 자식으로 붙이면 글자가 뒤집혀 맵 직속. `say(text, hint)`(BBCode 가능), `finish_typing()`, `close()`. 폰트 강한육군 Bold — **모든 `*_font_size` 슬롯 지정**(빼면 `[b]`가 16px). ⚠️ "썌"는 글리프 없음 → "쌔"
- 대사 `Tutorial.gd`: 교관 500px 안에 들면 시작, **스페이스로 한 줄씩**(행동 판정 아님), 강조 `_em()` = 빨간 굵게. 대사 중엔 카메라를 교관 ±450px로 clamp. TODO: 이동·점프 다음 조작 설명

## 훈련장 `maps/TrainingGround.tscn`

- 물리값·게임 속도 슬라이더(static var — 영구 반영은 `DEFAULT_*`), 모든 스킬 쿨 0. `Engine.time_scale`은 `_exit_tree`에서 복구. 충돌 보기 `CollisionDebugView.gd`, 바닥 눈금자 `FloorRuler.gd`

### ⚠️ 그림을 갈아 끼울 땐 **uid도 같이** 바꾼다 (2026-10-06)

`.tscn`/`.tres`의 참조는 이렇게 생겼다:

```
[ext_resource type="Texture2D" uid="uid://cf5dlqlyj3jys" path="res://.../런닝머신(8~9).png" id="3_car"]
```

**Godot은 `uid`를 먼저 본다.** 경로만 새 그림으로 바꾸고 uid를 그대로 두면 **옛 그림이 그대로 나온다**(조용히).
새 uid는 그 그림의 `.png.import` 첫머리 `uid=` 줄에 있다. uid가 아예 없는 줄(생성기가 만든 씬 등)은 경로만 바꾸면 된다.

- 바퀴(스포츠카 단계)를 `런닝머신(8~9).png`(민 휠) -> `헬스장바퀴.png`(타이어 있는 버전)로 갈아 끼운 예:
  12개 파일(캐릭터별 `*CarStudio.tscn` 10 + 원본 스튜디오 + `TreadmillGear.tres`)에서 **경로와 uid를 같이** 바꿨다
- 캔버스 크기가 같으면(둘 다 1254x1254) 맞춰 둔 자리·배율이 안 흔들린다. **다른 크기 그림으로 바꾸면 단계 자리를 다시 봐야 한다**

### ⚠️ 헤드리스 검사가 **스크립트 오류를 놓친다**(2026-10-06에 실제로 겪음)

`load(path) == null`로만 보는 검사는 **파싱 오류를 못 잡는다** — 중복 함수처럼 컴파일이 깨져도
`load()`가 null이 아닌 걸 돌려줘서 "실패 0"으로 통과한다. 검사 출력에서 **`SCRIPT ERROR` / `Parse Error`를
같이 grep**할 것.

```
godot --headless --path . res://_chk.tscn 2>&1 | grep -iE ">>> |씬 [0-9]+ \||SCRIPT ERROR|Parse Error"
```

파일 하나만 빠르게 볼 땐 `godot --headless --check-only --script <경로>`(종료코드 0 = 정상).
⚠️ 단 이 방법은 **오토로드를 안 올린다** — `GameState`를 쓰는 스크립트는 "Identifier not found: GameState"가
뜨지만 **가짜 경보**다.

⚠️ **남이 만든 파일에 함수를 더할 땐 같은 이름이 이미 있는지 먼저 본다.** `_validate_property`를
`_get_property_list`만 찾아보고 없다고 단정했다가 중복으로 넣어 씬이 안 열렸다

## GDScript 코드 스타일

| 대상 | 규칙 | 예시 |
| --- | --- | --- |
| 클래스명 / 파일명 | PascalCase, 파일명 = class_name | `CharacterStats` |
| 함수 / 변수 | snake_case | `move_speed`, `take_damage()` |
| 상수 / enum 값 | ALL_CAPS_SNAKE_CASE | `MAX_HP` |
| 시그널 | 과거형 snake_case | `health_changed` |
| private 관례 | 언더스코어 접두사 | `_internal_cooldown` |

- `class_name`·`extends` → `@export` → 멤버 변수 → 생명주기 → 커스텀 함수. 씬과 스크립트는 같은 폴더에
- 주석은 한국어: public 함수/변수 위 `##` 한 줄, 복잡한 로직에만. 자명한 코드엔 주석 금지

```
res://
  GameState.gd  Timers.gd
  characters/   # Fighter.gd + BodyRig.gd + 캐릭터별(chokbeopsonyeon, akpeulleo, jujeongbaengi, catmom,
                #   subwayvillain, floornoise, gymbro, iljin, hwanggeunchul / 로스터 밖: police, dummy)
  skills/  combat/  controllers/  stats/  maps/  ui/(story/, cutin/)  tools/
```

## 참고

- 기획 미정은 임시값 + TODO
- `invalid UID` 경고 → 씬 uid를 `.import`의 uid로
- **코드 수정 후 헤드리스 확인 안 함(사용자 요청)** — "실행해서 확인해줘"일 때만
- Godot 실행 파일: `Godot*4.7*win64*console*.exe` 검색
- 헤드리스 테스트: 쓰이는 씬을 띄울 것(`--quit-after`만으론 파싱 에러 못 잡음). `extends SceneTree --script` 금지 → `extends Node` 임시 `.tscn`. 시간 기반은 `--fixed-fps 60`. `apply_physics()` 중복 호출 금지, 순간이동 직후 착지 랙 대기
