class_name Sfx
extends RefCounted

## 효과음 한 번 울리기 — 어디서든 `Sfx.play(self, 소리)` 한 줄로 쓴다.
## 소리 노드를 **지금 장면 루트**에 붙여서, 부른 노드(판정·투사체)가 먼저 사라져도 소리가 끝까지 난다.
## 버스는 "Sfx"라 설정의 효과음 볼륨을 따른다. 다 울리면 스스로 지워진다

## 같은 소리가 기계처럼 똑같이 들리지 않게 매번 음높이를 이만큼 흔든다(±)
const DEFAULT_PITCH_JITTER: float = 0.08

## `stream`을 한 번 울린다. `pitch`는 기준 음높이(1 = 원래대로, 낮을수록 묵직하다)
static func play(from: Node, stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0, pitch_jitter: float = DEFAULT_PITCH_JITTER) -> void:
	if stream == null or from == null or not from.is_inside_tree():
		return
	var root: Node = from.get_tree().current_scene
	if root == null:
		root = from.get_tree().root
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Sfx"
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch + randf_range(-pitch_jitter, pitch_jitter), 0.05)
	# 컷인·클래시처럼 트리가 멈춘 동안에도 끊기지 않게
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.finished.connect(player.queue_free)
	root.add_child(player)
	player.play()
