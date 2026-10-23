class_name RewardedAdResult
extends RefCounted

enum Kind { REWARDED, DISMISSED, UNAVAILABLE }

var kind: int
var reward_id: String = ""
var reason: int = UnavailableReason.NONE


static func rewarded(id: String) -> RewardedAdResult:
	var r := RewardedAdResult.new()
	r.kind = Kind.REWARDED
	r.reward_id = id
	return r


static func dismissed() -> RewardedAdResult:
	var r := RewardedAdResult.new()
	r.kind = Kind.DISMISSED
	return r


static func unavailable(why: int) -> RewardedAdResult:
	var r := RewardedAdResult.new()
	r.kind = Kind.UNAVAILABLE
	r.reason = why
	return r
