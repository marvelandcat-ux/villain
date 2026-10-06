---
paths:
  - "characters/police/**"
  - "sprite/경찰관/**"
  - "skills/TaserGunSkill.gd"
  - "skills/StoneThrowSkill.gd"
  - "skills/ThrownStone.gd"
  - "skills/BatonModeUltimate.gd"
  - "combat/BluntImpact.gd"
---

# 주인공(경찰) — 훈련장 전용

- **`PoliceRig.tscn`이 정본**. 표시 이름 "주인공"은 `TRAINING_ONLY_CHARACTERS`·`CHARACTER_COLORS` 키·`PoliceStats.tres` 세 곳 일치
- 테이저건: 맞으면 기절 — **기절은 스킬이 `connected` 신호로 건다**, 막히면 없음
- 맨손/경봉(`weapon_switch` + `held_item_armed`): 경봉 중 데미지 x2(`set_modifier`, `_exit_tree()`에서도 해제). 무기 숨기기는 던지기 처리보다 **뒤에**. 맨손 `jab_reach_x`는 도달 x **절대값**
- **경봉 평타 "개 패듯이"**(`armed_flurry_enabled`, 경찰만): 내려찍기 → 올려베기 + 띄우기 → 맞으면 누르는 족족 부채꼴 판정
  - ⚠️ 판정 껐다 켜기 재타격은 이 간격에선 안 됨 → `repeat_interval` 9999 + 누를 때마다 `clear_repeat_state()`. ⚠️ `_hold_in_flurry()`가 끌어당김(띄우기를 올리면 `armed_flurry_hold_y`·`armed_flurry_origin`도). 난무 중엔 `start_busy` 금지
  - 모션 `BodyRig.SLASHES` 표 + `play_weapon_slash()`. 경봉 그림은 손에서 -38도 → 손 각도 = 원하는 각도 + 38. 1·2타 `BluntImpact` + 그 두 타에만 히트스톱
- 컷인: 얼굴 두 장 크기·위치 같아야 함
