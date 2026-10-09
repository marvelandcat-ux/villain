---
paths:
  - "characters/akpeulleo/**"
  - "sprite/악플러/**"
  - "skills/MouseGrab*.gd"
  - "skills/RageBuffSkill.gd"
  - "skills/WeakenAuraUltimate.gd"
---

# 악플러

- 새 캐릭터 크기 기준(머리 ~53x52, 상한 55x55)
- `RageBuffSkill`: 콤보 매 타 +`bonus_damage` + 붉은 색조 + 액션 얼굴(전용 머리 돌리기 세트 `action_head_turn_*`) + `play_head_shake()`
- `MouseGrab.gd`: 한 장 그림을 `region_rect`로 유선/물체 잘라 그림(**그림을 다시 그리면 영역·중심선 상수 재측정**). **실효 사거리는 중력이 정함 — 속도를 바꾸면 중력은 배수의 제곱으로**. 크기 값은 `new()` 후 `setup()` 전에. `cast_windup_offset.y`는 -6보다 위로 금지
- 키보드 z_index 1(2 이상이면 대시 잔상 키보드가 본체 앞에). 두 손 잡기: 총 회전각 120도 이하, `attack_grip_speed` 9 이상
- 그랩 후 회전 난무(`spin_flurry_*`): 판정은 바라보는 쪽 반원. `spin_wind` 하얀 바람 줄기는 **꺼 둠**(2026-10-10 사용자 요청 "하얀 선 없애줘", `Akpeulleo.tscn`에서 `spin_wind = false`). 대신 **호 트레일** `combat/SpinArcTrail.gd`(리그 `fan_trail`, 키보드 양 끝이 지나간 길에 흰·검은 줄이 번갈아 겹친 호 — 2026-10-10 격투 게임 레퍼런스)
- 궁 슬로우·스킬2 공격력 버프 이펙트는 공용 `combat/StatusIconVfx.gd`(달팽이 내려감 / 칼 올라감) — CLAUDE.md "VFX는 길목에" 참고
