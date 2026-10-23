class_name ScreenRoute
extends RefCounted
## Une destination de la pile de navigation.

## Pages pleines : HOME, GAME, MONUMENT, RESULT, HELP, DAILY, TROPHIES. Popups posés sur la page d'en dessous : SETTINGS, CREDITS, LANGUAGE.
enum Kind { HOME, GAME, MONUMENT, SETTINGS, CREDITS, RESULT, LANGUAGE, HELP, DAILY, TROPHIES }

var kind: int
var level_id: String = ""
var token: int = 0
var result: VictoryResult


static func home() -> ScreenRoute:
	return ScreenRoute._make(Kind.HOME)


static func monument() -> ScreenRoute:
	return ScreenRoute._make(Kind.MONUMENT)


static func settings() -> ScreenRoute:
	return ScreenRoute._make(Kind.SETTINGS)


static func credits() -> ScreenRoute:
	return ScreenRoute._make(Kind.CREDITS)


static func language() -> ScreenRoute:
	return ScreenRoute._make(Kind.LANGUAGE)


static func help() -> ScreenRoute:
	return ScreenRoute._make(Kind.HELP)


static func daily() -> ScreenRoute:
	return ScreenRoute._make(Kind.DAILY)


static func trophies() -> ScreenRoute:
	return ScreenRoute._make(Kind.TROPHIES)


## Vrai pour les routes affichées comme popup au-dessus de la page de base.
static func is_popup_kind(p_kind: int) -> bool:
	return p_kind == Kind.SETTINGS or p_kind == Kind.CREDITS or p_kind == Kind.LANGUAGE


static func game(p_level_id: String, p_token: int) -> ScreenRoute:
	var r := ScreenRoute._make(Kind.GAME)
	r.level_id = p_level_id
	r.token = p_token
	return r


static func result_of(p_result: VictoryResult) -> ScreenRoute:
	var r := ScreenRoute._make(Kind.RESULT)
	r.result = p_result
	return r


static func _make(p_kind: int) -> ScreenRoute:
	var r := ScreenRoute.new()
	r.kind = p_kind
	return r


## Clé stable : sert à détecter un changement d'écran réel.
func key() -> String:
	match kind:
		Kind.GAME:
			return "game-%s-%d" % [level_id, token]
		Kind.RESULT:
			return "result-%s" % result.level_id
		_:
			return ["home", "game", "monument", "settings", "credits", "result", "language", "help", "daily", "trophies"][kind]
