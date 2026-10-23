class_name MemoryFakes
extends RefCounted
## Doublures de test des ports (progression en mémoire, régie publicitaire simulée).


class MemoryProgress extends ProgressRepository:
	var state := ProgressState.new()
	var fail_writes := false

	func read() -> ProgressState:
		return state

	func update(transform: Callable) -> ProgressState:
		if fail_writes:
			return null
		state = transform.call(state)
		return state


class FakeAds extends AdProvider:
	var reason: int = UnavailableReason.NONE
	var rewarded: RewardedAdResult = RewardedAdResult.rewarded("ad-1")
	var return_ad_shown := 0

	func rewarded_unavailable_reason() -> int:
		return reason

	func show_rewarded() -> RewardedAdResult:
		return rewarded

	func show_return_ad_if_ready() -> bool:
		return_ad_shown += 1
		return true
