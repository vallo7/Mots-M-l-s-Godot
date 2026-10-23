class_name AppSettings
extends RefCounted
## Réglages persistants. `language` : Language.FR/EN, ou NONE (-1) tant que le joueur n'a pas choisi
## (la langue du téléphone est alors utilisée).

const NONE := -1

var language: int = NONE
const DEFAULT_MUSIC_VOLUME := 0.6
const DEFAULT_SFX_VOLUME := 1.0

## Volume des effets sonores (clics, mots trouvés, victoire, voix de félicitations), de 0 (muet) à 1.
var sfx_volume := DEFAULT_SFX_VOLUME
## Volume de la musique de fond, de 0 (muet) à 1.
var music_volume := DEFAULT_MUSIC_VOLUME
var haptics_enabled := true
var reduce_motion := false
var large_text := false
var dark_mode := false

## Compatibilité : les effets sonores sont « actifs » dès que leur volume n'est pas nul.
var sound_enabled: bool:
	get:
		return sfx_volume > 0.001
	set(value):
		if value and sfx_volume <= 0.001:
			sfx_volume = DEFAULT_SFX_VOLUME
		elif not value:
			sfx_volume = 0.0

## Compatibilité : la musique est « active » dès que son volume n'est pas nul.
var music_enabled: bool:
	get:
		return music_volume > 0.001
	set(value):
		if value and music_volume <= 0.001:
			music_volume = DEFAULT_MUSIC_VOLUME
		elif not value:
			music_volume = 0.0


func copy() -> AppSettings:
	var c := AppSettings.new()
	c.language = language
	c.sfx_volume = sfx_volume
	c.music_volume = music_volume
	c.haptics_enabled = haptics_enabled
	c.reduce_motion = reduce_motion
	c.large_text = large_text
	c.dark_mode = dark_mode
	return c


## Langue effective : le choix du joueur, sinon la langue du téléphone (EN si elle n'est pas gérée).
func resolve_language(system_language_code: String) -> int:
	return language if language != NONE else Language.from_code(system_language_code)
