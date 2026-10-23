class_name Strings
extends RefCounted
## Accès aux textes traduits (translations/strings.csv). Les arguments sont des {0}, {1}… (positions).
## Les pluriels sont deux clés : `<clé>_one` et `<clé>_other`.
##
## Les fichiers `.translation` générés par l'import du CSV sont déclarés dans project.godot
## (Paramètres du projet > Localisation). `ensure_loaded()` est un filet de sécurité : si la déclaration est
## absente ou si l'import n'a pas eu lieu, les traductions sont enregistrées ici, et l'on n'affiche jamais de clé brute.

const TRANSLATION_FILES: Array[String] = [
	"res://translations/strings.en.translation",
	"res://translations/strings.fr.translation",
]

static var _loaded := false


## Enregistre les traductions auprès du serveur si elles n'y sont pas déjà (idempotent).
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for path in TRANSLATION_FILES:
		var translation := load(path) as Translation
		if translation == null:
			push_error("Traduction introuvable : %s" % path)
			continue
		if TranslationServer.get_translation_object(translation.locale) != translation:
			TranslationServer.add_translation(translation)


static func set_language(language: int) -> void:
	ensure_loaded()
	TranslationServer.set_locale(Language.code(language))


static func t(key: String, args: Array = []) -> String:
	ensure_loaded()
	var text: String = TranslationServer.translate(key)
	return text.format(args) if not args.is_empty() else text


## Pluriel : « one » vaut 1 en anglais, 0 et 1 en français (règles CLDR).
static func n(key: String, count: int) -> String:
	var one := count == 1 or (TranslationServer.get_locale().begins_with("fr") and count == 0)
	return t(key + ("_one" if one else "_other"), [count])
