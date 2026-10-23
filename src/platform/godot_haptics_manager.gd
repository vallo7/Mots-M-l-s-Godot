class_name GodotHapticsManager
extends HapticsManager
## Retour haptique à quatre intensités via Input.vibrate_handheld (durée en ms, amplitude 0..1).
## Les valeurs reprennent celles de l'app d'origine (amplitude 0..255 ramenée à 0..1).

var _enabled := true


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func perform(effect: int) -> void:
	if not _enabled:
		return
	match effect:
		HapticEffect.SELECTION:
			Input.vibrate_handheld(12, 60.0 / 255.0)
		HapticEffect.CONFIRM:
			Input.vibrate_handheld(22, 140.0 / 255.0)
		HapticEffect.ERROR:
			Input.vibrate_handheld(14, 90.0 / 255.0)
		HapticEffect.SUCCESS:
			# Deux impulsions : légère puis franche, séparées par 50 ms de silence.
			Input.vibrate_handheld(30, 120.0 / 255.0)
			await get_tree().create_timer(0.08).timeout
			if _enabled:
				Input.vibrate_handheld(70, 230.0 / 255.0)
