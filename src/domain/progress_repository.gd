class_name ProgressRepository
extends RefCounted
## Progression persistante. `update` est atomique : lecture, transformation, écriture.
## `transform` : Callable(ProgressState) -> ProgressState. Interface : surchargée par les implémentations.


func read() -> ProgressState:
	push_error("ProgressRepository.read non implémenté")
	return ProgressState.new()


func update(_transform: Callable) -> ProgressState:
	push_error("ProgressRepository.update non implémenté")
	return ProgressState.new()
