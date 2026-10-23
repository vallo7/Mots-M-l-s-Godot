class_name TextNormalizer
extends RefCounted
## « Île » -> « ILE » : majuscules, sans accents, lettres A-Z uniquement.
## Comme le code d'origine (décomposition NFD), les ligatures (œ, æ) et ß ne sont pas décomposées :
## elles sont ignorées, et le validateur signale donc tout mot qui en contiendrait.

const _ACCENT_GROUPS := {
	"A": "ÀÁÂÃÄÅ", "C": "Ç", "E": "ÈÉÊË", "I": "ÌÍÎÏ", "N": "Ñ", "O": "ÒÓÔÕÖ", "U": "ÙÚÛÜ", "Y": "ÝŸ",
}
static var _base_of: Dictionary = {}


static func to_grid_letters(display: String) -> String:
	if _base_of.is_empty():
		for base in _ACCENT_GROUPS:
			for ch in String(_ACCENT_GROUPS[base]):
				_base_of[ch] = base
	var out := ""
	for ch in display.to_upper():
		if ch >= "A" and ch <= "Z" and ch.length() == 1:
			out += ch
		elif _base_of.has(ch):
			out += String(_base_of[ch])
	return out
