class_name HintOutcome
extends RefCounted

enum Kind { REVEALED, NO_BALANCE, LIMIT_REACHED, NOTHING_TO_REVEAL }

var kind: int
var hint: RevealedHint
var state: GameState
var new_balance: int


func _init(p_kind: int, p_hint: RevealedHint = null, p_state: GameState = null, p_new_balance: int = 0) -> void:
	kind = p_kind
	hint = p_hint
	state = p_state
	new_balance = p_new_balance
