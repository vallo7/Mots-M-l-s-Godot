class_name TrophyStyle
extends RefCounted
## Présentation des trophées : couleur et nom de rareté, textes, date de déblocage.

const TIER_COLORS: Array[Color] = [
	Color8(0xD9, 0x7A, 0x3A), Color8(0x8E, 0xA3, 0xC0), Color8(0xF2, 0xA1, 0x00),
	Color8(0x2F, 0xBF, 0x63), Color8(0x1F, 0x8F, 0xE6), Color8(0x8E, 0x45, 0xE8),
]


static func tier_color(tier: int) -> Color:
	return TIER_COLORS[clampi(tier, 0, TIER_COLORS.size() - 1)]


static func tier_name(tier: int) -> String:
	return Strings.t(Trophy.tier_key(tier))


static func title(trophy: Trophy) -> String:
	return Strings.t(trophy.name_key())


static func description(trophy: Trophy) -> String:
	return Strings.t(trophy.description_key(), [trophy.target])


## Date de déblocage (secondes Unix, heure locale de l'appareil) : « 22/10/2026 » en français, « 10/22/2026 » en anglais.
static func date_text(unix_seconds: int) -> String:
	var local := Time.get_datetime_dict_from_unix_time(unix_seconds + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	if TranslationServer.get_locale().begins_with("fr"):
		return "%02d/%02d/%d" % [local["day"], local["month"], local["year"]]
	return "%02d/%02d/%d" % [local["month"], local["day"], local["year"]]
