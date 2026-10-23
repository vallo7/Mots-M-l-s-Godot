class_name RewardOutcome
extends RefCounted

enum Kind { GRANTED, DISMISSED, DUPLICATE, UNAVAILABLE }

var kind: int
var amount: int = 0
var reason: int = UnavailableReason.NONE


func _init(p_kind: int, p_amount: int = 0, p_reason: int = UnavailableReason.NONE) -> void:
	kind = p_kind
	amount = p_amount
	reason = p_reason
