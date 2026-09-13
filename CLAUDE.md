# 트러블 메이커 (villain) — Godot 프로젝트 규칙

사이드뷰 대전 격투 게임 **"트러블 메이커"**(2026-09-08 개명 — 리포·폴더는 `villain`, 빌드 산출물 `build/TroubleMaker/`). 기획 문서: https://claude.ai/code/artifact/661e48af-d8db-49c9-bc68-a9294790becb
전역 규칙(한국어 응답, 초보자 눈높이, 안전 규칙) 유지, 코드 스타일은 이 문서 우선 — 전역 CLAUDE.md는 Unity/C# 기준이나 이 프로젝트는 **Godot/GDScript**.

## 프로젝트 정보

- 엔진: Godot 4.7.2, GDScript (2026-09-10에 4.6에서 올림 — "참고" 절 버전 규칙 참조)
- 렌더러: Forward Plus, 3D 물리 Jolt (프로젝트 기본값 — 실제 게임은 2D)
- 장르: 사이드뷰 대전 격투, 바운스어택류(타격 후 넉백을 다시 잡아채는) 콤보 중심
- 전투 원칙: 히트스턴 최소화 지향, 지형·벽 활용 스테이지 기믹

## 확정된 아키텍처 방향

**캐릭터 전용 `.gd`는 만들지 않는다** — 모든 캐릭터 씬이 `characters/Fighter.gd`를 루트로 쓰고 스탯(`.tres`) + 스킬 노드 조합만으로 차이를 만든다.

- `characters/Fighter.gd`: 공용 베이스(`CharacterBody2D`) — 이동/점프/중력, HP(`take_damage`/`heal`/`health_changed`), 스킬 슬롯(`skill_1`/`skill_2`/`skill_ultimate`/`basic_attack` ← 자식 노드 `Skill1`/`Skill2`/`SkillUltimate`/`BasicAttack` 자동 연결), 자유 데이터 저장소 `custom_data`(예: 술 스택)
- 버프·디버프(`move_speed_multiplier` 등) 직접 대입 금지 → **`set_modifier(property, id, value)`/`clear_modifier(property, id)`**(id별 저장 후 곱셈이라 겹쳐도 안 지움). ⚠️ 옛 `set(property, value)` 대입 → 나중 디버프가 먼저 것을 지움 → modifier로 해결. 임시 효과 = `apply_temp_multiplier(property, value, duration)`(id 발급·만료 자동); 켰다 껐다 하는 지속 효과 = `"drink_stacks"` 같은 고정 id로 직접 호출(`DrinkSkill.gd`/`VomitSkill.gd`)
- **캐릭터끼리 몸 충돌 없음** — `Fighter._ignore_other_fighters()`가 `_ready()`에서 다른 Fighter와 양방향 `add_collision_exception_with`(새로 스폰된 쪽이 걸어 라운드 리로드·훈련장 교체 자동). ⚠️ 안 걸면 상대 머리 위를 발판처럼 밟고 다님. **충돌 레이어를 바꾸면 안 된다**(바닥·벽·발판까지 영향); `Hitbox`/`Hurtbox`는 Area2D라 그대로 감지; 대가 = 두 캐릭터가 겹쳐 설 수 있음(밀어내기가 필요하면 따로 넣을 것)
- `skills/Skill.gd`: 스킬 공용 베이스(`Node`) — 쿨 카운트다운·`can_use()`/`use(fighter)`를 여기서만 구현, 새 스킬은 상속해 `_execute(fighter)`만 오버라이드
- **궁극기는 라운드 시작 시 쿨을 물고 시작**(`Skill.start_on_cooldown`, 2026-09-10 — 전 캐릭터 `SkillUltimate` 켜짐, `_ready()`에서 `cooldown_left = effective_cooldown()`); 스킬1·2·기본공격은 꺼져 있어 즉시 사용 가능
  - 라운드 전환 = `Stage`의 `reload_current_scene()` → `_ready()`가 매 라운드 돎("게임 시작"과 "라운드 시작"을 따로 처리할 필요 없음), 라운드 승수만 `GameState`(오토로드)에 남음
  - `_ready()`를 오버라이드하는 `ComboMeleeAttack`은 `super()`를 부를 것 — 안 부르면 그 스킬만 조용히 빠짐
  - **궁 쿨:** 촉법소년 **50초**(2026-09-10에 20→50) / 악플러 25 / 고양이 아주머니 22 / 층간소음·지하철 아저씨 24 / 주정뱅이·헬스장 죽돌이 20. **쿨은 컷인이 끝난 뒤부터**(`use_ultimate()` 쿨 확인 → 연출 → `fire_ultimate_now()`에서 시작) → 재사용 간격 = 쿨 + 연출(촉법소년 2.9초 → 약 52.9초)
- **`Skill.cooldown_override`(2026-09-10)**: 0 초과면 `cooldown` 대신 이 값 — "몇 배"가 아니라 **"몇 초로"** 고정하는 절대값(악플러 열등감 = 기본공격 쿨 0.3초), 버프 종료 시 0으로 복귀
  - 쿨을 채우는 자리는 전부 `effective_cooldown()` 경유(`Skill.use()`/`cancel_use()`, `ComboMeleeAttack._resolve()`의 콤보 마무리·헛발 리셋, HUD `SkillCooldownIcon`). **한 군데라도 `cooldown`을 직접 읽으면 그 경로만 안 먹는다**
  - **헛발 쿨(`miss_cooldown`)도 같이 묶을 것**(`ComboMeleeAttack._effective_miss_cooldown()`) — 악플러는 마무리 0.3 / 헛발 1초라 예외로 두면 한 번 헛치는 순간 1초를 쉬어 버프가 무의미. 배수 방식(`Fighter.attack_speed_multiplier` — `Skill._process`가 기본공격 쿨 진행 속도에 곱함)도 남아 있고 같이 켜면 곱해짐
- `skills/RageBuffSkill.gd`(악플러 스킬2 "열등감 느끼기"): `duration`(6초) 동안 기본공격 쿨 = `basic_attack_cooldown`(0.3초) 고정 + 붉은 오라(`set_tint`) + 분노 표정(`set_action_face(true)` → `action_head_texture`); 되돌리는 건 **이 노드의 자식 `Timer`**(아래 Lambda capture); 발동 시 **이미 돌던 쿨도 `minf`로 0.3초까지 깎음**. 옛 `attack_speed_multiplier`(1.5배)는 export로 남았으나 기본값 1.0이라 꺼짐
  - **⚠️ 스킬에서 `Visual.scale` 직접 트윈 금지 → `BodyRig.play_squash(배율)`(2026-09-10).** 원인: 리그가 왼쪽을 볼 때 `scale.x` 음수인데 양수 목표값(예: `(1.12, 1.12)`)으로 트윈하면 0을 지나며 오른쪽으로 뒤집히고 `_face_moving_direction()`과 싸움. `play_squash()` = 점프/착지의 `_squash` 장치, 리그가 매 프레임 **방향 부호를 곱해** 적용하고 `squash_recover_speed`(2.5/초)로 복귀. 사용처: `HealSkill.heal_pop`(1.25배); `ScreamConeUltimate.shout_squash`(1.15 x 0.9); `JumpDebuffUltimate`(고아 파일); 열등감은 크기 연출 제거. 실측 촉법소년 -1.22/1.22, 주정뱅이 -1.12/0.92. **`FirePlate`처럼 자기 자식 스프라이트 트윈은 무관**(문제는 캐릭터 `Visual`뿐)
- `combat/Hitbox.gd` / `combat/Hurtbox.gd`: 데미지 판정 — `Hurtbox`(Fighter 자식 Area2D)가 피격을 받아 `take_damage()` 호출, `Hitbox`(공격 Area2D)가 `Hurtbox`와 겹치면 데미지(자기 자신 무시)
- `skills/ComboMeleeAttack.gd`: **기본공격 3타 콤보, 기본공격 있는 6명 전원**(`MeleeAttack` 상속). 히트 확인식 — 헛치면 예약 입력 폐기 + `miss_cooldown`(1초) + 1타 리셋, 3타 적중 시 `cooldown`(0.3초). 타별 데미지·넉백 = `combo_damage`/`combo_knockback` 배열이라 `damage` 프로퍼티는 안 씀(씬에서 지울 것). 기본공격 없는 지하철 아저씨(`vault_jump`)만 예외
  - ⚠️ 4명(악플러·고양이 아주머니·촉법소년·층간소음) 콤보가 "사라짐" → GitHub Desktop이 브랜치 전환 시 만든 stash → `git stash list`부터 볼 것
- `skills/MeleeAttack.gd`: 기본공격 공용 스킬 — 앞에 히트박스를 잠깐 켰다 끔; `damage`/`range`만 캐릭터별 지정해 재사용(사탕찌르기·키보드 휘두르기·술병깨기·팻말 때리기)
- **클래시 연출(2026-09-10 재구현, `ui/SkillClashPopup.gd` + `ui/ClashBand.gd`)**
  - 노란(P1)/파란(P2) 덩어리가 화면 밖에서 미끄러져 들어와 맞물림(`slam_time` 0.22초, 가속 곡선) + 번쩍임(`flash_*`) + 카메라 흔들림(`shake_*`); 맞물린 **사선 경계선 = 밀당 게이지**(눈금·숫자 없음) + 스파크(`spark_*`/`glow_*`); 얼굴 = `GameState.PORTRAITS` 정면 그림, 밀리는 쪽은 자리가 좁아지며 고개가 뒤로·이기는 쪽은 앞으로 꺾임(`face_tilt_deg` 26도)
  - **두 캐릭터는 주먹 러시(2026-09-12)**, 밀당에 따른 몸·고개 기울기 유지. **연타 한 번 = 주먹 두 방**(`BodyRig.clash_punches_per_press`, 양손 번갈아) — 팝업 `_push`가 그 쪽 리그의 `clash_punch()` 호출, 누르는 속도 = 주먹질 속도(8타/초=16방, AI 5타=10방); 큐 `clash_punch_queue_max`(4); 주먹 하나 = `clash_punch_time`(0.055초) sin 반주기
    - **각 손의 쉬는 자리에서 출발할 것** — 가운데 한 점이면 손이 톡 튐
    - 다 뻗은 순간마다 **잔상**(`clash_ghost_*`, 8칸 재활용, 0.14초 페이드); owner를 안 줘 씬에 저장 안 됨; 오른손 바로 뒤 순서(몸보다 앞·머리보다 뒤); 조금씩 어긋나게 남길 것
    - 러시 중엔 **손에 든 물건(소주병·키보드) 숨김**(`_hold_hidden_by_clash`), 끝나면 복귀
    - 옛 `shove_amplitude`(8px)/`shove_speed`(8)는 **0으로 껐고** 이기는 쪽 전진 쏠림 `shove_bias`만 남김; 몸통·머리도 절반쯤 따라감(`BodyRig.clash_body_follow`)
  - **흔들림 = 화면(월드) 기준 값을 두 캐릭터에게 똑같이 전달**(`BodyRig.set_clash_shove`) — 각자 "앞으로"를 쓰면 마주 본 상태라 손이 서로를 파고듦; 방향 보정은 리그가 `facing`으로. 실측 두 손 간격 30.00px 고정
  - **연타 키는 항상 일반공격 키**(`mash_action_id` = "basic_attack"; 빈 문자열이면 슬롯 키) — 슬롯 키면 멈춘 0.2초 안에 키를 판단해야 함. `balance_recenter`(0.03/초)만큼 게이지가 가운데로 복귀
  - **연타 수치(2026-09-12 재조정):** `push_per_press` **0.09**(가운데서 순수 약 6타 앞서면 승) / `balance_recenter` **0.03** / `mash_duration` **2.0초** / AI 연타 간격 **0.16~0.24초**(평균 5타/초, 예전 6.7). 옛 값 0.035 / 0.10 / 1.6초는 10타/초로도 끝까지 민 비율 0%. 결과: 8타/초 → 98%·1.6초 / 9타 → 100%·1.1초 / 7타 → 16%(나머지는 시간 종료 시 앞서서 승) / 안 누르면 AI가 1.2초쯤 승. **대가: 6타/초 이상인 사람에게 AI가 거의 못 이김**(예전 승률 44%) — 세게 하려면 이 간격만 줄이면 되고 사람끼리 대전엔 영향 없음
  - **결착(2026-09-12):** 시간 종료 시 **누른 횟수가 많은 쪽** 승(`_decide_by_presses` — 게이지 위치로 정하면 복귀력 때문에 어긋남), 동수면 게이지가 기운 쪽, 그것도 가운데면 동전 던지기
    - 연타 중 **누를 때마다 화면 떨림**(`press_shake` 2.5px, `rumble_max` 7px, `rumble_decay` 9/초); 띠·얼굴이 올라간 CanvasLayer의 `offset`도 같이 흔들 것(`ui_shake_ratio` 0.6) — 카메라만 흔들면 UI가 따로 놂
    - 시퀀스: 흔들림 정지 → 이긴 색이 화면 밖까지 차오름(`pour_time` 0.45초 = 게이지 절반 기준, 남은 거리 비례 단축; 가운데 `pour_bulge` 70px 불룩) → 한 덩어리로 번쩍 → `fly_delay` 0.15초 멈춤(진 쪽 얼굴 소멸·이긴 얼굴 튐) → 진행 방향으로 날아감(`fly_time` 0.38초, `fly_windup` 0.6로 뒤로 움찔 후 가속, 잔상 3장 `ClashBand.trail`, A 승=오른쪽/B 승=왼쪽, 얼굴 동승 = `face_anchor`가 `fly`를 더함) → 줌아웃. 전체 정지 시간 약 1초 증가(길면 `pour_time`·`fly_delay`부터 줄일 것)
    - **이긴 쪽 색은 게이지 끝(1.0)보다 더 채움**(`ClashBand.full_balance`, 1280폭 기준 약 1.15) — 사선이라 1.0에서도 구석에 진 쪽 색 삼각형이 남음 → `ClashBand.balance`는 -1~2까지 받고 얼굴·몸 기울기(`push_a`)는 -1~1에서 자름
    - **`solid`로 바꿀 때 띠를 사선 폭만큼 더 길게 그릴 것**(`_solid_half_len`) — 바꾸는 순간 모양이 안 변하게; 양 끝은 경계선과 같은 기울기로 잘림
- **⚠️ 띠를 화면 한가운데(`band_center_ratio` 0.5)에 두지 말 것** → 카메라가 두 캐릭터를 정중앙에 잡아 대치 그림을 통째로 가림(0.46 → 0.22로 올림)
- **`ClashBand`는 노드 없이 `_draw()` 한 곳에서 전부 그림**(경계가 매 프레임 움직이는 사선). 스파크는 **가로로만 뻗고 세로로는 마디마다 방향을 뒤집는 지그재그** — 아무 방향으로 꺾으면 흩어진 나뭇가지로 보임
- **대치 자세를 켤 때 리그의 `process_mode`를 ALWAYS로 올릴 것** — 클래시 중엔 `get_tree().paused = true`라 `BodyRig._process`가 안 돎; 끝나면 INHERIT 복귀
- **`BodyRig._pose_clash()`의 기울기에는 `facing` 부호를 곱할 것** — `scale.x = -1` 반전인데 Node2D 변환이 "회전 * 크기" 순서라 회전 각도가 그대로 남음 → 안 곱하면 왼쪽 보는 캐릭터가 "뒤로 넘어가기"를 함
- `combat/SkillClashManager.gd`: 두 Fighter가 같은 슬롯을 `match_window`(0.15초) 안에 함께 쓰면 화면 정지 + `ui/SkillClashPopup.tscn`; 이긴 쪽만 효과가 나가고 진 쪽은 `Skill.cancel_use()`로 쿨만 소모된 채 취소. `Stage.gd`가 `_ready()`에서 심고 Fighter는 `"skill_clash_manager"` 그룹으로 찾음(매니저 없는 씬은 바로 발동). **`skill_1`/`skill_2`/궁만 클래시를 탄다 — `Fighter.use_basic_attack()`은 일부러 안 거침**(쿨 1초 잽까지 걸리면 마주칠 때마다 화면이 멈춤)
- ⚠️ `get_tree().create_timer(t).timeout.connect(func(): 다른노드.뭔가 = 값)` → 그 노드가 먼저 사라지면 `ERROR: Lambda capture ... was freed`(`create_timer()`가 SceneTree 소속이라 노드보다 오래 삶) → `is_instance_valid()` 체크가 아니라 **그 노드(또는 관련 스킬 노드)의 자식으로 `Timer` 노드를 만들어 쓸 것**(부모가 사라지면 콜백 자체가 실행 안 됨 — `Fighter._after()`, `FirePlate.gd`, `Projectile.gd`). `await get_tree().create_timer(t).timeout` 단발 대기(`MeleeAttack` 히트박스 on/off)는 그대로 둬도 됨
- ⚠️ 공격이 에러 없이 조용히 안 맞음 → `Skill`은 `Node` 상속(`Node2D` 아님)이라 자식 `Hitbox`에 `hitbox.position = ...`을 쓰면 트랜스폼 체인이 끊겨 항상 `(0,0)` 기준 → `hitbox.global_position = fighter.global_position + Vector2(range * fighter.facing, 0)`처럼 **global_position으로 직접 배치**(`MeleeAttack.gd`). `Projectile`/`FirePlate`처럼 맵(Node2D)에 `add_child`하면 무관
- 이동을 잠깐 가로채는 스킬(돌진 등) = `Fighter.movement_override`에 자신을 등록 + `get_move_velocity_x()`/`after_physics(fighter, delta)` 구현(`skills/DashSkill.gd`)
- `Fighter.is_feared`/`apply_fear(duration)`: 공포 상태(지하철 아저씨 `skills/FearSkill.gd`)면 이동은 되나 `use_skill_1/2/ultimate/basic_attack` 전부 무시; `set_tint`로 색조도 걸어 구분
- `combat/Hitbox.gd`의 `pull_to_source`/`pull_strength`: true면 고정 `knockback` 대신 맞는 순간 공격자 방향으로 끌어당김(청소기 흡입 — `skills/VacuumSkill.gd`)
- `skills/AoeAttack.gd`: 캐릭터 중심 원형 범위 공격 공용 스킬 — `damage`/`radius` + `slow_multiplier`/`slow_duration`을 주면 `apply_temp_multiplier`로 둔화(층간소음 기타연주, 재사용 가능)
- **주정뱅이 술 스택(2026-09-01):** `DrinkSkill.max_stacks` **3**(예전 5), 술 쿨 3초라 풀스택 6초. 토하기 = 투사체가 아니라 **입에서 뻗는 가로 기둥** — `base_range=40`(0스택) + `range_per_stack=310` → **3스택 970px**; 두께 `base_height=24` + `height_per_stack=16` → **24 / 40 / 56 / 72px**(2026-09-09에 14/4에서 키움; 그림 4장의 실제 몸통 비율, 왜곡 최대 21%). **넘어가려면 여전히 이단 점프 필요**(3스택 기둥은 지면 위 9~81px, 지상 점프 56px). 970px > 가로맵 벽 안쪽 폭 920px → **풀스택이면 벽에 붙어 쏴도 반대편 벽까지 닿음**(끝이 x=460에서 끊김)
- **토 기둥 그림은 스택마다 따로 그린 걸 갈아끼움(2026-09-09)** — 한 장을 늘리면 0스택에서 783px 그림이 40px로 1/20 찌그러짐
  - `sprite/주정뱅이/토사물모음/1~4스택.png`(2048x683, 투명 배경); **파일 이름 1~4 = 게임 스택 0~3**(1스택.png = 0스택); 무지개가 길이 방향 2~5바퀴 반복. **3스택은 `4스택.png`이 아니라 `4스택진짜.png`**(왼쪽 끝이 산발이라 다시 그림), `4스택.png`은 이제 안 씀
  - `VomitBeam.stack_textures`(스택 = index) + `stack_body_rects`에 **각 그림의 기둥 몸통 위치** 기록(방울이 사방에 흩어져 그림 전체를 쓰면 위치가 안 맞음); 몸통이 판정 사각형에 겹치고 그 밖 방울은 장식으로 삐져나옴; 몸통 영역 = **세로 중앙선의 연속 불투명 구간**을 열마다 측정(두께 = 가운데 40% 구간 중앙값, 중심선 = 양끝 터짐을 뺀 가운데 50% 평균) — 그림을 새로 그리면 다시 잴 것
  - **벽에 막히면 눌러 줄이지 말고 잘라낼 것** — `region_rect` 가로만 잘라 오른쪽을 날림(누르면 찌그러짐); 영역 시작을 (0,0)으로 둬야 위치 계산이 맞음
  - **못 찾으면 그냥 안 그림(2026-09-09)** — 기본 텍스처 없음 + `push_warning` + `_visual.visible = false`(옛 갈색 fallback `토프로토.png`은 조용히 엉뚱한 그림을 내보내 제거). **갈색 토가 보이면 fallback이 아니라 스크립트가 죽었다는 신호**
- `skills/VomitBeam.gd` + `.tscn`: 토하기 기둥 — `Hitbox` 상속, `ScreamCone`처럼 **맵에 직접 붙여 `global_position`으로 입 위치에 배치**(Skill은 Node라 좌표 없음); 길이·두께는 `VomitSkill`이 계산해 `setup(방향, 길이, 두께, 데미지, 시전자)`로 전달, 유지 시간·연출·넉백은 씬 보유. 그림(`sprite/주정뱅이/토프로토.png`) = `region_rect = Rect2(15, 42, 783, 159)` + `centered = false`로 왼쪽 끝을 입에 맞춘 뒤 늘림; 왼쪽을 볼 때 `scale.x` 음수(판정 사각형은 음수 스케일 대신 `_facing`을 곱한 위치에 직접 배치). `stop_at_wall`이면 레이캐스트로 벽까지 재서 끊되 **캐릭터는 뚫어야 하므로 `fighters` 그룹 전체를 레이캐스트에서 제외**. BB탄 = 공용 `Projectile.tscn`(판정 반지름 5, 그림 `sprite/축법소년/총알.png`의 `region_rect = Rect2(550, 308, 426, 642)`); **2026-09-12에 `Visual.scale` 0.03 → 0.024, 화면 12.8x19.3 → 10.2x15.4px**(판정 지름 10px 유지)
- **⚠️ 갈색 토가 나오면 스크립트 문법 오류를 의심할 것(2026-09-09).** `VomitBeam.gd` 문법 오류 → Godot이 **스크립트를 떼어낸 채 씬을 띄워** 예전 그림이 날것으로 보이고 `@tool` 쪽에선 `class_name VomitBeam`이 안 잡혀 "placeholder instance" 에러가 줄줄이 남 → **먼저 Output 패널의 파싱 에러부터 볼 것**(실제 원인은 `static var _loaded_defaults: Array[Texture2D] = [] = [ ... ]` 이중 대입)
- ⚠️ `Projectile`이 발사 즉시 사라짐 → 쏜 사람 본인의 Hurtbox/CharacterBody2D에 반응(총구 앞 30px인데 판정이 크거나(토사물 36px 폭) 느리면(0스택 100px/s) 첫 물리 프레임에 시전자 몸(반지름 20)과 겹침; BB탄은 반지름 5·500px/s라 우연히 안 걸림) → `_on_area_entered`/`_on_body_entered` 둘 다 `source_fighter`면 무시. **판정을 키우거나 느리게 만들 때 재발 주의**
- `AIController`는 원거리 판단 시 `skill_2`의 `projectile_scene`뿐 아니라 **`beam_scene`도 함께 봄** — 안 고치면 주정뱅이가 근접처럼 달려듦
- ⚠️ GDScript에서 **해제된 객체는 `== null`이 `true`**(`is_instance_valid()`만 false) → `if source_fighter != null and not is_instance_valid(source_fighter)` 같은 방어 코드는 **절대 발동하지 않는다**. 훈련장 캐릭터 교체(`maps/TrainingGround.gd:96`의 `_fighter.queue_free()`) 시 시전자만 사라지고 기둥·투사체가 남아 해제된 객체를 `Hurtbox.take_hit()`의 `Fighter` 인자로 넘겨 타입 에러 → `Hitbox`가 `source_fighter`를 setter 프로퍼티로 바꿔 **주인이 있었는지를 `_has_source` 불리언으로 기억**. 열차처럼 주인이 원래 없는(null) 히트박스는 정상 동작해야 하므로 `is_instance_valid`로만 막으면 안 된다
- ⚠️ `lifetime_per_stack` 무효 + 실측 사거리가 계산값의 5배 → `Projectile` 수명 타이머를 `_ready()`에서 만들어 `VomitSkill`이 `add_child` 다음 줄에서 넣은 `lifetime`이 반영 안 됨(아래 `add_child` → `_ready()` 동기 실행 함정과 같은 건) → 타이머 생성을 `setup()`으로 이동(`skills/Projectile.gd._start_lifetime_timer()`). BB탄은 기본값(1.5초)을 써 영향 없음
- `skills/ScreamConeUltimate.gd` + `skills/ScreamCone.tscn`: 주정뱅이 궁 "괴성" — 입 앞 **부채꼴** 판정을 맵에 띄워 데미지+넉백 + 점프력 디버프(`jump_multiplier`/`debuff_duration`); 옛 `JumpDebuffUltimate`(판정 없이 디버프만) 대체. `ScreamCone` = `Hitbox` 상속, **빨간 부채꼴(`RangeFill`/`RangeOutline`)을 판정 폴리곤(`Collision`)과 똑같은 점 배열로 그려** 보이는 범위 = 맞는 범위; 검은 음파는 `wave_texture`가 있으면 그걸, 비면 코드로 그린 검은 호(`wave_count`/`wave_interval`/`wave_travel_time`), 부모 Node2D의 `scale`을 키워 전진과 확산을 한 번에 처리
  - **값이 사는 곳이 갈려 있다:** 데미지·입 위치·디버프 = 캐릭터 씬의 `SkillUltimate` 노드 / 부채꼴 길이(`cone_range`)·각도(`half_angle_deg`)·연출 = `ScreamCone.tscn` 루트. **한 값은 한 군데에만** — 양쪽에 두면 스킬이 씬 값을 덮어써 `ScreamCone.tscn`을 고쳐도 안 먹는 함정
- `skills/MouseGrab.gd`(악플러 스킬1 "유선 마우스 그랩"): 던지는 동안 `sprite/악플러/몸/마우스 선.png`, 잡은 뒤 `묶인거.png`. **두 그림 다 "케이블 왼쪽 + 물체 오른쪽"인 한 장이라 유선과 물체를 `region_rect`로 잘라 따로 그림**(통짜로 늘리면 마우스·뭉치까지 찌그러짐) — 유선만 늘리고(`_stretch_cord`) 물체는 배율 고정
  - 영역 + "케이블 중심선이 영역 위에서 몇 px 아래인가": 마우스 유선 `Rect2(0,333,1751,72)`/축 35, 마우스 몸통 `Rect2(1751,259,383,174)`/축 109, 감긴 유선 `Rect2(0,474,722,134)`/축 52, 케이블 뭉치 `Rect2(722,292,644,491)`/축 234·중심 (322,245.5). **그림을 다시 그리면 전부 다시 잴 것**
  - 유선 = `centered = false` + `offset`으로 **텍스처 중심선을 스프라이트 원점에 맞춘 뒤** 두 점을 잇는 각도로 회전; 왼쪽을 볼 때는 `scale.x` 부호를 뒤집을 것 — 회전 180도면 마우스·뭉치가 위아래로 뒤집힘(**유선만 회전 사용**). **시작점 = 리그의 실제 오른손**(`BodyRig.get_hand_position()` = `HandRHold`의 global_position), 고정 좌표 금지(옛 몸통 기준 `(22,-6)`은 줄이 배에서 나옴)
  - **뒤쪽 절반이 포물선으로 떨어짐(2026-09-10):** `throw_drop_after`(0.5 = 사거리 절반) 이후 `throw_gravity`(5000 px/초²); 수평 속도는 끝까지 그대로; `throw_drop_after` = 1이면 곧게 날아감. 중력 3400 → 5000(2026-09-10)으로 실효 사거리 303 → 약 285px, 변화는 처지는 각도 — 더 일찍 처지게 하려면 중력이 아니라 `throw_drop_after`를 낮출 것(옛 0.7/2600은 떨어지는 구간 120px뿐이라 갈고리처럼 보임)
    - **손 높이 = 지면에서 27px**(리그 `HandRHold` y=3, 캡슐 반지름 20+절반 30 → 발 y=+30) → 조금만 처져도 지면 아래인데 `z_index = 20`이라 땅에 박힌 채 미끄러짐 → `throw_stop_on_ground`(기본 켜짐)로 **지면·발판에 닿으면 그 자리에서 소멸**
    - **평지 실효 사거리 = `max_range` 400이 아니라 약 311px**(던지고 0.58초 뒤 지면 접촉; 몸 중심 기준, 손 기준 약 289px) — `max_range`는 "공중에서 던졌을 때 상한"에 가깝고 **점프해서 던지면 더 멀리 남**(의도). 평지 실측: 100·150·200·240·260·280·300px 적중, **340px 빗나감**
    - **떨어지는 동안에도 잡기 판정이 삶** — 판정은 `STATE_FLY` 전체(매 프레임 `_mouse_pos.distance_to(상대 중심) < catch_radius`), **종료는 지면 접촉**(또는 `max_range` 도달)이고 그때부터 `STATE_RETURN`. **한 프레임 안에서는 잡기를 착지보다 먼저 볼 것** — 착지가 먼저면 맞을 만했던 한 발이 사라짐
    - 판정 = **상대 중심에서 `catch_radius`(30px)** — 상대 몸(캡슐 20x60)보다 좁아 줄이면 스치기만 하고 안 잡힘(24 → 30); 프레임당 최대 11.7px이라 안 뚫림
    - **빗나가면 사라지지 않고 손으로 되감김(`STATE_RETURN`)** — `throw_return_speed`(1100 px/초) > 던지는 속도(700)라야 "탁 감긴다"로 보임(평지 0.40 + 0.24 = 0.64초); `_draw_throw()`가 마우스 뒤끝을 항상 `-_dir`(=손 방향)에 둬 그리는 코드는 손댈 게 없음. **되감기 중에도 잡기 판정이 삶(2026-09-11)** — 같은 `_touches_opponent()`로 닿으면 `_grab()` → 데미지 + `STATE_REEL`; 되돌리려면 `STATE_RETURN` 분기 끝의 `_touches_opponent()` 두 줄만 지울 것; 프레임당 약 18px이라 판정 지름(60px)보다 작아 안 뚫림; 상대가 이미 `_release_dist` 안이면 데미지만 들어가고 다음 프레임에 놓아줌. `return_speed` ≤ 0이면 영영 안 돌아와 노드가 남으므로 바로 `_release()`
    - 착지 판정 = 지나간 선분(직전 → 이번 위치) 레이캐스트 + **법선이 위를 향하는 면만** 인정; 벽은 일부러 통과(막으면 맵마다 사거리가 달라짐); 캐릭터는 `fighters` 그룹째 제외(`VomitBeam._clip_to_wall()`과 같은 방식)
    - **시간이 아니라 x 이동 거리로 잼** — 사라지는 판정(`absf(_mouse_pos.x - hand.x) >= _max_range`)과 같은 자라야 "70% 지점"이 실제로 70%(던진 뒤 걸으면 손이 움직여 시간으로 재면 어긋남); 유선은 `_stretch_cord`가 매번 다시 그려 처지면 줄도 비스듬해지고 마우스 그림은 수평 유지
  - **던지기 세 단계: ① 손에 쥔 채 젖히기(`throw_windup` 0.14초) ② 날아가기 ③ 끌어오기.** ①에서 마우스 앞끝을 손보다 반 칸 앞에 두는데 ②와 **같은 식**이라 손을 떠나는 순간 유선 길이가 안 튐; 둘 다 `_draw_throw()` 하나로 그림
  - 팔 동작 = `BodyRig.play_cast_motion(젖히는 시간, 돌아오는 시간)`. **젖히는 시간은 `MouseGrabSkill.throw_windup`과 같은 값을 넘길 것**(마우스가 손을 떠나는 순간과 팔이 뿌리는 순간이 맞아야 함). 잡은 뒤 `BodyRig.set_reeling(true)`로 두 손이 줄을 잡고 당기는 자세, 놓아줄 때(`_release`/`_exit_tree`) 꺼짐
  - 크기 = `mouse_length`(30px, 마우스 몸통)·`coil_width`(50px, 뭉치 폭)(배율을 역산해 그림이 바뀌어도 화면 크기 유지). **`MouseGrab.new()`로 코드에서 만드는 노드라 이 두 값은 `setup()` 전에 대입할 것**(`setup()` 안에서 그림을 만듦)
- `Fighter.vault_jump: bool`: true인 캐릭터(지하철 아저씨)는 기본공격이 없는 대신 점프 시 `_play_vault_effect()`가 회전 트윈으로 "개찰구를 뛰어넘는" 연출
- ⚠️ `add_child(node)`는 `_ready()`를 **그 자리에서 동기 실행** → 다음 줄에서 export를 세팅해도 `_ready()`는 이미 기본값으로 끝난 뒤(`_ready()` 안에서 `wait_time = lifetime`처럼 export를 캐싱하면 기본값이 캐싱됨 — `skills/CatPet.gd`) → 그런 캐싱은 **첫 `_physics_process`/`_process` 시점**(`_initialized` 플래그로 한 번만)으로 미룰 것

## 조작 / AI

- `controllers/PlayerController.gd`: 입력 → 부모 Fighter. `player_index`(1/2)로 `p1_*`/`p2_*` 읽음 → P1/P2 둘 다 사람 조작 가능
- `controllers/AIController.gd`: 거리로 접근/거리유지/후퇴/공격 결정. Fighter는 사람/AI 구분 없음(`fighter.move()`·`use_skill_1()` 공용 메서드)
  - `skill_2`에 `projectile_scene` 있으면(BBGunSkill/VomitSkill) 원거리 → `ranged_distance`(180px) 유지. 스킬 구성만 보므로 새 캐릭터도 자동
  - 쓸 스킬 없으면(`_all_skills_on_cooldown`) 확률적 후퇴, 바닥에서 낮은 확률 점프
  - 대시·방어도 AI가 씀(2026-09-10, 전 캐릭터 동일)
    - 대시 조건 ①상대가 `dash_approach_distance`(200px) 밖 ②쿨 벌려 후퇴 중(`_retreat_timer`) ③원거리 캐릭터가 밀착 상대에게서 이탈 ④안전지대까지 `dash_dodge_distance`(80px) 초과. **조건 맞으면 매 프레임 호출**(쿨 3초를 `Fighter.dash()`가 막음)
    - 방어: 상대가 `guard_threat_distance`(70px) 안 → `guard_start_chance`(0.06/프레임)로 `Fighter.start_guard()`. **유지·해제·쿨은 Fighter, AI는 "켤까"만 판단.** HP 30% 밑 2.5배. `ClaudeAIController` → `guard_bias`: `aggressive` 0.4 / `retreat` 1.5 / `defensive` 3배
    - **기믹(열차) 중엔 안 막음**(`_hazard_active()` — 안 막히는데 피하지도 못해 순손해). 방어 중엔 다른 판단 스킵
  - ⚠️ 후퇴 중 투사체가 반대로 나감 → `Fighter.move()`가 `facing`도 바꿈 → 후퇴 직후 `fighter.facing` 강제. **`Fighter.dash()`도 동일하니 뒤로 대시 뒤 반드시 되돌릴 것**
- 조작키 확정(2026-08-30) — `project.godot` InputMap의 `p1_*`/`p2_*`:

| 조작 | P1 | P2 | 액션 이름 |
|---|---|---|---|
| 이동 | A / D | ← / → | `p1_left`·`p1_right` / `p2_left`·`p2_right` |
| 점프 | W | ↑ | `p1_jump` / `p2_jump` |
| 기본공격 | F | L | `p1_basic_attack` / `p2_basic_attack` |
| 스킬1 | G | K | `p1_skill_1` / `p2_skill_1` |
| 스킬2 | H | J | `p1_skill_2` / `p2_skill_2` |
| 궁극기 | R | P | `p1_ultimate` / `p2_ultimate` |
| 플랫폼 아래로 내려가기 | S 누른 채 W | ↓ 누른 채 ↑ | `p1_down`+`p1_jump` / `p2_down`+`p2_jump` |
| 대시 | A A / D D | ← ← / → → | (전용 액션 없음 — 이동키 두 번) |
| 방어 | S | ↓ | `p1_down` / `p2_down` 누르는 순간 발동 (1.2초 무적 / 쿨 5초) |

  - `Stage.gd`가 P2에 `ClaudeAIController`를 붙임 → **2P 사람 조작을 켜려면 `_spawn_fighter(..., is_ai)`에 false를 넘기는 분기(모드 선택) 필요**
  - 이단 점프(완료, 2026-09-03): `Fighter.jump()`가 `is_on_floor()`로 지상/공중 분기. `Fighter.max_air_jumps`(1)·`air_jump_velocity`는 static var(훈련장 실시간 조절). 공중 점프는 낙하 속도 무시하고 `velocity.y` 덮어씀. `_air_jumps_left`는 `apply_physics()`의 `move_and_slide()` **뒤에** `is_on_floor()`로 채움(앞이면 한 프레임 늦음)
  - **⚠️ 값 변경(2026-09-08):** 이동속도 전 캐릭터 +40(각 `stats/*.tres`), `DEFAULT_JUMP_VELOCITY` -350→**-430** / `DEFAULT_AIR_JUMP_VELOCITY` -420→**-510**. **아래 실측 높이(지상 71.1px·이단 165.4px, 놀이터 절 56.3/129.2px, -507 권장치)는 전부 옛 값(-350/-420) 기준 — 지금은 더 높다.** 지하철 벤치(145px = 옛 실측 "이단으로만 닿는" 높이)·놀이터 발판(120px)은 여유 있게 닿을 것, 재측정 필요. 전 맵 공통이라 링아웃형 맵(학교 옥상)이 관대해짐(밸런스 확인 필요)
  - 방향키 두 번 대시(완료, 2026-09-10): `PlayerController.DOUBLE_TAP_WINDOW`(0.25초) 안 두 번 → `Fighter.dash_speed`(700) x `dash_duration`(0.18초) = **126px**, `dash_cooldown` **3초**. InputMap 변경 없음
    - 스킬이 아니라 기본 조작(`Fighter`에 직접, 스킬 클래시·`is_busy()` 무관). 공중에서도 나가고 중력 계속 받음. 값 셋은 static var
    - **`movement_override`(자전거 돌진·마우스 끌려가기)가 걸리면 대시 안 나감**, 대시 중 걸리면 그쪽이 이김(`apply_physics`가 대시 속도 뒤에 덮어씀). **맞으면 대시 끊김**(`_hitstun_time > 0` — 넉백이 대시를 이겨야 콤보 성립)
    - **두 번째 탭이 인정되면 기록을 지울 것**(안 지우면 연타마다 계속 나감). 잔상 = `Fighter._spawn_dash_afterimage()`의 `Visual` 복제(`DashSkill`과 동일) — **복제본 스크립트를 뗄 것**(안 떼면 `BodyRig` 자세 계산이 잔상에서도 돔). 쿨 HUD 없음(`Fighter.dash_cooldown_ratio()` 0~1)
  - 아래 키 방어(완료, 2026-09-10): 누르는 순간 원형 보호막(`combat/GuardShield.gd`) + `Fighter.guard_duration`(**1.2초**) 동안 **데미지·넉백 0**, 이후 `guard_cooldown`(**5초**). 한 번 눌러 발동(키 떼도 유지 — "누르는 동안 절반" 방식은 기획과 달라 폐기)
    - **`take_damage`에서 `is_invincible`과 같은 자리에 early return**(넉백·경직도 무효), 막은 양은 `custom_data["guard_absorbed"]`에 누적. 방어 중 이동·점프·기본공격·스킬 전부 차단, 공중에서도 켜지고 수평 속도 0 고정
    - ⚠️ 아래 키가 발판 통과와 겹침 → 내려가려다 방어가 켜져 5초 쿨 낭비 → `PlayerController.GUARD_CANCEL_WINDOW`(0.25초) 안 점프면 **통과 의도로 보고 `cancel_guard(true)`로 쿨까지 환불**(없으면 발판 맵에서 방어 못 씀)
    - 막는 자세 `Fighter._set_visual_guard()` → `BodyRig.set_guarding()`: 두 손이 몸 앞(오른손 얼굴 앞 / 왼손은 더 낮은 가슴 앞으로 어긋나게), 몸·머리 `guard_crouch`(5px) 움츠림, 고개 `guard_head_deg`(6도). `_guard_blend`로 섞고 메서드 없는 비주얼은 스킵
      - **손 위치는 머리 오른쪽 끝(x=25)보다 앞에. 더 붙이려면 x를 줄이지 말고 y를 올릴 것**(기본 오른손 `(29,-34)` / 왼손 `(25,-17)`) — x를 안쪽으로 넣으면 촉법소년만 손이 얼굴을 덮고(이 리그만 손에 `z_index = 1`) 나머지 5명은 손이 머리 뒤로 숨음
      - **`guard_hand_deg`는 음수(-45)라야 한다** — 손에 든 물건이 따라가서 음수면 몸 쪽으로 눕고 양수면 머리 위로 치솟음. -45 = 악플러 키보드가 얼굴 앞 방패 / 촉법소년 사탕은 모자 옆
    - 보호막 = `_draw()` 반투명 원 + 남은 시간만큼 12시부터 시계로 줄어드는 테두리, 켜질 때 25% 부풀었다 복귀. 반지름 47 / 중심 `(0,-14)` = 캐릭터 전체(머리 -60 ~ 발 +32) 커버, 6명 공통
    - **`Fighter._shield`에 타입 안 붙임** — `GuardShield`가 `preload`로 가져오는 새 `class_name`이라 타입을 붙이면 클래스 캐시 갱신 전 `set_active()`를 못 찾는 파싱 에러(`movement_override`와 동일). 쿨 HUD 없음(`Fighter.guard_cooldown_ratio()` 0~1)
  - 플랫폼 아래로 내려가기(완료, 2026-09-03): 아래키+점프 → `PlayerController._drop_through_platform()` → `Fighter.drop_through_platform()`. 통과 가능한 발판 위가 아니면 평범한 점프(입력 씹힘 방지)
    - **레이어를 끄지 말고 `add_collision_exception_with(발판)`으로 그 발판만 예외**(레이어를 끄면 같은 레이어인 지면·벽까지 통과해 맵 밖으로 떨어짐). 예외는 `Fighter.DROP_THROUGH_DURATION`(0.35초) 뒤 자식 Timer(`_after`)로 복구
    - 발밑 발판 = 직전 `move_and_slide()`의 `get_slide_collision` 중 법선이 위를 향하는 면만 골라 `is_shape_owner_one_way_collision_enabled()`로 판별(`Fighter._get_one_way_floor()`)

## 캐릭터 몸(스프라이트 조립)

`characters/BodyRig.tscn` — 조각(머리/몸/손/발)을 Sprite2D로 조립한 공용 몸. 캐릭터 씬 `Visual` 자리에 인스턴스(6명 전원). 이름이 `Visual`이라 `Fighter._flash_hit`·궁극기 연출이 그대로 동작.

- 파일 배치: 공용 `sprite/body/` / 전용 `sprite/<캐릭터>/몸/`(주정뱅이는 몸·발·머리 전용, 손만 공용). 층간소음·고양이 아주머니·지하철 아저씨는 `sprite/층간소/`·`sprite/캣/`·`sprite/지하철빌/` **바로 아래** `발.png`/`손.png`(`몸/` 안 씀 — 새 파츠는 두 군데 다 볼 것). 세 명의 `손.png` = `sprite/body/손.png`와 바이트까지 동일. 발은 캐릭터 색 신발(층간소음 빨강 / 고양이 자홍 / 지하철 파랑), 캔버스가 공용 `발.png`와 같은 179x101이라 기본 배율 그대로 텍스처만 덮어씀
- 인게임 머리 = 옆모습(리그 `Head`, 층간소음 `층간소음측면.png`) / 선택창 초상화 = 정면(`GameState.PORTRAITS`에만, 층간소음 `층간소음머리.png`)
  - **초상화 배경은 투명이어야 한다**(`CharacterSelect`가 색 타일 `CHARACTER_COLORS` 위에 얹어 흰 배경은 흰 사각형이 됨). `sprite/body/지하철정면.png`은 흰 배경 → 테두리부터 플러드 필로 깎아 `sprite/지하철빌/지하철빌런정면.png`로 저장해 씀(**흰 머리카락이라 '흰 픽셀 전부 지우기' 금지, 반드시 테두리에서 번지는 방식**, 원본 보존)
  - 6명 전원 등록. 고양이 아주머니 = `sprite/body/면.png`(파일명이 짧게 잘렸으니 주의 — 없는 `캣맘정면.png`를 가리켜 색 타일만 나오던 버그를 고친 것)
  - 초상화 크기·위치는 `ui/PortraitFrames.tscn`에서 캐릭터마다 조절(2026-09-08): 프레임(`Panel` 200x180) + `Portrait`(TextureRect), 드래그=위치 / 핸들 리사이즈=크기(노드 rect), 프레임(`clip_contents`)이 곧 게임 타일. `GameState._load_portrait_frames()`가 텍스처 + 프레임 대비 비율(`_portrait_rect_center`/`_portrait_rect_size`)을 읽고 `GameState.frame_portrait(image, 이름, 상자크기)`가 옮겨 가운데 맞춤. rect 리사이즈·Transform>Scale 둘 다 반영(rect에 `scale.x`를 곱해 환산 — ⚠️ 처음엔 `scale.x`만 읽어 핸들 리사이즈 미반영 → rect 기준으로 고침). **초상화 네 곳(선택 그리드 100x90 / 미리보기 300x330 / 에피소드 타일 120x100 / 대전 HUD 70x70)이 전부 이 함수를 거친다**
- `BodyRig.tscn`의 `Head`는 텍스처가 비어 있고 캐릭터별 머리는 씬 상속(상속 씬에서 `Head` 텍스처/위치/크기만 덮어씀, 예: `characters/akpeulleo/AkpeulleoRig.tscn`). 6명: `JujeongbaengiRig`·`AkpeulleoRig`·`ChokbeopsonyeonRig`·`FloorNoiseRig`·`CatMomRig`·`SubwayVillainRig`
  - **새 리그 배율은 눈대중 금지.** 기준(투명 여백 제외) 몸 약 33x30px / 머리 약 55x55px / 머리 보이는 중심 리그 원점 기준 약 `(-2, -32.8)`. `Image.get_used_rect()`로 실제 영역을 재서 역산(캔버스 크기로 계산하면 어긋남)
  - 고양이 아주머니 머리 `sprite/캣/캣맘머리.png`(1254x1254, 알파 bbox x15~1215 / y27~1191): 교체 때 옛 배율 0.0555가 남아 66.7x64.7px → 0.0454 / (-1.48, -32) → **2026-09-12 배율 0.042 / 위치 (-1.52, -32.07)** = 50.4x48.9px, 중심 (-2.0, -32.8) 유지. **배율을 바꾸면 위치도 다시 잡을 것**(position = 목표중심 - (bbox중심 - 캔버스중심) x 배율)
  - 다른 머리 화면 크기(2026-09-11 실측): 악플러 54.4x52.8 / 촉법소년 50.0x52.9 / 층간소음 47.5x46.6 / 주정뱅이 51.6x54.8 / 지하철 59.8x54.7 — 평균 53x52px, "55x55"는 상한
  - PowerShell 함정: 변수 이름이 대소문자를 안 가려 `$h`와 `$H`가 같은 변수
- 조각 위치는 **에디터에서 `BodyRig.tscn`을 직접 열어** 옮길 것(캐릭터 씬에서 `Visual`을 만지면 그 캐릭터만의 덮어쓰기 발생)
- `characters/BodyRig.gd`: 애니메이션 파일 없이 코드로 걷기 — 두 발이 반 바퀴 어긋난 교차 걸음(`foot_stride`), 앞으로 나갈 때만 발끝 `foot_swing_deg`·뒤로 밀릴 땐 눕힘, 걸음마다 몸/머리/손 들썩임(`body_bob`), 손은 발과 반대로(`hand_swing`). 왼쪽 = `scale.x` 부호만 뒤집음(크기는 안 건드림 — 궁극기 연출이 `Visual.scale`을 만짐). 제자리 값은 `_ready()`에서 씬 위치를 기억 → **에디터에서 옮겨도 코드 수정 불필요**. 공중(`is_on_floor()` false)엔 두 발 `jump_foot_deg`(60도), 착지 시 복귀
- **손에 드는 무기는 `HandRHold`의 자식으로 단다.** `Head`보다 앞 순서 = 무기가 머리 뒤로 넘어가면 가려짐(상속 씬 `Head`가 `index="6"`인 이유). `HandR`의 위치·회전을 매 프레임 복사하는 배율 1짜리 빈 Node2D(HandR 자식으로 달면 손의 0.11 배율까지 물려받음). 주정뱅이 소주병이 이 방식
- 방어에 막히면 때린 손·무기가 빨갛게 깜빡이고 기본공격 잠김(2026-09-10): `Fighter.blocked_attack_lock`(3초) 동안 기본공격 차단 + 오른손·무기가 `blocked_flash_color`(빨강)를 `blocked_flash_cycles`(6)번 왕복(투명도도 `blocked_flash_min_alpha` 0.3까지). 3초 안에 또 막히면 타이머만 재시작
  - 시간의 주인은 `Fighter.blocked_attack_lock`(static var) 하나, `Fighter.play_weapon_blocked()`가 몸에 넘김 — `BodyRig.blocked_flash_duration`은 Fighter 없이 몸만 띄울 때의 예비값이니 **시간은 Fighter 쪽에서 고칠 것**
  - **`HandR`·`HandRHold` 두 노드에 각각 `modulate`** — 부모-자식이 아니라 형제(트랜스폼만 복사)라 한쪽만 걸면 나머지가 안 물들고, 양쪽에 걸어도 두 번 곱해지지 않음. 손은 전원 보유 → 무기 없는 캐릭터도 보임
  - 막힘 판정은 `Hitbox._is_blocked_by_guard()`(`take_damage()`는 방어 중 맨 앞에서 return, `Hurtbox.take_hit()`은 막혀도 true — `source_fighter`를 아는 Hitbox가 맞은 쪽 `is_guarding`을 직접 봄). 기본공격만 잠김(히트박스 부모가 공격자의 `basic_attack` 노드인지로 판별 → 씬 수정 불필요)
- **맵 피해는 `Fighter.take_map_damage()` 한 곳으로(2026-09-10).** 열차·화분·층간소음 충격파 등 주인 없는 피해 전부. **맵 피해 전용 처리는 전부 여기 넣을 것**(지금은 "방어로 안 막힘" 하나)
  - 분기는 `Hurtbox.take_hit()` — `source_fighter` 있으면 `take_damage()`(막힘), null이면 `take_map_damage()`(관통). 기준이 "주인 유무"라 씬 수정 불필요(해제된 주인은 `Hitbox._try_hit()`이 먼저 걸러냄). 히트박스 없이 때리는 기믹(`StompZone`·`HazardPlatform`)은 직접 호출
  - **맵 피해는 방어를 깬다(`cancel_guard()`)** — 데미지만 통과시키면 넉백이 지워짐(방어 중 `apply_physics()`가 매 프레임 `velocity.x = 0` → 열차에 맞아도 제자리 붙박이). 쿨은 정상 소모(방어로 열차를 막으면 기믹이 죽어서 뚫리게 한 것)
  - **`take_damage()`의 `ignore_guard`를 바깥에서 직접 true로 주지 말 것**(`take_map_damage()` 전용 — 직접 쓰면 맵 피해 경로가 둘로 갈라짐)
- 막으면 데미지 숫자 대신 "BLOCK"(2026-09-10): `DamagePopup.setup_block()`(`block_font_size`/`block_color`). `Hitbox._try_hit()`이 막힘을 한 번만 판정해 팝업·무기 깜빡임에 공용(두 군데서 판정하면 "BLOCK인데 HP가 깎임"). 맵 기믹은 관통이라 데미지 숫자(같은 `_has_source` 기준)
- 기본공격 모션: `Fighter.use_basic_attack()` 발동 순간 `Visual.play_attack_swing()`(메서드 있는 비주얼만) — 오른손이 머리 뒤쪽 위로(`attack_raise_offset`/`attack_raise_deg`) → 앞아래로 내려찍고(`attack_slam_offset`/`attack_swing_deg`) 복귀. `attack_duration`(0.4초) 중 40~62%가 내려찍는 구간
- 기본공격 중 손에 든 물건은 손 회전을 그대로 따라간다. 각도 고정용 `attack_hold_deg`를 넣었다 **되돌렸으니 다시 건드리지 말 것**(`8755e71` 커밋의 공격 코드와 일치 확인)
- 두 손으로 잡는 기본공격(`attack_two_handed`, 기본 false — 악플러만): 왼손이 `attack_grip_offset`으로 붙음(무기는 `HandRHold`에 매달려 있어 왼손은 위치·회전만 따라감). 왼손 회전도 `_apply_pose`에서 매 프레임 0으로 되돌린 뒤 덮어씀(안 그러면 공격 후에도 돌아간 채 남음)
  - 콤보 동안 두 손이 계속 붙어 있음(2026-09-10): `_grip_blend`가 `_attack_time > 0`이면 1 유지, 마지막 타 뒤에야 0으로(`attack_grip_speed` 12/초). 타별 스윙 진행도로 계산하면 타마다 풀렸다 붙어 덜덜거림
  - `_pose_grip_hand()`는 스윙 함수가 아니라 `_apply_pose`에서 매 프레임 호출(공격 후 블렌드가 남아야 스르륵 풀림). **`attack_grip_speed`를 9 밑으로 내리지 말 것**(예비동작 0.18초보다 느리면 때리는 순간 한 손으로 보임)
- 두 손 무기는 타별 스윙이 따로(`_two_handed_variant_params()`, 2026-09-10): 1타 씬 값 그대로 짧게 / 2타 어깨 위로 들었다 앞아래 / 3타 머리 위까지 들었다 바닥까지. **총 회전각(raise + swing) 120도 밑으로 유지할 것**(2타 105도=45+60, 3타 120도=50+70 — 넘으면 키보드가 얼굴을 가로지름). **타별 크기 차이는 각도가 아니라 손 이동 거리(`raise_off`/`slam_off`)로**(무기가 손에서 20px 떨어져 위치가 더 크게 먹힘). 켠 리그가 악플러뿐 → 다른 캐릭터 영향 없음
- 악플러 키보드 `AkpeulleoRig.tscn`의 `HandRHold/Keyboard`: 원본 2172x724(그림 2083x649), `scale 0.0221` = 화면 약 46x14px, 배트처럼 뻗도록 숫자패드 쪽 끝을 쥐게 `position (-19, -8)`
- 악플러 기본공격 = 도끼질이 아니라 야구배트 스윙, `AkpeulleoRig.tscn`에서 덮어씀: `attack_raise_deg 35` / `attack_swing_deg 85`(총 120도) / `attack_raise_offset (-24, -6)` / `attack_slam_offset (24, 6)` / `attack_duration 0.45`. 더 키우면(45/120 시도) 키보드가 얼굴을 가로지름. 주정뱅이는 공용 기본값(100/130/0.40)
- **⚠️ 손에 든 물건의 위치 오프셋은 그림 반길이보다 작아야 한다.** `HandRHold` 자식의 `position` = 손에서 물건 중심까지 거리, 무기는 손을 축으로 회전 → 키보드를 `(-42, -19)`(길이 46)에 두면 반길이(2083 x 0.0221 / 2 = 23)의 두 배 = 손에 안 잡힌 상태로 몸에서 날아감. 지금은 키보드 축(45도) 방향 20만큼(스윙 내내 손과 최대 19.8px)
- `attack_swing_arc`(기본 0): 후려치는 구간에서 손이 이동 방향 아래로 부푼 호(악플러 26, 0이면 직선이라 주정뱅이 영향 없음). 악플러 최종값 `raise 25 / swing 70 / raise_offset (-24, 4) / slam_offset (26, -12) / arc 26`
- 회전 각도와 물건 오프셋은 얽혀 있다 — 오프셋 46 + 120도 = 키보드가 화면 밖으로 날아감. **오프셋을 바꾸면 `attack_raise_deg`/`attack_swing_deg`도 다시 볼 것**
- 촉법소년 기본공격 = 막대사탕 3타 콤보(1타 찌르기 / 2타 아래서 위로 올려치기 / 3타 머리 뒤로 넘겨 바닥까지 내려찍기). `BodyRig.attack_thrust`(기본 꺼짐)를 켜면 `_attack_variant_params()` 대신 `_thrust_variant_params()`, 다른 5명 영향 없음
  - **2·3타는 1타에서 파생 금지, `thrust2_*`/`thrust3_*` 8개 export로 따로 지정**(찌르기는 회전을 거의 안 써 배수로는 다른 궤적이 안 나오고 "동작이 하나뿐"으로 보임)
  - 사탕 = `ChokbeopsonyeonRig.tscn`의 `HandRHold/Candy`. `rotation 45도`(평소 앞위) + 후리기 45도 = 찌를 때 정확히 수평 정면 — 한 쌍이라 한쪽만 바꾸면 어긋남
  - `attack_raise_deg`가 음수(-20): 머리 55x55라 손 제자리(27,3)에서 뒤로 당기면 사탕이 얼굴 위에 얹힘 → 예비동작에서 아래·앞으로 눕혀 턱 밑을 지나가게(+20, raise_offset (-12,-3)은 입에 문 것처럼 보여 폐기)
  - `position (9.6891, -9.6743)` / `scale 0.021` = 막대 아래쪽 끝(원본 픽셀 (511.5, 1420))이 손에 오도록 역산. 화면 사탕 지름 16.4px / 전체 길이 29.7px(손~사탕 중심 20.4px) — 그림을 바꾸면 다시 잴 것
  - **사탕은 `z_index`를 안 준다(머리·손보다 뒤)** — 3타에서 머리에 가려져야 "뒤로 넘겼다"로 읽힘. BB총 발사 중엔 숨김(같은 오른손 그립이라 겹침): `BodyRig.gun_hides_held_item`(기본 꺼짐)이 악플러 `cast_hides_held_item`과 같은 자리에서 판단, 자전거 돌진 중엔 들고 있음. 궁극기 컷인 3번 장면 `Runner`도 이 리그 인스턴스라 달리는 손에도 사탕이 보임
- **⚠️ `attack_duration`을 바꾸면 `BasicAttack.windup`도 맞출 것**(구간 40~62% → 0.40=0.16 / 0.45=0.18 / 0.35=0.14(촉법소년)). 안 맞추면 예비동작 중 판정이 나감
- 마우스 던지기/줄 당기기(악플러 스킬1): `play_cast_motion(젖히는 시간, 돌아오는 시간)` = 오른손을 어깨 뒤로(`cast_windup_offset`) → 앞으로 뿌리고(`cast_release_offset`) → 복귀. `set_reeling(true/false)` = 두 손을 줄에 모아(`reel_hand_offset`/`reel_hand_l_offset`) `reel_tug_speed` 박자로 당기는 자세(`_reel_blend`로 섞어 안 끊김)
  - **`cast_windup_offset`의 y를 -6보다 위로 올리지 말 것** — 손 제자리(27,3) 기준 y=-6 위는 전부 얼굴, 마우스는 `z_index 20`이라 머리 위에 얹힌 것처럼 보임(-20으로 잡았다 고침). 지금 (-8,-2)
  - `cast_hides_held_item`(기본 꺼짐) = 던지고 당기는 동안 `HandRHold` 숨김(악플러만 켬 — 키보드와 마우스가 겹침)
- 피격 표정(`hurt_head_texture`, 2026-09-09): `Fighter.take_damage` → `Visual.play_hurt_face()`, `hurt_face_duration`(0.45초). 그림 없으면 스킵 → 촉법소년(`축법소년 다치다.png`)·악플러(`악플러 피격.png`)·주정뱅이(`주정뱅이 피격.png`) 셋
  - 잠깐 표정 우선순위 **피격 > 토하기 > (액션/취함/맨정신)**. `set_action_face`/`set_drunk_head`는 적용을 미루고, 끝날 때 `_restore_head()`가 남은 표정 → 기본 머리 순으로 복귀
  - 악플러 얼굴 네 장 캔버스 1374x1145 동일(기본 `sprite/body/악플러대가리.png` 포함), 촉법소년 머리 세 장도 얼굴(살색) 영역 거의 동일(x 406~1192, y 413~955, 셋 다 1536x1024) → 둘 다 보정 불필요. **악플러 기본 머리가 `sprite/악플러/`가 아니라 공용 `sprite/body/`에 있으니 주의.** 여백이 다른 그림만 `hurt_head_scale`/`weary_head_scale`
  - **⚠️ `sprite/축법소년/축법소년 머리.png`가 폴더·git에 없이 임포트 캐시(`.godot/imported/*.ctex`)로만 존재한 적 있음**(게임은 멀쩡, 캐시 삭제·새 클론 시 사라짐) → `.ctex`(GST2 헤더 + offset 56부터 무손실 WebP)에서 원본 추출, `.import`를 두면 uid 유지돼 씬 참조 안 깨짐
- 지친 표정(`weary_head_texture`, 2026-09-10) = HP가 적은 동안 계속 걸리는 상태 표정: `weary_hp_ratio`(0.3) 이하면 지친 얼굴, 회복하면 복귀. 촉법소년(`힘든 축법소년.png`)·악플러(`악플러 힘듬.png`)·주정뱅이(`주정뱅이 힘듬.png`). 비면 스킵(여백 다르면 `weary_head_scale`)
  - `Fighter._update_hp_face()`가 `take_damage`/`heal`/`ring_out` **세 군데 전부**에서 `Visual.update_hp_ratio(비율)` 호출(하나라도 빠지면 회복 후에도 지쳐 보임)
  - 기본 머리 우선순위 **액션 표정 > 취함 > 지침 > 맨정신**(`BodyRig._apply_base_head()`), 그 위에 잠깐 표정(피격 > 토하기)이 덮이는 2층 구조
  - 취함이 지침보다 위(2026-09-10, 사용자 결정) — 술 스택이 토하기 사거리(0스택 40px ~ 3스택 970px)를 정하는 핵심 정보라 빈사에서도 취한 얼굴이 보여야 함 → 지친 얼굴은 "맨정신 + HP 적음"일 때만. 바꾸려면 `_apply_base_head()`의 두 elif 순서만 뒤집을 것
  - 주정뱅이 얼굴 다섯 장 중 셋이 동일 캔버스: 기본(1330x1182)·피격(1331x1181)·힘듬(1330x1182) 보정 없음, 취함·토하기(1254x1254)만 `drunk_head_scale`/`vomit_head_scale`
- 악플러 얼굴 3종(2026-09-10): `악플러 피격.png` / `악플러 분노.png`(열등감 발동 중, `action_head_texture`) / `악플러 힘듬.png`(HP 30% 이하), 셋 다 `AkpeulleoRig.tscn`에 보정 없이. `sprite/악플러/몸/악플러머리.png`·`몸통.png` = 원본 없이 `.import`만 남은 고아 파일. `sprite/악플러/몸/힘든 악플러.png`와 `sprite/악플러/악플러 힘듬.png` = 바이트까지 같은 두 장, 쓰는 건 `악플러 힘듬.png`
- 술 마시기 모션(주정뱅이 스킬1): `DrinkSkill` → `Visual.play_drink_motion()`(메서드 없으면 스킵). 고개 `drink_head_tilt_deg`(-22도, 음수=위를 봄), 오른손 `drink_hand_offset`(-16, -34)만큼 올라가며 `drink_hand_deg`(-116도) 회전. 다 올린 뒤 머리·병이 같은 `gulp` 값으로 함께 들썩임(`drink_head_bob` 2.5px, `drink_gulp_count` 3회). `drink_duration`(1.1초) 중 0~25% 올리기 / 25~75% 마시기 / 75~100% 내리기
- 마시기는 `_pose_attack_hand()`와 같은 자리에서 공격 다음에 덮어씀(겹치면 마시기가 이김). 머리 회전도 `_apply_pose`에서 매 프레임 0으로 되돌린 뒤 덮어씀(안 그러면 고개가 젖혀진 채 남음)
- 술병(`JujeongbaengiRig.tscn`의 `HandRHold/Bottle`) 제자리 `position (6.868347, -10.263336)` / `rotation -2.708751`(-155도) = 이미 붓는 자세. **(5,12)/-34도로 바꿨다 되돌렸으니 다시 건드리지 말 것.** 원본이 뚜껑 위인 세로 그림이라 회전 r일 때 병목 방향 = `(sin r, -cos r)`
- 제자리 각도가 이미 붓는 자세라 마실 때 추가 회전 없음(`drink_hand_deg` 0), 위치만 올림. 실측: 뚜껑 끝 (25, 11) → (15, -15)로 입 (15, -14)에 닿음. 올라가는 길은 `drink_hand_arc`(12px)만큼 바깥으로 부푼 호(이동 방향 수직 `sin(reach * PI)` — 출발·도착 0이라 안 튐)
- 히트박스를 내리치는 순간에 맞추려고 `MeleeAttack`에 `windup` 추가(기본 0, 주정뱅이만 0.16초)
- 흔들림·걸음 값 전부 `@export`: `foot_swing_deg`(22도) / `foot_stride`(8px) / `body_bob`(2px) / `hand_swing`(5px) / `step_speed`(9) / `blend_speed`(8) / `jump_foot_deg`(60도) / `jump_blend_speed`(12)
- 아직 안 된 것: 공격 모션

### 그림 파일을 교체할 때 (실제로 겪은 함정)

- **⚠️ 에디터 밖에서 PNG를 덮어써도 Godot이 재임포트하지 않음** → `.godot/imported/` 캐시 때문에 옛 그림이 그대로 나오고(크기·유효영역까지 옛 값) 새 배율이 옛 그림에 적용돼 조용히 어긋남 → 해당 `.png.import`를 지우고 `godot --headless --editor --path <프로젝트> --quit`로 강제 재임포트
- **그림을 바꾸면 `scale`·`position` 재계산할 것**: `유효영역(get_used_rect) x scale`이 예전과 같아지도록 배율을 잡고, `centered` 스프라이트는 유효영역 중심과 텍스처 중심의 차이만큼 position 보정
  - 예(지하철 아저씨 머리, 2026-09-06): 옛 1376x1143(유효 1136x953)·`scale (0.0528, 0.0577)` = 59.98x54.99 → 새 762x651(유효 698x597)이라 `scale (0.085932, 0.092107)` / `position (-1.48, -33.63)`
- 새로 받은 캐릭터 그림은 배경이 흰색인 경우가 많다. **"흰색이면 다 지우기" 금지, 바깥 테두리에서 번지는 flood fill로 지울 것** — 지하철 아저씨·층간소음 청년처럼 흰 머리카락이 있으면 단순 색상 제거로 머리카락까지 날아감(검은 외곽선에 막혀 flood fill은 안전)

### 일진 (2026-09-13 추가 — 7번째 캐릭터)

`characters/iljin/Iljin.tscn` + `IljinRig.tscn`, `stats/IljinStats.tres`(이동속도 275), 그림은 `sprite/일진/`.
`GameState`의 CHARACTERS·CHARACTER_COLORS(남색)·PORTRAITS와 `ui/PortraitFrames.tscn`(7번째 칸)에 등록 완료.

- **리그 값**: 머리 `일진머리.png` 배율 0.0481 / 위치 (-1.88, -34.05) = 화면 48.7px, 몸 `일진 몸.png` (0.035, 0.03968) = 33x30, 발 `일진발.png`(공용 발과 캔버스·모양이 같아 텍스처만 교체), 손은 공용
- **표정**: 피격 `일진 아픈`(0.0434) / 힘듬 `힘든일진`(0.0439) / 액션 슬롯은 **스킬이 그때그때 넣는다**(아래 함정)
- **기본공격(F)**: `attack_thrust` 3타 — 1·2타 주먹, **3타에 두 손으로 가방 내려찍기**. 평소 가방(`일진 무기.png` = 클러치백)은 **왼손에 가로로** 들고 있고(`HandL/BagIdle`, `show_behind_parent`로 손보다 뒤, 손은 `z_index 1`), 마지막 타에만 오른손 가방(`HandRHold/Bag`)이 나타난다
- **스킬1 담배 연기(G)** `CigaretteSmokeSkill.gd` + `CigaretteSmoke.tscn` — 쿨 10초. `windup`(0.45초) 뒤 입에 물고(손 담배 숨김 + 얼굴 `담배 일진`) `duration`(5초) 동안 앞으로 연기. `reach` 190px, 0.5초마다 2 데미지 + 넉백 (95, -35), 그동안 `start_busy`로 공격·스킬 잠김(이동은 됨). 연기는 맵에 붙고 매 프레임 입을 따라간다. 손 올리는 동작은 주정뱅이 마시기 모션 재사용(`drink_duration`을 windup x4로 맞추고, `drink_head_tilt_deg`는 0으로 꺼서 고개를 안 젖힌다)
- **스킬2 어깨 들이박기(H)** `ShoulderChargeSkill.gd` — 쿨 6초. 0.4초 x 560 = 최대 224px 돌진(얼굴 `신남일진`, `ChargeWind.gd` 바람 줄 + 잔상). 맞으면 **둘 다 같은 `launch_speed`(440 = 약 84px)로 뜨고 상대만 1초 기절**(`StunStars`). 가드로 막으면 안 뜬다. 돌진이 끝나면 `end_busy()`로 잠금을 바로 풀어 **평타 연계가 된다**
  - ⚠️ `take_damage`는 넉백을 기존 속도에 **더하므로**(`velocity.y +=`) 그냥 두면 둘의 높이가 어긋난다 → 받은 뒤 양쪽 `velocity`를 같은 값으로 덮어쓴다
- **공용 `BodyRig`에 넣은 기능 3개(전부 기본 꺼짐이라 다른 캐릭터는 영향 없음)**: `weapon_on_final_hit`(+`weapon_node`/`idle_weapon`/`final_hit_index`) = 마지막 타에만 무기를 쥔다, `set_charging()` = 돌진 자세(두 손 모으고 앞으로 기울기, 기울기에 facing 부호를 곱한다), `Fighter.end_busy()` = 잠금 즉시 해제
- **⚠️ 액션 표정 슬롯은 하나뿐이다.** 스킬이 `action_head_texture`를 런타임에 갈아끼우는 방식이라, **표정을 쓰는 스킬은 자기 얼굴을 직접 지정해야 한다**(`smoke_face` / `charge_face`). 안 그러면 앞서 쓴 스킬의 얼굴이 그대로 나온다(실제로 돌진 뒤 담배를 피우면 신남 얼굴이 나오는 버그가 났다)

## 스킬 로고 (쿨타임 HUD)

각 스킬 노드의 `Skill.icon`(`@export var icon: Texture2D`)에 그림을 넣으면 `ui/SkillCooldownIcon.gd`가 HUD 슬롯에 깔고 쿨타임만큼 아래에서 위로 차오르게 그림. 비우면 캐릭터 색 사각형이 같은 방식 — 로고 없어도 정상 동작하므로 그려진 것부터 넣으면 된다.

- 등록 현황: 주정뱅이 3개(`sprite/주정뱅이/스킬로고/1번·2번·궁극기.png`), 촉법소년 3개(`sprite/축법소년/스킬로고/잼민이G스킬.png`=스킬1 자전거 돌진, `잼민이H스킬.png`=스킬2 BB탄, `버릇없는꼬마궁극기로고.png`=궁극기). 나머지 4명 없음. 파일 이름의 G/H = P1 조작키(G=스킬1, H=스킬2)
- **로고는 투명 여백을 잘라서 넣을 것**: `SkillCooldownIcon._fit_bar()`가 원본 크기 전체를 슬롯(안쪽 약 40px)에 맞추므로, 여백이 크면 그림이 작아지고 치우쳐 있으면 구석으로 몰리며 물높이도 여백 기준이 돼 어긋남
  - 주정뱅이 로고는 유효영역 79~98%라 그대로 사용. `잼민이H스킬-Photoroom.png`(1339x1439)는 총이 가로 56% / 세로 44%만 차지하고 오른쪽 아래로 치우쳐(40px 슬롯에서 21x17px) → 유효영역 `Rect2(382, 445, 748, 627)`만 잘라 `잼민이H스킬.png`로 저장해 씀(Photoroom 원본 보존). `잼민이G스킬.png`는 93% x 75%라 원본 그대로

## 스킬 범위 미리보기 (에디터 전용)

`characters/SkillRangePreview.gd` — 캐릭터 씬에서 토하기 기둥·괴성 부채꼴이 몸의 어디서 어떤 크기로 나가는지 보여주는 `@tool` 노드. 주정뱅이 씬의 마지막 자식.

- 모양을 새로 그리지 않고 실제 효과 씬(`VomitBeam.tscn`/`ScreamCone.tscn`)을 그대로 띄움(에디터 = 게임 모양). 이를 위해 두 스크립트에 `@tool`과 `build_preview()`(판정·타이머 없이 도형만) 추가
- 붙이는 자식들은 `owner`가 없어 `.tscn`에 저장 안 됨. 게임 중엔 `Engine.is_editor_hint()`가 false라 `_ready()`가 바로 빠져나가며 자신을 숨기고 `_process`도 끔(검증: 자식 0개, 히트박스 0개)
- `_process`가 형제 스킬 노드(`Skill2`/`SkillUltimate`)의 `mouth_offset`·사거리 스냅샷을 들고 있다가 바뀌면 다시 만듦(효과 씬 쪽 값은 `Refresh` 체크박스로 다시 읽음)
- 스택별 노드: `토하는얼굴 / 토하기0~3 / 괴성`. 켜고 끄기는 씬 트리 눈 아이콘, 트리 순서 = 그리는 순서(뒤일수록 위, 얼굴이 맨 앞 — 게임에선 기둥이 맵에 붙어 캐릭터 위에 그려짐)
- **⚠️ 홀더를 뷰포트에서 끌고 늘려도 게임엔 반영 안 됨(2026-09-09)** → `토하기N`은 껍데기라 게임이 트랜스폼을 안 봄 → **`Apply Holders To Skill` 체크박스**를 누르면 홀더의 위치·배율이 `VomitSkill.stack_offsets`/`stack_scales`(게임이 읽는 값)로 옮겨가고 홀더는 원점·1배로 복귀(모양 그대로, 곱해 누적하므로 여러 번 눌러도 안 어긋남). **누른 뒤 씬 저장 필수**(값은 Output에도 찍힘)
  - `stack_scales` = x 길이 / y 두께, 판정도 같이 커짐(WYSIWYG). 그림만 밀려면 `stack_visual_offsets`(판정 안 움직임)
  - 미리보기와 게임이 같은 식 사용(`VomitSkill.spawn_offset()`/`scale_for()` ↔ `SkillRangePreview._scale_of()`/`_whole_offset_of()`) — **항상 같이 고칠 것**
- **⚠️ 에디터에서는 `@tool`이 아닌 스크립트의 메서드를 부를 수 없다** → 껍데기(placeholder) 인스턴스라 `Attempt to call a method on a placeholder instance` 에러로 함수 중단(`SkillRangePreview`가 `VomitSkill.visual_offset_for()`를 불러 미리보기가 통째로 안 만들어짐) → **export 변수 값 읽기는 되므로 필요한 값은 배열/변수로 직접 읽을 것**
- `VomitBeam`/`ScreamCone`이 `@tool`이라 에디터에서도 `_ready()`가 돈다. **시간·물리 의존 코드(`create_tween`, 레이캐스트)는 전부 `setup()` 안에만 두고 `build_preview()`에서는 부르지 않는다**

## 훈련장 (값 조정용)

`maps/TrainingGround.tscn` — 평평한 바닥에 캐릭터 하나만 세워두고 중력·점프력·이동속도를 슬라이더로 실시간 조절하는 개발용 방.

- 배경 눈금선 가로 100px / 세로 50px(500px마다 진한 선)
- 점프마다 최고 높이 / 체공 시간 / 수평 이동 거리 자동 측정해 패널 표시(중력 900·점프력 -450 기준 약 112px, 1.0초). `Fighter.max_jumps`(기본 2)만큼 공중 점프
- 조절 패널은 개발 도구라 `.tscn`이 아니라 `TrainingGround.gd`에서 코드로 생성
- **중요:** 이 화면을 위해 `Fighter.GRAVITY`/`JUMP_VELOCITY` 상수를 `static var Fighter.gravity`/`Fighter.jump_velocity`로 바꿨다. 전 Fighter 공유, 바꾼 값은 게임 종료까지 유지돼 로컬 대전에서 그대로 시험됨. **영구 반영하려면 `Fighter.gd`의 `DEFAULT_GRAVITY`/`DEFAULT_JUMP_VELOCITY`에 옮겨 적을 것**
- 이동속도는 캐릭터별 스탯(`stats/*.tres`의 `move_speed`)이라 훈련장에선 배수(`move_speed_multiplier`)로만 조절 — 확정되면 각 `.tres`를 고칠 것

## 궁극기 컷인 연출

`ui/UltimateCutIn.tscn` — 궁을 쓰면 카메라가 시전자에게 빨려들어갔다 컷인을 보여주고 돌아온 뒤 실제 궁이 나간다. `Stage.gd`·`maps/TrainingGround.gd`가 `_ready()`에서 심고 `Fighter`는 `ultimate_cutin` 그룹으로 찾는다(없는 씬이면 즉시 발동).

**기획 확정(임의로 바꾸지 말 것):**
- **전체 1.5초**(줌인 0.25 / 컷인 1.0 / 복귀 0.25, 전부 `@export`). **장면이 `cutin_duration`을 들고 있으면 그 값 우선**(`_hold`에 담고 `ramp_time`도 맞춤) — 잼민이 2.4초라 전체 2.9초
- **연출 중 시간 정지**(`get_tree().paused`, 컷인 노드만 `process_mode = ALWAYS`) / **스킵 없음** / **확정타 아님**(연출 시작 시점의 자리·방향으로 나가 빗나갈 수 있다)
- `Fighter.use_ultimate()`이 쿨 확인 후 연출 재생 → `Fighter.fire_ultimate_now()`가 발동(쿨타임도 이때 시작). 장면은 `CharacterStats.ultimate_cutin_scene`, 비면 이름만 뜨는 임시 화면
- **컷인은 파츠를 코드로 흔들어 만든다** — `ui/cutin/CutInAnimation.gd`가 자식 `Head`/`Body`/`HandL`/`HandR`에 `shake_max`/`shake_speed`/`zoom_in`/`red_tint`. 주정뱅이는 `ui/cutin/JujeongbaengiCutIn.tscn`
- **괴성은 컷인에서 지르지 않는다** — 컷인은 예비동작, 발성은 복귀 후 인게임 궁(판정 순간을 살리려고)

**악플러 컷인** `ui/cutin/AkpeulleoCutIn.tscn` + 전용 `AkpeulleoCutIn.gd`(공용 `CutInAnimation.gd`와 별개), 좌우 분할:
- 왼쪽 `악플러정면머리.png` + `악플러몸통.png`: `head_bob`으로 들썩, 어깨는 `body_bob_ratio`(0.35)만큼만, 끝으로 갈수록 `head_zoom`
- `TypeHandL`/`TypeHandR`: 반 박자 엇갈려 내려찍고 **가장 깊이 눌린 순간(`press > 0.6`)에만** `TapMarkL`/`TapMarkR` 효과선이 번쩍(계속 켜두면 효과선으로 안 보인다)
- `MonitorLight`: 모니터를 안 그리고 빛만으로. `CanvasItemMaterial.blend_mode = 1`(더하기)라야 "비춘다"로 보인다. **꼭짓점 `(-285, 560)`의 부채꼴 5겹**(Polygon2D엔 그라디언트가 없어 반지름·각을 줄이며 겹쳐 falloff를 흉내낸다)
- `Keyboard`: `modulate` 0.15(밝으면 회색 판), **`MonitorLight`보다 앞(먼저 그려지는 자리)에 둬야 빛을 받는다**
- 오른쪽: 댓글 5줄(`Comments/Comment0~4`의 `Text`)이 밀려들어와 쌓임 — `hold_time`(1.0초) 안에 다 뜨도록 `comment_start`/`comment_end` 비율로 배치
- **주의: 더하기 블렌드로 빛을 만들 때 하드한 도형은 "판때기"로 보인다**(사각형+막대, 타원+빛줄기 두 번 실패) → **한 겹으로 진하게 칠하지 말고 크기를 줄여가며 여러 겹을 옅게 겹칠 것**
- `ui/cutin/blur.gdshader`(3x3 가중평균 흐림, 재사용 가능): `blur_amount`는 **원본 텍스처 픽셀** 기준이라 크게 확대할수록 키워야 하고 **0이면 원본 그대로 통과**(악플러 컷인은 0)

**촉법소년 컷인** `ui/cutin/ChokbeopsonyeonCutIn.tscn` + `.gd`, **2.4초**(`cutin_duration`). 파츠가 아니라 **러프 3장 플립북**(배경이 같은 그림이라 이어져 보인다), `sprite/축법소년/궁극기컷인/1·2·3번프레임.png`(1619x915):
- **1번(0~26%, 0.62초)**: `Pellets/Pellet0~2`(`총알.png`)가 날아가고 발마다 화면 반동. 총구 `muzzle`(517, 151) = 그림 픽셀 (1440, 642) x 0.82 — **그림을 갈아끼우면 다시 잴 것**. `shot_spread`(0.8)를 1에 가깝게 키우면 마지막 총알이 화면 밖으로 나가기 전에 장면이 넘어간다
- **2번(26~64%, 0.91초)**: 대사 뒤 `exclaim_at`(31%)에 느낌표(`느낌표.png` 40x93, (250, -52))가 튀어나오며 `notice_punch`. **대사는 그림이 아니라 `ShoutText`(Label)**(인스펙터에서 문구 수정). `ShoutMark`(빨간 말줄) = 원본 `.paint`에서 "얼마나 빨간가"로 알파를 잡아 뽑은 `말줄.png`(65x112)
- **폰트 `fonts/Jua-Regular.ttf`(주아체)** — SIL OFL 1.1, 상업 이용 가능(**`fonts/OFL.txt` 동봉 필수**). 지금은 `ShoutText`에만 `theme_override_fonts/font`, **나머지 화면은 Godot 기본 폰트**(전체 적용은 `project.godot`의 `gui/theme/custom_font`)
- **`Frame2`·`ShoutText`·`ShoutMark`·`Exclaim`은 씬에서 `visible`을 켠 채 저장한다**(에디터 배치용, 게임에선 `_reset()`이 1번만 남김). **일부러 `visible = false`로 저장하지 말 것.** 대사 피벗은 `_ready()`에서 상자 크기 절반으로 다시 잡는다
- **3번(64~100%, 0.86초)**: `3번배경.png` + `Runner`(인게임 리그 `ChokbeopsonyeonRig.tscn` 인스턴스)라 팔·다리가 `BodyRig` 걷기 코드로 움직인다. `run_distance`(1100px) 달려 사라지고 `Dust/Dust0~2`가 남으며 화면은 `run_drift`·`run_zoom`, 머리는 `set_action_face(true)`로 `달리는 축법소년 표정.png`
  - **`BodyRig.manual_speed_ratio`**(기본 -1, 컷인 1.0): Fighter 없이 걷게 하는 값, **Fighter가 있으면 무시돼 인게임 동작은 그대로**
  - 리그 **배율 4.5 / 위치 (255, 231)**(3번프레임의 잼민이 503 x 0.82 = 412px, 발바닥 로컬 y 374). `scale.x` 음수로 왼쪽을 본다(`_face_moving_direction()`은 Fighter가 없으면 넘어가 부호 유지) — **음수라 회전이 반대로 보여 `run_lean_deg`가 양수다**
  - `3번배경.png` = `sprite/축법소년/궁극기배경.png` + 1번프레임 하늘(가로 1.054배 `scale = 1619/1536`, y 123px 올림, 사물 약 81%). **3번프레임에서 캐릭터를 지우고 메우는 건 무늬 때문에 세 번 다 실패.** 맞는 배경판을 그리면 `3번배경.png`만 교체(**3번프레임.png은 씬이 안 쓴다**)
- **교훈: 컷인에 캐릭터를 움직여 넣어야 하면 러프를 오려내지 말고 `characters/<캐릭터>/<캐릭터>Rig.tscn`을 먼저 볼 것**
- **배율 0.82는 흔들 여유용**(1327x750 > 화면 1280x720) — **0.79 밑이면 흔들 때 검은 여백이 보인다**
- 받은 3장의 하늘이 달라 프레임2 하늘로 통일했다(프레임2 하늘의 글씨·말줄·느낌표 x 880~1305 / y 160~420은 지움). 원본 `.paint`는 `C:\게임러프스케치\` — **다시 그릴 땐 세 장 다 하늘까지 칠해 주면** 합성이 필요 없다

## 게임 플로우 / 씬 전환

`GameState.gd`(프로젝트 루트, 오토로드 싱글턴)가 화면 사이에서 선택값을 들고 다닙니다.

- **소리는 `Sound/` 폴더.** `타이틀화면브금.mp3`(64kbps, 약 54초)·`타이틀클릭했을때나는소리.mp3`(256kbps, 약 2.2초)뿐
  - **브금 반복은 임포트 설정이 아니라 코드에서** — `TitleScreen._ready()`가 `AudioStreamMP3.loop = true`를 직접 넣는다
  - 전환: `Fade`가 걷히며(`enter_fade` 0.6초) 브금 시작 → 아무 키에 클릭 소리 + 어두워짐(`exit_fade` 1.4초) + 브금 페이드아웃 → 메인 메뉴. `exit_fade`는 **클릭 소리 2.2초를 보고 정한 값**(씬이 바뀌면 소리 노드가 사라져 끊기므로 짧으면 "띡" 하다 만다)
  - `Fade`(검정 ColorRect)는 **씬의 맨 마지막 자식**이라야 다 덮는다

**첫 화면(2026-09-01 개편):** `ui/TitleScreen.tscn`(제목 + "아무 키나 누르세요") → `ui/MainMenu.tscn`(왼쪽 메뉴 + 오른쪽 일러스트).

- **스토리/대전 모드는 확인 창을 거친다**(`ui/ConfirmPopup.tscn` + `.gd`). 창은 `confirmed`/`cancelled`만 내고 동작은 부르는 쪽이 `_ask(문구, 실행할_함수)`로 넘긴 `Callable`에 담긴다(어디서든 재사용)
  - **⚠️ 확인 창이 왼쪽 위 구석에 뜨면 앵커를 의심할 것.** 원본은 전체 화면인데 `MainMenu.tscn`에 인스턴스로 얹으며 `anchors_preset = 0`이 덮어써져 크기가 **0x0**, `CenterContainer`가 (0,0)에 패널을 놓았다. 고침: `anchors_preset = 15` + `anchor_right/bottom = 1.0` + `grow_horizontal/vertical = 2` 명시
  - **편집기에서 Control을 드래그하면 이 preset 덮어쓰기가 조용히 생긴다** — 전체 화면 오버레이(확인 창·페이드·컷인)를 옮긴 뒤 `.tscn`에 `anchors_preset = 0`이 끼지 않았는지 확인할 것
  - ① 열 때 직전 포커스를 기억해 **취소하면 되돌린다**(안 하면 방향키 조작이 끊긴다) ② ESC 뒤 `set_input_as_handled()`(**안 부르면 뒤쪽 메뉴 ESC까지 발동해 타이틀로 튕긴다**)
- **주의:** `.tscn`은 노드가 전부 나온 뒤 `[connection]`이 와야 한다(파일 끝에 노드를 덧붙이면 깨진다)
- 배경 `sprite/메인메뉴/배경프로토.png`(1672x941, 16:9)를 `TextureRect`(`stretch_mode = 6` KEEP_ASPECT_COVERED)로 깔고 `Scrim`(검정 45%) + `LeftFade`(가로 그라디언트 왼쪽 94% → 오른쪽 0%)를 덮는다(**없으면 버튼 글씨가 묻힌다**, 한 겹 50%로는 부족). 배경 세 겹 전부 `mouse_filter = 2`(IGNORE)
- **메뉴는 사선 5항목(2026-09-09)**: 스토리 모드 / 대전 모드 / **훈련장** / 조작 방법 / 설정(사용자 결정)
  - 구조 `Menu/<이름>Item`(Button, `flat`, **판정 전용·제자리 고정**) > `Slide`(Control, **보이는 것만 이동**) > `Shape`(TextureRect) + `Text`(Label). **판정까지 움직이면 호버가 덜덜 떨린다.** `mouse_entered`에서 `grab_focus()`를 주고 **연출은 포커스만 보고** 돈다(둘을 따로 보면 갈린다)
  - 도형 `sprite/UI/메뉴사선_임시.png`(620x84, 오른쪽만 40px 사선, 흰색) — **흰색으로 만들어 `modulate`로 색을 입힌다**(`menu_color`/`menu_color_focus`). 항목은 화면 밖 x -40에서 620px 뻗는다. **교체 규격: 1장을 5번 재사용**(따로 뽑으면 사선 각도·두께가 어긋난다) / **투명 배경** / **글자는 굽지 말 것** / 가운데는 밋밋할 것
  - **메뉴 글꼴은 아직 기본 폰트**(주아체 미적용) — 정해지면 `Text` 라벨 5개에 `theme_override_fonts/font`만
- **일러스트를 번갈아 보여주고 배경도 같이 바뀐다.** `Illust`로 시작하는 Node2D와 `Background`로 시작하는 자식을 트리 순서대로 모아 **index로 짝짓고** `illust_swap_seconds`(10초)마다 교체. 짝: `BackgroundJaemmin`<->`IllustJaemmin` / `Background`(`배경프로토.png`)<->`Illust`(주정꾼) / `BackgroundCatMom`(`캣맘찐배경.png`)<->`IllustCatMom` / `BackgroundSubway`(`지하철아저씨일러스트배경.png`)<->`IllustSubway`. **트리 순서 = 보여주는 순서**, 나타날 때 `restart()`가 있으면 부른다. 배경 전부 1672x941이라 위치 (717,312)·배율 0.86 동일
  - **일러스트를 추가하면 배경도 같이 추가할 것**(짝이 없으면 새 배경이 안 들어와 화면이 빈다)
  - 배경은 `ui/cutin/blur.gdshader`(`blur_amount` 6, ShaderMaterial 공유)로 흐리고 그 위에 `Scrim`·`LeftFade`. 전환은 `illust_fade_seconds`(0.9초) 크로스페이드(`modulate.a` 1->0 / 0->1)
  - 실행하면 `_collect_illustrations()`가 첫 장만 남기므로 **에디터 눈 아이콘은 게임에 영향 없다**
- **등장 연출(3프레임)은 뺐다(2026-09-08).** `EntranceFrame1/2`·`MainMenu.entrance_frame_time`·`_show_entrance_step()`·`_process()`·`MenuIllust.restart_breathing()` 삭제(되살리려면 `3a92276`). `팔내리고있는주정꾼.png`·`앞에소주든주정꾼.png`는 참조 없이 남음
  - **주의: 씬을 막 불러온 첫 프레임은 delta가 크게 튄다** — 시간 누적 연출은 앞부분이 밀린다. 다시 넣는다면 `minf(delta, 0.05)`로 상한을 둘 것

### 메인 메뉴 일러스트(파츠 분리)

- **주정꾼** `ui/MenuIllust.tscn` + `MenuIllust.gd`: 6장(몸통/아래쪽옷/머리/머리띠 3조각) — 몸통은 두 발 사이 축 세로 숨쉬기, 머리는 목 축 갸웃, 머리띠 3조각은 **시간차**를 두고 흔들림
  - **캔버스 1230x1278 -> 1230x1428(2026-09-08).** 잘린 술병 꼭대기 때문에 **위에 150px 덧붙임**(6장 동일, 원본 백업 `주정꾼_파츠/_원본캔버스_1230x1278/`, 병 윗부분은 `주정꾼잘생긴소주풀버전.png`에서 병 영역만으로 정렬해 이식)
  - **씬 보정: 회전축(Node2D `position`)은 그대로 두고 각 `Sprite`의 `position` y만 150 뺀다**(몸통 `-750,-1276` -> `-750,-1426`). **`MenuIllust.get_image_size()` 기본값도 1428**
- **잼민이** `ui/JaemminIllust.tscn` + `.gd`, `sprite/메인메뉴/일러스트/잼민이/`(1254x1254). 파츠 `_0003_레이어-1`(밑그림)/`_0002_오른쪽다리`/`_0001_머리`/`_0000_총과왼팔`, 씬 순서는 번호 역순(Body->RightLeg->Head->GunArm). 축: 목 (555, 368) / 허벅지 (709, 815) / **팔 단면 (430, 510)**
  - **주의: 총 든 팔은 "손+총"이라 축을 총구 쪽((695, 538))에 잡으면 안 된다**(까딱이 아니라 휘두르기) — **팔이 잘려나온 왼쪽 단면**에 둘 것
  - **팔 제자리 각도는 씬의 `GunArm.rotation`(-6도)** — `_arm_rest_rot`로 기억해 더하므로 **에디터에서 돌려놓으면 그 각도가 기준**(머리·다리도 동일)
  - 동작: 머리 들썩+갸웃 / **오른쪽 다리는 주기의 앞 35%에서만 톡톡 두 번**(`_tap_curve()`) / 왼팔은 어깨 축 까딱. **눈 깜빡임** `말썽꾸러기미남_눈감음.png`(`눈감은꽃미남잼민이.png`에서 눈·눈썹만 오려 7px 부풀림)을 `Head/EyeClosed`로 `blink_close`(0.11초)만, 간격 `blink_interval_min~max`(2.5~5.5초)
  - **밑그림은 `_0003`이 아니라 `말썽꾸러기미남_몸통.png`**(받은 `_0003`은 파츠가 다 든 통짜라 깔면 머리가 두 개로 보인다)
- **캣맘** `ui/CatMomIllust.tscn` + `.gd`, `sprite/메인메뉴/일러스트/캣맘/`(1140x1380). 손키스를 **내뱉기 전 -> 후**로 바꾸는 게 다른 점. 축: 목 **(545, 338)** / 허리 **(652, 545)** / 팔 단면 **(462, 624)**
  - **내뱉기 전은 통짜 `입덮은캣맘.png` 한 장**(팔 위치가 달라 파츠로 못 만든다), `PreSpit` <-> `Post`(파츠)를 `spit_fade`(0.14초) 겹쳐 교체. **`Post`를 미리 켜두면 안 된다**(내민 손이 PreSpit 밖 x 289~350으로 삐져나온다) — 기본 `visible = false`, `modulate.a = 0`
  - 구조 `Rig`(발 585,1372 축, 좌우 기울기) > `Body`(발 축 세로 숨쉬기) > `Post` + `PreSpit`. **파츠를 Body 자식으로** 둬야 어깨가 올라갈 때 팔도 따라간다. `Heart`만 Rig 바깥(허공 물건이라 숨결·기울기를 안 받아야 한다)
  - **머리는 `_0001_머리.png`가 아니라 `캣맘_머리_턱채움.png`**(받은 파츠는 턱이 y=332에서 잘려 있었다. `턱채운캣맘.png`의 흰 배경을 flood fill로 지우고 원래 파츠 알파와 합집합) → bbox **(358,12,733,338)**, 목 축 338. **턱을 또 고치면 `턱채운캣맘.png`를 고치고 파생 3개(`캣맘_머리_턱채움`/`캣맘_몸통`/`캣맘_머리_눈감음`)를 전부 다시 만들 것**
  - **눈 깜빡임** `캣맘_머리_눈감음.png`(`크기조정눈감은캣맘머리.png`에 **눈뜬 머리 알파를 씌워** 실루엣을 맞춤)을 `Head/EyeClosed`로. **눈감은 그림이 내뱉은 후 포즈뿐이라 입을 가린 동안엔 안 깜빡인다**. **눈감은 판은 눈뜬 판과 픽셀 단위로 크기가 같아야 한다**(다르면 머리가 튄다) — **실패 둘(반복 금지)**: 크기 다른 그림을 **합성**하면 윤곽이 이중(→ **알파 클리핑**으로 맞출 것) / **전체 그림**에서 턱까지 오려내면 턱 밑에 분홍 얼룩(그 자리가 목·옷깃이었다)
  - **하트는 메울 필요 없다**(허공이라 투명이면 됨). `캣맘_하트뺀판*.png`는 통짜로 돌아갈 때용
- **지하철 아저씨** `ui/SubwayIllust.tscn` + `.gd`, `sprite/메인메뉴/일러스트/지하철아저씨/`(1140x1380). 파츠 4장은 **끝부분만 잘려 있다**(`단소든오른팔`(팔뚝)/`아저씨왼팔`(손목)/`아저씨오른쪽조끼`/`아저씨의머리카락`). 축: 팔뚝 단면 **(138, 492)** / 손목 **(980, 800)** / 조끼 어깨 **(306, 509)** / 머리 **(496, 520)**, 발 축(Rig) **(414, 1378)**
  - **단소 끝이 축에서 636px이라 1도에 11px** — `danso_deg`를 2도 넘게 주면 휘두르기가 된다
  - **뻗은 손은 회전이 아니라 "커졌다 제자리"로만(`hand_push` 3.5%)** — 1.0배 아래면 손이 덮던 자리의 메운 얼룩이 드러난다(커지는 쪽으로만 움직이면 안전). **눈 깜빡임 없음**(선글라스). 하트는 `heart_from`(124, 22) → (316, 250) `easeOutBack` 뒤 `heart_bob`(9px)·`heart_pulse`(5%)
  - **(보류) 집중선**: `FxSubway` 노드만 뺐고 `ui/FocusLines.gd`·`sprite/.../지하철효과.png`·`MainMenu._pair_effect()`는 남아 노드 하나만 넣으면 살아난다. 되살릴 땐 **뒤집기(`jitter_flip`) 끄고 / `jitter_hz` 3~4 / 회전 0**(정신없던 원인 1·2·3위), 흔들림은 `randf()` 말고 **시간 기반 결정적 난수**, 자기 투명도는 **`self_modulate`**(크로스페이드가 `modulate`를 쓴다), 배치는 **배경 다음 / `Scrim` 앞**, 초점은 얼굴(약 926, 331), 등장 `burst_scale` 1.28 / 0.42초
  - **효과판은 index가 아니라 이름으로 짝짓는다** — "Illust"를 "Fx"로 바꾼 이름(`IllustSubway`<->`FxSubway`)을 `MainMenu._pair_effect()`가 찾고, 짝이 잡히면 켜기/끄기/페이드/`restart()`가 같이 간다

**파츠 공통 규칙**
- **파츠는 반드시 원본 캔버스 크기 그대로 내보낸다.** 포토샵 `File > Export > Layers to Files`에서 File Type을 **PNG-24**로 해야 `Transparency`/`Trim Layers`가 나오고 **`Trim Layers`를 꺼야** 모든 장이 같은 크기다. 그러면 `Sprite2D`를 `centered = false` + `position = -축좌표`로 두는 것만으로 원본과 픽셀 단위로 맞고, 감싼 Node2D(=축)를 돌리면 원하는 지점 중심 회전이 된다
- 파일 이름 번호는 **위 레이어일수록 작다**(`_0000_`이 맨 앞) — 씬에는 **번호 역순**으로 쌓을 것
- **뒤에 깔 몸통은 "원본에서 파츠 자리를 지운 그림"이어야 한다**(원본 그대로면 두 겹). 단 **그냥 지우면 파츠가 비켜났을 때 검은 구멍이 드러난다** → ① 바깥 배경에서 출발해 몸이 아닌 곳만 통과하는 flood fill로 **"원래 배경이던 자리"를 비우고** ② 몸에 둘러싸인 나머지만 테두리 색을 BFS로 번지게 **메운다**(①을 빼먹고 전부 메우면 빨간 얼룩이 남는다). 결과물 `주정꾼잘생긴버전_0005_몸통.png`, 잼민이·캣맘·지하철도 같은 방식(알파 2px 부풀려 지우고 BFS)
  - **구멍 안쪽은 얼룩덜룩하지만 파츠가 덮어 안 보이고 경계 부근은 정확하다** → **각도를 크게 주면(캣맘 머리 1.5도 초과) 안쪽 얼룩이 드러난다**
- **코드로 만든 그림(`캣맘_몸통`·`캣맘_머리_눈감음`·`캣맘_하트뺀판*`)은 에디터를 한 번 열어야 임포트된다**(안 읽히면 `_warn_missing()`이 Output에 찍는다)
- **일러스트는 Control이 아니라 `Sprite2D`**(Control은 앵커 레이아웃이 매 프레임 `position`을 되돌려 코드와 싸운다)
- **위치·크기는 씬(`Illust` 노드)에 저장돼 있고 코드는 안 건드린다**(`position (651.64, 70)` / `scale 0.485133` = 화면 597x620을 구워 넣어 **에디터에서 보이는 그대로가 게임 화면**). `auto_place_illustration`은 기본 **꺼짐** — 크기가 완전히 다른 일러스트를 넣을 때만 켜서 `illust_height`(620px)에 맞추고 값을 저장한 뒤 다시 끌 것
- `ui/breath.gdshader`: 한 장짜리 그림의 특정 타원만 부풀리는 셰이더. 지금 메뉴는 안 쓰지만 **파츠 분리가 안 된 일러스트에 쓸 수 있다**
- **주의: 화면을 덮는 배경이 마우스 클릭을 삼킨다.** `Control`의 `mouse_filter` 기본값이 `STOP`이라 전체 화면 `ColorRect`/`TextureRect`가 클릭을 먹고 `_unhandled_input`까지 안 온다(타이틀에서 키보드만 먹던 원인). `mouse_filter = 2`(IGNORE)로 통과 — **단, 버튼 자신에게 주면 클릭을 못 받으니 배경 레이어에만**

### 방 설정 / 조작 방법

- `ui/HowToPlay.tscn`은 키를 고정 문자열이 아니라 **`InputMap`에서 읽어온다**(재배정하면 표시도 바뀐다). 읽기 전용, 바꾸는 건 설정 > 조작 탭
- **`ui/RoomSettings.tscn`(2026-09-09 개편)**: 프리셋 3개(빠른 대전 1선승·1분 / 표준 2선승·무제한 / 장기전 3선승·3분) + 큰 카드 2장(`RoundsCard`/`TimeCard` — `[◀ 큰 값 ▶]` 스테퍼 + 한 줄 설명) + 아래 요약 한 줄. 배경은 메인 메뉴와 **같은 그림·같은 흐림**(`blur_amount` 6) + 스크림. 버튼 연결은 `[connection]`이 아니라 `_ready()`에서 코드로
- **주의: 주아체(Jua)에는 기호 글리프가 거의 없다.** `◀ ▶ ● ○ · × ↑ ↓`가 전부 없어 두부로 나온다(`~ / ( ) - | , .`는 있음). 그래서 방 설정 화살표 버튼 두 개만 **폰트 지정 없이 기본 폰트**로 뒀다. 주아체 라벨에 기호를 넣을 땐 글리프 유무를 먼저 확인할 것

**로컬 대전(PvP) 흐름:** `ui/TitleScreen.tscn`(아무 키) → `ui/MainMenu.tscn`("대전 모드") → `ui/RoomSettings.tscn`(선취 라운드 1~40, 시간제한 무제한/1~5분 → `GameState.rounds_to_win`/`time_limit_seconds`) → `ui/CharacterSelect.tscn`(P1→P2, `GameState.p1_character_path`/`p2_character_path`) → `ui/MapSelect.tscn`(선택 시 바로 그 맵으로) → 선택한 맵(`Stage.gd` 상속).

### 스토리 모드(2026-09-12 전면 개편 중)

옛 스토리(에피소드 선택 -> 캐릭터 선택 -> 대전 -> 개과천선 -> 클리어)는 **통째로 걷어냈다** — `EpisodeSelect`/`ReformCutscene`/`StoryClear`/`StoryIntro`, `GameState.STORY_OPPONENTS`/`STORY_MAPS`/`story_index`/`story_cleared`와 진행도 함수, `CharacterSelect`·`Stage`의 스토리 분기 전부 삭제(2026-09-12 이전 커밋에 있음).

흐름: `ui/MainMenu.tscn`("스토리 모드" -> 확인) -> `StoryScene1`(경찰서 앞) -> `StoryScene2`(간판) -> `StoryScene3`(대화) -> `StoryScene4`(장소 카드) -> `StoryScene5`(놀이터 배경, 지금 마지막). 장면은 `ui/story/StoryFadeScene.gd` 하나로 돈다: **페이드인(`fade_in_time` 1.2초) -> 머묾(`hold_time` 1.5초) -> 페이드아웃(`fade_out_time` 1.2초) -> `next_scene`**(비면 페이드인한 채 멈춤). ESC는 어디서든 메인 메뉴로.

- **`Fade`(검은 ColorRect)는 항상 트리 맨 마지막 자식**, **씬 파일에선 투명(알파 0)으로 저장**(불투명이면 에디터가 까매져 배치를 못 한다). 게임에선 `_ready`가 시작 알파를 정한다(검은 화면이면 1, 크로스페이드면 0)
- **에디터에서 보며 배치하고 게임에선 나중에 나타나는 노드**(사건 파일·도장)는 씬에서 보이게 두고 루트의 `hide_on_start`에 넣는다(@show/@stamp로 띄움). `reveal` 노드(인물·대화창)는 시작 때 강제로 보이게 — 에디터 눈 아이콘 상태는 게임에 영향 없다
- **도장 위치(사용자가 직접 정함):** `ui/story/StoryScene3.tscn` > `CaseFile/Paper/Stamp`를 2D에서 끌거나 Transform의 Position(화면 1280x720 픽셀, 종이는 대략 x 33~1246 / y 71~644)/Rotation/Scale로. **놓아 둔 모습이 찍힌 뒤의 최종 모습**(@stamp는 2.3배에서 줄어든다). 지금 값 (1059, 498), -18°, 0.22배

**화면 전환(2026-09-12 확정):** 메인 메뉴 -> 1번 = 검은 화면에서 밝아짐 / 1번 -> 2번 = 0.7초 크로스페이드 / 2번 -> 3번 = **검은 화면**(2번 `out_transition` BLACK, 3번은 1.2초 밝아짐) -> 경찰이 살짝 올라오며 등장 -> 대화창이 뒤따라(`reveal`, 0.35초 간격)
- 크로스페이드: 나가는 장면(`out_transition = CROSSFADE`)이 직전 화면을 찍어(`get_viewport().get_texture().get_image()`) `StoryFadeScene`의 **static 변수**에 두고(autoload 회피), 들어오는 장면이 `_ready`에서 맨 위(마지막 자식 TextureRect)에 덮고 `crossfade_time` 동안 투명하게. 3초 넘은 사진·ESC로 나갈 때는 버린다. 그 0.7초는 사진이라 구름·사람이 멈춰 보인다(거의 티 안 남)
- `reveal` 노드는 전환이 끝난 뒤 투명 -> 불투명, `reveal_rise`(18px) 아래에서 제자리로. 대화창은 다 나타나기 전(`modulate.a < 0.99`)엔 스페이스바를 안 받는다. **앞으로 인물 등장에도 `reveal`을 쓸 것**
- (확대 연출은 뺐지만 `StoryZoomView`의 `zoom_delay`/`accelerate`는 기능으로 남음)

**1번 = 경찰서 앞.** `PoliceStation`(Node2D, 1536x1024 그림을 0.8333배로 1280폭에 맞추고 위아래 80px(그림 기준)씩 잘림) 밑에 뒤에서부터 `Sky` -> `Clouds`(8개) -> `Building` -> `Flags`(3개), `hold_time` 1.5초
- 원본 `sprite/storymode/연출용사진모음/`(`레이어-0` 통짜, `레이어-1~6` 구름, `첫번째깃발`/`레이어-7`(태극기)/`3번째깃발`)은 안 건드리고, 게임용 `경찰서_하늘.png`(구름 자리를 하늘색으로 메운 판)·`경찰서_건물.png`(하늘 뺀 건물·나무·땅, 깃발 자리는 주변색)을 `sprite/storymode/경찰서/`에 만들었다(지금 생성 입력은 `찐막_*.png`)
  - 에셋 주의(다시 만들 때): **파츠에 이어져 있던 구름 가장자리 조각**은 통짜에서 하늘을 빼(color-to-alpha) 그 파츠에 붙인다(bbox 안 흰 픽셀만 지우면 이어진 구름이 가로로 잘린 채 하늘에 남는다) / **구름7(레이어-8)만** 둘레 하늘·건물 윤곽선이 딸려와 하늘 flood·흰 픽셀만 남기고 color-to-alpha — **다른 구름에 걸면 파란 테두리까지 투명해지니 걸지 말 것** / **구름8(레이어-9)**은 레이어-8과 겹치는 픽셀을 뺐다(두 번 그리면 진해진다) / 검증은 첫 화면 합성 vs 원본(평균 차이 0.17, 크게 다른 픽셀 0.5%)
- 구름 `ui/story/DriftingClouds.gd`: `Clouds` 밑 Sprite2D를 `speed`(14px/초, 그림 픽셀 기준)로 오른쪽으로 흘리고 화면 밖으로 나가면 왼쪽에서 다시 들어온다(화면 끝은 매 프레임 뷰포트에서 역산해 `PoliceStation`을 옮기거나 키워도 맞는다). 캔버스에서 잘린 구름(1·7·8 왼쪽, 4·6 오른쪽 — 메타데이터 `cut_left`/`cut_right`)은 `ui/story/CloudEdge.gdshader`로 단면을 흐린다(왼쪽은 움직인 거리 x1.5, 최대 `edge_fade` 60px / 오른쪽은 한 바퀴 돌아 들어올 때부터, 폭은 줄마다 0.2~1.8배)
  - **흐림을 그림에 굽지 말 것** — 구워두면 첫 화면에서 화면 끝 구름이 깎여 보인다
  - **구름 노드 순서 = 포토샵 순서의 반대**(번호 `0000`이 맨 위 레이어). 트리에선 `Cloud8`(레이어-9, 0010) -> `Cloud7`(레이어-8, 0009) -> `Cloud6`(0005) 순으로 앞(뒤에 그려짐), `Cloud1`(0000)이 맨 끝. **순서를 바꾸면 겹친 자리가 파란 얼룩처럼 보인다**
  - 파츠에 이어지지 않은 떨어진 조각은 하늘 판에 남아 **안 움직인다**. 머무는 시간이 짧아(약 4초) 구름은 50px쯤만 흐른다
- 깃발 `ui/story/FlagWave.gdshader`(깃발마다 따로): 깃대 선(`hoist_x0`, `hoist_slope`, 잘라낸 그림 픽셀 좌표)은 고정, 멀어질수록 최대 `amplitude`(3px)만큼 물결치며 밝기 변화. 셋의 `wave_speed`/`phase`를 어긋나게 뒀다

**2번 = 민폐퇴치부 간판.** 크로스페이드(0.7초)로 들어와 `hold_time` 1.9초(사용자 지정) 뒤 **검은 화면으로**(1.2초) 3번으로. `Office`(`ui/story/StoryZoomView.gd`) 밑에 뒤에서부터 `Plate`(배경) -> `People`(6명) -> `SignBand`
- **지금 = 사람들이 흔들림 없이 걷는 방향으로 조금만 미끄러지고 화면은 1.05 -> 1.08배로 거의 티 안 나게 확대**(**싫어했던 진짜 이유는 움직일 때 옛 자리에 윤곽이 남는 것**이었다)
- 원본 한 장짜리 `Still` 노드(`민폐퇴치부일러바꾼버전/..._레이어-0.png`)는 숨겨 뒀다 — 켜고 `Plate`/`People`/`SignBand`를 끄면 움직임 없는 원본. `StoryZoomView`엔 `pivot_to`(확대하며 초점 이동)와 그림 밖 검은 바탕을 가두는 처리가 있다
- 원본: `sprite/storymode/민폐퇴치부일러바꾼버전/*_사람레이어분리버전_*.png`(사람 6명 + `레이어-0` 통짜), `sprite/storymode/경찰서/민폐퇴치부간판_사람없는버전.png`. 게임용은 `sprite/storymode/민폐퇴치부/`
- 에셋 만드는 법(다시 만들 때만 필요): **배경 = 통짜 + 움직이는 6명 자리만 사람없는 판**(통째로 쓰면 레이어로 안 나눈 사람들까지 사라진다), 사람없는 판이 그림자까지 밝게 칠해져 있어 발자국 바깥 고리의 차이를 안쪽으로 퍼뜨려 더하고 **경계는 차이 30 미만인 바닥에서 12px에 걸쳐 섞는다**. **사람 = 레이어 + 번짐**(레이어 알파가 모션 블러보다 좁아 옛 자리에 윤곽이 남는다) — 두 판이 다른 레이어 둘레 12px(머리 위 3px)을 **가장 가까운 사람 색**으로 붙인다
  - 규칙 셋: **여섯 명의 번짐·그림자는 한꺼번에 키울 것**(차례로 키우면 앞 사람 그림자가 옆 사람 번짐을 먹어 하얀 테두리가 남는다) / **바닥 그림자는 사람에게 안 붙인다**(밝은 띠가 드러나고 옆 사람 몸을 그림자로 착각한다, 사람은 최대 20px만 이동) / **번짐 색을 "원본 - 바닥"으로 계산하지 말 것**(밝기 차까지 끌고 와 하얀 톱니 테두리)
  - **확인: 첫 화면 합성 vs 원본(평균 차이 0.24) + 다 걸은 뒤(최대 이동) 합성을 확대해 옛 자리 윤곽을 볼 것**(첫 화면만 보면 이 문제가 하나도 안 보인다)
- 걷기 `ui/story/StoryWalker.gd`(Sprite2D, **노드 위치 = 발 밑**이라 크기·기울기가 발 기준): `walk`(총 이동 px) / `walk_time` 8초 / 마지막 `stop_time` 1.5초 동안 서서히 멈춤 / `grow`(멀어지면 -). `bob`·`sway_deg`는 기본 0으로 꺼짐. 다리 동작이 없어 실제 속도로 밀면 종이 인형처럼 보이니 수십 px만. **멈추는 이유:** 오래 머물면 잘린 단면이나 화면 밖까지 간다(지금 약 3.8초 = 0.7+1.9+1.2라 절반쯤만 움직인다)
- 캔버스 아래에서 잘린 사람(경찰관1·2, 화면아래-남직원, 왼쪽끝직원)은 위로 **약 19px(1.05배 확대로 생긴 여유 22px 안)까지만** — 넘으면 잘린 단면이 보인다(`StoryZoomView.zoom_from`을 1.05보다 줄이면 여유도 준다)
- `SignBand`(간판 아래 모서리 띠, 선 두께 5px 포함)를 사람들 위에 덮어 여비서1이 간판 **뒤로** 들어가게 한다
- 남은 흠: 멀어지는 사람(입구쪽남직원, 경찰관1)이 발을 뗀 자리와 여비서1 머리 오른쪽에 옅은 얼룩 — 그 사람의 `walk`를 줄이거나 사람없는 판 밝기를 원본에 맞추면 준다

**3번 = 경찰서 안 대화.** 배경 `sprite/storymode/경찰서/대화창경찰서배경.png`(1448x1086을 0.884배로 가로에 꽉, 위쪽 기준 — 아래 바닥은 대사창 뒤), 가운데 경찰 `경찰초기일러 (2).png`(0.613배, 머리 꼭대기 y=33, 몸 중심 x=664). 흐름: "오늘이 이 부서에서 근무 첫날인가..." -> "아 벌써 새 사건이 들어왔군" -> **사건 파일이 화면을 덮음**(`CaseFile` = 검정 80% `Dim` + `사건파일양식.png`를 비율 유지해 화면에 다 들어오게 맞춘 `Paper` — 꽉 채우면 가장자리·칸이 잘린다), 대화창은 그대로 -> "이런 이거 지독하네" -> "당장 출동해야겠어" -> 대화창이 사라지고 파일만 남음 -> **수사착수 도장이 비스듬히 쾅**(`Stamp` = `수사착수도장.png`, 2.3배에서 0.14초 만에 줄며 찍히고 종이가 흔들림) -> 0.8초 뒤 대화 끝 -> 검게(`fade_out_time` 1.0) -> 4번

**4번 = 장소 카드.** `ui/story/StoryScene4.tscn` — 검은 화면 가운데 작은 "사건현장"(옅은 노랑 24) + 큰 "놀이터"(흰색 56, 나눔고딕). 0.3초 쉬고 부제가 서서히 -> 이름이 초당 8자로 한 글자씩 -> 1.2초 머묾 -> 검게(0.8초) -> 5번. 재사용 부품 `ui/story/LocationCard.tscn`(+`.gd`) — `subtitle`/`title`/`chars_per_second`/`hold_time`. `StoryFadeScene.dialogue`에 지정하면 카드가 끝나야 넘어간다(`_dialogue_done`은 `is_finished()`만 있으면 대화창·카드 둘 다 받음)
- 비주얼 노벨 장소 전환 3방식: ①검은 화면+장소 이름(챕터 시작·현장 도착) ②새 배경 위 모서리 장소 띠(자잘한 이동) ③표시 없이 전환. 현장 도착은 ①, 한 현장 안 이동이 생기면 ②를 섞기로

**5번 = 놀이터 배경(지금 마지막).** `sprite/메인메뉴/일러스트/잼민이/잼민이일러스트배경.png`을 TextureRect로 꽉 차게(`stretch_mode = 6`), 흐림 셰이더는 안 씀. 게임 맵 놀이터가 아니라 **잼민이 일러스트 배경**(사용자 지정)

**대화창 초기 형식(사용자 지정, 앞으로 계속 쓸 것): 화면 아래 전체 폭 큰 대사창(높이 156) + 그 바로 위 왼쪽 작은 이름창(280x63), 둘 다 반투명 회색.** 글자는 나눔고딕(이름 27 옅은 노랑, 대사 26 흰색)
- 재사용 부품 `ui/story/DialogueBox.tscn`(+`.gd`): 인스턴스로 올리고 `speaker`/`lines`만 채운다. **스페이스바로만** 진행(클릭·엔터 안 됨, 꾹 누른 반복 입력 무시), 다 넘기면 `finished`. 대사 앞에 `이름|`을 붙이면 그 줄부터 화자 변경(예: `민원인|저기요`), 화자가 비면 이름창을 숨긴다(내레이션). `StoryFadeScene.dialogue`에 지정하면 대사를 다 넘기고 hold_time도 지나야 다음 장면
- **대사는 한 글자씩 찍힌다.** `chars_per_second` 28, 문장부호(. , ! ? … ~) 뒤 `punct_pause` 0.12초 추가. 찍히는 중 스페이스 = 한 번에 다 보여주기, 다 나온 뒤 = 다음 대사. 대화창이 다 나타난 뒤부터 찍고, `visible_characters_behavior = VC_CHARS_AFTER_SHAPING`이라 줄바꿈 위치가 안 흔들린다
- **명령 줄**: `lines`에서 "@"로 시작하는 줄은 대사가 아니라 명령 — 스페이스 없이 바로 실행하고 다음 줄로. `@show 노드 [초]`(서서히 나타남, 기본 0.4초, **다 나타난 뒤** 다음 대사) / `@hide 노드 [초]` / `@close [초]`(대화창을 서서히 없앰 — 뒤에 줄이 없으면 대화 끝, 대사가 오면 다시 나타남) / `@waitkey`(닫힌 상태에서도 스페이스 대기) / `@pause 초` / `@stamp 노드 [초]`(도장 쾅 — Node2D만, 씬에 놓은 크기·각도가 최종 모습, 2.3배·10° 더 돌아간 채 나타나 가속하며 줄어 찍히고 부모가 짧게 흔들림). 시간이 걸리는 명령은 끝난 뒤 다음 줄로, 노드는 장면 루트 기준 경로. **대화창을 끊지 않고 같은 장면 안에서 화면을 바꿀 때** 쓴다(장면을 바꾸면 대화창이 끊긴다). 연출 중엔 글자도 안 찍고 스페이스도 안 받는다
- 대화창 컨트롤은 전부 `mouse_filter = 2`(무시) — 나중에 클릭으로 넘기려면 클릭이 `_unhandled_input`까지 와야 해서. **장면 루트 Control도 무시로 둘 것**
- 글꼴 **나눔고딕**(`fonts/NanumGothic-Regular.ttf`, Google Fonts 공식 저장소, OFL). 다른 UI는 여전히 주아체
- **이름창과 대사창은 확 구분되게**: 이름창 = Color(0.08,0.08,0.1,0.88) + 왼쪽 6px 노란 강조 줄(`Accent`) + 옅은 노란 글자, 두 창 사이 6px 틈, 대사창 = Color(0.22,0.22,0.24,0.62) + 위쪽 2px 밝은 선(`TopLine`)
- `GameState.game_mode = "story"`는 그대로 쓴다 — `Stage`가 P2를 AI로 붙이고 `FighterPanel`이 P2 조작키를 숨기는 모드 구분 장치라 새 스토리에 대전을 붙일 때 다시 쓸 수 있다

### 훈련장 흐름 / 대전 진행

**훈련장:** `ui/TitleScreen.tscn` → `ui/MainMenu.tscn`("조작 방법") → `ui/HowToPlay.tscn`("훈련장에서 해보기") → `maps/TrainingGround.tscn`. 캐릭터·맵 선택을 거치지 않고 바로 들어가고 캐릭터는 안의 드롭다운으로 바꾼다(바꾸면 그 자리에서 다시 스폰). 상대·라운드·시간제한·HUD가 없어 `Stage.gd`를 상속하지 않는 독립 씬

- 캐릭터·맵 후보는 `GameState.CHARACTERS`/`GameState.MAPS` 딕셔너리 하나로 관리 — 한 줄만 추가하면 선택 화면에 자동으로 나타남
- 모든 화면에 ESC(`ui_cancel`) 탈출구: 모드 선택→메인 메뉴, 방 설정→모드 선택, 캐릭터 선택→방 설정, 맵 선택→캐릭터 선택, 스토리 장면→메인 메뉴, 대전 중→메인 메뉴(버튼도 동일)
- **라운드제:** `Stage._process()`가 KO(HP 0) 또는 시간 초과(`GameState.time_limit_seconds`>0이고 다 됐을 때 — 그 순간 HP 높은 쪽 승, 동률이면 무승부)를 감지하면 `_end_round(p1_won, is_draw)`. 승수는 `GameState.p1_round_wins`/`p2_round_wins`에 누적, `rounds_to_win` 미달이면 `MatchResult.show_round_result()` 배너 뒤 `get_tree().reload_current_scene()`(HP·위치 초기화, 승수는 오토로드라 유지). 도달하면 `MatchResult.show_result()`/`show_draw()` 또는 스토리 승리 시 `ReformCutscene`
- `CombatHUD`는 중앙 상단에 **남은 시간 박스**(`TimerFrame` > `TimerBox` > `TimerLabel`) + 그 아래 `RoundLabel`. `Stage`가 `combat_hud.update_round_info(p1_wins, p2_wins, time_left)`로 매 프레임 갱신 — **시간 제한 없음(0)이면 `TimerFrame`이 숨겨지고** 10초 이하면 숫자가 빨개진다
- `maps/Stage.gd`는 `_ready()`에서 `GameState`가 가리키는 캐릭터 씬을 `PlayerSpawn1`/`PlayerSpawn2`에 동적 생성. P1은 항상 `PlayerController`, P2는 `GameState.game_mode`가 스토리면 `ClaudeAIController` / pvp면 `PlayerController`. 새 맵은 바닥·벽(or 링아웃용 빈 공간)·`PlayerSpawn1`/`PlayerSpawn2`·`Camera2D`(`maps/CameraRig.gd`)·`CombatHUD`만 배치하면 된다
- 승패: `Stage._process()`가 매 프레임 양쪽 `current_hp`를 직접 확인(HP 0 또는 `ring_out()`). **`died` 시그널에 바로 반응하지 않는 이유:** 같은 프레임에 동시에 쓰러져도 먼저 처리된 쪽이 임의로 승자가 되는 버그가 있었다 — 지금은 그 프레임 데미지가 다 반영된 뒤 한 번에 판정해 양쪽 0이면 무승부. 링아웃은 `Stage.ring_out_y` 아래로 떨어지면 발동(벽 있는 맵은 사실상 발동 안 됨)
- 히트 이펙트: `Fighter._flash_hit()`가 잠깐 빨갛게 물들이고 `combat/Hitbox.gd`가 `combat/HitSpark.tscn`을 스폰
- 상태별 색조는 `Fighter.set_tint(id, color, duration)`/`clear_tint(id)` — 여러 개가 걸려도 스택처럼 쌓였다 하나가 풀리면 밑에 깔린 색으로 돌아간다(`set_modifier`와 같은 발상). 스킬 9종 전부 적용: `DashSkill`·`BBGunSkill`·`HealSkill`, `TauntSkill`·`RageBuffSkill`·`WeakenAuraUltimate`, `DrinkSkill`·`VomitSkill`·`ScreamConeUltimate`
- 넉백: `MeleeAttack`/`Projectile`이 `Hitbox.knockback`을 설정해 맞은 캐릭터 `velocity`에 즉시 더한다(`Fighter.take_damage`). 바운스어택 콤보의 기반 — 스킬별 세밀 조정은 아직(전부 임시값)
- 대전 시작 시 `ui/RoundStart.tscn`("3, 2, 1, FIGHT!") 동안 양쪽 컨트롤러가 멈춘다(`is_active`). **주의:** `set_physics_process(false)`로 멈추면 직전 프레임 관성(velocity.x)이 남아 미끄러진다 — `is_active=false`일 때도 `apply_physics`는 돌리되 `fighter.move(0.0)`으로 수평 속도를 매 프레임 0으로 고정할 것

### 주정뱅이 술병 타격 연출

- **술방울 튀기기 `combat/LiquorSplash.gd`(2026-09-12, 장식 — 판정 없음)**: 콤보 **마무리 3타에만** 술방울 6~12개가 때린 방향으로 튀고 0.6초 안에 사라진다(바닥에 닿으면 퍼져 안 쌓인다). 그림 없이 `_draw()`(작은 원 + 검은 테두리). 매 타 유리 파편이 떨어지던 예전 방식을 대체
- **8번 맞히면 소주병이 깨진다(2026-09-12).** 손의 병이 `sprite/주정뱅이/꺠진소주병.png`로 바뀌고 **`combat/GlassShard.tscn` 5개**가 터진다. **성능은 똑같고(연출만) 라운드 끝까지 깨진 채**(씬 리로드로 다음 라운드엔 새 병)
  - **맞힌 횟수만 센다** — 헛친 것·스킬로 맞힌 것은 안 세고(기본공격 히트박스의 `connected` 신호만), 방어에 막힌 한 방은 센다
  - 손잡이는 `BasicAttack`(`ComboMeleeAttack`)의 export: `break_after_hits`(8) / `broken_item_texture` / `break_debris_scene` / `break_debris_count`(5). **0이면 안 깨지므로 다른 캐릭터는 영향 없다**
  - 교체는 `BodyRig.swap_held_texture()`가 `HandRHold`의 첫 Sprite2D 텍스처만 바꾼다. **위치·각도·배율은 안 건드리므로 두 그림의 캔버스가 같아야 한다** — `꺠진소주병.png`는 `소주병.png`(1254x1254)에서 병목만 지운 **코드로 만든 임시 그림**(화면 14.1x39.6 -> **14.1x26.5px**). 제대로 그린 그림이 오면 **같은 캔버스 1254x1254로** 덮어쓰면 된다
  - 실측(헤드리스): 8번째에 그림이 바뀌고 파편 5개 스폰, 10번을 때려도 한 번만 깨진다
- `sprite/주정뱅이/스킬로고/유리조각*.png`와 `GlassShard.gd`는 계속 쓴다(병 깨질 때만 5개, 바닥까지 떨어져 10초 뒤 사라짐)
- **술 스택이 많을수록 많이 튄다**(`drops_per_power` 2개/스택, 3스택 12개) — `Hitbox._spawn_debris()`가 `custom_data["drink_stacks"]`를 읽어 `burst_power`로 넣는다. 타별 스위치는 `Hitbox.debris_enabled`(씬에 저장 안 되는 런타임 값)이고 `ComboMeleeAttack._fire()`가 `debris_final_hit_only`(기본 켜짐)를 보고 넣어준다. 다른 캐릭터는 `debris_scene`이 비어 영향 없다

## 맵 기믹

- `maps/PassingTrain.gd` (`maps/SubwayTrack.tscn`): 제자리에서 켜졌다 꺼지는 **판정만 있는** 열차(경고 → ON → OFF). 아직 폴리곤 — `Metro!.png`로 교체 가능
- `maps/SubwayTrain.gd` + `.tscn` (`SubwayPlatform.tscn`의 `DecoSubwayTrain`): 선로를 가로지르는 열차. 조절은 전부 인스펙터 — `interval`(**30초**, "도착에서 다음 도착까지" — 출발 순간 `_timer = interval`로 채워 통과 시간 포함) / `first_delay`(12초) / `warning_duration`(경고등·음악, **5초**) / `speed`(950) / `damage`(12) / `hit_interval`(0.35초) / `knockback_push`(420) / `knockback_lift`(260) / `travel_x`(±1200) / `alternate_direction` / `arrival_music`(비어 있음 — 넣으면 5초 전 재생)
  - **부딪히면 계속 밀린다** — `Hitbox.repeat_interval`로 0.35초마다 재타격, 넉백 `Vector2(knockback_push * 진행방향, -knockback_lift)`. 판정이 지붕까지 덮어 올라타도 튕겨 나간다(기획 확정 4·5)
  - **창문 불빛:** **창문만 밝게 구운 그림**(`sprite/맵/지하철역/열차창문빛.png`)을 `Body/WindowGlow`로 얹고 `blend_mode = 1`(더하기) 합성. 캔버스가 `region_rect`(2101x250)보다 **사방 70px 크고**(2241x390) 둘 다 `centered`라 **여백을 좌우 다르게 주면 어긋난다**. 마스크는 `Metro!.png`의 창문 13개 — **그림을 다시 그리면 마스크와 `WINDOW_RECTS`도 다시 뽑을 것**
  - **⚠️ `CanvasModulate`가 가산 광선 색까지 곱한다.** 그림은 **미리 보정한 (255,196,92)** 로 구웠고, 맵을 밝힌 뒤(2026-09-11)엔 다시 굽지 않고 `WindowGlow.modulate` RGB를 `(0.625, 0.644, 0.729)` = **옛 조명 ÷ 새 조명**으로 줘서 더해지는 양을 맞췄다(코드는 `modulate.a`만 건드린다). 맵 조명을 또 바꾸면 `WindowGlow.modulate`·`beam_color`·형광등 `glow_color`를 **원하는 최종색 ÷ 새 조명**으로 다시 잡을 것
  - **창문 빛이 벽에 비친다:** 사다리꼴 빛기둥(`Polygon2D`)을 `WINDOW_RECTS`로 `_ready()`에서 코드 생성, 끝은 `vertex_colors`로 투명. 더하기 블렌드는 컨테이너에 걸고 자식은 `use_parent_material`, 컨테이너는 `body.move_child(..., 0)`으로 **Car보다 앞 순서**(위에 얹으면 반투명 판때기)
    - **⚠️ `beam_spread`를 크게 주면 안 된다**(0.5면 옆 창문과 겹쳐 하얗게 뜬다). 지금 0.1. **`beam_tilt`(0.35)는 중심에서 멀수록 바깥으로 눕히는 별개 값**. **`beam_down_length`는 0**(열차가 바닥 y=300에 붙어 아래 빛은 가린다)
    - `beam_length_variance`(0.35)로 창문마다 높이가 다르고 **출발할 때마다(`_begin_run`) 기존 `polygon`만 재계산**한다(`_beams`가 창문·방향을 들고 있다). 나머지: `window_glow`(1.0)/`window_flicker`(0.09)/`window_flicker_speed`(16)/`beam_up_length`(230)/`beam_alpha`(0.68)/`beam_color`
  - 운전실이 **왼쪽**이라 `_apply_direction()`이 `body.scale.x = -_direction`으로 **부호를 뒤집는다**(판정은 대칭이라 무관)
  - **AI가 이 기믹을 피한다:** `is_dangerous()`가 WARNING/RUNNING이면 true + `_ready()`에서 `add_to_group("ai_danger_zone")` → `AIController._try_dodge_hazard()`가 `"ai_safe_spot"` 그룹(`maps/AISafeSpot.gd`, 빈 Marker2D에 붙이기만) 중 가까운 곳으로 가 이단 점프로 올라타 버틴다(`AISafeSpotLeft`/`Right`, y=155). **캐릭터·맵 이름 분기 없이 두 그룹만으로 판단하는 범용 시스템** — 새 기믹은 `is_dangerous()`만 만들어 등록하면 되고, 피할 곳이 없으면 `ai_safe_spot`을 안 놓으면 그만
- **`Hitbox.repeat_interval`(기본 0):** 0보다 크면 겹친 동안 그 간격마다 재타격(`_process`가 `get_overlapping_areas()`를 훑으며 대상별 쿨타임 관리 — `HazardPlatform.gd`와 같은 방식). **스킬 히트박스는 전부 0.** 판정을 껐다 켤 때 `clear_repeat_state()`

### `maps/Playground.tscn` (놀이터) — **왕관 훔쳐서 달아나기** / 스프링 시소 / 그네 / 모래사장

**스프링 시소 → 정자 지붕 → 중간 구름 → 꼭대기 구름의 왕관** 3단 등반, 가운데 그네는 **닿는 사람을 튕겨내는 방해물**.
씬은 `tools/build_playground.py`가 통째로 생성한다(장식 폴리곤 200개라 손으로 못 고친다) — 좌표는 그 스크립트 상수(`ROOF_Y`/`MID_Y`/`TOP_Y`/`PAV_CX`/`SPRING_X`...)를 고치고 다시 돌릴 것.
**편집기에서 손으로 맞춘 값은 빌더의 `PLATFORM_OVERRIDES`(구름 콜리전 위치·크기, 그림 위치·배율·텍스처)와 `CROWN_POS`/`CROWN_VISUAL_OFFSET`에 박혀 있다.** 또 옮기면 그 값도 옮겨 적을 것 — 안 그러면 빌더를 돌리는 순간 되돌아간다.

| 요소 | 좌표 |
|---|---|
| 바닥 윗면 | y = 280 (`Ground`는 y=300에 1920x40), 좌우 벽 x=±960(**투명** — 충돌만 있고 그림 없음, 안쪽 면 ±940) |
| 스프링 시소 | x = ±680 (좌석 윗면 y=226, **원웨이**) — 정자 지붕 **밑**에 둬서 튕기면 지붕을 뚫고 올라간다 |
| 정자 지붕 (1층) | 윗면 y = **-82**, x ±315~±705 (`PavilionLeft/RightRoof` 390x20, **원웨이**) |
| 정자 기둥 | **충돌 없는 장식** — 그림만 있고 통과된다 |
| 중간 구름 (2층) | 윗면 y = **-228**(왼쪽) / **-227**(오른쪽), 왼쪽 x -390~-130 / 오른쪽 x 224~484 (각 260x20, **원웨이**) |
| 꼭대기 구름 (3층) | 윗면 y = **-418**, x -114~174 (`CloudTop` 288x16, **원웨이**) |
| 왕관 | `Crown` (**25, -472**) — 꼭대기 구름 윗면보다 약 37px 위에 떠 있다 |
| 그네 | `Swing` (0, 280) — 맵 정중앙 |
| 모래사장 | x ±110~±330 (그네 양옆 짧게 2군데, `SandPit0/1`) |
| 스폰 | PlayerSpawn1/2 = **±560** |
| 카메라 | `min_y` **-300** / `max_y` 20 / **`lock_ground_to_bottom` 켬**(흙 56px 고정) |

- **⚠️ 구름은 좌우 대칭이 아니다**(그림에 발판을 맞춘 결과). 왼쪽 중심 x=-254, 오른쪽 **338**, 꼭대기 **22** — 되돌리려면 빌더의 `MID_LEFT_CX`/`MID_RIGHT_CX`/`TOP_CX`. 2026-09-12 편집기 수정으로 콜리전이 (-6,24)/(16,25)/(8,-22)만큼 옮겨졌고 꼭대기가 300x20 -> 288x16, 오른쪽 구름 그림이 구름3 -> **구름2**가 됐다
- **왕관은 본체(`Crown`)를 옮길 것 — 자식(`CrownCollision`/`CrownVisual`)만 옮기면 안 된다.** `Crown.gd`가 본체를 `head_offset`·`ground_y`에 놓으므로 자식만 46px 올리면 줍는 판정이 14px밖에 안 겹친다
- **⚠️ 2026-09-12 구름 수정 뒤로 아래 실측이 안 맞는다 — 다시 재야 한다.** 새 배치로는 지붕(원점 -112) -> 중간(-258)이 146px로 **쉬워졌고**(여유 약 47px), 중간 -> 꼭대기(-448)가 **190px**로 이단 점프 최대(약 193px)에 **여유 3px뿐**이며 가로도 안 겹친다(왼쪽 16px / 오른쪽 50px). **꼭대기(=왕관)에 사실상 못 올라갈 수 있다** — 안 되면 꼭대기 구름을 20~30px 내리거나 넓힐 것
- **3단 도달 가능성 실측**(중력 1150 / 점프 -430 / 공중점프 -510 / 스프링 700, 원점은 발밑 30px 위):
  - 지면 → **스프링 + 공중점프** → 지붕(-112) ✅. **스프링만으로는 못 올라간다**(좌석 발밑 226에서 최소 튕김 213px = 발밑 13, 지붕은 -82) — **정점에서 공중점프**로 113px을 더 번다(스프링 좌석은 바닥 취급이라 공중점프가 차 있다)
  - 지붕(-112) → **이단 점프** → 중간 구름(-282) 여유 23px → 꼭대기(-428) 여유 47px ✅
  - **가로 겹침이 층마다 다르다.** 지붕L↔중간L 69px, 지붕R↔중간R 153px은 그냥 위로. **중간→꼭대기는 왼쪽 4px / 오른쪽 36px 벌어져 공중에서 안쪽으로 밀어야 한다** — **오른쪽 구름 바깥끝(x=460)에서는 못 닿아 바닥까지 떨어진다**(실측)
  - 여유가 23~47px뿐이라 **점프·중력·스프링 상수를 건드리면 사다리가 끊긴다** — 바꿨다면 다시 실측할 것
- **아래 흙 두께는 `CameraRig.lock_ground_to_bottom`으로 고정한다**(벽 사이 1960px이라 카메라가 0.65배까지 물러나면 흙이 100~190px까지 두꺼워졌다). 켜면 카메라 중심 하한 = `ground_y - (화면 반높이 - ground_margin_px) / 지금배율`을 매 프레임 계산해 지면이 늘 화면 아래에서 `ground_margin_px`(56px) 위(실측 배율 0.65~1.00 전 구간 **56.0px 고정**), `max_y`는 상한으로 남는다. **기본값은 꺼져 있다**(9개 맵이 `CameraRig`를 공유) — 켜는 건 놀이터뿐
- **카메라 기본값(`max_y` 250)이면 화면 아래 흙만 보인다.** `max_y` 20, `min_y` **-300** — **구름을 올릴 때마다 `min_y`도 같이 올릴 것**(안 그러면 꼭대기에서 카메라가 멈춘다)
- **맵 밖 벽은 그림 없이 충돌만 둔다**(울타리 ±940·나무가 이미 경계). 실측 x=±920에서 막힘
- **⚠️ 배경이 지글거리면 밉맵부터 의심할 것**(1000~2000px 원본을 84~700px로 줄여 그린다 — 울타리 0.14배). **둘 다 해야 한다**: ① `sprite/맵/놀이터/*.png.import`의 `mipmaps/generate=true`(18장) ② 씬 루트 `Playground`에 `texture_filter = 4`(Linear with Mipmaps) — **캔버스 기본 필터는 밉맵을 안 보므로 ①만 하면 안 쓴다**(루트에 걸면 CanvasItem 자식이 물려받고 HUD·컷인은 CanvasLayer라 제외). 변화량이 절반이 됐고 **이방성(`texture_filter = 6`)은 의미 없다.** 더 줄이려면 `FENCE_H`를 키워 축소율을 낮출 것
- **배경 아파트는 `아파트1동/2동/3동.png` 세 장을 9동으로 돌려 쓴다**(빌더의 `APT_SPRITES`·`APARTMENTS`). **`a1`은 딱 한 동만**("1동" 간판이 박혀 있다). **지붕 높이를 구름 발판과 안 겹치게 고를 것**(흰 구름이 밝은 벽면 위에서 뭉개진다) — `check_apartments()`가 생성 때마다 검산해 침범하면 경고(`CLOUD_ZONES`). **원경 흐리기는 `modulate`로 못 하므로**(곱셈이라 밝게 못 만든다) 동마다 **하늘과 같은 색** 판(`Haze*`)을 덮는다(0.10~0.30). **`maps/apartment.gdshader`는 고아 파일**
- **울타리 `덜촘촘한울타리.png`를 가로로 이어붙인다** — 온전한 안쪽 기둥 554·1615 기준 `region_rect = Rect2(554, 54, 1061, 588)`만 쓴다. **캔버스 통째로(0~2171) 붙이면 양 끝 잘린 기둥끼리 만나 간격이 틀어진다.** 높이 `FENCE_H`(84px), 아랫변 지면(280), `FENCE_SPAN`(±1360)까지 9칸. 예전 `울타리.png`(너무 촘촘)와 생울타리(`Hedge*`)는 폐기
- **정자 `정자.png`는 `Visual` 한 장** — 기와지붕만 발판, 기둥은 **충돌 없이 통과**(반투명은 폐기. `PAV_POST_ALPHA`를 1 미만으로 주면 텍스처 y=**350**(`PAV_CUT_Y`)에서 갈라 두 장으로 그린다). 크기·위치는 "지붕 가운데 윗면 -> `ROOF_Y`(-82)" + "그림 맨 아래 -> 지면(280)"이 정한다 → 배율 0.3324, 374x407px
  - **⚠️ 지붕 윗면 기준을 bbox 맨 위(y=17, 처마 끝)로 잡으면 캐릭터가 12px 떠 보인다** — 실제 밟는 면은 **y=54**(bbox의 3.29%, `PAV_RIDGE_F`). 판정 폭(`PAV_HALF` 195 = 390)은 그림 폭(407)보다 **좁게**
- **모든 층 발판은 원웨이여야 한다**(스프링으로 지붕을 뚫고 올라가야 하고 위층에서 내려올 때도 통과해야 한다). **스프링 좌석도 원웨이** — 꽉 찬 충돌이면 좌석(226~244)과 캐릭터(220~280)가 겹쳐 **옆으로 못 지나가** 통행을 막는 벽이 된다(부스트 판정도 좌석 위 176~216으로 좁혔다)
- **그네(`maps/Swing.gd`)는 타는 기구가 아니라 튕겨내는 방해물**(탑승식은 맵 한가운데라 걸리면 못 빠져나가는 "감옥"이 됐다). 좌석이 **항상 왕복**(`swing_deg` 38도 / `swing_period` 2.2초), 닿으면 **좌석에 대한 상대 속도의 반대쪽**으로 튕기며 뜬다(`bounce_speed` 520 + 좌석 속도 x 0.5, `bounce_lift` -300)
  - **튕긴 뒤 `apply_hitstun`으로 짧게 경직**(`bounce_stun_max` 0.45초) — 안 걸면 다음 프레임에 `Fighter.move()`가 덮어써서 튕김이 없던 일이 된다. **데미지 없음**(`Fighter.damaged`가 안 나가 왕관도 안 벗겨진다). 같은 사람은 `rebounce_delay`(0.35초) 동안 재튕김 없음
- **미끄럼틀은 2026-09-10 개편에서 없어졌다** — 옛 서술(48.3° 경사면·`SlideDeck` 등) 전부 무효. 경사면을 `floor_max_angle` 45°보다 가파르게 잡아야 미끄러진다는 것만 참고할 만함
- **구름 발판 세 장은 서로 다른 그림.** 빌더의 `CLOUDS` 표에서 발판 -> (ExtResource id, 알파 bbox):

  | 발판 | 그림 | 모양 |
  |---|---|---|
  | `CloudTop` | `구름1.png` | 가운데가 봉긋 — 왕관 받침 |
  | `CloudMidLeft` | `구름2.png` | 가장 길고 납작 |
  | `CloudMidRight` | `구름2.png` | 왼쪽 구름과 같은 그림 (2026-09-12 사용자가 구름3에서 바꿈 — 구름3은 이제 안 쓴다) |

  - **세로는 원본 비율을 안 따르고 목표 높이로 맞춘다(비균등 배율)** — `CLOUD_ASPECT`(0.26)가 "그림 폭 대비 높이"를 고정(원본 비율대로면 폭 260 구름이 109px이라 층 간격 170px을 거의 다 먹는다)
  - `region_rect`는 각 알파 bbox(구름1 `71,111,1643,687` / 구름2 `99,53,1978,622` / 구름3 `34,142,1604,662`) — 안 자르면 "그림 폭 = 발판 폭 x `CLOUD_WIDEN`(1.32)" 계산이 여백까지 세어 구름이 작아진다. 나머지: `CLOUD_WIDEN` / `CLOUD_SINK`
  - **⚠️ 편집기에서 구름을 손으로 고쳤다면 `tools/build_playground.py`를 다시 돌리면 안 된다**(씬을 통째로 새로 써서 다 날아간다). 바꾼 값을 `MID_CX`/`MID_HALF`/`TOP_HALF`나 위 상수에 **되먹인 뒤** 돌릴 것
- **기절 연출 `combat/StunStars.gd` / `.tscn`** — `기절효과1.png`/`2.png`를 `frame_interval`(0.11초)마다 번갈아 끼우는 2프레임 플립북, 왕관을 뺏긴 쪽 머리 위(`Crown._drop()`이 `StunStars.spawn(loser, king_stun_time)`). `head_offset`(0, -76), `Stars/scale`(0.046671, 폭 약 68px). `spawn()`은 **이미 떠 있으면 시간만 늘린다**(`extend()`)
  - **⚠️ 두 프레임을 각자 알파 bbox로 자르면 그림이 좌우로 튄다** — **합집합** `Rect2(234, 58, 1457, 580)`으로 똑같이 자를 것
  - **캐릭터 자식으로 붙이지 않는다**(`scale.x = -1`에 같이 뒤집히고 캐릭터가 사라질 때 잘린다) — `Crown`처럼 **맵에 붙여 매 프레임 머리 위치를 따라간다**
- **모래사장 그림 `모래사장 (2).png`**(`SandVisual0/1`은 `Ground`의 자식). **"모래 윗면"이 지면(y=280)에 오도록** 맞춘다 — 모래 윗면은 bbox의 **21.2%**(`SAND_SURFACE_F`). **세로로 늘여 쓴다**(원본 12.5:1) — `SAND_W`/`SAND_H`(244 x 30), 그림 폭은 둔화 판정 폭(220)보다 조금 넓게. **`Ground`가 y=300이라 지면 윗면이 로컬 y=-20**(빼먹으면 20px 어긋난다)
- **왕관 그림 `왕관.png` -> `진짜왕관.png` 교체** — 맵의 `Crown/CrownVisual`과 `ui/CrownCutIn.tscn`의 `Holder/Crown` **두 곳 다** 바꿀 것. **알파 bbox가 정중앙이 아니라**(x 163~1419 / y 150~895) `region_enabled`로 bbox만 써야 하고, 배율은 맵 `0.0487 -> 0.04455` / 컷인 `0.296 -> 0.2705`(화면 크기 유지). **`왕관.png`는 이제 안 쓴다**(파일은 남김)
  - ⚠️ **`모래사장.png`(괄호 없는 쪽)은 쓰면 안 된다** — 내용물이 왕관이고 알파 채널이 없어(colortype 2) 체크무늬가 구워져 있다. 쓰는 건 `모래사장 (2).png`
- **놀이터 스프라이트 배치**(전부 배경 제거 후 `region_rect`로 여백 잘라 씀): `기린시소.png` x=-680, `파란시소.png` x=680, `진짜왕관.png`는 `Crown/CrownVisual`(`화분.png`는 고아 씬 `FallingPot.tscn`). 시소는 **안장 윗면이 좌석 충돌(y=226)에, 받침 바닥이 지면(280)에** 오도록 배율을 잡았다(기린 0.09 / 파란 0.078261), 화분은 몸통 폭이 충돌 상자(36px)에 맞게 0.055385
  - **주의: 시소 원본 두 장은 투명 배경이 아니라 체크무늬였다** — "밝고 무채색"(min>0.82, 최대-최소<0.06)만 flood fill로 지웠다(원본은 스크래치패드에 백업)
  - 스프링 눌림은 `Visual`을 **지면(280) 기준**으로 세로 압축 — `centered = false`라 노드를 지면에 안 두면 위로 줄어든다
- `maps/SpringJumpPad.gd`: **트램폴린** — 닿는 순간 점프 버튼과 무관하게 튕긴다. `bounce_velocity`(700, 최소) / `bounce_restitution`(1.15, 낙하 속도에 곱함) / `max_bounce_velocity`(1100). 실측 그냥 올라서면 **219px**, 높은 데서 떨어지면 **362px**. 착지 순간 `velocity.y`가 0이라 캐릭터별 **직전 프레임 낙하 속도(`_prev_fall`)를 기억**해 계산하고, 판정이 좌석 바로 위(y 176~216)라 밑으로 지나가면 반응 없다. `area_entered/exited` 대신 매 프레임 `get_overlapping_areas()`(라운드 리셋·순간이동 때 신호가 안 온다). 예전 `set_modifier("jump_multiplier", ...)` 방식은 폐기
- **낙하 화분은 2026-09-10에 놀이터에서 제거됐다(기획 변경).** `PotSpawner`와 `PavilionShelter`(`pot_shelter` 그룹)를 씬에서 뺐고 **`maps/FallingPot.gd`/`FallingPot.tscn`/`PotSpawner.gd`는 고아 파일**(`maps/HazardPlatform.gd`도 원래 고아). 씬에 `PotSpawner` 노드만 도로 놓으면 되살아난다
- **`maps/Crown.gd` — 핵심 기믹 "왕관 훔쳐서 달아나기".** 꼭대기 발판의 왕관을 **몸으로 닿으면** 줍고 "놀이터의 왕"이 된다. 왕이 **한 대라도 맞으면 왕관이 튕겨 나가 바닥에 떨어지고** `pickup_delay`(0.6초) 뒤부터 아무나 줍는다
  - **승리 조건은 건드리지 않는다** — 승패는 `Stage.gd`가 HP·링아웃으로만 판정한다. "N초 들면 승리"로 원한다면 맵이 아니라 `RoomSettings`의 규칙 옵션으로 뺄 것
  - 왕 버프: `king_speed_multiplier`(1.25) / `king_damage_multiplier`(1.3) / 모래사장 둔화 면역. **공격력은 `attack_debuff_multiplier`에 건다** — 이름은 디버프 같지만 `compute_damage()`가 그대로 곱해서 1보다 크면 버프다. `set_modifier(..., get_instance_id(), ...)`로 id를 준다
  - 왕 표시는 `custom_data["playground_king"]`, `Crown.is_king(fighter)`로 물어본다(`SandPit`이 왕을 봐준다) — 라운드 리셋 때 캐릭터와 같이 사라진다
  - **떨어뜨리기 훅으로 `Fighter.damaged(amount, knockback)` 시그널을 새로 만들었다**(`health_changed`는 회복에도 날아오고 넉백 방향을 모른다). 가드로 완전히 막아 0이면 발동 안 함
  - **`pickup_delay`(0.35초)를 0으로 두면 안 된다** — 때린 쪽이 밀착해 있으면 바로 회수해 "때리면 뺏김"이 된다
  - **떨어질 때 왕관은 거의 수직(`drop_velocity` (0, -300)).** 넉백 방향 (180, -420)은 **때린 쪽이 손해**였다(왕관 151px vs 왕 36px라 왕 너머에 떨어지고 0.84초 체공)
  - **`drop_grace`(1초) — 주운 직후엔 맞아도 안 벗겨진다**(없으면 원거리가 툭툭 치는 것만으로 무한 봉쇄). **데미지·넉백 문턱으로 원거리를 거르는 건 지금 수치로 불가능**(BB탄/토하기 6·200 vs 근접 기본공격 6·220, 백수플렉스 슬램은 넉백 70) — **뺏기는 빈도에 상한**을 두는 방식으로 풀었다. `drop_min_damage`는 기본 0(꺼짐)
  - **넉백 없는 피해로는 안 벗겨진다**(`Fighter.apply_dot()`/`MouseGrab`/`HazardPlatform`까지 받으면 독 틱 한 번에 벗겨진다). **겹친 사람 중 왕관에 가장 가까운 쪽이 줍는다**(첫 번째를 집으면 늘 같은 플레이어가 이긴다)
  - **⚠️ 맵 기믹 스크립트에서 `gravity` 변수 이름을 쓰면 안 된다** — `Area2D`에 내장 프로퍼티가 있어 `The member "gravity" already exists in parent class Area2D` 컴파일 에러(여기선 `fall_gravity`). `priority`·`monitoring`·`linear_damp`·`angular_damp`도 피할 것(함수 **안** 지역 변수는 경고만)
  - 떨어진 왕관은 Area2D라 `_fall()`이 중력·바닥(`ground_y` 263)·좌우 벽(±690)을 손으로 계산한다. **발판은 통과해 항상 바닥까지 떨어진다**(쟁탈 지점이 늘 지면). 발판에 얹으려면 레이캐스트 필요
  - 획득 컷인(`ui/CrownCutIn.tscn`)은 1.8초라 `cutin_once`(기본 true)면 라운드 **첫 획득에만** 재생. 그림은 `sprite/맵/놀이터/왕관.png`(1536x1024, bbox 1150x714), 충돌 56x34에 맞춰 `scale = 0.0487`, `z_index = 20`
  - 올라가는 경로는 위 좌표표와 "3단 도달 가능성"을 볼 것 — 옛 `PlatformLow/Mid/Top` 서술은 무효
  - **AI도 떨어진 왕관을 주우러 간다** — `AIController._try_take_crown()`이 이동 판단을 가로챈다("crown" 그룹이라 왕관 없는 맵은 영향 없음). 단 **초기 위치(꼭대기 발판)까지는 못 올라간다**(발판 경로 탐색이 없다) — `crown_max_height` 120px 위는 무시(없으면 못 닿는 왕관 아래를 영원히 서성인다). **AI전에서 첫 왕관은 항상 플레이어가 가져간다**
- `maps/SandPit.gd`: **모래사장** — 안에 서 있는 동안 이동속도 `slow_multiplier`(0.6)배. `set_modifier("move_speed_multiplier", 노드 instance_id, 배수)`로 걸었다 벗어나면 `clear_modifier`(다른 둔화와 겹쳐도 안 지운다). 겹침은 매 프레임 `get_overlapping_areas()`
  - **판정을 발치 높이(y 256~296)에만 뒀다** — 지면 Hurtbox(220~280)와 24px 겹치고 점프하면(1단 56.3px) 바로 벗어난다(걸어서 건너느냐 뛰어넘느냐의 선택)
  - 폭 ±260 근거: 왼쪽 미끄럼틀 아래턱(x -403)·오른쪽 스프링 시소(좌석 354~606)를 안 건드리고 `PlayerSpawn1`(x -300, 반지름 20)이 **모래 밖에서 시작**하도록 20px 여유 — 넓힐 때 이 셋을 확인할 것

### `maps/SubwayPlatform.tscn` 구조 (2026-09-03 기획 확정본)

**승강장 바닥이 없다 — 플레이어는 선로 바닥에서 싸운다.** 올라갈 수 있는 발판은 **의자 2개뿐**.

| 요소 | 좌표 |
|---|---|
| 선로 바닥(서 있는 곳) | y = 300 (`Ground`는 y=320에 1120x40) |
| 좌우 터널 벽 | x = ±560 (40x900) → 실제 이동 범위 x -520~520 |
| 의자 발판 윗면 | y = 155 (`BenchLeft`/`BenchRight`, x=±280, 220폭, 원웨이) |
| 열차 | y 195~300 (`DecoSubwayTrain`이 y=247.5) |
| 역 이름 표시 | 중심 (0, 25), 띠 y -4~61 |
| 벽 타일 | x -1000~1000 / y -320~320 |
| 카메라 | `min_y` 80 / `max_y` 190 (바닥이 화면 아래쪽이라 위로 붙임) |

- **의자 높이(바닥에서 145px)는 이단 점프 전용** — 지상 점프 71.1px로는 못 닿고 이단 점프(실측 165.4px)로만 올라간다(기획 확정 5를 숫자로 강제)
- **의자에 올라서면 열차에 안 맞는다**(캐릭터 y 95~155, 열차 지붕 195 → **40px 여유**). 유일한 피난 수단이므로 의자 높이·열차 크기를 건드릴 때 같이 계산할 것
- **의자는 트리에서 열차보다 먼저 나온다 = 열차가 의자 앞을 지나간다**(기획 확정 3 "건너편 의자"를 깊이감으로). 순서를 바꾸면 의자가 열차 위에 얹힌 것처럼 보인다
- 의자가 공중에 떠 다리 끝 제약이 없어져 배율 0.153846 → 0.190147로 폭 220으로 넓혔다
- 링아웃 없음(바닥이 벽 사이를 꽉 채운다). 맵 이름은 `GameState.MAPS`에서 "지하철 승강장 (열차)"

### 지하철역 스프라이트 배치 (`sprite/맵/지하철역/`)

전부 `region_rect`로 **투명 여백을 잘라낸 뒤** 배치(여백까지 쓰면 위치 계산이 어긋난다). 헤드리스 실측값:

| 그림 | 잘라 쓰는 영역(region_rect) | 배율 | 월드 배치 |
|---|---|---|---|
| `Metro!.png` (열차) | `Rect2(36, 221, 2101, 250)` | 0.42 | 882.4 x 105, 그림 y 195~300 |
| `지하철선로.png` (선로) | `Rect2(14, 287, 2143, 177)` | 0.541297 | 1160 x 95.8, 윗면 y=300. 스테이지 안쪽 1장은 `Track`(미리보기 포함), 바깥 2장은 `DecoBackground` |
| `등받이.png` (의자 발판) | `Rect2(144, 245, 1157, 596)` | 0.190147 | 220 x 113.3, 의자마다 `position (-110, -56.4)`·`centered=false` |
| `역이름.png` (역 표시) | `Rect2(88, 184, 2015, 325)` | 0.496278 | 1000 x 161.3, 중심 (0, 25) |
| `지하철벽타일.png` (벽 타일) | `Rect2(44, 40, 1446, 926)` | 0.345781 | 500 x 320.2짜리 8장(4열 x 2행) |

- **벽 타일은 반복(texture_repeat) 대신 스프라이트 여러 장** — 원본 바깥 반투명 비네트 때문에 타일링하면 이음매마다 어두운 띠가 생긴다
- **`역이름.png`의 좌우 띠는 그림 폭(1000)까지만 간다.** 벽 전체로 이으려고 같은 색 `Color(0.2431, 0.2431, 0.5569)` 띠(`SignBand`, y 0~57)와 검은 테두리(`SignBandOutline`, y -4~61)를 벽 폭으로 깔았다 — **그림을 옮기면 두 폴리곤도 같이 옮길 것**
- `Track`만 `Deco` 접두사가 없는 이유: 미리보기에 바닥 선이 보이려면 스테이지 폭만큼의 선로가 필요하고, 나머지 2장은 바운딩 박스만 키운다
- **맵 조명 `CanvasModulate` = (0.88, 0.9, 0.96)**(2026-09-11, 예전 (0.55, 0.58, 0.7)). **형광등·창문 빛은 예전과 같은 양이 더해지게** 빛 색을 **옛 조명 ÷ 새 조명** ≈ (0.625, 0.644, 0.729)배로 줄였다(안 줄이면 1.6배로 하얗게 날아간다). 형광관은 꺼지면 (0.63, 0.67, 0.71) 회색, 켜지면 흰색
- **벽 형광등 `maps/FluorescentLight.tscn` + `.gd`**(장식): 평소 켜져 있다 가끔 파바박, 가끔 푹 꺼졌다 켜진다. `DecoBackground` 안 4개(x ±310, ±470 / y -30 — 역 이름판 타원 x -253~235 / y -55~105를 피하고, 카메라가 가장 당겨졌을 때 화면 윗선 y 약 -52보다 아래여야 늘 보인다)
  - **아직 임시 도형** — 스프라이트를 받으면 `_draw()`만 바꾸면 된다. 빛은 자식 `Light` 레이어(더하기, 코드 생성·씬 저장 안 됨)가 그리고 **깜빡임은 이 레이어 투명도만** 바꾼다
  - `FluorescentLight2`만 `flicker_interval` 1.5~4초로 **고장 난 형광등**(전부 같은 주기면 연출처럼 보인다). `glow_color`(지금 (0.625, 0.644, 0.656))도 `CanvasModulate`를 감안해 미리 나눈 값이라 **맵 조명을 바꾸면 같이 다시 잡을 것**. 아래로 떨어지는 빛은 사다리꼴 세 겹(한 겹으로 진하게 칠하면 판때기)
- **바람에 날리는 신문지 `maps/WindNewspaper.gd`**(장식, 충돌·판정 없음): `DecoWindPapers` 아래 바닥 6장 + 의자 위 2장. **아직 도형**이라 그림을 받으면 `_draw()`만 바꾸면 된다
  - **바람은 열차보다 먼저 온다** — 앞머리 `gust_reach`(160px) 앞 = 돌풍(120~230px/s) / 차체 옆 `body_wind` 0.4 / 꼬리 뒤 `wake_reach`(120px) 0.55. `wind_speed`(480)가 열차(950)보다 느려 **처지며 흩날린다**(같거나 빠르면 열차에 붙어 같이 사라진다). **경고 구간(5초)엔 바닥 종이가 들썩거려**(`tremble`) 경고 역할도 겸한다
  - 크게 뜨는 건 열차당 한 번(`_gusted`), 이후엔 톡톡 튀며(`hop_*`) 끌려간다. 벽(±540)에 튕겨 안 사라지고 **다음 열차가 도로 날린다**
  - 열차는 `"subway_train"` 그룹으로 찾고 **읽기 전용** `is_running()`/`get_direction()`/`get_body_x()`/`get_half_width()`로 묻는다. **트리 순서가 `DecoSubwayTrain` 다음이라 열차 앞에 그려진다**(뒤면 차체에 가린다)
  - **노드 `scale`을 안 쓰고 배율(`_look`)을 좌표에 직접 곱한다**(@tool이라 에디터 scale이 씬에 저장되고, scale로 누르면 외곽선까지 얇아진다). 놓인 자리 바로 밑을 누운 면으로 치므로(`_rest_y`) 노드 위치는 종이 **가운데**다 — 바닥(299)에 두려면 y = 299 - 세로 x 0.4 / 2 (신문 295.4 / 전단지 295.8 / 의자 위 151.4)
- **생동감 + 화면 진동**(2026-09-12). **지금 씬에 살아 있는 건 화면 진동과 전광판 둘뿐** — 사람 실루엣(`maps/PlatformCrowd.gd`, `count` 6명·발선 y=218·키 52px·`DecoBackground` z_index -10)과 비둘기(`maps/Pigeon.gd`, `DecoPigeons` 아래 2마리·y=299·`return_delay` 1.6초)는 2026-09-13에 사용자 요청으로 씬에서 뺐다(**고아 파일**, 노드만 도로 놓으면 살아난다). 전부 **그림 없이 코드로 그린 장식**이고 충돌·판정 없음
  - **열차가 지나갈 때 화면이 흔들린다** — 경고 구간 낮게(`warning_shake` 0.12 ≈ 1.1px), 통과 중 크게(`pass_shake` 0.5, 가운데에 가까울수록 세게 — `pass_shake_focus` 0.6). 실측 최대 12px
  - **⚠️ `CameraRig.add_trauma()`로는 지속 진동을 못 만든다** — 순간 충격이고 감쇠가 **초당 3(절대값 차감)** 이라 매 프레임 조금씩 부으면 **하나도 안 쌓인다**(실측 0px). 그래서 `CameraRig.set_rumble(세기)`를 만들었다(이번 프레임에 유지할 **바닥값**). 열차에 맞으면 `Hitbox` 타격 진동이 위에 더 얹힌다
  - **전광판 `maps/SubwaySignBoard.gd`** — 평소 안내 문구가 흐르고 경고 중엔 빨간 "열차가 들어오고 있습니다"가 가운데서 깜빡인다(흘리면 못 읽는다). 판·테두리는 `_draw()`, **글자는 자식 `Clip/Text`(Label)** — `Clip`의 `clip_contents`가 삐져나온 글자를 잘라준다(`_draw()`만으로는 못 자른다). 폰트는 주아체
  - **⚠️ `.tscn`에 노드를 손으로 끼울 때는 부모의 "속성 줄" 다음에 넣을 것** — `[node name="Ground" ...]` 헤더 **바로 뒤**에 끼웠더니 밑의 `position = Vector2(0, 320)`이 **새 노드 속성으로 딸려가** 바닥이 y=0이 됐고 **캐릭터가 맵 아래로 떨어져 매 라운드 무승부**가 됐다(에러가 하나도 안 뜬다)
- **아직 안 들어간 기획:** ① 열차 위에서 전투 ② 두 번째 열차에 지하철 빌런 무리가 쏟아지는 연출

- **발판은 반드시 `one_way_collision = true`로 둘 것(실제로 겪은 버그).** 캡슐 60px에 지상 점프 71px이라 올라갈 수 있는 발판의 **밑 공간은 34px**뿐 — "밑으로 지나다니면서 뛰어올라갈 수도 있는 높이"는 이 게임에 없다. 꽉 찬 충돌이면 발판 밑 캐릭터가 껴서 y≈266으로 눌린다
  - `maps/NoisyApartment.tscn`의 `UpperPlatform`도 같은 버그(발판 225~245)라 함께 고쳤다
  - 반대로 `maps/TrashRoom.tscn`의 쓰레기 더미는 밑 공간이 없는 장애물이라 **원웨이로 바꾸면 안 된다**
- **`Deco`로 시작하는 노드 이름은 "맵 선택 미리보기에서 빼라"는 뜻이다.** `ui/MapPreview.gd`는 맵의 `Polygon2D`·`Sprite2D`를 모아 바운딩 박스에 맞춰 축소하는데, 화면 밖까지 깔린 장식(`DecoBackground` 1800x860)이 섞이면 스테이지가 점처럼 작아진다. 그래서 `Camera2D`/`CanvasLayer`와 함께 `Deco` 가지를 통째로 건너뛴다 — **새 맵 장식에도 이 규칙을 지킬 것**
  - 원래 `Polygon2D`만 그렸는데 벤치가 스프라이트로 바뀌며 미리보기가 비어서 **`Sprite2D`도 그리도록 확장**(`_sprite_entry()`가 `region_enabled`/`centered`/`scale`을 반영해 `draw_texture_rect_region()`으로 그린다)

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
  ui/             # MainMenu/RoomSettings/CharacterSelect/MapSelect/MatchResult, story/(새 스토리 장면), HP바·쿨타임 HUD
```

## 참고

- 기획 오픈 이슈(히트스턴 예외, 승리 조건 HP vs 링아웃 등)는 아티팩트 문서의 "다음에 정할 것" 표를 확인. 확정 전까지는 구현 시 임시값으로 처리하고 주석/TODO로 표시
- **엔진 버전은 4.7.2로 통일한다(2026-09-10에 4.6 -> 4.7.2로 올렸다).** `project.godot`의 `config/features`가 `"4.7"`이다. **버전이 섞이면 이 줄이 열 때마다 다시 쓰여서 매번 머지 충돌이 난다** — 바로 옆 줄인 `run/main_scene`까지 같이 충돌로 딸려 들어온다(실제로 겪음). 그래서 **팀원 전원이 4.7.2를 써야 한다.** 누군가 4.6으로 열면 반대 방향으로 똑같은 충돌이 난다
  - 올리기 전에 4.7.2에서 전체 검증을 돌렸다: 스크립트 파싱 에러 0건, 맵 3종(지하철 승강장·놀이터·층간소음) 각 18초 무사고, UI 5종(타이틀·메인메뉴·캐릭터선택·맵선택·방설정)·훈련장 무사고, 방어 동작 16항목 전부 통과
  - **4.7에서 새로 뜨는 경고: `ext_resource, invalid UID`.** 씬이 들고 있는 uid와 `.import`의 실제 uid가 다르면 경고를 띄우고 경로로 대체해 읽는다(동작은 한다). `MenuIllust.tscn` 6개·`SubwayVillainRig.tscn` 1개가 그랬는데 — 그림을 다시 임포트하면 uid가 새로 생기는데 씬은 옛 uid를 들고 있어서다. 전부 실제 값으로 맞춰뒀다. **그림을 갈아끼운 뒤 이 경고가 뜨면 씬의 uid를 `.import`의 `uid=` 값으로 고칠 것**
  - 남아 있는 것: 타이틀 화면을 `--quit-after`로 강제 종료하면 `2 ObjectDB instances were leaked` / `1 resources still in use`가 뜬다. 브금·페이드 트윈이 도는 중에 끊어서 나는 종료 시점 메시지라 게임 동작에는 영향이 없다
- **코드 수정 후 헤드리스로 에러 확인은 기본적으로 하지 않는다(사용자 요청, 2026-09-08).** 시간·크레딧을 아끼기 위해 매번 돌리지 말 것 — 사용자가 명시적으로 "실행해서 확인해줘"라고 할 때만 돌린다.
- Godot 실행 파일은 PC마다 다르다. **이 PC(`C:\Users\bitba\Documents\GitHub\villain`)는 `C:\Users\bitba\Downloads\Godot_v4.7.2-stable_win64.exe (1)\Godot_v4.7.2-stable_win64_console.exe`** — 폴더 이름에 공백과 괄호가 들어 있으니 PowerShell에서는 호출 연산자로 `& "<경로>" ...`처럼 부를 것. 다른 PC는 `D:\10인준완\Godot\engine\` 아래에 있었다(4.6 시절 경로라 지금은 다를 수 있다). 경로가 안 맞으면 `Godot*4.7*win64*console*.exe`로 찾을 것
  - (필요할 때) 헤드리스로 씬을 실행해서 런타임 에러를 확인할 수 있다 — 예: `& "<위 경로>" --headless --path "C:\Users\bitba\Documents\GitHub\villain" "res://maps/SubwayPlatform.tscn" --fixed-fps 60 --quit-after 1100`
- **주의:** 새 `class_name` 스크립트를 추가한 직후에는 먼저 `& "<위 경로>" --headless --path "C:\Users\bitba\Documents\GitHub\villain" --editor --quit-after 20`로 한 번 실행해서 전역 클래스 캐시를 갱신해야 함. 안 그러면 방금 만든 클래스를 참조하는 다른 스크립트가 "Could not find type" 에러로 로드 실패함
- 자동 입력 시뮬레이션이 필요한 테스트는 `extends SceneTree` + `--script` 방식이 아니라, `extends Node` 스크립트를 임시 `.tscn`으로 감싸서 `--headless --path ... <임시 씬> --quit-after N`로 실행할 것 — `--script` 모드는 오토로드(`GameState` 등)가 초기화되지 않아 컴파일 에러가 남
- **주의:** 헤드리스 모드는 프레임 제한이 없어서 60fps보다 훨씬 빠르게 돈다(실측 약 145fps). 쿨타임·버프 지속시간처럼 시간 기반 로직을 테스트할 때 `--quit-after N`의 N을 "60fps 기준 초"로 계산하면 실제로는 그보다 훨씬 짧은 시간만 흐른다 — 프레임 수 대신 `Time.get_ticks_msec()`로 실제 경과 시간을 재면서 대기하거나, `--fixed-fps 60`을 같이 붙여서 프레임당 델타를 고정시킬 것

