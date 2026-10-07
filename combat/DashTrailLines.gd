class_name DashTrailLines
extends Node2D

## 대시의 하얀 스피드 라인 — 혜성 꼬리 (순수 장식, 판정 없음). 그림 없이 `_draw()`로 그린다(2026-10-06 사용자 요청).
## 시전자가 지나간 자리를 **맵 좌표로 기록**해서 그 길을 따라 줄을 긋는다 — 점프하면 줄이 포물선으로 휜다.
## trail_time초보다 오래된 자리는 계속 지워져서 몸 바로 뒤의 꼬리만 남고, 서 있으면 꼬리가 몸 쪽으로 줄어든다.
## 기록이 끝나면(life초 뒤) 남은 꼬리가 몸 쪽으로 줄어들며 옅어진다.
## 줄 모양(앞쪽 끝도 짧게 투명)은 combat/SpeedLines.gd와 같은 느낌으로 맞췄다

## 줄 하나 — 지나간 길에서 이만큼 위아래로 떨어진 곳에 긋는다
class Line:
	var y: float = 0.0
	var tail_cut: float = 0.0    # 꼬리 끝을 이만큼(px) 덜 그린다 — 줄마다 길이가 달라 보이게
	var head_back: float = 0.0   # 시전자 위치보다 이만큼(px) 뒤에서 줄이 끝난다
	var width: float = 1.6

## 줄 개수
@export var line_count: int = 4
## 줄 색
@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.6)
## 줄이 생기는 높이 범위 (몸 기준, y는 음수가 위쪽)
@export var spread_y: Vector2 = Vector2(-40.0, 24.0)
## true면 spread_y만큼 위아래가 아니라 **지나간 길에 수직으로** 띄운다(점프처럼 세로로 움직일 때)
@export var offset_along_normal: bool = false
## 켜면 life와 상관없이 **시전자가 3타로 날아가는 동안만**(`is_finisher_flying()`) 기록한다
@export var while_flying: bool = false
## 꼬리에 남기는 시간(초) — 이보다 오래된 자리는 지워진다. 길수록 꼬리가 길다
@export var trail_time: float = 0.25
## 앞쪽 끝이 투명해지는 길이(px) — 줄이 짧으면 줄 길이의 30%까지만
@export var head_soft: float = 20.0
## 곡선을 이 간격(px)마다 끊어 그린다 — 작을수록 매끈하다
@export var sample_step: float = 4.0

var _caster: Node2D = null
## 기록을 계속할 남은 시간(초)
var _left: float = 0.0
## 이 노드가 생긴 뒤 흐른 시간(초) — 기록한 자리의 나이를 잰다
var _time: float = 0.0
## 기록이 끝난 순간의 _time (-1 = 아직 기록 중)
var _end_time: float = -1.0
## 지나간 자리(맵 좌표)와 그때의 _time — 오래된 것이 앞
var _points: PackedVector2Array = PackedVector2Array()
var _times: PackedFloat32Array = PackedFloat32Array()
var _lines: Array[Line] = []

## 대시가 시작될 때 부른다 — **add_child 다음에** 부를 것. life초 동안 시전자가 지나간 길을 기록한다
func setup(caster: Node2D, life: float) -> void:
	_caster = caster
	_left = life
	# 캐릭터 뒤에 깔린다 — z는 시전자와 같게 두고 트리 순서만 시전자 바로 앞으로.
	# 음수 z로 두면 배경이 z 0인 맵(번화가·헬스장·튜토리얼 숲)에선 배경 그림 뒤로 숨어서 안 보였다
	z_index = caster.z_index
	z_as_relative = caster.z_as_relative
	if caster.get_parent() == get_parent():
		get_parent().move_child(self, caster.get_index())
	global_position = Vector2.ZERO
	# 높이 범위를 줄 개수만큼 나눠 칸마다 하나씩 — 줄끼리 너무 붙지 않게
	var band: float = (spread_y.y - spread_y.x) / maxf(line_count, 1)
	for i in line_count:
		var l := Line.new()
		l.y = spread_y.x + band * (i + randf_range(0.2, 0.8))
		l.tail_cut = randf_range(0.0, 24.0)
		l.head_back = randf_range(4.0, 22.0)
		l.width = randf_range(1.4, 2.4)
		_lines.append(l)
	_record()

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_time += delta
	if _end_time < 0.0:
		_left -= delta
		var flying: bool = not while_flying or (is_instance_valid(_caster) and _caster.has_method("is_finisher_flying") and _caster.call("is_finisher_flying"))
		if _left > 0.0 and flying and is_instance_valid(_caster):
			_record()
		else:
			_end_time = _time
	_trim()
	if _end_time >= 0.0 and _time - _end_time >= trail_time:
		queue_free()
		return
	queue_redraw()

## 지금 시전자 자리를 기록한다
func _record() -> void:
	_points.append(_caster.global_position)
	_times.append(_time)

## trail_time보다 오래된 자리를 지운다 — 가장 오래된 점은 다음 점 쪽으로 끌어당겨 꼬리가 매끄럽게 줄어든다
func _trim() -> void:
	var cutoff: float = _time - trail_time
	while _times.size() >= 2 and _times[1] <= cutoff:
		_points.remove_at(0)
		_times.remove_at(0)
	if _times.size() >= 2 and _times[0] < cutoff:
		var t: float = inverse_lerp(_times[0], _times[1], cutoff)
		_points[0] = _points[0].lerp(_points[1], t)
		_times[0] = cutoff

func _draw() -> void:
	if _points.size() < 2:
		return
	# 앞쪽(시전자 쪽)부터 거꾸로 훑으며 앞쪽 끝에서 잰 거리를 쌓는다
	var path := PackedVector2Array()
	var dist := PackedFloat32Array()
	var total: float = 0.0
	for i in range(_points.size() - 1, -1, -1):
		var p: Vector2 = to_local(_points[i])
		if not path.is_empty():
			var seg: float = p.distance_to(path[path.size() - 1])
			if seg < 0.5:
				continue
			total += seg
		path.append(p)
		dist.append(total)
	if path.size() < 2:
		return
	# 기록이 끝난 뒤엔 남은 꼬리가 줄어들면서 전체가 옅어진다
	var fade: float = 0.0
	if _end_time >= 0.0:
		fade = clampf((_time - _end_time) / maxf(trail_time, 0.01), 0.0, 1.0)
	var peak_col: Color = line_color
	peak_col.a *= 1.0 - fade * fade
	var clear_col: Color = peak_col
	clear_col.a = 0.0
	for l in _lines:
		var head: float = l.head_back
		var tail: float = total - l.tail_cut
		if tail - head <= 2.0:
			continue
		var soft: float = minf(head_soft, (tail - head) * 0.3)
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var idx: int = 0
		var s: float = head
		while true:
			# 거리 s에 해당하는 길 위의 점 — s는 커지기만 하니 idx를 앞으로만 옮긴다
			while idx < dist.size() - 2 and dist[idx + 1] < s:
				idx += 1
			var t: float = inverse_lerp(dist[idx], dist[idx + 1], s)
			var off := Vector2(0.0, l.y)
			if offset_along_normal:
				# 길에 수직으로 띄운다 — 세로로 뛸 때 줄들이 좌우로 나란히 선다
				var dir: Vector2 = (path[idx + 1] - path[idx]).normalized()
				off = Vector2(-dir.y, dir.x) * l.y
			pts.append(path[idx].lerp(path[idx + 1], clampf(t, 0.0, 1.0)) + off)
			# 투명(앞쪽 끝) → 진함 → 투명(꼬리)
			if s < head + soft:
				cols.append(clear_col.lerp(peak_col, (s - head) / maxf(soft, 0.01)))
			else:
				cols.append(peak_col.lerp(clear_col, (s - head - soft) / maxf(tail - head - soft, 0.01)))
			if s >= tail:
				break
			s = minf(s + sample_step, tail)
		draw_polyline_colors(pts, cols, l.width)
