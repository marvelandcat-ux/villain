class_name ClaudeAIController
extends AIController

## AIController를 그대로 상속해서 순간순간의 이동/기본공격 판단은 기존 규칙 기반 로직에 맡기고,
## 몇 초에 한 번씩 Claude API에 현재 체력/거리/쿨타임 상황을 물어봐서 "전략"과 "지금 쓸 스킬"을 받아와 얹는다.
## API 왕복에 짧아도 수백 ms가 걸리기 때문에 매 프레임 호출은 불가능 — 그래서 Claude는
## 프레임 단위가 아니라 몇 초 주기의 "큰 그림" 판단만 담당한다

## 몇 초마다 한 번씩 Claude에게 판단을 물어볼지
@export var decision_interval: float = 2.5

const API_URL := "https://api.anthropic.com/v1/messages"
const MODEL := "claude-haiku-4-5-20251001"

var _http: HTTPRequest
var _decision_timer: float = 0.0
var _waiting_for_response: bool = false

func _ready() -> void:
	super._ready()
	# 스토리 상대는 조금 약하게 — 후속타(콤보 잇기·빈틈 파고들기·날아가는 상대 추격)를 모른다
	knows_follow_ups = false
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	if GameState.anthropic_api_key.is_empty():
		push_warning("ClaudeAIController: ANTHROPIC_API_KEY가 없어서 기본 규칙 기반 AI로만 동작합니다. .env 파일을 확인하세요.")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_active or GameState.anthropic_api_key.is_empty():
		return
	_decision_timer -= delta
	if _decision_timer <= 0.0 and not _waiting_for_response:
		_decision_timer = decision_interval
		_request_decision()

## 현재 상황을 요약해서 Claude에게 비동기로 물어본다. 응답은 _on_request_completed에서 처리된다
func _request_decision() -> void:
	if target == null or not is_instance_valid(target):
		return
	var system_prompt := "너는 2D 사이드뷰 대전 격투 게임의 AI 상대다. 아래 상황을 보고 다음 행동 전략을 딱 하나의 JSON으로만 답해라. 다른 설명은 절대 쓰지 마라. 형식: {\"strategy\": \"aggressive\" 또는 \"defensive\" 또는 \"retreat\", \"use_skill\": 1, 2, 3 중 하나 또는 null}. use_skill은 지금 당장 그 스킬을 쓰고 싶으면 번호(1=스킬1, 2=스킬2, 3=궁극기), 아니면 null. defensive를 고르면 상대가 가까울 때 보호막을 자주 켜서 받는 피해가 절반이 되지만 그 동안 움직이지도 때리지도 못한다. aggressive는 거의 안 막고 밀어붙인다."
	var body := {
		"model": MODEL,
		"max_tokens": 60,
		"system": system_prompt,
		"messages": [{"role": "user", "content": _build_state_summary()}],
	}
	var headers := PackedStringArray([
		"x-api-key: %s" % GameState.anthropic_api_key,
		"anthropic-version: 2023-06-01",
		"content-type: application/json",
	])
	var err := _http.request(API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err == OK:
		_waiting_for_response = true

func _build_state_summary() -> String:
	var my_hp_pct := int(round(100.0 * fighter.current_hp / fighter.stats.max_hp))
	var opp_hp_pct := int(round(100.0 * target.current_hp / target.stats.max_hp))
	var dist := int(absf(target.global_position.x - fighter.global_position.x))
	return "내 체력 %d%%, 상대 체력 %d%%, 거리 %dpx. 스킬1 사용가능=%s, 스킬2 사용가능=%s, 궁극기 사용가능=%s" % [
		my_hp_pct, opp_hp_pct, dist,
		str(fighter.skill_1 != null and fighter.skill_1.can_use()),
		str(fighter.skill_2 != null and fighter.skill_2.can_use()),
		str(fighter.skill_ultimate != null and fighter.skill_ultimate.can_use()),
	]

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_waiting_for_response = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("ClaudeAIController: API 요청 실패 (result=%d, code=%d)" % [result, response_code])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not (parsed is Dictionary) or not parsed.has("content"):
		return
	var text: String = parsed["content"][0]["text"]
	var decision = JSON.parse_string(_strip_code_fence(text))
	if decision == null or not (decision is Dictionary):
		return
	_apply_decision(decision)

## Claude가 응답을 ```json ... ``` 코드 블록으로 감싸서 줄 때가 있어서, 순수 JSON만 남기고 벗겨낸다
func _strip_code_fence(text: String) -> String:
	var trimmed := text.strip_edges()
	if trimmed.begins_with("```"):
		var lines := trimmed.split("\n")
		lines.remove_at(0)
		if not lines.is_empty() and lines[-1].strip_edges() == "```":
			lines.remove_at(lines.size() - 1)
		trimmed = "\n".join(lines)
	return trimmed

func _apply_decision(decision: Dictionary) -> void:
	var strategy: String = decision.get("strategy", "")
	# 전략은 "얼마나 자주 막느냐"로도 이어진다 — defensive가 예전엔 아무 일도 안 했다
	if strategy == "retreat":
		_retreat_timer = retreat_duration
		guard_bias = 1.5
	elif strategy == "aggressive":
		_retreat_timer = 0.0
		guard_bias = 0.4   # 밀어붙일 땐 거의 안 막는다
	elif strategy == "defensive":
		guard_bias = 3.0   # 붙어 있을 때 훨씬 자주 보호막을 켠다

	var use_skill = decision.get("use_skill", null)
	if use_skill == 1 and fighter.skill_1 and fighter.skill_1.can_use():
		fighter.use_skill_1()
	elif use_skill == 2 and fighter.skill_2 and fighter.skill_2.can_use():
		fighter.use_skill_2()
	elif use_skill == 3 and fighter.skill_ultimate and fighter.skill_ultimate.can_use():
		fighter.use_ultimate()
