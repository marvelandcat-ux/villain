extends RefCounted

## 대전 종료 연출(승리·패배·연행) 효과음을 한 곳에서 관리한다.
## 파일은 `Sound/result/`에 **아래 이름으로만** 넣으면 된다(확장자는 .ogg/.wav/.mp3 아무거나).
## 아직 파일이 없으면 조용히 넘어간다 — 그림 연출은 소리 없이도 그대로 돈다.
## class_name을 일부러 안 단다(새 class_name을 바로 타입으로 쓰면 파싱 에러) — 쓰는 쪽에서 preload한다

const DIR := "res://Sound/result/"
const EXTENSIONS := ["ogg", "wav", "mp3"]

## 출처(2026-10-08 받음, 전부 CC0 — 출처 표기 의무 없음):
##   popper.mp3     Pixabay "partypopper" (원본 Freesound Streety)
##   boo.mp3        Pixabay "boo" (원본 Freesound dr_skitz)
##   cheer.ogg      BigSoundBank #0236 "Shouts and Applauses of Teens #1"
##   applause.ogg   BigSoundBank #3521 "Applause from 40 People #5"
##   siren.ogg      BigSoundBank #0886 "Gendarmerie, Outdoor Siren"

## 축포(파티 폭죽) 펑
const POPPER := "popper"
## 박수
const APPLAUSE := "applause"
## 환호성
const CHEER := "cheer"
## 야유
const BOO := "boo"
## 패배 화면 빗소리(아직 파일 없음 — 넣으면 바로 나온다)
const RAIN := "rain"
## 연행 장면 사이렌
const SIREN := "siren"

## 사이렌(siren.ogg)의 **높은음이 시작되는 때**(초, 소리 처음 기준). 낮은음은 그 0.5초 뒤에 시작한다.
## 경광등을 소리에 맞춰 깜빡이려고 2026-10-08에 실제 파형에서 음높이를 재서 적었다(높은음 약 1312Hz / 낮은음 약 732Hz).
## 녹음된 진짜 사이렌이라 간격이 1.05~1.1초로 조금씩 흔들려서 고정 주기 대신 표를 쓴다.
## ⚠️ **siren 파일을 바꾸면 다시 재야 한다**
const SIREN_HIGH_STARTS := [0.032, 1.132, 2.219, 3.307, 4.394, 5.494, 6.582, 7.682, 8.769]
## 높은음 길이 / 표 뒤로 이어 갈 때의 한 바퀴(높은음+낮은음)
const SIREN_HIGH_LEN := 0.5
const SIREN_PERIOD := 1.092

## 사이렌 소리 t초 지점이 높은음인지 낮은음인지 → Vector2(1 = 높은음 / -1 = 낮은음, 그 음이 시작되고 흐른 초).
## 표가 끝난 뒤는 같은 박자로 이어 간다 — 소리가 꺼진 뒤에도 불빛이 같은 박자로 계속 돈다
static func siren_tone_at(t: float) -> Vector2:
	var starts: Array = SIREN_HIGH_STARTS
	var last: float = float(starts[starts.size() - 1])
	var base: float
	if t >= last:
		base = last + floorf((t - last) / SIREN_PERIOD) * SIREN_PERIOD
	elif t < float(starts[0]):
		return Vector2(-1.0, t + SIREN_PERIOD - SIREN_HIGH_LEN - float(starts[0]))
	else:
		base = float(starts[0])
		for s in starts:
			if float(s) <= t:
				base = float(s)
	var local: float = t - base
	if local < SIREN_HIGH_LEN:
		return Vector2(1.0, local)
	return Vector2(-1.0, local - SIREN_HIGH_LEN)

## 이름에 맞는 소리 파일을 찾는다. 없으면 null
static func stream(sound: String) -> AudioStream:
	for ext in EXTENSIONS:
		var path: String = "%s%s.%s" % [DIR, sound, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null

## `parent` 밑에 붙여서 튼다 — parent(연출 화면)가 사라지면 소리도 같이 끊긴다.
## 파일이 없으면 null을 돌려준다(부르는 쪽은 null이어도 그냥 넘어가면 된다)
static func play(parent: Node, sound: String, volume_db: float = 0.0, pitch: float = 1.0, loop: bool = false) -> AudioStreamPlayer:
	var s: AudioStream = stream(sound)
	if s == null or parent == null or not parent.is_inside_tree():
		return null
	var player := AudioStreamPlayer.new()
	player.stream = s
	player.bus = &"Sfx"
	player.volume_db = volume_db
	player.pitch_scale = pitch
	# 연출 중에 트리가 멈춰도 끊기지 않게
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	if loop:
		player.finished.connect(player.play)
	else:
		player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()
	return player

## 소리를 duration초 동안 줄이다가 끈다.
## 다 울려서 이미 지워진 플레이어를 넘겨도 된다 — 그래서 인자에 타입을 안 단다
## (타입을 달면 지워진 객체가 들어오는 순간 SCRIPT ERROR: 환호성이 승리 화면 중에 끝나면 실제로 났다)
static func fade_out(player, duration: float = 0.4) -> void:
	if not is_instance_valid(player) or not (player is AudioStreamPlayer):
		return
	var sound: AudioStreamPlayer = player
	var tween := sound.create_tween()
	tween.tween_property(sound, "volume_db", -40.0, duration)
	tween.tween_callback(sound.queue_free)
