class_name Trophy
extends RefCounted
## Un trophée (accomplissement) : un compteur (`metric`) à atteindre (`target`). Les textes sont dans
## translations/strings.csv sous `trophy_<id>_name` et `trophy_<id>_desc` (la description reçoit `{0}` = objectif).

## Rareté, de la plus courante à la plus rare ; elle donne la couleur du trophée.
enum Tier { BRONZE, SILVER, GOLD, EMERALD, SAPPHIRE, AMETHYST }

const TIER_ICONS: Array[String] = [
	"ic_trophy_bronze", "ic_trophy_silver", "ic_trophy", "ic_trophy_emerald", "ic_trophy_sapphire", "ic_trophy_amethyst",
]
const LOCKED_ICON := "ic_trophy_locked"

var id: String
var metric: String
## Objectif à atteindre : l'objectif d'origine (`base_target`) multiplié par `factor` (×2 ou ×3 selon le trophée),
## plafonné à `cap` quand le contenu du jeu ne permettrait pas d'aller plus loin (0 = pas de plafond).
var target: int
var tier: int
var base_target: int
var factor: int


func _init(p_id: String, p_metric: String, p_base_target: int, p_tier: int, p_factor: int = 1, p_cap: int = 0) -> void:
	id = p_id
	metric = p_metric
	base_target = p_base_target
	factor = maxi(p_factor, 1)
	target = base_target * factor
	if p_cap > 0:
		target = mini(target, p_cap)
	tier = p_tier


func name_key() -> String:
	return "trophy_%s_name" % id


func description_key() -> String:
	return "trophy_%s_desc" % id


func icon_name() -> String:
	return TIER_ICONS[tier]


static func tier_key(p_tier: int) -> String:
	return "trophy_tier_%d" % p_tier
