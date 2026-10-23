class_name Language
extends RefCounted
## Langues supportées. Le contenu (grilles, mots, thèmes) existe dans chaque langue.

enum { FR, EN }

const ALL: Array[int] = [FR, EN]


static func code(language: int) -> String:
	return "fr" if language == FR else "en"


## Retourne EN quand le code est inconnu (comme l'app Kotlin).
static func from_code(code_value: String) -> int:
	return FR if code_value.to_lower() == "fr" else EN


## Texte localisé : un Dictionary {"fr": ..., "en": ...}.
static func pick(text: Dictionary, language: int) -> String:
	return String(text.get(code(language), ""))
