# 트러블 메이커 (villain) — Godot 프로젝트 규칙

사이드뷰 대전 격투 게임 **"트러블 메이커"**(리포·폴더는 `villain`, 빌드 산출물 `build/TroubleMaker/`). 기획 문서: https://claude.ai/code/artifact/661e48af-d8db-49c9-bc68-a9294790becb
전역 규칙(한국어 응답, 초보자 눈높이, 안전 규칙) 유지, 코드 스타일은 이 문서 우선 — 이 프로젝트는 **Godot/GDScript**(전역 CLAUDE.md의 Unity/C# 규칙 아님).

## 프로젝트 정보

- 엔진: Godot 4.7.2, GDScript ("참고" 절 버전 규칙 참조) / Forward Plus, 3D 물리 Jolt(기본값 — 실제 게임은 2D)
- 장르: 사이드뷰 대전 격투, 바운스어택류(넉백을 다시 잡아채는) 콤보 중심. 히트스턴 최소화 지향, 지형·벽 활용 기믹

## 확정된 아키텍처 방향

**캐릭터 전용 `.gd`는 만들지 않는다** — 모든 캐릭터 씬 루트가 `characters/Fighter.gd`, 차이는 스탯(`.tres`) + 스킬 노드 조합으로만.

- `Fighter.gd`(`CharacterBody2D`): 이동/점프/중력, HP(`take_damage`/`heal`/`health_changed`), 스킬 슬롯(자식 `Skill1`/`Skill2`/`SkillUltimate`/`BasicAttack` 자동 연결), 자유 데이터 `custom_data`(예: 술 스택)
- 버프·디버프는 직접 대입 금지 → `set_modifier(property, id, value)`/`clear_modifier(property, id)`(id별 저장 후 곱함). 임시 효과는 `apply_temp_multiplier(property, value, duration)`, 켰다 껐다 하는 지속 효과는 고정 id(`"drink_stacks"` 등)로 직접 호출. (`set()` 직접 덮어쓰기는 겹친 디버프를 지우는 버그였음)
- **캐릭터끼리 몸 충돌 없음**: `Fighter._ignore_other_fighters()`가 `_ready()`에서 양방향 `add_collision_exception_with`(없으면 상대 머리를 밟고 다님). 레이어는 바닥·벽까지 영향이라 안 건드림. Area2D 판정은 그대로
- **공용 정적 헬퍼 — 새 스킬에서 직접 다시 짜지 말 것:**
  - `combat/PhysicsQuery.gd`: `raycast_ignoring_fighters(ctx, from, to)` / `ground_y_below(ctx, from, probe, fallback_y)` — 캐릭터를 뚫는 레이캐스트(바닥·벽 거리)는 전부 이것
  - `Timers.gd`(루트): `after(owner, delay, cb)` / `self_destruct(target, lifetime)` — owner 자식 Timer로 예약(아래 Lambda capture 함정 참고)
  - `Fighter.find_fighter_in_box(fighter, range_x, range_y, direction, back_tolerance := 20.0)`: 몸 충돌 없는 근접 상대를 거리로 찾기
  - `CrashBurst.spawn(parent, pos)`: 기본 충돌 이펙트. **색·조각 수를 바꾸려면 `CrashBurst.new()`로 만들어 add_child 전에 값을 채울 것**(`_ready()`가 기본값으로 먼저 그림)
- `skills/Skill.gd`(`Node`): 쿨타임·`can_use()`/`use(fighter)` 공용. 새 스킬은 상속 후 `_execute(fighter)`만 오버라이드
- **궁극기는 라운드 시작 시 쿨을 물고 시작**(`Skill.start_on_cooldown`, 전 캐릭터 `SkillUltimate`에 켬 — `_ready()`에서 `cooldown_left = effective_cooldown()`). 라운드마다 `reload_current_scene()`이라 게임/라운드 시작 구분 불필요(승수만 `GameState`에 남음). 스킬1·2·기본공격은 꺼져 있음
  - `_ready()`를 오버라이드하는 스킬(`ComboMeleeAttack` 등)은 반드시 `super()` 호출 — 안 부르면 이 규칙에서 조용히 빠짐
  - 쿨은 컷인이 끝난 뒤(`fire_ultimate_now()`)부터 돈다 → 실제 재사용 간격 = 쿨 + 연출 시간
- **`Skill.cooldown_override`**: 0보다 크면 `cooldown` 대신 사용(버프가 "몇 초로" 고정할 때, 끝나면 0으로). 배수 방식 `Fighter.attack_speed_multiplier`와 곱해짐
  - **쿨을 채우는 자리는 전부 `effective_cooldown()`을 거칠 것** — `Skill.use()`/`cancel_use()`, `ComboMeleeAttack._resolve()`, HUD `SkillCooldownIcon`. 한 곳이라도 `cooldown`을 직접 읽으면 그 경로만 안 먹음
  - 헛발 쿨도 묶어야 함(`ComboMeleeAttack._effective_miss_cooldown()`) — 안 묶으면 헛칠 때 원래 쿨이라 버프 체감이 없음
- `skills/RageBuffSkill.gd`(악플러 열등감): `duration` 동안 기본공격 쿨을 `basic_attack_cooldown`으로 고정(발동 시 돌던 쿨도 `minf`로 깎음) + 붉은 `set_tint` + `set_action_face(true)` + `BodyRig.play_head_shake()`(`head_shake_time`; 버프 내내 떨게 하려면 `duration`과 같게). 복구는 자식 Timer
- **⚠️ 스킬에서 `Visual.scale`을 직접 트윈 금지 → `BodyRig.play_squash(배율)` 사용.** 리그는 왼쪽을 볼 때 `scale.x` 음수라 양수 목표로 트윈하면 0을 지나 오른쪽으로 뒤집히고 `_face_moving_direction()`과 싸움. `play_squash()`는 방향 부호를 곱해 적용·자동 복귀. 사용처: `HealSkill.heal_pop`, `ScreamConeUltimate.shout_squash`. 자기 자식 스프라이트 트윈(`FirePlate`)은 무관
- `combat/Hitbox.gd`/`Hurtbox.gd`: `Hurtbox`(Fighter 자식 Area2D)가 피격 시 `take_damage()`, `Hitbox`는 겹치면 데미지(자기 자신 무시)
  - **허트박스는 머리 꼭대기까지**(사용자 요청): 캐릭터 씬 12개의 `HurtboxCollision`이 별도 `CapsuleShape2D_hurt`, 발끝 +30 고정·윗끝 = 머리 그림 꼭대기(높이 = 30 - 꼭대기, `position.y` = (30 + 꼭대기)/2; 금쪽이는 프로펠러 빼고 모자까지). **머리 그림을 바꾸면 다시 잴 것.** 몸 충돌 캡슐은 그대로. 이 때문에 `SpringJumpPad`는 몸 중심이 판정 아래면 무시
- `skills/ComboMeleeAttack.gd`(`MeleeAttack` 상속): **기본공격 3타 콤보, 기본공격 있는 캐릭터 전원 사용**(2026-09-26 확인: 지하철 아저씨 `SubwayVillain.tscn`에도 붙어 있다 — 예전 "지하철만 기본공격 없음" 서술은 옛 내용). 히트 확인식: 헛치면 예약 입력 버림 + `miss_cooldown` + 1타 리셋, 3타 성공 시 `cooldown`. 타별 값은 `combo_damage`/`combo_knockback` 배열이라 `damage`는 안 씀(씬에서 지울 것)
  - **마무리 타 더 멀리 + 이펙트(2026-09-26 사용자 요청, 전원):** `finisher_distance_scale`(1.25)을 마무리 타 가로 넉백에 곱한다. **거리가 아니라 속도 배수**라 1.5를 주면 거리가 1.8~2.1배가 됐다(바닥 미끄러짐이 속도² 비례) — 1.25가 거리 약 1.5배(실측 금쪽이 3타 몫 194 -> 280px, 악플러 38 -> 57px). `finisher_trail`이면 `_launch_finisher()`가 경직·구르기 설정과 상관없이(그 early return **앞에서**) `combat/LaunchTrail.gd`를 맵에 붙인다: ① 맞은 자리 충격(첫 순간 섬광 + 가시 + 퍼지는 고리 — 사용자 요청으로 크게 키움, `burst_*`) ② 날아가는 동안 몸 뒤 바람 줄기 ③ 지나간 길에 C자 먼지 고리(입이 날아가는 쪽). 흰색 + 옅은 테두리, 땅에 닿거나 느려지면(`stop_speed`) 따라가기를 멈춘다. 막힌 타엔 안 나옴
  - 참고: 옛 방식 캐릭터(금쪽이 외)는 3타 넉백 (220, -90)에 경직이 따로 없어 원래 38px 정도밖에 안 날아간다 — 더 날리려면 캐릭터별 `combo_knockback[2]`/`launch_stun`을 만질 것
  - **확정 콤보 설계(사용자 요청 "경직 vs 후딜")**:
    - 판정은 캐릭터 앞 40px의 30x30 상자 → 상대 중심 약 75px 안. **넉백을 키우면 파고들기(lunge)도 같이 키울 것**(1·2타 기본 넉백 (60,0)·`combo_pop` 0)
    - windup 0이면 `_fire()`가 물리 프레임 **두 번** 대기(한 번이면 area_entered가 안 남). 선딜 0이던 캐릭터는 `windup` 0.16(= 모션 0.4초의 40%)
    - `link_stun_margin`: 1·2타 명중 시 경직을 "다음 타 예비동작 + margin"으로 보장(`_hold_for_next_hit`) — 늦게 누르면 풀림
  - 공용(전 캐릭터 영향): ① 1·2타 명중 시 상대 가로 속도를 지우고 이번 넉백만(`take_damage`는 넉백을 **더함**) ② 판정이 켜진 동안 캐릭터를 따라다님(`_process`)
  - `combo_lunge`: `movement_override`로 예비동작 동안 이동, 판정은 도착 자리 기준. 데미지 비례 푸시백(`pushback_base`/`pushback_per_damage`, 0이면 `combo_knockback`)은 `v = sqrt(2 x HITSTUN_FRICTION x 거리)`로 역산 + 다 미끄러질 때까지 경직 보장. `lunge_follows_pushback`: 파고들기 = 직전 푸시백 + `combo_lunge`
  - 드롭킥(`dropkick_finisher`)·발차기 코드는 공용에 남아 있음
  - 회전 타격 `BodyRig.spin_hit_index`(-1 = 안 돔)/`spin_*`: 루트 `scale.x`에 `cos`를 곱해 돌면서 때림. **판정 시각 = duration x spin_end x spin_strike를 windup과 맞출 것**
    - ⚠️ 곱하기 전 `scale.x`를 다음 프레임 `_apply_pose` 첫머리에서 되돌림(안 그러면 `absf(scale.x)`로 얇은 몸이 굳음), 최소 0.04(0이면 변환 깨짐)
  - `BodyRig.play_lunge_step`: 파고들 때 발 내딛는 연출(이동 거리와 무관)
  - 공중에서 경직이 끝나면 `Fighter.move(0)`이 가로 속도를 0으로 덮어써 수직 낙하 → `Fighter._launch_momentum`으로 해결
  - **주의(겪음): GitHub Desktop이 브랜치 이동 시 작업을 stash에 치워 "콤보가 사라짐"이 된 적 있음 — 뭔가 없어지면 `git stash list`부터**
- `skills/MeleeAttack.gd`: 기본공격 공용(캐릭터 앞 히트박스 on/off, `damage`/`range`만 다르게)
- **클래시 연출**(`ui/SkillClashPopup.gd` + `ui/ClashBand.gd`): P1 노랑/P2 파랑 덩어리가 쾅 맞물리고 **사선 경계선이 곧 게이지**(숫자 없음). 얼굴은 `GameState.PORTRAITS`, 밀리는 쪽 고개 젖힘(`face_tilt_deg`)
  - 캐릭터는 **주먹 러시**: 연타 1번 = 주먹 2방(`BodyRig.clash_punches_per_press`, `_push`가 `clash_punch()` 호출). 주먹은 **각 손의 쉬는 자리에서 출발**(가운데서면 손이 튐). 잔상 `clash_ghost_*`(owner 없음 = 씬 미저장). 러시 중 손 물건 숨김(`_hold_hidden_by_clash`). `shove_amplitude` 0(주먹과 겹치면 춤춤), `shove_bias`만. 흔들림은 월드 값을 두 리그에 똑같이(`set_clash_shove`), 방향 보정은 리그가
  - **연타 키는 항상 일반공격**(`mash_action_id`) — 슬롯별 키면 순간 판단 불가
  - 연타 수치(`push_per_press`/`balance_recenter`/`mash_duration`/AI 간격)는 시뮬레이션으로 맞춘 값 — 복귀력이 크면 끝까지 밀기가 불가능해짐. AI가 느려서 빠른 사람에게 거의 못 이김(세게 하려면 AI 간격만 줄일 것)
  - 결착: **누른 횟수 많은 쪽 승**(`_decide_by_presses`). 흔들림은 CanvasLayer `offset`도 같이(`ui_shake_ratio` — 안 하면 UI만 따로 놈). 승부 후 이긴 색 차오름(`pour_*`) → `solid` → 띠가 날아감(`fly_*`, `ClashBand.trail`). 길면 `pour_time`·`fly_delay`부터 줄일 것
    - `ClashBand.full_balance`(>1)까지 채움(사선이라 1.0에선 구석에 진 색이 남음) — `balance`는 -1~2, `push_a`는 -1~1로 자름. `solid` 전환 시 `_solid_half_len`으로 길게 그려 모양 유지
- **⚠️ 띠를 화면 한가운데(`band_center_ratio` 0.5)에 두면 대치 그림을 가린다**(지금 위쪽 0.22)
- `ClashBand`는 노드 없이 `_draw()`로. 스파크는 가로로 뻗고 세로만 뒤집는 지그재그(아무 방향이면 나뭇가지처럼 흩어짐)
  - 두 덩어리는 경계선 마디마다 **가로 띠 조각 `draw_primitive`** 로 칠하고 경계선 x는 `±pad`로 자른다(2026-09-27). 다각형 하나로 그리던 때는 한쪽이 크게 밀려 경계선이 띠 끝 밖으로 나가면 "triangulation failed"가 매 프레임 쏟아졌다 — AI 강화로 연타 대결이 잦아지며 디버거 오류가 폭증한 원인
- **대치 자세 중 리그 `process_mode`를 ALWAYS로**(paused라 `BodyRig._process`가 멈춤), 끝나면 INHERIT
- **`BodyRig._pose_clash()` 기울기에 `facing` 부호를 곱할 것**(회전*크기 순이라 안 곱하면 왼쪽 캐릭터가 뒤로 넘어감)

- `combat/SkillClashManager.gd`: 두 Fighter가 같은 슬롯을 `match_window` 안에 쓰면 화면 정지 + `ui/SkillClashPopup.tscn`. 진 쪽은 `Skill.cancel_use()`(쿨만 소모). `Stage.gd`가 심고 Fighter는 `"skill_clash_manager"` 그룹으로 찾음(없는 씬은 즉시 발동). **스킬1·2·궁만 해당 — `use_basic_attack()`은 일부러 매니저를 안 거침**(잽마다 연타 게임이 뜨는 꼴 방지)
- **주의(Lambda capture):** `get_tree().create_timer(t).timeout.connect(func(): 노드.x = ...)`는 노드가 먼저 사라지면(나가기·다시하기) `Lambda capture ... was freed` 에러. `is_instance_valid()` 말고 **그 노드(또는 스킬 노드)의 자식 `Timer`로 예약**(`Timers.after`, `Fighter._after`, `FirePlate`, `Projectile`). 짧은 `await ...create_timer().timeout` 한 번은 그대로 둬도 됨
- **주의:** `Skill`은 `Node`라 좌표가 없다 → Skill 자식 `Hitbox`에 `position`을 주면 항상 (0,0) 기준(에러 없이 안 맞음). **반드시 `hitbox.global_position = fighter.global_position + Vector2(range * fighter.facing, 0)`**(`MeleeAttack.gd`). 맵에 직접 add_child하는 `Projectile`/`FirePlate`는 무관
- 이동을 가로채는 스킬: `Fighter.movement_override`에 자신 등록 + `get_move_velocity_x()`/`after_physics(fighter, delta)` 구현(`DashSkill.gd`)
  - 돌진 바람 줄 `skills/ChargeWind.gd`(`DashSkill.wind_lines`): **맵에 붙여 시전자를 따라다니게** — 캐릭터 자식이면 좌우 반전에 뒤집혀 반대로 흐름. 일찍 끝나면 `_end_dash()`가 `stop()`
  - 금쪽이 자전거 속도 = 이동속도 x `dash_speed_multiplier` — 금쪽이 씬 `Skill1`에서 **1.7**(2026-09-26 사용자 요청으로 2.5 -> 2.1 -> 1.7, 스크립트 기본 2.5). `dash_duration` 0.9초는 그대로라 거리도 약 850 -> 578px로 같이 줄었다. `DashSkill`은 금쪽이만 씀
  - **상대를 들이받아도 자기 피해 없음**(`enemy_hit_self_damage` 0, 2026-09-28) — 튕겨 나오기만 한다. 0이면 `take_damage(0)` 대신 넉백·경직만 직접 준다(0 피해로 부르면 번쩍임·아픈 표정·콤보 수가 들어감). 벽 자해(`self_damage_on_wall`)는 그대로
  - **들이받으면 자전거가 부서지며 부품 하나만 튀어 바닥에 남는다**(`wreck_on_enemy_hit`, `combat/BikeWreck.gd`, 2026-09-28 사용자 요청·결정): **바퀴 / 안장 / 파란 몸체 중 하나를 랜덤**(`pick_one`), 나머지 자전거는 그 자리에서 사라진다(`BodyRig.break_bike()`). 조각 그림 `sprite/축법소년/자전거_조각_바퀴/안장/몸체.png`는 원본 `자전거.png`와 **같은 캔버스**라 자전거 자리에 그대로 겹쳐 시작한다 — 바퀴 = 앞바퀴 아래 절반을 180도 돌려 붙인 포크 없는 바퀴, 안장 = 안장+기둥, 몸체 = 바퀴 원(반지름 270)·안장을 뺀 파란 프레임(+핸들·페달). 알파 24 미만 점은 지워 둠(회전 중심 틀어짐 방지). 자전거 그림을 바꾸면 조각도 다시 만들 것. 조각은 튀어 올라 돌다 되튀고 미끄러져 멈춘 뒤 라운드 끝까지 남는다. **바닥 닿음은 그림 네모 상자가 아니라 색이 칠해진 부분의 볼록 껍질(`_hull_of`)로 잰다**(상자로 재면 돌아간 바퀴가 떠 있었다, 사용자 지적) + 바닥에 닿으면 무게중심이 낮아지는 쪽으로 넘어져 눕는다(`topple_speed`, 안장·몸체가 끝으로 서서 멈추지 않게). **그리기 순서는 z_index를 낮추지 말고 맵에서 첫 캐릭터 바로 앞으로 `move_child`** — z -1이면 배경이 z 0인 맵(헬스장)에서 배경 뒤로 숨었다. 다음 돌진엔 새 자전거가 나온다
- `Fighter.is_feared`/`apply_fear(duration)`(`FearSkill.gd`): 이동은 되고 스킬·기본공격 전부 무시, `set_tint`로 표시
- `Hitbox.pull_to_source`/`pull_strength`: 고정 넉백 대신 공격자 쪽으로 끌어당김(`VacuumSkill`)
- `skills/AoeAttack.gd`: 자신 중심 원형 범위 공격, `slow_multiplier`/`slow_duration`으로 둔화(`apply_temp_multiplier`)
- **주정뱅이 술 스택**(`DrinkSkill.max_stacks` 3): 토하기는 입에서 뻗는 **가로 기둥** — 길이 `base_range` + 스택 x `range_per_stack`, 두께 `base_height` + 스택 x `height_per_stack`(두께는 그림 몸통 비율에 맞춘 값). 풀스택은 벽에 붙어 쏴도 반대편 벽까지 닿음(의도)
- **토 기둥 그림은 스택별 4장 교체**(한 장을 늘리면 0스택이 1/20로 찌그러짐): `sprite/주정뱅이/토사물모음/1~4스택.png` — **파일 1~4 = 스택 0~3**, **3스택은 `4스택진짜.png`**(`4스택.png`는 안 씀)
  - `VomitBeam.stack_textures`(index = 스택) + `stack_body_rects`(각 그림에서 기둥 몸통 영역 — 방울이 흩어져 있어 전체를 쓰면 위치가 어긋남). 몸통 영역이 판정 사각형에 겹치게 배치. **그림을 새로 그리면 몸통 영역을 다시 잴 것**(세로 중앙선을 지나는 연속 불투명 구간 기준)
  - 벽에 막히면 누르지 말고 `region_rect` 가로를 잘라냄(영역 시작 (0,0) 유지)
  - 텍스처 못 찾으면 `push_warning` + `_visual.visible = false`(fallback 없음, `VomitBeam.tscn`의 `Visual` 기본 텍스처 비움)
- `skills/VomitBeam.gd`/`.tscn`: `Hitbox` 상속, **맵에 붙여 `global_position`으로 입 위치에**. `VomitSkill`이 `setup(방향, 길이, 두께, 데미지, 시전자)`, 지속·넉백은 씬 보유. 왼쪽이면 그림만 `scale.x` 음수, 판정은 `_facing` 곱한 위치. `stop_at_wall` 레이캐스트는 `fighters` 제외
- **함정 — 토 그림이 안 보이면(또는 옛 갈색) 스크립트 파싱 오류부터 의심.** Godot은 스크립트를 떼고 씬을 띄우며 다른 `@tool`에서 "placeholder instance" 에러가 줄줄이 남 → Output 패널 파싱 에러부터(예: 이중 대입 `= [] = [...]`)
- **주의:** `Projectile`이 시전자 본인 Hurtbox/몸에 반응해 즉시 사라지던 문제 → `_on_area_entered`/`_on_body_entered`에서 `source_fighter` 무시. **판정을 키우거나 느리게 만들 때 재발 주의**
- `AIController`는 원거리 판단에 `skill_2`의 `projectile_scene`과 **`beam_scene`**을 함께 본다(안 보면 주정뱅이가 근접처럼 돌진)
- **주의:** 해제된 객체는 `== null`이 **true**(`is_instance_valid()`만 false) → `x != null and not is_instance_valid(x)`는 절대 발동 안 함. 시전자만 사라진 뒤 맵에 남은 판정이 타입 에러를 내서, `Hitbox.source_fighter`를 setter로 만들고 **주인 유무를 `_has_source`로 따로 기억**. 주인이 원래 없는 히트박스(열차)도 동작해야 하므로 `is_instance_valid`만으로 막지 말 것
- **주의:** `Projectile` 수명 타이머를 `_ready()`에서 만들면 add_child 뒤에 넣은 `lifetime`이 무시됨 → `setup()`의 `_start_lifetime_timer()`로 옮김(아래 add_child 함정과 같은 건)
- `skills/ScreamConeUltimate.gd` + `ScreamCone.tscn`(주정뱅이 궁 괴성): 맵에 띄운 **부채꼴** 판정(`Hitbox` 상속)으로 데미지+넉백+점프 디버프. 빨간 부채꼴(`RangeFill`/`RangeOutline`)은 판정 폴리곤과 **같은 점 배열**(보이는 범위 = 맞는 범위). 음파는 `wave_texture` 없으면 코드로 그린 호
  - **한 값은 한 곳에만**: 데미지·입 위치·디버프는 캐릭터 씬 `SkillUltimate`, `cone_range`·`half_angle_deg`·연출은 `ScreamCone.tscn` 루트(양쪽에 두면 한쪽이 덮여 안 먹음)
- `skills/MouseGrab.gd`(악플러 스킬1 유선 마우스 그랩): 던질 때 `sprite/악플러/몸/마우스 선.png`, 잡은 뒤 `묶인거.png`. 한 장짜리라 **유선과 물체를 `region_rect`로 잘라 따로 그림** — 유선만 늘리고(`_stretch_cord`) 물체는 배율 고정
  - 잘라 쓰는 영역(`Rect2`)·케이블 중심선 축은 코드 상수 — **그림을 다시 그리면 전부 다시 잴 것**
  - 유선은 `centered = false` + `offset`으로 중심선을 원점에 맞추고 두 점을 잇는 각도로 회전. 왼쪽은 `scale.x` 부호 반전(회전 180이면 물체가 위아래로 뒤집힘 — 유선만 회전)
  - **유선 시작점은 리그의 실제 오른손**(`BodyRig.get_hand_position()` = `HandRHold`)
  - 뒤쪽이 포물선으로 처짐(`throw_drop_after` 이후 `throw_gravity`; 1이면 직선). **실효 사거리는 `max_range`가 아니라 중력이 정함**(손이 지면에서 27px뿐) — 늘리려면 중력↓ 또는 `throw_drop_after`↑
  - `throw_stop_on_ground`: 지면·발판에 닿으면 끝(안 그러면 땅에 박혀 미끄러짐). 착지는 선분 레이캐스트로 **법선이 위인 면만**(벽 통과 — 맵마다 사거리 일정), `fighters` 제외. 거리 판정은 시간이 아닌 **x 이동 거리**(손이 따라 움직여서)
  - 잡기 판정은 `STATE_FLY` 전체(처지는 구간 포함), **되감기(`STATE_RETURN`) 중엔 없음**(의도), 잡기를 착지보다 먼저 봄. 빗나가면 손으로 되감김(`throw_return_speed` ≈ `throw_speed` x 1.5; ≤0이면 즉시 `_release()`). 끌어오기가 길면 `reel_speed`↑
  - **던지는 속도 2026-09-27 1.6배**(사용자 요청): `throw_speed` 500 -> 800, 되감기 800 -> 1280, 사거리 유지하려고 `throw_gravity` 900 -> 2304(= x1.6²). **속도를 바꾸면 중력은 배수의 제곱으로 같이** — 안 그러면 사거리가 늘어난다. 끌어오기 `reel_speed`는 그대로. 옛 실측값은 현재 값과 안 맞음(재측정 필요)
  - 젖히기(`throw_windup`)와 날아가기는 같은 식(`_draw_throw()`)이라 유선 길이가 안 튐. 팔은 `BodyRig.play_cast_motion(젖히는 시간, 돌아오는 시간)` — **젖히는 시간 = `throw_windup`**. 잡은 뒤 `set_reeling(true)`, `_release`/`_exit_tree`에서 끔
  - 크기 `mouse_length`/`coil_width`는 **`MouseGrab.new()` 후 `setup()` 전에 대입**(setup에서 그림 생성)
- `Fighter.vault_jump`(지하철 아저씨): 기본공격 없음, 점프 시 `_play_vault_effect()` 회전 연출
- **주의(add_child 함정):** `add_child(node)`는 `_ready()`를 **즉시 동기 실행** — 그 다음 줄에서 export를 세팅해도 `_ready()`는 기본값으로 끝난 뒤. `_ready()`에서 export를 캐싱하지 말고 **첫 `_physics_process`/`_process`(`_initialized` 플래그)** 로 미룰 것(`CatPet.gd`에서 겪음)
- **촉법소년의 게임 표시 이름은 "금쪽이".** 표시 이름이 곧 키라 바꿀 땐 **전부 같이**: `GameState`(CHARACTERS·색·초상화·리그), `ChokbeopsonyeonStats.tres`, `CharacterSelect.tscn`, `CharacterDex.tscn`, `PortraitFrames.tscn` 노드 이름, `Stage.knockout_characters`, `sprite/도감/전신/금쪽이.png`. 내부 이름(`chokbeopsonyeon`/"촉법소년")은 그대로

### 캐릭터별 스킬 구성 현황 (2026-09-15 기준)

캐릭터 씬의 `BasicAttack`/`Skill1`/`Skill2`/`SkillUltimate` 스크립트가 전부다. **빈 `skills/Skill.gd` = 쿨만 도는 껍데기.**

| 캐릭터 | 기본공격 | 스킬1 (G/K) | 스킬2 (H/J) | 궁극기 (R/P) |
|---|---|---|---|---|
| 촉법소년 | `ComboMeleeAttack` (막대사탕 3타) | `DashSkill` (자전거 돌진) | `BBGunSkill` (비비탄) | `HealSkill` 50초 |
| 악플러 | `ComboMeleeAttack` (키보드, 두 손) | `MouseGrabSkill` | `RageBuffSkill` (열등감) | `WeakenAuraUltimate` |
| 주정뱅이 | `ComboMeleeAttack` (술병) | `DrinkSkill` (술 스택) | `VomitSkill` (토 기둥) | `ScreamConeUltimate` (괴성) |
| 고양이 아주머니 | `ComboMeleeAttack` | `TunaThrowSkill` | `TunaPlaceSkill` | `CatHutUltimate` |
| 층간소음 청년 | `ComboMeleeAttack` | `AoeAttack` (기타, 둔화) | `VacuumSkill` (흡입) | `DunkUltimate` |
| 지하철 아저씨 | **없음** (`vault_jump`) | `TurnstileSkill` | `FearSkill` | `TteokbokkiUltimate` |
| 헬스장 빌런 | `ComboMeleeAttack` | `LivingShadowSkill` | `BackSuplexSkill` | **빈 `Skill.gd`** |
| 일진 | `ComboMeleeAttack` (3타 가방) | `CigaretteSmokeSkill` | `ShoulderChargeSkill` | **빈 `Skill.gd`** (컷인만) |
| 주인공(경찰, 훈련장 전용) | `ComboMeleeAttack` (경봉) | **빈** | **빈** | **빈** |

- `skills/DunkUltimate.gd`(층간소음 궁): 상대 쪽으로 도약 후 착지 지점 범위 공격, 도약 중 `movement_override`로 좌우 잠금
- `skills/TteokbokkiUltimate.gd`(지하철 궁): `channel_duration` 동안 전진하며 `drop_interval`마다 `FirePlate` 흘림, 벽에 닿으면 종료
  - **오픈 이슈:** 기획은 "궁 키를 누르고 있는 동안 이동"인데 원샷 입력이라 고정 시간 채널로 단순화
- **빈 껍데기(헬스장·일진 궁, 주인공 스킬 3칸)는 의도된 미구현.** 로스터 여부는 `GameState.CHARACTERS` / `TRAINING_ONLY_CHARACTERS`로 가름(주인공만 훈련장 전용)

## 조작 / AI

- `controllers/PlayerController.gd`: 입력 → 부모 Fighter. `player_index`(1/2)로 `p1_*`/`p2_*`
- `controllers/AIController.gd`: **규칙 기반**(학습 아님). 2026-09-27 사용자 요청으로 전면 강화 — 판단 순서: 기믹 피하기 -> 상대 공격 읽기(`_update_threat`) -> 왕관 -> 발판 길찾기 -> 거리 싸움 -> 스킬. Fighter는 사람/AI 구분 없음(`move()`·`use_skill_1()` 공용)
  - **공격 읽기:** 상대 기본공격 `_swinging`·돌진(`movement_override` + 빠른 속도)·날아오는 `Projectile`(도달 0.35초 안)·상대 소유 판정을 `reaction_time`(0.09초) 늦게 알아채 한 번 대응 — `guard_react_chance`로 방어, 못 하면 투사체·돌진은 점프, 근접은 대시(뒤가 막히면 상대를 뚫고 등 뒤로). 예전의 "가까우면 확률로 방어"는 없앴다
  - **거리 싸움:** 사거리는 기본공격 `range + 28`로 자동. 콤보 중엔 밀려난 상대를 따라가며 계속 누름(휘두르는 중 입력은 예약돼 맞으면 다음 타). **상대가 방어 중이거나 내 공격이 잠겼으면 치지 않고** 상대 사거리 바로 밖에서 기다림. 상대 빈틈(`_target_vulnerable`: 경직·착지 경직·공격 잠김·헛손질 쿨)이면 대시로 파고듦. 가끔 사거리 밖에서 멈칫해 헛손질 유도(`bait_chance`)
  - **원거리 캐릭터**(`skill_2`에 `projectile_scene`/`beam_scene`)는 그 스킬이 준비됐을 때만 `ranged_distance` 유지, 아니면 근접으로 싸운다
  - **스킬:** `_want_skill()`이 스킬 스크립트 이름(`get_global_name()`)별로 사거리·높이·방어 여부를 따져 맞을 때만 씀(사거리는 스킬 export에서 읽음). **새 스킬을 만들면 여기에 한 줄 추가**(없으면 "250px 안에서 가끔"). 맵 스킬(내리찍기)은 상대 바로 위 공중에서
  - **발판 길찾기:** 맵의 StaticBody2D 직사각형 충돌을 1초마다 모아(`_refresh_platforms`, 부서진 발판 제외) 발판 그래프를 만들고, 상대(또는 왕관)가 선 발판까지 가장 적게 갈아타는 길의 다음 발판으로 간다. 오를 수 있는 높이는 `Fighter` 점프 값으로 계산(1단+2단, 스프링 좌석이면 튕김+2단). 원웨이는 밑에서 뚫고, 막힌 발판은 옆에서 뛰고, 내려갈 땐 `drop_through_platform()`. **스프링 좌석 위에선 점프를 누르지 않는다**(튕김 속도를 덮어씀)
    - **기울어진 충돌(놀이터 왼쪽 미끄럼틀)은 발판 목록에 없다** — 그 밑에 끼이면(가려는데 가로 속도 0, 벽 아님) `_update_stuck`/`_run_detour`가 머리 위가 뚫린 곳(`_head_clear`, 어깨 너비 광선 3줄 — 한 줄이면 판 모서리를 놓침)까지 물러나 곧게 이단 점프하고, **이단 점프 정점에서야** 원래 방향으로 간다. 놀이터 P1 스폰(-560, 240)이 바로 그 밑이다
    - 발 높이로 오가는 방해물은 `"ai_jump_over"` 그룹 + `ai_obstacle_position()`(지금 그네 `maps/Swing.gd`)으로 알리면 AI가 다가갈 때 뛰어넘는다(`_jump_obstacles`, 콤보 중엔 안 함)
  - 열차가 오는 중엔 피난처를 벗어나는 회피(대시·점프)를 안 하고 피난처에 선 뒤에만 방어한다 — 상대 고양이를 피하려다 의자에서 떨어져 열차에 맞았었다. 피난처 위에서 상대가 코앞이면 제자리에서 때린다
  - **검증(2026-09-27, 옛 AI와 같은 캐릭터 미러전, 편의점·지하철·놀이터 x 8캐릭터 x 좌우 = 48판):** 1차 38승 9패 1무 -> 열차 회피·끼임 탈출·그네 넘기 수정 뒤 **47승 1패**(평균 남은 체력 차 +59%p). 놀이터에서 꼭대기 왕관까지 올라감 확인. 옛 AI는 git 이력(`controllers/AIController.gd`, 2026-09-27 이전)
  - 기믹(열차) 중엔 방어 안 함(`_hazard_active()`). `ClaudeAIController`의 `guard_bias`는 방어 확률 배수로 그대로 쓰임
  - ⚠️ `Fighter.move()`/`dash()`가 `facing`도 바꿈 → 후퇴·뒤로 대시 직후 `fighter.facing`을 강제로 되돌릴 것(안 하면 투사체가 반대로 나감)
- 조작키 — `project.godot` InputMap:

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
| 방어 | S | ↓ | `p1_down` / `p2_down` 누르는 순간 발동 (1초 무적 / 쿨 5초) |

  - **이단 점프**: `Fighter.jump()`가 `is_on_floor()`로 지상/공중 구분. `max_air_jumps`·`air_jump_velocity`·`gravity`·`jump_velocity`는 **static var**(훈련장에서 바로 변경). 공중 점프는 `velocity.y`를 덮어씀. `_air_jumps_left`는 `move_and_slide()` **뒤에** 채울 것(앞이면 한 프레임 늦음)
  - 점프력은 `DEFAULT_JUMP_VELOCITY`/`DEFAULT_AIR_JUMP_VELOCITY`(지금 이단 점프 전체 ≈ 216px). 높이 = 속도²/(2x중력). **점프·중력을 바꾸면 맵 발판 사다리(층 간격)가 끊기므로 맵 높이를 같이 확인**(놀이터·지하철 의자·공사현장)
  - 이동속도는 `stats/*.tres`의 `move_speed`
  - **낙하 중력 배수** `Fighter.fall_gravity_multiplier`(static, `velocity.y > 0`일 때만; 사용자 요청으로 현재 1.0=꺼짐). 경직 중엔 안 곱함(콤보 궤적 보호). 낙하 높이→속도 역산은 반드시 `_fall_gravity()` 사용(착지 경직·먼지 기준). `IljinCrewMember`·`LivingShadow`는 `Fighter.gravity`만 씀
  - **착지 경직**(사용자 결정: 높이 기준 하나): `landing_lag_height` 이상 낙하 착지 시 `landing_lag_time` 동안 전부 막힘(`is_busy()` 포함), `BodyRig.play_land_crouch`(발은 제자리, 몸·머리·손만 내림). 둘 다 static var, 0이면 꺼짐
    - 경직 동안 몸 전체가 납작하게 눌린다(`BodyRig.land_lag_squash` (1.15, 0.86), 2026-09-26 사용자 요청) — 주저앉는 정도(`_land_crouch_amount()`)만큼 `_squash`를 잡아두고, 착지 순간 스쿼시(`land_squash`)가 더 세면 그게 풀릴 때까지 그쪽을 따른다
    - **모든 스쿼시·스트레치는 발바닥(`squash_pivot_y` +30) 기준** — 몸 중심 기준으로 누르면 발이 뜬다. 리그 y를 통째로 덮지 않고 `_squash_lift`로 더한 만큼만 뺐다 더한다(`BodySuplexSkill`처럼 리그 위치를 잠깐 쓰는 스킬과 안 싸우게). `play_squash()`(회복 팝·괴성)도 이제 발 기준으로 부푼다
    - 피격 낙하(`_launch_momentum`/경직)·`movement_override` 착지는 제외. 낙하 속도·공중점프 사용 여부는 `move_and_slide()` **전에** 기억(착지하면 지워짐)
    - 착지 즉시 튕기는 기믹은 `cancel_landing_lag()` 호출 필수(`SpringJumpPad`처럼 — 안 하면 공중에서 조작 불가)
  - **대시**(방향키 두 번, `PlayerController.DOUBLE_TAP_WINDOW`): 거리 = `dash_speed` x `dash_duration`(static var). 스킬 아님(클래시·`is_busy()` 무관), 공중 가능, 중력 받음
    - `apply_physics`에서 대시 속도 → `movement_override`가 덮어씀(override 쪽이 이김). 맞으면(`_hitstun_time > 0`) 끊김
    - 두 번째 탭 인정 시 탭 기록 삭제(안 하면 연타마다 대시)
    - 잔상 `_spawn_dash_afterimage()`는 `Visual` 복제 후 **스크립트를 뗄 것**(안 떼면 BodyRig가 잔상에서도 돔)
    - TODO: 대시·방어 쿨 HUD 없음(`_dash_cooldown_left`/`_guard_cooldown_left` 사용)
  - **아래 키 방어**: 누르는 순간 `combat/GuardShield.gd` 켜짐, `guard_duration` 동안 데미지·넉백 0, 이후 `guard_cooldown`. 누르고 있는 방식 아님
    - `take_damage`에서 `is_invincible`과 같은 자리에서 early return(넉백·경직도 없음). 막은 양은 `custom_data["guard_absorbed"]`
    - 디버프·그랩 차단, **궁극기 디버프만 관통**(사용자 결정) — 판정은 `Fighter.blocks_debuff(from_ultimate)` 한 곳. 스킬 디버프는 `apply_temp_multiplier`에서만 차단(궁은 마지막 인자 true). `set_modifier` 직접 호출(맵 기믹·자기 버프)은 검사 안 거침 → 맵 디버프는 방어 관통
    - 그랩은 "아예 안 잡히게": `MouseGrab._touches_opponent()`·`BackSuplexSkill._find_target()`이 `Fighter.can_be_grabbed()` 확인
    - 방어 중 이동·점프·공격·스킬 전부 막힘, 수평 속도 0 고정
    - 함정: 아래 키가 발판 통과와 겹침 → `GUARD_CANCEL_WINDOW` 안에 점프가 오면 `cancel_guard(true)`로 쿨 환불
    - 자세 `BodyRig.set_guarding()`(`_guard_blend`). 손 위치는 머리 오른쪽 끝(x=25)보다 앞에 둘 것 — 얼굴에 붙이려면 x 말고 y를 올릴 것(촉법소년만 손 `z_index=1`이라 x를 줄이면 캐릭터마다 다르게 보임). `guard_hand_deg`는 음수여야 함(양수면 무기가 머리 위로)
    - 보호막은 `_draw()`(남은 시간 테두리). `Fighter._shield`는 무타입(새 `class_name`을 preload로 가져와 타입 붙이면 캐시 전 파싱 에러)
  - **슈퍼아머** `Fighter.add_super_armor()`/`remove_super_armor()`/`has_super_armor()`
    - HP·반짝임·콤보 카운트·`damaged` 신호는 들어감 / 넉백·경직·구르기·피격 기울기·잡기·기절 별은 막힘
    - `velocity`를 직접 덮는 띄우기(어깨치기)는 `apply_physics`에서 위로 솟는 속도를 0으로 자름
    - **개수로 셈** — 거는 쪽은 반드시 add/remove 짝으로. `blocks_debuff()`에 섞지 말 것(공포·도트까지 막힘)
    - 사용처: `BackSuplexSkill.super_armor`(경찰 `Police.tscn` Skill1만 켬). `_begin()`에서 걸고 `_release()`/`_exit_tree()`에서 품
  - **플랫폼 내려가기**: `PlayerController._drop_through_platform()` → `Fighter.drop_through_platform()`. 발판 위가 아니면 평범한 점프
    - 레이어를 끄지 말고 `add_collision_exception_with(발판)`(레이어 끄면 지면·벽까지 통과), `DROP_THROUGH_DURATION` 뒤 `_after`로 복구
    - 발판 판별 `Fighter.get_one_way_floor()`(공개 — `GroundPoundSkill`도 씀): 법선 위 + `is_shape_owner_one_way_collision_enabled()`
    - 예외는 발판 **바디 전체**에 걸림 → 한 바디에 막힘 충돌(기둥 등)을 섞지 말 것

## 캐릭터 몸(스프라이트 조립)

`characters/BodyRig.tscn` — 머리/몸/손/발 Sprite2D 조립 공용 몸. 캐릭터 씬 `Visual` 자리에 인스턴스(이름 `Visual`이라 `_flash_hit`·궁 연출이 동작).

- 파일: 공용 `sprite/body/` / 전용 `sprite/<캐릭터>/몸/`. 층간소음·캣맘·지하철은 `sprite/층간소/`·`sprite/캣/`·`sprite/지하철빌/` 바로 아래 `발.png`/`손.png`(새 파츠는 두 군데 다 볼 것). 발은 공용 `발.png`와 캔버스(179x101) 같아 텍스처만 교체
- 인게임 머리 = 옆모습(리그 `Head`) / 선택창 초상화 = 정면(`GameState.PORTRAITS`만)
  - 초상화 배경은 투명이어야 함(색 타일 위에 얹힘). 흰 배경 제거는 **테두리 flood fill**(흰 머리카락 캐릭터 있음)
  - 초상화 크기·위치는 `ui/PortraitFrames.tscn`(프레임 Panel + `Portrait`)에서 캐릭터별 조절. `GameState._load_portrait_frames()`/`frame_portrait()`가 rect 크기에 `scale.x`를 곱해 환산. 초상화 네 곳(선택 그리드/미리보기/에피소드 타일/대전 HUD) 전부 이 함수 경유
  - 캣맘 초상화 = `sprite/body/면.png`(짧게 잘린 파일명)
- 캐릭터별 머리는 `BodyRig.tscn` 씬 상속(`Head` 텍스처/위치/크기만 덮어씀, 예 `characters/akpeulleo/AkpeulleoRig.tscn`)
  - **새 리그 배율은 눈대중 금지** — `Image.get_used_rect()`로 실제 영역 재서 역산(기준 몸 ~33x30, 머리 ~53x52 상한 55x55, 머리 중심 ~(-2, -32.8)). 배율 바꾸면 위치도: position = 목표중심 - (bbox중심 - 캔버스중심) x 배율
  - PowerShell 함정: 변수 이름 대소문자 무시(`$h` == `$H`)
- 조각 위치는 **`BodyRig.tscn`을 직접 열어** 옮길 것(캐릭터 씬에서 `Visual`을 만지면 그 캐릭터만 덮어쓰기)
- `characters/BodyRig.gd`: 애니 파일 없이 코드로 걷기(교차 걸음·발끝 스윙·들썩임·손 반대 흔들기·`foot_step_lift`로 옮기는 발만 들림). 왼쪽 = `scale.x` 부호만 뒤집음. 제자리 값은 `_ready()`에서 씬 위치를 기억 → 에디터에서 옮겨도 코드 수정 불필요. 공중엔 `jump_foot_deg`
- **손에 드는 무기는 `HandRHold`의 자식**(HandR 위치·회전을 매 프레임 복사하는 배율 1 Node2D — HandR 자식이면 0.11 배율 상속). `Head`보다 앞 순서라 머리 뒤로 넘어가면 가려짐(상속 씬 `Head`가 `index="6"`인 이유)
  - ⚠️ 무기 `position` 오프셋은 그림 반길이보다 작아야 함(아니면 손에서 떨어져 날아감). 오프셋 바꾸면 `attack_raise_deg`/`attack_swing_deg`도 다시 볼 것
- **방어에 막히면** `Fighter.blocked_attack_lock` 동안 기본공격 잠김 + 오른손·무기 빨강 깜빡임, 잠긴 동안 무기에만 안쪽 테두리(`combat/BlockedOutline.gdshader`, `BodyRig._set_blocked_outline()`, 사용자 결정으로 무기만 — 되돌리려면 `_blocked_outline_targets()`)
  - 테두리는 안쪽으로 그림(바깥은 투명 여백에 잘림 — `ui/story/RimGlow.gdshader`가 반대 방식). 두께는 화면 px을 파츠 배율로 나눠 매 프레임 재설정(표정 바뀌면 배율 변함)
  - 시간의 주인은 `Fighter.blocked_attack_lock`(static), `BodyRig.blocked_flash_duration`은 예비값 — 시간은 Fighter 쪽에서 고칠 것
  - `HandR`·`HandRHold`는 형제라 `modulate`를 둘 다 걸어야 함
  - 막힘 판정은 `Hitbox._is_blocked_by_guard()`(Hitbox가 맞은 쪽 `is_guarding` 확인). 기본공격 판별은 히트박스 부모가 공격자의 `basic_attack` 노드인지
- **맵 피해는 `Fighter.take_map_damage()` 한 곳으로**(주인 없는 피해 전용 처리는 전부 여기). 분기는 `Hurtbox.take_hit()`: `source_fighter` 있으면 `take_damage()`, null이면 `take_map_damage()`. 히트박스 없는 기믹(`StompZone`)은 직접 호출
  - 맵 피해는 방어를 깸(`cancel_guard()`, 쿨 소모) — 안 깨면 방어 중 `velocity.x=0`이라 넉백이 사라짐
  - `take_damage()`의 `ignore_guard`를 바깥에서 직접 true로 주지 말 것
- 막으면 "BLOCK" 팝업(`DamagePopup.setup_block()`). `Hitbox._try_hit()`이 막힘을 **한 번만** 판정해 팝업·깜빡임 공용(두 번 판정하면 BLOCK인데 HP 깎임)
- 기본공격 모션 `Visual.play_attack_swing()`: 올렸다(`attack_raise_*`) 내려찍고(`attack_slam_*`/`attack_swing_deg`) 복귀, `attack_duration` 중 40~62%가 내려찍기
  - **⚠️ `attack_duration`을 바꾸면 `BasicAttack.windup`(= duration x 0.4)도 맞출 것**
  - 손에 든 물건은 손 회전을 그대로 따라감 — 각도 고정(`attack_hold_deg`)은 넣었다 되돌림, 다시 건드리지 말 것
  - **악플러 키보드는 맨 앞(`HandRHold/Keyboard` `z_index` 1, 2026-09-28 사용자 요청)** — 머리·몸·손보다 앞에 그려진다(원래는 `Head`가 뒤 순서라 머리에 가려졌음). 1보다 크게 올리지 말 것: 대시 잔상은 `Visual`째 z -2로 복제돼 자식 z가 더해지므로, 2 이상이면 잔상 키보드가 본체 앞에 그려진다
  - 두 손 잡기 `attack_two_handed`(악플러만): 왼손 `attack_grip_offset`. `_grip_blend`는 `_attack_time > 0`이면 1 유지(타마다 풀리면 덜덜). `_pose_grip_hand()`는 `_apply_pose`에서 매 프레임. `attack_grip_speed`를 9 밑으로 내리지 말 것. 왼손 회전은 매 프레임 0으로 되돌린 뒤 덮어씀
  - 두 손 무기 타별 스윙 `_two_handed_variant_params()`: **총 회전각(raise+swing) 120도 이하**(넘으면 키보드가 얼굴 가로지름), 타별 크기 차이는 각도 말고 손 이동 거리로
  - `attack_swing_arc`(0이면 직선): 후려칠 때 손이 아래로 부푼 호
- **브롤할라식 평타 데이터 `combat/AttackData.gd`**: `ComboMeleeAttack.hits`에 .tres를 순서대로 — 목록 길이 = 타 수, 마지막 = 마무리. 지금 촉법소년만(`characters/chokbeopsonyeon/attacks/*.tres`), 비어 있으면 옛 배열(`combo_damage` 등) 사용
  - **판정 시각은 적지 않음** — `BodyRig.strike_time(모션 길이, 회전)`이 계산(보통 40%, 회전은 `spin_end x spin_strike`)
  - 따라붙기 "발 먼저": `AttackData.lunge_time`/`lunge_foot_lead`, 리그 `play_lunge_step(시간, lead)`(`_pose_lead_step`). 연타로 끊기면 남은 거리(`_lunge_remaining_distance`)를 새 걸음에 얹음. 몸 밀어내기(`BODY_PUSH_WIDTH`) 때문에 `lunge_extra` 값만큼 다 안 나감
  - 공중 피격 관성 `Fighter._launch_momentum`(착지하면 꺼짐, `LAUNCH_AIR_CONTROL`/`LAUNCH_AIR_DRAG`) — 경직이 공중에서 풀릴 때 가로 속도가 0으로 끊기던 문제 해결
- **끊어 치기 `attack_snap` + 휘두르기 잔상 `attack_smear`**(BodyRig export, 지금 촉법소년만): snap은 구간 경계(40/62%) 유지하고 구간 안 흐름만 바꿔 판정 시각 불변. 다음 타 예비동작은 앞 타 끝 자세(`_swing_from_*`)에서 출발
  - smear 잔상은 top_level, 보간은 **리그 기준 변환**으로(월드 변환은 왼쪽 볼 때 음수 배율이라 뒤집힘). 클래시 주먹 잔상(`_ghosts`)과 칸 별도
- **촉법소년 막대사탕 3타** `BodyRig.attack_thrust`(→ `_thrust_variant_params()`): 2·3타는 `thrust2_*`/`thrust3_*` export로 따로 지정(1타에서 파생 금지)
  - 사탕 `ChokbeopsonyeonRig.tscn`의 `HandRHold/Candy`: `rotation 45도` + 후리기 45도가 한 쌍(한쪽만 바꾸면 어긋남). `attack_raise_deg` 음수(머리가 커서 뒤로 당기면 사탕이 얼굴 위). 그림 바꾸면 position/scale 재측정
  - 사탕은 `z_index` 없음(3타에서 머리에 가려져야 함). BB총 중엔 `gun_hides_held_item`으로 숨김
- 마우스 던지기/줄 당기기(악플러): `play_cast_motion(젖히는, 돌아오는)`, `set_reeling(true/false)`(`_reel_blend`). **`cast_windup_offset`의 y를 -6보다 위로 올리지 말 것**(얼굴에 마우스가 얹힘). `cast_hides_held_item`은 악플러만
- **피격 움찔 `BodyRig.play_hit_flinch()`**(전원): 넉백 있는 피격이면 `Fighter._play_hit_reaction()`이 호출(BodyRig 없으면 옛 기울기). 전부 **다른 자세 위에 더하기**, 바라보는 쪽 기준. 밀림 방향은 Fighter가 넉백 x 부호 x facing으로 넘김. 구르기·슈퍼아머 중엔 없음
  - **그림만 움직이고 실제 위치·판정은 그대로** — 물리로 띄우면 금쪽이 1·2타 3타 확정이 깨짐
- **머리 돌리기 그림**(금쪽이·악플러·주정뱅이): 머리를 측면·정면·뒤통수 그림으로 갈아끼워 돈다. 세 곳에서 쓴다 — ① idle 뒤돌아보기(`_pose_lookback`) ② 방향 전환 ③ 회전 타격. `_set_head_frame(frame, dir)` / `_set_head_image()` / `_clear_head_frame()`
  - 그림 **장수는 자유**: `head_turn_textures`(측면1→…→**마지막 장이 정면**)에 끼우고 기준점·방향 칸을 +1씩 늘리면 단계(그림 n장 → 2n+1)가 알아서 늘어난다. 지금 측면1·측면2·측면3·정면
  - **방향 전환** `head_turn_on_face`(끄면 예전처럼 탁 뒤집힘): **고개 먼저, 몸은 나중(사용자 결정)** — `face_turn_duration` 앞 절반은 몸이 옛 방향인 채 머리가 정면까지 돌고, **머리가 정면인 순간 몸을 뒤집고** 뒤 절반에 새 방향 옆모습까지. 그동안 손·발이 몸 가운데로 모였다 벌어짐(`face_turn_limb_gather`, 위치만 좁힘). **옛 방향은 그림뿐이고 `Fighter.facing`은 즉시 바뀌므로** 공격·스킬·방어·피격이 시작되면 `_face_turn_blocked()`로 즉시 끝내고 몸을 새 방향에 맞춘다. 걷는 동안 매 프레임 불리는 `_end_lookback()`이 도는 그림을 안 지우게 막아 둠
  - **회전 타격** `spin_uses_head_turn`(머리 그림 있으면 켬): 몸을 cos로 얇게 누르는 대신 앞 반 바퀴는 머리 그림(정면 순간 몸 뒤집힘), 뒤 반 바퀴는 `spin_back_flip`에서 몸이 다시 앞으로 뒤집히고 그 앞뒤 `spin_back_show` 동안 **뒤통수 `head_back_texture`/`head_back_anchor`**(`축법소년 뒷머리.png`, 대칭이라 안 뒤집음). 뒤집히는 순간 앞뒤 `spin_gather_width` 동안 손·발·사탕을 모음. **`spin_back_flip + spin_back_show` < `spin_strike`** 여야 후려칠 때 얼굴이 보인다. 판정 시각은 불변. 머리 그림 없는 캐릭터는 예전 종이 뒤집기
  - export `head_turn_textures` / `head_turn_anchors`(0번 = 원래 옆모습, 각 **머리 공의 (중심x, 중심y, 지름)** 그림 픽셀) / `head_turn_faces_left`
  - ⚠️ 앵커는 프로펠러·턱 기준이면 흔들림 → **머리 공만** 잴 것(알파 1/4 축소 후 bbox 높이 22% 사각형 열림 연산, 무게중심·`2sqrt(넓이/pi)`). 그림 바꾸면 재측정
  - **악플러(2026-09-28)**: `sprite/악플러/몸/악플러 측면 1~3.png`(전부 왼쪽을 봄) + 정면은 선택창 초상화 `악플러정면머리.png`를 같이 씀. 앵커는 같은 열림 연산으로 잰 값, 방향 전환(`head_turn_on_face`)도 켬. 회전 타격·뒤통수는 없음(악플러는 회전 타격 안 함). 몸통 돌리기는 `악플러 몸 측면 2/3.png`(오른쪽을 봄) — 캔버스(887x887)·그린 크기가 원래 몸통(344x270)과 달라 **`body_turn_match_height`**(보이는 영역 높이를 원래 몸통에 맞춤)를 켰다
  - **주정뱅이(2026-09-29)**: `sprite/주정뱅이/몸/주정뱅이 측면1.png`·`주정뱅잉 측면2.png`(파일명 "잉" 오타 그대로)·`주정뱅이 측면 3.png` + 정면은 선택창 초상화 `주정뱅이얼굴정면.png`. **전부 오른쪽을 봄**(`head_turn_faces_left` 전부 false — 금쪽이·악플러와 반대). 앵커는 같은 열림 연산으로 잰 값, 방향 전환도 켬. 몸통 돌리기 그림은 없음(몸통은 정면 그대로). 소용돌이 눈(`SwirlEye`)은 기본 얼굴일 때만 그려져 도는 동안엔 그림 속 소용돌이가 보인다
  - 금쪽이 그림 `sprite/축법소년/`: 측면2 파일명이 `축법소년 픅면 2.png`(오타 그대로). 측면1·2·3은 왼쪽을 봄(뒤집어 씀). 뒤통수 그림도 `_is_turn_texture()`에 포함(안 넣으면 다른 표정으로 착각해 멈춤)
  - **몸통도 같이 돈다(2026-09-26, 금쪽이만)** — 머리만 돌고 몸통은 그대로라 "몸이 이상하다"는 지적으로. **평소 몸통은 정면 그대로**(사용자 결정 — 옆모습 몸통을 평소 몸통으로 써 봤다가 되돌림, `금쪽이 몸 측면.png`은 지금 안 씀). 머리가 **도는 도중에만** `body_turn_textures` = [`금쪽이 몸 측면 2.png`(3/4), `금쪾이 몸 측면3.png`(거의 정면 — 파일명 "쪾" 오타 그대로)]를 끼운다
    - `_set_head_frame()`이 `_set_body_frame(frame, dir)`도 부른다 — 머리가 옆(0)·정면(마지막)이면 원래 정면 몸통, 그 사이 단계만 그림을 내림 비율로 나눠 끼움(머리 측면1·2 -> 3/4, 측면3 -> 거의 정면). 뒤통수 순간·그 밖엔 원래 몸통(`_clear_head_frame()` -> `_clear_body_frame()`)
    - 몸통 그림은 전부 **오른쪽을 보고** 그린다. 원래 몸통과 같은 캔버스면 배율 그대로(금쪽이), 캔버스·크기가 다르면 `body_turn_match_height`로 높이를 맞춘다(악플러). `_body_anchor_of()`가 보이는 영역의 **바닥 가운데**를 한 번 재서 그 점이 원래 자리에 오게 위치를 더한다(반대쪽이면 dir로 뒤집음)
    - 영역은 `_opaque_rect_of()`가 **알파 절반 이상만** 4px 간격으로 잰다(리그 공용 static 캐시). `Image.get_used_rect()`는 알파 1/255 점 하나에도 늘어나서 악플러 몸 측면 3이 120px 크게 재져 떠 보였다
    - 도는 도중 손이 몸 앞에 모이는 건(`face_turn_limb_gather`) 그대로다
  - 평소 얼굴일 때만 돔(다른 표정 들어오면 양보), Fighter 있을 때만. 위치는 앞선 자세 오프셋 유지 + 제자리 차이만 더함
- **대치 자세 `fight_stance`**(사용자 결정으로 꺼짐, 기능만 있음): `HandRHold` 복사 직전에 더하기만, 공격 출발 자세에서 대치 오프셋을 빼둘 것(안 빼면 두 번 더해져 튐)
- **눈 깜빡임 `characters/EyeBlink.gd`**(@tool): 살색 타원+곡선을 코드로 그림. 리그 상속 씬에서 **`Head`의 자식**, 위치(눈 중심 - 그림 중심)·`eye_size`는 **머리 그림 픽셀 단위**. 기본 얼굴 텍스처일 때만 깜빡임(사용자 결정), 부모에 `play_attack_swing` 없으면(잔상) 안 함
  - **넣은 캐릭터 6명: 금쪽이·층간소음·일진·일진 친구·일진 여자친구·경찰(주인공).** 안 넣음: 악플러·캣맘·지하철(안경·선글라스), 주정뱅이(소용돌이 눈) — 사용자 결정. 헬스장 빌런·샌드백은 머리가 아직 임시 원이라 눈이 없음
  - 눈 재는 법: 흰자 덩어리를 찾고 거기서 바깥으로 검은 테두리가 끝나는 곳까지 = 눈 테두리 상자, `eye_size`는 그보다 가로 ~15·세로 ~18px 넉넉히(금쪽이 값과 같은 규칙). 흰자가 거의 없는 가는 눈(여자친구·경찰)은 눈으로 보고 잡았다. 감으면 위 눈꺼풀 양끝이 조금 남아 속눈썹처럼 보인다
  - 층간소음은 동그란 코가 눈 테두리 오른쪽 아래를 덮고 있어 감을 때 코 윗부분이 조금 가려진다(게임 크기에선 1~2px)
  - 칠하기는 세로 띠 `draw_primitive`(다각형 하나로 만들면 분할 실패 에러)
- **⚠️ `_draw()`로 모양이 줄어드는(폭·높이가 0이 될 수 있는) 사각형·가시는 `draw_colored_polygon` 말고 `draw_primitive`로** — 다각형 분할이 실패하면 "Invalid polygon data, triangulation failed"가 매 프레임 쏟아진다(EyeBlink·ClashBand·LaunchTrail 가시·JumpWind·HitSpark 마름모·LensGlint에서 겪음). **이 오류는 `--headless`에선 안 나온다**(그리기를 안 함) — 창을 띄워 확인할 것
- **눈이 안 보이는 캐릭터의 생동감(2026-09-26 사용자 요청)** — 셋 다 기본 얼굴 텍스처일 때만, 부모에 `play_attack_swing` 없으면(잔상) 안 함. `Head`의 자식, 좌표·크기는 머리 그림 픽셀
  - **렌즈 반짝임 `characters/LensGlint.gd`**(@tool, unshaded라 어두운 맵에서도 번쩍): 악플러·캣맘·지하철. 가끔(`interval_*`) 사선 빛줄기가 렌즈 타원(`lens_size`) 안을 훑고 지나감(세로 띠 조각으로 잘라 칠함). `blink_now()`가 있어 훈련장 "눈 깜빡임" 버튼으로도 나온다. 에디터에선 렌즈 범위가 하늘색 선으로 보이고 `preview`로 빛줄기 미리보기
    - **악플러는 렌즈가 흰색이라 흰 빛이 안 보여** 굵은 줄기(`band_width` 0.3)·느린 훑기(`sweep_time` 0.45) + 모서리 반짝 별(`sparkle_size` 150, 테두리도 별 크기 비례, 2026-09-27 "더 잘 보이게"). 2026-09-28 "하얀색 느낌"으로 **흰 `glint_color` + 옅은 하늘색 테두리(`band_edge_color`/`band_edge_width`)** — 흰 빛만으론 흰 렌즈에 묻혀서 둘레를 두른다
    - 렌즈 재는 법: 악플러 흰 덩어리 / 캣맘 진한 하늘색(빨강 낮은 픽셀 — 두건의 옅은 하늘색과 구분) / 지하철 검정 덩어리를 **열림 연산으로 외곽선 떼고**(안경다리는 눈으로 빼고) 그 bbox. `lens_size`는 렌즈 테두리 안쪽으로 조금 작게
  - **소용돌이 회전 `characters/SwirlEye.gd`**(@tool): 주정뱅이. 그림의 소용돌이를 흰 원(`eye_size`, 눈 테두리 **안쪽**)으로 덮고 코드로 그린 나선(`turns`/`spiral_radius`/`line_width`)을 `spin_speed`로 돌린다. 몇 초마다 빨라짐(`surge`). 흰 원·나선은 조명을 받는다(머리와 같은 밝기)
  - **특수 idle 몸짓 `BodyRig.idle_special`**: 1 안경 올리기(악플러) / 2 딸꾹질(주정뱅이). 가만히 있으면 머리 긁기·뒤돌아보기와 셋 중 하나로 랜덤(`_start_special`/`_pose_special`/`_end_special`, 움직이면 즉시 취소)
    - 안경 올리기: 왼손이 `glasses_hand_pos`(리그 좌표 — 악플러 렌즈 앞쪽 끝 (17, -25), 머리 위치·배율로 계산)로 올라가 쓱 밀고 고개가 살짝 들린다. **왼손은 원래 머리 뒤에 그려져서 올라가 있는 동안만 `z_index` 3**, 끝나면 `_hand_l_rest_z`로 복구
    - 딸꾹질: `hiccup_count`번 머리가 톡 튀며 젖혀지고, 매번 머리 위에 `hiccup_text`("딸꾹!", 주아체) Label이 떠올랐다 사라진다 — **top_level**이라 리그가 좌우로 뒤집혀도 글자는 안 뒤집힘
    - 훈련장 "특수 몸짓" 버튼(`play_special()`)
- **피격 표정** `hurt_head_texture`(`play_hurt_face()`). 그림 없으면 스킵, 여백 다르면 `hurt_head_scale`. (HP 낮을 때 지친 표정은 2026-09-26 삭제됨)
  - 잠깐 표정 우선순위 **피격 > 토하기**, 그 아래 기본 머리 **액션 > 취함 > 지침 > 맨정신**(`_apply_base_head()`, 취함>지침은 사용자 결정 — 술 스택 정보라). `set_action_face`/`set_drunk_head`는 미뤘다가 `_restore_head()`로 복귀
  - **주정뱅이 토하는 얼굴·술 머금은 얼굴 배율(2026-09-29 사용자 지적 "머리가 너무 작다")**: 두 그림은 캔버스(1254)·그린 크기가 평소 머리(1330x1182)와 달라 옛 값(0.05·0.051, 가로세로 같음)이면 12~16% 작았다. 평소 머리는 가로세로 배율이 다르다(0.045, 0.0507) — 같은 비율을 유지한 채 **알파 절반 이상 영역 높이(머리카락 끝~머리띠 끈 끝)** 를 평소 머리와 같게: 토 (0.0526, 0.0593) + `vomit_head_offset` (3.6, 0.3)(뒤통수 쪽 끝을 맞춤 — 벌린 턱은 앞으로 나와서), 술 머금은 (0.0513, 0.0578). 그림을 바꾸면 같은 방식으로 다시 잴 것
  - `Fighter._update_hp_face()`는 `take_damage`/`heal`/`ring_out` **세 군데 전부**에서 호출(하나 빠지면 회복 후에도 지쳐 보임)
  - 악플러 기본 머리는 `sprite/악플러/몸/악플러대가리.png`(2026-09-28 사용자가 `sprite/body/`에서 옮김 — **옮기며 uid가 새로 붙어** 리그 `ext_resource` 경로·uid를 같이 고쳤다. 파일을 탐색기에서 옮기면 참조가 깨지니 Godot 파일시스템 창에서 옮길 것)
  - ⚠️ 그림이 `.godot/imported/*.ctex` 캐시에만 있고 원본이 없던 적 있음(`축법소년 머리.png`) → `.ctex`(offset 56부터 WebP)에서 추출, `.import` 두면 uid 유지
- 술 마시기(주정뱅이 스킬1) `play_drink_motion()`: 공격 다음에 덮어씀(겹치면 마시기 이김), 머리 회전도 매 프레임 0 리셋 후 덮어씀
  - 술병 `JujeongbaengiRig.tscn`의 `HandRHold/Bottle` 제자리 position/rotation은 이미 붓는 자세 — **바꿨다 되돌렸으니 다시 건드리지 말 것**(그래서 `drink_hand_deg` 0)
- TODO: 공격 모션 미완

### 그림 파일을 교체할 때 (실제로 겪은 함정)

- ⚠️ 에디터 밖에서 PNG를 덮어쓰면 재임포트 안 됨(옛 그림·옛 크기 사용) → 해당 `.png.import` 삭제 후 `godot --headless --editor --path <프로젝트> --quit`
- 그림을 바꾸면 `get_used_rect() x scale`이 예전과 같게 배율 재계산, `centered`면 유효영역 중심 차이만큼 position 보정
- 흰 배경 제거는 "흰색 전부 지우기" 금지, 바깥 테두리 flood fill(흰 머리카락 보호)
- 그림을 갈아끼우면 씬의 경로·uid·배율·위치를 전부 확인 — "안 보인다"의 첫 원인은 지워진 파일을 가리키는 `ext_resource`

### 일진 (2026-09-13 추가 — 7번째 캐릭터)

`characters/iljin/Iljin.tscn` + `IljinRig.tscn`, `stats/IljinStats.tres`, 그림 `sprite/일진/`. `GameState` CHARACTERS·COLORS·PORTRAITS, `PortraitFrames.tscn` 등록됨.

- 기본공격: `attack_thrust` 3타(1·2타 주먹, 3타 두 손 가방). 평소 가방은 왼손 `HandL/BagIdle`(`show_behind_parent`), 마지막 타에만 `HandRHold/Bag`
- 스킬1 `CigaretteSmokeSkill.gd` + `CigaretteSmoke.tscn`: `windup` 뒤 `duration` 동안 입 앞 연기(맵에 붙어 입을 따라감), `start_busy`로 공격·스킬 잠김. 손 동작은 마시기 모션 재사용(`drink_duration` = windup x4, `drink_head_tilt_deg` 0)
- 스킬2 `ShoulderChargeSkill.gd`: 돌진(`ChargeWind.gd`), 맞으면 둘 다 같은 `launch_speed`로 뜨고 상대만 기절(`StunStars`), 가드면 안 뜸. 끝나면 `end_busy()`로 평타 연계
  - ⚠️ `take_damage`는 넉백을 기존 속도에 **더함** → 받은 뒤 양쪽 `velocity`를 같은 값으로 덮어쓸 것
- 공용 BodyRig 추가(기본 꺼짐): `weapon_on_final_hit`(+`weapon_node`/`idle_weapon`/`final_hit_index`), `set_charging()`(기울기에 facing 부호), `Fighter.end_busy()`
- ⚠️ **액션 표정 슬롯은 하나** — 스킬이 `action_head_texture`를 런타임에 갈아끼우므로 표정 쓰는 스킬은 자기 얼굴을 직접 지정(`smoke_face`/`charge_face`, 안 하면 앞 스킬 얼굴이 나옴)
- **궁극기 `skills/IljinCrewUltimate.gd`**(컷인 `ui/cutin/IljinCutIn.tscn`): 1단계(등장)까지만 구현. 좌우 `side_offset`에 친구(왼쪽)·여자친구(오른쪽)가 페이드인. **좌우는 화면 기준 고정, 방향만 일진과 같음**(사용자 지정). TODO: 공격·버프·퇴장
  - **길은 막되 머리 위엔 못 서게**(사용자 요청): 캐릭터와 몸 충돌을 끄고(`_ignore_fighter_bodies()`, 양방향) 가로로만 밀어냄(`_block_fighters()`, `Fighter.BODY_PUSH_WIDTH`/`BODY_PUSH_HEIGHT` 사용)
    - 도형으로는 못 막음(뾰족 도형도 꼭짓점 착지 시 바닥 판정, `floor_max_angle`은 밟는 쪽 값)
    - 예외는 `_ready()` 한 번이 아니라 매 물리 프레임 훑기(`_ignored`로 중복 방지) — 나중에 생긴 캐릭터 누락 방지
    - 밀리는 건 상대뿐, 부른 일진은 안 밈
  - **패거리 = `IljinCrewMember`(CharacterBody2D + Hurtbox + Visual)**: `characters/iljin/IljinFriend.tscn`/`IljinGirlfriend.tscn`. 중력(`Fighter.gravity`)·넉백(`Fighter.take_damage` 계산 복사, `knockback_friction`)·바닥/벽/발판 충돌. HP(`max_hp`)가 0이면 페이드아웃, 부른 일진이 죽으면(`Fighter.died`) 같이 사라짐. 주인이 시그널 없이 사라지는 경우는 `_had_owner` 불리언(해제 객체는 `== null`이 true). 부른 사람 공격은 `Hurtbox.immune_source`로 면역
    - **Fighter로 만들면 안 됨** — fighters 그룹(카메라·AI 오인) + `_ignore_other_fighters()`로 몸 충돌이 꺼져 통과됨
    - ⚠️ `Hurtbox.fighter`를 `Node`로 풀었으므로 받는 쪽은 `area.fighter as Fighter`로 확인(`Crown`·`SandPit`·`SpringJumpPad`·`Swing`이 단정했다가 타입 에러 폭주). `Hitbox._is_blocked_by_guard()`도 `"is_guarding" in victim`. 앞으로 HP 있는 오브젝트는 `take_damage()`/`take_map_damage()`/`is_guarding`만 있으면 됨
    - idle 모션 끔(`BodyRig.idle_gestures = false`, 사용자 요청). 방향은 루트 말고 `Visual`에만(루트 음수 배율은 충돌 도형까지 뒤집음). 피격 빨강은 `Visual.modulate`(루트는 페이드가 씀)
    - 리그 `IljinFriendRig.tscn`/`IljinGirlfriendRig.tscn` — 손·발은 공용과 캔버스 같아 텍스처만 교체
  - **친구 침 뱉기**: 하늘색 파선 경고(`skills/SpitWarning.gd`, 길이 = 실제 사거리) → 침(`skills/Spit.tscn`, 관통) → `spit_interval` 반복. `spit_scene`이 비면 안 함(여자친구). 침의 주인은 일진(방어로 막히고 일진은 안 맞음)
    - `face_opponent`: 매 프레임 몸 좌우(`Visual.scale.x`, `face_deadzone`) + 머리 위아래(`BodyRig.set_head_aim()`) 조준, 침·파선도 같은 각도. 머리 각도는 부호 곱하지 말고 그대로 넘길 것. 경고 중에도 조준 따라감(피하게 하려면 `_begin_warning()`에서 `_aim` 고정)
    - `Spit`이 이동을 직접 함(`Projectile`은 x만 이동). `aim()`은 `setup()` **다음에**
    - 침 나가는 순간 파선을 `hide()`+`queue_free()`(한 프레임 겹침 방지)
    - ⚠️ 빠른 투사체는 판정을 진행 방향으로 늘릴 것 — `Spit.setup()`이 `프레임 이동거리 x sweep_margin`으로 가로 확장. 판정 도형은 새로 만들어 끼움(`sub_resource` 공유라 직접 고치면 다른 침까지 바뀜)
    - 관통은 `_on_area_entered`에서 `super` 안 부르고 `_try_hit(area)`만
    - ⚠️ `Spit`은 "iljin_crew" 그룹 몸을 통과(안 하면 여자친구가 침을 막음), 벽·바닥엔 막힘
    - `mouth_offset`은 실제 입술 끝(얼굴 세 장 모두 같은 자리). `_mouth_offset()`이 리그 `Head` 위치를 축으로 회전(에디터에서 머리 옮기면 따라옴). 입 재는 법: 얼굴 오른쪽 윤곽 두 봉우리 중 아래가 입술(위는 코)
    - 침 그림 `물방울.png`(region_rect 사용, +x 방향). 얼굴은 모으는/뱉는 두 장을 액션 표정 슬롯으로(일진 스킬과 같은 주의), 뱉는 얼굴은 `spit_face_scale` 보정
  - **여자친구 = 좀비 걷기 + 발차기**(사용자 지정: 대시·방어·점프 없음): `walk_to_opponent`/`walk_speed`/`walk_stop_distance`. 걷기 동작은 `BodyRig.manual_speed_ratio`로 넣음(Fighter가 아니라서)
    - 발차기 `kick_enabled`, 리그 발차기 모션(`attack_kick_hit = 0` + `play_attack_swing(0)`) 재사용. 주인은 일진
    - ⚠️ `kick_windup` = 리그 `attack_duration` x 0.4
    - ⚠️ 넉백 맞으면 `knockback_stun` 동안 굳힘(안 하면 걷기가 `velocity.x`를 덮어 넉백이 사라짐 — 그네와 같은 함정)
  - 표정: 친구(피격 보정 없음 / 지침 `weary_head_scale` 보정), 여자친구(피격·지침 보정 없음). Fighter가 아니라 `IljinCrewMember.take_damage()`가 `play_hurt_face()`·`update_hp_ratio()`를 직접 호출
  - 여자친구 머리 `일진 여자친구 머리.png`(알파 있는 새 판; 옛 `-Photoroom` 판은 삭제됨). 긴 머리 캐릭터는 얼굴이 아니라 **머리 전체 크기**로 다른 캐릭터(평균 ~53x52)에 맞출 것. `일진 여자친구 정면.png`는 미사용. 어색하면 에디터에서 `Head` scale·position만

## 스킬 로고 (쿨타임 HUD)

`Skill.icon`을 `ui/SkillCooldownIcon.gd`가 슬롯에 깔고 쿨만큼 차오르게 그림. 비우면 캐릭터 색 사각형.

- 등록: 주정뱅이·촉법소년만(`sprite/<캐릭터>/스킬로고/`). 파일명 G/H = 스킬1/스킬2
- **로고는 투명 여백을 잘라 넣을 것** — `_fit_bar()`가 원본 크기 전체를 맞춰 넣어 작아지고 치우치며 물높이도 어긋남

## 스킬 범위 미리보기 (에디터 전용)

`characters/SkillRangePreview.gd`(@tool, 주정뱅이 씬) — 실제 `VomitBeam`/`ScreamCone` 씬을 `build_preview()`(도형만)로 띄움.

- 자식은 owner 없어 저장 안 됨, 게임 중엔 꺼짐. 효과 씬 값 변경은 `Refresh` 체크박스
- ⚠️ 홀더(`토하기N`)를 뷰포트에서 옮겨도 게임엔 반영 안 됨 -> **`Apply Holders To Skill`** 로 `VomitSkill.stack_offsets`/`stack_scales`에 옮긴 뒤 **씬 저장**
  - 그림만 밀려면 `stack_visual_offsets`(판정 그대로)
  - 미리보기(`_scale_of()`/`_whole_offset_of()`)와 게임(`VomitSkill.spawn_offset()`/`scale_for()`)은 같은 식 — **항상 같이 고칠 것**
- ⚠️ 에디터에선 @tool 아닌 스크립트 메서드 호출 불가(placeholder 에러) -> export 값을 직접 읽을 것
- `VomitBeam`/`ScreamCone`은 @tool -> 트윈·레이캐스트는 `setup()`에만 둘 것

## 훈련장 (값 조정용)

`maps/TrainingGround.tscn` — 물리값·게임 속도 슬라이더 개발용 방(패널은 `TrainingGround.gd`가 코드로 생성).

- `Fighter.gravity` 등은 **static var**(공유, 게임 종료까지 유지) — 영구 반영은 `DEFAULT_*`에. 이동속도는 배수로만 -> 확정되면 `stats/*.tres`
- `Engine.time_scale`은 **`_exit_tree`에서 1로 복구**(안 하면 메뉴까지 느려짐)
- 동작 테스트: `BodyRig.play_scratch()`/`play_lookback()`/`play_blink()`
- 충돌 영역 보기: `maps/CollisionDebugView.gd`

## 궁극기 컷인 연출

`ui/UltimateCutIn.tscn` — Stage·훈련장이 심고 Fighter는 `ultimate_cutin` 그룹으로 찾음(없으면 즉시 발동).

**기획 확정(임의로 바꾸지 말 것):**
- **전체 1.5초**(줌인 0.25 / 컷인 1.0 / 복귀 0.25). 장면이 `cutin_duration`을 들고 있으면 그 값 우선(잼민이 2.4초)
- **연출 중 시간 정지**(`get_tree().paused`, 컷인만 `process_mode = ALWAYS`) / **스킵 없음** / **확정타 아님**(연출 시작 시점 자리·방향으로 나감)
- `Fighter.use_ultimate()` 쿨 확인 -> 연출 -> `fire_ultimate_now()` 발동(쿨도 이때 시작). 장면은 `CharacterStats.ultimate_cutin_scene`, 비면 이름만 뜨는 임시 화면
- 컷인은 파츠를 코드로 흔들어 만든다 — `ui/cutin/CutInAnimation.gd`
- **괴성은 컷인에서 지르지 않는다** — 컷인은 예비동작, 발성은 복귀 후 인게임 궁(판정 순간을 살리려고)

- 컷인 있는 캐릭터: 주정뱅이·촉법소년·악플러·일진(`ui/cutin/<이름>CutIn.tscn`)
- ⚠️ 일진은 컷인만 있고 궁 효과 없음(`SkillUltimate` = 빈 `Skill.gd`) — 버그 아님
- **교훈: 컷인에 캐릭터를 움직여 넣을 땐 러프를 오려내지 말고 `characters/<캐릭터>/<캐릭터>Rig.tscn`을 쓸 것**
- **촉법소년**: 배경 한 장(`1번배경.png`) 고정 + 리그(`Runner`)가 3단계 연기(러프 플립북은 장마다 배경이 달라 폐기)
  - 배경은 흔들림 여유로 화면보다 크게. 어긋나면 `Runner` position·scale만 조정
  - 2단계만 `_set_shout_face()`가 머리 texture를 직접 교체. **3단계 전환 시 원래 머리 복원 후 `set_action_face(true)` 순서**(반대면 `_apply_base_head()`가 덮어씀)
  - `ShoutText`·`ShoutMark`·`Exclaim`은 **visible 켠 채 저장**(에디터 배치용, 게임은 `_reset()`이 숨김)
  - 3단계: `scale.x` 음수 + `BodyRig.manual_speed_ratio = 1.0`(Fighter 없는 리그용 걷기, Fighter 있으면 무시). scale.x 음수라 `run_lean_deg`는 양수
- 폰트 `fonts/Jua-Regular.ttf`(주아체, OFL)
- **일진**: 침 뱉는 얼굴은 `Friend/SpitGatherPose`/`SpitFacePose` 노드 배치대로 재생(각도는 노드로)
- `ui/cutin/CutInSpit.gd`: `_draw()` 침, 그림 오면 `spit_texture`에

## 게임 플로우 / 씬 전환

`GameState.gd`(오토로드)가 화면 사이 선택값을 들고 다닌다.

- 브금 반복은 `TitleScreen._ready()`의 `loop = true`. `exit_fade`는 클릭 소리 길이 기준(짧으면 소리 끊김)
- `Fade`(검정 ColorRect)는 **씬의 맨 마지막 자식**이어야 다 덮는다

**첫 화면:** `ui/TitleScreen.tscn` -> `ui/MainMenu.tscn`(왼쪽 메뉴 + 오른쪽 일러스트).

- **타이틀 뒤에서 실제 게임이 돈다(구경 모드, 2026-09-28 사용자 요청)** — 켤 때마다 `GameState.MAPS`에서 맵 하나, `CHARACTERS`에서 캐릭터 둘을 랜덤으로 뽑아 **둘 다 `AIController`** 로 싸운다. **카메라는 싸움을 따라가지 않고 맵 왼쪽 벽 끝에서 전체 거리의 `pan_end`(3/4)까지 `pan_time`(10초) 동안 흐르고**(`CameraRig.start_pan`/`pan_finished`, 출발만 살짝 느림 — 사용자 결정: 끝까지 가면 맵만 오래 보여서 3/4), 거기 닿으면 어두워졌다가(`swap_fade`) 새 조합으로 바꿔 다시 왼쪽부터 흐른다(2026-09-28 사용자 결정 — 쓰러져도 계속 흐른다. 체력 0이 돼도 캐릭터는 계속 움직이고 싸운다). `round_max_time`(40초)은 흐르기가 안 끝날 때의 안전 한도. 게임 소리(열차 등)는 그대로, 제목 글자는 임시(사용자가 로고를 줄 예정)
  - `Stage`는 `GameState.game_mode == "attract"`면 `_start_attract()`만 한다: 두 캐릭터 AI, `CombatHUD` 숨김, 카운트다운·일시정지 버튼·연타 대결 매니저·궁극기 컷인 없음(화면을 멈추거나 UI를 띄워서), 맵의 `"crown_cutin"`(왕관 획득 컷인, 게임을 멈춤)도 지운다. `_process`는 낙사 구조만 하고 승패·결과·재시작 안 함, `_unhandled_input` 무시(ESC 일시정지 방지). 판 교체는 TitleScreen이 카메라 흐르기 끝을 보고 한다
  - 게임 장면은 `ArenaViewport`(SubViewport, **창 해상도 그대로** — 선명하게)에 띄우고 `Arena`(TextureRect)로 깐다 — 맵 카메라가 제목 글자까지 움직이지 않게. ⚠️ `CameraRig`는 시야를 **뷰포트 픽셀 크기**로 잡아서, 창 크기로 그리면 그만큼 넓게(작게) 찍힌다(SubViewportContainer 늘이기·`size_2d_override` 둘 다 안 먹음) -> **`CameraRig.view_scale`**(static, 창 높이/720)로 기준 배율을 곱해 구도를 맞추고, **`CameraRig.zoom_boost`**(static, 타이틀 `arena_zoom` 1.5)로 더 당겨 찍는다 — **지금 1.5배**(1.5 -> 1 -> 다시 1.5, 2026-09-28 사용자 결정: 1배에선 좁은 맵이 흐를 거리가 없어 제자리에 멈춰 있었는데, **넘어가는 기준은 항상 카메라가 왼쪽에서 오른쪽으로 흐른 것**이어야 한다). 그래서 제자리 대기(`pan_min_range`/`hold_time`)는 `pan_min_range` 0으로 꺼 두었다. 맵이 1.5배 화면보다도 좁으면 벽 한계선 때문에 흐를 거리가 0이라 멈춘 채 `pan_time`이 지나고 넘어간다 — 그럴 땐 `arena_zoom`을 더 올릴 것. 둘 다 평소 1 — **TitleScreen `_exit_tree()`가 1로 되돌린다**(안 되돌리면 실제 대전 카메라까지 당겨짐)
  - **흐를 때 카메라 높이는 바닥선이 화면 맨 아래 근처**(`CameraRig._pan_center_y()` — 맵 `Ground` 윗면 + `_pan_bottom_px` 36, 2026-09-28 사용자 요청 "땅이 너무 많이 보인다, 위쪽이 다 보여야"). `Ground`가 없으면 싸울 때의 가장 아래 높이
  - **새 판의 두 AI는 카메라가 처음 보는 화면 안의 밟을 수 있는 곳에 랜덤으로 선다**(`TitleScreen._place_fighters_in_view()`, 2026-09-28 사용자 요청): 맵 StaticBody2D 직사각형 윗면 중 벽·기둥(폭 60 미만·세로가 가로 2배 넘음) 빼고, 발~머리(100px)가 화면에 들어오는 곳에서 고르고 둘은 `min_spawn_gap`(140) 넘게 떨어뜨린다
  - **타이틀 AI만 약하게**(`TitleScreen.ai_reaction_time` 0.25 / `ai_guard_chance` 0.25 / `ai_dodge_chance` 0.35 / `ai_skill_chance` 0.8, 헛손질 유도 끔 — 인스펙터에서 조절). 판을 띄운 직후 `_soften_ai()`가 그 판의 `AIController`에 넣는다. 실제 대전 AI는 그대로
  - **타이틀 AI는 보여주기 위주**(`AIController.showcase`, 2026-09-28 사용자 요청): `_showcase_movement()`가 잠깐(`showcase_kite_time`) `showcase_keep_distance`(220)를 벌린 채 `showcase_hop_interval`마다 이단 점프, `showcase_dash_interval`마다 대시(벽·화면 끝에 몰리면 상대를 뛰어넘음)하다가 다가간다(최대 `showcase_engage_time`). 다가가는 동안 조건 맞는 스킬을 쓰거나, 평타 거리까지 붙으면 **평타 3타 콤보를 한 번 치고**(사용자 결정 — 콤보가 끝나거나 헛치면) 다시 빠진다. **화면(카메라에 보이는 곳) 가장자리 `showcase_screen_margin`(70px) 밖으로는 웬만하면 안 나간다**(`_view_rect()`, 넘어가면 안쪽으로 걷고 그쪽으론 대시 안 함). 발판 길찾기는 다가갈 때만. 스킬 쓸 확률 `ai_skill_chance`는 0.8. **스킬 위주(2026-09-29 사용자 요청):** 타이틀 동안만 스킬 쿨 배율 `GameState.cooldown_multiplier`를 `ai_cooldown_scale`(0.35)로 줄이고(떠날 때 `_restore_cooldown()`), 준비된 스킬을 조건이 안 맞아 `showcase_skill_patience`(1.2초) 못 쓰면 상대가 `showcase_skill_range`(450) 안일 때 그냥 쓴다. 평타 콤보는 쓸 스킬이 하나도 없을 때만
  - **타이틀에선 데미지 숫자·N HIT·BLOCK 팝업이 안 뜬다**(`Hitbox._spawn_damage_number`/`_spawn_block_popup`이 `game_mode == "attract"`면 리턴)
  - TitleScreen은 `process_mode = ALWAYS`(뒤 게임에서 멈추는 연출이 끼어도 타이틀은 돈다), 새 판 시작 때 `paused = false`. 메뉴로 넘어갈 때 `game_mode`를 "pvp"로 되돌린다. `_exit_tree()`에서 브금을 멈춘다(재생 중 종료하면 "resources still in use"·ObjectDB 누수 경고)
  - **타이틀 로고 `ui/TitleLogo.tscn`+`.gd`+`.gdshader`**(2026-09-28 사용자 요청 — 델타룬 타이틀처럼): 사용자 그림 `sprite/타이틀/타이틀.png`는 검은 손글씨 테두리만 있고 글자 안이 투명이라, `tools/make_title_logo.py`가 같은 캔버스(글자 영역 + 여백 70) 세 장을 만든다 — `타이틀_선.png`(원본 테두리) / `타이틀_채움.png`(글자 안쪽 — 투명 덩어리마다 가로 광선이 테두리를 홀수 번 건너면 글자 몸통, 짝수면 'ㅇ'·'ㅂ'·'ㅁ' 구멍이라 안 칠함. 선끼리 붙은 곳은 판정이 틀려서 — '이'의 ㅣ가 빠지고 ㅇ 구멍이 칠해졌었다 — 스크립트의 `FORCE_FILL`/`FORCE_EMPTY`에 원본 그림 좌표로 찍어 고친다) / `타이틀_빛.png`(흐리게 번진 둘레 빛). **로고 그림을 바꾸면 스크립트를 다시 돌릴 것.** 겹 순서 Glow -> Fill -> Line, **검은 테두리는 그대로**(사용자 결정). 연출은 계속 반복(사용자 결정): 하양(`white_time`) -> 빛 세짐 + 사선 빛줄기 훑기(`shine_time`) -> 글자 안에 **왼쪽 -> 오른쪽으로 흐르는 무지개**가 차오름(`rainbow_fade_time`/`rainbow_time`, `flow_speed`) -> 다시 하양. 둘레 빛도 무지개일 땐 같은 색. 예전 `TitleLabel` 글자는 뺐다(부제·안내 글자는 그대로)
  - 실행 순서: `project.godot` 시작 씬 `ui/Disclaimer.tscn` -> TitleScreen -> MainMenu

- 확인 창 `ui/ConfirmPopup.tscn`: 동작은 `_ask(문구, Callable)`로 넘김
  - ⚠️ 오버레이가 왼쪽 위 구석에 뜨면 인스턴스에 `anchors_preset = 0`이 덮어써진 것(에디터 드래그로 조용히 생김) -> `anchors_preset = 15` + anchor 1.0 + grow 2
  - 취소 시 직전 포커스 복귀, ESC 후 `set_input_as_handled()`(안 하면 뒤 메뉴 ESC까지 발동)
- **주의:** `.tscn`은 모든 노드 뒤에 `[connection]`이 와야 함(파일 끝에 노드 덧붙이면 깨짐)
- 배경 위 `Scrim` + `LeftFade` 필수(버튼 글씨 묻힘)
- **메인 메뉴에서 ESC = "게임을 나가시겠습니까?" -> 게임 종료**(`_quit_game()`, 2026-09-28 사용자 요청 — 예전엔 타이틀로 돌아갔다). 아래 안내 글자도 "ESC로 게임 나가기"
- **메뉴 사선 5항목(사용자 결정): 스토리 모드 / 대전 모드 / 훈련장 / 조작 방법 / 설정**
  - `<이름>Item`(Button, 판정 고정) > `Slide`(보이는 것만 이동) — **판정까지 움직이면 호버가 떨림**. 호버 = `grab_focus()`, 연출은 포커스만 봄
  - 도형 `메뉴사선_임시.png`는 흰색 + `modulate`. 교체 규격: 1장 재사용 / 투명 배경 / 글자 굽지 말 것
  - TODO: 메뉴 글꼴 미정(기본 폰트) — 정하면 `Text` 5개에 `theme_override_fonts/font`
- `Illust*`와 `Background*`를 트리 순서 **index로 짝지어** 교대(나타날 때 `restart()`). **일러스트 추가 시 배경도 같이 추가**(짝 없으면 빈 화면)
- **주의: 씬 첫 프레임 delta가 크게 튐** — 시간 누적 연출엔 `minf(delta, 0.05)`
- **해상도**(설정 화면, `GameState.RESOLUTIONS` 1280x720/1920x1080/2560x1440, 게임 기준 화면은 1280x720 + `canvas_items` 늘이기 — 배치 숫자는 전부 1280x720 기준): **기본값 1920x1080**(`resolution_index` 1 + `project.godot` `window_width/height_override`, 2026-09-28 — 저장 파일이 없는 첫 실행도 `_load_settings()`가 적용). 이미 저장한 사람은 그 값 유지. `_apply_window_size()`가 **모니터 전체 크기**와 비교해 안 들어가면 한 칸씩 내린다. 작업표시줄 영역을 넘는 크기(모니터와 같은 크기)는 **테두리 없는 창**으로 꽉 채운다(2026-09-28 — 예전엔 작업표시줄 뺀 영역과 비교해 1080 모니터에서 1920x1080을 못 골랐다). ⚠️ 에디터에서 "Embed Game on Play"로 실행하면 창 크기가 안 바뀐다 — 내보낸 빌드나 embed 끄고 확인

### 설정 > 조작 탭 = 키보드 그림(`ui/KeyboardMap.gd`, 2026-09-29)
- **키보드를 통째로 그려 놓고 키를 끌어다 다른 키에 놓아서 배정한다.** 예전의 "조작 이름 + [키] 16줄 / 칸을 누르고 새 키 입력" 방식은 없앴다(`Settings.gd`의 `_fill_key_rows`·`_listening_action`·`_unhandled_key_input` 삭제)
- 색이 곧 주인이다 — 아무도 안 쓰는 키 **회색**, 1P **파랑**, 2P **빨강**. 키 위에 조작 이름이 같이 적힌다(긴 이름은 `_fit_size()`가 글자를 줄여 키 폭에 맞춘다)
- **텐키리스 배열**(숫자패드 없음). 자리는 `LAYOUT`(한 줄 15u) + `ARROWS`(방향키) + `EXTRAS`(PrtSc/ScrLk/Pause, Ins/Home/PgUp, Del/End/PgDn — 2026-09-29 추가). 키마다 노드를 만들지 않고 Control 한 장에 `_draw()`로 그린다 — 60개 노드를 놓으면 끌어놓는 동안 "지금 어느 키 위인지"를 판단하기가 오히려 어렵다
- **놓는 자리에 다른 조작이 있으면 서로 자리를 바꾼다**(덮어쓰지 않는다) — 덮어쓰면 그 조작이 키를 잃고, 뭘 잃었는지도 모른다
- 키보드 밖에서 손을 떼는 경우가 있어서 `_gui_input`(칸 안)과 `_input`(칸 밖) 둘 다에서 놓기를 받는다. 안 그러면 딱지가 마우스에 붙어 남는다
  - 그래도 놓기 신호가 아예 안 오는 경우(창 밖에서 떼기, 다른 창이 입력을 가져감)가 있어서 **끄는 동안만 도는 `_process` 감시**가 마지막 보루다 — 버튼이 눌린 걸 한 번 본 뒤(`_drag_held`) 떨어지면 마지막으로 알던 자리에 그대로 넣는다. `_drag_held` 빗장이 없으면 누른 프레임에 아직 눌림 상태가 안 올라와 있어서 **집자마자 제자리에 놓아버린다**
  - ⚠️ 이 감시 때문에 `push_input`으로 끌어놓기를 흉내 내는 테스트는 실제 마우스 버튼이 안 눌려 있어 영향을 받는다(빗장 덕에 지금은 안 터진다). 샌드박스에서는 **진짜 마우스 클릭을 게임 창에 넣을 수 없어서**(user32 SendInput이 창까지 안 닿는다) 최종 확인은 사용자가 직접 해야 한다
  - ⚠️ **`_input`에서 `get_local_mouse_position()`을 쓰면 안 된다**(2026-09-29 버그). 창은 1920x1080인데 기준 화면은 1280x720이라 1.5배 어긋나서, 놓을 때마다 오른쪽 아래로 밀린 엉뚱한 키에 놓이거나 키 바깥이라 아무 일도 안 일어났다. **이벤트가 들고 있는 자리**(`_local_of()` = `get_global_transform().affine_inverse() * event.position`)를 쓴다 — 화면 배율이 이미 반영된 값이다
  - 키 사이 틈(5px)에 놓아도 **반 칸 거리 안이면 가장 가까운 키에 붙인다**(`_key_at`)
  - **놓는 자리 1순위는 커서가 들어가 있는 키다**(2026-09-29 사용자 요청). 커서가 키 사이 틈이나 키보드 밖일 때만 딱지가 가장 많이 덮은 키로 정한다
  - **끄는 동안 커서 자리는 `_process`에서 `get_local_mouse_position()`으로 매 프레임 직접 읽는다.** 이벤트만 믿었더니 놓기 신호가 늦게 와서 "손을 떼도 그 키 안에서는 확정이 안 되고, 커서가 그 키를 벗어나야 비로소 바뀌는" 증상이 났다
  - 딱지 기준 판정(참고)은 (`_drop_target()` = 딱지와 겹치는 면적이 가장 큰 키, 2026-09-29). 예전엔 딱지가 키보다 2배 넓고 커서 한 점으로 판정해서 "보이는 자리"와 "바뀌는 자리"가 어긋났다 — 딱지를 **키 한 칸 크기**로 줄이고, 집은 지점(`_drag_grab`)을 그대로 유지해 손에 붙어 오게 했다
  - 창 1280x720 / 1920x1080 둘 다에서 끌어놓기·자리바꿈·틈에 놓기·허공에 놓기(취소)를 실측 확인했다. ⚠️ 테스트를 짤 때 **설정창이 내려오는 연출(0.35초)이 끝나기 전에** 이벤트를 넣으면 카드가 움직이는 중이라 한 줄 밀린 키에 놓인다 — 코드 문제가 아니다
- **방향키 커서는 조작 탭에서 리셋 단추 하나만 들른다**(`_rows_of`) — 방향키 자체가 바꿀 수 있는 키라서 커서와 배정이 겹친다. 키보드는 마우스 전용
- 저장은 `GameState.rebind_action(action, 키코드, 좌우위치)` / `reset_keybindings()` -> `user://settings.cfg`
- **좌우가 따로 있는 키(Shift·Ctrl·Alt·Win)는 `location`까지 같이 저장한다**(2026-09-29). 키코드가 둘이 같아서 그것만으로는 구분이 안 돼, 오른쪽 Shift에 올려놔도 왼쪽 Shift로 눌리고 양쪽이 같이 칠해졌다. `InputEventKey.location`(`KEY_LOCATION_LEFT`/`RIGHT`)을 넣으면 그 자리에서만 먹는다 — 4.7.2에서 실측 확인
  - 배정 목록(`_bindings`)의 열쇠도 키코드가 아니라 **`"키코드:위치"`**(`_bind_id()`)다
  - 저장 파일 호환: 예전에는 숫자 하나였고 지금은 `[키코드, 위치]` — `_load_settings()`가 둘 다 읽는다
- ⚠️ **`refresh()`는 마지막에 반드시 `queue_redraw()`를 부른다.** 2026-09-29에 이 한 줄이 편집 실수로 `_key_id()` 안으로 밀려 들어가 죽은 코드가 된 적이 있다 — 배정은 바뀌는데 화면 색이 그대로라, 커서가 그 키를 벗어나 hover가 바뀔 때에야 비로소 색이 바뀌는 것처럼 보였다(사용자 신고). 픽셀로 확인하는 회귀 테스트: 1P 키를 2P 키 위에 놓고 **손 뗀 다음 프레임**에 두 칸 색이 서로 바뀌어 있어야 한다
- 조작 이름은 `KeyboardMap.ACTION_LABELS` 한 곳에서 고친다. 아래 키는 방어와 맵 전용 스킬을 겸해서 `"방어 / 맵 전용"`이다

### 메인 메뉴 일러스트(파츠 분리)

- **주정꾼** `ui/MenuIllust.tscn`: 캔버스 1230x1428(위로 150px 확장) — 그림 교체 시 `get_image_size()` 기본값과 Sprite position도 맞출 것
- **잼민이** `ui/JaemminIllust.tscn`
  - 총 든 팔의 축은 총구 쪽이 아니라 **팔 잘린 단면**(아니면 휘두르기가 됨)
  - 제자리 각도는 씬 rotation 기준(에디터에서 조정)
  - 밑그림은 `_0003`(통짜라 머리 두 개로 보임)이 아니라 `말썽꾸러기미남_몸통.png`
- **캣맘** `ui/CatMomIllust.tscn`: 내뱉기 전 통짜(`PreSpit`) <-> 파츠(`Post`) 교체. **`Post`를 미리 켜두지 말 것**(손이 삐져나옴)
  - 파츠는 `Body` 자식(어깨 따라 팔), `Heart`만 `Rig` 밖
  - **턱을 고치면 `턱채운캣맘.png`를 고치고 파생 3개(`캣맘_머리_턱채움`/`캣맘_몸통`/`캣맘_머리_눈감음`) 전부 재생성**
  - 눈감은 판은 눈뜬 판과 **픽셀 크기 동일**해야. 금지: 크기 다른 그림 합성(윤곽 이중 -> 알파 클리핑) / 전체 그림에서 턱까지 오려내기(분홍 얼룩)
- **지하철 아저씨** `ui/SubwayIllust.tscn`: `danso_deg` 2도 초과 금지(휘두르기가 됨). 뻗은 손은 **1.0배 이상으로만**(`hand_push`, 아래면 메운 얼룩 노출)
  - (보류) 집중선: `FxSubway` 노드만 뺌(`ui/FocusLines.gd`·`MainMenu._pair_effect()` 남음, 이름으로 짝지음). 되살릴 때 `jitter_flip` 끄고 `jitter_hz` 3~4·회전 0, 투명도는 `self_modulate`(크로스페이드가 `modulate` 씀), `Scrim` 앞
- **악플러** `ui/AkpeulleoIllust.tscn`: 샷건은 자세 그림 2장 교체. **교훈: 큰 동작은 파츠 회전보다 자세 그림 한 장**(팔 회전은 어깨 단면이 떠서 실패)

**파츠 공통 규칙**
- 파츠는 **원본 캔버스 크기 그대로** 내보낼 것(PNG-24, **Trim Layers 끔**) -> `centered = false` + `position = -축좌표`, 감싼 Node2D가 축
- 파일 번호가 작을수록 위 레이어 -> 씬엔 번호 역순으로 쌓기
- 뒤 몸통은 파츠 자리를 지운 그림: ① 원래 배경 자리는 flood fill로 비우고 ② 몸에 둘러싸인 곳만 BFS로 메움. 메운 안쪽은 얼룩이라 **회전을 크게 주면 드러남**
- 코드로 만든 그림은 에디터를 한 번 열어야 임포트됨
- 일러스트는 Control이 아니라 **Sprite2D**(Control 앵커가 position을 되돌려 코드와 싸움)
- 위치·크기는 씬 노드에 저장(에디터 = 게임). `auto_place_illustration`은 크기가 전혀 다른 그림 넣을 때만 켰다 끌 것
- `ui/breath.gdshader`: 한 장짜리 그림의 타원만 부풀림(미사용, 파츠 없는 그림용)
- **주의: 전체 화면 배경 Control이 클릭을 삼킨다**(기본 STOP) -> 배경 레이어에만 `mouse_filter = 2`

### 방 설정

- `ui/RoomSettings.tscn`: 위 빠른 프리셋 `PresetA`("표준" 2선승·2분) / `PresetB`("장기전" 3선승·무제한) + `PresetMore`("프리셋" = 저장/불러오기 전용). 아래 `Card` 2열 — 왼쪽 `RoundRow`/`TimeRow`/`CooldownRow`(`[◀ 값 ▶]` 스테퍼), 오른쪽 `ClashRow`/`GuardRow`/`DashRow`(ON/OFF 토글), 그 아래 카드 폭 전체 `OpponentRow`("상대 (P2)" 사람/컴퓨터 — 2026-09-27, 넣느라 줄 높이 98 -> 84) + 요약 한 줄
  - `_on_next_pressed()` -> `GameState.rounds_to_win`/`time_limit_seconds`/`cooldown_multiplier`/`clash_minigame_enabled`/`guard_enabled`/`dash_enabled`/`vs_ai`
  - **컴퓨터 대전(`GameState.vs_ai`)**: 켜면 `Stage`가 pvp에서도 P2에 **규칙 AI `AIController`**를 붙인다(API 비용 없는 쪽 — 사용자 결정, 난이도 선택 없음). 스토리는 그대로 `ClaudeAIController`. P2 키 표시 숨김(`FighterPanel`)·캐릭터 선택 안내 "P2(컴퓨터)"도 이 값을 본다. 방 설정은 지난번 고른 값을 기억(다른 항목은 매번 기본값)
  - 라운드 ◀▶는 `wrapi(값, 1, MAX_ROUNDS+1)`로 1<->40 순환(TimeRow와 같은 방식). 직접 입력값은 클램프만(순환시키면 직관과 어긋남)
  - `RoundRow`/`CooldownRow`의 `Value`는 `LineEdit` — `text_submitted`/`focus_exited`에서 커밋, `is_valid_int()` 아니면 이전 값. 쿨타임 칸은 "숫자%" 표시, `trim_suffix("%")` 후 파싱
  - 프리셋: `PopupMenu` id 0 "현재 설정 저장..." -> `_show_save_preset_dialog()`(코드로 만든 오버레이) -> `GameState.save_room_preset(이름, data)` -> `user://settings.cfg` `[room_presets]`(7값: `rounds`/`time_index`/`cooldown_percent`/`clash_enabled`/`guard_enabled`/`dash_enabled`/`vs_ai`). 저장분은 `SAVED_PRESET_ID_BASE`(1)부터 나열, `_apply_saved_preset()`. 같은 이름 덮어씀. **삭제 UI 없음(TODO)**
  - 버튼 연결은 `.tscn` `[connection]`이 아니라 `_ready()` 코드로. 배경은 메인 메뉴와 같은 그림+흐림 셰이더. 뒤로가기는 왼쪽 아래 `flat` 글자("뒤로가기 (ESC)", 캐릭터·맵 선택과 통일)
- **쿨타임 배율은 `Skill.effective_cooldown()` 한 곳에서 곱한다.** 예외로 챙긴 곳: `ComboMeleeAttack._effective_miss_cooldown()`, `RageBuffSkill._execute()` 즉시 클램프(`fighter.basic_attack.effective_cooldown()`), `LivingShadowSkill.use()` — **`cooldown`을 직접 읽는 경로를 새로 만들면 배율이 안 먹는다**
- 연타 미니게임 off: `SkillClashManager.request()` 맨 앞에서 `on_win.call()` 즉시 발동. 가드/대시 off: `Fighter.can_guard()`/`can_dash()` 맨 앞 — Player·AI 컨트롤러 둘 다 이걸 거치므로 한 곳으로 충분
- **⚠️ 주아체(Jua)엔 기호 글리프가 거의 없다**(`◀ ▶ ● ○ · × ↑ ↓` 없음 -> 두부, `~ / ( ) - | , .`는 있음). 방 설정 화살표 버튼은 폰트 미지정(기본 폰트 대체). 주아체 라벨에 기호 넣기 전 글리프 확인

**로컬 대전(PvP) 흐름:** `ui/TitleScreen.tscn` -> `ui/MainMenu.tscn`("대전 모드") -> `ui/RoomSettings.tscn` -> `ui/CharacterSelect.tscn`(P1->P2, `GameState.p1_character_path`/`p2_character_path`) -> `ui/MapSelect.tscn`(고르면 바로 전환) -> 맵(`Stage.gd` 상속).

### 스토리 모드

- 옛 스토리(`EpisodeSelect`/`ReformCutscene`/`StoryClear`/`StoryIntro`, `GameState.STORY_OPPONENTS`/`STORY_MAPS`/`story_index` 등)는 전부 삭제(필요하면 2026-09-12 이전 커밋)
- `MainMenu`("스토리 모드" -> 확인) -> `ui/story/StoryScene1~11.tscn`. **모든 장면이 `ui/story/StoryFadeScene.gd`**: 페이드인(`fade_in_time`) -> 머묾(`hold_time`) -> 페이드아웃(`fade_out_time`) -> `next_scene`(비면 멈춤)
- ESC = 일시정지(`ui/PauseMenu.tscn`, 사용자 결정 — 바로 나가지 않음). 멈추는 동안 페이드·타자 정지, "다시하기"는 장면 처음부터
- 씬 규칙:
  - `Fade`(검은 ColorRect)는 **맨 마지막 자식**, 씬 파일에선 **알파 0**(에디터에서 배치 가능하게). 시작 알파는 `_ready`가 정함
  - 나중에 나타날 노드(사건 파일·도장·인물)는 씬에서 보이게 두고 루트 `hide_on_start`에 등록 -> 대화 명령으로 띄움. `reveal` 노드(인물·대화창)는 전환 후 투명->불투명 + `reveal_rise`만큼 올라옴(인물 등장엔 `reveal` 쓸 것 — 사용자 호평). 대화창은 다 나타나기 전(`modulate.a < 0.99`) 입력 무시
  - 장면 루트 Control·대화창 컨트롤은 `mouse_filter = 2`(클릭이 `_unhandled_input`까지 와야 함)
- 전환: `out_transition` BLACK(검게) / CROSSFADE — 나가는 장면이 `get_viewport().get_texture().get_image()`로 찍어 `StoryFadeScene` static 변수에 저장(autoload 회피), 들어오는 장면이 맨 위 TextureRect로 덮고 `crossfade_time` 동안 투명화. 3초 지난 사진·ESC 나갈 때 폐기. 전환 중엔 앞 장면이 정지 사진
  - 사용자 결정: 메뉴->1 검은 화면 / 1->2 크로스페이드 0.7초 / 2->3 검은 화면(간판->대화 사이). 검게 전환은 "다른 장면"으로 읽히므로 이어지는 흐름엔 크로스페이드
- **스토리->대전:** `StoryFadeScene.battle_p1`/`battle_p2`/`battle_rounds`/`battle_time_limit`(0=무제한)를 채우면 넘어가기 전 `_setup_battle()`이 `GameState`에 캐릭터·맵·라운드 초기화. `game_mode == "story"`면 P2는 AI(`FighterPanel`은 P2 키 숨김). **스토리에서 GameState에 뭘 담는 코드는 `_setup_battle()`에 넣을 것**(S 건너뛰기가 `_open_next()`를 우회해서 기본 캐릭터로 붙던 버그)
  - 이기면: 장면의 `battle_win_scene` -> `GameState.story_next_scene` -> `Stage._show_final_result()`가 스토리+P1 최종 승리+값 있음이면 `MatchResult.hide_buttons()` 후 `story_win_delay` 뒤 전환(`await` 뒤 `is_inside_tree()` 확인). 지면 재시도/메뉴(재시도해도 값 유지). 메인 메뉴에서 모드 시작 시 비움
- **(임시, 스토리 완성 후 삭제)** `S` 건너뛰기: 장면은 `StoryFadeScene.debug_skip_key`, 전투는 `Stage.debug_story_skip_key`(`p1_round_wins`를 채워 승리 처리, 스토리+`story_next_scene` 있을 때만)
  - ⚠️ `set_input_as_handled()`는 `change_scene_to_file()` **전에**(후엔 `get_viewport()` null) — `_can_debug_skip_story_battle`/`_debug_skip_story_battle`로 분리
  - ⚠️ `S`는 P1 방어키이기도 해서 전투 중 방어하면 승리로 넘어간다 — 사용자가 그래도 `S` 유지 결정. 방어 테스트 땐 맵 루트(`Playground`) `debug_story_skip_key`를 잠깐 끌 것
- 게임에 보이는 글자는 "비비탄"으로 통일(사용자 지정)
- 장면 목록(사용자 러프·지정 기반):
  1. 경찰서 앞 — `PoliceStation` 밑 `Sky`->`Clouds`(8)->`Building`->`Flags`(3). 구름 `ui/story/DriftingClouds.gd`(화면 밖 순환, 잘린 구름은 메타 `cut_left`/`cut_right` + `ui/story/CloudEdge.gdshader`로 움직인 만큼만 흐림 — 그림에 굽지 말 것), 깃발 `ui/story/FlagWave.gdshader`. 에셋은 `sprite/storymode/경찰서/`(원본 세트 보존). **구름 노드 순서 = 포토샵 역순**(바꾸면 얼룩). color-to-alpha는 Cloud7(레이어-8)에만
  2. 민폐퇴치부 간판 — `Office`(`ui/story/StoryZoomView.gd` 살짝 확대) 밑 `Plate`->`People`(`ui/story/StoryWalker.gd` 6명, 흔들림 없이 조금만 미끄러짐 — 사용자 결정)->`SignBand`(여비서1이 간판 뒤로). `Still`(원본) 숨김. 배경 = 통짜 그림 + 움직이는 자리만 사람없는 판 보정, 사람 = 레이어 + 번짐(그림자는 안 붙임 — 밝은 찢어짐). 잘린 사람은 확대 여유(~19px) 안에서만 이동. 검증은 **다 걸은 뒤 상태**를 확대해서. 남은 흠: 몇 명 발자리·여비서1 머리 옆 옅은 얼룩
  3. 경찰서 안 대화 — 주인공 대사 -> `@show CaseFile`(`Dim` + `Paper` = `잼민이사건파일_끝장판.png`, 화면에 다 들어오게) -> `@close` -> `@waitkey` -> `@stamp`(`CaseFile/Paper/Stamp` = `수사착수도장.png`, 위치·각도·배율은 사용자가 에디터에서 정함 — 씬 값이 최종 모습) -> 4
     - ⚠️ 원본은 `잼민이사건파일-끝장버전.psd`(Godot 못 읽음) — 고치면 **PNG로도 내보낼 것**. 캔버스 1748x900이 바뀌면 `Stamp` 위치 재조정
  4. 장소 카드 "사건현장/놀이터" — 재사용 부품 `ui/story/LocationCard.tscn`(`subtitle`/`title`/`chars_per_second`/`hold_time`). `StoryFadeScene.dialogue`에 지정하면 끝나야 넘어감(`is_finished()`만 있으면 됨). 장소 이동 표시 규칙(사용자 합의): 현장 도착=검은 화면+이름 카드, 현장 안 소이동=모서리 띠(미구현)
  5. 놀이터 대화 -> 대전 — 배경 `잼민이일러스트배경.png`(`stretch_mode = 6`, 흐림 없음 — 게임 맵 그림 아님). **말하는 사람만 가운데 한 명씩**(`@hide` -> `@enter`, 사용자 요청). `Hero`=`경찰초기일러 (2).png`, `Kid`=잼민이 스토리 일러(둘 다 `hide_on_start`). 잼민이 도망 `@exit Kid 0.4 420` -> 놀이터 대전(P1 주인공 vs 잼민이)
  6. 제압 후 공원 — `Bg(공원풀숲)`->`Kid`->`Head`->`GrassFront(풀숲_앞)`->`Fade`(Bg·GrassFront는 같은 1672x941 캔버스, 전체 앵커+KEEP_ASPECT_COVERED). 순서(사용자 지정): 잼민이 자전거 통과 -> `RidingBy.passed` -> 머리 퐁 -> 잎
     - `ui/story/RidingBy.gd`(Kid): `frames` 두 장 번갈아, `speed` 등속, 출발·도착은 화면 밖 자동 — 에디터에선 `position.y`·`scale`만 의미. 잔상 `trail_count`/`trail_alpha`/`trail_spacing`(0=`speed/60` 자동), 미리 만든 노드를 본체 앞 순서에 배치. 화면 위로 잘리는 건 의도(하반신만 지나감)
     - ⚠️ 씬 Sprite2D `texture`에 첫 장을 지정해 둘 것(`frames[0]`은 런타임에만 들어가 에디터에서 안 보임)
     - `ui/story/PopUpLayer.gd`(Head, Node2D, `풀숲머리2.png` Sprite2D): position만 바꿈, `hide_offset`/`delay`/`overshoot`, 시점은 **초가 아니라 `after = ../Kid` 신호 대기**(크기 바꾸면 통과 시간이 변해 순서가 뒤집힘). `popped` 신호 -> `ui/story/LeafBurst.gd`(`Leaves`, `trigger = ../Head`, `seed_value` 고정 난수, 초록 잎이라 하늘까지 솟게)
     - `풀숲_앞.png` 가림막은 머리 그림 아랫 윤곽 기준으로 `공원풀숲.png`에서 오려낸 것(`make_front_grass.py`) — 배경은 `공원풀숲.png` 사용
  7. 돌 던지기 — 검은 배경(나중에 그림 가능). `ui/story/RockThrow.gd`(`Cop`): `throw_delay` 뒤 준비->던진 자세 텍스처 교체(같은 캔버스), `Rock`은 평소 숨김(준비 그림에 돌이 있음). 던진 자세 옆에서 수평 직진(`rock_arc` 0, 사용자 지정), 잔상 `trail_count`/`trail_spacing`(돌 폭보다 좁게), `trail_additive`는 밝은 배경일 때만 의미
     - ⚠️ `rock_arc` 0이면 `TRANS_LINEAR` 한 번으로(두 구간 이징은 가운데서 끊겨 보임)
     - `ui/story/RimGlow.gdshader`(바깥 빛, `glow_width`/`glow_strength`/`body_light`) — ⚠️ `glow_width`가 그림 투명 여백(여기선 오른쪽 29px)보다 크면 잘림. `흩날릴나뭇잎.png`을 여기 얹는 건 아직(TODO)
  8. 돌 맞고 넘어짐 — `ui/story/RockHit.gd`(돌 자신): 씬의 돌 위치 = 명중점(뒷바퀴), `start_offset` 밖에서 날아옴, 명중 시 배경 텍스처 교체 + `shake_target`(`Shake`) 흔들기. 카메라 없음 -> 흔드는 노드의 배경은 화면보다 크게(여유 바꾸면 돌 위치도 재조정)
  9. 붙잡은 뒤 대화 — 5번 배경, 한 명씩 방식, 우는 잼민이
  10. 장소 카드 "사건 이후/경찰서"(`LocationCard` 재사용)
  11. 경찰서 훈방(현재 마지막, `next_scene` 비어 있음, `clears_story` 켬) — 3번과 같은 배경·자리 + `흐느끼는잼민이.png`, `@exit Room/Kid 0.5 420` -> `@show CaseFile` -> `@close` -> `@waitkey` -> `사건해결도장.png` `@stamp` -> `@pause 0.8`. **3번·11번은 도장만 다른 같은 구조 — 새 사건은 둘을 복사해 문구·도장만 교체**
- **경찰관(주인공)** `characters/police/Police.tscn` + `PoliceRig.tscn` + `stats/PoliceStats.tres`: 기본공격(경봉, `HandRHold` 자식)만, 스킬 3칸 빈 껍데기
  - 파츠 `sprite/storymode/경찰서/경찰머리·경찰몸통·경찰발·경봉.png`. 리그 값은 사용자가 에디터에서 맞춤 — **`PoliceRig.tscn`이 정본**. `경찰발.png`은 촉법소년 발과 캔버스 동일(기존 파츠 위에 덮어 그리면 배치 불필요)
  - 몸통은 체크무늬가 구워진 RGB로 와서 `경찰몸통_배경제거.png` 사용(`police_body_alpha.py`, 테두리 flood fill). **파츠는 알파 있는 PNG로 달라고 할 것**
  - 발바닥이 바닥선보다 9px 아래(살짝 파묻힘) — 의도 아니면 리그를 8px 올릴 것
  - 표시 이름 "주인공": `GameState.TRAINING_ONLY_CHARACTERS` 키 / `CHARACTER_COLORS` 키 / `PoliceStats.tres` `character_name` **세 곳 일치**
  - 훈련장 전용(사용자 결정 — 스킬 빈 껍데기): `CHARACTERS`와 별도 `TRAINING_ONLY_CHARACTERS`, 훈련장은 `training_characters()`. 스킬 완성 시 `CHARACTERS`로 옮기기만
  - ⚠️ 이름 역조회 코드는 어느 목록을 보는지 확인(`VersusIntro._find_character_name()`이 `CHARACTERS`만 봐서 "?"·회색으로 떴음 -> `training_characters()`)
- **대화창 `ui/story/DialogueBox.tscn`(+`.gd`)** — 형식 고정(사용자 지정): 아래 전체 폭 대사창(반투명 회색 + `TopLine`) + 그 위 왼쪽 이름창(더 짙게 + 노란 `Accent`, 6px 틈), 글꼴 나눔고딕(`fonts/NanumGothic-Regular.ttf`, OFL — 다른 UI는 주아체)
  - `speaker`/`lines`만 채움. 넘기기: 스페이스 / Z / X / 마우스 좌·우 클릭(엔터·휠·키 반복 무시). 키 목록은 **`DialogueBox.ADVANCE_KEYS` 한 곳**(`keycode`+`physical_keycode` 둘 다 봐서 한글 입력 상태에서도 동작). 다 넘기면 `finished`
  - `이름|대사`로 화자 변경, 화자 비면 이름창 숨김. `center_speakers`(기본 ["나레이션"])는 가운데 정렬 + 자동 괄호, 인물 대사는 왼쪽 정렬
  - 타자 효과 `chars_per_second`, 문장부호 뒤 `punct_pause`. 찍는 중 입력 = 전부 표시, 다 나온 뒤 = 다음. `VC_CHARS_AFTER_SHAPING`으로 줄바꿈 고정
  - `StoryFadeScene.dialogue`에 지정하면 대사 끝 + `hold_time` 후 넘어감
  - **명령 줄**(`@`로 시작, 입력 없이 순차 실행, 노드 경로는 장면 루트 기준, 연출 중엔 입력 무시): `@show 노드 [초]` / `@hide 노드 [초]` / `@enter 노드`(등장) / `@exit 노드 ...`(미끄러지며 퇴장, 예 `@exit Kid 0.4 420`) / `@close [초]`(뒤에 대사 오면 다시 나타남) / `@waitkey` / `@pause 초` / `@stamp 노드 [초]`(Node2D, 씬 값이 최종 모습, 부모가 흔들림). 장면을 안 바꾸고 화면을 바꿀 때 사용(장면 바꾸면 대화창 끊김)

### 대전 공통 (화면 흐름·라운드·HUD·이펙트)

- `ui/HowToPlay.tscn`은 키를 `InputMap`에서 읽음(읽기 전용, 변경은 설정 > 조작)
- 캐릭터·맵 목록은 `GameState.CHARACTERS`/`GameState.MAPS`에 한 줄 추가하면 선택 화면에 자동 반영
- 모든 화면 ESC(`ui_cancel`)로 한 단계 뒤로. 스토리 장면·대전 중엔 일시정지 화면(거기 "메인메뉴로")
- **라운드제:** `Stage._process()`가 KO/시간 초과(HP 높은 쪽 승, 동률 무승부) 감지 -> `_end_round(p1_won, is_draw)`. 승수는 `GameState.p1_round_wins`/`p2_round_wins`(오토로드라 유지). 미달이면 `MatchResult.show_round_result()` 후 `reload_current_scene()`, 도달이면 `show_result()`/`show_draw()`(스토리 승리는 위 `story_next_scene` 경로)
- `CombatHUD`: `TimerFrame` > `TimerBox` > `TimerLabel` + `RoundLabel`, `Stage`가 `update_round_info(p1_wins, p2_wins, time_left)`로 매 프레임 갱신(HUD는 표시만). 시간 제한 0이면 `TimerFrame` 숨김, 10초 이하 빨강
- `maps/Stage.gd`가 `_ready()`에서 `GameState` 캐릭터를 `PlayerSpawn1/2`에 생성. P1 `PlayerController`, P2는 story면 `ClaudeAIController`, pvp면 `PlayerController`(방 설정 "상대: 컴퓨터"면 `AIController`). 새 맵 필수 요소: 바닥·벽(or 링아웃 공간)·`PlayerSpawn1/2`·`Camera2D`(`maps/CameraRig.gd`)·`CombatHUD`
- 승패는 `died` 시그널이 아니라 `_process()`에서 양쪽 `current_hp`를 한 번에 판정(시그널 순서로 동시 KO 승자가 임의로 갈리던 버그) — 양쪽 0이면 `show_draw()`. 링아웃은 `Stage.ring_out_y` 아래(벽 없는 맵에서만 의미)
- 히트 이펙트: `Fighter._flash_hit()` + `Hitbox`가 `combat/HitSpark.tscn` 스폰
  - `_draw()` 세 겹(번쩍 + 넉백 방향 마름모 섬광 + 방향 쪽 불꽃, `direction_bias`). 세기 = 데미지 / `Hitbox.SPARK_POWER_DAMAGE`, 세기 1.5 이상이면 충격파 고리. 방어에 막히면 파랗게 작게
  - `Hitbox.hit_spark`로 히트박스별 끄기(막힘 파란 스파크는 유지). **지금 금쪽이 기본공격(`Chokbeopsonyeon.tscn` `BasicAttack/Hitbox`)만 꺼짐**
  - `start_progress`로 진행된 상태에서 시작(히트스톱 중 점만 보이는 것 방지). 투사체 착탄·총구 섬광·도발 표시가 `setup()` 없이 기본값으로 재사용
- **착지 먼지 `combat/LandDust.gd`**(장식): **모든 착지**(떨어진 높이 `land_dust_min_height` 20px 이상)에서 **발 양옆에 몽글몽글한 구름 뭉치가 하나씩** 생겨 바닥을 따라 바깥으로 미끄러지며 부풀었다 사라진다(2026-09-26 사용자 레퍼런스·결정). 흰색 + 옅은 테두리(점프 바람과 같은 톤). 크기 = 떨어진 높이 / `Fighter.land_dust_height`(기본 크기가 되는 높이, 음수면 `_land_dust_height()`가 이단 점프 최고 높이 약 216px로 계산) — 땅 점프(약 100px)면 약 70% 크기. 착지 경직 걸린 착지는 최소 기본 크기. 높이는 `속도² / (2 x 낙하 중력)`으로 환산. 맵에 붙임(캐릭터 자식 금지). 그림 없이 `_draw()`(동그라미 5개로 구름 모양, 테두리 먼저 깔고 흰 몸통)
- **점프 바람 줄기 `combat/JumpWind.gd`**(장식, 2026-09-26 사용자 요청 — 타 게임 레퍼런스): 지상·이단 점프 모두 `Fighter.jump()` -> `_spawn_jump_wind(air)`가 발밑(원점 +30)에 맵에 붙인다. 뛴 방향(`velocity`, 가로 이동 포함이라 대각선이면 비스듬)을 따라 흰 삐죽한 줄기 3가닥이 뻗었다가 **뛴 자리(꼬리)부터 따라 올라가며** 사라진다(사용자 결정: 흰색·발밑에서 진행 반대로 끌림). 흰색만으론 밝은 배경에 묻혀 옅은 어두운 테두리(`outline_color`/`outline_px`)를 먼저 깐다. 마디마다 사각형으로 나눠 그림(삐죽한 다각형 하나는 분할 실패 위험 — EyeBlink와 같은 이유)
  - ⚠️ 낙하 속도는 `move_and_slide()` **전에** 기억할 것(충돌 후 `velocity.y` = 0) — 스프링 `_prev_fall`과 같은 이유
- **⚠️ 히트스톱은 지금 꺼져 있다(사용자 요청)** — `Hitbox.hitstop_time` = 0이면 `_apply_hitstop()`이 즉시 리턴(데미지 비례분·`AttackData.hitstop_scale` 무시). 켜려면 0.022. KO 슬로모션(`Stage.knockout_*`)은 별개
  - 동작: `Engine.time_scale`을 `Hitbox.HITSTOP_SCALE`로 떨어뜨려 화면 전체 정지(경직 `_hitstun_time`과 별개). 시간 = `hitstop_time` + 데미지 x `hitstop_per_damage`, 상한 `hitstop_max`
  - `repeat_interval` 판정(열차·담배 연기)은 건너뜀 / 이미 `time_scale` < 0.5면 안 걸음(KO 슬로모션 배속을 1로 되돌려버림) / 복귀 타이머는 `ignore_time_scale = true` 필수
- 색조: `Fighter.set_tint(id, color, duration)`/`clear_tint(id)` — 스택식(set_modifier와 같은 발상). 사용처: `DashSkill`·`BBGunSkill`·`HealSkill`·`RageBuffSkill`·`WeakenAuraUltimate`·`DrinkSkill`·`VomitSkill`·`ScreamConeUltimate`
- 넉백: `Hitbox.knockback`을 `Fighter.take_damage`가 velocity에 더함. 스킬별 값은 전부 임시(세밀 조정 TODO)
- `ui/RoundStart.tscn` 카운트다운 동안 컨트롤러 `is_active` false. ⚠️ `set_physics_process(false)`로 멈추면 관성으로 미끄러짐 — `apply_physics`는 계속 돌리고 `fighter.move(0.0)`으로 수평 속도 0 고정

### 주정뱅이 술병 타격 연출

- `combat/LiquorSplash.gd`(장식, `_draw()`): 콤보 **마무리 3타에만** 술방울이 때린 방향으로 튐. 스택당 `drops_per_power` 개 — `Hitbox._spawn_debris()`가 `custom_data["drink_stacks"]`를 `burst_power`로. 타별 스위치 `Hitbox.debris_enabled`(런타임 값)를 `ComboMeleeAttack._fire()`가 `debris_final_hit_only`로 설정. 다른 캐릭터는 `debris_scene` 비어 영향 없음
- **8번 맞히면 소주병이 깨짐**(연출만, 라운드 끝까지 유지): 기본공격 히트박스 `connected`만 셈(헛침·스킬 제외, 방어에 막힌 건 포함). `BasicAttack` export `break_after_hits`(0이면 안 깨짐)/`broken_item_texture`/`break_debris_scene`(`combat/GlassShard.tscn`)/`break_debris_count`. 한 번만 깨짐
  - `BodyRig.swap_held_texture()`는 `HandRHold` 첫 Sprite2D 텍스처만 교체 — **두 그림 캔버스가 같아야 함**. `꺠진소주병.png`는 코드로 만든 임시 그림, 정식 그림은 **같은 1254x1254 캔버스로** 덮어쓸 것
  - `GlassShard.gd`·`sprite/주정뱅이/스킬로고/유리조각*.png`는 병 깨질 때만 사용. 그림이 형광 초록이라 같은 조명에서도 주변보다 빛나 보여서 `GlassShard.tint` (0.65, 0.55, 0.65)를 조각 스프라이트(`Piece.modulate`)에 곱해 주변 톤에 맞춘다(노드 자신의 modulate는 사라지는 트윈이 투명도로 씀)
  - **바닥 닿음은 칠해진 부분의 볼록 껍질로**(2026-09-29 사용자 요청 "폴리곤 딱 맞게", `GlassShard._hull_of` — `BikeWreck`과 같은 방식): 껍질 가운데를 회전축으로 두고, 껍질의 한 변(긴 변일수록 잘 뽑힘)이 바닥에 평평하게 눕는 각도로 굴러 떨어져 맨 아래 점이 바닥선에 딱 닿는다. 예전 `get_used_rect()` 상자 바닥 기준은 돌아가면 떠 있거나 파묻혔다. 착지 세로 눌림은 뺐다(돌아간 조각을 세로로 누르면 모양이 틀어져 떠 보임)

## 그 밖의 화면

- **도감 `ui/CharacterDex.tscn`+`.gd`** — 읽기 전용(확인 창 없음), 메인 메뉴 `DexButton`으로 연다
  - 별점은 표시 전용 `CharacterStats.attack_rating`/`hp_rating`/`speed_rating`(실제 스탯은 로스터가 거의 같아서). 맵 설명은 `CharacterDex.MAP_DESCRIPTIONS`
  - ⚠️ TODO: 놀이터 설명이 옛 기믹(미끄럼틀·화분) 그대로 — "왕관 훔쳐서 달아나기"로 고칠 것
- **일시정지 `ui/PauseMenu.tscn`+`.gd`** — ESC로 `Stage.gd`가 붙이고, `paused`는 PauseMenu `_ready()`가 건다. **`process_mode = ALWAYS` 필수**
  - 등장 연출: 왼쪽 메뉴는 왼쪽에서, 스토리 칸은 오른쪽에서 차례로 밀려 들어온다(`intro_*`), 제목은 제자리 페이드
    - 움직이는 건 항목·칸 자신 — **안의 `Slide`는 건드리지 말 것**(선택 연출과 충돌)
    - `_setup_intro()`가 첫 프레임에 `_apply_intro(0.0)`(안 하면 번쩍). 끝나면 `_intro_t`도 멈추니 시간 재기에 쓰지 말 것
  - 왼쪽: "일시정지" + 사선 메뉴 4개(계속하기/다시하기/설정/메인메뉴로), 색·사선 그림·연출은 메인 메뉴 값 그대로(같은 한 장)
  - 오른쪽: `GameState.current_story_name()` 상자 + 스토리 목록. 칸은 같은 사선 그림 `flip_h`, **`GameState.STORY_EPISODES` 순서로 코드가 생성**. 스토리 모드가 아니면 `StoryPanel` 통째로 숨김
  - 미클리어 에피소드는 자물쇠(사용자 지정, 진행 중인 건 제외) — `ui/LockIcon.gd` `_draw()`(폰트에 🔒 글리프 없음)
  - 목록은 보여주기만(고르면 하던 대전이 날아감). 고르게 하려면 칸을 Button으로 바꾸고 `GameState.start_story(id)`
  - 설정은 씬 전환 없이 위에 얹는다(`Settings.overlay_mode = true`) — 닫을 때 `closed` 쏘고 자기만 `queue_free()`
    - ⚠️ `Settings._unhandled_input` ESC는 닫기 **전에** `set_input_as_handled()` — 안 하면 PauseMenu까지 같이 닫힌다(순서 뒤집으면 `get_viewport()` null)

### 스토리 진행도 (2026-09-15)

- 에피소드 목록 = `GameState.STORY_EPISODES`(`{id, name, scene}`, `scene` 비면 미제작 — 지금 `ep1`만). 시작은 `GameState.start_story(id)` 한 곳
- 클리어 기록 `GameState.story_cleared`(`user://settings.cfg` `[story] cleared`), `mark_story_cleared(id)`가 즉시 저장
- 기록 시점 = **`StoryFadeScene.clears_story`를 켠 장면의 `_ready()`**(지금 `StoryScene11`) — 마지막 장면은 `next_scene`이 비어 "끝" 시점이 없어서. 새 이야기를 붙이면 이 체크를 그 마지막 장면으로 옮길 것
- **`ui/FanTile.gd`(@tool, Button 상속)** — 캐릭터 선택 칸. `corners` 네 점을 채우면 그 모양으로 그리고 클릭 판정도 따른다
  - `CharacterSelect.tscn`: 가운데 랜덤 칸 기준 왼쪽(`flip_h=true`)/오른쪽 사슬, 인접 칸은 `lean`만큼 겹쳐야 변이 맞물린다. 추가는 좌우 번갈아(다음 왼쪽) + `ThumbRow.custom_minimum_size.x` 갱신 — 식은 `FanTile.gd` 맨 위 주석
- **`ui/outline.gdshader`** — 알파 가장자리 안쪽 선(`line_alpha`로 켜고 끔), 알파 있는 그림이면 재사용 가능
  - ⚠️ Godot 셰이더는 사용자 함수 안에서 `TEXTURE`/`UV` 못 씀 — 헬퍼로 짜면 컴파일 통째 실패, 여덟 방향을 `fragment()`에 펼쳐 쓸 것

## 맵 기믹

- `maps/PassingTrain.gd`(`maps/SubwayTrack.tscn`): 제자리 on/off 판정만 있는 열차(경고→ON→OFF), 아직 폴리곤
- `maps/SubwayTrain.gd`+`.tscn`(`DecoSubwayTrain`): 선로를 가로지르는 열차, 조절은 인스펙터(`interval`은 "도착→다음 도착", 통과 시간 포함)
  - `Hitbox.repeat_interval`로 계속 재타격·밀림(지붕까지 판정)
  - **창문 불빛·빛기둥은 꺼져 있다(사용자 요청 "어색하다")** — `window_lights`(기본 false)면 `Body/WindowGlow` 숨김 + 빛기둥 미생성. 켜면 아래대로 동작
    - `열차창문빛.png` 캔버스는 region보다 사방 70px 크고 둘 다 centered(여백 비대칭이면 어긋남). 열차 그림을 바꾸면 마스크·`WINDOW_RECTS`도 다시 뽑을 것
    - ⚠️ `CanvasModulate`가 가산광 색까지 곱한다 — 창문빛 그림은 맵 조명 (0.55,0.58,0.7) 기준으로 구웠다. 맵 조명을 바꾸면 `WindowGlow.modulate`·`beam_color`를 **원하는 최종색 ÷ 새 조명**으로 다시 잡을 것
    - 빛기둥 컨테이너(더하기 블렌드)는 **Car보다 앞 순서**(위면 판때기). ⚠️ `beam_spread` 크게 주면 하얗게 뜬다
  - 운전실이 왼쪽이라 `_apply_direction()`이 `body.scale.x = -_direction`
  - **AI 회피 범용 시스템:** `is_dangerous()` + `"ai_danger_zone"` 그룹 → `AIController._try_dodge_hazard()`가 가까운 `"ai_safe_spot"`(`maps/AISafeSpot.gd`)로 피한다. 새 기믹은 이 둘만 만들면 됨
- `Hitbox.repeat_interval`(기본 0): >0이면 겹친 동안 간격마다 재타격(`_process`+`get_overlapping_areas()`). 스킬 히트박스는 전부 0. 판정 껐다 켤 때 `clear_repeat_state()`

### `maps/Playground.tscn` (놀이터) — **왕관 훔쳐서 달아나기** / 스프링 시소 / 그네 / 모래사장

3단 등반: 양 끝 스프링 시소 → 미끄럼틀 지붕 → 중간 구름 → 꼭대기 구름의 왕관. 가운데 그네는 튕겨내는 방해물.

- **빌더 `tools/build_playground.py`와 씬의 동기화(중요)**
  - 빌더가 씬을 통째로 생성 — 좌표는 빌더 상수(`ROOF_Y`/`MID_Y`/`TOP_Y`/`SPRING_X`/`MID_LEFT_CX`/`TOP_CX`...)로 바꾼다
  - 편집기 손수정 값은 `PLATFORM_OVERRIDES`·`CROWN_POS`/`CROWN_VISUAL_OFFSET`에 옮겨 적을 것 — 안 하면 빌더 재실행 시 되돌아간다
  - ⚠️ 빌더는 `maps/Playground.tscn`을 곧바로 덮어쓴다(출력 경로 인자 없음) — 돌리기 전에 씬 백업
  - ⚠️ **지금은 빌더를 돌리면 안 된다:** 미끄럼틀 교체·왼쪽 미끄럼틀 판정은 씬을 직접 고쳤고 빌더는 아직 정자 기준이다. 돌리면 이 변경과 에디터 수정이 날아간다
  - 씬에서 노드를 지우면 빌더 생성 코드도 같이 지울 것
- **땅:** `DecoSky/GroundImage`(`놀이터바닥_모래띠제거.png`) 지면선을 y=280에, 잔디 `DecoSky/GrassTile0~3`(`잔디.png` 이어 붙임). 배율 바꾸면 위치 재계산(잔디 `y = 280 + (617 - 560) x 배율`)
  - ⚠️ 그림을 넣었는데 화면이 안 바뀌면 **`z_index` 높은 옛 폴리곤이 덮는지부터** 볼 것(실제로 겪음)

| 요소 | 좌표 |
|---|---|
| 바닥 윗면 | y=280 (`Ground` y=300, 1920x40), 좌우 벽 x=±960 (**그림 없이 충돌만**, 안쪽 면 ±940) |
| 스프링 시소 | 좌석 윗면 y=226, **원웨이**. 오른쪽 x=680, 왼쪽 x=**-770**(편집기 수정) |
| 미끄럼틀 지붕 (1층) | 윗면 y=-82, `PavilionLeft/RightRoof` 315x20 @ ±560, **원웨이** |
| 미끄럼틀 기둥·판 | 오른쪽은 충돌 없는 장식, **왼쪽은 판정 있음**(아래 참고) |
| 중간 구름 (2층) | 윗면 y≈-228, 왼쪽 x -390~-130 / 오른쪽 x 224~484 (260x20, **원웨이**) |
| 꼭대기 구름 (3층) | 윗면 y=-418, x -114~174 (`CloudTop` 288x16, **원웨이**) |
| 왕관 | `Crown` (25, -472) |
| 그네 | `Swing` (0, 280) |
| 모래사장 | x ±110~±330 (`SandPit0/1`) |
| 스폰 | PlayerSpawn1/2 = ±560 |
| 카메라 | `min_y` -300 / `max_y` 20 / `lock_ground_to_bottom` 켬 |

- 구름은 좌우 대칭이 아니다(사용자가 그림 위치를 옮기고 발판을 맞춤). 대칭으로 되돌리려면 빌더의 `MID_LEFT_CX`/`MID_RIGHT_CX`/`TOP_CX`
- **왕관은 본체 `Crown`을 옮길 것** — 자식(`CrownCollision`/`CrownVisual`)만 옮기면 머리 위·바닥에 놓을 때 그만큼 떠서 줍기 판정이 어긋난다
- **점프 높이 ↔ 층 간격 동기화:** 여유가 수십 px뿐이라 점프·중력·스프링 상수나 발판 위치를 바꾸면 사다리가 바로 끊긴다 — 바꾸면 헤드리스로 재실측할 것
  - ⚠️ TODO: 구름 수정·점프력 변경 뒤 재실측 안 됨. 계산상 중간→꼭대기가 필요 190px로 이단 점프 최대(~193)에 여유 ~3px, 가로도 안 겹쳐(왼 16px/오른 50px) **왕관에 사실상 못 올라갈 수 있다** — 안 되면 꼭대기 구름을 20~30px 내리거나 넓힐 것
  - 지면→지붕은 스프링만으로 부족, **튕긴 정점에서 공중점프**로 닿는 설계(스프링 좌석은 바닥 취급이라 튕길 때 공중점프가 차 있음)
- **모든 층 발판·스프링 좌석은 원웨이여야 한다** — 스프링으로 지붕을 뚫고 올라가고 위에서 내려오기 위해. 좌석이 꽉 찬 충돌이면 옆으로 못 지나가 벽이 된다
- **카메라:** 위쪽이 중요해서 `max_y` 20 / `min_y` -300. 구름을 올리면 `min_y`도 같이 올릴 것(안 그러면 꼭대기에서 카메라가 멈춤)
  - `CameraRig.start_pan(초, 끝 비율, 최소 거리, 제자리 시간)`: 캐릭터를 안 따라가고 벽 한계선 왼쪽 끝에서 끝 비율까지 흐른다. ⚠️ 타이틀은 카메라를 `get_camera_2d()`로 찾지 말고 맵 안의 CameraRig를 직접 찾는다(놀이터는 지워지는 중인 왕관 컷인 안의 카메라가 잡혀 흐르기가 안 시작됐었다)(타이틀 전용, `pan_time` 0이면 평소대로 따라감). 벽 없는 맵은 처음 자리 기준 ±400px
  - `CameraRig.lock_ground_to_bottom`: 줌과 무관하게 지면을 화면 아래 `ground_margin_px` 위에 고정. 기본 꺼짐, 놀이터만 켬(다른 맵은 `ground_y` 맞춰 켜면 됨)
- ⚠️ **배경이 지글거리면 밉맵부터 의심**(큰 원본을 0.14배까지 축소) — 두 가지 다 해야 한다: ① `sprite/맵/놀이터/*.png.import`에 `mipmaps/generate=true` ② 씬 루트 `texture_filter = 4`(기본 필터는 밉맵을 안 봄). 이방성(6)은 효과 없음. 더 줄이려면 `FENCE_H`를 키울 것
- **아파트 배경:** `아파트1동/2동/3동.png`을 빌더 `APT_SPRITES`/`APARTMENTS`로 9동 배치
  - `a1`은 "1동" 간판이 있어 **한 동만** 쓴다
  - 지붕이 구름 발판과 겹치면 구름 테두리가 뭉개진다 — `check_apartments()`가 `CLOUD_ZONES`로 검산·경고
  - 원경 흐리기는 `modulate`(곱셈)로 못 밝혀서 하늘색 판(`Haze*`)을 덮는다
- **울타리 `덜촘촘한울타리.png`** 가로 반복(`FENCE_H` 84, 아랫변 지면, `FENCE_SPAN` ±1360)
  - 이음매가 맞게 **온전한 안쪽 기둥 두 개 사이만 region으로 잘라 쓴다** — 캔버스 통째로 붙이면 잘린 끝 기둥끼리 만나 간격이 틀어진다. 그림 바꾸면 재측정
- **미끄럼틀(`미끄럼틀-넓은버전.png`)** — 노드 이름은 `PavilionLeft/Right`(`Roof`) 그대로. 미끄럼판이 둘 다 안쪽(그네 쪽)으로 오게 오른쪽만 `flip_h`
  - **왼쪽만 판정 있음**, 바디 넷: `PavilionLeftRoof`·`PavilionLeftBar`(원웨이) / `PavilionLeftPosts`·`PavilionLeftSlide`(막힘) — 왼쪽 탑 안(스프링)은 위로만 들어간다. 오른쪽은 지붕 판정뿐
  - ⚠️ CollisionShape2D는 물리 바디의 **직계 자식**만 등록된다(편집기에서 `Collision` 밑에 붙여 하나도 안 먹혔었음)
  - ⚠️ 한 바디에 몰지 말 것 — `drop_through_platform()`은 밟은 발판 **바디 전체**를 예외 처리해 지붕에서 내려가면 기둥까지 뚫린다
  - 빌더의 정자(`정자.png`, `PAV_*`) 로직은 옛것. 지붕 기준선은 bbox 맨 위(처마 끝)가 아니라 실제 밟는 면으로 잡을 것
- **그네 `maps/Swing.gd` — 탑승 없이 튕겨내는 방해물**(탑승식은 맵 한가운데 "감옥"이 돼서 바꿈)
  - 좌석이 항상 왕복, 닿으면 **좌석에 대한 상대 속도의 반대쪽**으로 튕긴다
  - 튕긴 뒤 `apply_hitstun`(최대 `bounce_stun_max`) 필수 — 안 걸면 `Fighter.move()`가 다음 프레임에 덮어써 튕김이 사라진다
  - ⚠️ 날아가는 거리는 **속도보다 경직 시간이 정한다** — 거리 = `v x T - 450 x T^2`(T = min(경직, v/900))
  - 데미지 0(왕관 안 벗겨짐). `rebounce_delay` 동안 같은 사람 재튕김 없음
  - 그림: 고정 `Frame` + 회전하는 `Arm`(축=쇠고리) 밑 `SeatVisual`, 판정 `Arm/Seat`. 그림 바꾸면 기준점 재측정
- **구름 그림:** `CloudTop`=`구름1.png`, `CloudMidLeft`/`CloudMidRight`=`구름2.png`(구름3 안 씀). 빌더 `CLOUDS` 표
  - 세로는 `CLOUD_ASPECT`로 고정한 비균등 배율(두께 통일·층 간격 보호). `region_rect`는 알파 bbox — 그림 바꾸면 재측정
- **기절 연출 `combat/StunStars.gd`/`.tscn`** — `기절효과1/2.png` 2프레임 플립북, 왕관 뺏긴 쪽 머리 위(`Crown._drop()`이 `StunStars.spawn(loser, king_stun_time)`)
  - 두 프레임은 **합집합 bbox로 똑같이** 잘라야 안 튄다. 캐릭터 자식 금지(반전·소멸에 휩쓸림) — 맵에 붙여 따라간다. 이미 떠 있으면 `extend()`
- **모래사장 그림 `모래사장 (2).png`**(`Ground` 자식 `SandVisual0/1`) — **모래 윗면이 지면 y=280**에 오게 역산(`SAND_SURFACE_F`), 세로로 늘여 씀(`SAND_W`/`SAND_H`), 판정 폭보다 약간 넓게
  - `Ground`가 y=300이라 지면이 로컬 y=-20 — 빼먹으면 20px 어긋남
  - 빨간 틀은 사용자 결정으로 유지. 틀 없는 판 `모래사장_틀없음.png`도 있다
  - ⚠️ 텍스처 경로를 바꿀 땐 `ext_resource`의 낡은 `uid=`를 지울 것 — Godot이 uid를 우선해 옛 그림이 계속 나온다
  - ⚠️ `모래사장.png`(괄호 없음)는 쓰지 말 것 — 내용이 왕관이고 알파 없이 체크무늬가 구워져 있다
- **왕관 그림 `진짜왕관.png`** — 맵 `Crown/CrownVisual`과 `ui/CrownCutIn.tscn`의 `Holder/Crown` **두 곳 다** 바꿔야 모양이 맞는다. 알파 bbox가 캔버스 중앙이 아니라 `region_enabled`로 bbox만 잘라 쓴다. `왕관.png`는 미사용
- **시소:** 왼쪽 `기린시소.png`, 오른쪽 `파란시소.png` — 안장=좌석 충돌(226), 받침=지면(280). 눌림 연출은 `Visual`을 지면 기준 세로 압축(노드를 지면에)
- **`maps/SpringJumpPad.gd` — 트램폴린**: 좌석에 닿으면 버튼 없이 튕긴다(`bounce_velocity` 최소 / `bounce_restitution` 낙하속도 배수 / `max_bounce_velocity` 상한)
  - 착지 순간 `velocity.y`가 0이라 직전 낙하 속도(`_prev_fall`)를 기억해 쓴다. 판정은 좌석 바로 위만
  - 신호 대신 매 프레임 `get_overlapping_areas()`(리셋·순간이동 때 신호 누락 대비 — `SandPit`도 동일)
- **`maps/Crown.gd` — 핵심 기믹.** 왕관에 몸으로 닿으면 "놀이터의 왕", 한 대라도 맞으면 왕관이 바닥에 떨어지고 `pickup_delay` 뒤 아무나 줍는다
  - **승리 조건은 건드리지 않는다**(사용자·설계 결정) — 승패는 HP·링아웃뿐. "N초 보유 승리"를 원하면 맵이 아니라 `RoomSettings` 규칙 옵션으로
  - 왕 버프: 속도·공격력(`attack_debuff_multiplier`에 `set_modifier` — 이름과 달리 곱하는 값)·모래 면역. 왕 표시 `custom_data["playground_king"]`, 조회 `Crown.is_king(fighter)`
  - 떨어뜨리기 훅은 `Fighter.damaged(amount, knockback)`(`health_changed`는 회복에도 오고 넉백 모름). 가드로 0 깎이면 발동 안 함. **넉백 없는 피해(`apply_dot`/`MouseGrab`)로는 안 벗겨진다**
  - `pickup_delay`를 0으로 두지 말 것(때린 쪽이 즉시 회수). 떨어질 때 `drop_velocity`는 거의 수직 — 넉백 방향으로 날리면 때린 쪽이 손해였다
  - `drop_grace`: 주운 직후 무적 — 원거리 무한 봉쇄 방지(원거리/근접은 수치로 구분 불가라 빈도 상한으로 해결)
  - 겹친 사람 중 가장 가까운 쪽이 줍는다
  - ⚠️ Area2D 맵 기믹에서 `gravity` 변수명 금지(내장 프로퍼티와 충돌 → 컴파일 에러, `fall_gravity` 사용). `priority`·`monitoring`·`linear_damp`·`angular_damp`도 피할 것
  - 떨어진 왕관은 `_fall()`이 손으로 계산 — **발판은 통과해 항상 지면까지**
  - 획득 컷인 `ui/CrownCutIn.tscn`은 `cutin_once`면 라운드 첫 획득에만
  - AI: `AIController._try_take_crown()`이 `crown_interest_range` 안의 왕관을 발판 길찾기로 올라가 줍는다(2026-09-27 — 예전엔 바닥 왕관만). 상대가 코앞이면 싸움 먼저
- **`maps/SandPit.gd` — 모래사장**: 안에 있는 동안 `set_modifier("move_speed_multiplier", 노드 id, slow_multiplier)`, 벗어나면 `clear_modifier`(다른 둔화와 안 지움). 왕은 면역
  - 판정은 발치 높이에만 — 점프하면 바로 벗어난다(걸어서 느리게 vs 뛰어넘기 선택이 의도)
  - 폭을 바꿀 때 미끄럼틀·스프링 시소·스폰 지점과 안 겹치는지(스폰이 모래 밖에서 시작) 같이 확인

### `maps/SubwayPlatform.tscn` 구조

**승강장 바닥 없음 — 선로 바닥에서 싸운다.** 올라갈 발판은 의자 2개뿐.

| 요소 | 좌표 |
|---|---|
| 선로 바닥 | y = 300 (`Ground` y=320, 1120x40) |
| 좌우 터널 벽 | x = ±560 → 이동 범위 -520~520 |
| 의자 발판 윗면 | y = 155 (`BenchLeft/Right`, x ±280, 폭 220, 원웨이) |
| 열차 | y 195~300 (`DecoSubwayTrain` y=247.5) |
| 카메라 | `min_y` 80 / `max_y` 190 |

- 의자 높이(145px)는 **이단 점프 전용**(기획 확정 5). **의자 위 = 열차 피난처**(캐릭터 발 155 vs 열차 지붕 195) — 의자 높이·열차 크기 바꿀 때 같이 계산
- 의자는 트리에서 열차보다 먼저 = 열차가 의자 앞을 지나감(순서 바꾸면 의자가 열차 위에 얹혀 보임)
- 링아웃 없음. `GameState.MAPS` 이름 "지하철 승강장 (열차)"

### 지하철역 스프라이트 배치 (`sprite/맵/지하철역/`)

- 전부 `region_rect`로 투명 여백을 잘라 배치(여백 포함하면 위치 계산 어긋남). 값은 씬 참고
- 벽 타일은 texture_repeat 대신 스프라이트 8장(원본 가장자리 비네트 때문에 반복하면 이음매마다 어두운 띠)
- `역이름.png` 좌우 띠는 그림 폭(1000)까지만 → 같은 색 `SignBand` + `SignBandOutline` 폴리곤을 벽 폭으로 깔았다. **그림 옮기면 둘도 같이**
- `Track`(안쪽 선로)만 `Deco` 접두사 없음 — 미리보기에 바닥 선이 보여야 해서
- **조명:** `CanvasModulate` (0.55, 0.58, 0.7)로 어둡게 깔고 형광등마다 진짜 `PointLight2D`로 밝힘(사용자 요청 "전등 빛을 플레이어가 받게")
  - 빛나야 하는 물체는 `CanvasItemMaterial.light_mode = UNSHADED`(씬의 `CanvasItemMaterial_unshaded` 공유): `StationSign`·`SignBand`/`SignBandOutline`·`SignBoard`(자식 `Clip`/`Text`는 `use_parent_material`)·형광관 `Light` 레이어
  - **unshaded는 `CanvasModulate`까지 무시한다** → 보정 계산 불필요. 반대로 **더하기(가산) 색은 `CanvasModulate`가 곱해지므로** 조명을 바꾸면 가산 색도 다시 잡을 것
- **층 깊이 표현**(카메라가 거의 안 움직여 parallax만으론 깊이가 안 보여서):
  - **먼 층 흐리게:** `DecoBackground` = `CanvasGroup` + `maps/far_blur.gdshader`(`blur_px` 0.8, `dim`, unshaded — 자식이 합쳐질 때 이미 조명 받음). 그룹째 흐려야 벽 타일 이음매가 안 번진다. 흐리는 건 벽·역 이름판·형광등·전광판뿐(더 흐리면 역 번호가 안 읽힘)
  - **먼 층 덜 움직이기:** `DecoBackground`에 `maps/ParallaxFollow.gd`(`factor` 0.8 = 카메라 움직임의 80%만 따라감, `reference` (0, 150) = 카메라 기본 중심 — 거기선 에디터 배치 그대로). 벽 타일이 x ±1000까지 깔려 있어 밀려도 안 빈다. 공용 스크립트라 다른 층·맵에도 붙이면 된다(1보다 크면 앞 층)
  - 의자 아래 땅(`PlatformEdge0~8`·`TrackPit`·`RailFarLeft/Right`)은 선명한 `DecoGround`(z -10, `DecoBackground` 바로 다음). 싸우는 층도 그룹 밖
  - **앞 층 기둥:** `DecoForeground`(`maps/ForegroundPillars.gd`, @tool, z 50, unshaded) x -560/0/560, 폭 120. 카메라 이동의 `parallax`(1.25)배 움직여 앞에 있는 것처럼(카메라 x=0일 때 에디터 배치 그대로). 캐릭터가 뒤에 들어가면 그 기둥만 `behind_alpha` 반투명
  - 그림이 있으면 `_draw_textured()`로 세로 반복, 없으면 임시 어두운 도형. **씬은 원본 `기둥.png`가 아니라 반복용 `기둥_반복.png`를 쓴다**(`texture_region` (5, 0, 318, 1655))
    - ⚠️ 손그림이라 세로줄이 그림 위·아래에서 3~4px 어긋나 **어디서 잘라도 이음매에 턱/줄이 생긴다**(캔버스째 반복하면 이음매 칸이 117px로 길어지고, 가로줄 한가운데서 자르면 줄이 한 줄 더 생겼다). 그래서 원본에서 가로줄 19px 아래 흰 면끼리(y 88~1743, 같은 위상) 잘라낸 뒤, **끝 40줄을 시작 바로 위 40줄과 크로스페이드**해 마지막 줄이 첫 줄로 이어지게 구웠다(`tools/make_pillar_tile.py`). 그림을 바꾸면 같은 방식으로 다시 만들 것
  - `tint`로 어둡게 + `maps/foreground_blur.gdshader`(unshaded). 크게 축소하므로 `.import` 밉맵 + `texture_filter` 밉맵 선형(지글거림 방지)
- **벽 형광등 `maps/FluorescentLight.tscn`/`.gd`:** 가끔 파바박·푹 꺼졌다 켜짐. `DecoBackground` 안 4개(역 이름판을 피하고 카메라 최대 줌에서도 보이는 높이)
  - 주변 조명은 코드로 만드는 자식 `Lamp`(PointLight2D, 씬 저장 안 됨). 빛 색은 살짝 따뜻하게(푸른 방과 대비 — 빛 받는 곳은 원래 색, 그늘은 푸르게). 폭을 크게 주면 형광등 간격(160)상 빛이 겹쳐 캐릭터가 하얗게 날아간다
  - 깜빡임은 `Light` 레이어 투명도 + `Lamp` 세기를 같이 바꾼다
  - 아직 임시 도형 — 스프라이트 받으면 `_draw()`만 교체. `FluorescentLight2`만 `flicker_interval` 짧게 = 고장 난 형광등(전부 같으면 연출처럼 보임)
- **바람에 날리는 신문지 `maps/WindNewspaper.gd`**(장식, `DecoWindPapers` 아래 8장, 아직 도형 — 그림 오면 `_draw()`만):
  - `wind_speed`가 열차보다 느려야 처지며 흩날린다(같거나 빠르면 열차에 붙어 사라짐). 경고 구간엔 들썩(`tremble`)
  - 열차는 `"subway_train"` 그룹 + 읽기 전용 `is_running()`/`get_direction()`/`get_body_x()`/`get_half_width()`. 트리 순서가 `DecoSubwayTrain` 다음이라야 열차 앞에 그려짐
  - 노드 `scale` 안 쓰고 배율 `_look`을 좌표에 곱한다(@tool이라 scale이 씬에 저장되고 외곽선도 얇아짐)
- **화면 진동:** 열차 경고·통과 중(`warning_shake`/`pass_shake`)
  - ⚠️ `CameraRig.add_trauma()`는 순간 충격이라 매 프레임 조금씩 부어도 안 쌓인다 → 지속 진동은 `CameraRig.set_rumble(세기)`(이번 프레임 바닥값)
- **전광판 `maps/SubwaySignBoard.gd`:** 평소 문구가 흐르고 경고 중엔 빨간 "열차가 들어오고 있습니다"를 가운데서 깜빡(흘리면 못 읽음). 판은 `_draw()`, 글자는 자식 `Clip/Text`(Label, `clip_contents`로 자름 — `_draw()`로는 못 자름), 주아체
- ⚠️ `.tscn`에 노드를 손으로 끼울 땐 부모의 속성 줄 **다음**에 넣을 것 — 헤더 바로 뒤에 끼우면 부모 `position`이 새 노드로 딸려가 에러 없이 바닥이 y=0이 됐다(매 라운드 무승부)
- **TODO(기획):** ① 열차 위에서 전투 ② 두 번째 열차에서 지하철 빌런 무리 쏟아지는 연출
- **올라갈 수 있는 발판은 반드시 `one_way_collision = true`**(실제 버그: 밑 공간이 좁아 꽉 찬 충돌이면 밑의 캐릭터가 끼어 눌림). 단 `TrashRoom` 쓰레기 더미는 밑 공간 없는 장애물이라 원웨이 금지
- **`Deco`로 시작하는 노드 = 맵 선택 미리보기(`ui/MapPreview.gd`)에서 제외**(화면 밖 장식이 섞이면 스테이지가 점처럼 작아짐). `Camera2D`/`CanvasLayer`도 제외. 새 맵 장식도 이 규칙

### 맵 전용 스킬(`Stage.map_skill_scene` / `Fighter.map_skill`) — 캐릭터 씬을 안 건드리고 맵에만 스킬을 붙이는 인프라

- `Stage.map_skill_scene`(PackedScene)을 지정하면 `_spawn_fighter()`가 두 캐릭터 모두에 인스턴스해 붙이고 `fighter.map_skill`에 저장. 비우면 무동작
- `Fighter.use_map_skill()`: `use_skill_1()`과 같은 확인(공포·잡힘·busy·쿨) 후 발동, **스킬 클래시는 안 탄다**(맵과의 상호작용이라)
- 입력: **공중에서 아래 키 단독**(`PlayerController._physics_process()`) — 원래 단독으론 효과 없던 키라 기존 조작을 안 깬다. map_skill 없는 맵에선 조용히 리턴
- `Fighter.get_one_way_floor()`는 외부 스킬도 밟은 발판을 알아야 해서 공개 메서드

### `skills/GroundPoundSkill.gd` + `maps/BreakablePlatform.gd` — 내리찍기와 부서지는 발판

- 공중에서 수직 급강하(`movement_override`로 좌우 잠금) → 착지 순간 원형 범위 데미지 + 밟은 발판이 `break_platform()`을 가지면 부순다(`has_method` 덕 타이핑 — 진짜 지면은 안 부서짐)
- 지상에서 쓰이면 쿨타임을 0으로 되돌린다
- `BreakablePlatform`: 부서지면 숨기고 충돌 끔 → **자식 `RespawnTimer`**로 `respawn_time` 뒤 복구(`get_tree().create_timer()` 금지 — Lambda capture 함정)
- 파편은 `CrashBurst` 재사용(색만 바꿈)

### `maps/CollapsingApartment.tscn` — 공사현장 (세로로 긴 맵, 파일·클래스 이름은 `CollapsingApartment` 그대로)

- 진짜 지면 위 `BreakablePlatform` 4층, 층 간격 170px. `map_skill_scene` = `GroundPoundSkill.tscn`
- 벽 사이 1200px, 발판 폭 500을 층마다 좌우 교차(`Floor1/3` 왼쪽 x -250, `Floor2/4` 오른쪽 x 250) — **반대쪽으로 대각선 점프해야** 다음 층
- 층 간격 170 = "지상 점프로는 못 닿고 이단 점프로만"을 연속 물리 공식으로 계산한 값. **점프력(`DEFAULT_JUMP_VELOCITY`/`DEFAULT_AIR_JUMP_VELOCITY`)이 바뀌면 다시 계산**, 이산 물리와 다를 수 있으니 훈련장에서 확인
- `CameraRig._apply_wall_limits()`가 벽 폭으로 최소 줌을 강제 → 두 캐릭터가 층 끝과 끝으로 멀어지면 한쪽이 화면 밖일 수 있음(구조적 한계, `stage_width`·`min_y`/`max_y`/`extra_zoom`으로 조정)
- `HintLayer/HintLabel`에 조작 힌트 고정 표시

## GDScript 코드 스타일

### 명명 규칙

| 대상 | 규칙 | 예시 |
| --- | --- | --- |
| 클래스명 / 파일명 | PascalCase, 파일명 = class_name | `CharacterStats` |
| 함수 / 변수 | snake_case | `move_speed`, `take_damage()` |
| 상수 / enum 값 | ALL_CAPS_SNAKE_CASE | `MAX_HP`, `STATE_STUNNED` |
| 시그널 | 과거형 snake_case | `health_changed`, `skill_used` |
| private 관례 | 언더스코어 접두사(관례일 뿐) | `_internal_cooldown` |

### 파일 구조

- `class_name`과 `extends`는 파일 맨 위(`class_name` 없으면 `extends`만)
- `@export` 변수 → 그 외 멤버 변수 → `_ready()` 등 생명주기 함수 → 커스텀 함수 순
- 씬(`.tscn`)과 스크립트(`.gd`)는 같은 폴더에 짝지어 배치(예: `characters/jujeongbaengi/Jujeongbaengi.tscn` + `.gd`)

### 주석 — 한국어 필수

- public 함수/변수 위에 독스트링(`## 설명`) 한 줄 한국어
- 복잡한 로직에만 한 줄 한국어 설명. 자명한 코드엔 주석 금지

### 폴더 구조 (제안)

실제 구조가 이미 이대로다:

```
res://
  GameState.gd    # 오토로드 — 캐릭터/맵/모드/라운드 선택값 전달
  Timers.gd       # 공용 정적 헬퍼(after/self_destruct), 오토로드 아님
  characters/     # Fighter.gd + BodyRig.gd + 캐릭터별 씬
                  #   로스터 8종: chokbeopsonyeon/, akpeulleo/, jujeongbaengi/, catmom/,
                  #   subwayvillain/, floornoise/, gymbro/, iljin/(IljinCrewMember 포함)
                  #   로스터 밖: police/(스토리 주인공, 훈련장 전용), dummy/(TrainingGround.gd가 직접 씀)
  skills/         # Skill.gd + 스킬 컴포넌트, 투사체
  combat/         # Hitbox/Hurtbox/HitSpark + PhysicsQuery.gd
  controllers/    # PlayerController / AIController / ClaudeAIController / DummyController
  stats/          # CharacterStats 리소스(.tres)
  maps/           # Stage.gd + CameraRig.gd + 스테이지 10종(GameState.MAPS) + 공유 컴포넌트 씬
  ui/             # 메뉴·선택·결과 화면, story/, cutin/, HUD
  tools/          # 개발용 — BalanceTest/RigPreview, build_playground.py 등
```

## 참고

- 기획 오픈 이슈(히트스턴 예외, 승리 조건 HP vs 링아웃 등)는 아티팩트 문서의 "다음에 정할 것" 표 확인. 확정 전엔 임시값 + 주석/TODO
- **엔진은 4.7.2로 통일**(`project.godot` `config/features` = `"4.7"`). 버전이 섞이면 이 줄(+ 옆 `run/main_scene`)이 매번 머지 충돌 — 팀원 전원 4.7.2
  - 경고 `ext_resource, invalid UID`(그림 재임포트 후 흔함) → 씬 uid를 `.import`의 `uid=` 값으로 고칠 것
- **코드 수정 후 헤드리스 에러 확인은 기본적으로 하지 않는다(사용자 요청).** 사용자가 "실행해서 확인해줘"라고 할 때만
- Godot 실행 파일(PC마다 다름). **이 PC: `C:\Users\bitba\Desktop\임시 더미\Godot_v4.7.2-stable_win64.exe (1)\Godot_v4.7.2-stable_win64_console.exe`**(2026-09-27 Downloads에서 옮겨짐) — 공백·괄호가 있어 PowerShell에선 `& "<경로>" ...`. 다른 PC는 `D:\10인준완\Godot\engine\` 아래였음(4.6 시절). 못 찾으면 `Godot*4.7*win64*console*.exe` 검색
  - 예: `& "<경로>" --headless --path "C:\Users\bitba\Documents\GitHub\villain" "res://maps/SubwayPlatform.tscn" --fixed-fps 60 --quit-after 1100`
- ⚠️ `--editor --quit-after`로는 파싱 에러를 다 못 잡는다(실제로 겪음: 선언 빠진 변수가 통과했다가 게임에서 캐릭터 고르는 순간 크래시). **바꾼 스크립트가 실제로 쓰이는 씬을 헤드리스로 띄워야 확실**
  - `extends Node` 임시 스크립트를 `.tscn`으로 감싸 `GameState`에 캐릭터를 넣고 맵을 붙이는 방식이 빠르다
  - `change_scene_to_file()` 쓰지 말 것(테스트 노드도 사라짐) → `add_child(load(맵).instantiate())`
- 주의: 새 `class_name` 추가 직후엔 `& "<경로>" --headless --path "<프로젝트>" --editor --quit-after 20`로 전역 클래스 캐시 갱신(안 하면 "Could not find type")
- 입력 시뮬레이션 테스트는 `extends SceneTree` + `--script` 금지(오토로드 미초기화) → `extends Node` 스크립트를 임시 `.tscn`으로 감싸 `--headless --path ... <임시 씬> --quit-after N`
- 주의: 헤드리스는 프레임 제한이 없어 60fps보다 훨씬 빠르다 → 시간 기반 테스트는 `--fixed-fps 60`을 붙이거나 `Time.get_ticks_msec()`로 경과 시간 측정
