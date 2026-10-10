"""번화가 비둘기 시트(`sprite/맵/번화가/비둘기.png`)를 자세별 PNG로 자른다 (2026-10-08).

- 배경은 **테두리에서 flood fill**로 뺀다(순백이 아니라 살짝 얼룩진 흰색이라 `BG_THRESH`로 허용).
- 남은 그림을 **빈 세로줄**로 끊어 왼쪽부터 다섯 자세 순서로 저장한다: 앉음 / 날개위 / 날개아래 / 활공 / 쪼기.
- 자세마다 **부리**(주황 픽셀 중 맨 오른쪽 끝 근처)와 **발**(나머지 주황)을 재서 `anchors.json`에 적고 출력한다.
  `DowntownPigeons.gd`의 `FRAMES` 표가 이 값을 쓴다 — **시트를 바꾸면 다시 돌리고 표도 갱신할 것**.

실행: py -3 tools/cut_pigeons.py   (Pillow + numpy만 쓴다)
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "sprite" / "맵" / "번화가" / "비둘기.png"
OUT_DIR = ROOT / "sprite" / "맵" / "번화가" / "비둘기"
NAMES = ["앉음", "날개위", "날개아래", "활공", "쪼기"]
# flood fill이 씨앗(테두리 흰색)과 이만큼 다른 밝기까지 배경으로 본다. 비둘기 밝은 회색은 ~200
BG_THRESH = 34
PAD = 2
# 부리 = 맨 오른쪽 주황 픽셀에서 이 거리 안의 주황
BEAK_RADIUS = 45


def dilate(mask: np.ndarray, r: int) -> np.ndarray:
    out = mask.copy()
    for _ in range(r):
        m = out
        p = np.pad(m, 1)
        out = (p[:-2, :-2] | p[:-2, 1:-1] | p[:-2, 2:] | p[1:-1, :-2] | m | p[1:-1, 2:]
               | p[2:, :-2] | p[2:, 1:-1] | p[2:, 2:])
    return out


def background_mask(img: Image.Image) -> np.ndarray:
    gray = img.convert("L")
    w, h = gray.size
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)] + [(x, 0) for x in range(0, w, 97)] \
        + [(x, h - 1) for x in range(0, w, 97)] + [(0, y) for y in range(0, h, 97)] + [(w - 1, y) for y in range(0, h, 97)]
    for s in seeds:
        if gray.getpixel(s) > 200:
            ImageDraw.floodfill(gray, s, 0, thresh=BG_THRESH)
    return np.array(gray) == 0


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    rgba = np.array(img)
    rgb = rgba[..., :3].astype(int)
    bg = background_mask(img)
    # flood fill이 0으로 칠한 자리 = 배경. 그림 안에 원래 0인 검정(윤곽선)은 테두리와 안 이어지니 섞이지 않게
    # 윤곽선은 밝기 0이 아니라 20~40이라 괜찮지만, 혹시 몰라 원래 0이었던 픽셀은 그림으로 되돌린다
    bg &= ~(rgb.max(axis=2) == 0)
    fg = ~bg

    alpha = np.where(fg, 255, 0).astype(np.uint8)
    # 배경과 맞닿은 그림 픽셀은 밝기대로 반투명 — 자른 자리가 톱니로 안 보이게
    edge = fg & dilate(bg, 1)
    m = rgb.min(axis=2)
    soft = np.clip((235 - m) * 255 / 60, 40, 255).astype(np.uint8)
    alpha[edge] = soft[edge]
    rgba[..., 3] = alpha

    # 빈 세로줄로 자세를 나눈다(조금 부풀려 떨어진 깃털 끝도 한 덩어리로)
    cols = dilate(fg, 4).any(axis=0)
    spans = []
    start = None
    for x, v in enumerate(cols):
        if v and start is None:
            start = x
        elif not v and start is not None:
            spans.append((start, x - 1))
            start = None
    if start is not None:
        spans.append((start, len(cols) - 1))
    spans = [s for s in spans if s[1] - s[0] > 40]
    # 맞닿은 자세(날개위·날개아래가 꼬리/날개 끝으로 닿았다) — 가장 넓은 덩어리를 그림이 제일 얇은 세로줄에서 가른다
    counts = fg.sum(axis=0)
    while len(spans) < len(NAMES):
        i = max(range(len(spans)), key=lambda k: spans[k][1] - spans[k][0])
        x0, x1 = spans[i]
        inner = range(x0 + 60, x1 - 60)
        cut = min(inner, key=lambda x: counts[x])
        print(f"덩어리 {spans[i]}를 x={cut}(그림 {counts[cut]}px)에서 가른다")
        spans[i:i + 1] = [(x0, cut), (cut + 1, x1)]
    if len(spans) != len(NAMES):
        raise SystemExit(f"자세가 {len(spans)}개 잡혔다(기대 {len(NAMES)}): {spans} — BG_THRESH/부풀리기 값을 손볼 것")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    report = {}
    for name, (x0, x1) in zip(NAMES, spans):
        sub = rgba[:, x0:x1 + 1]
        a = sub[..., 3] > 0
        ys, xs = np.where(a)
        cx0, cx1, cy0, cy1 = xs.min(), xs.max(), ys.min(), ys.max()
        crop = sub[max(cy0 - PAD, 0):cy1 + 1 + PAD, max(cx0 - PAD, 0):cx1 + 1 + PAD]
        Image.fromarray(crop).save(OUT_DIR / f"{name}.png")

        c = crop[..., :3].astype(int)
        vis = crop[..., 3] > 128
        orange = vis & (c[..., 0] > 190) & (c[..., 1] > 80) & (c[..., 1] < 200) & (c[..., 2] < 120)
        oy, ox = np.where(orange)
        h, w = crop.shape[:2]
        entry = {"size": [int(w), int(h)]}
        if len(ox):
            tip = np.argmax(ox)
            d = np.hypot(ox - ox[tip], oy - oy[tip])
            beak = d <= BEAK_RADIUS
            entry["beak"] = [round(float(ox[beak].mean()), 1), round(float(oy[beak].mean()), 1)]
            if (~beak).sum() > 30:
                entry["feet_bottom"] = int(oy[~beak].max())
                entry["feet_center_x"] = round(float(ox[~beak].mean()), 1)
        report[name] = entry
        print(name, json.dumps(entry, ensure_ascii=False))
    (OUT_DIR / "anchors.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
