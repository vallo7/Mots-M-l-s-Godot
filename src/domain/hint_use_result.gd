class_name HintUseResult
extends RefCounted

enum Kind { USED, NO_BALANCE, LIMIT_REACHED, NOTHING_TO_REVEAL, FAILED }

var kind: int
var hint: RevealedHint
var new_balance: int


func _init(p_kind: int, p_hint: RevealedHint = null, p_new_balance: int = 0) -> void:
	kind = p_kind
	hint = p_hint
	new_balance = p_new_balance
