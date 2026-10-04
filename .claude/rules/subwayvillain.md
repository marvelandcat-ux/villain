---
paths:
  - "characters/subwayvillain/**"
  - "sprite/지하철빌/**"
  - "skills/Turnstile*.gd"
  - "skills/Counter*.gd"
  - "skills/DualInstrumentUltimate.gd"
  - "skills/*Recorder*.gd"
  - "skills/XSlashFinisher.gd"
  - "combat/SlashMark.gd"
  - "combat/XSlashTrail.gd"
---

# 지하철 아저씨

- 평타: 두 손 찌르기 / 발차기 / 한 바퀴 돌며 베기(`spin_duration` 0.5 → 판정 ≈ 0.223 — **회전 값을 바꾸면 `finisher_windup`과 같이**)
- **카운터 `CounterSkill`**: 자세 중 상대 공격(맵 피해 제외)을 맞으면 반격, 헛방이면 `whiff_lag`. **자세 중 idle 몸짓 금지**
  - 반격: 슬로(`Timers.after(..., real_time = true)`, `_exit_tree()`에서 복구) → 등 뒤 순간이동 → 베기 → `launch_finisher`. **필중** — 맞을 때까지 둘 다 묶음(`_lock`/`_unlock`), 신호가 안 오면 허트박스에 직접 `_try_hit`. 명중 신호에서 먼저 풀어야 `launch_finisher`가 안 막힘
  - 가로채는 곳 둘 다 `Fighter.try_counter()`: `Hurtbox.take_hit()` / `take_damage()`(넉백 있는 피해만). 등록 슬롯 `counter_stance`
- 개찰구 `Turnstile.gd`: 그림 한 장을 반으로 잘라 둘에. **`visual_scale`과 `TurnstileSkill.spacing`은 같이(spacing = 817 x 배율)**. `CABINET_X`/`BOTTOM_Y`는 그림 바꾸면 재측정
- **궁 `DualInstrumentUltimate`**(쌍 악기): 왼손 리코더, 기본공격 강화. 대시 = 뒤로 물러났다 내지르는 돌진(`dash_override` → `take_over_dash()`, `_process`에서 보면 한 프레임 늦어 튐)
  - 돌진 판정은 `sense_only`로 X자 자국(`combat/SlashMark.tscn`, **맞은 몸의 자식**, z 62)만 새기고 끝나면 터지며 `burst_damage`. 방어·무적이면 자국 없음(`connected`는 막힌 타에도 뜸)
  - 폭발 판정 = 돌진 판정 복제 — ⚠️ `DUPLICATE_SCRIPTS | DUPLICATE_GROUPS`, ⚠️ 복제본 `sense_only` 끌 것, 한 프레임만 켜면 겹침 누락 → `burst_hitbox_time`. 트리에서 빠질 땐 터뜨리지 말고 지움
  - 리그 `HandLHold`(왼손 물건걸이, `held_item_l_armed`). `_pose_dual()`은 **`_pose_guard`보다 먼저**. 쌍 악기 동안 두 악기·왼손 z를 머리 앞으로. 단소 세계각 = 손 각도 - 53.4
- 오타 파일명 그대로: `지하철 아저 씨측면 1.png`
