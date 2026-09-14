"""PNG 한 장으로 윈도우 아이콘(.ico)을 만든다.

    python tools/make_ico.py "sprite/메인메뉴/일러스트/잼민이/앱아이콘찐.png" icon.ico 1.0

- 그림에서 **실제로 색이 있는 부분(알파 경계)** 만 잘라내 정사각형 가운데에 놓는다.
- 세 번째 인자는 **채움 비율**(기본 0.92 = 사방 4% 여백). 캐릭터 그림 한 장을 아이콘으로 쓸 땐
  여백이 있어야 답답하지 않고, **이미 아이콘 모양으로 그린 그림(둥근 사각형 등)은 1.0**을 줘서
  그대로 꽉 채운다.
- 16 / 32 / 48 / 64 / 128 / 256 픽셀을 한 파일에 다 넣는다. 윈도우가 표시 크기에 맞춰 골라 쓴다.
- 표준 라이브러리(zlib, struct)만 쓴다 — Pillow 같은 외부 패키지가 필요 없다.
- .ico 안에는 PNG를 그대로 넣는다(Vista 이후 지원). BMP보다 파일이 작고 알파가 깔끔하다.
"""
import struct
import sys
import zlib

SIZES = [16, 32, 48, 64, 128, 256]
## 정사각형 한 변 대비 그림이 차지할 비율 (0.92면 사방에 4%씩 여백). 세 번째 인자로 바꿀 수 있다
FILL = 0.92


def decode_png(path):
	"""PNG를 (가로, 세로, RGBA 행 목록)으로 읽는다. 8비트 RGB/RGBA·인터레이스 없음만 지원."""
	data = open(path, "rb").read()
	assert data[:8] == b"\x89PNG\r\n\x1a\n", "PNG 파일이 아니다: %s" % path
	pos, idat, width, height, channels = 8, b"", 0, 0, 0
	while pos < len(data):
		length, kind = struct.unpack(">I4s", data[pos:pos + 8])
		body = data[pos + 8:pos + 8 + length]
		if kind == b"IHDR":
			width, height, depth, color = struct.unpack(">IIBB", body[:10])
			assert depth == 8 and color in (2, 6), "8비트 RGB/RGBA만 지원한다"
			channels = 3 if color == 2 else 4
		elif kind == b"IDAT":
			idat += body
		elif kind == b"IEND":
			break
		pos += 12 + length
	raw = zlib.decompress(idat)
	stride = width * channels
	rows, prev, at = [], bytearray(stride), 0
	for _ in range(height):
		filter_type = raw[at]
		line = bytearray(raw[at + 1:at + 1 + stride])
		at += 1 + stride
		for i in range(stride):
			left = line[i - channels] if i >= channels else 0
			up = prev[i]
			upleft = prev[i - channels] if i >= channels else 0
			if filter_type == 1:
				line[i] = (line[i] + left) & 255
			elif filter_type == 2:
				line[i] = (line[i] + up) & 255
			elif filter_type == 3:
				line[i] = (line[i] + (left + up) // 2) & 255
			elif filter_type == 4:
				p = left + up - upleft
				pa, pb, pc = abs(p - left), abs(p - up), abs(p - upleft)
				pred = left if (pa <= pb and pa <= pc) else (up if pb <= pc else upleft)
				line[i] = (line[i] + pred) & 255
		prev = line
		if channels == 4:
			rows.append(bytes(line))
		else:
			rgba = bytearray(width * 4)
			for x in range(width):
				rgba[x * 4:x * 4 + 3] = line[x * 3:x * 3 + 3]
				rgba[x * 4 + 3] = 255
			rows.append(bytes(rgba))
	return width, height, rows


def encode_png(width, height, rows):
	"""RGBA 행 목록을 PNG 바이트로 만든다 (필터 없음)."""
	raw = b"".join(b"\x00" + bytes(r) for r in rows)

	def chunk(kind, body):
		return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

	return (b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
		+ chunk(b"IDAT", zlib.compress(raw, 9))
		+ chunk(b"IEND", b""))


def alpha_bbox(width, height, rows):
	"""색이 있는(알파 > 8) 부분만 감싸는 네모. 전부 투명하면 그림 전체를 돌려준다."""
	x0, y0, x1, y1 = width, height, -1, -1
	for y in range(height):
		row = rows[y]
		for x in range(width):
			if row[x * 4 + 3] > 8:
				if x < x0: x0 = x
				if x > x1: x1 = x
				if y < y0: y0 = y
				if y > y1: y1 = y
	if x1 < 0:
		return 0, 0, width - 1, height - 1
	return x0, y0, x1, y1


def square_resize(width, height, rows, size):
	"""알파 경계를 정사각형 가운데에 놓고 size x size로 줄인다 (박스 필터 평균)."""
	x0, y0, x1, y1 = alpha_bbox(width, height, rows)
	side = max(x1 - x0 + 1, y1 - y0 + 1) / FILL
	cx, cy = (x0 + x1 + 1) / 2.0, (y0 + y1 + 1) / 2.0
	left, top = cx - side / 2.0, cy - side / 2.0
	step = side / size
	out = []
	for oy in range(size):
		line = bytearray(size * 4)
		sy0, sy1 = int(top + oy * step), int(top + (oy + 1) * step)
		for ox in range(size):
			sx0, sx1 = int(left + ox * step), int(left + (ox + 1) * step)
			# 알파를 가중치로 색을 평균낸다 — 그냥 평균내면 투명한 부분의 색이 섞여 테두리가 탁해진다
			acc_a = acc_r = acc_g = acc_b = count = 0
			for sy in range(sy0, max(sy1, sy0 + 1)):
				if sy < 0 or sy >= height:
					count += 1
					continue
				row = rows[sy]
				for sx in range(sx0, max(sx1, sx0 + 1)):
					count += 1
					if sx < 0 or sx >= width:
						continue
					i = sx * 4
					a = row[i + 3]
					acc_a += a
					acc_r += row[i] * a
					acc_g += row[i + 1] * a
					acc_b += row[i + 2] * a
			if count == 0 or acc_a == 0:
				continue
			line[ox * 4] = acc_r // acc_a
			line[ox * 4 + 1] = acc_g // acc_a
			line[ox * 4 + 2] = acc_b // acc_a
			line[ox * 4 + 3] = acc_a // count
		out.append(bytes(line))
	return out


def main():
	src = sys.argv[1] if len(sys.argv) > 1 else "sprite/축법소년/축법소년 정면.png"
	dst = sys.argv[2] if len(sys.argv) > 2 else "icon.ico"
	global FILL
	if len(sys.argv) > 3:
		FILL = float(sys.argv[3])
	width, height, rows = decode_png(src)
	images = [encode_png(s, s, square_resize(width, height, rows, s)) for s in SIZES]
	# ICONDIR + 크기별 ICONDIRENTRY + PNG 본문
	header = struct.pack("<HHH", 0, 1, len(SIZES))
	offset = len(header) + 16 * len(SIZES)
	entries = b""
	for size, blob in zip(SIZES, images):
		entries += struct.pack("<BBBBHHII", size % 256, size % 256, 0, 0, 1, 32, len(blob), offset)
		offset += len(blob)
	open(dst, "wb").write(header + entries + b"".join(images))
	print("%s -> %s (%d bytes, %s)" % (src, dst, offset, "/".join(str(s) for s in SIZES)))


main()
