---
paths:
  - "characters/jujeongbaengi/**"
  - "sprite/주정뱅이/**"
  - "skills/DrinkSkill.gd"
  - "skills/Vomit*.gd"
  - "skills/ScreamCone*.gd"
  - "characters/SkillRangePreview.gd"
  - "combat/LiquorSplash.gd"
---

# 주정뱅이

- 술 스택(최대 3). 토 기둥 `VomitBeam`(Hitbox 상속, **맵에 붙여 입 위치에**), 길이·두께가 스택 비례, 벽에 막히면 `region_rect`를 자름
  - 그림 `sprite/주정뱅이/토사물모음/` — **파일 1~4 = 스택 0~3, 3스택은 `4스택진짜.png`**. 새 그림이면 `stack_body_rects` 재측정. 안 보이면 파싱 오류부터
- 괴성 `ScreamConeUltimate` + `ScreamCone.tscn`: **데미지·입 위치·디버프는 캐릭터 씬 `SkillUltimate`, 범위·각도·연출은 `ScreamCone.tscn` — 한 값은 한 곳에만**
- 술병: 3타에만 술방울, **8타 맞히면 병이 깨짐**(`swap_held_texture()` — 두 그림 캔버스 같아야 함). 술병 제자리 값·`drink_hand_deg` 0은 **건드리지 말 것**
- 토·술 머금은 얼굴 배율은 평소 머리와 높이를 맞춘 값(그림 바꾸면 재측정)
- 스킬 범위 미리보기 `characters/SkillRangePreview.gd`(@tool): 홀더를 옮기면 **`Apply Holders To Skill`** 후 저장. 미리보기와 게임 식은 같이 고칠 것
- 오타 파일명 그대로: `주정뱅잉 측면2.png`. ⚠️ 머리/몸통 파일명이 비슷 — 머리가 몸통으로 덮인 적 있음
