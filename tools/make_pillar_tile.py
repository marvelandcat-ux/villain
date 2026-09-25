# 사용법: 프로젝트 루트에서  python -X utf8 tools/make_pillar_tile.py
# 기둥.png에서 세로로 이어 붙여도 이음매가 안 보이는 반복용 그림을 만든다.
# 반복 구간 [A, B) 끝의 K줄을, 구간 시작 바로 위 K줄(같은 위상)과 점점 섞어서 마지막 줄 다음이 첫 줄과 똑같이 이어지게 한다.
from PIL import Image
src = Image.open("sprite/맵/지하철역/기둥.png").convert("RGBA")
X0, X1 = 280, 608          # 몸통(285~602) + 양옆 여백 — 흐림이 바깥 투명을 섞어 가장자리가 부드럽게
A, B, K = 88, 1743, 40     # 구간 시작·끝(둘 다 가로줄에서 19px 아래), 섞는 줄 수
crop = src.crop((X0, A, X1, B))
out = crop.copy()
W = X1 - X0
H = B - A
for i in range(K):
    t = (i + 1) / K                     # 끝으로 갈수록 시작 쪽 모양에 가까워진다
    row_end = src.crop((X0, B - K + i, X1, B - K + i + 1))
    row_pre = src.crop((X0, A - K + i, X1, A - K + i + 1))
    out.paste(Image.blend(row_end, row_pre, t), (0, H - K + i))
out.save("sprite/맵/지하철역/기둥_반복.png")
print(out.size)
