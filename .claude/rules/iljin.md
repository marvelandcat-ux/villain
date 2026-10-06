---
paths:
  - "characters/iljin/**"
  - "sprite/일진/**"
  - "skills/Cigarette*.gd"
  - "skills/ShoulderChargeSkill.gd"
  - "skills/IljinCrewUltimate.gd"
  - "skills/Spit*.gd"
---

# 일진

- 평소 가방 `HandL/BagIdle`, 3타에만 `HandRHold/Bag`. 담배 연기(입 앞) / 어깨치기(같은 `launch_speed`로 뜨고 상대만 기절, 가드면 안 뜸)
- ⚠️ **액션 표정 슬롯은 하나** — 표정 쓰는 스킬은 자기 얼굴을 직접 지정
- **궁 `IljinCrewUltimate`**(등장까지만, TODO 공격·버프·퇴장): 친구·여자친구가 화면 기준 고정 위치에
  - 패거리 `IljinCrewMember`(CharacterBody2D) — **Fighter로 만들면 안 됨**. 캐릭터와 몸 충돌 끄고 가로로만 밀어냄. 부른 일진 공격엔 `immune_source`로 면역. z 0(캐릭터와 같은 층)
  - 친구 침(`Spit.tscn`): `aim()`은 `setup()` 다음, 빠른 투사체는 판정을 진행 방향으로 늘림(도형은 새로 만들어 — sub_resource 공유). 여자친구: 넉백 맞으면 `knockback_stun`
