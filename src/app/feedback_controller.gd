class_name FeedbackController
extends Node
## Point d'entrée unique des retours sonores et haptiques de l'interface (autoload `Feedback`),
## avec une garde anti double-clic courte (jamais un blocage long des boutons).

const CLICK_LOCK_MS := 350

var audio: AudioManager
var haptics: HapticsManager
var _last_click_at: int = -1_000_000


func _ready() -> void:
	# Doublures silencieuses tant que l'application n'a pas branché les vrais gestionnaires.
	set_managers(AudioManager.new(), HapticsManager.new())


## Branche les gestionnaires audio et haptique (nœuds : ils rejoignent l'arbre de scène).
func set_managers(new_audio: AudioManager, new_haptics: HapticsManager) -> void:
	for old in [audio, haptics]:
		if old != null:
			old.queue_free()
	audio = new_audio
	haptics = new_haptics
	add_child(audio)
	add_child(haptics)


## Vrai si un clic peut être traité ; refuse les clics répétés pendant CLICK_LOCK_MS.
func try_acquire_click() -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_click_at < CLICK_LOCK_MS:
		return false
	_last_click_at = now
	return true


func play(sound: int) -> void:
	audio.play(sound)


func play_praise(praise: int, language: int) -> void:
	audio.play_praise(praise, language)


func perform(effect: int) -> void:
	haptics.perform(effect)
