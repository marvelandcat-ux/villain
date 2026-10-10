extends Node
const D := "res://sprite/주정뱅이/몸/"
func _ready() -> void:
	var normal := ["주정뱅이 머리 (1).png", "주정뱅이 측면1.png", "주정뱅잉 측면2.png", "주정뱅이 머리 측면 3.png", "주정뱅이얼굴정면.png", "주정뱅이 뒷모습.png"]
	var drunk := ["주정뱅이 머리 술 머금은 (2).png", "주정뱅이 머리 술 먹금은 측면 1.png", "주정뱅이 머리 술 먹금은 측면 2.png", "주정뱅이 머리 술 먹금은 측면 3.png", "주정뱅이 머리 술머금은 정면.png"]
	for frac in [0.22]:
		for n in normal:
			print(">>> N ", n, " ", measure(D + n, frac))
		for n in drunk:
			print(">>> D ", n, " ", measure(D + n, frac))
	get_tree().quit()

# 알파를 1/4로 줄여 마스크 → 높이(마스크 bbox) 22% 지름 원으로 열림(침식→팽창) → 무게중심·2sqrt(넓이/pi)
func measure(path: String, frac: float) -> Vector3:
	var img: Image = (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var W: int = img.get_width() / 4
	var H: int = img.get_height() / 4
	var m := PackedByteArray()
	m.resize(W * H)
	var top := H
	var bot := -1
	for y in H:
		for x in W:
			var on: bool = img.get_pixel(x * 4 + 2, y * 4 + 2).a > 0.5
			m[y * W + x] = 1 if on else 0
			if on:
				top = mini(top, y)
				bot = maxi(bot, y)
	var r: float = float(bot - top + 1) * frac * 0.5
	var dist := _dist(m, W, H, true)   # 배경까지 거리
	var er := PackedByteArray()
	er.resize(W * H)
	for i in W * H:
		er[i] = 1 if dist[i] > r else 0
	var d2 := _dist(er, W, H, false)  # 침식된 것까지 거리
	var n := 0
	var sx := 0.0
	var sy := 0.0
	for y in H:
		for x in W:
			if d2[y * W + x] <= r and m[y * W + x] == 1:
				n += 1
				sx += x
				sy += y
	if n == 0:
		return Vector3.ZERO
	return Vector3(round((sx / n) * 4 + 2), round((sy / n) * 4 + 2), round(2.0 * sqrt(float(n) / PI) * 4))

# 두 번 훑는 근사 유클리드 거리(체임퍼 3-4). inside=true면 마스크 안 픽셀의 "밖까지" 거리, false면 마스크 밖 픽셀의 "마스크까지" 거리
func _dist(m: PackedByteArray, W: int, H: int, inside: bool) -> PackedFloat32Array:
	var BIG := 1e9
	var d := PackedFloat32Array()
	d.resize(W * H)
	for i in W * H:
		var target: bool = (m[i] == 0) if inside else (m[i] == 1)
		d[i] = 0.0 if target else BIG
	for y in H:
		for x in W:
			var i := y * W + x
			var v: float = d[i]
			if x > 0: v = minf(v, d[i - 1] + 1.0)
			if y > 0:
				v = minf(v, d[i - W] + 1.0)
				if x > 0: v = minf(v, d[i - W - 1] + 1.4142)
				if x < W - 1: v = minf(v, d[i - W + 1] + 1.4142)
			d[i] = v
	for y in range(H - 1, -1, -1):
		for x in range(W - 1, -1, -1):
			var i := y * W + x
			var v: float = d[i]
			if x < W - 1: v = minf(v, d[i + 1] + 1.0)
			if y < H - 1:
				v = minf(v, d[i + W] + 1.0)
				if x < W - 1: v = minf(v, d[i + W + 1] + 1.4142)
				if x > 0: v = minf(v, d[i + W - 1] + 1.4142)
			d[i] = v
	return d
