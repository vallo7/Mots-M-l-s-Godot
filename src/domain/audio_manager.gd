class_name AudioManager
extends Node
## Retours sonores. Interface : surchargée par l'implémentation de la couche plateforme.


func play(_sound: int) -> void:
	pass


## Joue le praise dans `language` ; repli sur Sound.SUCCESS_GENERIC si le fichier manque.
func play_praise(_praise: int, _language: int) -> void:
	pass


func set_sfx_volume(_volume: float) -> void:
	pass


func set_sound_effects_enabled(_enabled: bool) -> void:
	pass


func set_music_enabled(_enabled: bool) -> void:
	pass


## Volume de la musique de fond, de 0 (muet) à 1.
func set_music_volume(_volume: float) -> void:
	pass
