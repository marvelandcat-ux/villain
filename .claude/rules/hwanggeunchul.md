---
paths:
  - "characters/hwanggeunchul/**"
  - "sprite/황근출 해병/**"
  - "skills/DropkickSkill.gd"
  - "skills/JjajangEatSkill.gd"
  - "skills/Barracks*.gd"
  - "maps/Barracks*.gd"
  - "combat/ScreenShatter.gd"
  - "characters/EyeGlow.gd"
---

# 황근출 해병(숨김) `characters/hwanggeunchul/`

- 그림 `sprite/황근출 해병/`(오타 파일명 그대로: `황 근충 해병 팔.png`, `환근출 해병 정면.png`, `황근축 해병 몸 측면 3.png`). **기본 몸 = 옷 입은 버전**(`HwanggeunchulUniformRig.tscn` — 캐릭터 씬 `Visual`·`GameState` 리그·튜토리얼 교관 공용)
- 기본공격: 뒷손 잽 → 앞손 잽(경찰 맨손 잽 재사용) → 박치기(`unarmed_headbutt`, `_pose_headbutt()`, 로컬 좌표라 facing 부호 안 곱함). 수치 = 악플러 배열
- 스킬1 `DropkickSkill`: 무릎 꿇기(슈퍼아머, `set_kneeling`) → 날아 차기 → 맞으면 `launch_finisher(…, shape)`, 헛치면 착지 후 못 움직임(쓰는 내내 점프도 막음 — `Fighter.jump()`가 `movement_override.blocks_jump()`를 봄)
- 스킬2 `JjajangEatSkill`: 먹고 잃은 체력 일부 회복, 먹을 때마다 대시 쿨 증가(`dash_cooldown_bonus`), 맞으면 끊김. ⚠️ `EatBowl` 순서는 씬의 `index="3"`으로 — `_ready()`에서 `move_child`하면 대시 잔상이 자식 속성을 순서로 복사해 머리가 커진다
- **궁 `BarracksUltimate`**: 옷 벗어 던짐(`get_body_outfit()`/`set_body_outfit()`, 맨몸 값 `bare_body_*`) → 원래 맵이 깨져 떨어짐(`ScreenShatter`, 못 찍으면 암전) → 내무반으로 옮겨 15초 → 같은 연출로 복귀(까만 동안 다시 입음)
  - 내무반은 맵 위 `arena_offset`에 그때 생성: 그림 `궁극기/군대 집.webp`(배율이 작을수록 캐릭터가 크게 보임, 앞 층은 `size_scale`로 같이), 바닥·천장(`ceiling_image_y`)은 그림 y 기준. 그동안 맵 루트 CanvasItem·`Deco*` CanvasLayer를 숨기고 **`process_mode` DISABLED**(카메라 제외 — 열차 흔들림·소리·충돌이 안 새게, AI `_hazard_active()`도 `can_process()` 아닌 기믹 무시). 카메라 `CameraRig.enter_arena()`/`leave_arena()`, CameraRig 없는 훈련장은 `_enter_plain_camera()`. 도는 동안 `can_use()` false
  - 창문 `maps/BarracksWindows.gd`(배경 Sprite2D 자식 — 좌표 = 배경 그림 픽셀): 배경·창문 그림을 바꾸면 `window_rects`·`window_frame`·`window_panes` 재측정
  - 앞 층 `maps/BarracksForeground.gd`: 위아래는 매 프레임 **카메라 화면 바닥 기준**, 캐릭터가 뒤면 반투명, z 60
  - 진입 동안 둘 다 무적·busy. 쓴 순간~복귀까지 **상대 궁극기 봉인**. 눈 빨간 빛 `Head/EyeGlow`(색은 `HwanggeunchulRig.tscn`에서 덮어씀)
  - **내무반 동안 스킬2 = `BarracksSlamSkill`**(씬 노드 `BarracksSkill2`, `_swap_skill_2()`가 끼우고 나올 때 `abort()` 후 복구): 순간 돌진(지나간 구간으로 판정) → 잡아 두 손 번쩍(`set_lift_pose`, 상대 `is_grabbed`) → 상대 위로 순간이동 → 내려찍기(`set_stomp_pose`) → 땅에 꽂히는 순간 `launch_finisher`. 슬로모션 `_set_slow`/`_clear_slow`(이미 0.5 밑이면 안 건드림, `_exit_tree`에서 복구)
