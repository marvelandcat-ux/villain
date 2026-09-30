class_name Guide
extends Control

## 가이드 화면 — 메인 메뉴의 "가이드"로 들어오면 나오는 **갈림길 화면**(2026-09-30).
## 예전에는 메인 메뉴에 "조작 방법"과 "도감"이 따로 한 줄씩 있었는데, 둘 다 "읽어보는 것"이라
## 한 칸으로 묶고 여기서 고르게 했다.
##
## 칸은 캐릭터 선택·도감과 같은 `FanTile`이다 — 사선 평행사변형에 그림을 넣고 아래 띠에 이름을 건다.
## **흰 테두리는 FanTile이 알아서 그린다**(커서를 올리거나 포커스가 있으면). 여기서는 크기만 키운다

## 커서를 올렸을 때 칸이 커지는 배수와 따라붙는 속도(클수록 즉각적).
## 설정 화면 탭(`Settings.tab_hover_scale`)과 같은 방식이라 손맛이 통일된다
@export var hover_scale: float = 1.06
@export var hover_speed: float = 14.0
## 좌측 상단 ◀에 커서를 올렸을 때 커지는 배수 — 도감·설정과 같은 값
@export var back_hover_scale: float = 1.18

@onready var _cards: Array[FanTile] = [$Cards/HowToCard, $Cards/DexCard]

func _ready() -> void:
	for card in _cards:
		# 커지는 기준점을 칸 한가운데로 둔다 — 왼쪽 위를 기준으로 커지면 칸이 오른쪽 아래로 밀린다
		card.pivot_offset = card.size * 0.5
		card.mouse_entered.connect(card.grab_focus)
	$Cards/HowToCard.pressed.connect(_on_how_to_pressed)
	$Cards/DexCard.pressed.connect(_on_dex_pressed)
	$BackButton.pressed.connect(_on_back_pressed)
	# 커지는 기준점을 버튼 한가운데로 — 왼쪽 위 기준이면 커질 때 오른쪽 아래로 밀린다
	$BackButton.pivot_offset = ($BackButton as Control).size * 0.5
	$BackButton.mouse_entered.connect(_on_back_hover.bind(true))
	$BackButton.mouse_exited.connect(_on_back_hover.bind(false))
	_cards[0].grab_focus()

func _on_back_hover(entered: bool) -> void:
	var back: Button = $BackButton
	back.pivot_offset = back.size * 0.5
	var goal: Vector2 = Vector2.ONE * (back_hover_scale if entered else 1.0)
	var tw := create_tween()
	tw.tween_property(back, "scale", goal, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	# 지금 고른(=커서가 올라가 있거나 포커스가 있는) 칸만 조금 커진다
	for card in _cards:
		var target: float = hover_scale if (card.has_focus() or card.is_hovered()) else 1.0
		card.scale = card.scale.lerp(Vector2.ONE * target, clampf(delta * hover_speed, 0.0, 1.0))

func _on_how_to_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/HowToPlay.tscn")

func _on_dex_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/CharacterDex.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
