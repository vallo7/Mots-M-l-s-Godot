class_name SettingsRepository
extends RefCounted
## Réglages persistants. `update` est atomique. `transform` : Callable(AppSettings) -> AppSettings.


func read() -> AppSettings:
	push_error("SettingsRepository.read non implémenté")
	return AppSettings.new()


func update(_transform: Callable) -> AppSettings:
	push_error("SettingsRepository.update non implémenté")
	return AppSettings.new()
