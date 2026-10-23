class_name UiSounds
extends RefCounted
## Fichiers et volumes des sons d'interface (assets/audio/ui).

const DIRECTORY := "res://assets/audio/ui"

const _FILES := {
	Sound.CLICK: "click.wav",
	Sound.SELECT_CELL: "select_cell.wav",
	Sound.CORRECT: "correct.wav",
	Sound.WRONG: "wrong.wav",
	Sound.HINT: "hint.wav",
	Sound.GIFT: "gift.wav",
	Sound.PROGRESS_UP: "progress_up.wav",
	Sound.VICTORY: "victory.wav",
	Sound.MENU_CHANGE: "menu_change.wav",
	Sound.SUCCESS_GENERIC: "success_generic.wav",
	Sound.SHUFFLE: "shuffle.wav",
	Sound.SWIPE: "swipe.wav",
}

## Volume 0..1 (jamais de saturation : aucun son n'est joué au maximum).
const _VOLUMES := {
	Sound.CLICK: 0.7,
	Sound.SELECT_CELL: 0.5,
	Sound.CORRECT: 0.8,
	Sound.WRONG: 0.6,
	Sound.HINT: 0.8,
	Sound.GIFT: 0.9,
	Sound.PROGRESS_UP: 0.8,
	Sound.VICTORY: 0.85,
	Sound.MENU_CHANGE: 0.5,
	Sound.SUCCESS_GENERIC: 0.85,
	Sound.SHUFFLE: 0.7,
	Sound.SWIPE: 0.45,
}


static func all_sounds() -> Array:
	return _FILES.keys()


static func file_for(sound: int) -> String:
	return _FILES[sound]


static func asset_path(sound: int) -> String:
	return "%s/%s" % [DIRECTORY, _FILES[sound]]


static func volume_for(sound: int) -> float:
	return _VOLUMES[sound]
