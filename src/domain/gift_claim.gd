class_name GiftClaim
extends RefCounted

var state: ProgressState
var amount: int


func _init(p_state: ProgressState, p_amount: int) -> void:
	state = p_state
	amount = p_amount
