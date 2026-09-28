# -*- coding: utf-8 -*-
"""타이틀 로고(sprite/타이틀/타이틀.png — 검은 손글씨 테두리만 있고 글자 안은 투명)에서
색을 칠할 글자 안쪽 영역과 빛 번짐 그림을 뽑는다. 결과 셋은 같은 캔버스(글자 영역 + 여백 PAD):
  타이틀_선.png   원본 테두리(잘라낸 것)
  타이틀_채움.png 글자 안쪽(흰색) — ui/TitleLogo.gdshader가 하양/무지개로 칠한다
  타이틀_빛.png   테두리+안쪽을 흐리게 번진 흰 그림(글자 둘레 은은한 빛)
글자 안쪽 판정: 투명 영역 덩어리마다 왼쪽·오른쪽으로 광선을 쏴서 테두리 선을 몇 번 건너는지 센다 —
홀수면 글자 몸통(칠함), 짝수면 바깥이나 'ㅇ'·'ㅂ' 같은 구멍(안 칠함). 로고 그림을 바꾸면 다시 돌릴 것:
  python -X utf8 tools/make_title_logo.py
"""
import os
from collections import deque
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sprite", "타이틀")
SRC = os.path.join(ROOT, "타이틀.png")
PAD = 70            # 빛 번짐이 잘리지 않게 글자 영역 둘레에 둘 여백(px)
LINE_ALPHA = 100    # 이 알파보다 진하면 테두리 선
FILL_UNDER = 7      # 채움을 테두리 밑으로 이만큼 넓혀 이음매 틈을 없앤다(테두리가 위에 덮임)
GLOW_RADIUS = 16
# 선이 서로 붙어 홀짝 판정이 틀리는 곳 — 원본 그림 좌표(x, y)를 찍으면 그 덩어리를 강제로 칠한다/비운다
FORCE_FILL = [(945, 707)]    # '이'의 ㅣ(사용자 지적 2026-09-28)
FORCE_EMPTY = [(818, 667)]   # '이'의 ㅇ 가운데 구멍(사용자 지적 2026-09-29)

src = Image.open(SRC).convert("RGBA")
bx0, by0, bx1, by1 = src.getchannel("A").getbbox()
W, H = bx1 - bx0 + PAD * 2, by1 - by0 + PAD * 2
line = Image.new("RGBA", (W, H), (0, 0, 0, 0))
line.paste(src.crop((bx0, by0, bx1, by1)), (PAD, PAD))

alpha = line.getchannel("A").tobytes()
solid = bytearray(1 if a > LINE_ALPHA else 0 for a in alpha)

# 투명 영역 덩어리 나누기(4방향)
label = [-1] * (W * H)
comps = []
for start in range(W * H):
    if solid[start] or label[start] != -1:
        continue
    cid = len(comps)
    pix = []
    q = deque([start])
    label[start] = cid
    while q:
        p = q.popleft()
        pix.append(p)
        x, y = p % W, p // W
        for n, ok in ((p - 1, x > 0), (p + 1, x < W - 1), (p - W, y > 0), (p + W, y < H - 1)):
            if ok and not solid[n] and label[n] == -1:
                label[n] = cid
                q.append(n)
    comps.append(pix)

def crossings(p, step):
    """p에서 가로로 캔버스 끝까지 가며 테두리 선 덩어리를 몇 번 건너는지"""
    x, y = p % W, p // W
    n, inside = 0, False
    while 0 <= x < W:
        s = solid[y * W + x]
        if s and not inside:
            n += 1
        inside = bool(s)
        x += step
    return n

fill = bytearray(W * H)
for cid, pix in enumerate(comps):
    xs = [p % W for p in pix]
    ys = [p // W for p in pix]
    if min(xs) == 0 or min(ys) == 0 or max(xs) == W - 1 or max(ys) == H - 1:
        continue   # 캔버스 가장자리에 닿음 = 바깥
    if len(pix) < 150:
        inside = True   # 선 속의 작은 틈 — 칠해서 메운다
    else:
        votes = 0
        samples = pix[:: max(1, len(pix) // 21)][:21]
        for p in samples:
            votes += 1 if crossings(p, -1) % 2 == 1 else -1
            votes += 1 if crossings(p, 1) % 2 == 1 else -1
        inside = votes > 0
    if inside:
        for p in pix:
            fill[p] = 255

for seeds, value in ((FORCE_FILL, 255), (FORCE_EMPTY, 0)):
    for ox, oy in seeds:
        p = (oy - by0 + PAD) * W + (ox - bx0 + PAD)
        assert label[p] != -1, ("테두리 선 위를 찍었다", ox, oy)
        for q in comps[label[p]]:
            fill[q] = value

fill_img = Image.frombytes("L", (W, H), bytes(fill))
grown = fill_img.filter(ImageFilter.MaxFilter(FILL_UNDER * 2 + 1))
# 넓힌 부분은 진한 테두리 밑에서만(바깥 안티앨리어싱 가장자리로 흰 테가 새지 않게)
line_mask = Image.frombytes("L", (W, H), bytes(255 if a >= 128 else 0 for a in alpha))
under = Image.frombytes("L", (W, H), bytes(min(g, m) for g, m in zip(grown.tobytes(), line_mask.tobytes())))
fill_a = Image.frombytes("L", (W, H), bytes(max(f, u) for f, u in zip(fill_img.tobytes(), under.tobytes())))
fill_out = Image.new("RGBA", (W, H), (255, 255, 255, 0))
fill_out.putalpha(fill_a)

silhouette = Image.frombytes("L", (W, H), bytes(max(f, a) for f, a in zip(fill_a.tobytes(), alpha)))
glow_a = silhouette.filter(ImageFilter.GaussianBlur(GLOW_RADIUS))
glow_out = Image.new("RGBA", (W, H), (255, 255, 255, 0))
glow_out.putalpha(glow_a)

line.save(os.path.join(ROOT, "타이틀_선.png"))
fill_out.save(os.path.join(ROOT, "타이틀_채움.png"))
glow_out.save(os.path.join(ROOT, "타이틀_빛.png"))
print("canvas", W, H, "components", len(comps), "filled", sum(1 for f in fill if f))
